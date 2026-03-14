import Foundation

// MARK: - Drag & drop (forwarded to DragCoordinator)

extension LaunchyViewModel {

    /// Starts a drag session for the given item. Records an undo snapshot once at drag
    /// start so the entire reorder can be undone with a single Cmd+Z.
    func beginDrag(for id: UUID, sourceFolder: UUID? = nil) {
        recordForUndo()
        dragCoordinator.beginDrag(for: id, sourceFolder: sourceFolder)
    }

    /// Ends the current drag session. If `commit` is `true`, persists changes immediately.
    func endDrag(commit: Bool) {
        dragCoordinator.endDrag(commit: commit)
    }

    /// Extracts a dragged item from its source folder into the top-level grid.
    /// No-op if the item is already top-level or no drag is active.
    func extractDraggedItemIfNeeded() {
        dragCoordinator.extractDraggedItemIfNeeded()
    }

    /// Requests folder-creation stacking onto the target item after a short delay.
    /// Cancels any previous pending stacking request.
    func requestStacking(onto id: UUID) {
        dragCoordinator.requestStacking(onto: id)
    }

    /// Cancels any pending stacking timer.
    func cancelPendingStacking() {
        dragCoordinator.cancelPendingStacking()
    }

    /// Commits the pending stacking if it matches the given target ID.
    /// Returns whether stacking occurred.
    @discardableResult
    func commitPendingStackingIfNeeded(for id: UUID) -> Bool {
        dragCoordinator.commitPendingStackingIfNeeded(for: id)
    }

    /// Immediately stacks the currently dragged item onto the target
    /// (creating a folder or adding to an existing one).
    @discardableResult
    func stackDraggedItem(onto targetID: UUID) -> Bool {
        dragCoordinator.stackDraggedItem(onto: targetID)
    }

    /// Moves the currently dragged item to the end of the flat items array,
    /// effectively placing it on a new last page when the current last page is full.
    func moveDraggedItemToEnd() {
        extractDraggedItemIfNeeded()
        guard let dragID = dragItemID else { return }
        moveItem(dragID, before: nil)
    }
}
