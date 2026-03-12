import SwiftUI

#if os(macOS)
    import AppKit

    final class AppDelegate: NSObject, NSApplicationDelegate {
        func applicationWillTerminate(_ notification: Notification) {
            NSApp.presentationOptions = []
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
            wrappedValue: LaunchyViewModel(dataStore: dataStore, settingsStore: settings))

        #if os(macOS)
            DispatchQueue.main.async {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            LaunchyRootView(viewModel: viewModel)
                .environmentObject(settingsStore)
        }
        .commands {
            CommandGroup(after: .appSettings) {
                Button(viewModel.isEditing ? "Exit Wiggle Mode" : "Enter Wiggle Mode") {
                    viewModel.toggleEditing()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(viewModel.presentedFolderID != nil)
            }
        }

        Settings {
            SettingsView(store: settingsStore)
                .frame(width: 680, height: 540)
        }
    }
}
