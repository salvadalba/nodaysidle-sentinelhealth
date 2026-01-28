// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SentinelHealth",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "SentinelHealthCore",
            targets: ["SentinelHealthCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "SentinelHealthCore",
            dependencies: [],
            path: "Sources/SentinelHealthCore",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "SentinelHealthCoreTests",
            dependencies: ["SentinelHealthCore"],
            path: "Tests/SentinelHealthCoreTests"
        ),
    ]
)
