import SwiftUI
import WatchCLIProtocol

@main
struct WatchCLIWatchApp: App {
    @StateObject private var store = EndpointStore()
    @StateObject private var session = SessionViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var store: EndpointStore
    @EnvironmentObject var session: SessionViewModel

    var body: some View {
        TabView {
            TerminalView().tag(0)
            ComposeView().tag(1)
            ServersView().tag(2)
        }
        .tabViewStyle(.verticalPage)
        .background(Theme.background.ignoresSafeArea())
        // Auto-connect to the first endpoint on launch as a convenience.
        .task {
            if session.selectedEndpointID == nil, let first = store.endpoints.first {
                session.select(first)
            }
        }
    }
}
