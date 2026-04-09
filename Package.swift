// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "devtail",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "devtail"
        ),
    ]
)
