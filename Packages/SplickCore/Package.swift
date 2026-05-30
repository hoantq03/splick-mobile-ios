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
        .library(name: "Localization", targets: ["Localization"]),
    ],
    dependencies: [
        .package(path: "../SplickDomain"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.8.0"),
    ],
    targets: [
        .target(
            name: "Common",
            path: "Sources/Common"
        ),
        .target(
            name: "Localization",
            dependencies: ["Common", "Storage"],
            path: "Sources/Localization"
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
                "Localization",
                .product(name: "SplickDomain", package: "SplickDomain"),
                .product(name: "NukeUI", package: "Nuke"),
            ],
            path: "Sources/DesignSystem",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "LocalizationTests",
            dependencies: ["Localization"],
            path: "Tests/LocalizationTests"
        ),
    ]
)
