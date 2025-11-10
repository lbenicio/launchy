// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Single source-of-truth for package version used by build scripts or about dialogs.
let packageVersion = "0.0.1"

let package = Package(
    name: "TahoeLaunchpad",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TahoeLaunchpad", targets: ["TahoeLaunchpad"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "TahoeLaunchpad",
            path: "src"
        )
    ]
)
