import SwiftUI

struct EndpointListView: View {
    @EnvironmentObject var store: EndpointStore
    @State private var showingAdd = false

    var body: some View {
        List {
            Section {
                if store.endpoints.isEmpty {
                    ContentUnavailableView(
                        "No servers",
                        systemImage: "server.rack",
                        description: Text("Tap + to add a watchcli-daemon endpoint running on your Mac, workstation, or server.")
                    )
                } else {
                    ForEach(store.endpoints) { e in
                        NavigationLink(value: e) {
                            VStack(alignment: .leading) {
                                Text(e.name).font(.headline)
                                Text(e.url.absoluteString).font(.caption).foregroundStyle(.secondary)
                                Text("agent: \(e.defaultAgent)").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { store.remove(at: $0) }
                }
            } header: {
                Text("Endpoints")
            } footer: {
                Text("Endpoints sync to your Apple Watch automatically (P5).")
            }
        }
        .navigationDestination(for: Endpoint.self) { e in
            EndpointDetailView(endpoint: e)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            EndpointEditView(endpoint: nil) { new in store.add(new) }
        }
    }
}

struct EndpointDetailView: View {
    @EnvironmentObject var store: EndpointStore
    let endpoint: Endpoint
    @State private var editing = false

    var body: some View {
        Form {
            LabeledContent("Name", value: endpoint.name)
            LabeledContent("URL", value: endpoint.url.absoluteString)
            LabeledContent("Default agent", value: endpoint.defaultAgent)
            LabeledContent("Token", value: String(repeating: "•", count: min(endpoint.token.count, 16)))
        }
        .toolbar {
            Button("Edit") { editing = true }
        }
        .sheet(isPresented: $editing) {
            EndpointEditView(endpoint: endpoint) { updated in store.update(updated) }
        }
    }
}

struct EndpointEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var urlString: String
    @State private var token: String
    @State private var agent: String
    private let existingId: UUID?
    private let onSave: (Endpoint) -> Void

    init(endpoint: Endpoint?, onSave: @escaping (Endpoint) -> Void) {
        self._name = .init(initialValue: endpoint?.name ?? "")
        self._urlString = .init(initialValue: endpoint?.url.absoluteString ?? "ws://192.168.1.2:8765/v1/session")
        self._token = .init(initialValue: endpoint?.token ?? "")
        self._agent = .init(initialValue: endpoint?.defaultAgent ?? "shell")
        self.existingId = endpoint?.id
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)
                }
                Section("Connection") {
                    TextField("ws://host:port/v1/session", text: $urlString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Bearer token", text: $token)
                }
                Section("Default agent") {
                    Picker("Agent", selection: $agent) {
                        Text("Shell").tag("shell")
                        Text("Claude Code").tag("claude")
                        Text("Copilot CLI").tag("copilot")
                    }
                }
            }
            .navigationTitle(existingId == nil ? "Add server" : "Edit server")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let url = URL(string: urlString) else { return }
                        let e = Endpoint(id: existingId ?? UUID(), name: name, url: url, token: token, defaultAgent: agent)
                        onSave(e); dismiss()
                    }
                    .disabled(name.isEmpty || URL(string: urlString) == nil || token.isEmpty)
                }
            }
        }
    }
}
