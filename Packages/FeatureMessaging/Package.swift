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
            ],
            path: "Sources/FeatureMessaging"
        ),
        .testTarget(
            name: "FeatureMessagingTests",
            dependencies: ["FeatureMessaging"],
            path: "Tests/FeatureMessagingTests"
        ),
    ]
)
