import SwiftUI
import WatchCLIProtocol

@main
struct WatchCLIWatchApp: App {
    @StateObject private var store = EndpointStore()
    @StateObject private var session = SessionViewModel()
    @State private var sync: EndpointSyncBridge?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(session)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    if sync == nil { sync = EndpointSyncBridge(store: store) }
                }
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
        .task {
            if session.selectedEndpointID == nil, let first = store.endpoints.first {
                session.select(first)
            }
        }
    }
}
