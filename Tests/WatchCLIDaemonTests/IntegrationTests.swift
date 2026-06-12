import XCTest
import Foundation
import HTTPTypes
import HummingbirdWSClient
import Logging
import NIOCore
@testable import WatchCLIDaemon
@testable import WatchCLIProtocol

final class IntegrationTests: XCTestCase {

    /// Pick an unused TCP port by binding 0 then closing.
    private func freePort() throws -> Int {
        let s = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(s) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(s, $0, len) }
        }
        XCTAssertEqual(bindResult, 0, "bind failed")
        let nameResult = withUnsafeMutablePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(s, $0, &len) }
        }
        XCTAssertEqual(nameResult, 0)
        return Int(UInt16(bigEndian: addr.sin_port))
    }

    func testEndToEnd_runsShellCommandAndStreamsOutput() async throws {
        let port = try freePort()
        let token = "test-token-\(UUID().uuidString)"
        var config = DaemonConfig.default
        config.host = "127.0.0.1"
        config.port = port
        config.shellPath = "/bin/sh"

        var serverLogger = Logger(label: "test.server"); serverLogger.logLevel = .error
        let app = makeApplication(config: config, token: token, logger: serverLogger)

        let serverTask = Task { try await app.runService() }
        defer { serverTask.cancel() }

        // Wait for the listener to bind.
        try await waitForPort(port: port, timeout: .seconds(5))

        var clientLogger = Logger(label: "test.client"); clientLogger.logLevel = .error
        var clientConfig = WebSocketClientConfiguration()
        clientConfig.additionalHeaders = HTTPFields([
            .init(name: .authorization, value: "Bearer \(token)")
        ])

        let collected = AsyncCollector()

        let client = WebSocketClient(
            url: "ws://127.0.0.1:\(port)/v1/session",
            configuration: clientConfig,
            logger: clientLogger
        ) { inbound, outbound, _ in
            // 1. start a one-shot session
            try await outbound.write(.text(WireCodec.encode(ClientMessage.start(.init(agent: "oneshot")))))
            // 2. send a command
            try await outbound.write(.text(WireCodec.encode(ClientMessage.input(.init(data: "echo wrist-hello && echo to-stderr 1>&2")))))
            // 3. consume server messages until exit marker
            for try await msg in inbound.messages(maxSize: 64 * 1024) {
                guard case .text(let text) = msg else { continue }
                let server = try WireCodec.decode(ServerMessage.self, from: text)
                await collected.append(server)
                if case .output(let p) = server, p.data.contains("[exit ") {
                    break
                }
            }
        }
        _ = try await client.run()

        let messages = await collected.all
        // banner should arrive first
        guard case .banner(let banner) = messages.first else {
            return XCTFail("expected first message to be banner, got \(messages.first as Any)")
        }
        XCTAssertEqual(banner.protocolVersion, ProtocolVersion.current)

        let allText = messages.compactMap { msg -> String? in
            if case .output(let p) = msg { return p.data } else { return nil }
        }.joined()
        XCTAssertTrue(allText.contains("wrist-hello"), "stdout missing in: \(allText)")
        XCTAssertTrue(allText.contains("to-stderr"),   "stderr missing in: \(allText)")
        XCTAssertTrue(allText.contains("[exit 0]"),    "exit marker missing in: \(allText)")
    }

    /// Drives the PTY-backed `shell` agent: sends `printf wrist\\n` and
    /// `exit\n`, expects the printed marker followed by an `exit` server
    /// message.
    func testEndToEnd_PTYShellInteractive() async throws {
        let port = try freePort()
        let token = "pty-token-\(UUID().uuidString)"
        var config = DaemonConfig.default
        config.host = "127.0.0.1"; config.port = port
        config.shellPath = "/bin/sh"
        var logger = Logger(label: "test.server"); logger.logLevel = .error

        let app = makeApplication(config: config, token: token, logger: logger)
        let serverTask = Task { try await app.runService() }
        defer { serverTask.cancel() }
        try await waitForPort(port: port, timeout: .seconds(5))

        var cfg = WebSocketClientConfiguration()
        cfg.additionalHeaders = HTTPFields([.init(name: .authorization, value: "Bearer \(token)")])
        var clog = Logger(label: "test.client"); clog.logLevel = .error

        let collected = AsyncCollector()
        let client = WebSocketClient(
            url: "ws://127.0.0.1:\(port)/v1/session",
            configuration: cfg, logger: clog
        ) { inbound, outbound, _ in
            try await outbound.write(.text(WireCodec.encode(ClientMessage.start(.init(agent: "shell", cols: 60, rows: 20)))))
            // Wait briefly for the shell to print its first prompt before
            // pushing input — `sh -i` writes its banner asynchronously.
            try await Task.sleep(for: .milliseconds(300))
            try await outbound.write(.text(WireCodec.encode(ClientMessage.input(.init(data: "printf wristmark\\n\n")))))
            try await outbound.write(.text(WireCodec.encode(ClientMessage.input(.init(data: "exit\n")))))

            for try await msg in inbound.messages(maxSize: 64 * 1024) {
                guard case .text(let text) = msg else { continue }
                let server = try WireCodec.decode(ServerMessage.self, from: text)
                await collected.append(server)
                if case .exit = server { break }
            }
        }
        _ = try await client.run()

        let messages = await collected.all
        let allText = messages.compactMap { msg -> String? in
            if case .output(let p) = msg { return p.data } else { return nil }
        }.joined()
        XCTAssertTrue(allText.contains("wristmark"),
                      "expected PTY shell to echo our marker; got: \(allText)")
        XCTAssertTrue(messages.contains(where: { if case .exit = $0 { true } else { false } }),
                      "expected an `exit` server message")
    }

    func testRejectsBadToken() async throws {
        let port = try freePort()
        var config = DaemonConfig.default
        config.host = "127.0.0.1"; config.port = port
        var logger = Logger(label: "test.server"); logger.logLevel = .error
        let app = makeApplication(config: config, token: "good", logger: logger)
        let serverTask = Task { try await app.runService() }
        defer { serverTask.cancel() }
        try await waitForPort(port: port, timeout: .seconds(5))

        var cfg = WebSocketClientConfiguration()
        cfg.additionalHeaders = HTTPFields([.init(name: .authorization, value: "Bearer wrong")])
        var clog = Logger(label: "test.client"); clog.logLevel = .error
        let client = WebSocketClient(url: "ws://127.0.0.1:\(port)/v1/session", configuration: cfg, logger: clog) { _, _, _ in }
        do {
            _ = try await client.run()
            XCTFail("expected upgrade rejection")
        } catch {
            // expected: server returned non-101 (it returns 200 from the
            // shouldUpgrade=.dontUpgrade branch which the client treats as a
            // failed upgrade).
        }
    }

    private func waitForPort(port: Int, timeout: Duration) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            let s = socket(AF_INET, SOCK_STREAM, 0)
            defer { close(s) }
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = UInt16(port).bigEndian
            inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)
            let r = withUnsafePointer(to: &addr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            if r == 0 { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("port \(port) never became reachable")
    }
}

actor AsyncCollector {
    private(set) var all: [ServerMessage] = []
    func append(_ m: ServerMessage) { all.append(m) }
}
