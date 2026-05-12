import SwiftUI
import WatchCLIProtocol

@main
struct WatchCLIWatchApp: App {
    @StateObject private var store = EndpointStore()
    @StateObject private var manager = SessionManager()
    @State private var sync: EndpointSyncBridge?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(manager)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    if sync == nil { sync = EndpointSyncBridge(store: store) }
                    if manager.tabs.isEmpty, let first = store.endpoints.first {
                        _ = manager.add(endpoint: first)
                    }
                }
        }
    }
}

/// Root layout: a horizontal page-style TabView that contains all open
/// terminal sessions plus a final "+" page used as a swipe-create surface.
/// Swipe past the last real tab → land on the New page → tap a row to spawn
/// that session, which auto-becomes the active tab.
private struct RootView: View {
    @EnvironmentObject var store: EndpointStore
    @EnvironmentObject var manager: SessionManager

    /// Effective number of pages = real tabs + 1 (the New page).
    private var pageCount: Int { manager.tabs.count + 1 }

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $manager.activeIndex) {
                ForEach(Array(manager.tabs.enumerated()), id: \.element.id) { idx, tab in
                    TerminalSessionView(session: tab.sessionVM, agent: tab.agent)
                        .tag(idx)
                }
                NewTabPage()
                    .tag(manager.tabs.count)   // sentinel: index == count
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            TabIndicatorBar(count: pageCount, active: manager.activeIndex)
                .padding(.top, 2)
                .allowsHitTesting(false)
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

/// Tiny page-control style indicator at the top: one dot per tab, last dot
/// is a `+` glyph for the create-new page. Live status dot for active tab.
private struct TabIndicatorBar: View {
    @EnvironmentObject var manager: SessionManager
    let count: Int
    let active: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<count, id: \.self) { idx in
                Group {
                    if idx == count - 1 {
                        Image(systemName: "plus")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(idx == active ? Theme.accent : Theme.muted.opacity(0.5))
                    } else {
                        Circle()
                            .fill(idx == active ? Theme.accent : Theme.muted.opacity(0.4))
                            .frame(width: idx == active ? 5 : 3,
                                   height: idx == active ? 5 : 3)
                    }
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(Color.black.opacity(0.5)))
    }
}

/// The "+" sentinel page. Tap-to-spawn a session for any (server, agent)
/// combo. Acts as the swipe-create surface — swiping past the last real
/// tab brings you here.
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
                    Text("No servers. Open the iPhone app to add one.")
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
            }
            .padding(8)
        }
        .containerBackground(Theme.background, for: .tabView)
    }
}
