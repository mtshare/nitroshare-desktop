// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "NitroShare",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "NitroShare",
            path: "Sources/NitroShare"
        )
    ]
)
