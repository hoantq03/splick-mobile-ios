// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "SplickDomain",
    platforms: [.iOS(.v16)],
    products: [
        .library(name: "SplickDomain", targets: ["SplickDomain"]),
    ],
    targets: [
        .target(
            name: "SplickDomain",
            path: "Sources/SplickDomain"
        ),
    ]
)
