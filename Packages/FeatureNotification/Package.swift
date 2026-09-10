// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FeatureNotification",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FeatureNotification", targets: ["FeatureNotification"]),
    ],
    dependencies: [
        .package(path: "../SplickCore"),
        .package(path: "../SplickDomain"),
    ],
    targets: [
        .target(
            name: "FeatureNotification",
            dependencies: [
                .product(name: "Networking", package: "SplickCore"),
                .product(name: "Storage", package: "SplickCore"),
                .product(name: "DesignSystem", package: "SplickCore"),
                .product(name: "Common", package: "SplickCore"),
                .product(name: "Localization", package: "SplickCore"),
                .product(name: "SplickDomain", package: "SplickDomain"),
            ],
            path: "Sources/FeatureNotification"
        ),
    ]
)
