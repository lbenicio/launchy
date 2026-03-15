import Combine
import Foundation

/// Typed, Combine-based replacement for the stringly-keyed `NotificationCenter` event bus.
/// All cross-cutting app-level events route through this singleton so callers use
/// `AppCoordinator.shared.send(_:)` and subscribers use `.onReceive(AppCoordinator.shared.events)`.
@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    private let subject = PassthroughSubject<AppEvent, Never>()

    var events: AnyPublisher<AppEvent, Never> {
        subject.eraseToAnyPublisher()
    }

    func send(_ event: AppEvent) {
        subject.send(event)
    }

    private init() {}
}

/// All app-level events that were previously scattered across `Notification.Name` constants.
enum AppEvent: Sendable, Equatable {
    /// Toggle the in-app settings overlay (Cmd+,).
    case toggleSettings
    /// The launcher window was shown again after being hidden.
    case launcherDidReappear
    /// Request to hide the launcher window.
    case dismissLauncher
    /// Reset the grid to the default factory layout.
    case resetToDefaultLayout
    /// Export the current layout to a file.
    case exportLayout
    /// Import a layout from a file.
    case importLayout
    /// Sort all top-level items and folder contents alphabetically.
    case sortAlphabetically
    /// The menu-bar icon was clicked; toggle launcher visibility.
    case menuBarToggleLauncher
    /// Import the Launchpad layout from the macOS Dock SQLite database.
    case importFromLaunchpad
    /// The launcher window finished its close animation; the previous app should regain focus.
    case launcherDidDismiss
}
