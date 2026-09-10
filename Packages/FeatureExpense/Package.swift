// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "FeatureExpense",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "FeatureExpense", targets: ["FeatureExpense"]),
    ],
    dependencies: [
        .package(path: "../SplickCore"),
        .package(path: "../SplickDomain"),
        .package(path: "../FeatureFriends"),
    ],
    targets: [
        .target(
            name: "FeatureExpense",
            dependencies: [
                .product(name: "Networking", package: "SplickCore"),
                .product(name: "Storage", package: "SplickCore"),
                .product(name: "DesignSystem", package: "SplickCore"),
                .product(name: "Common", package: "SplickCore"),
                .product(name: "Localization", package: "SplickCore"),
                .product(name: "SplickDomain", package: "SplickDomain"),
                .product(name: "FeatureFriends", package: "FeatureFriends"),
            ],
            path: "Sources/FeatureExpense"
        ),
        .testTarget(
            name: "FeatureExpenseTests",
            dependencies: [
                "FeatureExpense",
                .product(name: "SplickDomain", package: "SplickDomain"),
                .product(name: "Localization", package: "SplickCore"),
                .product(name: "Storage", package: "SplickCore"),
            ],
            path: "Tests/FeatureExpenseTests"
        ),
    ]
)
