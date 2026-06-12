import SwiftUI

@main
struct WatchCLICompanionApp: App {
    @StateObject private var store = EndpointStore()
    @StateObject private var prefs = Preferences()
    @State private var sync: EndpointSyncBridge?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(prefs)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .task {
                    if sync == nil { sync = EndpointSyncBridge(store: store, prefs: prefs) }
                }
                .onChange(of: store.endpoints) { _, _ in sync?.push() }
                .onChange(of: prefs.voiceInputMode) { _, _ in sync?.push() }
                .onChange(of: prefs.themeFontSize)  { _, _ in sync?.push() }
                .onChange(of: prefs.hapticsEnabled) { _, _ in sync?.push() }
                .onChange(of: prefs.autoConnect)    { _, _ in sync?.push() }
                .onChange(of: prefs.scrollWithCrown) { _, _ in sync?.push() }
                .onChange(of: prefs.crownTabSwitch) { _, _ in sync?.push() }
        }
    }
}

private struct RootView: View {
    var body: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("WatchCLI")
        }
    }
}
