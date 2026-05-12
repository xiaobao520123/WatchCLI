import SwiftUI

/// P1 stub. P4 will hook the dictation field and slash-command palette.
struct ComposeView: View {
    @State private var draft: String = ""

    var body: some View {
        VStack(spacing: 8) {
            Text("Compose")
                .font(Theme.mono(.caption))
                .foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            TextField("type or dictate", text: $draft, axis: .vertical)
                .font(Theme.mono(.footnote))
                .textFieldStyle(.plain)
                .padding(8)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Button {
                    // P4: kick off Speech recognition
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                Button {
                    // P3: send draft to active session
                    draft = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.bordered)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(8)
        .containerBackground(Theme.background, for: .tabView)
    }
}
