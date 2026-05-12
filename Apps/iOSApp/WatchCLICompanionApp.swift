import SwiftUI

@main
struct WatchCLICompanionApp: App {
    @StateObject private var store = EndpointStore()
    @State private var sync: EndpointSyncBridge?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    if sync == nil { sync = EndpointSyncBridge(store: store) }
                }
                .onChange(of: store.endpoints) { _, _ in
                    sync?.push()
                }
        }
    }
}

private struct RootView: View {
    @EnvironmentObject var store: EndpointStore

    var body: some View {
        NavigationStack {
            EndpointListView()
                .navigationTitle("WatchCLI")
        }
    }
}
