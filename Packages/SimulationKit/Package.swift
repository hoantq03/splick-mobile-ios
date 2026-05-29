// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SimulationKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SimulationKit", targets: ["SimulationKit"]),
        .executable(name: "Sandbox", targets: ["Sandbox"]),
    ],
    dependencies: [
        .package(path: "../SplickCore"),
        .package(path: "../SplickDomain"),
        .package(path: "../FeatureSocialFeed"),
        .package(path: "../FeatureExpense"),
        .package(path: "../FeatureNotification"),
        .package(path: "../FeatureMedia"),
        .package(path: "../FeatureFriends"),
    ],
    targets: [
        .target(
            name: "SimulationKit",
            dependencies: [
                .product(name: "Networking", package: "SplickCore"),
                .product(name: "Storage", package: "SplickCore"),
                .product(name: "Common", package: "SplickCore"),
                .product(name: "SplickDomain", package: "SplickDomain"),
                .product(name: "FeatureSocialFeed", package: "FeatureSocialFeed"),
                .product(name: "FeatureExpense", package: "FeatureExpense"),
                .product(name: "FeatureNotification", package: "FeatureNotification"),
                .product(name: "FeatureMedia", package: "FeatureMedia"),
                .product(name: "FeatureFriends", package: "FeatureFriends"),
            ],
            path: "Sources/SimulationKit"
        ),
        .executableTarget(
            name: "Sandbox",
            dependencies: ["SimulationKit"],
            path: "Sources/Sandbox"
        ),
    ]
)
