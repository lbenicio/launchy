import Combine
import Foundation

#if os(macOS)
    import AppKit
#endif

@MainActor
final class NotificationBadgeProvider: ObservableObject {
    static let shared = NotificationBadgeProvider()

    /// Maps bundle identifier to badge label string (e.g. "3", "!", etc.)
    @Published private(set) var badges: [String: String] = [:]

    private var pollTask: Task<Void, Never>?

    private init() {
        #if os(macOS)
            startPolling()
        #endif
    }

    #if os(macOS)
        private func startPolling() {
            refreshBadges()
            pollTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(8))
                    guard !Task.isCancelled else { break }
                    self?.refreshBadges()
                }
            }
        }

        private func refreshBadges() {
            Task.detached(priority: .utility) {
                let result = Self.fetchBadgeCounts()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.badges = result
                }
            }
        }

        /// Fetches badge counts for all running applications using a single
        /// `lsappinfo list` invocation instead of one process per app.
        ///
        /// - Note: `lsappinfo` is a private Apple binary. If it stops existing in a
        ///   future macOS release this function silently returns an empty dictionary,
        ///   so badges simply disappear rather than crashing.
        nonisolated private static func fetchBadgeCounts() -> [String: String] {
            let binaryPath = "/usr/bin/lsappinfo"
            guard FileManager.default.fileExists(atPath: binaryPath) else { return [:] }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: binaryPath)
            task.arguments = ["list", "-only", "StatusLabel"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                return [:]
            }

            guard task.terminationStatus == 0 else { return [:] }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return [:] }

            var result: [String: String] = [:]
            var currentBundleID: String?

            for line in output.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Match bundleID="com.example.app"
                if let range = trimmed.range(of: "bundleID=\""),
                    let endRange = trimmed[range.upperBound...].range(of: "\"")
                {
                    currentBundleID = String(trimmed[range.upperBound..<endRange.lowerBound])
                }

                // Match "StatusLabel"={ "label"="3" }
                if let bundleID = currentBundleID,
                    let labelRange = trimmed.range(of: "\"label\"=\""),
                    let endRange = trimmed[labelRange.upperBound...].range(of: "\"")
                {
                    let badge = String(trimmed[labelRange.upperBound..<endRange.lowerBound])
                    if !badge.isEmpty {
                        result[bundleID] = badge
                    }
                    currentBundleID = nil
                }
            }

            return result
        }
    #endif
}
