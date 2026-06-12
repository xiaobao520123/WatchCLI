import SwiftUI

/// Big bordered welcome panel matching the reference screenshot exactly:
///   - Title row: "<Brand> v<version>" in orange
///   - Greeting: "Welcome back!" in green
///   - Two-column body: pixel mascot + meta on left, "Tips" + "Recent" on right
struct WelcomePanel: View {
    let brand: String
    let model: String
    let cwd:   String
    let tips:  String
    let mascot: AnyView
    let toneColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(brand) v\(DaemonClientInfo.appVersion)")
                .font(Theme.monoFixed(9).weight(.semibold))
                .foregroundStyle(toneColor)
            Text("Welcome back!")
                .font(Theme.monoFixed(8).weight(.semibold))
                .foregroundStyle(Color(red: 0.55, green: 0.83, blue: 0.55))

            HStack(alignment: .top, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    mascot
                    Text(model)
                        .font(Theme.monoFixed(7))
                        .foregroundStyle(Theme.muted)
                    Text(cwd)
                        .font(Theme.monoFixed(7))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
                Rectangle()
                    .fill(toneColor.opacity(0.6))
                    .frame(width: 0.6)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tips")
                        .font(Theme.monoFixed(7).weight(.semibold))
                        .foregroundStyle(toneColor)
                    Text(tips)
                        .font(Theme.monoFixed(7))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(3)
                    Text("Recent")
                        .font(Theme.monoFixed(7).weight(.semibold))
                        .foregroundStyle(toneColor)
                        .padding(.top, 2)
                    Text("No recent activity")
                        .font(Theme.monoFixed(7))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .stroke(toneColor.opacity(0.7), lineWidth: 0.8)
        )
    }
}

/// Cyan `= /` prompt indicator that matches the reference image.
struct PromptIndicator: View {
    var body: some View {
        HStack(spacing: 0) {
            Text("=").foregroundStyle(Theme.prompt)
            Text("/").foregroundStyle(Theme.prompt)
            Spacer()
        }
        .font(Theme.monoFixed(10).weight(.bold))
        .padding(.vertical, 2)
    }
}

/// Two-column slash command list (matches reference).
struct SlashList: View {
    let commands: [SlashCommand]
    let highlightedIndex: Int
    let onPick: (SlashCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(commands.enumerated()), id: \.element.id) { idx, cmd in
                HStack(alignment: .top, spacing: 4) {
                    Text(cmd.id)
                        .font(Theme.monoFixed(8).weight(.semibold))
                        .foregroundStyle(idx == highlightedIndex ? Color.black : Theme.prompt)
                        .frame(width: 56, alignment: .leading)
                    Text(cmd.description)
                        .font(Theme.monoFixed(7))
                        .foregroundStyle(idx == highlightedIndex ? Color.black.opacity(0.8) : Theme.textPrimary)
                        .lineLimit(2)
                    Spacer()
                }
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(idx == highlightedIndex ? Theme.prompt : Color.clear)
                .onTapGesture { onPick(cmd) }
            }
        }
    }
}
