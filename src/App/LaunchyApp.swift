import Combine
import SwiftUI

#if os(macOS)
    import AppKit

    final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {
        private var cancellables: Set<AnyCancellable> = []

        func applicationDidFinishLaunching(_ notification: Notification) {
            let trackpadService = TrackpadGestureService.shared
            trackpadService.onPinchIn = {
                // Pinch-in for previous page
                AppCoordinator.shared.send(.navigatePrevious)
            }
            trackpadService.onPinchOut = {
                // Pinch-out for next page
                AppCoordinator.shared.send(.navigateNext)
            }
            trackpadService.start()

            // Make app come to front on launch
            NSApp.activate(ignoringOtherApps: true)

            // Set up basic app behavior - no background services needed
            AppCoordinator.shared.events
                .sink { _ in }
                .store(in: &cancellables)
        }

        func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
            .terminateNow
        }

        func applicationWillTerminate(_ notification: Notification) {
            // Clean up any resources
            TrackpadGestureService.shared.stop()
        }

        /// When window closes, quit the app
        func applicationShouldHandleReopen(
            _ sender: NSApplication,
            hasVisibleWindows flag: Bool
        ) -> Bool {
            !flag  // If no windows are visible, show a new one
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
                    AppCoordinator.shared.send(.toggleSettings)
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
