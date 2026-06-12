import Foundation

/// Tiny helper for surfacing the bundle version into welcome screens.
enum DaemonClientInfo {
    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }
}
