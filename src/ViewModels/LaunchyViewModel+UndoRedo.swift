import Foundation

// MARK: - Undo / Redo

extension LaunchyViewModel {

    func undo() {
        if let previous = undoManager.undo(current: items) {
            items = previous
            saveNow()
        }
    }

    func redo() {
        if let next = undoManager.redo(current: items) {
            items = next
            saveNow()
        }
    }
}
