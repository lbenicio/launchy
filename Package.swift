// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

// Single source-of-truth for app name and version used by build scripts.
let appName = "Launchy"
let packageVersion = "1.0.0"

let package = Package(
    name: appName,
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: appName, targets: [appName])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: appName,
            path: "src",
            linkerSettings: [.linkedLibrary("sqlite3")]
        ),
        .testTarget(
            name: "\(appName)Tests",
            dependencies: [Target.Dependency(stringLiteral: appName)],
            path: "tests"
        ),
    ]
)
