import Foundation
import Hummingbird
import HummingbirdWebSocket
import Logging
import WatchCLIProtocol

public enum DaemonVersion {
    public static let current = "0.1.0"
}

/// Builds a Hummingbird application configured with the WatchCLI routes.
/// Returned as a value so tests can spawn one on a random port.
public func makeApplication(config: DaemonConfig, token: String, logger: Logger? = nil) -> some ApplicationProtocol {
    let log = logger ?? Logger(label: "watchcli.daemon")
    let router = Router(context: BasicWebSocketRequestContext.self)

    router.get("/health") { _, _ -> Response in
        let body = #"{"ok":true,"version":"\#(DaemonVersion.current)","protocol":"\#(ProtocolVersion.current)"}"#
        return Response(status: .ok,
                        headers: [.contentType: "application/json"],
                        body: .init(byteBuffer: ByteBuffer(string: body)))
    }

    router.ws(
        "/v1/session",
        shouldUpgrade: { request, _ in
            // Accept token via `Authorization: Bearer <t>` or `?token=<t>`.
            let presented: String? = {
                if let h = request.headers[.authorization],
                   h.lowercased().hasPrefix("bearer ") {
                    return String(h.dropFirst(7)).trimmingCharacters(in: .whitespaces)
                }
                if let q = request.uri.queryParameters.get("token") {
                    return q
                }
                return nil
            }()

            guard let presented, constantTimeEquals(presented, token) else {
                log.warning("rejected ws upgrade: bad/missing token")
                return .dontUpgrade
            }
            return .upgrade([:])
        },
        onUpgrade: { inbound, outbound, context in
            await SessionHandler(config: config, log: log).run(inbound: inbound, outbound: outbound)
        }
    )

    let app = Application(
        router: router,
        server: .http1WebSocketUpgrade(webSocketRouter: router),
        configuration: .init(address: .hostname(config.host, port: config.port)),
        logger: log
    )
    return app
}

/// Per-connection actor that owns the protocol state for one WebSocket.
actor SessionHandler {
    let config: DaemonConfig
    let log: Logger
    private var agent: String = ""
    private var currentTask: Task<Void, Never>?

    init(config: DaemonConfig, log: Logger) {
        self.config = config
        self.log = log
    }

    func run(inbound: WebSocketInboundStream, outbound: WebSocketOutboundWriter) async {
        do {
            try await send(.banner(.init(
                protocolVersion: ProtocolVersion.current,
                daemonVersion: DaemonVersion.current,
                agent: "",
                hostname: ProcessInfo.processInfo.hostName
            )), via: outbound)

            for try await message in inbound.messages(maxSize: 64 * 1024) {
                guard case .text(let text) = message else { continue }
                let msg: ClientMessage
                do {
                    msg = try WireCodec.decode(ClientMessage.self, from: text)
                } catch {
                    try await send(.error(.init(code: "protocol.decode", message: "\(error)")), via: outbound)
                    continue
                }
                await handle(msg, outbound: outbound)
            }
        } catch {
            log.warning("session ended: \(error)")
        }
        currentTask?.cancel()
    }

    private func handle(_ msg: ClientMessage, outbound: WebSocketOutboundWriter) async {
        switch msg {
        case .start(let p):
            guard config.allowedAgents.contains(p.agent) else {
                try? await send(.error(.init(code: "agent.notAllowed", message: "agent '\(p.agent)' not in allowlist")), via: outbound)
                return
            }
            agent = p.agent
            try? await send(.output(.init(stream: .stdout, data: "[watchcli] agent=\(p.agent) ready\n")), via: outbound)

        case .input(let p):
            guard !agent.isEmpty else {
                try? await send(.error(.init(code: "session.notStarted", message: "send `start` first")), via: outbound)
                return
            }
            let line = p.data.trimmingCharacters(in: .newlines)
            guard !line.isEmpty else { return }
            currentTask?.cancel()
            let runner = CommandRunner(shellPath: config.shellPath)
            let argv = runner.command(for: agent, line: line)
            currentTask = Task { [weak self] in
                guard let self else { return }
                for await event in runner.run(argv) {
                    if Task.isCancelled { break }
                    switch event {
                    case .stdout(let s): try? await self.send(.output(.init(stream: .stdout, data: s)), via: outbound)
                    case .stderr(let s): try? await self.send(.output(.init(stream: .stderr, data: s)), via: outbound)
                    case .exit(let code):
                        try? await self.send(.output(.init(stream: .stdout, data: "\n[exit \(code)]\n")), via: outbound)
                    }
                }
            }

        case .resize:
            // No-op until P6 (PTY).
            break

        case .signal:
            currentTask?.cancel()

        case .ping(let id):
            try? await send(.pong(id: id), via: outbound)

        case .stop:
            currentTask?.cancel()
        }
    }

    private func send(_ message: ServerMessage, via outbound: WebSocketOutboundWriter) async throws {
        let json = try WireCodec.encode(message)
        try await outbound.write(.text(json))
    }
}
