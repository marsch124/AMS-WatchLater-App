// swift-tools-version:5.9
import PackageDescription

// The model — everything the app knows about videos, with no screen in it.
// `swift test` here runs in seconds and needs no simulator.
let package = Package(
    name: "WatchLaterCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "WatchLaterCore", targets: ["WatchLaterCore"]),
    ],
    targets: [
        .target(name: "WatchLaterCore"),
        .testTarget(name: "WatchLaterCoreTests", dependencies: ["WatchLaterCore"]),
    ]
)
