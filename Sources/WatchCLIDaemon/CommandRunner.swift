import Foundation

/// Runs a single shell command and streams stdout+stderr lines back to the
/// caller via an `AsyncStream`.
///
/// P2 scope: one-shot execution per `input` message. P6 will replace this
/// with a proper PTY-backed interactive session for `claude` / `copilot`.
public struct CommandRunner: Sendable {
    public enum Event: Sendable, Equatable {
        case stdout(String)
        case stderr(String)
        case exit(Int32)
    }

    public let shellPath: String

    public init(shellPath: String) {
        self.shellPath = shellPath
    }

    /// Resolve an agent name to a concrete command. The `shell` agent runs
    /// the user's input verbatim through `$SHELL -c`. Other agents are still
    /// shelled for now (they'll get PTY treatment in P6) so e.g. `claude`
    /// just becomes `claude <args>`.
    public func command(for agent: String, line: String) -> [String] {
        switch agent {
        case "shell":   return [shellPath, "-l", "-c", line]
        case "claude":  return [shellPath, "-l", "-c", "claude \(shellQuote(line))"]
        case "copilot": return [shellPath, "-l", "-c", "copilot \(shellQuote(line))"]
        default:        return [shellPath, "-l", "-c", line]
        }
    }

    /// Spawn the child and return an async stream of events. The returned
    /// stream completes after `.exit` is yielded.
    public func run(_ argv: [String]) -> AsyncStream<Event> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: argv[0])
            process.arguments = Array(argv.dropFirst())

            let outPipe = Pipe(), errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe
            process.standardInput = FileHandle.nullDevice

            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { handle.readabilityHandler = nil; return }
                if let s = String(data: data, encoding: .utf8) {
                    continuation.yield(.stdout(s))
                }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty { handle.readabilityHandler = nil; return }
                if let s = String(data: data, encoding: .utf8) {
                    continuation.yield(.stderr(s))
                }
            }

            process.terminationHandler = { p in
                // Drain anything readers may have missed.
                if let rest = try? outPipe.fileHandleForReading.readToEnd(),
                   !rest.isEmpty,
                   let s = String(data: rest, encoding: .utf8) {
                    continuation.yield(.stdout(s))
                }
                if let rest = try? errPipe.fileHandleForReading.readToEnd(),
                   !rest.isEmpty,
                   let s = String(data: rest, encoding: .utf8) {
                    continuation.yield(.stderr(s))
                }
                continuation.yield(.exit(p.terminationStatus))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                if process.isRunning { process.terminate() }
            }

            do {
                try process.run()
            } catch {
                continuation.yield(.stderr("watchcli-daemon: failed to spawn: \(error)\n"))
                continuation.yield(.exit(127))
                continuation.finish()
            }
        }
    }

    private func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
