// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "WatchCLI",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "WatchCLIProtocol", targets: ["WatchCLIProtocol"]),
        .executable(name: "watchcli-daemon", targets: ["WatchCLIDaemon"]),
    ],
    dependencies: [
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.5.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-websocket.git", from: "2.2.0"),
    ],
    targets: [
        .target(
            name: "WatchCLIProtocol",
            path: "Sources/WatchCLIProtocol"
        ),
        .target(
            name: "CWatchCLIPTY",
            path: "Sources/CWatchCLIPTY",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "WatchCLIDaemon",
            dependencies: [
                "WatchCLIProtocol",
                "CWatchCLIPTY",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdWebSocket", package: "hummingbird-websocket"),
            ],
            path: "Sources/WatchCLIDaemon"
        ),
        .testTarget(
            name: "WatchCLIProtocolTests",
            dependencies: ["WatchCLIProtocol"],
            path: "Tests/WatchCLIProtocolTests"
        ),
        .testTarget(
            name: "WatchCLIDaemonTests",
            dependencies: [
                "WatchCLIDaemon",
                "WatchCLIProtocol",
                "CWatchCLIPTY",
                .product(name: "HummingbirdWSClient", package: "hummingbird-websocket"),
            ],
            path: "Tests/WatchCLIDaemonTests"
        ),
    ]
)
