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

        /// Fetches badge counts for running applications by querying `lsappinfo`.
        ///
        /// `lsappinfo info -only StatusLabel -app <bundleID>` returns output like:
        /// ```
        /// "StatusLabel" = { "label"="3" }
        /// ```
        /// when an app has a badge set on its dock icon. We parse the label value
        /// out of that response for every regular (dock-visible) running application.
        nonisolated private static func fetchBadgeCounts() -> [String: String] {
            var result: [String: String] = [:]

            let apps = NSWorkspace.shared.runningApplications
            for app in apps {
                guard let bundleID = app.bundleIdentifier else { continue }
                // Only check regular apps (those that appear in the Dock)
                guard app.activationPolicy == .regular else { continue }

                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/bin/lsappinfo")
                task.arguments = ["info", "-only", "StatusLabel", "-app", bundleID]

                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = FileHandle.nullDevice

                do {
                    try task.run()
                    task.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    guard let output = String(data: data, encoding: .utf8) else { continue }

                    // Expected format: "StatusLabel"={ "label"="3" }
                    // Also handles:    "StatusLabel"={ "label"="New" }
                    if let labelRange = output.range(of: "\"label\"=\""),
                        let endRange = output[labelRange.upperBound...].range(of: "\"")
                    {
                        let badge = String(output[labelRange.upperBound..<endRange.lowerBound])
                        if !badge.isEmpty {
                            result[bundleID] = badge
                        }
                    }
                } catch {
                    // Silently skip apps we can't query
                    continue
                }
            }

            return result
        }
    #endif
}
