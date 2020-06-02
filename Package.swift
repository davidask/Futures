// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "Futures",
    platforms: [
        .macOS(.v10_10),
        .iOS(.v8),
        .tvOS(.v9),
        .watchOS(.v2)
    ],
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
