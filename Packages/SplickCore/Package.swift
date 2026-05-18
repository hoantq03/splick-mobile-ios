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
    dependencies: [
        .package(path: "../SplickDomain"),
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
            dependencies: [
                "Common",
                .product(name: "SplickDomain", package: "SplickDomain"),
            ],
            path: "Sources/DesignSystem",
            resources: [.process("Resources")]
        ),
    ]
)
