import SwiftUI
import WatchCLIProtocol

/// One CLI session — matches the reference image:
///
///   ┌─ tab strip ────────────────┐
///   │ 🐛 claude  +  …  X         │
///   ├────────────────────────────┤
///   │  ┌──────────────────────┐  │
///   │  │ Claude Code v0.1     │  │
///   │  │ Welcome back!        │  │
///   │  │ [mascot] | Tips      │  │
///   │  │ Sonnet   |  ...      │  │
///   │  │ ~        | Recent... │  │
///   │  └──────────────────────┘  │
///   │  = /                       │
///   │  /add-dir  Add a new...    │
///   │  /agents   Manage agent..  │
///   │  /bashes   List and...     │
///   │                            │
///   │ ❯ ▌                  [mic] │
///   └────────────────────────────┘
struct TerminalSessionView: View {
    @ObservedObject var session: SessionViewModel
    let agent: String

    @EnvironmentObject var store: EndpointStore
    @EnvironmentObject var prefs: Preferences
    @AppStorage("commandHistory") private var historyJSON: String = "{}"
    @StateObject private var recorder = AudioRecorder()
    @State private var draft: String = ""
    @State private var transcribing = false
    @State private var lastError: String?
    @State private var slashIndex: Double = 0
    @State private var scrollOffset: Double = 0
    @State private var showingActions = false
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
        case "oneshot": return "$ -c"
        default:        return agent
        }
    }
    private var hostShort: String {
        if !session.bannerHostname.isEmpty {
            return session.bannerHostname.replacingOccurrences(of: ".local", with: "")
        }
        return "—"
    }
    private var brandLabel: String {
        switch agent {
        case "claude":  return "Claude Code"
        case "copilot": return "GitHub Copilot"
        default:        return "WatchCLI"
        }
    }
    private var toneColor: Color {
        switch agent {
        case "claude":  return Theme.claude
        case "copilot": return Theme.copilot
        case "shell":   return Theme.shellTone
        default:        return Theme.muted
        }
    }
    private var tipsText: String {
        switch agent {
        case "claude":  return "Run /init to create a CLAUDE.md file."
        case "copilot": return "/skills · /help to see all commands."
        case "shell":   return "Type a command, /help, or hold input."
        default:        return "Run any shell command via $SHELL -c."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            outputArea
            promptRow
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 2)
        .containerBackground(Theme.background, for: .tabView)
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.height < -40 { showingActions = true }
                }
        )
        .sheet(isPresented: $showingActions) {
            TabActionsSheet(session: session, agent: agent,
                            presented: $showingActions,
                            onPickCommand: { draft = $0; send() })
        }
    }

    // MARK: - Output

    private var outputArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !hasOutput {
                        WelcomePanel(
                            brand: brandLabel,
                            model: modelLabel,
                            cwd: hostShort,
                            tips: tipsText,
                            mascot: AnyView(mascotForAgent),
                            toneColor: toneColor
                        )
                        PromptIndicator()
                        SlashList(
                            commands: Array(SlashCatalog.welcomeSubset.prefix(5)),
                            highlightedIndex: -1,
                            onPick: { draft = $0.id }
                        )
                    }
                    ForEach(session.lines) { line in
                        Text(line.text.isEmpty ? " " : line.text)
                            .font(Theme.monoFixed(CGFloat(prefs.themeFontSize)))
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
    private var mascotForAgent: some View {
        switch agent {
        case "copilot":  CopilotMascot(lineHeight: 8, color: Theme.copilot)
        default:         PixelMascot(pixel: 2, color: toneColor)
        }
    }

    // MARK: - Prompt row (compact, with optional mic per Preferences)

    private var promptRow: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !slashMatches.isEmpty {
                SlashList(commands: Array(slashMatches.prefix(4)),
                          highlightedIndex: max(0, min(Int(slashIndex.rounded()), slashMatches.count - 1)),
                          onPick: { draft = $0.id; slashIndex = 0; inputFocused = false })
                    .background(RoundedRectangle(cornerRadius: 4).fill(Theme.surface))
                    .focusable()
                    .digitalCrownRotation($slashIndex,
                        from: 0, through: Double(max(0, slashMatches.count - 1)),
                        by: 1, sensitivity: .low,
                        isContinuous: false, isHapticFeedbackEnabled: prefs.hapticsEnabled)
                    .onChange(of: slashMatches.count) { _, n in
                        if slashIndex >= Double(n) { slashIndex = max(0, Double(n - 1)) }
                    }
            }
            HStack(spacing: 3) {
                Text("❯")
                    .font(Theme.monoFixed(10).weight(.bold))
                    .foregroundStyle(recorder.state == .recording ? .red : Theme.prompt)
                TextField("type or /cmd", text: $draft, axis: .vertical)
                    .font(Theme.monoFixed(CGFloat(prefs.themeFontSize)))
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .lineLimit(1...2)
                if prefs.voice != .off {
                    micChip
                }
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(recorder.state == .recording ? Color.red : Theme.muted.opacity(0.4),
                                    lineWidth: 0.6)
                    )
            )
            if let lastError {
                Text(lastError)
                    .font(Theme.monoFixed(7))
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .padding(.horizontal, 4)
            }
        }
    }

    /// Tiny mic icon that adapts to the user-selected voice mode.
    @ViewBuilder
    private var micChip: some View {
        if transcribing {
            ProgressView().controlSize(.mini)
        } else {
            Button(action: micTapped) {
                Image(systemName: micGlyph)
                    .font(.system(size: 10))
                    .foregroundStyle(recorder.state == .recording ? .red : Theme.accent)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(prefs.voice == .nativeDictation ? "Dictate" : "Hold to record")
        }
    }
    private var micGlyph: String {
        recorder.state == .recording ? "stop.fill" : (prefs.voice == .nativeDictation ? "mic" : "mic.circle.fill")
    }

    // MARK: - Actions

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        var h = history; h.record(text); historyJSON = h.encoded()
        session.send(line: text)
        draft = ""; slashIndex = 0
    }

    private func micTapped() {
        lastError = nil
        switch prefs.voice {
        case .off:
            return
        case .nativeDictation:
            // Trigger watchOS native dictation by focusing the field.
            inputFocused = true
        case .whisperViaDaemon:
            if recorder.state == .recording { stopAndTranscribe() } else { startRecording() }
        }
    }

    private func startRecording() {
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
