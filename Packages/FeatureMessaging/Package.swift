// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FeatureMessaging",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FeatureMessaging", targets: ["FeatureMessaging"]),
    ],
    dependencies: [
        .package(path: "../SplickCore"),
        .package(path: "../SplickDomain"),
        .package(path: "../FeatureStickers"),
    ],
    targets: [
        .target(
            name: "FeatureMessaging",
            dependencies: [
                .product(name: "Networking", package: "SplickCore"),
                .product(name: "Storage", package: "SplickCore"),
                .product(name: "DesignSystem", package: "SplickCore"),
                .product(name: "Common", package: "SplickCore"),
                .product(name: "Localization", package: "SplickCore"),
                .product(name: "SplickDomain", package: "SplickDomain"),
                .product(name: "FeatureStickers", package: "FeatureStickers"),
            ],
            path: "Sources/FeatureMessaging"
        ),
        .testTarget(
            name: "FeatureMessagingTests",
            dependencies: [
                "FeatureMessaging",
                .product(name: "Common", package: "SplickCore"),
                .product(name: "Localization", package: "SplickCore"),
                .product(name: "Storage", package: "SplickCore"),
                .product(name: "Networking", package: "SplickCore"),
            ],
            path: "Tests/FeatureMessagingTests"
        ),
    ]
)
