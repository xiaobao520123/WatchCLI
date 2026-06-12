import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Microphone capture for watchOS / iOS. Records to a local m4a file
/// (AAC in MPEG-4) which is small + fast to upload, then surfaces the
/// raw bytes for the `TranscribeClient` to ship to the daemon.
@MainActor
public final class AudioRecorder: NSObject, ObservableObject {
    public enum State: Equatable, Sendable { case idle, recording, error(String) }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var level: Float = 0       // 0…1 RMS level for VU
    public private(set) var lastFileURL: URL?

    #if canImport(AVFoundation)
    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    #endif

    public override init() { super.init() }

    public func requestPermission() async -> Bool {
        #if canImport(AVFoundation)
        if #available(watchOS 11.0, iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { ok in cont.resume(returning: ok) }
            }
        }
        #else
        return false
        #endif
    }

    public func start() {
        #if canImport(AVFoundation)
        guard state != .recording else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.duckOthers])
            try session.setActive(true)

            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("watchcli-rec-\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 16_000,             // 16 kHz mono is plenty for Whisper
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            ]
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.isMeteringEnabled = true
            r.delegate = self
            guard r.record() else {
                state = .error("recorder.record() returned false")
                return
            }
            recorder = r
            lastFileURL = url
            state = .recording
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tickMeter() }
            }
        } catch {
            state = .error("\(error)")
        }
        #else
        state = .error("AVFoundation unavailable")
        #endif
    }

    /// Stops recording and returns the raw bytes of the captured m4a file
    /// (or `nil` on failure). Cleans up the temp file.
    @discardableResult
    public func stop() async -> Data? {
        #if canImport(AVFoundation)
        meterTimer?.invalidate(); meterTimer = nil
        guard let r = recorder else { state = .idle; return nil }
        r.stop()
        recorder = nil
        try? AVAudioSession.sharedInstance().setActive(false)
        state = .idle
        guard let url = lastFileURL else { return nil }
        let data = try? Data(contentsOf: url)
        try? FileManager.default.removeItem(at: url)
        lastFileURL = nil
        return data
        #else
        return nil
        #endif
    }

    public func cancel() {
        Task { _ = await self.stop() }
    }

    #if canImport(AVFoundation)
    private func tickMeter() {
        guard let r = recorder else { return }
        r.updateMeters()
        // dBFS in [-160, 0]; map to [0, 1]
        let db = max(-50.0, Double(r.averagePower(forChannel: 0)))
        level = Float((db + 50.0) / 50.0)
    }
    #endif
}

#if canImport(AVFoundation)
extension AudioRecorder: AVAudioRecorderDelegate {
    public nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in if !flag { self.state = .error("recording cut short") } }
    }
}
#endif
