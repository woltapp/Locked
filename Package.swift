// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Locked",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: [
        .library(
            name: "Locked",
            targets: ["Locked"]
        ),
    ],
    targets: [
        .target(
            name: "Locked"
        )
    ]
)
