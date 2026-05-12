import Foundation
import WatchCLIProtocol

import Foundation
import Hummingbird
import Logging
import WatchCLIProtocol

let args = Array(CommandLine.arguments.dropFirst())

let config: DaemonConfig
do {
    config = try DaemonConfig.parse(args)
} catch DaemonConfig.ArgError.helpRequested {
    print(DaemonConfig.helpText)
    exit(0)
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n\n".utf8))
    print(DaemonConfig.helpText)
    exit(2)
}

let token: String
do {
    token = try TokenStore.loadOrCreate(at: config.tokenFilePath)
} catch {
    FileHandle.standardError.write(Data("failed to load/create token at \(config.tokenFilePath): \(error)\n".utf8))
    exit(1)
}

var logger = Logger(label: "watchcli.daemon")
logger.logLevel = .info

logger.info("watchcli-daemon \(DaemonVersion.current) (protocol v\(ProtocolVersion.current))")
logger.info("listening on ws://\(config.host):\(config.port)/v1/session")
logger.info("token: \(token)   (stored at \(config.tokenFilePath))")
logger.info("agents: \(config.allowedAgents.sorted().joined(separator: ", "))")

let app = makeApplication(config: config, token: token, logger: logger)
try await app.runService()
