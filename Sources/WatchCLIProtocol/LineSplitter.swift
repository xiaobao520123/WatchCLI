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

/// Buffers partial output and yields whole lines as they complete.
///
/// - Carriage returns are normalised away (`\r\n` → `\n`, bare `\r` → drop).
/// - When `stripANSI` is true (the default) ANSI CSI / OSC escape sequences
///   are stripped before splitting. The watch can't render them as colors
///   yet, and showing the raw bytes turns prompts into noise.
public struct LineSplitter: Sendable {
    public var stripANSI: Bool
    public private(set) var pending: String = ""

    public init(stripANSI: Bool = true) { self.stripANSI = stripANSI }

    public mutating func feed(_ chunk: String, kind: TerminalLineKind) -> [TerminalLineChunk] {
        var normalized = chunk.replacingOccurrences(of: "\r\n", with: "\n")
                              .replacingOccurrences(of: "\r", with: "")
        if stripANSI { normalized = ANSI.strip(normalized) }
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

/// ANSI escape-sequence stripper. Handles the common cases we see from
/// interactive shells: CSI (`ESC [ … final`), OSC (`ESC ] … BEL` or
/// `ESC ] … ESC \`), and lone `ESC` letters.
public enum ANSI {
    public static func strip(_ s: String) -> String {
        guard s.contains("\u{1B}") else { return s }
        var out = String()
        out.reserveCapacity(s.count)
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c != "\u{1B}" {
                out.append(c)
                i = s.index(after: i)
                continue
            }
            // ESC encountered. Look at the next char.
            let after = s.index(after: i)
            guard after < s.endIndex else { break }
            let kind = s[after]
            switch kind {
            case "[":
                // CSI: ESC [ params* final-byte (0x40..0x7E)
                var j = s.index(after: after)
                while j < s.endIndex {
                    let ch = s[j]
                    if let scalar = ch.unicodeScalars.first,
                       scalar.value >= 0x40 && scalar.value <= 0x7E {
                        j = s.index(after: j); break
                    }
                    j = s.index(after: j)
                }
                i = j
            case "]":
                // OSC: ESC ] data BEL  or  ESC ] data ESC \
                var j = s.index(after: after)
                while j < s.endIndex {
                    let ch = s[j]
                    if ch == "\u{07}" { j = s.index(after: j); break }
                    if ch == "\u{1B}", let k = s.index(j, offsetBy: 1, limitedBy: s.endIndex), k < s.endIndex, s[k] == "\\" {
                        j = s.index(after: k); break
                    }
                    j = s.index(after: j)
                }
                i = j
            default:
                // ESC <single char>; just drop both.
                i = s.index(after: after)
            }
        }
        return out
    }
}
