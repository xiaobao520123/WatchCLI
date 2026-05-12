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
}
