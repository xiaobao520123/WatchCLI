import Foundation
import SwiftUI
import WatchCLIProtocol
#if os(watchOS)
import WatchKit
#endif

/// SwiftUI-side line model: a chunk + a UUID for ForEach + a Color binding.
public struct TerminalLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let chunk: TerminalLineChunk

    public init(id: UUID = UUID(), chunk: TerminalLineChunk) {
        self.id = id; self.chunk = chunk
    }
    public init(text: String, kind: TerminalLineKind) {
        self.init(chunk: .init(text: text, kind: kind))
    }
    public var text: String { chunk.text }
    public var kind: TerminalLineKind { chunk.kind }
    public var color: Color {
        switch chunk.kind {
        case .stdout: Theme.textPrimary
        case .stderr: Color(red: 1.00, green: 0.55, blue: 0.45)
        case .system: Theme.muted
        case .prompt: Theme.prompt
        }
    }
}

/// Plays a haptic on watchOS; no-op elsewhere.
@MainActor
enum Haptics {
    static func play(_ type: HapticType) {
        #if os(watchOS)
        WKInterfaceDevice.current().play(type.wkType)
        #endif
    }
    enum HapticType {
        case click, success, failure, notification
        #if os(watchOS)
        var wkType: WKHapticType {
            switch self {
            case .click:        .click
            case .success:      .success
            case .failure:      .failure
            case .notification: .notification
            }
        }
        #endif
    }
}

/// MainActor view-model owned by the watchOS app. Mediates between the
/// `DaemonClient` and SwiftUI views, owns reconnect/backoff and haptics.
@MainActor
public final class SessionViewModel: ObservableObject {
    public enum State: Equatable, Sendable { case idle, connecting, connected, disconnected(String?) }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var lines: [TerminalLine] = []
    @Published public private(set) var selectedEndpointID: UUID?
    @Published public private(set) var bannerHostname: String = ""

    private var client: DaemonClient?
    private var stdoutSplitter = LineSplitter()
    private var stderrSplitter = LineSplitter()
    private var pumpTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    public private(set) var currentEndpoint: Endpoint?
    private var reconnectAttempt = 0
    private var userInitiatedDisconnect = false

    public init() {}

    public func select(_ endpoint: Endpoint?) {
        selectedEndpointID = endpoint?.id
        Task { await disconnect() }
        guard let endpoint else { return }
        connect(to: endpoint)
    }

    public func connect(to endpoint: Endpoint) {
        currentEndpoint = endpoint
        userInitiatedDisconnect = false
        reconnectAttempt = 0
        Task { [weak self] in await self?.connectAsync(to: endpoint) }
    }

    public func send(line raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Haptics.play(.click)
        // Local slash commands short-circuit before going to the wire.
        if let cmd = SlashCatalog.all.first(where: { $0.id == text }), cmd.kind == .local {
            handleLocalSlash(cmd)
            return
        }
        appendLine(.init(text: "$ \(text)", kind: .prompt))
        Task { [weak self] in
            guard let self, let client = await self.currentClient() else { return }
            try? await client.send(.input(.init(data: text + "\n")))
        }
    }

    private func handleLocalSlash(_ cmd: SlashCommand) {
        switch cmd.id {
        case "/help":
            appendLine(.init(text: "$ /help", kind: .prompt))
            for c in SlashCatalog.all {
                appendLine(.init(text: "  \(c.id.padding(toLength: 12, withPad: " ", startingAt: 0))\(c.description)", kind: .system))
            }
        case "/clear":
            clear()
        case "/disconnect":
            appendLine(.init(text: "$ /disconnect", kind: .prompt))
            Task { await disconnect() }
        case "/reconnect":
            appendLine(.init(text: "$ /reconnect", kind: .prompt))
            if let endpoint = currentEndpoint {
                connect(to: endpoint)
            } else {
                appendLine(.init(text: "✗ no endpoint selected", kind: .stderr))
            }
        default:
            // Non-local but somehow got here — fall back to wire.
            appendLine(.init(text: "$ \(cmd.id)", kind: .prompt))
            Task { try? await self.client?.send(.input(.init(data: cmd.id + "\n"))) }
        }
    }

    /// Sends an interrupt (^C) to the active session.
    public func interrupt() {
        Haptics.play(.click)
        Task { [weak self] in
            guard let self, let client = await self.currentClient() else { return }
            try? await client.send(.signal(.init(signal: 2)))
        }
    }

    public func disconnect() async {
        userInitiatedDisconnect = true
        reconnectTask?.cancel(); reconnectTask = nil
        pumpTask?.cancel(); pumpTask = nil
        await client?.disconnect()
        client = nil
        if case .connected = state { state = .disconnected(nil) }
    }

    public func clear() {
        lines.removeAll()
        stdoutSplitter = LineSplitter()
        stderrSplitter = LineSplitter()
    }

    // MARK: - Internal

    private func currentClient() async -> DaemonClient? { client }

    private func connectAsync(to endpoint: Endpoint) async {
        // Tear down any prior session without flipping userInitiatedDisconnect.
        let wasUserInitiated = userInitiatedDisconnect
        pumpTask?.cancel(); pumpTask = nil
        await client?.disconnect()
        client = nil
        userInitiatedDisconnect = wasUserInitiated

        let c = DaemonClient(endpoint: endpoint)
        self.client = c
        self.state = .connecting
        appendLine(.init(text: "→ connecting to \(endpoint.name)…", kind: .system))

        let stream = await c.events()
        await c.connect()
        try? await c.send(.start(.init(agent: endpoint.defaultAgent)))

        pumpTask = Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await self.apply(event)
            }
        }
    }

    private func apply(_ event: DaemonClient.Event) async {
        switch event {
        case .connected:
            state = .connected
            reconnectAttempt = 0
            Haptics.play(.success)
        case .disconnected(let reason):
            state = .disconnected(reason)
            for c in stdoutSplitter.flush(kind: .stdout) { appendLine(.init(chunk: c)) }
            for c in stderrSplitter.flush(kind: .stderr) { appendLine(.init(chunk: c)) }
            appendLine(.init(text: "✗ disconnected\(reason.map { " (\($0))" } ?? "")", kind: .system))
            Haptics.play(.failure)
            scheduleReconnectIfNeeded()
        case .message(let m):
            applyServerMessage(m)
        }
    }

    private func applyServerMessage(_ m: ServerMessage) {
        switch m {
        case .banner(let p):
            bannerHostname = p.hostname
            appendLine(.init(text: "✓ \(p.hostname) · daemon \(p.daemonVersion)", kind: .system))
        case .output(let p):
            switch p.stream {
            case .stdout: for c in stdoutSplitter.feed(p.data, kind: .stdout) { appendLine(.init(chunk: c)) }
            case .stderr: for c in stderrSplitter.feed(p.data, kind: .stderr) { appendLine(.init(chunk: c)) }
            }
        case .error(let p):
            appendLine(.init(text: "! \(p.code): \(p.message)", kind: .stderr))
        case .exit(let p):
            appendLine(.init(text: "[exit \(p.code)]", kind: .system))
            Haptics.play(.notification)
        case .pong:
            break
        }
    }

    private func scheduleReconnectIfNeeded() {
        guard !userInitiatedDisconnect, let endpoint = currentEndpoint else { return }
        reconnectAttempt = min(reconnectAttempt + 1, 6)
        // 1s, 2s, 4s, 8s, 16s, 30s (capped).
        let delaySeconds = min(30.0, pow(2.0, Double(reconnectAttempt - 1)))
        appendLine(.init(text: "↻ reconnect in \(Int(delaySeconds))s (attempt \(reconnectAttempt))", kind: .system))
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delaySeconds))
            guard let self, !Task.isCancelled else { return }
            await self.connectAsync(to: endpoint)
        }
    }

    private func appendLine(_ line: TerminalLine) {
        lines.append(line)
        if lines.count > 500 { lines.removeFirst(lines.count - 500) }
    }
}
