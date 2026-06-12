import Foundation
import WatchCLIProtocol

/// Thin async wrapper around `URLSessionWebSocketTask` for the WatchCLI v1
/// protocol. Lives outside `MainActor` so the receive loop can run free of
/// UI updates; surface state changes back via the `events` async stream.
public actor DaemonClient {
    public enum Event: Sendable {
        case connected
        case message(ServerMessage)
        case disconnected(reason: String?)
    }

    private let endpoint: Endpoint
    private var task: URLSessionWebSocketTask?
    private var continuation: AsyncStream<Event>.Continuation?
    private var receiveLoop: Task<Void, Never>?

    public init(endpoint: Endpoint) {
        self.endpoint = endpoint
    }

    public func events() -> AsyncStream<Event> {
        AsyncStream { cont in
            self.continuation = cont
            cont.onTermination = { @Sendable _ in
                Task { await self.disconnect() }
            }
        }
    }

    public func connect() {
        guard task == nil else { return }
        var req = URLRequest(url: endpoint.url)
        req.timeoutInterval = 15
        req.setValue("Bearer \(endpoint.token)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .ephemeral)
        let t = session.webSocketTask(with: req)
        self.task = t
        t.resume()
        continuation?.yield(.connected)
        startReceiveLoop()
    }

    public func disconnect() {
        receiveLoop?.cancel()
        receiveLoop = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        continuation?.yield(.disconnected(reason: nil))
        continuation?.finish()
        continuation = nil
    }

    public func send(_ message: ClientMessage) async throws {
        guard let task else { throw DaemonClientError.notConnected }
        let json = try WireCodec.encode(message)
        try await task.send(.string(json))
    }

    private func startReceiveLoop() {
        receiveLoop = Task { [weak self] in
            guard let self else { return }
            await self.receiveForever()
        }
    }

    private func receiveForever() async {
        guard let task else { return }
        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                let text: String
                switch message {
                case .string(let s):  text = s
                case .data(let d):    text = String(decoding: d, as: UTF8.self)
                @unknown default:     continue
                }
                do {
                    let server = try WireCodec.decode(ServerMessage.self, from: text)
                    continuation?.yield(.message(server))
                } catch {
                    // ignore malformed frames; keep the connection alive
                }
            } catch {
                continuation?.yield(.disconnected(reason: "\(error)"))
                continuation?.finish()
                continuation = nil
                return
            }
        }
    }
}

public enum DaemonClientError: Error, LocalizedError {
    case notConnected
    public var errorDescription: String? {
        switch self {
        case .notConnected: "Not connected to the daemon."
        }
    }
}
