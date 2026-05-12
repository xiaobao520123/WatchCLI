import SwiftUI

struct ServersView: View {
    @EnvironmentObject var store: EndpointStore

    var body: some View {
        List {
            if store.endpoints.isEmpty {
                Section {
                    Text("No servers yet")
                        .font(Theme.mono(.footnote))
                        .foregroundStyle(Theme.muted)
                    Text("Add one in the WatchCLI iPhone app — it will sync here automatically.")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                ForEach(store.endpoints) { e in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(e.name).font(Theme.mono(.footnote)).foregroundStyle(Theme.textPrimary)
                        Text(e.url.host() ?? e.url.absoluteString)
                            .font(.caption2).foregroundStyle(Theme.muted)
                    }
                }
            }
        }
        .containerBackground(Theme.background, for: .tabView)
    }
}
