import SwiftUI

/// Tab strip matching the reference image: each chip shows the agent's
/// pixel mascot icon + the tab name in the agent's tone color, with a
/// trailing `+` chip for new and `_` / `X` action icons on the active tab.
/// The active tab is filled in its tone color; inactive tabs are outlined.
struct TabStrip: View {
    @EnvironmentObject var manager: SessionManager
    @EnvironmentObject var store: EndpointStore
    @Binding var showingActions: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 3) {
                    ForEach(Array(manager.tabs.enumerated()), id: \.element.id) { idx, tab in
                        chip(for: tab, index: idx).id(tab.id)
                    }
                    addChip
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 18)
            .onChange(of: manager.activeIndex) { _, new in
                guard manager.tabs.indices.contains(new) else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(manager.tabs[new].id, anchor: .center)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for tab: SessionManager.Tab, index: Int) -> some View {
        let active = manager.activeIndex == index
        let tone = color(for: tab.agent)
        Button { manager.activeIndex = index } label: {
            HStack(spacing: 3) {
                Image(systemName: glyph(for: tab.agent))
                    .font(.system(size: 8, weight: .bold))
                Text(tab.agent)
                    .font(Theme.monoFixed(8).weight(.semibold))
                    .lineLimit(1)
                if active {
                    Button { showingActions = true } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 8))
                    }
                    .buttonStyle(.plain)
                    Button { manager.close(tab.id) } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(active ? Color.black : tone)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(active ? tone : Color.clear)
            )
            .overlay(
                Capsule().stroke(tone.opacity(active ? 0 : 0.6), lineWidth: 0.7)
            )
        }
        .buttonStyle(.plain)
    }

    private var addChip: some View {
        Button { manager.activeIndex = manager.tabs.count } label: {
            Image(systemName: "plus")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .overlay(Capsule().stroke(Theme.muted.opacity(0.5), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
    }

    private func color(for agent: String) -> Color {
        switch agent {
        case "claude":  Theme.claude
        case "copilot": Theme.copilot
        case "shell":   Theme.shellTone
        case "oneshot": Theme.muted
        default:        Theme.accent
        }
    }
    private func glyph(for agent: String) -> String {
        switch agent {
        case "claude":  "ant.fill"             // bug-shaped
        case "copilot": "circle.hexagongrid.fill"
        case "shell":   "terminal.fill"
        case "oneshot": "1.circle.fill"
        default:        "questionmark.circle"
        }
    }
}
