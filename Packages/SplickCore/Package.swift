// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplickCore",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "Networking", targets: ["Networking"]),
        .library(name: "Storage", targets: ["Storage"]),
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
        .library(name: "Common", targets: ["Common"]),
    ],
    targets: [
        .target(
            name: "Common",
            path: "Sources/Common"
        ),
        .target(
            name: "Networking",
            dependencies: ["Common"],
            path: "Sources/Networking"
        ),
        .target(
            name: "Storage",
            dependencies: ["Common"],
            path: "Sources/Storage"
        ),
        .target(
            name: "DesignSystem",
            dependencies: ["Common"],
            path: "Sources/DesignSystem",
            resources: [.process("Resources")]
        ),
    ]
)
