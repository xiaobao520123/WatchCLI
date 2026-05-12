import Foundation

/// One slash-command exposed in the Compose palette and the Welcome view.
/// Mirrors the catalogue you see in real `claude` / `copilot` CLIs.
public struct SlashCommand: Identifiable, Hashable, Sendable {
    public let id: String         // e.g. "/help"
    public let description: String
    public let kind: Kind
    public enum Kind: String, Sendable { case local, agent }

    public init(_ id: String, _ description: String, _ kind: Kind = .agent) {
        self.id = id; self.description = description; self.kind = kind
    }
}

/// The default catalogue. `local` commands are handled on the watch itself
/// (no daemon round-trip); `agent` commands are forwarded as input lines.
public enum SlashCatalog {
    public static let all: [SlashCommand] = [
        .init("/help",     "Show this command list",                       .local),
        .init("/clear",    "Clear conversation history (reset, new)",      .local),
        .init("/disconnect","Disconnect from the active server",           .local),
        .init("/reconnect","Force-reconnect to the active server",         .local),
        .init("/add-dir",  "Add a new working directory"),
        .init("/agents",   "Manage agent configurations"),
        .init("/bashes",   "List and manage background tasks"),
        .init("/compact",  "Summarize history but keep context"),
        .init("/cost",     "Show current session cost"),
        .init("/login",    "Log in / refresh API credentials"),
        .init("/model",    "Pick the active model"),
        .init("/init",     "Create a CLAUDE.md / COPILOT.md file"),
    ]

    /// Subset shown by default in the welcome panel (most useful, fits the
    /// small screen).
    public static let welcomeSubset: [SlashCommand] = [
        all.first(where: { $0.id == "/add-dir" })!,
        all.first(where: { $0.id == "/agents" })!,
        all.first(where: { $0.id == "/bashes" })!,
        all.first(where: { $0.id == "/clear" })!,
        all.first(where: { $0.id == "/compact" })!,
    ]

    public static func match(prefix: String) -> [SlashCommand] {
        let p = prefix.lowercased()
        guard p.hasPrefix("/") else { return [] }
        return all.filter { $0.id.lowercased().hasPrefix(p) }
    }
}
