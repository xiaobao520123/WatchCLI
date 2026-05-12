import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

/// Bridges `EndpointStore` between the iOS companion and the watchOS app
/// using `WCSession.updateApplicationContext`. The application context is
/// the right primitive here because we only need the *latest* set of
/// endpoints; transferring large or queued payloads is unnecessary.
public final class EndpointSyncBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let store: EndpointStore
    private let session: WCSession

    public init(store: EndpointStore, session: WCSession = .default) {
        self.store = store
        self.session = session
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    /// Call from the iOS app whenever endpoints change to push them to the
    /// watch. Safe to call on either side; only the iOS side actually
    /// transfers (the watch's outgoing application context is unused here).
    public func push() {
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        do {
            let data = try JSONEncoder().encode(store.endpoints)
            try session.updateApplicationContext(["endpoints": data])
        } catch {
            // Best-effort sync; surface as console warning only.
            print("WatchCLI sync: \(error)")
        }
    }

    // MARK: WCSessionDelegate

    public func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if state == .activated { push() }
    }
    #if os(iOS)
    public func sessionDidBecomeInactive(_ session: WCSession) {}
    public func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    public func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["endpoints"] as? Data,
              let list = try? JSONDecoder().decode([Endpoint].self, from: data) else { return }
        DispatchQueue.main.async { [store] in
            store.replaceAll(list)
        }
    }
}
#else
public final class EndpointSyncBridge {
    public init(store: EndpointStore) {}
    public func push() {}
}
#endif
