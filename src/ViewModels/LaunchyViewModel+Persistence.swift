import Foundation

// MARK: - Persistence (disk + iCloud)

extension LaunchyViewModel {

    /// Schedules a debounced save. Only the last call within the delay window persists to disk.
    func scheduleDebouncedSave() {
        saveDebouncerTask?.cancel()
        saveDebouncerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.saveDebouncerDelay ?? 0.5))
            guard !Task.isCancelled, let self else { return }
            self.dataStore.save(self.items)
        }
    }

    /// Persists the current item layout to disk immediately, cancelling any pending debounced save.
    func saveNow() {
        saveDebouncerTask?.cancel()
        saveDebouncerTask = nil
        dataStore.save(items)
        uploadToICloudIfNeeded()
    }

    // Internal — called from init in the core file.
    func setupICloudSync() {
        guard settingsStore.settings.iCloudSyncEnabled else { return }
        let syncService = ICloudSyncService.shared
        syncService.onRemoteChange = { [weak self] remoteItems in
            guard let self, self.settingsStore.settings.iCloudSyncEnabled else { return }
            if remoteItems != self.items {
                self.items = remoteItems
                self.ensureCurrentPageInBounds()
            }
        }
        syncService.startObserving()
    }

    private func uploadToICloudIfNeeded() {
        guard settingsStore.settings.iCloudSyncEnabled else { return }
        ICloudSyncService.shared.upload(items: items)
    }
}
