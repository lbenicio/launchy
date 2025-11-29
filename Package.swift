// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Single source-of-truth for package version used by build scripts or about dialogs.
let packageVersion = "0.4.0"

let package = Package(
    name: "Launchy",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Launchy", targets: ["Launchy"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Launchy",
            path: "src"
        ),
        .testTarget(
            name: "LaunchyTests",
            dependencies: ["Launchy"],
            path: "tests"
        )
    ]
)
