import SwiftUI
import UniformTypeIdentifiers

// MARK: - Cross-Page Edge Drop Delegate

struct CrossPageEdgeDropDelegate: DropDelegate {
    let viewModel: LaunchyViewModel
    let direction: Int  // -1 for left (previous page), +1 for right (next page)
    let totalPages: Int
    let onEdgeEntered: (Int) -> Void
    let onEdgeExited: () -> Void

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchyItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        let currentPage = viewModel.currentPage
        let targetPage = currentPage + direction
        guard targetPage >= 0 else { return }
        // For rightward drags past the last page, allow signalling new-page creation.
        if direction < 0 {
            guard targetPage < totalPages else { return }
        }
        onEdgeEntered(targetPage)
    }

    func dropExited(info: DropInfo) {
        onEdgeExited()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        onEdgeExited()
        return false
    }
}

// MARK: - Item Drop Delegate

struct LaunchyItemDropDelegate: DropDelegate {
    let item: LaunchyItem
    let viewModel: LaunchyViewModel
    let frameProvider: () -> CGRect?

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchyItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        viewModel.extractDraggedItemIfNeeded()
        guard let dragID = viewModel.dragItemID, dragID != item.id else { return }

        if case .folder = item {
            // Springload: open the folder overlay after a short hover delay,
            // matching real Launchpad — don't add the app eagerly.
            viewModel.cancelPendingStacking()
            viewModel.requestSpringload(folderID: item.id)
        } else if shouldStack(using: info) {
            viewModel.requestStacking(onto: item.id)
        } else {
            viewModel.cancelPendingStacking()
            viewModel.moveItem(dragID, before: item.id)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard let dragID = viewModel.dragItemID, dragID != item.id else {
            return DropProposal(operation: .move)
        }

        if case .folder = item {
            // Keep the springload in progress; no stacking changes needed
        } else if shouldStack(using: info) {
            viewModel.requestStacking(onto: item.id)
        } else {
            viewModel.cancelPendingStacking()
        }
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        viewModel.cancelPendingStacking()
        viewModel.cancelPendingSpringload()
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.cancelPendingSpringload()

        // For folder targets, move the dragged item into the folder now
        if case .folder = item {
            viewModel.cancelPendingStacking()
            _ = viewModel.stackDraggedItem(onto: item.id)
            viewModel.endDrag(commit: true)
            return true
        }

        var stacked = viewModel.commitPendingStackingIfNeeded(for: item.id)

        if !stacked, shouldStack(using: info) {
            viewModel.cancelPendingStacking()
            stacked = viewModel.stackDraggedItem(onto: item.id)
        }

        if !stacked {
            viewModel.cancelPendingStacking()
        }

        viewModel.endDrag(commit: true)
        return true
    }

    private func shouldStack(using info: DropInfo) -> Bool {
        // Only stack onto apps (folder stacking is handled separately above)
        guard case .app = item, let frame = frameProvider() else { return false }
        let location = info.location
        let center = CGPoint(x: frame.width * 0.5, y: frame.height * 0.5)
        let distance = hypot(location.x - center.x, location.y - center.y)
        let activationRadius = min(frame.width, frame.height) * 0.35
        return distance <= activationRadius
    }
}

// MARK: - Trailing Drop Delegate

struct LaunchyTrailingDropDelegate: DropDelegate {
    let viewModel: LaunchyViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchyItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        viewModel.cancelPendingStacking()
        viewModel.extractDraggedItemIfNeeded()
        guard let dragID = viewModel.dragItemID else { return }
        viewModel.moveItem(dragID, before: nil)
    }

    func dropExited(info: DropInfo) {
        viewModel.cancelPendingStacking()
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.cancelPendingStacking()
        viewModel.endDrag(commit: true)
        return true
    }
}

// MARK: - Folder Drop Delegate

struct FolderDropDelegate: DropDelegate {
    let folderID: UUID
    let viewModel: LaunchyViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchyItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        viewModel.cancelPendingStacking()
        viewModel.extractDraggedItemIfNeeded()
        guard let dragID = viewModel.dragItemID else { return }
        viewModel.addApp(dragID, toFolder: folderID)
    }

    func dropExited(info: DropInfo) {
        viewModel.cancelPendingStacking()
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.cancelPendingStacking()
        viewModel.endDrag(commit: true)
        return true
    }
}

// MARK: - Folder App Drop Delegate

struct FolderAppDropDelegate: DropDelegate {
    let folderID: UUID
    let targetAppID: UUID
    let viewModel: LaunchyViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchyItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        guard let dragID = viewModel.dragItemID else { return }
        viewModel.cancelPendingStacking()

        if viewModel.dragSourceFolderID == folderID {
            viewModel.moveAppWithinFolder(folderID: folderID, appID: dragID, before: targetAppID)
        } else {
            viewModel.extractDraggedItemIfNeeded()
            viewModel.addApp(dragID, toFolder: folderID)
        }
    }

    func dropExited(info: DropInfo) {
        viewModel.cancelPendingStacking()
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.cancelPendingStacking()
        viewModel.endDrag(commit: true)
        return true
    }
}

// MARK: - Folder Trailing Drop Delegate

struct FolderTrailingDropDelegate: DropDelegate {
    let folderID: UUID
    let viewModel: LaunchyViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchyItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        guard let dragID = viewModel.dragItemID else { return }
        viewModel.cancelPendingStacking()

        if viewModel.dragSourceFolderID == folderID {
            viewModel.moveAppWithinFolder(folderID: folderID, appID: dragID, before: nil)
        } else {
            viewModel.extractDraggedItemIfNeeded()
            viewModel.addApp(dragID, toFolder: folderID)
        }
    }

    func dropExited(info: DropInfo) {
        viewModel.cancelPendingStacking()
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.cancelPendingStacking()
        viewModel.endDrag(commit: true)
        return true
    }
}

// MARK: - Trash Drop Delegate

struct TrashDropDelegate: DropDelegate {
    let viewModel: LaunchyViewModel
    let isHovering: Binding<Bool>

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchyItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        isHovering.wrappedValue = true
    }

    func dropExited(info: DropInfo) {
        isHovering.wrappedValue = false
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        isHovering.wrappedValue = false
        guard let dragID = viewModel.dragItemID else { return false }
        viewModel.endDrag(commit: false)
        viewModel.deleteItem(dragID)
        return true
    }
}

// MARK: - Finder File URL Drop Delegate

struct FinderDropDelegate: DropDelegate {
    let viewModel: LaunchyViewModel

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.fileURL])
        guard !providers.isEmpty else { return false }

        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in
                    _ = viewModel.addAppFromFinder(url: url)
                }
            }
        }
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .copy)
    }
}
