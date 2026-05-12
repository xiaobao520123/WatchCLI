import SwiftUI

/// ASCII art splash banner mirroring the GitHub Copilot CLI welcome screen
/// (extracted from the live `copilot` binary). Rendered in monospaced font
/// so the box-drawing aligns. Used in the empty/welcome state of a tab.
struct CopilotBanner: View {
    let title: String              // e.g. "Copilot CLI v0.1"
    let subtitle: String           // e.g. "GPT · GitHub Copilot"
    let body1: [String] = [
        "┌──                                ──┐",
        "│                  ▄▄▄▄▄▄▄▄          │",
        "    Welcome to G▄▄███████████▄▄▄    ",
        "    █████┐ ███▌██████████████▀▀▀▀█  ",
        "   ██┌───┘██┌─▐███████████████  ▐▌  ",
        "   ██│    ██│ ▐████████████████ ▐▌  ",
        "   ██│    ██│  ████▄     █▄  ▀▀▀█▌  ",
        "   └█████┐└████│▀██████████   ▐ ▌   ",
        "    └────┘ └───┘  ▀███████▄    ▐    ",
        "│ - -                ▀███████▄▄▌    │",
        "└──|                     ▀▀▀▀▀▀   ──┘",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                Text(title)
                    .font(Theme.monoFixed(10).weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
            }
            Text(subtitle)
                .font(Theme.monoFixed(9))
                .foregroundStyle(Theme.muted)
                .padding(.bottom, 2)
            ForEach(body1, id: \.self) { line in
                Text(line)
                    .font(Theme.monoFixed(7))
                    .foregroundStyle(Theme.copilot)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

/// Compact Claude Code style splash — pixel mascot + welcome line. Used
/// when the active agent is `claude`.
struct ClaudeBanner: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title)
                    .font(Theme.monoFixed(10).weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Spacer()
            }
            Text(subtitle)
                .font(Theme.monoFixed(9))
                .foregroundStyle(Theme.muted)
            HStack(alignment: .center, spacing: 8) {
                PixelMascot(pixel: 3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Welcome back!")
                        .font(Theme.monoFixed(9))
                        .foregroundStyle(Color(red: 0.55, green: 0.83, blue: 0.55))
                    Text("Run /init to create CLAUDE.md")
                        .font(Theme.monoFixed(8))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

/// Plain shell banner used when the agent is `shell` / `oneshot`.
struct ShellBanner: View {
    let hostname: String
    let agent: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text("WatchCLI")
                    .font(Theme.monoFixed(10).weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("v\(DaemonClientInfo.appVersion)")
                    .font(Theme.monoFixed(9))
                    .foregroundStyle(Theme.muted)
                Spacer()
            }
            Text("\(agent) · \(hostname)")
                .font(Theme.monoFixed(9))
                .foregroundStyle(Theme.muted)
            Text("type /help for commands, or speak with mic.")
                .font(Theme.monoFixed(8))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
        }
    }
}
