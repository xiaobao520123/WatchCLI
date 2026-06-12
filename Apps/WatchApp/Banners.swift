import SwiftUI

/// Compact Copilot CLI splash. Replaces ASCII box borders with a real
/// rounded rectangle stroke so it stays crisp on the watch face.
struct CopilotBanner: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            CopilotMascot(lineHeight: 9, color: Theme.copilot)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.monoFixed(9).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Describe a task to get started.")
                    .font(Theme.monoFixed(8))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Text("Tip: /help · /skills")
                    .font(Theme.monoFixed(7))
                    .foregroundStyle(Theme.muted)
                Text("AI may make mistakes.")
                    .font(Theme.monoFixed(7))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Theme.copilot.opacity(0.6), lineWidth: 0.8)
        )
    }
}

/// Compact Claude Code style splash — pixel mascot + welcome line.
struct ClaudeBanner: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            PixelMascot(pixel: 2)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(Theme.monoFixed(9).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(Theme.monoFixed(8))
                    .foregroundStyle(Theme.muted)
                Text("Welcome back!")
                    .font(Theme.monoFixed(8))
                    .foregroundStyle(Color(red: 0.55, green: 0.83, blue: 0.55))
                Text("Run /init for CLAUDE.md")
                    .font(Theme.monoFixed(7))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Theme.accent.opacity(0.6), lineWidth: 0.8)
        )
    }
}

/// Plain shell banner.
struct ShellBanner: View {
    let hostname: String
    let agent: String
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Text("$_")
                    .font(Theme.monoFixed(11).weight(.bold))
                    .foregroundStyle(Theme.shellTone)
                Text("WatchCLI v\(DaemonClientInfo.appVersion)")
                    .font(Theme.monoFixed(9).weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Text("\(agent) · \(hostname)")
                .font(Theme.monoFixed(8))
                .foregroundStyle(Theme.muted)
                .lineLimit(1).truncationMode(.middle)
            Text("hold input to dictate · /help")
                .font(Theme.monoFixed(7))
                .foregroundStyle(Theme.muted)
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Theme.shellTone.opacity(0.6), lineWidth: 0.8)
        )
    }
}
