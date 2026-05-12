import SwiftUI
import WatchCLIProtocol

/// One full CLI session — modeled after the real GitHub Copilot CLI:
///
///   ┌──────────────────────────────────────┐
///   │  splash banner (mascot + tip line)   │
///   └──────────────────────────────────────┘
///   ● Environment loaded                       ← system / loading lines
///   $ ls                                       ← user lines (cyan)
///   total 8                                    ← stdout
///   ── ─ ──────────────────────────── ── ─
///   ❯ │                                     [mic]
///   ──────────────────────────────────────
///   ~/cwd  /commands · ?help  Sonnet 4.5   ← bottom status line
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
    @State private var pressing = false
    @FocusState private var inputFocused: Bool

    private var history: CommandHistory { CommandHistory.decode(historyJSON) }
    private var hasOutput: Bool {
        session.lines.contains { $0.kind == .stdout || $0.kind == .stderr || $0.kind == .prompt }
    }
    private var slashMatches: [SlashCommand] {
        guard draft.hasPrefix("/") else { return [] }
        return SlashCatalog.match(prefix: draft)
    }
    private var modelLabel: String {
        switch agent {
        case "claude":  return "Sonnet 4.5"
        case "copilot": return "Claude Opus"
        case "shell":   return "zsh"
        default:        return agent
        }
    }
    private var hostShort: String {
        if !session.bannerHostname.isEmpty {
            return session.bannerHostname.replacingOccurrences(of: ".local", with: "")
        }
        return "—"
    }

    var body: some View {
        VStack(spacing: 0) {
            outputArea
            if !slashMatches.isEmpty { slashPickerView }
            promptRow
            statusLine
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .containerBackground(Theme.background, for: .tabView)
    }

    // MARK: - Output

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !hasOutput {
                        bannerForAgent.padding(.bottom, 2)
                    }
                    ForEach(session.lines) { line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(Theme.monoFixed(9))
                            .foregroundStyle(line.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
            }
            .frame(maxHeight: .infinity)
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
            CopilotBanner(title: "GitHub Copilot v\(DaemonClientInfo.appVersion)",
                          subtitle: host)
        default:
            ShellBanner(hostname: host, agent: agent)
        }
    }

    // MARK: - Prompt + slash picker

    /// Compact prompt row: bordered ❯ input. Tap-and-hold the row to
    /// dictate (red border + pulse), release to transcribe. Tap (without
    /// hold) just focuses the text field for typing. Submitting the
    /// keyboard return sends the line.
    private var promptRow: some View {
        HStack(alignment: .center, spacing: 4) {
            Text("❯")
                .font(Theme.monoFixed(10).weight(.bold))
                .foregroundStyle(recorder.state == .recording ? .red : Theme.prompt)
            TextField("ask, /cmd, or hold to speak", text: $draft, axis: .vertical)
                .font(Theme.monoFixed(9))
                .textFieldStyle(.plain)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .lineLimit(1...2)
            if transcribing {
                ProgressView().controlSize(.mini)
            } else if recorder.state == .recording {
                Image(systemName: "waveform")
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .symbolEffect(.variableColor.iterative.reversing)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(recorder.state == .recording ? Color.red : Theme.muted.opacity(0.4),
                                lineWidth: 0.6)
                )
        )
        .scaleEffect(recorder.state == .recording ? 1.0 + CGFloat(recorder.level) * 0.04 : 1.0)
        .animation(.easeOut(duration: 0.12), value: recorder.level)
        .onLongPressGesture(minimumDuration: 0.25, maximumDistance: 30) {
            startRecording()
        } onPressingChanged: { pressing in
            self.pressing = pressing
            if !pressing && recorder.state == .recording { stopAndTranscribe() }
        }
    }

    private var slashPickerView: some View {
        let safeIndex = max(0, min(Int(slashIndex.rounded()), slashMatches.count - 1))
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(slashMatches.prefix(4).enumerated()), id: \.element.id) { idx, cmd in
                HStack(spacing: 4) {
                    Text(cmd.id)
                        .font(Theme.monoFixed(9).weight(.semibold))
                        .foregroundStyle(idx == safeIndex ? Color.black : Theme.prompt)
                    Text(cmd.description)
                        .font(Theme.monoFixed(8))
                        .foregroundStyle(idx == safeIndex ? Color.black.opacity(0.85) : Theme.muted)
                        .lineLimit(1).truncationMode(.tail)
                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(idx == safeIndex ? Theme.prompt : Color.clear)
                .onTapGesture {
                    draft = cmd.id; slashIndex = 0; inputFocused = false
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 4).fill(Theme.surface))
        .focusable()
        .digitalCrownRotation($slashIndex,
            from: 0, through: Double(max(0, slashMatches.count - 1)),
            by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: slashMatches.count) { _, n in
            if slashIndex >= Double(n) { slashIndex = max(0, Double(n - 1)) }
        }
    }

    // MARK: - Status line (matches real Copilot CLI bottom strip)

    private var statusLine: some View {
        HStack(spacing: 4) {
            Image(systemName: stateIcon)
                .font(.system(size: 7))
                .foregroundStyle(stateTint)
            Text(hostShort)
                .font(Theme.monoFixed(7))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Spacer(minLength: 2)
            Text(modelLabel)
                .font(Theme.monoFixed(7))
                .foregroundStyle(Theme.copilot.opacity(0.85))
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .padding(.top, 2)
        .overlay(alignment: .bottom) {
            if let lastError {
                Text(lastError)
                    .font(Theme.monoFixed(7))
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
                    .background(Color.black.opacity(0.7))
            }
        }
    }

    private var stateIcon: String {
        switch session.state {
        case .idle:           "circle"
        case .connecting:     "arrow.triangle.2.circlepath"
        case .connected:      "circle.fill"
        case .disconnected:   "exclamationmark.circle"
        }
    }
    private var stateTint: Color {
        switch session.state {
        case .idle:           Theme.muted
        case .connecting:     .yellow
        case .connected:      .green
        case .disconnected:   .red
        }
    }

    // MARK: - Actions

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var h = history; h.record(text); historyJSON = h.encoded()
        session.send(line: text)
        draft = ""; slashIndex = 0
    }

    private func startRecording() {
        lastError = nil
        Task {
            let ok = await recorder.requestPermission()
            guard ok else { lastError = "microphone permission denied"; return }
            recorder.start()
        }
    }

    private func stopAndTranscribe() {
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
                lastError = String(describing: error).prefix(120).description
            }
            transcribing = false
        }
    }
}
