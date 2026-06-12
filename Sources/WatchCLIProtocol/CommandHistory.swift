import Foundation

/// Persists the last N user-entered command lines so the user can recall
/// them from the watch without re-dictating. Lives in `WatchCLIProtocol`
/// (no UI deps) so it can be unit-tested by `swift test`.
public struct CommandHistory: Equatable, Codable, Sendable {
    public var entries: [String]
    public static let maxEntries = 20

    public init(entries: [String] = []) { self.entries = entries }

    /// Records a new command. Move-to-front semantics: re-using an existing
    /// command bubbles it to the top instead of producing a duplicate.
    public mutating func record(_ raw: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return }
        entries.removeAll { $0 == s }
        entries.insert(s, at: 0)
        if entries.count > Self.maxEntries {
            entries = Array(entries.prefix(Self.maxEntries))
        }
    }

    public static func decode(_ raw: String) -> CommandHistory {
        guard let data = raw.data(using: .utf8),
              let h = try? JSONDecoder().decode(CommandHistory.self, from: data) else {
            return .init()
        }
        return h
    }
    public func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let s = String(data: data, encoding: .utf8) else { return "{}" }
        return s
    }
}
