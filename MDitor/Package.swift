// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MDitor",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "MDitorCore"),
        .executableTarget(name: "MDitor", dependencies: ["MDitorCore"]),
        .testTarget(name: "MDitorCoreTests", dependencies: ["MDitorCore"]),
    ]
)
