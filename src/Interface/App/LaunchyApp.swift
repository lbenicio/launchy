import AppKit
import SwiftUI

@main
struct LaunchyApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @StateObject private var catalogStore = AppCatalogStore()
    @StateObject private var settings = AppSettings()

    init() {
        appDelegate.activationHandler = {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
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
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
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
            CommandMenu("Catalog") {
                Button("Reload Catalog") {
                    Task { await catalogStore.reloadCatalog() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
        Settings {
            SettingsView()
                .environmentObject(settings)
                .frame(width: 320)
                .padding(20)
        }
    }

    private func openSettingsWindow() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    var activationHandler: (() -> Void)?

    private var storedPresentationOptions: NSApplication.PresentationOptions = []
    private var presentationStored = false
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .vibrantDark)
        setupStatusItem()
        NSApp.activate(ignoringOtherApps: true)
        AccessibilityPermission.requestIfNeeded()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        guard let window = NSApp.windows.first else { return }
        if !presentationStored {
            storedPresentationOptions = NSApp.presentationOptions
            presentationStored = true
        }
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func applicationDidResignActive(_ notification: Notification) {
        restorePresentationOptions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        restorePresentationOptions()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

    @objc private func openMainWindow() {
        activationHandler?()
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func restorePresentationOptions() {
        guard presentationStored else { return }
        NSApp.presentationOptions = storedPresentationOptions
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = makeStatusMenu()
        if let button = statusItem.button {
            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                let image = NSImage(contentsOf: iconURL)
            {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Launchy"
            }
        }
        self.statusItem = statusItem
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Open Launchy", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Launchy", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }
}
