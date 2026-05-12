import SwiftUI
import WatchCLIProtocol

/// Splash / idle view shown in the Terminal tab when there's no live output
/// yet. Mirrors the Claude Code v2 welcome layout: orange-bordered panel,
/// pixel mascot, current model + cwd, Tips for getting started, Recent
/// activity, then a cyan `= /` prompt followed by the slash-command palette.
struct WelcomeView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var store: EndpointStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header strip: "claude/copilot v0.1"
            HStack(spacing: 4) {
                Text("WatchCLI")
                    .font(Theme.mono(.caption))
                    .foregroundStyle(Theme.accent)
                Text("v\(DaemonClientInfo.appVersion)")
                    .font(Theme.mono(.caption2))
                    .foregroundStyle(Theme.muted)
                Spacer()
            }

            // Welcome line
            Text("Welcome back, \(NSUserName().isEmpty ? "wrist" : NSUserName())!")
                .font(Theme.mono(.footnote))
                .foregroundStyle(Color(red: 0.55, green: 0.83, blue: 0.55))   // soft green

            HStack(alignment: .top, spacing: 8) {
                // Mascot + meta column
                VStack(alignment: .leading, spacing: 4) {
                    PixelMascot(pixel: 3)
                    Text(activeAgentLabel)
                        .font(Theme.mono(.caption2))
                        .foregroundStyle(Theme.muted)
                    Text(hostLabel)
                        .font(Theme.mono(.caption2))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Divider().background(Theme.accent.opacity(0.5))
                // Tips + recent activity
                VStack(alignment: .leading, spacing: 6) {
                    sectionHeader("Tips")
                    Text("Tap mic to dictate, or pick a /command below.")
                        .font(.caption2)
                        .foregroundStyle(Theme.textPrimary)
                    sectionHeader("Recent")
                    Text(recentActivity)
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.accent, lineWidth: 1)
            )

            // Prompt line
            HStack(spacing: 4) {
                Text("=").foregroundStyle(Theme.prompt)
                Text("/").foregroundStyle(Theme.prompt)
                Spacer()
            }
            .font(Theme.mono(.footnote))
            .padding(.top, 2)

            // Slash command palette (two columns)
            VStack(alignment: .leading, spacing: 2) {
                ForEach(SlashCatalog.welcomeSubset) { cmd in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(cmd.id)
                            .font(Theme.mono(.caption2))
                            .foregroundStyle(Theme.prompt)
                        Text(cmd.description)
                            .font(.caption2)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    // MARK: - Strings

    private var activeAgentLabel: String {
        let agent = currentEndpoint?.defaultAgent ?? "shell"
        let model: String = {
            switch agent {
            case "claude":  "Sonnet · Claude"
            case "copilot": "GPT · Copilot"
            case "shell":   "zsh · Shell"
            default:        "—"
            }
        }()
        return model
    }

    private var hostLabel: String {
        if !session.bannerHostname.isEmpty { return session.bannerHostname }
        if let host = currentEndpoint?.url.host() { return host }
        return "(no host)"
    }

    private var recentActivity: String {
        let count = session.lines.filter { $0.kind == .prompt }.count
        return count == 0 ? "No recent activity" : "\(count) command\(count == 1 ? "" : "s") this session"
    }

    private var currentEndpoint: Endpoint? {
        guard let id = session.selectedEndpointID else { return store.endpoints.first }
        return store.endpoints.first(where: { $0.id == id })
    }

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Theme.accent)
    }
}

/// Tiny helper for surfacing the bundle version into the welcome view.
enum DaemonClientInfo {
    static var appVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.1.0"
    }
}