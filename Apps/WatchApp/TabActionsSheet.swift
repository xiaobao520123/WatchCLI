import SwiftUI

/// Bottom sheet that surfaces "advanced" tab actions. Triggered by the
/// `…` icon in the active tab chip (or by swiping up on the body in
/// future iterations). Matches the user's spec: close current CLI,
/// quick-pick from common commands, send signal, jump to settings.
struct TabActionsSheet: View {
    @EnvironmentObject var manager: SessionManager
    let session: SessionViewModel
    let agent: String
    @Binding var presented: Bool
    var onPickCommand: (String) -> Void

    /// Useful commands depending on the active agent. Subset of the full
    /// catalog plus a few raw shell commands when the agent is shell-like.
    private var quickCommands: [String] {
        switch agent {
        case "claude":  return ["/help", "/init", "/clear", "/compact", "/cost", "/model"]
        case "copilot": return ["/help", "/login", "/clear", "/skills", "/model", "/usage"]
        case "shell":   return ["ls", "pwd", "git status", "uptime", "df -h", "uname -a"]
        case "oneshot": return ["ls", "pwd", "git status", "uptime"]
        default:        return ["/help"]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tab actions")
                    .font(Theme.monoFixed(10).weight(.semibold))
                    .foregroundStyle(Theme.accent)

                Section {
                    Button {
                        session.interrupt(); presented = false
                    } label: {
                        Label("Interrupt (^C)", systemImage: "stop.fill")
                            .font(Theme.monoFixed(8))
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)

                    Button(role: .destructive) {
                        if let id = manager.tabs.first(where: { $0.sessionVM === session })?.id {
                            manager.close(id)
                        }
                        presented = false
                    } label: {
                        Label("Close tab", systemImage: "xmark.circle.fill")
                            .font(Theme.monoFixed(8))
                    }
                    .buttonStyle(.bordered)
                }

                Text("QUICK COMMANDS")
                    .font(.caption2)
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 4)
                ForEach(quickCommands, id: \.self) { cmd in
                    Button {
                        onPickCommand(cmd); presented = false
                    } label: {
                        HStack {
                            Text(cmd)
                                .font(Theme.monoFixed(8))
                                .foregroundStyle(cmd.hasPrefix("/") ? Theme.prompt : Theme.shellTone)
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.surface))
                    }
                    .buttonStyle(.plain)
                }

                Button("Cancel") { presented = false }
                    .font(Theme.monoFixed(8))
                    .padding(.top, 6)
            }
            .padding(8)
        }
        .containerBackground(Theme.background, for: .navigation)
    }
}
