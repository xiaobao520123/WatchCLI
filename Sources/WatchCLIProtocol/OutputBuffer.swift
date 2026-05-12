import Foundation

/// Pure projection from `ServerMessage` events to terminal-render output.
/// Has no UI / `MainActor` dependency so it can be unit-tested in
/// `swift test`. The watchOS view-model owns one of these and forwards the
/// emitted lines into its `@Published` state.
public struct OutputBuffer: Sendable {
    public enum Effect: Equatable, Sendable {
        case lines([TerminalLineChunk])
        case bannerHostname(String)
        case haptic(Haptic)

        public enum Haptic: Equatable, Sendable {
            case success, failure, click, notification
        }
    }

    private var stdoutSplitter = LineSplitter()
    private var stderrSplitter = LineSplitter()

    public init() {}

    /// Apply a server-originated message and return the effects the UI should
    /// observe. Multiple lines may be produced per call (e.g. when an
    /// `output` chunk contains several newlines).
    public mutating func apply(_ message: ServerMessage) -> [Effect] {
        switch message {
        case .banner(let p):
            return [
                .bannerHostname(p.hostname),
                .lines([.init(text: "✓ \(p.hostname) · daemon \(p.daemonVersion)", kind: .system)]),
            ]
        case .output(let p):
            switch p.stream {
            case .stdout: return [.lines(stdoutSplitter.feed(p.data, kind: .stdout))]
            case .stderr: return [.lines(stderrSplitter.feed(p.data, kind: .stderr))]
            }
        case .error(let p):
            return [.lines([.init(text: "! \(p.code): \(p.message)", kind: .stderr)])]
        case .exit(let p):
            return [
                .lines([.init(text: "[exit \(p.code)]", kind: .system)]),
                .haptic(.notification),
            ]
        case .pong:
            return []
        }
    }

    /// Apply a connection-state event.
    public mutating func applyConnected() -> [Effect] {
        [.haptic(.success)]
    }
    public mutating func applyDisconnected(reason: String?) -> [Effect] {
        var effects: [Effect] = []
        let leftoverStdout = stdoutSplitter.flush(kind: .stdout)
        let leftoverStderr = stderrSplitter.flush(kind: .stderr)
        if !leftoverStdout.isEmpty { effects.append(.lines(leftoverStdout)) }
        if !leftoverStderr.isEmpty { effects.append(.lines(leftoverStderr)) }
        effects.append(.lines([.init(text: "✗ disconnected\(reason.map { " (\($0))" } ?? "")", kind: .system)]))
        effects.append(.haptic(.failure))
        return effects
    }
}
