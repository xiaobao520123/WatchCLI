import Foundation

/// Describes one runnable agent: a name, what to execute, and whether it
/// should be driven as a one-shot per `input` message or as a long-lived
/// interactive PTY child.
public struct AgentSpec: Sendable {
    public enum Mode: String, Sendable { case oneshot, pty }

    public var name: String
    public var mode: Mode
    /// Command argv. For `oneshot`, the user's input is appended as the last
    /// argument. For `pty`, this is the full argv to spawn at session start.
    public var argv: [String]

    public init(name: String, mode: Mode, argv: [String]) {
        self.name = name; self.mode = mode; self.argv = argv
    }
}

/// Built-in agent catalogue. The `shell`, `claude`, `copilot` agents all
/// run inside a PTY for proper interactive UX. `oneshot` keeps the simpler
/// non-interactive mode used by the integration tests and trivial commands.
public enum BuiltInAgents {
    public static func registry(shellPath: String) -> [String: AgentSpec] {
        [
            "shell": AgentSpec(
                name: "shell", mode: .pty,
                argv: [shellPath, "-i"]
            ),
            "claude": AgentSpec(
                name: "claude", mode: .pty,
                argv: [shellPath, "-l", "-i", "-c", "claude"]
            ),
            "copilot": AgentSpec(
                name: "copilot", mode: .pty,
                argv: [shellPath, "-l", "-i", "-c", "copilot"]
            ),
            "oneshot": AgentSpec(
                name: "oneshot", mode: .oneshot,
                argv: [shellPath, "-l", "-c"]
            ),
        ]
    }
}
