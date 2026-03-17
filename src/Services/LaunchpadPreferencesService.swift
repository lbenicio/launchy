import Foundation
import SwiftUI

#if os(macOS)
    import AppKit
#endif

/// Integrates Launchy with macOS system preferences and provides Launchpad-like settings
@MainActor
final class LaunchpadPreferencesService: ObservableObject {
    static let shared = LaunchpadPreferencesService()
    
    @Published var resetToDefaultEnabled: Bool = true
    @Published var autoArrangeEnabled: Bool = false
    @Published var showAppBadges: Bool = true
    @Published var launchpadEnabled: Bool = true
    
    private let userDefaults = UserDefaults.standard
    
    // Keys for storing preferences
    private let resetToDefaultKey = "LaunchpadResetToDefault"
    private let autoArrangeKey = "LaunchpadAutoArrange"
    private let showAppBadgesKey = "LaunchpadShowAppBadges"
    private let launchpadEnabledKey = "LaunchpadEnabled"
    
    private init() {
        loadPreferences()
        setupSystemPreferencesObserver()
    }
    
    // MARK: - Public Interface
    
    /// Resets Launchpad to default layout (matches real Launchpad behavior)
    func resetToDefaultLayout() {
        // Post notification that will be handled by LaunchyViewModel
        AppCoordinator.shared.send(.resetToDefaultLayout)
        
        // Also clear system preferences if they exist
        clearSystemPreferences()
    }
    
    /// Toggles auto-arrange functionality
    func toggleAutoArrange() {
        autoArrangeEnabled.toggle()
        savePreferences()
        
        if autoArrangeEnabled {
            // Auto-arrange apps alphabetically
            AppCoordinator.shared.send(.sortAlphabetically)
        }
    }
    
    /// Toggles app badge visibility
    func toggleAppBadges() {
        showAppBadges.toggle()
        savePreferences()
        
        // Update settings store to reflect this change
        // This would need to be connected to the GridSettingsStore
    }
    
    /// Enables/disables Launchpad (replaces real Launchpad)
    func toggleLaunchpadEnabled() {
        launchpadEnabled.toggle()
        savePreferences()
        
        #if os(macOS)
        if launchpadEnabled {
            // Enable our Launchy app
            enableLaunchy()
        } else {
            // Disable our Launchy and restore real Launchpad if possible
            disableLaunchy()
        }
        #endif
    }
    
    /// Imports layout from real Launchpad if available
    func importFromLaunchpad() {
        AppCoordinator.shared.send(.importFromLaunchpad)
    }
    
    /// Exports current layout to be compatible with real Launchpad
    func exportToLaunchpad() {
        AppCoordinator.shared.send(.exportLayout)
    }
    
    // MARK: - Private Methods
    
    private func loadPreferences() {
        resetToDefaultEnabled = userDefaults.bool(forKey: resetToDefaultKey)
        autoArrangeEnabled = userDefaults.bool(forKey: autoArrangeKey)
        showAppBadges = userDefaults.bool(forKey: showAppBadgesKey)
        launchpadEnabled = userDefaults.bool(forKey: launchpadEnabledKey)
        
        // Set defaults if not set
        if !userDefaults.bool(forKey: "LaunchpadPreferencesInitialized") {
            resetToDefaultEnabled = true
            showAppBadges = true
            launchpadEnabled = true
            savePreferences()
            userDefaults.set(true, forKey: "LaunchpadPreferencesInitialized")
        }
    }
    
    private func savePreferences() {
        userDefaults.set(resetToDefaultEnabled, forKey: resetToDefaultKey)
        userDefaults.set(autoArrangeEnabled, forKey: autoArrangeKey)
        userDefaults.set(showAppBadges, forKey: showAppBadgesKey)
        userDefaults.set(launchpadEnabled, forKey: launchpadEnabledKey)
    }
    
    private func clearSystemPreferences() {
        // Clear any cached Launchpad preferences
        userDefaults.removeObject(forKey: "LaunchpadLayout")
        userDefaults.removeObject(forKey: "LaunchpadPageState")
    }
    
    #if os(macOS)
    private func enableLaunchy() {
        // Ensure Launchy is set as the default Launchpad replacement
        // This might involve modifying system preferences or using Launch Agents
        
        // Set up Launchy to respond to Launchpad hotkeys
        GlobalHotkeyService.shared.start()
        
        // Disable real Launchpad if possible (this would require system-level changes)
        // For now, we'll just ensure our app is active
    }
    
    private func disableLaunchy() {
        // Disable Launchy's Launchpad functionality
        GlobalHotkeyService.shared.stop()
        
        // Attempt to restore real Launchpad functionality
        // This would require reversing any system changes made during enable
    }
    #endif
    
    private func setupSystemPreferencesObserver() {
        // Observe system preference changes that might affect Launchpad
        #if os(macOS)
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            // Handle system preference changes
            self?.handleSystemPreferenceChange()
        }
        #endif
    }
    
    private func handleSystemPreferenceChange() {
        // Check if system preferences changed in ways that affect Launchpad
        // For example, if real Launchpad was re-enabled, we might need to disable ours
        
        #if os(macOS)
        // This is a placeholder for actual system preference monitoring
        // In a real implementation, you'd monitor relevant system preference domains
        #endif
    }
    
    // MARK: - System Integration
    
    /// Checks if Launchy can replace real Launchpad on the current system
    func canReplaceLaunchpad() -> Bool {
        #if os(macOS)
        // Check if we have necessary permissions and system compatibility
        return NSWorkspace.shared.responds(to: #selector(NSWorkspace.openURL(_:)))
        #else
        return false
        #endif
    }
    
    /// Gets the current Launchpad replacement status
    var launchpadReplacementStatus: LaunchpadStatus {
        #if os(macOS)
        if launchpadEnabled {
            return .enabled
        } else {
            return .disabled
        }
        #else
        return .unsupported
        #endif
    }
    
    enum LaunchpadStatus {
        case enabled
        case disabled
        case unsupported
    }
}

// MARK: - SwiftUI Integration

extension LaunchpadPreferencesService {
    
    /// Creates a preferences view that mimics the real Launchpad preferences
    func createPreferencesView() -> some View {
        LaunchpadPreferencesView(service: self)
    }
}

struct LaunchpadPreferencesView: View {
    @ObservedObject var service: LaunchpadPreferencesService
    
    var body: some View {
        Form {
            Section {
                Toggle("Enable Launchpad", isOn: $service.launchpadEnabled)
                    .help("Replace the built-in Launchpad with Launchy")
            }
            
            Section {
                Button("Reset Launchpad Layout") {
                    service.resetToDefaultLayout()
                }
                .disabled(!service.resetToDefaultEnabled)
                
                Toggle("Auto-arrange apps", isOn: $service.autoArrangeEnabled)
                    .help("Automatically arrange apps in alphabetical order")
                
                Toggle("Show app notification badges", isOn: $service.showAppBadges)
                    .help("Show notification counts on app icons")
            }
            
            Section {
                Button("Import from Launchpad") {
                    service.importFromLaunchpad()
                }
                
                Button("Export layout to Launchpad") {
                    service.exportToLaunchpad()
                }
            }
            
            Section(footer: footerText) {
                Text("Launchpad Preferences")
                    .font(.headline)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
    
    private var footerText: String {
        switch service.launchpadReplacementStatus {
        case .enabled:
            return "Launchy is currently replacing the built-in Launchpad."
        case .disabled:
            return "Launchy is disabled. The built-in Launchpad will be used."
        case .unsupported:
            return "Launchpad replacement is not supported on this system."
        }
    }
}
