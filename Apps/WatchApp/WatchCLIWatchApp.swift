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
                    // Auto-spawn the first tab against the first endpoint.
                    if manager.tabs.isEmpty, let first = store.endpoints.first {
                        _ = manager.add(endpoint: first)
                    }
                }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var store: EndpointStore
    @EnvironmentObject var manager: SessionManager

    var body: some View {
        VStack(spacing: 2) {
            TabStripView()
            if manager.tabs.isEmpty {
                EmptyTabsHint()
            } else {
                TabView(selection: $manager.activeIndex) {
                    ForEach(Array(manager.tabs.enumerated()), id: \.element.id) { idx, tab in
                        TerminalSessionView(session: tab.sessionVM, agent: tab.agent)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct EmptyTabsHint: View {
    @EnvironmentObject var store: EndpointStore
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WatchCLI")
                .font(Theme.monoFixed(11).weight(.semibold))
                .foregroundStyle(Theme.accent)
            if store.endpoints.isEmpty {
                Text("Add a server in the iPhone app.\nIt will sync here automatically.")
                    .font(Theme.monoFixed(9))
                    .foregroundStyle(Theme.muted)
            } else {
                Text("Tap + above to start a session.")
                    .font(Theme.monoFixed(9))
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(8)
        .containerBackground(Theme.background, for: .tabView)
    }
}
