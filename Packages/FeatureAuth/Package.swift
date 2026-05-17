// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FeatureAuth",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FeatureAuth", targets: ["FeatureAuth"]),
    ],
    dependencies: [
        .package(path: "../SplickCore"),
        .package(path: "../SplickDomain"),
    ],
    targets: [
        .target(
            name: "FeatureAuth",
            dependencies: [
                .product(name: "Networking", package: "SplickCore"),
                .product(name: "Storage", package: "SplickCore"),
                .product(name: "DesignSystem", package: "SplickCore"),
                .product(name: "Common", package: "SplickCore"),
                .product(name: "SplickDomain", package: "SplickDomain"),
            ],
            path: "Sources/FeatureAuth"
        ),
    ]
)
