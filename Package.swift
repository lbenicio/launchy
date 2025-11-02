// swift-tools-version: 5.9
import Foundation
import PackageDescription

private func computeExcludeList(for targetPath: String) -> [String] {
  let fm = FileManager.default
  var excludes: [String] = []
  let resourcesPath = "\(targetPath)/Resources"
  if fm.fileExists(atPath: resourcesPath) {
    excludes.append("Resources")
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
