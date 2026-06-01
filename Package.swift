// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacApps",
    platforms: [
        .macOS(.v15)
    ],
    targets: [
        .executableTarget(
            name: "MacApps",
            path: "Sources/MacApps"
        )
    ]
)
