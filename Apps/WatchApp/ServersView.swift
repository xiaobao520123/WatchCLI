import SwiftUI

struct ServersView: View {
    @EnvironmentObject var store: EndpointStore
    @EnvironmentObject var session: SessionViewModel

    var body: some View {
        List {
            if store.endpoints.isEmpty {
                Section {
                    Text("No servers yet")
                        .font(Theme.mono(.footnote))
                        .foregroundStyle(Theme.muted)
                    Text("Add one in the WatchCLI iPhone app — it will sync here automatically (P5).")
                        .font(.caption2)
                        .foregroundStyle(Theme.muted)
                }
            } else {
                ForEach(store.endpoints) { e in
                    Button {
                        session.select(e)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.name)
                                    .font(Theme.mono(.footnote))
                                    .foregroundStyle(Theme.textPrimary)
                                Text(e.url.host() ?? e.url.absoluteString)
                                    .font(.caption2)
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            if session.selectedEndpointID == e.id {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .containerBackground(Theme.background, for: .tabView)
    }
}
