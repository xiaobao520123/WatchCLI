import SwiftUI
import WatchCLIProtocol

struct ComposeView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var draft: String = ""

    private let suggestions = ["ls", "pwd", "uptime", "git status", "/help"]

    var body: some View {
        VStack(spacing: 8) {
            Text("Compose")
                .font(Theme.mono(.caption))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            // watchOS shows the dictation/scribble UI when the user taps a TextField.
            TextField("type or dictate", text: $draft, axis: .vertical)
                .font(Theme.mono(.footnote))
                .textFieldStyle(.plain)
                .padding(8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                .submitLabel(.send)
                .onSubmit(send)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { s in
                        Button(s) { draft = s }
                            .font(Theme.mono(.caption2))
                            .buttonStyle(.bordered)
                            .tint(Theme.muted)
                    }
                }
            }

            HStack(spacing: 8) {
                Button { draft = "" } label: {
                    Image(systemName: "trash")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.bordered)
                .disabled(draft.isEmpty)

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .frame(maxWidth: .infinity, minHeight: 32)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(!canSend)
            }
        }
        .padding(8)
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
        session.send(line: draft)
        draft = ""
    }
}
