import Foundation

/// User-facing description of a remote daemon endpoint.
public struct Endpoint: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String                 // user-friendly, e.g. "Mac Studio"
    public var url: URL                     // ws(s)://host:port/v1/session
    public var token: String                // bearer token for auth
    public var defaultAgent: String         // "shell" | "claude" | "copilot"

    public init(id: UUID = UUID(), name: String, url: URL, token: String, defaultAgent: String = "shell") {
        self.id = id; self.name = name; self.url = url
        self.token = token; self.defaultAgent = defaultAgent
    }
}

/// JSON-on-disk endpoint store. Both watchOS and iOS targets use this; the
/// iOS app additionally syncs the same JSON blob to the watch via
/// WatchConnectivity in P5.
public final class EndpointStore: ObservableObject {
    @Published public private(set) var endpoints: [Endpoint] = []

    private let url: URL

    public init(filename: String = "endpoints.json") {
        let dir = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)) ?? FileManager.default.temporaryDirectory
        self.url = dir.appendingPathComponent(filename)
        load()
    }

    public func add(_ e: Endpoint) { endpoints.append(e); save() }
    public func remove(at offsets: IndexSet) { endpoints.remove(atOffsets: offsets); save() }
    public func update(_ e: Endpoint) {
        guard let i = endpoints.firstIndex(where: { $0.id == e.id }) else { return }
        endpoints[i] = e; save()
    }
    public func replaceAll(_ list: [Endpoint]) { endpoints = list; save() }

    private func load() {
        guard let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Endpoint].self, from: data) else { return }
        endpoints = list
    }
    private func save() {
        guard let data = try? JSONEncoder().encode(endpoints) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
