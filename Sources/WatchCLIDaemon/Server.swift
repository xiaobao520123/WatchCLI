import Foundation
import Hummingbird
import HummingbirdWebSocket
import Logging
import WatchCLIProtocol

public enum DaemonVersion {
    public static let current = "0.2.0"
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
        onUpgrade: { inbound, outbound, _ in
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
    private var spec: AgentSpec?
    private var pty: PTYProcess?
    private var pumpTask: Task<Void, Never>?
    private var oneshotTask: Task<Void, Never>?

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
        await cleanup()
    }

    private func cleanup() async {
        pumpTask?.cancel(); pumpTask = nil
        oneshotTask?.cancel(); oneshotTask = nil
        if let pty {
            pty.signal(SIGHUP)
            _ = await pty.waitForExit()
        }
        pty = nil
    }

    private func handle(_ msg: ClientMessage, outbound: WebSocketOutboundWriter) async {
        switch msg {
        case .start(let p):
            guard config.allowedAgents.contains(p.agent) else {
                try? await send(.error(.init(code: "agent.notAllowed", message: "agent '\(p.agent)' not in allowlist")), via: outbound)
                return
            }
            let registry = BuiltInAgents.registry(shellPath: config.shellPath)
            guard let spec = registry[p.agent] else {
                try? await send(.error(.init(code: "agent.unknown", message: "no such agent '\(p.agent)'")), via: outbound)
                return
            }
            self.spec = spec

            switch spec.mode {
            case .oneshot:
                try? await send(.output(.init(stream: .stdout, data: "[watchcli] agent=\(spec.name) (oneshot) ready\n")), via: outbound)
            case .pty:
                await startPTY(spec: spec, cols: p.cols, rows: p.rows, env: p.env, outbound: outbound)
            }

        case .input(let p):
            guard let spec else {
                try? await send(.error(.init(code: "session.notStarted", message: "send `start` first")), via: outbound)
                return
            }
            switch spec.mode {
            case .oneshot: await runOneshot(spec: spec, line: p.data, outbound: outbound)
            case .pty:     try? pty?.write(Data(p.data.utf8))
            }

        case .resize(let r):
            pty?.resize(cols: r.cols, rows: r.rows)

        case .signal(let s):
            if let pty {
                pty.signal(s.signal)
            } else {
                oneshotTask?.cancel()
            }

        case .ping(let id):
            try? await send(.pong(id: id), via: outbound)

        case .stop:
            await cleanup()
        }
    }

    private func runOneshot(spec: AgentSpec, line: String, outbound: WebSocketOutboundWriter) async {
        let trimmed = line.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return }
        oneshotTask?.cancel()
        let runner = CommandRunner(shellPath: config.shellPath)
        let argv = spec.argv + [trimmed]
        oneshotTask = Task { [weak self] in
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
    }

    private func startPTY(spec: AgentSpec, cols: UInt16, rows: UInt16, env: [String: String]?, outbound: WebSocketOutboundWriter) async {
        do {
            // Inherit a sensible TERM if the client didn't specify one.
            var environment = ProcessInfo.processInfo.environment
            if let env { environment.merge(env, uniquingKeysWith: { $1 }) }
            if environment["TERM"] == nil { environment["TERM"] = "xterm-256color" }

            let executable = spec.argv[0]
            let arguments  = Array(spec.argv.dropFirst())
            let pty = try PTYProcess.spawn(
                executable: executable, arguments: arguments,
                environment: environment, cols: cols, rows: rows
            )
            self.pty = pty

            // Pump stdout: PTY → outbound `output` messages.
            pumpTask = Task { [weak self, log] in
                guard let self else { return }
                for await chunk in pty.read() {
                    let text = String(decoding: chunk, as: UTF8.self)
                    try? await self.send(.output(.init(stream: .stdout, data: text)), via: outbound)
                }
                let code = await pty.waitForExit()
                log.info("pty child exited code=\(code)")
                try? await self.send(.exit(.init(code: code)), via: outbound)
            }
        } catch {
            try? await send(.error(.init(code: "pty.spawn", message: "\(error)")), via: outbound)
        }
    }

    private func send(_ message: ServerMessage, via outbound: WebSocketOutboundWriter) async throws {
        let json = try WireCodec.encode(message)
        try await outbound.write(.text(json))
    }
}
