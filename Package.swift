// swift-tools-version: 5.9
import Foundation
import PackageDescription

// Single source-of-truth for package version used by build scripts or about dialogs.
let packageVersion = "0.1.5"

let package = Package(
  name: "Launchy",
  platforms: [
    .macOS(.v13)
  ],
  products: [
    .executable(
      name: "Launchy",
      targets: ["Launchy"]
    )
  ],
  targets: [
    .executableTarget(
      name: "Launchy",
      path: "src",
      exclude: computeExcludeList(for: "src"),
      linkerSettings: [
        .linkedFramework("AppKit"),
        .linkedFramework("SwiftUI"),
        .linkedFramework("ApplicationServices"),
      ]
    )
  ]
)

private func computeExcludeList(for targetPath: String) -> [String] {
  let fm = FileManager.default
  var excludes: [String] = []
  let resourcesPath = "\(targetPath)/assets"
  if fm.fileExists(atPath: resourcesPath) {
    excludes.append("assets")
  }
  if let enumerator = fm.enumerator(atPath: targetPath) {
    for case let file as String in enumerator {
      if file.hasSuffix("/.DS_Store") || file == ".DS_Store" {
        excludes.append("\(targetPath)/\(file)")
      }
    }
  }
  return excludes
}