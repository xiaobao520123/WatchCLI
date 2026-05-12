import Foundation

/// Daemon runtime configuration.
public struct DaemonConfig: Sendable {
    public var host: String
    public var port: Int
    public var shellPath: String          // for the `shell` agent
    public var allowedAgents: Set<String> // names whitelist
    public var tokenFilePath: String

    public static let `default` = DaemonConfig(
        host: "127.0.0.1",
        port: 8765,
        shellPath: ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh",
        allowedAgents: ["shell", "claude", "copilot", "oneshot"],
        tokenFilePath: defaultTokenFilePath()
    )

    public static func defaultTokenFilePath() -> String {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? "/tmp"
        return "\(home)/.config/watchcli/token"
    }

    /// Very small hand-rolled arg parser. Supports `--host`, `--port`,
    /// `--shell`, `--token-file`, `--agents shell,claude` and `--help`.
    public static func parse(_ args: [String]) throws -> DaemonConfig {
        var c = DaemonConfig.default
        var i = 0
        while i < args.count {
            let a = args[i]
            func next() throws -> String {
                guard i + 1 < args.count else { throw ArgError.missingValue(a) }
                i += 1
                return args[i]
            }
            switch a {
            case "--host":       c.host = try next()
            case "--port":
                guard let p = Int(try next()), (1...65535).contains(p) else { throw ArgError.invalid("--port") }
                c.port = p
            case "--shell":      c.shellPath = try next()
            case "--token-file": c.tokenFilePath = try next()
            case "--agents":
                let v = try next()
                c.allowedAgents = Set(v.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) })
            case "-h", "--help": throw ArgError.helpRequested
            default: throw ArgError.unknown(a)
            }
            i += 1
        }
        return c
    }

    public enum ArgError: Error, CustomStringConvertible {
        case missingValue(String), invalid(String), unknown(String), helpRequested
        public var description: String {
            switch self {
            case .missingValue(let f): "missing value for \(f)"
            case .invalid(let f):      "invalid value for \(f)"
            case .unknown(let f):      "unknown option \(f)"
            case .helpRequested:       "help"
            }
        }
    }

    public static let helpText = """
    watchcli-daemon — bridge an Apple Watch to a shell or AI CLI

    USAGE:
      watchcli-daemon [OPTIONS]

    OPTIONS:
      --host <host>          Bind address (default 127.0.0.1)
      --port <port>          TCP port (default 8765)
      --shell <path>         Shell binary for the `shell` agent (default $SHELL)
      --agents <list>        Comma-separated list of allowed agents
                             (default shell,claude,copilot)
      --token-file <path>    Where to read/write the auth token
                             (default ~/.config/watchcli/token)
      -h, --help             Show this help

    The first launch generates a random bearer token and writes it to the
    token file. Copy it into the WatchCLI iPhone app.
    """
}
