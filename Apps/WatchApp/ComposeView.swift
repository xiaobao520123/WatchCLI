import SwiftUI
import WatchCLIProtocol

struct ComposeView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var store: EndpointStore
    @AppStorage("commandHistory") private var historyJSON: String = "{}"
    @StateObject private var recorder = AudioRecorder()
    @State private var draft: String = ""
    @State private var transcribing = false
    @State private var lastError: String?
    @FocusState private var inputFocused: Bool

    private var history: CommandHistory { CommandHistory.decode(historyJSON) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Compose")
                    .font(Theme.mono(.caption))
                    .foregroundStyle(Theme.muted)

                TextField("press mic, or type", text: $draft, axis: .vertical)
                    .font(Theme.mono(.footnote))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)

                micRow
                if let lastError {
                    Text(lastError)
                        .font(.caption2)
                        .foregroundStyle(Color.red.opacity(0.85))
                        .lineLimit(3)
                }

                HStack(spacing: 8) {
                    Button(action: send) {
                        Image(systemName: "paperplane.fill")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(!canSend)

                    Button(role: .destructive) {
                        session.interrupt()
                    } label: {
                        Image(systemName: "stop.circle.fill")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                }

                paletteSection(title: "slash", items: SlashCatalog.all.map(\.id))
                if !history.entries.isEmpty {
                    paletteSection(title: "recent", items: history.entries)
                }
            }
            .padding(8)
        }
        .containerBackground(Theme.background, for: .tabView)
    }

    @ViewBuilder
    private var micRow: some View {
        HStack(spacing: 8) {
            Button(action: micTapped) {
                ZStack {
                    if recorder.state == .recording {
                        Circle().fill(Color.red.opacity(0.3))
                            .scaleEffect(0.8 + 0.4 * CGFloat(recorder.level))
                            .animation(.easeOut(duration: 0.15), value: recorder.level)
                    }
                    Image(systemName: micIcon)
                        .font(.title3)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(recorder.state == .recording ? .red : Theme.accent)
            .disabled(transcribing)

            if transcribing {
                ProgressView().controlSize(.small)
            }
        }
    }

    private var micIcon: String {
        if transcribing { return "ellipsis" }
        switch recorder.state {
        case .recording:        return "stop.fill"
        case .idle, .error:     return "mic.fill"
        }
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

    private func micTapped() {
        lastError = nil
        if recorder.state == .recording {
            transcribing = true
            Task {
                guard let audio = await recorder.stop(), !audio.isEmpty else {
                    transcribing = false; lastError = "no audio captured"; return
                }
                guard let endpoint = store.endpoints.first(where: { $0.id == session.selectedEndpointID }) ?? store.endpoints.first else {
                    transcribing = false; lastError = "no endpoint"; return
                }
                do {
                    let text = try await TranscribeClient(endpoint: endpoint).transcribe(audio)
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    draft = draft.isEmpty ? trimmed : draft + " " + trimmed
                } catch {
                    lastError = error.localizedDescription
                }
                transcribing = false
            }
        } else {
            Task {
                let ok = await recorder.requestPermission()
                guard ok else { lastError = "microphone permission denied"; return }
                recorder.start()
            }
        }
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
                        .tint(s.hasPrefix("/") ? Theme.prompt : Theme.muted)
                }
            }
        }
    }
}
