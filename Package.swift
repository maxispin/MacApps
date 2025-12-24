// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacApps",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "MacApps",
            path: "Sources/MacApps"
        )
    ]
)
