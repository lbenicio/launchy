import XCTest

@testable import Launchy

@MainActor
final class LayoutUndoManagerTests: XCTestCase {

    private func makeItem(name: String) -> LaunchyItem {
        .app(
            AppIcon(
                name: name,
                bundleIdentifier: "com.test.\(name.lowercased())",
                bundleURL: URL(fileURLWithPath: "/Applications/\(name).app")
            )
        )
    }

    // MARK: - Initial state

    func testInitialStateHasNoUndoOrRedo() {
        let manager = LayoutUndoManager()
        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    // MARK: - Recording snapshots

    func testRecordSnapshotEnablesUndo() {
        let manager = LayoutUndoManager()
        let items = [makeItem(name: "Safari")]
        manager.recordSnapshot(items)
        XCTAssertTrue(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }

    func testRecordSnapshotClearsRedoStack() {
        let manager = LayoutUndoManager()
        let state1 = [makeItem(name: "Safari")]
        let state2 = [makeItem(name: "Safari"), makeItem(name: "Mail")]

        manager.recordSnapshot(state1)
        _ = manager.undo(current: state2)
        XCTAssertTrue(manager.canRedo)

        // Recording a new snapshot should clear the redo stack
        manager.recordSnapshot(state2)
        XCTAssertFalse(manager.canRedo)
    }

    // MARK: - Undo

    func testUndoReturnsPreviousState() {
        let manager = LayoutUndoManager()
        let state1 = [makeItem(name: "Safari")]
        let state2 = [makeItem(name: "Safari"), makeItem(name: "Mail")]

        manager.recordSnapshot(state1)  // Record state before mutation
        let restored = manager.undo(current: state2)

        XCTAssertNotNil(restored)
        XCTAssertEqual(restored!.count, 1)
        XCTAssertEqual(restored!.first?.displayName, "Safari")
    }

    func testUndoWithEmptyStackReturnsNil() {
        let manager = LayoutUndoManager()
        let current = [makeItem(name: "Safari")]
        XCTAssertNil(manager.undo(current: current))
    }

    func testUndoEnablesRedo() {
        let manager = LayoutUndoManager()
        let state1 = [makeItem(name: "Safari")]
        let state2 = [makeItem(name: "Safari"), makeItem(name: "Mail")]

        manager.recordSnapshot(state1)
        _ = manager.undo(current: state2)
        XCTAssertTrue(manager.canRedo)
    }

    // MARK: - Redo

    func testRedoRestoresUndoneState() {
        let manager = LayoutUndoManager()
        let state1 = [makeItem(name: "Safari")]
        let state2 = [makeItem(name: "Safari"), makeItem(name: "Mail")]

        manager.recordSnapshot(state1)
        let afterUndo = manager.undo(current: state2)!
        let afterRedo = manager.redo(current: afterUndo)

        XCTAssertNotNil(afterRedo)
        XCTAssertEqual(afterRedo!.count, 2)
    }

    func testRedoWithEmptyStackReturnsNil() {
        let manager = LayoutUndoManager()
        let current = [makeItem(name: "Safari")]
        XCTAssertNil(manager.redo(current: current))
    }

    // MARK: - Multiple undo/redo

    func testMultipleUndoRedoCycles() {
        let manager = LayoutUndoManager()
        let state0: [LaunchyItem] = []
        let state1 = [makeItem(name: "Safari")]
        let state2 = [makeItem(name: "Safari"), makeItem(name: "Mail")]

        manager.recordSnapshot(state0)  // Before adding Safari
        manager.recordSnapshot(state1)  // Before adding Mail

        // Undo back to state1
        let afterFirstUndo = manager.undo(current: state2)!
        XCTAssertEqual(afterFirstUndo.count, 1)

        // Undo back to state0
        let afterSecondUndo = manager.undo(current: afterFirstUndo)!
        XCTAssertEqual(afterSecondUndo.count, 0)

        // Redo to state1
        let afterFirstRedo = manager.redo(current: afterSecondUndo)!
        XCTAssertEqual(afterFirstRedo.count, 1)

        // Redo to state2
        let afterSecondRedo = manager.redo(current: afterFirstRedo)!
        XCTAssertEqual(afterSecondRedo.count, 2)
    }

    // MARK: - Stack size limit

    func testStackSizeLimitedTo50() {
        let manager = LayoutUndoManager()

        // Record 55 snapshots
        for i in 0..<55 {
            let items = (0..<i).map { makeItem(name: "App\($0)") }
            manager.recordSnapshot(items)
        }

        XCTAssertTrue(manager.canUndo)

        // Should be able to undo exactly 50 times (max stack size)
        var undoCount = 0
        var current = (0..<55).map { makeItem(name: "App\($0)") }
        while let previous = manager.undo(current: current) {
            current = previous
            undoCount += 1
        }
        XCTAssertEqual(undoCount, 50)
    }

    // MARK: - Clear

    func testClearAllResetsState() {
        let manager = LayoutUndoManager()
        manager.recordSnapshot([makeItem(name: "Safari")])
        _ = manager.undo(current: [makeItem(name: "Mail")])

        manager.clearAll()

        XCTAssertFalse(manager.canUndo)
        XCTAssertFalse(manager.canRedo)
    }
}
