// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplickWidgetKit",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SplickWidgetKit", targets: ["SplickWidgetKit"]),
    ],
    dependencies: [
        .package(path: "../SplickDomain"),
    ],
    targets: [
        .target(
            name: "SplickWidgetKit",
            dependencies: [
                .product(name: "SplickDomain", package: "SplickDomain"),
            ],
            path: "Sources/SplickWidgetKit"
        ),
        .testTarget(
            name: "SplickWidgetKitTests",
            dependencies: ["SplickWidgetKit"],
            path: "Tests/SplickWidgetKitTests"
        ),
    ]
)
