import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity

/// Bridges `EndpointStore` AND `Preferences` between the iOS companion and
/// the watchOS app using `WCSession.updateApplicationContext`. The
/// application context is the right primitive here because we only need
/// the *latest* set of endpoints + prefs; transferring large or queued
/// payloads is unnecessary.
public final class EndpointSyncBridge: NSObject, WCSessionDelegate, @unchecked Sendable {
    private let store: EndpointStore
    private let prefs: Preferences?
    private let session: WCSession

    public init(store: EndpointStore, prefs: Preferences? = nil, session: WCSession = .default) {
        self.store = store
        self.prefs = prefs
        self.session = session
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    public func push() {
        guard WCSession.isSupported(), session.activationState == .activated else { return }
        do {
            var ctx: [String: Any] = [:]
            let data = try JSONEncoder().encode(store.endpoints)
            ctx["endpoints"] = data
            if let prefs { ctx["prefs"] = prefs.toContext() }
            try session.updateApplicationContext(ctx)
        } catch {
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
        if let data = applicationContext["endpoints"] as? Data,
           let list = try? JSONDecoder().decode([Endpoint].self, from: data) {
            DispatchQueue.main.async { [store] in store.replaceAll(list) }
        }
        if let prefs {
            // Encode the prefs slice to a Sendable JSON Data so it crosses the
            // actor hop without tripping Swift 6 strict-concurrency checks.
            if let prefDict = applicationContext["prefs"] as? [String: Any],
               let prefData = try? JSONSerialization.data(withJSONObject: prefDict) {
                DispatchQueue.main.async { [prefs] in
                    if let parsed = try? JSONSerialization.jsonObject(with: prefData) as? [String: Any] {
                        prefs.absorb(parsed)
                    }
                }
            }
        }
    }
}
#else
public final class EndpointSyncBridge {
    public init(store: EndpointStore, prefs: Preferences? = nil) {}
    public func push() {}
}
#endif
