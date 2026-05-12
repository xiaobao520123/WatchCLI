import SwiftUI
import WatchCLIProtocol

/// One full CLI session: scrollable output area on top, inline prompt
/// on the bottom. Modeled after the layout of the real `claude` /
/// `copilot` CLIs: dense monospaced output, prompt with `> ` cyan
/// caret, slash picker pops up as the user types `/`. The Digital
/// Crown scrolls the slash picker when it's visible (claude/copilot UX).
struct TerminalSessionView: View {
    @ObservedObject var session: SessionViewModel
    let agent: String

    @EnvironmentObject var store: EndpointStore
    @AppStorage("commandHistory") private var historyJSON: String = "{}"
    @StateObject private var recorder = AudioRecorder()
    @State private var draft: String = ""
    @State private var transcribing = false
    @State private var lastError: String?
    @State private var slashIndex: Double = 0
    @FocusState private var inputFocused: Bool

    private var history: CommandHistory { CommandHistory.decode(historyJSON) }

    private var hasOutput: Bool {
        session.lines.contains { $0.kind == .stdout || $0.kind == .stderr || $0.kind == .prompt }
    }

    private var slashMatches: [SlashCommand] {
        guard draft.hasPrefix("/") else { return [] }
        return SlashCatalog.match(prefix: draft)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            outputArea
            promptRow
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
        .containerBackground(Theme.background, for: .tabView)
    }

    // MARK: - Output

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 1) {
                    if !hasOutput {
                        bannerForAgent
                            .padding(.bottom, 4)
                    }
                    ForEach(session.lines) { line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(Theme.monoFixed(10))
                            .foregroundStyle(line.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
            }
            .onChange(of: session.lines.count) { _, _ in
                guard let last = session.lines.last else { return }
                withAnimation(.easeOut(duration: 0.08)) {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    @ViewBuilder
    private var bannerForAgent: some View {
        let host = session.bannerHostname.isEmpty ? "(disconnected)" : session.bannerHostname
        switch agent {
        case "claude":
            ClaudeBanner(title: "Claude Code v\(DaemonClientInfo.appVersion)",
                         subtitle: "Sonnet · \(host)")
        case "copilot":
            CopilotBanner(title: "Copilot CLI v\(DaemonClientInfo.appVersion)",
                          subtitle: "GPT · \(host)")
        default:
            ShellBanner(hostname: host, agent: agent)
        }
    }

    // MARK: - Prompt + slash picker

    private var promptRow: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !slashMatches.isEmpty {
                slashPickerView
            }
            HStack(alignment: .center, spacing: 4) {
                Text(">")
                    .font(Theme.monoFixed(11).weight(.bold))
                    .foregroundStyle(Theme.prompt)
                TextField("type or /cmd", text: $draft, axis: .vertical)
                    .font(Theme.monoFixed(10))
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .lineLimit(1...3)
                Button(action: micTapped) {
                    Image(systemName: micIcon)
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(
                            Circle().fill(recorder.state == .recording ? Color.red : Theme.accent)
                        )
                }
                .buttonStyle(.plain)
                .disabled(transcribing)

                Button(action: send) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(canSend ? Theme.accent : Theme.muted)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 6).fill(Theme.surface))
            if let lastError {
                Text(lastError)
                    .font(.caption2)
                    .foregroundStyle(Color.red.opacity(0.85))
                    .lineLimit(2)
            }
        }
    }

    private var slashPickerView: some View {
        let safeIndex = max(0, min(Int(slashIndex.rounded()), slashMatches.count - 1))
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(slashMatches.enumerated()), id: \.element.id) { idx, cmd in
                HStack(spacing: 4) {
                    Text(cmd.id)
                        .font(Theme.monoFixed(10).weight(.semibold))
                        .foregroundStyle(idx == safeIndex ? Color.black : Theme.prompt)
                    Text(cmd.description)
                        .font(Theme.monoFixed(9))
                        .foregroundStyle(idx == safeIndex ? Color.black.opacity(0.85) : Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(idx == safeIndex ? Theme.prompt : Color.clear)
                .onTapGesture {
                    draft = cmd.id
                    slashIndex = 0
                    inputFocused = false
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.surface))
        .focusable()
        .digitalCrownRotation(
            $slashIndex,
            from: 0,
            through: Double(max(0, slashMatches.count - 1)),
            by: 1,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: slashMatches.count) { _, n in
            if slashIndex >= Double(n) { slashIndex = max(0, Double(n - 1)) }
        }
    }

    // MARK: - Actions

    private var canSend: Bool {
        if case .connected = session.state {
            return !draft.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return !draft.trimmingCharacters(in: .whitespaces).isEmpty
            && SlashCatalog.all.first(where: { $0.id == draft.trimmingCharacters(in: .whitespaces) })?.kind == .local
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var h = history; h.record(text); historyJSON = h.encoded()
        session.send(line: text)
        draft = ""; slashIndex = 0
    }

    private var micIcon: String {
        if transcribing { return "ellipsis" }
        return recorder.state == .recording ? "stop.fill" : "mic.fill"
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
}
