import SwiftUI
import WatchCLIProtocol

/// Read-only terminal pane. P1 ships with a static welcome banner so we can
/// validate look & feel; P3 swaps the data source for live WebSocket output.
struct TerminalView: View {
    @State private var lines: [TerminalLine] = .welcome

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(lines) { line in
                        Text(line.text)
                            .font(Theme.mono(.footnote))
                            .foregroundStyle(line.color)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id(line.id)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
            }
            .background(Theme.background)
            .onChange(of: lines.count) { _, _ in
                if let last = lines.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
        .containerBackground(Theme.background, for: .tabView)
        .navigationTitle("watchcli")
    }
}

struct TerminalLine: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let color: Color
}

extension Array where Element == TerminalLine {
    static let welcome: [TerminalLine] = [
        .init(text: "WatchCLI v0.1", color: Theme.accent),
        .init(text: "protocol v1 · not connected", color: Theme.muted),
        .init(text: "", color: Theme.textPrimary),
        .init(text: "  Tip: add a server in the Servers tab,", color: Theme.textPrimary),
        .init(text: "  then dictate a command in Compose.",   color: Theme.textPrimary),
        .init(text: "", color: Theme.textPrimary),
        .init(text: "= /", color: Theme.prompt),
    ]
}
