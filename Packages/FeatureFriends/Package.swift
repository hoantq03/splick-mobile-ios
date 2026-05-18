// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FeatureFriends",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FeatureFriends", targets: ["FeatureFriends"]),
    ],
    dependencies: [
        .package(path: "../SplickCore"),
        .package(path: "../SplickDomain"),
    ],
    targets: [
        .target(
            name: "FeatureFriends",
            dependencies: [
                .product(name: "Networking", package: "SplickCore"),
                .product(name: "DesignSystem", package: "SplickCore"),
                .product(name: "Common", package: "SplickCore"),
                .product(name: "SplickDomain", package: "SplickDomain"),
            ],
            path: "Sources/FeatureFriends"
        ),
    ]
)
