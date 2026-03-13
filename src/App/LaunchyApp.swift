import SwiftUI

#if os(macOS)
    import AppKit

    final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
        private var clickOutsideMonitor: Any?

        func applicationDidFinishLaunching(_ notification: Notification) {
            let hotkeyService = GlobalHotkeyService.shared
            hotkeyService.onToggle = { [weak self] in
                self?.toggleLauncher()
            }
            hotkeyService.start()

            let trackpadService = TrackpadGestureService.shared
            trackpadService.onPinchIn = { [weak self] in
                self?.toggleLauncher()
            }
            trackpadService.start()

            MenuBarService.shared.setup()

            NotificationCenter.default.addObserver(
                forName: .menuBarToggleLauncher,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.toggleLauncher()
                }
            }

            clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.handleClickOutside()
                }
            }
        }

        func applicationWillTerminate(_ notification: Notification) {
            if let monitor = clickOutsideMonitor {
                NSEvent.removeMonitor(monitor)
                clickOutsideMonitor = nil
            }
            NSApp.presentationOptions = []
            GlobalHotkeyService.shared.stop()
            TrackpadGestureService.shared.stop()
            MenuBarService.shared.teardown()
        }

        /// When the user clicks the dock icon while the app is already running
        /// but the window is hidden, bring it back on screen.
        func applicationShouldHandleReopen(
            _ sender: NSApplication,
            hasVisibleWindows flag: Bool
        )
            -> Bool
        {
            if !flag {
                showLauncherWindow()
            }
            return true
        }

        /// Dismisses the launcher when a click is detected outside the app window.
        @MainActor private func handleClickOutside() {
            guard
                let window = NSApp.windows.first(where: {
                    $0.identifier?.rawValue == "dev.lbenicio.launchy.main"
                }),
                window.isVisible,
                window.alphaValue > 0
            else { return }
            NotificationCenter.default.post(name: .dismissLauncher, object: nil)
        }

        @MainActor private func toggleLauncher() {
            guard
                let window = NSApp.windows.first(where: {
                    $0.identifier?.rawValue == "dev.lbenicio.launchy.main"
                })
            else { return }

            if window.isVisible && window.alphaValue > 0 {
                // Dismiss the launcher
                NotificationCenter.default.post(name: .dismissLauncher, object: nil)
            } else {
                showLauncherWindow()
            }
        }

        @MainActor private func showLauncherWindow() {
            guard
                let window = NSApp.windows.first(where: {
                    $0.identifier?.rawValue == "dev.lbenicio.launchy.main"
                })
            else { return }
            window.alphaValue = 1
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()

            // Restore presentation options for full-screen layout
            // The WindowConfigurator will re-apply the correct options on the next
            // view update cycle, but we set a reasonable default here so the dock
            // and menubar hide immediately.
            NotificationCenter.default.post(name: .launcherDidReappear, object: nil)
        }
    }
#endif

@main
struct LaunchyApp: App {
    @StateObject private var settingsStore: GridSettingsStore
    @StateObject private var viewModel: LaunchyViewModel

    #if os(macOS)
        @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    #endif

    init() {
        let settings = GridSettingsStore()
        let dataStore = LaunchyDataStore()
        _settingsStore = StateObject(wrappedValue: settings)
        _viewModel = StateObject(
            wrappedValue: LaunchyViewModel(dataStore: dataStore, settingsStore: settings)
        )

        #if os(macOS)
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate()
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            LaunchyRootView(viewModel: viewModel)
                .environmentObject(settingsStore)
        }
        .commands {
            // Replace the default Preferences/Settings menu item with one
            // that toggles the in-app overlay instead of opening a separate window.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NotificationCenter.default.post(name: .toggleInAppSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .appSettings) {
                Button(viewModel.isEditing ? "Exit Wiggle Mode" : "Enter Wiggle Mode") {
                    viewModel.toggleEditing()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(viewModel.presentedFolderID != nil)
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    viewModel.undo()
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!viewModel.undoManager.canUndo)

                Button("Redo") {
                    viewModel.redo()
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!viewModel.undoManager.canRedo)
            }
        }
    }
}

extension Notification.Name {
    static let toggleInAppSettings = Notification.Name("toggleInAppSettings")
    static let launcherDidReappear = Notification.Name("launcherDidReappear")
    static let dismissLauncher = Notification.Name("dismissLauncher")
    static let resetToDefaultLayout = Notification.Name("resetToDefaultLayout")
    static let menuBarToggleLauncher = Notification.Name("menuBarToggleLauncher")
    static let exportLayout = Notification.Name("exportLayout")
    static let importLayout = Notification.Name("importLayout")
    static let sortAlphabetically = Notification.Name("sortAlphabetically")
}
