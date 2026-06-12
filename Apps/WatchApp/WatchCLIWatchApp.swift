import SwiftUI
import WatchCLIProtocol

@main
struct WatchCLIWatchApp: App {
    @StateObject private var store = EndpointStore()
    @StateObject private var prefs = Preferences()
    @StateObject private var manager = SessionManager()
    @State private var sync: EndpointSyncBridge?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(prefs)
                .environmentObject(manager)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    if sync == nil { sync = EndpointSyncBridge(store: store, prefs: prefs) }
                    if prefs.autoConnect, manager.tabs.isEmpty, let first = store.endpoints.first {
                        _ = manager.add(endpoint: first)
                    }
                }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var store: EndpointStore
    @EnvironmentObject var manager: SessionManager
    @EnvironmentObject var prefs: Preferences
    @State private var crownActive: Double = 0
    @State private var showingActions = false

    private var pageCount: Int { manager.tabs.count + 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabStrip(showingActions: $showingActions)
            TabView(selection: $manager.activeIndex) {
                ForEach(Array(manager.tabs.enumerated()), id: \.element.id) { idx, tab in
                    TerminalSessionView(session: tab.sessionVM, agent: tab.agent)
                        .tag(idx)
                }
                NewTabPage().tag(manager.tabs.count)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .background(Theme.background.ignoresSafeArea())
        // Crown rotation switches tabs (when the slash picker isn't focused).
        .focusable(prefs.crownTabSwitch && manager.tabs.count > 1)
        .digitalCrownRotation(
            $crownActive,
            from: 0, through: Double(max(0, pageCount - 1)),
            by: 1, sensitivity: .low,
            isContinuous: false, isHapticFeedbackEnabled: prefs.hapticsEnabled
        )
        .onChange(of: crownActive) { _, new in
            let target = max(0, min(Int(new.rounded()), pageCount - 1))
            if target != manager.activeIndex {
                manager.activeIndex = target
            }
        }
        .onChange(of: manager.activeIndex) { _, new in
            crownActive = Double(new)
        }
        .onAppear { crownActive = Double(manager.activeIndex) }
    }
}

/// "New Tab" sentinel page — swipe past the last real tab to land here.
/// Lists every (server, agent) pair as a fat tappable row + a Settings
/// shortcut at the bottom.
private struct NewTabPage: View {
    @EnvironmentObject var store: EndpointStore
    @EnvironmentObject var manager: SessionManager

    private let agents: [(id: String, label: String, color: Color)] = [
        ("shell",   "$ shell",    Theme.shellTone),
        ("claude",  "C claude",   Theme.claude),
        ("copilot", "G copilot",  Theme.copilot),
        ("oneshot", "1 oneshot",  Theme.muted),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("New tab")
                    .font(Theme.monoFixed(11).weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text("Swipe back to return.")
                    .font(Theme.monoFixed(7))
                    .foregroundStyle(Theme.muted)

                if store.endpoints.isEmpty {
                    Text("No servers yet. Open the iPhone Settings to add one.")
                        .font(Theme.monoFixed(8))
                        .foregroundStyle(Theme.muted)
                        .padding(.top, 6)
                } else {
                    ForEach(store.endpoints) { ep in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ep.name)
                                .font(Theme.monoFixed(9).weight(.semibold))
                                .foregroundStyle(Theme.textPrimary)
                            VStack(spacing: 2) {
                                ForEach(agents, id: \.id) { a in
                                    Button {
                                        manager.add(endpoint: ep, agent: a.id)
                                    } label: {
                                        HStack {
                                            Text(a.label)
                                                .font(Theme.monoFixed(9).weight(.semibold))
                                                .foregroundStyle(a.color)
                                            Spacer()
                                            Image(systemName: "plus.circle.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(a.color.opacity(0.85))
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(a.color.opacity(0.15))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                Text("Edit servers, voice mode and other prefs in the iPhone app.")
                    .font(Theme.monoFixed(7))
                    .foregroundStyle(Theme.muted)
                    .padding(.top, 6)
                    .lineLimit(3)
            }
            .padding(8)
        }
        .containerBackground(Theme.background, for: .tabView)
    }
}
