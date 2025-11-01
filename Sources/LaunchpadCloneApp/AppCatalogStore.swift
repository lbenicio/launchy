import AppKit
import SwiftUI

@MainActor
final class AppCatalogStore: ObservableObject {
    @Published private(set) var rootEntries: [CatalogEntry] = []
    @Published var query: String = ""
    @Published var presentedFolder: FolderItem? = nil
    @Published var isEditing: Bool = false
    @Published var draggingEntryID: String? = nil
    @Published var targetedEntryID: String? = nil

    private var lastLoaded: Date? = nil
    private let loader = AppCatalogLoader()
    private let folderCreationThreshold: CGFloat = 48

    var activeEntries: [CatalogEntry] {
        if let folder = presentedFolder {
            return folder.apps.map { .app($0) }
        }
        if query.isEmpty {
            return rootEntries
        }
        return flattenedEntriesMatchingQuery(query)
    }

    func refreshCatalogIfNeeded() async {
        guard shouldReload else { return }
        await reloadCatalog()
    }

    func reloadCatalog() async {
        let entries = await loader.loadCatalog()
        rootEntries = entries
        isEditing = false
        draggingEntryID = nil
        targetedEntryID = nil
        lastLoaded = Date()
    }

    func launch(_ app: AppItem) {
        guard !isEditing else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(
            at: app.bundleURL, configuration: configuration, completionHandler: nil)
    }

    func revealInFinder(_ app: AppItem) {
        NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
    }

    func present(_ folder: FolderItem) {
        guard !isEditing else { return }
        presentedFolder = folder
    }

    func dismissPresentedFolder() {
        presentedFolder = nil
    }

    func dismissPresentedFolderOrClearSearch() -> Bool {
        if isEditing {
            endEditing()
            return true
        }
        if presentedFolder != nil {
            presentedFolder = nil
            return true
        }
        if !query.isEmpty {
            query = ""
            return true
        }
        return false
    }

    func beginEditing() {
        if !query.isEmpty {
            query = ""
        }
        presentedFolder = nil
        isEditing = true
        targetedEntryID = nil
    }

    func endEditing() {
        isEditing = false
        draggingEntryID = nil
        targetedEntryID = nil
    }

    func beginDragging(entryID: String) {
        beginEditing()
        draggingEntryID = entryID
        targetedEntryID = nil
    }

    func updateDraggingTarget(entryID: String?) {
        targetedEntryID = entryID
    }

    func completeDrop(on targetID: String?, location: CGPoint?, tileSize: CGSize?) -> Bool {
        defer {
            draggingEntryID = nil
            targetedEntryID = nil
        }
        guard let draggingID = draggingEntryID else { return false }
        guard presentedFolder == nil else { return false }

        if let targetID {
            let shouldMerge = shouldMergeDrop(at: location, tileSize: tileSize)
      if shouldMerge, mergeEntry(draggingID: draggingID, targetID: targetID) {
        return true
      }
      moveEntry(draggingID: draggingID, before: targetID)
      return true
        } else {
            moveDraggingEntryToTail(with: draggingID)
            return true
        }
    }

    func abandonDrag() {
        draggingEntryID = nil
        targetedEntryID = nil
    }

    private var shouldReload: Bool {
        guard let lastLoaded else { return true }
        return Date().timeIntervalSince(lastLoaded) > 300
    }

    private func flattenedEntriesMatchingQuery(_ query: String) -> [CatalogEntry] {
        rootEntries.flatMap { entry -> [CatalogEntry] in
            switch entry {
            case .app(let app):
                return app.matches(query) ? [.app(app)] : []
            case .folder(let folder):
                return folder.apps.filter { $0.matches(query) }.map { .app($0) }
            }
        }
    }

    private func moveDraggingEntryToTail(with draggingID: String) {
        guard let index = rootEntries.firstIndex(where: { $0.id == draggingID }) else { return }
        let entry = rootEntries.remove(at: index)
    withAnimation(.easeInOut(duration: 0.18)) {
      rootEntries.append(entry)
    }
  }

  private func moveEntry(draggingID: String, before targetID: String) {
    guard draggingID != targetID else { return }
    guard let fromIndex = rootEntries.firstIndex(where: { $0.id == draggingID }),
      let targetIndex = rootEntries.firstIndex(where: { $0.id == targetID })
    else { return }
    let entry = rootEntries.remove(at: fromIndex)
    let destination = fromIndex < targetIndex ? targetIndex - 1 : targetIndex
    withAnimation(.easeInOut(duration: 0.18)) {
      rootEntries.insert(entry, at: destination)
    }
  }

    private func mergeEntry(draggingID: String, targetID: String) -> Bool {
        guard draggingID != targetID else { return false }
        guard let sourceIndex = rootEntries.firstIndex(where: { $0.id == draggingID }) else {
            return false
        }
        let draggedEntry = rootEntries.remove(at: sourceIndex)
        guard let targetIndex = rootEntries.firstIndex(where: { $0.id == targetID }) else {
            rootEntries.insert(draggedEntry, at: min(sourceIndex, rootEntries.count))
            return false
        }
        let targetEntry = rootEntries[targetIndex]

        switch (draggedEntry, targetEntry) {
        case (.app(let app), .folder(var folder)):
      withAnimation(.easeInOut(duration: 0.18)) {
        folder.apps.append(app)
        rootEntries[targetIndex] = .folder(folder)
      }
            return true
        case (.app(let sourceApp), .app(let targetApp)):
            let folder = FolderItem(
                id: UUID().uuidString,
                name: suggestedFolderName(
                    primary: targetApp.displayName, secondary: sourceApp.displayName),
                apps: [targetApp, sourceApp]
            )
      withAnimation(.easeInOut(duration: 0.18)) {
        rootEntries[targetIndex] = .folder(folder)
      }
            return true
        case (.folder(let sourceFolder), .folder(var targetFolder)):
      withAnimation(.easeInOut(duration: 0.18)) {
        targetFolder.apps.append(contentsOf: sourceFolder.apps)
        rootEntries[targetIndex] = .folder(targetFolder)
      }
            return true
        default:
      withAnimation(.easeInOut(duration: 0.18)) {
        rootEntries.insert(draggedEntry, at: targetIndex)
      }
            return false
        }
    }

    private func shouldMergeDrop(at location: CGPoint?, tileSize: CGSize?) -> Bool {
        guard let location, let tileSize else { return false }
        let center = CGPoint(x: tileSize.width / 2, y: tileSize.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
    let radius = min(tileSize.width, tileSize.height) * 0.38
    return distance <= max(radius, folderCreationThreshold)
    }

    private func suggestedFolderName(primary: String, secondary: String) -> String {
        let primaryToken = primary.split(separator: " ").first.map(String.init) ?? primary
        let secondaryToken = secondary.split(separator: " ").first.map(String.init) ?? secondary
        return "\(primaryToken) & \(secondaryToken)"
    }
}
