import Foundation

/// Manages undo/redo for layout changes using snapshots of the items array.
@MainActor
final class LayoutUndoManager: ObservableObject {
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false

    private var undoStack: [[LaunchyItem]] = []
    private var redoStack: [[LaunchyItem]] = []
    private let maxStackSize: Int = 50

    /// Records the current state before a mutation. Call this *before* modifying items.
    func recordSnapshot(_ items: [LaunchyItem]) {
        undoStack.append(items)
        if undoStack.count > maxStackSize {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
        canUndo = !undoStack.isEmpty
        canRedo = false
    }

    /// Returns the previous state, or `nil` if there's nothing to undo.
    func undo(current: [LaunchyItem]) -> [LaunchyItem]? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        canUndo = !undoStack.isEmpty
        canRedo = true
        return previous
    }

    /// Returns the next state, or `nil` if there's nothing to redo.
    func redo(current: [LaunchyItem]) -> [LaunchyItem]? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        canUndo = true
        canRedo = !redoStack.isEmpty
        return next
    }

    /// Clears both stacks.
    func clearAll() {
        undoStack.removeAll()
        redoStack.removeAll()
        canUndo = false
        canRedo = false
    }
}
