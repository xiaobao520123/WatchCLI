import Foundation
import SwiftUI
import WatchCLIProtocol

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

/// MainActor view-model owned by the watchOS app. Mediates between the
/// `DaemonClient` and SwiftUI views.
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

    public init() {}

    public func select(_ endpoint: Endpoint?) {
        selectedEndpointID = endpoint?.id
        Task { await disconnect() }
        guard let endpoint else { return }
        connect(to: endpoint)
    }

    public func connect(to endpoint: Endpoint) {
        Task { [weak self] in await self?.connectAsync(to: endpoint) }
    }

    public func send(line raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        appendLine(.init(text: "$ \(text)", kind: .prompt))
        Task { [weak self] in
            guard let self, let client = await self.currentClient() else { return }
            try? await client.send(.input(.init(data: text + "\n")))
        }
    }

    public func disconnect() async {
        pumpTask?.cancel()
        pumpTask = nil
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
        await disconnect()
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
        case .disconnected(let reason):
            state = .disconnected(reason)
            for c in stdoutSplitter.flush(kind: .stdout) { appendLine(.init(chunk: c)) }
            for c in stderrSplitter.flush(kind: .stderr) { appendLine(.init(chunk: c)) }
            appendLine(.init(text: "✗ disconnected\(reason.map { " (\($0))" } ?? "")", kind: .system))
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
        case .pong:
            break
        }
    }

    private func appendLine(_ line: TerminalLine) {
        lines.append(line)
        if lines.count > 500 { lines.removeFirst(lines.count - 500) }
    }
}
