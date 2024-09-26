// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Reorderable",
    platforms: [
      .iOS(SupportedPlatform.IOSVersion.v18),
    ],
    products: [
        .library(
            name: "Reorderable",
            targets: ["Reorderable"]),
    ],
    targets: [
        .target(
            name: "Reorderable"),
    ]
)
