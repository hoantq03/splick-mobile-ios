// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FeatureSocialFeed",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FeatureSocialFeed", targets: ["FeatureSocialFeed"]),
    ],
    dependencies: [
        .package(path: "../SplickCore"),
        .package(path: "../SplickDomain"),
        .package(path: "../FeatureFriends"),
        .package(path: "../FeatureMedia"),
    ],
    targets: [
        .target(
            name: "FeatureSocialFeed",
            dependencies: [
                .product(name: "Networking", package: "SplickCore"),
                .product(name: "Storage", package: "SplickCore"),
                .product(name: "DesignSystem", package: "SplickCore"),
                .product(name: "Common", package: "SplickCore"),
                .product(name: "Localization", package: "SplickCore"),
                .product(name: "SplickDomain", package: "SplickDomain"),
                .product(name: "FeatureFriends", package: "FeatureFriends"),
                .product(name: "FeatureMedia", package: "FeatureMedia"),
            ],
            path: "Sources/FeatureSocialFeed"
        ),
    ]
)
