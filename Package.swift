// swift-tools-version:4.0

import PackageDescription

let package = Package(
    name: "Futures",
    products: [
        .library(
            name: "Futures",
            targets: ["Futures"])
    ],
    targets: [
        .target(
            name: "Futures",
            dependencies: []),
        .testTarget(
            name: "FuturesTests",
            dependencies: ["Futures"])
    ]
)
