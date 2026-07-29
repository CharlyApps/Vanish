// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Vanish",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Vanish"),
        .testTarget(name: "VanishTests", dependencies: ["Vanish"]),
    ]
)
