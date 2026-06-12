import XCTest
@testable import WatchCLIProtocol

final class OutputBufferTests: XCTestCase {
    func testBannerProducesHostnameAndSystemLine() {
        var b = OutputBuffer()
        let effects = b.apply(.banner(.init(protocolVersion: "1", daemonVersion: "0.2.0", agent: "shell", hostname: "mac.local")))
        XCTAssertEqual(effects, [
            .bannerHostname("mac.local"),
            .lines([.init(text: "✓ mac.local · daemon 0.2.0", kind: .system)]),
        ])
    }

    func testOutputSplitsLinesAndStripsANSI() {
        var b = OutputBuffer()
        let e = b.apply(.output(.init(stream: .stdout, data: "\u{1B}[32mhello\u{1B}[0m\nworld")))
        guard case .lines(let chunks) = e.first else { return XCTFail() }
        XCTAssertEqual(chunks.map(\.text), ["hello"])
    }

    func testStderrSplitterIsIndependentOfStdout() {
        var b = OutputBuffer()
        _ = b.apply(.output(.init(stream: .stdout, data: "out-no-nl")))
        let e = b.apply(.output(.init(stream: .stderr, data: "err-line\n")))
        guard case .lines(let chunks) = e.first else { return XCTFail() }
        XCTAssertEqual(chunks.map(\.text), ["err-line"])
        // The stdout pending chunk should not have leaked into the stderr one.
    }

    func testExitEmitsLineAndHaptic() {
        var b = OutputBuffer()
        let effects = b.apply(.exit(.init(code: 137)))
        XCTAssertEqual(effects, [
            .lines([.init(text: "[exit 137]", kind: .system)]),
            .haptic(.notification),
        ])
    }

    func testErrorEmitsStderrLine() {
        var b = OutputBuffer()
        let effects = b.apply(.error(.init(code: "auth.invalid", message: "bad token")))
        XCTAssertEqual(effects, [
            .lines([.init(text: "! auth.invalid: bad token", kind: .stderr)])
        ])
    }

    func testPongIsSilent() {
        var b = OutputBuffer()
        XCTAssertEqual(b.apply(.pong(id: 1)), [])
    }

    func testConnectedHaptic() {
        var b = OutputBuffer()
        XCTAssertEqual(b.applyConnected(), [.haptic(.success)])
    }

    func testDisconnectedFlushesPendingAndAnnounces() {
        var b = OutputBuffer()
        _ = b.apply(.output(.init(stream: .stdout, data: "tail-without-nl")))
        let effects = b.applyDisconnected(reason: "io")
        // first effect: leftover stdout line
        guard case .lines(let leftover) = effects.first else { return XCTFail() }
        XCTAssertEqual(leftover.map(\.text), ["tail-without-nl"])
        // last effect: failure haptic
        XCTAssertEqual(effects.last, .haptic(.failure))
        // middle: an ✗ disconnected system line
        XCTAssertTrue(effects.contains(where: {
            if case .lines(let ls) = $0, ls.first?.text.contains("✗ disconnected") == true { return true }
            return false
        }))
    }
}
