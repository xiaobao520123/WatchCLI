import Foundation

/// Calls OpenAI Whisper for audio → text. The API key is read from the
/// `OPENAI_API_KEY` environment variable, or alternatively from
/// `~/.config/watchcli/openai-key`. If neither is present, transcription
/// is disabled (the watch surfaces a clear error).
public struct WhisperClient: Sendable {
    public let apiKey: String?
    public let model: String      // e.g. "whisper-1" or "gpt-4o-transcribe"
    public let endpoint: URL

    public static func loadDefault(env: [String: String] = ProcessInfo.processInfo.environment) -> WhisperClient {
        let key: String? = {
            if let v = env["OPENAI_API_KEY"], !v.isEmpty { return v }
            let path = (env["HOME"] ?? "/tmp") + "/.config/watchcli/openai-key"
            if let data = try? String(contentsOfFile: path, encoding: .utf8) {
                let s = data.trimmingCharacters(in: .whitespacesAndNewlines)
                return s.isEmpty ? nil : s
            }
            return nil
        }()
        let model = env["WATCHCLI_WHISPER_MODEL"] ?? "whisper-1"
        let url = URL(string: env["WATCHCLI_WHISPER_URL"] ?? "https://api.openai.com/v1/audio/transcriptions")!
        return WhisperClient(apiKey: key, model: model, endpoint: url)
    }

    /// Transcribe a chunk of audio (any container OpenAI accepts: m4a, wav,
    /// mp3, webm, ...). `filename` is only used for the multipart hint;
    /// the server detects the container from the bytes.
    public func transcribe(audio: Data, filename: String = "audio.m4a", language: String? = nil) async throws -> String {
        guard let apiKey, !apiKey.isEmpty else {
            throw WhisperError.notConfigured
        }
        let boundary = "----wcli\(UUID().uuidString)"
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = makeBody(boundary: boundary, audio: audio, filename: filename, language: language)
        req.timeoutInterval = 30

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw WhisperError.badResponse(0, "no http response") }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(decoding: data, as: UTF8.self)
            throw WhisperError.badResponse(http.statusCode, body.prefix(500).description)
        }
        struct Reply: Decodable { let text: String }
        let reply = try JSONDecoder().decode(Reply.self, from: data)
        return reply.text
    }

    private func makeBody(boundary: String, audio: Data, filename: String, language: String?) -> Data {
        var body = Data()
        func add(_ s: String) { body.append(Data(s.utf8)) }

        add("--\(boundary)\r\n")
        add("Content-Disposition: form-data; name=\"model\"\r\n\r\n\(model)\r\n")

        add("--\(boundary)\r\n")
        add("Content-Disposition: form-data; name=\"response_format\"\r\n\r\njson\r\n")

        if let language {
            add("--\(boundary)\r\n")
            add("Content-Disposition: form-data; name=\"language\"\r\n\r\n\(language)\r\n")
        }

        add("--\(boundary)\r\n")
        add("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        add("Content-Type: application/octet-stream\r\n\r\n")
        body.append(audio)
        add("\r\n--\(boundary)--\r\n")
        return body
    }
}

public enum WhisperError: Error, CustomStringConvertible {
    case notConfigured
    case badResponse(Int, String)
    public var description: String {
        switch self {
        case .notConfigured:    "OpenAI API key not configured (set OPENAI_API_KEY or write ~/.config/watchcli/openai-key)"
        case .badResponse(let code, let body): "Whisper HTTP \(code): \(body)"
        }
    }
}
