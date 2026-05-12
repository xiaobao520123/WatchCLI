import SwiftUI
import WatchCLIProtocol

struct ComposeView: View {
    @EnvironmentObject var session: SessionViewModel
    @AppStorage("commandHistory") private var historyJSON: String = "{}"
    @State private var draft: String = ""
    @FocusState private var inputFocused: Bool

    private let suggestions = ["ls", "pwd", "uptime", "git status", "/help"]

    private var history: CommandHistory { CommandHistory.decode(historyJSON) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Compose")
                    .font(Theme.mono(.caption))
                    .foregroundStyle(Theme.muted)

                TextField("tap to dictate", text: $draft, axis: .vertical)
                    .font(Theme.mono(.footnote))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)

                HStack(spacing: 8) {
                    Button { inputFocused = true } label: {
                        Label("Dictate", systemImage: "mic.fill")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.accent)

                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!canSend)
                }

                Button(role: .destructive) {
                    session.interrupt()
                } label: {
                    Label("Interrupt (^C)", systemImage: "stop.circle.fill")
                        .font(Theme.mono(.caption2))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                paletteSection(title: "quick", items: suggestions)
                if !history.entries.isEmpty {
                    paletteSection(title: "recent", items: history.entries)
                }
            }
            .padding(8)
        }
        .containerBackground(Theme.background, for: .tabView)
    }

    private var canSend: Bool {
        if case .connected = session.state {
            return !draft.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return false
    }

    private func send() {
        guard canSend else { return }
        var h = history
        h.record(draft)
        historyJSON = h.encoded()
        session.send(line: draft)
        draft = ""
    }

    @ViewBuilder
    private func paletteSection(title: String, items: [String]) -> some View {
        Text(title.uppercased())
            .font(.caption2)
            .foregroundStyle(Theme.muted)
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { s in
                    Button(s) { draft = s }
                        .font(Theme.mono(.caption2))
                        .buttonStyle(.bordered)
                        .tint(Theme.muted)
                }
            }
        }
    }
}
