import AppKit
import SwiftUI

@MainActor
final class SettingsWindowManager: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowManager()

    var settingsProvider: (() -> AppSettings)?

    private weak var windowController: NSWindowController?

    func show() {
        guard let settings = settingsProvider?() else {
            return
        }

        if let window = windowController?.window {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = makeController(with: settings)
        controller.showWindow(nil)
        windowController = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeController(with settings: AppSettings) -> NSWindowController {
        let rootView = SettingsView()
            .environmentObject(settings)

        let hostingView = NSHostingView(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 240),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        window.center()
        window.level = .launchyAuxiliary
        window.collectionBehavior.insert(.fullScreenAuxiliary)
        window.delegate = self

        let controller = NSWindowController(window: window)
        return controller
    }

    func windowWillClose(_ notification: Notification) {
        windowController = nil
    }
}
