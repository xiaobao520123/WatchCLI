import SwiftUI
import WatchCLIProtocol

@main
struct WatchCLIWatchApp: App {
    @StateObject private var store = EndpointStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var store: EndpointStore

    var body: some View {
        TabView {
            TerminalView()
                .tag(0)
            ComposeView()
                .tag(1)
            ServersView()
                .tag(2)
        }
        .tabViewStyle(.verticalPage)
        .background(Theme.background.ignoresSafeArea())
    }
}
