import SwiftUI
import UniformTypeIdentifiers

struct LaunchpadItemDropDelegate: DropDelegate {
    let item: LaunchpadItem
    let viewModel: LaunchpadViewModel
    let frameProvider: () -> CGRect?

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchpadItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        viewModel.extractDraggedItemIfNeeded()
        guard let dragID = viewModel.dragItemID, dragID != item.id else { return }
        viewModel.moveItem(dragID, before: item.id)
        updateStackingState(with: info)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        updateStackingState(with: info)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        viewModel.cancelPendingStacking()
    }

    func performDrop(info: DropInfo) -> Bool {
        var stacked = viewModel.commitPendingStackingIfNeeded(for: item.id)

        if !stacked, shouldStackOnDrop(info: info) {
            viewModel.cancelPendingStacking()
            stacked = viewModel.stackDraggedItem(onto: item.id)
        }

        if !stacked {
            viewModel.cancelPendingStacking()
        }

        viewModel.endDrag(commit: true)
        return true
    }

    private func updateStackingState(with info: DropInfo) {
        guard viewModel.isEditing,
            case .app = item,
            let frame = frameProvider()
        else {
            viewModel.cancelPendingStacking()
            return
        }

        if isLocationInStackZone(info.location, frame: frame) {
            viewModel.requestStacking(onto: item.id)
        } else {
            viewModel.cancelPendingStacking()
        }
    }

    private func shouldStackOnDrop(info: DropInfo) -> Bool {
        guard case .app = item, let frame = frameProvider() else { return false }
        return isLocationInStackZone(info.location, frame: frame)
    }

    private func isLocationInStackZone(_ location: CGPoint, frame: CGRect) -> Bool {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let distance = hypot(location.x - center.x, location.y - center.y)
        let activationRadius = min(frame.width, frame.height) * 0.45
        return distance <= activationRadius
    }
}

struct LaunchpadTrailingDropDelegate: DropDelegate {
    let viewModel: LaunchpadViewModel

    func validateDrop(info: DropInfo) -> Bool {
        viewModel.isEditing && info.hasItemsConforming(to: [.launchpadItemIdentifier])
    }

    func dropEntered(info: DropInfo) {
        viewModel.cancelPendingStacking()
        viewModel.extractDraggedItemIfNeeded()
        guard let dragID = viewModel.dragItemID else { return }
        viewModel.moveItem(dragID, before: nil)
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.cancelPendingStacking()
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
        viewModel.cancelPendingStacking()
        viewModel.extractDraggedItemIfNeeded()
        guard let dragID = viewModel.dragItemID else { return }
        viewModel.addApp(dragID, toFolder: folderID)
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.cancelPendingStacking()
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
        viewModel.cancelPendingStacking()

        if viewModel.dragSourceFolderID == folderID {
            viewModel.moveAppWithinFolder(folderID: folderID, appID: dragID, before: targetAppID)
        } else {
            viewModel.extractDraggedItemIfNeeded()
            viewModel.addApp(dragID, toFolder: folderID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.cancelPendingStacking()
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
        viewModel.cancelPendingStacking()

        if viewModel.dragSourceFolderID == folderID {
            viewModel.moveAppWithinFolder(folderID: folderID, appID: dragID, before: nil)
        } else {
            viewModel.extractDraggedItemIfNeeded()
            viewModel.addApp(dragID, toFolder: folderID)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        viewModel.cancelPendingStacking()
        viewModel.endDrag(commit: true)
        return true
    }
}
