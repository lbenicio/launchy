// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LaunchpadClone",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "LaunchpadClone",
            targets: ["LaunchpadCloneApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "LaunchpadCloneApp",
            path: "Sources/LaunchpadCloneApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        )
    ]
)
