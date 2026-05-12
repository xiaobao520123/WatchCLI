import Foundation
import WatchCLIProtocol

// Stub entrypoint for P1. Real Hummingbird WebSocket server lands in P2.
// (Using main.swift top-level form — no @main needed.)
let version = "0.1.0-dev"
FileHandle.standardError.write(Data("watchcli-daemon \(version) (protocol v\(ProtocolVersion.current))\n".utf8))
FileHandle.standardError.write(Data("P1 scaffold: server not yet wired up. Run `swift test` to verify protocol.\n".utf8))
