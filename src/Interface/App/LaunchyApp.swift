import AppKit
import SwiftUI

@main
struct LaunchyApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @StateObject private var catalogStore: AppCatalogStore
    @StateObject private var settings: AppSettings

    init() {
        let store = AppCatalogStore()
        let appSettings = AppSettings()
        _catalogStore = StateObject(wrappedValue: store)
        _settings = StateObject(wrappedValue: appSettings)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(catalogStore)
                .environmentObject(settings)
                .background(
                    VisualEffectView(
                        material: .fullScreenUI,
                        blendingMode: .behindWindow
                    )
                )
                .ignoresSafeArea()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Launchy") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            CommandGroup(after: .appTermination) {
                Button("Close Launchy") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("w", modifiers: [.command])
            }
            CommandMenu("Catalog") {
                Button("Reload Catalog") {
                    Task { await catalogStore.reloadCatalog() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }

    @MainActor
    private func openSettingsWindow() {
        SettingsWindowManager.shared.settingsProvider = { settings }
        SettingsWindowManager.shared.show()
    }
}

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    private var storedPresentationOptions: NSApplication.PresentationOptions = []
    private var presentationStored = false

    override init() {
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .vibrantDark)
        NSApp.setActivationPolicy(.regular)
        AccessibilityPermission.requestIfNeeded()
        Task { @MainActor in
            self.showPrimaryWindow()
        }
    }

    @MainActor
    func applicationDidBecomeActive(_ notification: Notification) {
        guard let window = primaryWindow else { return }
        if !presentationStored {
            storedPresentationOptions = NSApp.presentationOptions
            presentationStored = true
        }
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
        window.setIsVisible(true)
        window.alphaValue = 1
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationDidResignActive(_ notification: Notification) {
        restorePresentationOptions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        restorePresentationOptions()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool)
        -> Bool {
        Task { @MainActor in
            self.showPrimaryWindow()
        }
        return false
    }

    @MainActor
    private func showPrimaryWindow() {
        guard let window = primaryWindow else { return }
        window.setIsVisible(true)
        window.alphaValue = 1
        window.isReleasedWhenClosed = false
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func restorePresentationOptions() {
        guard presentationStored else { return }
        NSApp.presentationOptions = storedPresentationOptions
    }

    private var primaryWindow: NSWindow? {
        NSApp.windows.first { $0.level == .launchyPrimary }
    }
}
