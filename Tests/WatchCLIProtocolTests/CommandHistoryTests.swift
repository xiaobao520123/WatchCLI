import XCTest
@testable import WatchCLIProtocol

final class CommandHistoryTests: XCTestCase {
    func testRecordAddsToTop() {
        var h = CommandHistory()
        h.record("ls"); h.record("pwd")
        XCTAssertEqual(h.entries, ["pwd", "ls"])
    }

    func testRecordDedupesAndMovesToFront() {
        var h = CommandHistory(entries: ["a", "b", "c"])
        h.record("b")
        XCTAssertEqual(h.entries, ["b", "a", "c"])
    }

    func testRecordCapsAtMaxEntries() {
        var h = CommandHistory()
        for i in 0..<(CommandHistory.maxEntries + 5) { h.record("c\(i)") }
        XCTAssertEqual(h.entries.count, CommandHistory.maxEntries)
        XCTAssertEqual(h.entries.first, "c\(CommandHistory.maxEntries + 4)")
    }

    func testIgnoresWhitespaceOnlyEntries() {
        var h = CommandHistory()
        h.record("   "); h.record("\n")
        XCTAssertTrue(h.entries.isEmpty)
    }

    func testEncodeDecodeRoundTrip() {
        var h = CommandHistory()
        h.record("git status"); h.record("ls -la")
        let copy = CommandHistory.decode(h.encoded())
        XCTAssertEqual(copy, h)
    }

    func testDecodeOfBlobReturnsEmpty() {
        XCTAssertEqual(CommandHistory.decode("not-json"), .init())
        XCTAssertEqual(CommandHistory.decode("{}"), .init())
    }
}
