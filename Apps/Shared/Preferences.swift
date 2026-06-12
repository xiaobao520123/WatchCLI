import Foundation
import SwiftUI
import Combine

/// Cross-process / cross-device app preferences. Source of truth lives in
/// `@AppStorage` on the iPhone (so the user can edit them) and is synced
/// to the Watch via `EndpointSyncBridge.applicationContext`.
public final class Preferences: ObservableObject {
    @AppStorage("voiceInputMode") public var voiceInputMode: String = VoiceInputMode.nativeDictation.rawValue
    @AppStorage("themeFontSize")  public var themeFontSize: Int = 9
    @AppStorage("hapticsEnabled") public var hapticsEnabled: Bool = true
    @AppStorage("autoConnect")    public var autoConnect: Bool = true
    @AppStorage("scrollWithCrown") public var scrollWithCrown: Bool = true
    @AppStorage("crownTabSwitch")  public var crownTabSwitch: Bool = true

    public enum VoiceInputMode: String, CaseIterable, Identifiable, Sendable {
        case nativeDictation       // watchOS / iOS built-in dictation (default)
        case whisperViaDaemon      // POST /v1/transcribe → OpenAI Whisper
        case off                   // typing only, hide mic UI

        public var id: String { rawValue }
        public var label: String {
            switch self {
            case .nativeDictation:  "Native Dictation"
            case .whisperViaDaemon: "Whisper (via daemon)"
            case .off:              "Off (typing only)"
            }
        }
        public var subtitle: String {
            switch self {
            case .nativeDictation:  "Built-in. Tap text field, then mic."
            case .whisperViaDaemon: "Higher quality. Requires OpenAI key on daemon."
            case .off:              "Hide mic UI entirely."
            }
        }
    }

    public init() {}

    public var voice: VoiceInputMode {
        VoiceInputMode(rawValue: voiceInputMode) ?? .nativeDictation
    }

    /// Encode current prefs to a JSON dict suitable for
    /// WCSession.updateApplicationContext.
    public func toContext() -> [String: Any] {
        [
            "voiceInputMode":  voiceInputMode,
            "themeFontSize":   themeFontSize,
            "hapticsEnabled":  hapticsEnabled,
            "autoConnect":     autoConnect,
            "scrollWithCrown": scrollWithCrown,
            "crownTabSwitch":  crownTabSwitch,
        ]
    }

    /// Mirror an incoming applicationContext dict from the iPhone.
    public func absorb(_ dict: [String: Any]) {
        if let s = dict["voiceInputMode"] as? String { voiceInputMode = s }
        if let n = dict["themeFontSize"] as? Int     { themeFontSize = n }
        if let b = dict["hapticsEnabled"] as? Bool   { hapticsEnabled = b }
        if let b = dict["autoConnect"] as? Bool      { autoConnect = b }
        if let b = dict["scrollWithCrown"] as? Bool  { scrollWithCrown = b }
        if let b = dict["crownTabSwitch"] as? Bool   { crownTabSwitch = b }
        objectWillChange.send()
    }
}
