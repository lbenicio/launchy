import Combine
import Foundation

/// Syncs the Launchy layout to iCloud via `NSUbiquitousKeyValueStore`,
/// allowing the arrangement to follow the user across Macs.
///
/// The service stores the JSON-encoded `[LaunchyItem]` array under a single key.
/// Because `NSUbiquitousKeyValueStore` has a 1 MB per-key limit, this should
/// comfortably hold even very large layouts.
@MainActor
final class ICloudSyncService: ObservableObject {
    static let shared = ICloudSyncService()

    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncDate: Date? = nil

    private let store = NSUbiquitousKeyValueStore.default
    private let layoutKey = "dev.lbenicio.launchy.cloud-layout"
    private let timestampKey = "dev.lbenicio.launchy.cloud-timestamp"
    private var observer: Any?

    /// Called when a remote layout change is received. The caller should
    /// decide whether to merge or replace the local layout.
    var onRemoteChange: (([LaunchyItem]) -> Void)?

    private init() {}

    /// Starts listening for remote iCloud KV changes. Call once at app launch.
    func startObserving() {
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            Task { @MainActor in
                self?.handleRemoteChange(reason: reason)
            }
        }
        // Trigger an initial sync pull
        store.synchronize()
    }

    /// Stops listening for remote changes.
    func stopObserving() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    /// Uploads the current layout to iCloud.
    func upload(items: [LaunchyItem]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(items) else { return }

        isSyncing = true
        store.set(data, forKey: layoutKey)
        store.set(Date().timeIntervalSince1970, forKey: timestampKey)
        store.synchronize()
        lastSyncDate = Date()
        isSyncing = false
    }

    /// Downloads the layout from iCloud, if available.
    func download() -> [LaunchyItem]? {
        guard let data = store.data(forKey: layoutKey) else { return nil }
        return try? JSONDecoder().decode([LaunchyItem].self, from: data)
    }

    /// Returns the timestamp of the last iCloud upload, if available.
    func remoteTimestamp() -> Date? {
        let interval = store.double(forKey: timestampKey)
        return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
    }

    private func handleRemoteChange(reason: Int?) {
        guard let reason else { return }

        // Only act on server changes or initial sync
        switch reason {
        case NSUbiquitousKeyValueStoreServerChange,
            NSUbiquitousKeyValueStoreInitialSyncChange:
            guard let items = download() else { return }
            lastSyncDate = remoteTimestamp()
            onRemoteChange?(items)
        default:
            break
        }
    }
}
