import Foundation

// MARK: - Wire protocol (v1)
//
// The watch and the daemon exchange JSON-encoded messages over a single
// WebSocket. Each message carries a `type` discriminator so the protocol can
// evolve without breaking older clients.
//
// All payloads are intentionally small and Codable-only; this module has no
// platform dependencies so it can be linked into watchOS, iOS, macOS and
// (future) Linux builds.

public enum ProtocolVersion {
    public static let current = "1"
}

// MARK: Client -> Server

public enum ClientMessage: Codable, Equatable, Sendable {
    /// Open a new agent session (shell, claude, copilot, ...).
    case start(StartPayload)
    /// Raw stdin chunk for the running session.
    case input(InputPayload)
    /// PTY resize.
    case resize(ResizePayload)
    /// Send a UNIX signal (e.g. SIGINT to interrupt).
    case signal(SignalPayload)
    /// Liveness check.
    case ping(id: UInt64)
    /// Cleanly stop the session.
    case stop

    public struct StartPayload: Codable, Equatable, Sendable {
        public var agent: String                // "shell", "claude", "copilot", ...
        public var cols: UInt16
        public var rows: UInt16
        public var env: [String: String]?
        public init(agent: String, cols: UInt16 = 80, rows: UInt16 = 24, env: [String: String]? = nil) {
            self.agent = agent; self.cols = cols; self.rows = rows; self.env = env
        }
    }
    public struct InputPayload: Codable, Equatable, Sendable {
        public var data: String                 // utf-8 text; control chars allowed
        public init(data: String) { self.data = data }
    }
    public struct ResizePayload: Codable, Equatable, Sendable {
        public var cols: UInt16; public var rows: UInt16
        public init(cols: UInt16, rows: UInt16) { self.cols = cols; self.rows = rows }
    }
    public struct SignalPayload: Codable, Equatable, Sendable {
        public var signal: Int32                // POSIX signal number
        public init(signal: Int32) { self.signal = signal }
    }

    private enum CodingKeys: String, CodingKey { case type, payload, id }
    private enum Kind: String, Codable { case start, input, resize, signal, ping, stop }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .start(let p):  try c.encode(Kind.start, forKey: .type);  try c.encode(p, forKey: .payload)
        case .input(let p):  try c.encode(Kind.input, forKey: .type);  try c.encode(p, forKey: .payload)
        case .resize(let p): try c.encode(Kind.resize, forKey: .type); try c.encode(p, forKey: .payload)
        case .signal(let p): try c.encode(Kind.signal, forKey: .type); try c.encode(p, forKey: .payload)
        case .ping(let id):  try c.encode(Kind.ping, forKey: .type);   try c.encode(id, forKey: .id)
        case .stop:          try c.encode(Kind.stop, forKey: .type)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .start:  self = .start(try c.decode(StartPayload.self, forKey: .payload))
        case .input:  self = .input(try c.decode(InputPayload.self, forKey: .payload))
        case .resize: self = .resize(try c.decode(ResizePayload.self, forKey: .payload))
        case .signal: self = .signal(try c.decode(SignalPayload.self, forKey: .payload))
        case .ping:   self = .ping(id: try c.decode(UInt64.self, forKey: .id))
        case .stop:   self = .stop
        }
    }
}

// MARK: Server -> Client

public enum ServerMessage: Codable, Equatable, Sendable {
    case banner(BannerPayload)              // sent once after start
    case output(OutputPayload)              // stdout/stderr chunk
    case exit(ExitPayload)                  // process ended
    case error(ErrorPayload)                // protocol or runtime error
    case pong(id: UInt64)

    public struct BannerPayload: Codable, Equatable, Sendable {
        public var protocolVersion: String
        public var daemonVersion: String
        public var agent: String
        public var hostname: String
        public init(protocolVersion: String, daemonVersion: String, agent: String, hostname: String) {
            self.protocolVersion = protocolVersion; self.daemonVersion = daemonVersion
            self.agent = agent; self.hostname = hostname
        }
    }
    public struct OutputPayload: Codable, Equatable, Sendable {
        public enum Stream: String, Codable, Sendable { case stdout, stderr }
        public var stream: Stream
        public var data: String             // utf-8; may contain ANSI escapes
        public init(stream: Stream = .stdout, data: String) { self.stream = stream; self.data = data }
    }
    public struct ExitPayload: Codable, Equatable, Sendable {
        public var code: Int32
        public init(code: Int32) { self.code = code }
    }
    public struct ErrorPayload: Codable, Equatable, Sendable {
        public var code: String             // machine-readable, e.g. "auth.invalid"
        public var message: String
        public init(code: String, message: String) { self.code = code; self.message = message }
    }

    private enum CodingKeys: String, CodingKey { case type, payload, id }
    private enum Kind: String, Codable { case banner, output, exit, error, pong }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .banner(let p): try c.encode(Kind.banner, forKey: .type); try c.encode(p, forKey: .payload)
        case .output(let p): try c.encode(Kind.output, forKey: .type); try c.encode(p, forKey: .payload)
        case .exit(let p):   try c.encode(Kind.exit, forKey: .type);   try c.encode(p, forKey: .payload)
        case .error(let p):  try c.encode(Kind.error, forKey: .type);  try c.encode(p, forKey: .payload)
        case .pong(let id):  try c.encode(Kind.pong, forKey: .type);   try c.encode(id, forKey: .id)
        }
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .banner: self = .banner(try c.decode(BannerPayload.self, forKey: .payload))
        case .output: self = .output(try c.decode(OutputPayload.self, forKey: .payload))
        case .exit:   self = .exit(try c.decode(ExitPayload.self, forKey: .payload))
        case .error:  self = .error(try c.decode(ErrorPayload.self, forKey: .payload))
        case .pong:   self = .pong(id: try c.decode(UInt64.self, forKey: .id))
        }
    }
}

// MARK: - Codec helpers

public enum WireCodec {
    public static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.outputFormatting = [.withoutEscapingSlashes]; return e
    }()
    public static let decoder = JSONDecoder()

    public static func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
    public static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        try decoder.decode(type, from: Data(text.utf8))
    }
}

// MARK: - Built-in agents

public enum BuiltInAgent: String, CaseIterable, Sendable {
    case shell, claude, copilot
    public var displayName: String {
        switch self {
        case .shell:   "Shell"
        case .claude:  "Claude Code"
        case .copilot: "Copilot CLI"
        }
    }
}
