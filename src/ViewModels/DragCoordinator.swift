import Combine
import Foundation
import SwiftUI

/// Encapsulates all drag-and-drop state and logic previously interleaved in `LaunchyViewModel`.
///
/// The coordinator holds an `unowned` reference back to the view model so it can
/// read/write `items`, `presentedFolderID`, and call persistence helpers
/// (`scheduleDebouncedSave`, `saveNow`).  Because the view model owns the
/// coordinator as a stored property the lifecycle is guaranteed.
@MainActor
final class DragCoordinator: ObservableObject {

    // MARK: - Published drag state

    @Published private(set) var dragItemID: UUID? = nil
    @Published private(set) var dragSourceFolderID: UUID? = nil
    @Published private(set) var pendingStackTargetID: UUID? = nil

    // MARK: - Internal state

    private var pendingStackTask: Task<Void, Never>?
    private let stackingDelay: TimeInterval = 0.35

    // MARK: - Back-reference to the owning view model

    unowned let viewModel: LaunchyViewModel

    // MARK: - Init

    init(viewModel: LaunchyViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Drag lifecycle

    /// Starts a drag session for the given item. Forwarded from `LaunchyViewModel`.
    func beginDrag(for id: UUID, sourceFolder: UUID? = nil) {
        dragItemID = id
        dragSourceFolderID = sourceFolder
    }

    /// Ends the current drag session. If `commit` is true, persists changes immediately.
    func endDrag(commit: Bool) {
        if commit {
            viewModel.saveNow()
        }
        dragItemID = nil
        dragSourceFolderID = nil
        cancelPendingStacking()
    }

    // MARK: - Extraction from folder

    /// When an item is dragged from inside a folder onto the main grid,
    /// extract it from the source folder and insert it as a top-level item.
    func extractDraggedItemIfNeeded() {
        guard let dragID = dragItemID, let sourceFolderID = dragSourceFolderID else { return }

        // Already extracted to top level?
        if viewModel.items.contains(where: { $0.id == dragID }) { return }

        guard let folderIndex = viewModel.items.firstIndex(where: { $0.id == sourceFolderID }),
            var folder = viewModel.items[folderIndex].asFolder,
            let appIndex = folder.apps.firstIndex(where: { $0.id == dragID })
        else { return }

        let app = folder.apps.remove(at: appIndex)

        // If the folder has only one app left, disband it
        if folder.apps.count <= 1 {
            let remainingApps = folder.apps.map { LaunchyItem.app($0) }
            viewModel.items.remove(at: folderIndex)
            viewModel.items.insert(
                contentsOf: remainingApps,
                at: min(folderIndex, viewModel.items.count)
            )
            viewModel.items.insert(.app(app), at: min(folderIndex, viewModel.items.count))
        } else {
            viewModel.items[folderIndex] = .folder(folder)
            viewModel.items.insert(.app(app), at: min(folderIndex + 1, viewModel.items.count))
        }

        // Clear the source folder reference since item is now top-level
        dragSourceFolderID = nil
        viewModel.scheduleDebouncedSave()
    }

    // MARK: - Stacking (folder creation / insertion on hover)

    /// Requests folder-creation stacking onto the target item after a short delay. Cancels any previous pending stacking request.
    func requestStacking(onto id: UUID) {
        guard id != pendingStackTargetID else { return }
        cancelPendingStacking()
        pendingStackTargetID = id
        pendingStackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.stackingDelay ?? 0.35))
            guard !Task.isCancelled, let self, self.dragItemID != nil else { return }
            _ = self.stackDraggedItem(onto: id)
        }
    }

    /// Cancels any pending stacking timer.
    func cancelPendingStacking() {
        pendingStackTask?.cancel()
        pendingStackTask = nil
        pendingStackTargetID = nil
    }

    /// Commits the pending stacking if it matches the given target ID. Returns whether stacking occurred.
    func commitPendingStackingIfNeeded(for id: UUID) -> Bool {
        guard let pending = pendingStackTargetID, pending == id, dragItemID != nil else {
            return false
        }
        cancelPendingStacking()
        return stackDraggedItem(onto: id)
    }

    /// Immediately stacks the currently dragged item onto the target (creating a folder or adding to an existing one).
    @discardableResult
    func stackDraggedItem(onto targetID: UUID) -> Bool {
        guard let draggedID = dragItemID else { return false }

        // Case 1: Target is a folder — add dragged app into the folder
        if let targetIndex = viewModel.items.firstIndex(where: { $0.id == targetID }),
            var folder = viewModel.items[targetIndex].asFolder
        {
            // Source is inside a folder
            if let sourceFolderID = dragSourceFolderID,
                let sourceIndex = viewModel.items.firstIndex(where: { $0.id == sourceFolderID }),
                var sourceFolder = viewModel.items[sourceIndex].asFolder,
                let appIdx = sourceFolder.apps.firstIndex(where: { $0.id == draggedID })
            {
                let app = sourceFolder.apps.remove(at: appIdx)
                folder.apps.append(app)

                // Update both folders carefully (indices may be same if source == target)
                if sourceIndex == targetIndex {
                    // Same folder, just update once
                    viewModel.items[targetIndex] = .folder(folder)
                } else {
                    // Update the one with the higher index first to avoid shift
                    if sourceIndex > targetIndex {
                        if sourceFolder.apps.isEmpty {
                            viewModel.items.remove(at: sourceIndex)
                        } else {
                            viewModel.items[sourceIndex] = .folder(sourceFolder)
                        }
                        viewModel.items[targetIndex] = .folder(folder)
                    } else {
                        viewModel.items[targetIndex] = .folder(folder)
                        if sourceFolder.apps.isEmpty {
                            viewModel.items.remove(at: sourceIndex)
                        } else {
                            viewModel.items[sourceIndex] = .folder(sourceFolder)
                        }
                    }
                }
                viewModel.saveNow()
                return true
            }

            // Source is a top-level app
            if let topIndex = viewModel.items.firstIndex(where: { $0.id == draggedID }),
                case .app(let app) = viewModel.items[topIndex]
            {
                // Remove the dragged app first, then adjust target index
                viewModel.items.remove(at: topIndex)
                let adjustedTargetIndex = topIndex < targetIndex ? targetIndex - 1 : targetIndex
                folder.apps.append(app)
                viewModel.items[adjustedTargetIndex] = .folder(folder)
                viewModel.saveNow()
                return true
            }

            return false
        }

        // Case 2: Target is an app — create a new folder from both apps
        if let targetIndex = viewModel.items.firstIndex(where: { $0.id == targetID }),
            case .app(let targetApp) = viewModel.items[targetIndex]
        {
            var draggedApp: AppIcon?

            // Get the dragged app from a source folder
            if let sourceFolderID = dragSourceFolderID,
                let sourceIndex = viewModel.items.firstIndex(where: { $0.id == sourceFolderID }),
                var sourceFolder = viewModel.items[sourceIndex].asFolder,
                let appIdx = sourceFolder.apps.firstIndex(where: { $0.id == draggedID })
            {
                draggedApp = sourceFolder.apps.remove(at: appIdx)
                if sourceFolder.apps.isEmpty {
                    viewModel.items.remove(at: sourceIndex)
                } else {
                    viewModel.items[sourceIndex] = .folder(sourceFolder)
                }
            }
            // Or get the dragged app from top-level
            else if let topIndex = viewModel.items.firstIndex(where: { $0.id == draggedID }),
                case .app(let app) = viewModel.items[topIndex]
            {
                draggedApp = app
                viewModel.items.remove(at: topIndex)
            }

            guard let draggedApp else { return false }

            // Find the (possibly shifted) target index again
            guard let newTargetIndex = viewModel.items.firstIndex(where: { $0.id == targetID })
            else {
                // Target was removed somehow, just add dragged back
                viewModel.items.append(.app(draggedApp))
                viewModel.saveNow()
                return false
            }

            // Create a new folder with both apps
            let folderName = targetApp.name
            let newFolder = LaunchyFolder(
                name: folderName,
                color: .blue,
                apps: [targetApp, draggedApp]
            )
            viewModel.items[newTargetIndex] = .folder(newFolder)
            viewModel.saveNow()
            viewModel.presentedFolderID = newFolder.id
            return true
        }

        return false
    }
}
