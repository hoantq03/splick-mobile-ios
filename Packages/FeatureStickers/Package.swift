// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FeatureStickers",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FeatureStickers", targets: ["FeatureStickers"]),
    ],
    dependencies: [
        .package(path: "../SplickCore"),
        .package(path: "../SplickDomain"),
        .package(path: "../FeatureMedia"),
    ],
    targets: [
        .target(
            name: "FeatureStickers",
            dependencies: [
                .product(name: "Networking", package: "SplickCore"),
                .product(name: "DesignSystem", package: "SplickCore"),
                .product(name: "Common", package: "SplickCore"),
                .product(name: "Localization", package: "SplickCore"),
                .product(name: "SplickDomain", package: "SplickDomain"),
                .product(name: "FeatureMedia", package: "FeatureMedia"),
            ],
            path: "Sources/FeatureStickers"
        ),
        .testTarget(
            name: "FeatureStickersTests",
            dependencies: [
                "FeatureStickers",
                .product(name: "DesignSystem", package: "SplickCore"),
            ],
            path: "Tests/FeatureStickersTests"
        ),
    ]
)
