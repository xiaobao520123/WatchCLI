import SwiftUI
import WatchCLIProtocol

/// Live terminal pane backed by `SessionViewModel`. Shows the styled
/// `WelcomeView` when there's no output yet; otherwise renders the
/// streamed lines with auto-scroll.
struct TerminalView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var store: EndpointStore

    private var hasContent: Bool {
        // Treat any non-system / non-banner line as "real" content.
        session.lines.contains { $0.kind == .stdout || $0.kind == .stderr || $0.kind == .prompt }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    statusPill
                    if !hasContent {
                        WelcomeView()
                    } else {
                        ForEach(session.lines) { line in
                            Text(line.text.isEmpty ? " " : line.text)
                                .font(Theme.mono(.footnote))
                                .foregroundStyle(line.color)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id(line.id)
                        }
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .background(Theme.background)
            .onChange(of: session.lines.count) { _, _ in
                if let last = session.lines.last {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .containerBackground(Theme.background, for: .tabView)
        .navigationTitle("watchcli")
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle().fill(stateColor).frame(width: 6, height: 6)
            Text(stateLabel)
                .font(Theme.mono(.caption2))
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    private var stateColor: Color {
        switch session.state {
        case .idle:                 Theme.muted
        case .connecting:           .yellow
        case .connected:            .green
        case .disconnected:         .red
        }
    }
    private var stateLabel: String {
        switch session.state {
        case .idle:                 "idle"
        case .connecting:           "connecting…"
        case .connected:            session.bannerHostname.isEmpty ? "connected" : session.bannerHostname
        case .disconnected:         "disconnected"
        }
    }
}
