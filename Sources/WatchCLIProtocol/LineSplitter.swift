/// Plain enum used by both the watchOS line model and the daemon. Lives in
/// `WatchCLIProtocol` so `LineSplitter` can be unit-tested in `swift test`
/// without depending on SwiftUI.
public enum TerminalLineKind: String, Sendable, Equatable, Codable {
    case stdout, stderr, system, prompt
}

/// Output from `LineSplitter`. Keeps zero UI dependency.
public struct TerminalLineChunk: Sendable, Equatable {
    public var text: String
    public var kind: TerminalLineKind
    public init(text: String, kind: TerminalLineKind) { self.text = text; self.kind = kind }
}

/// Buffers partial output and yields whole lines as they complete. Carriage
/// returns are normalised away; the trailing partial line stays in `pending`
/// until the next feed (or `flush`).
public struct LineSplitter: Sendable {
    public private(set) var pending: String = ""
    public init() {}

    public mutating func feed(_ chunk: String, kind: TerminalLineKind) -> [TerminalLineChunk] {
        // Strip lone CRs (CRLF -> LF; bare CR -> drop) so progress bars don't
        // explode the line buffer on the watch. A future ANSI parser can do
        // better; for P3 this is good enough.
        let normalized = chunk.replacingOccurrences(of: "\r\n", with: "\n")
                              .replacingOccurrences(of: "\r", with: "")
        let combined = pending + normalized
        var lines: [TerminalLineChunk] = []
        var current = combined.startIndex
        while let nl = combined[current...].firstIndex(of: "\n") {
            lines.append(.init(text: String(combined[current..<nl]), kind: kind))
            current = combined.index(after: nl)
        }
        pending = String(combined[current...])
        return lines
    }

    public mutating func flush(kind: TerminalLineKind) -> [TerminalLineChunk] {
        guard !pending.isEmpty else { return [] }
        let line = TerminalLineChunk(text: pending, kind: kind)
        pending = ""
        return [line]
    }
}
