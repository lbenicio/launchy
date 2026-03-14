import Foundation
import SwiftUI

#if os(macOS)
    import AppKit

    /// Manages a menu bar status item that provides quick access to Launchy
    /// and shows recently launched apps.
    @MainActor
    final class MenuBarService {
        static let shared = MenuBarService()

        private var statusItem: NSStatusItem?
        private var recentlyLaunched: [RecentApp] = []
        private let maxRecent: Int = 5

        struct RecentApp {
            let name: String
            let bundleIdentifier: String
            let bundleURL: URL
        }

        private init() {}

        /// Creates the status bar item. Call once at app launch.
        func setup() {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = item.button {
                button.image = NSImage(
                    systemSymbolName: "square.grid.3x3.fill",
                    accessibilityDescription: "Launchy"
                )
                button.image?.size = NSSize(width: 16, height: 16)
            }
            statusItem = item
            rebuildMenu()
        }

        /// Records an app launch for the recents list.
        func recordLaunch(name: String, bundleIdentifier: String, bundleURL: URL) {
            // Remove existing entry for this app if present
            recentlyLaunched.removeAll { $0.bundleIdentifier == bundleIdentifier }
            // Insert at front
            recentlyLaunched.insert(
                RecentApp(name: name, bundleIdentifier: bundleIdentifier, bundleURL: bundleURL),
                at: 0
            )
            // Trim
            if recentlyLaunched.count > maxRecent {
                recentlyLaunched = Array(recentlyLaunched.prefix(maxRecent))
            }
            rebuildMenu()
        }

        /// Removes the status item from the menu bar.
        func teardown() {
            if let item = statusItem {
                NSStatusBar.system.removeStatusItem(item)
            }
            statusItem = nil
        }

        private func rebuildMenu() {
            let menu = NSMenu()

            let toggleItem = NSMenuItem(
                title: "Toggle Launchy",
                action: #selector(MenuBarActionHandler.toggleLauncher),
                keyEquivalent: ""
            )
            toggleItem.target = MenuBarActionHandler.shared
            menu.addItem(toggleItem)

            menu.addItem(NSMenuItem.separator())

            if !recentlyLaunched.isEmpty {
                let headerItem = NSMenuItem(
                    title: "Recently Launched",
                    action: nil,
                    keyEquivalent: ""
                )
                headerItem.isEnabled = false
                menu.addItem(headerItem)

                for recent in recentlyLaunched {
                    let appItem = NSMenuItem(
                        title: recent.name,
                        action: #selector(MenuBarActionHandler.launchApp(_:)),
                        keyEquivalent: ""
                    )
                    appItem.target = MenuBarActionHandler.shared
                    appItem.representedObject = recent.bundleURL

                    // Load the app icon for the menu item
                    let icon = NSWorkspace.shared.icon(forFile: recent.bundleURL.path)
                    icon.size = NSSize(width: 16, height: 16)
                    appItem.image = icon

                    menu.addItem(appItem)
                }

                menu.addItem(NSMenuItem.separator())
            }

            let quitItem = NSMenuItem(
                title: "Quit Launchy",
                action: #selector(MenuBarActionHandler.quitApp),
                keyEquivalent: "q"
            )
            quitItem.target = MenuBarActionHandler.shared
            menu.addItem(quitItem)

            statusItem?.menu = menu
        }
    }

    /// Handles menu bar action selectors. Required because NSMenuItem targets
    /// must be `NSObject` subclasses with `@objc` methods.
    @MainActor
    final class MenuBarActionHandler: NSObject {
        static let shared = MenuBarActionHandler()

        @objc func toggleLauncher() {
            AppCoordinator.shared.send(.menuBarToggleLauncher)
        }

        @objc func launchApp(_ sender: NSMenuItem) {
            guard let url = sender.representedObject as? URL else { return }
            NSWorkspace.shared.openApplication(
                at: url,
                configuration: NSWorkspace.OpenConfiguration()
            ) { _, _ in }
        }

        @objc func quitApp() {
            NSApplication.shared.terminate(nil)
        }
    }
#endif
