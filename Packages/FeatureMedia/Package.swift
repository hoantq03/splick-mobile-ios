// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FeatureMedia",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "FeatureMedia", targets: ["FeatureMedia"]),
    ],
    dependencies: [
        .package(path: "../SplickCore"),
        .package(path: "../SplickDomain"),
    ],
    targets: [
        .target(
            name: "FeatureMedia",
            dependencies: [
                .product(name: "Networking", package: "SplickCore"),
                .product(name: "Storage", package: "SplickCore"),
                .product(name: "DesignSystem", package: "SplickCore"),
                .product(name: "Common", package: "SplickCore"),
                .product(name: "SplickDomain", package: "SplickDomain"),
            ],
            path: "Sources/FeatureMedia"
        ),
    ]
)
