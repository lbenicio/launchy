import SwiftUI
import UniformTypeIdentifiers

struct LaunchpadItemDropDelegate: DropDelegate {
    let item: LaunchpadItem
    let viewModel: LaunchpadViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchpadItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        viewModel.extractDraggedItemIfNeeded()
        guard let dragID = viewModel.dragItemID, dragID != item.id else { return }
        viewModel.moveItem(dragID, before: item.id)
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.endDrag(commit: true)
        return true
    }
}

struct LaunchpadTrailingDropDelegate: DropDelegate {
    let viewModel: LaunchpadViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchpadItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        viewModel.extractDraggedItemIfNeeded()
        guard let dragID = viewModel.dragItemID else { return }
        viewModel.moveItem(dragID, before: nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.endDrag(commit: true)
        return true
    }
}

struct FolderDropDelegate: DropDelegate {
    let folderID: UUID
    let viewModel: LaunchpadViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchpadItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        viewModel.extractDraggedItemIfNeeded()
        guard let dragID = viewModel.dragItemID else { return }
        viewModel.addApp(dragID, toFolder: folderID)
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.endDrag(commit: true)
        return true
    }
}

struct FolderAppDropDelegate: DropDelegate {
    let folderID: UUID
    let targetAppID: UUID
    let viewModel: LaunchpadViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchpadItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        guard let dragID = viewModel.dragItemID else { return }

        if viewModel.dragSourceFolderID == folderID {
            viewModel.moveAppWithinFolder(folderID: folderID, appID: dragID, before: targetAppID)
        } else {
            viewModel.extractDraggedItemIfNeeded()
            viewModel.addApp(dragID, toFolder: folderID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.endDrag(commit: true)
        return true
    }
}

struct FolderTrailingDropDelegate: DropDelegate {
    let folderID: UUID
    let viewModel: LaunchpadViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchpadItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        guard let dragID = viewModel.dragItemID else { return }

        if viewModel.dragSourceFolderID == folderID {
            viewModel.moveAppWithinFolder(folderID: folderID, appID: dragID, before: nil)
        } else {
            viewModel.extractDraggedItemIfNeeded()
            viewModel.addApp(dragID, toFolder: folderID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.endDrag(commit: true)
        return true
    }
}
