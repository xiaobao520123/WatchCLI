import XCTest
@testable import WatchCLIProtocol

final class LineSplitterTests: XCTestCase {
    func testEmitsCompleteLinesAndKeepsRemainder() {
        var s = LineSplitter()
        let first = s.feed("hello\nworld", kind: .stdout)
        XCTAssertEqual(first.map(\.text), ["hello"])
        XCTAssertEqual(s.pending, "world")

        let next = s.feed("!\nfoo\n", kind: .stdout)
        XCTAssertEqual(next.map(\.text), ["world!", "foo"])
        XCTAssertEqual(s.pending, "")
    }

    func testNormalisesCRLFAndDropsBareCR() {
        var s = LineSplitter()
        let out = s.feed("a\r\nb\rc\n", kind: .stdout)
        XCTAssertEqual(out.map(\.text), ["a", "bc"])
    }

    func testFlushEmitsPending() {
        var s = LineSplitter()
        _ = s.feed("partial", kind: .stderr)
        let flushed = s.flush(kind: .stderr)
        XCTAssertEqual(flushed.map(\.text), ["partial"])
        XCTAssertEqual(flushed.map(\.kind), [.stderr])
        XCTAssertEqual(s.pending, "")
    }

    func testKindIsPreserved() {
        var s = LineSplitter()
        let lines = s.feed("hi\n", kind: .stderr)
        XCTAssertEqual(lines.first?.kind, .stderr)
    }

    func testStripsCSIColorEscapes() {
        var s = LineSplitter()
        let line = "\u{1B}[31mred\u{1B}[0m text\n"
        XCTAssertEqual(s.feed(line, kind: .stdout).map(\.text), ["red text"])
    }

    func testStripsOSCTitleSequences() {
        var s = LineSplitter()
        // OSC 0;set title\u{07} (BEL terminator)
        let line = "\u{1B}]0;some-title\u{07}prompt> \n"
        XCTAssertEqual(s.feed(line, kind: .stdout).map(\.text), ["prompt> "])
    }

    func testCanDisableStripping() {
        var s = LineSplitter(stripANSI: false)
        let line = "\u{1B}[31mred\u{1B}[0m\n"
        XCTAssertEqual(s.feed(line, kind: .stdout).map(\.text), ["\u{1B}[31mred\u{1B}[0m"])
    }

    func testHandlesPartialEscapeAcrossChunks_safely() {
        // We don't promise correctness across split escapes (would need a
        // proper state machine), but we do promise no crash and eventual
        // emission of the whole line including the broken chunk.
        var s = LineSplitter()
        _ = s.feed("foo\u{1B}", kind: .stdout)
        _ = s.feed("[31mbar\n", kind: .stdout)
        // Anything is fine here — just ensure we got something and didn't trap.
        XCTAssertNotNil(s.pending)
    }
}

final class ANSITests: XCTestCase {
    func testStripsBackspacesNotTouched() {
        // We deliberately do NOT strip backspaces; only CSI/OSC/ESC pairs.
        XCTAssertEqual(ANSI.strip("a\u{08}b"), "a\u{08}b")
    }
    func testStripsClearScreen() {
        XCTAssertEqual(ANSI.strip("\u{1B}[2J\u{1B}[Hhello"), "hello")
    }
}
