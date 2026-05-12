import SwiftUI

/// Horizontal scrollable tab chip bar (Windows-Terminal-style):
/// each tab is a small chip showing the agent label + index; the active
/// chip is filled with its agent's tone color, inactive chips are outlined.
/// The trailing `+` chip spawns a fresh session. Long-press a chip to
/// close it.
struct TabStripView: View {
    @EnvironmentObject var manager: SessionManager
    @EnvironmentObject var store: EndpointStore
    @State private var showingNew = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(manager.tabs.enumerated()), id: \.element.id) { idx, tab in
                        chip(for: tab, index: idx)
                            .id(tab.id)
                    }
                    addChip
                }
                .padding(.horizontal, 4)
            }
            .frame(height: 22)
            .onChange(of: manager.activeIndex) { _, new in
                guard manager.tabs.indices.contains(new) else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(manager.tabs[new].id, anchor: .center)
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            NewTabSheet(onPick: { ep, agent in
                manager.add(endpoint: ep, agent: agent)
                showingNew = false
            }, onCancel: { showingNew = false })
        }
    }

    @ViewBuilder
    private func chip(for tab: SessionManager.Tab, index: Int) -> some View {
        let isActive = manager.activeIndex == index
        let tone = color(for: SessionManager.chipKey(for: tab.agent))
        Button {
            manager.activeIndex = index
        } label: {
            HStack(spacing: 3) {
                Text(SessionManager.chipLabel(for: tab.agent))
                    .font(Theme.monoFixed(10).weight(.bold))
                Text("\(index + 1)")
                    .font(Theme.monoFixed(9))
            }
            .foregroundStyle(isActive ? Color.black : tone)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule().fill(isActive ? tone : Color.clear)
            )
            .overlay(
                Capsule().stroke(tone.opacity(isActive ? 0 : 0.6), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                manager.close(tab.id)
            } label: { Label("Close", systemImage: "xmark") }
        }
    }

    private var addChip: some View {
        Button {
            showingNew = true
        } label: {
            Image(systemName: "plus")
                .font(Theme.monoFixed(11).weight(.bold))
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .overlay(Capsule().stroke(Theme.muted.opacity(0.6), lineWidth: 0.8))
        }
        .buttonStyle(.plain)
    }

    private func color(for tone: SessionManager.AgentTone) -> Color {
        switch tone {
        case .claude:   Theme.claude
        case .copilot:  Theme.copilot
        case .shell:    Theme.shellTone
        case .neutral:  Theme.muted
        }
    }
}

/// Sheet to pick (endpoint, agent) when adding a new tab.
struct NewTabSheet: View {
    @EnvironmentObject var store: EndpointStore
    @EnvironmentObject var manager: SessionManager
    let onPick: (Endpoint, String) -> Void
    let onCancel: () -> Void
    @State private var selectedEndpointID: UUID?

    private let agents: [(String, String, Color)] = [
        ("shell",   "$",  Theme.shellTone),
        ("claude",  "C",  Theme.claude),
        ("copilot", "G",  Theme.copilot),
        ("oneshot", "1",  Theme.muted),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("New tab")
                    .font(Theme.monoFixed(11).weight(.semibold))
                    .foregroundStyle(Theme.accent)

                if store.endpoints.isEmpty {
                    Text("No servers. Add one in the iPhone app first.")
                        .font(Theme.monoFixed(9))
                        .foregroundStyle(Theme.muted)
                } else {
                    Text("SERVER")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                    ForEach(store.endpoints) { ep in
                        Button {
                            selectedEndpointID = ep.id
                        } label: {
                            HStack {
                                Text(ep.name)
                                    .font(Theme.monoFixed(10))
                                Spacer()
                                if selectedEndpointID == ep.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    if selectedEndpointID == nil, store.endpoints.count == 1 {
                        // auto-select the only one
                        Color.clear.frame(height: 0)
                            .onAppear { selectedEndpointID = store.endpoints.first?.id }
                    }

                    Text("AGENT")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 4)
                    ForEach(agents, id: \.0) { agent in
                        Button {
                            guard let id = selectedEndpointID,
                                  let ep = store.endpoints.first(where: { $0.id == id }) else { return }
                            onPick(ep, agent.0)
                        } label: {
                            HStack {
                                Text(agent.1)
                                    .font(Theme.monoFixed(11).weight(.bold))
                                    .frame(width: 16)
                                    .foregroundStyle(agent.2)
                                Text(agent.0)
                                    .font(Theme.monoFixed(10))
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(agent.2.opacity(0.25))
                        .disabled(selectedEndpointID == nil)
                    }
                }

                Button("Cancel", action: onCancel)
                    .font(Theme.monoFixed(10))
                    .padding(.top, 4)
            }
            .padding(8)
        }
        .containerBackground(Theme.background, for: .navigation)
    }
}
