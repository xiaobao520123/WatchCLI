import SwiftUI
import WatchCLIProtocol

/// Live terminal pane backed by `SessionViewModel`. Auto-scrolls to bottom
/// as new lines arrive; falls back to a friendly hint when there's nothing
/// to show yet.
struct TerminalView: View {
    @EnvironmentObject var session: SessionViewModel
    @EnvironmentObject var store: EndpointStore

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    header
                    if session.lines.isEmpty {
                        emptyHint
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

    private var header: some View {
        HStack(spacing: 4) {
            Circle().fill(stateColor).frame(width: 6, height: 6)
            Text(stateLabel).font(Theme.mono(.caption2)).foregroundStyle(Theme.muted)
            Spacer()
        }
        .padding(.bottom, 2)
    }

    private var emptyHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("WatchCLI v0.1").foregroundStyle(Theme.accent)
            Text("protocol v1").foregroundStyle(Theme.muted)
            if store.endpoints.isEmpty {
                Text("Add a server in the iPhone app, then it appears in the Servers tab.")
                    .foregroundStyle(Theme.muted)
            } else {
                Text("Pick a server in the Servers tab and dictate a command in Compose.")
                    .foregroundStyle(Theme.muted)
            }
        }
        .font(Theme.mono(.footnote))
    }

    private var stateColor: Color {
        switch session.state {
        case .idle:                 Theme.muted
        case .connecting:           Color.yellow
        case .connected:            Color.green
        case .disconnected:         Color.red
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
