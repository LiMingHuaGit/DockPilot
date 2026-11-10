// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "DockPilot",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DockPilot",
            path: "Sources/DockPilot",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
