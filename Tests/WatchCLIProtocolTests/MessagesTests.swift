import XCTest
@testable import WatchCLIProtocol

final class MessagesTests: XCTestCase {
    func testRoundTrip_start() throws {
        let original = ClientMessage.start(.init(agent: "shell", cols: 60, rows: 8, env: ["TERM": "xterm-256color"]))
        let json = try WireCodec.encode(original)
        let back = try WireCodec.decode(ClientMessage.self, from: json)
        XCTAssertEqual(original, back)
        XCTAssertTrue(json.contains("\"type\":\"start\""))
    }

    func testRoundTrip_input_resize_signal_ping_stop() throws {
        let cases: [ClientMessage] = [
            .input(.init(data: "ls -la\n")),
            .resize(.init(cols: 40, rows: 10)),
            .signal(.init(signal: 2)),
            .ping(id: 42),
            .stop,
        ]
        for msg in cases {
            let json = try WireCodec.encode(msg)
            let back = try WireCodec.decode(ClientMessage.self, from: json)
            XCTAssertEqual(msg, back, "round-trip failed for \(msg)")
        }
    }

    func testRoundTrip_serverMessages() throws {
        let cases: [ServerMessage] = [
            .banner(.init(protocolVersion: "1", daemonVersion: "0.1.0", agent: "shell", hostname: "macbook.local")),
            .output(.init(stream: .stdout, data: "hello\n")),
            .output(.init(stream: .stderr, data: "warn\n")),
            .exit(.init(code: 0)),
            .error(.init(code: "auth.invalid", message: "bad token")),
            .pong(id: 7),
        ]
        for msg in cases {
            let json = try WireCodec.encode(msg)
            let back = try WireCodec.decode(ServerMessage.self, from: json)
            XCTAssertEqual(msg, back, "round-trip failed for \(msg)")
        }
    }

    func testProtocolVersionConstant() {
        XCTAssertEqual(ProtocolVersion.current, "1")
    }
}
