import XCTest
import Foundation
import HTTPTypes
import HummingbirdWSClient
import Logging
@testable import WatchCLIDaemon
@testable import WatchCLIProtocol

/// Targeted integration tests for the daemon's wire protocol that are cheaper
/// than the end-to-end flow tests in `IntegrationTests`.
final class DaemonProtocolTests: XCTestCase {

    func testPingReceivesPong() async throws {
        let port = try freePort()
        let token = "tok-\(UUID().uuidString)"
        var config = DaemonConfig.default
        config.host = "127.0.0.1"; config.port = port
        var slog = Logger(label: "test.server"); slog.logLevel = .error
        let app = makeApplication(config: config, token: token, logger: slog)
        let serverTask = Task { try await app.runService() }
        defer { serverTask.cancel() }
        try await waitForPort(port: port, timeout: .seconds(5))

        var cfg = WebSocketClientConfiguration()
        cfg.additionalHeaders = HTTPFields([.init(name: .authorization, value: "Bearer \(token)")])
        var clog = Logger(label: "test.client"); clog.logLevel = .error
        let collector = AsyncCollector()
        let client = WebSocketClient(url: "ws://127.0.0.1:\(port)/v1/session", configuration: cfg, logger: clog) { inbound, outbound, _ in
            try await outbound.write(.text(WireCodec.encode(ClientMessage.ping(id: 42))))
            for try await msg in inbound.messages(maxSize: 8 * 1024) {
                guard case .text(let s) = msg else { continue }
                let m = try WireCodec.decode(ServerMessage.self, from: s)
                await collector.append(m)
                if case .pong = m { break }
            }
        }
        _ = try await client.run()
        let messages = await collector.all
        XCTAssertTrue(messages.contains(where: {
            if case .pong(let id) = $0 { return id == 42 }
            return false
        }))
    }

    func testStartUnknownAgentReturnsError() async throws {
        let port = try freePort()
        let token = "tok-\(UUID().uuidString)"
        var config = DaemonConfig.default
        config.host = "127.0.0.1"; config.port = port
        var slog = Logger(label: "test.server"); slog.logLevel = .error
        let app = makeApplication(config: config, token: token, logger: slog)
        let serverTask = Task { try await app.runService() }
        defer { serverTask.cancel() }
        try await waitForPort(port: port, timeout: .seconds(5))

        var cfg = WebSocketClientConfiguration()
        cfg.additionalHeaders = HTTPFields([.init(name: .authorization, value: "Bearer \(token)")])
        var clog = Logger(label: "test.client"); clog.logLevel = .error
        let collector = AsyncCollector()
        let client = WebSocketClient(url: "ws://127.0.0.1:\(port)/v1/session", configuration: cfg, logger: clog) { inbound, outbound, _ in
            try await outbound.write(.text(WireCodec.encode(ClientMessage.start(.init(agent: "no-such-agent")))))
            for try await msg in inbound.messages(maxSize: 8 * 1024) {
                guard case .text(let s) = msg else { continue }
                let m = try WireCodec.decode(ServerMessage.self, from: s)
                await collector.append(m)
                if case .error = m { break }
            }
        }
        _ = try await client.run()
        let messages = await collector.all
        XCTAssertTrue(messages.contains(where: {
            if case .error(let p) = $0 { return p.code == "agent.notAllowed" }
            return false
        }))
    }

    func testOneshotInputBeforeStartReturnsError() async throws {
        let port = try freePort()
        let token = "tok-\(UUID().uuidString)"
        var config = DaemonConfig.default
        config.host = "127.0.0.1"; config.port = port
        var slog = Logger(label: "test.server"); slog.logLevel = .error
        let app = makeApplication(config: config, token: token, logger: slog)
        let serverTask = Task { try await app.runService() }
        defer { serverTask.cancel() }
        try await waitForPort(port: port, timeout: .seconds(5))

        var cfg = WebSocketClientConfiguration()
        cfg.additionalHeaders = HTTPFields([.init(name: .authorization, value: "Bearer \(token)")])
        var clog = Logger(label: "test.client"); clog.logLevel = .error
        let collector = AsyncCollector()
        let client = WebSocketClient(url: "ws://127.0.0.1:\(port)/v1/session", configuration: cfg, logger: clog) { inbound, outbound, _ in
            try await outbound.write(.text(WireCodec.encode(ClientMessage.input(.init(data: "ls")))))
            for try await msg in inbound.messages(maxSize: 8 * 1024) {
                guard case .text(let s) = msg else { continue }
                let m = try WireCodec.decode(ServerMessage.self, from: s)
                await collector.append(m)
                if case .error = m { break }
            }
        }
        _ = try await client.run()
        let messages = await collector.all
        XCTAssertTrue(messages.contains(where: {
            if case .error(let p) = $0 { return p.code == "session.notStarted" }
            return false
        }))
    }

    /// Verifies that the daemon's HTTP /health probe can be hit without auth.
    func testHealthEndpointIsPublic() async throws {
        let port = try freePort()
        var config = DaemonConfig.default
        config.host = "127.0.0.1"; config.port = port
        var slog = Logger(label: "test.server"); slog.logLevel = .error
        let app = makeApplication(config: config, token: "irrelevant", logger: slog)
        let serverTask = Task { try await app.runService() }
        defer { serverTask.cancel() }
        try await waitForPort(port: port, timeout: .seconds(5))

        let url = URL(string: "http://127.0.0.1:\(port)/health")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let http = response as! HTTPURLResponse
        XCTAssertEqual(http.statusCode, 200)
        let body = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(body.contains("\"ok\":true"))
        XCTAssertTrue(body.contains("\"protocol\":\"\(ProtocolVersion.current)\""))
    }

    // MARK: - Helpers (duplicated from IntegrationTests for self-containment)

    private func freePort() throws -> Int {
        let s = socket(AF_INET, SOCK_STREAM, 0); defer { close(s) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET); addr.sin_port = 0; addr.sin_addr.s_addr = INADDR_ANY.bigEndian
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafePointer(to: &addr) { p in p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(s, $0, len) } }
        _ = withUnsafeMutablePointer(to: &addr) { p in p.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(s, $0, &len) } }
        return Int(UInt16(bigEndian: addr.sin_port))
    }

    private func waitForPort(port: Int, timeout: Duration) async throws {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while ContinuousClock.now < deadline {
            let s = socket(AF_INET, SOCK_STREAM, 0); defer { close(s) }
            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET); addr.sin_port = UInt16(port).bigEndian
            inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)
            let r = withUnsafePointer(to: &addr) { p in p.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.connect(s, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
            if r == 0 { return }
            try await Task.sleep(for: .milliseconds(50))
        }
        XCTFail("port \(port) never came up")
    }
}
