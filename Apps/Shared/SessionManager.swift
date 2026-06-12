import Foundation
import Combine
import WatchCLIProtocol

/// Owns N concurrent watch sessions, each backed by its own `SessionViewModel`.
/// Modeled after Windows Terminal's tab semantics: an ordered list of tabs,
/// one is active, the user can `add` (`+`), `close`, and `select` by index.
///
/// Each tab tracks its endpoint independently so the user can have a
/// `claude` tab next to a `shell` tab next to a `copilot` tab on the same
/// daemon — or even tabs pointing at different endpoints.
@MainActor
public final class SessionManager: ObservableObject {
    @Published public private(set) var tabs: [Tab] = []
    @Published public var activeIndex: Int = 0

    public struct Tab: Identifiable, Equatable {
        public let id: UUID
        public var endpointID: UUID
        public var agent: String
        public var sessionVM: SessionViewModel

        public static func == (lhs: Tab, rhs: Tab) -> Bool { lhs.id == rhs.id }
    }

    public init() {}

    public var activeTab: Tab? {
        guard tabs.indices.contains(activeIndex) else { return nil }
        return tabs[activeIndex]
    }

    /// Spin up a fresh session. If `endpoint` is nil, the new tab stays
    /// disconnected until the user picks one in the Servers tab.
    @discardableResult
    public func add(endpoint: Endpoint?, agent: String? = nil) -> Tab {
        let vm = SessionViewModel()
        let tab = Tab(
            id: UUID(),
            endpointID: endpoint?.id ?? UUID(),
            agent: agent ?? endpoint?.defaultAgent ?? "shell",
            sessionVM: vm
        )
        tabs.append(tab)
        activeIndex = tabs.count - 1
        if let endpoint {
            // Honor the per-tab agent override.
            var ep = endpoint
            if let agent { ep.defaultAgent = agent }
            vm.connect(to: ep)
        }
        return tab
    }

    public func close(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[idx]
        Task { await tab.sessionVM.disconnect() }
        tabs.remove(at: idx)
        if tabs.isEmpty {
            activeIndex = 0
        } else if activeIndex >= tabs.count {
            activeIndex = tabs.count - 1
        } else if idx < activeIndex {
            activeIndex -= 1
        }
    }

    public func select(_ id: UUID) {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return }
        activeIndex = idx
    }

    /// Returns a one- or two-letter chip label for the agent.
    public static func chipLabel(for agent: String) -> String {
        switch agent {
        case "claude":  "C"
        case "copilot": "G"   // GitHub
        case "shell":   "$"
        case "oneshot": "1"
        default:        String(agent.prefix(1)).uppercased()
        }
    }

    /// Color hint for the agent chip.
    public static func chipKey(for agent: String) -> AgentTone {
        switch agent {
        case "claude":  .claude
        case "copilot": .copilot
        case "shell":   .shell
        case "oneshot": .neutral
        default:        .neutral
        }
    }

    public enum AgentTone { case claude, copilot, shell, neutral }
}
