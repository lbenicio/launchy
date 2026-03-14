import Foundation

#if os(macOS)
    import AppKit
#endif

// MARK: - Folder management

extension LaunchyViewModel {

    /// Presents the folder overlay for the given folder ID.
    func openFolder(with id: UUID) {
        presentedFolderID = id
    }

    /// Dismisses the currently presented folder overlay.
    func closeFolder() {
        presentedFolderID = nil
    }

    func showInFinder(_ item: LaunchyItem) {
        #if os(macOS)
            if case .app(let icon) = item {
                NSWorkspace.shared.activateFileViewerSelecting([icon.bundleURL])
            }
        #endif
    }

    func renameFolder(_ folderID: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let index = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[index].asFolder
        else { return }
        folder.name = trimmed
        items[index] = .folder(folder)
        saveNow()
    }

    func updateFolderColor(_ folderID: UUID, to color: IconColor) {
        guard let index = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[index].asFolder
        else { return }
        folder.color = color
        items[index] = .folder(folder)
        saveNow()
    }

    /// Shifts an app within a folder by the given offset.
    func shiftAppInFolder(folderID: UUID, appID: UUID, by offset: Int) {
        guard let idx = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[idx].asFolder,
            let appIdx = folder.apps.firstIndex(where: { $0.id == appID })
        else { return }

        let newIdx = min(max(0, appIdx + offset), folder.apps.count - 1)
        if newIdx == appIdx { return }
        let app = folder.apps.remove(at: appIdx)
        folder.apps.insert(app, at: newIdx)
        items[idx] = .folder(folder)
        saveNow()
    }

    /// Repositions an app within a folder before the target app, or appends if target is `nil`.
    func moveAppWithinFolder(folderID: UUID, appID: UUID, before targetAppID: UUID?) {
        guard let idx = items.firstIndex(where: { $0.id == folderID }),
            var folder = items[idx].asFolder,
            let appIdx = folder.apps.firstIndex(where: { $0.id == appID })
        else { return }

        let app = folder.apps.remove(at: appIdx)
        if let target = targetAppID,
            let tIdx = folder.apps.firstIndex(where: { $0.id == target })
        {
            folder.apps.insert(app, at: tIdx)
        } else {
            folder.apps.append(app)
        }
        items[idx] = .folder(folder)
        scheduleDebouncedSave()
    }
}
