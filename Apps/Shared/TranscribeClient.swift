import Foundation
import WatchCLIProtocol

/// HTTP client to the daemon's `POST /v1/transcribe` endpoint. Hands the
/// audio off to the daemon, which proxies to OpenAI Whisper using its
/// locally-stored API key.
public struct TranscribeClient: Sendable {
    public let endpoint: Endpoint

    public init(endpoint: Endpoint) {
        self.endpoint = endpoint
    }

    public func transcribe(_ audio: Data) async throws -> String {
        var url = endpoint.url
        // /v1/session → /v1/transcribe (replace path), and ws[s]:// → http[s]://.
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            var c = comps
            c.scheme = (c.scheme == "wss") ? "https" : "http"
            c.path  = "/v1/transcribe"
            if let u = c.url { url = u }
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(endpoint.token)", forHTTPHeaderField: "Authorization")
        req.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30
        let (data, response) = try await URLSession.shared.upload(for: req, from: audio)
        guard let http = response as? HTTPURLResponse else { throw TranscribeError.bad("no http response") }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(decoding: data, as: UTF8.self)
            throw TranscribeError.bad("HTTP \(http.statusCode): \(body)")
        }
        struct Reply: Decodable { let text: String? ; let error: String? }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        if let text = reply.text { return text }
        throw TranscribeError.bad(reply.error ?? "no text in reply")
    }
}

public enum TranscribeError: Error, LocalizedError {
    case bad(String)
    public var errorDescription: String? {
        switch self { case .bad(let s): s }
    }
}
