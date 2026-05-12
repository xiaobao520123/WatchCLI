import SwiftUI

@main
struct WatchCLICompanionApp: App {
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
        NavigationStack {
            EndpointListView()
                .navigationTitle("WatchCLI")
        }
    }
}
