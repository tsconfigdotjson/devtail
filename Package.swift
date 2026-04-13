// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "devtail",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "DevtailKit"
        ),
        .executableTarget(
            name: "devtail",
            dependencies: ["DevtailKit"]
        ),
        .testTarget(
            name: "DevtailKitTests",
            dependencies: ["DevtailKit"]
        ),
        .testTarget(
            name: "devtailAppTests",
            dependencies: ["devtail", "DevtailKit"]
        ),
    ]
)
