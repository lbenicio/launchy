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
  @Published private(set) var draggingFromFolder: Bool = false
  @Published private(set) var exitHandledDuringEditing: Bool = false

  private var lastLoaded: Date? = nil
  private let loader = AppCatalogLoader()
  private let layoutPersistence = LayoutPersistence()
  private let folderCreationThreshold: CGFloat = 48
  private var reorderPending = false
  private var folderDragContext: FolderDragContext? = nil
  private var lastReorderPair: (draggingID: String, targetID: String)? = nil

  var activeEntries: [CatalogEntry] {
    if !query.isEmpty {
      return flattenedEntriesMatchingQuery(query)
    }
    return rootEntries
  }

  func refreshCatalogIfNeeded() async {
    guard shouldReload else { return }
    await reloadCatalog()
  }

  func reloadCatalog() async {
    let entries = await loader.loadCatalog()
    let merged = await applySavedLayout(to: entries)
    rootEntries = merged
    isEditing = false
    draggingEntryID = nil
    targetedEntryID = nil
    reorderPending = false
    draggingFromFolder = false
    folderDragContext = nil
    lastReorderPair = nil
    exitHandledDuringEditing = false
    lastLoaded = Date()
    persistLayout()
  }

  func launch(_ app: AppItem) {
    guard !isEditing else { return }
    let configuration = NSWorkspace.OpenConfiguration()
    NSWorkspace.shared.openApplication(
      at: app.bundleURL,
      configuration: configuration,
      completionHandler: nil
    )
  }

  func revealInFinder(_ app: AppItem) {
    NSWorkspace.shared.activateFileViewerSelecting([app.bundleURL])
  }

  func present(_ folder: FolderItem) {
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

  func beginEditing(preservingFolder: Bool = false) {
    if !query.isEmpty {
      query = ""
    }
    if !preservingFolder {
      presentedFolder = nil
    }
    isEditing = true
    targetedEntryID = nil
    reorderPending = false
    lastReorderPair = nil
    exitHandledDuringEditing = false
  }

  func endEditing() {
    isEditing = false
    draggingEntryID = nil
    targetedEntryID = nil
    reorderPending = false
    draggingFromFolder = false
    folderDragContext = nil
    lastReorderPair = nil
    exitHandledDuringEditing = true
  }

  func clearEditingCompletionFlag() {
    exitHandledDuringEditing = false
  }

  func beginDragging(entryID: String) {
    beginEditing()
    draggingEntryID = entryID
    targetedEntryID = nil
    reorderPending = false
    lastReorderPair = nil
  }

  func beginDraggingAppFromFolder(folderID: String, appID: String) {
    guard isEditing else { return }
    guard folderDragContext == nil else { return }
    guard
      let folderIndex = rootEntries.firstIndex(where: { entry in
        if case .folder(let folder) = entry {
          return folder.id == folderID
        }
        return false
      }),
      case .folder(let originalFolder) = rootEntries[folderIndex],
      let appIndex = originalFolder.apps.firstIndex(where: { $0.id == appID })
    else { return }

    var updatedFolder = originalFolder
    let app = updatedFolder.apps.remove(at: appIndex)
    let entry = CatalogEntry.app(app)
    let entryID = entry.id

    let folderBecameEmpty = updatedFolder.apps.isEmpty
    if folderBecameEmpty {
      withAnimation(.easeInOut(duration: 0.18)) {
        _ = rootEntries.remove(at: folderIndex)
      }
    } else {
      withAnimation(.easeInOut(duration: 0.18)) {
        rootEntries[folderIndex] = .folder(updatedFolder)
      }
    }

    var insertionIndex = folderIndex
    if !folderBecameEmpty {
      insertionIndex += 1
    }
    insertionIndex = min(insertionIndex, rootEntries.count)

    withAnimation(.easeInOut(duration: 0.18)) {
      rootEntries.insert(entry, at: insertionIndex)
    }

    folderDragContext = FolderDragContext(
      originalFolder: originalFolder,
      updatedFolder: folderBecameEmpty ? nil : updatedFolder,
      folderIndex: folderIndex,
      app: app,
      appIndex: appIndex,
      entryID: entryID,
      insertionIndex: insertionIndex,
      folderRemoved: folderBecameEmpty
    )

    draggingFromFolder = true
    draggingEntryID = entryID
    targetedEntryID = nil
    reorderPending = false
    lastReorderPair = nil

    presentedFolder = updatedFolder
  }

  func updateDraggingTarget(entryID: String?, location: CGPoint?, tileSize: CGSize?) {
    guard let entryID else {
      targetedEntryID = nil
      return
    }
    guard let draggingID = draggingEntryID, draggingID != entryID else {
      targetedEntryID = nil
      return
    }

    guard let location, let tileSize else {
      targetedEntryID = entryID
      return
    }

    let shouldMerge = shouldMergeDrop(at: location, tileSize: tileSize)
    if shouldMerge {
      targetedEntryID = entryID
      reorderPending = false
      lastReorderPair = nil
    } else {
      if let lastReorderPair, lastReorderPair.draggingID == draggingID,
        lastReorderPair.targetID == entryID
      {
        return
      }
      targetedEntryID = nil
      let reordered = moveEntry(draggingID: draggingID, before: entryID, persist: false)
      if reordered {
        reorderPending = true
        lastReorderPair = (draggingID: draggingID, targetID: entryID)
      } else if lastReorderPair?.targetID == entryID {
        lastReorderPair = nil
      }
    }
  }

  func completeDrop(on targetID: String?, location: CGPoint?, tileSize: CGSize?) -> Bool {
    guard let draggingID = draggingEntryID else { return false }
    var dropSucceeded = false

    if let targetID {
      let shouldMerge = shouldMergeDrop(at: location, tileSize: tileSize)
      if shouldMerge {
        dropSucceeded = mergeEntry(draggingID: draggingID, targetID: targetID)
      } else {
        dropSucceeded = moveEntry(draggingID: draggingID, before: targetID)
      }
    } else {
      if reorderPending {
        persistLayout()
        dropSucceeded = true
      } else if folderDragContext != nil {
        persistLayout()
        dropSucceeded = true
      }
      if !dropSucceeded {
        dropSucceeded = moveDraggingEntryToTail(with: draggingID)
      }
    }

    if dropSucceeded {
      finalizeFolderDragContext()
    } else {
      restoreFolderDragContext()
    }

    draggingEntryID = nil
    targetedEntryID = nil
    reorderPending = false
    draggingFromFolder = false
    lastReorderPair = nil

    return dropSucceeded
  }

  func abandonDrag() {
    if folderDragContext != nil {
      restoreFolderDragContext()
    }
    draggingEntryID = nil
    targetedEntryID = nil
    reorderPending = false
    draggingFromFolder = false
    lastReorderPair = nil
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

  private func moveDraggingEntryToTail(with draggingID: String, persist: Bool = true) -> Bool {
    guard let index = rootEntries.firstIndex(where: { $0.id == draggingID }) else { return false }
    guard index != rootEntries.count - 1 else { return false }
    let entry = rootEntries.remove(at: index)
    withAnimation(.easeInOut(duration: 0.18)) {
      rootEntries.append(entry)
    }
    if persist {
      persistLayout()
    }
    return true
  }

  private func moveEntry(
    draggingID: String,
    before targetID: String,
    persist: Bool = true
  ) -> Bool {
    guard draggingID != targetID else { return false }
    guard
      let fromIndex = rootEntries.firstIndex(where: { $0.id == draggingID }),
      let targetIndex = rootEntries.firstIndex(where: { $0.id == targetID })
    else { return false }

    let destination: Int
    if fromIndex < targetIndex {
      destination = targetIndex - 1
    } else {
      destination = targetIndex
    }

    if destination == fromIndex {
      if persist {
        persistLayout()
      }
      return persist
    }

    let entry = rootEntries.remove(at: fromIndex)
    withAnimation(.easeInOut(duration: 0.18)) {
      rootEntries.insert(entry, at: destination)
    }

    if persist {
      persistLayout()
    }

    return true
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
      persistLayout()
      return true
    case (.app(let sourceApp), .app(let targetApp)):
      let folder = FolderItem(
        id: UUID().uuidString,
        name: suggestedFolderName(
          primary: targetApp.displayName,
          secondary: sourceApp.displayName
        ),
        apps: [targetApp, sourceApp]
      )
      withAnimation(.easeInOut(duration: 0.18)) {
        rootEntries[targetIndex] = .folder(folder)
      }
      persistLayout()
      return true
    case (.folder(let sourceFolder), .folder(var targetFolder)):
      withAnimation(.easeInOut(duration: 0.18)) {
        targetFolder.apps.append(contentsOf: sourceFolder.apps)
        rootEntries[targetIndex] = .folder(targetFolder)
      }
      persistLayout()
      return true
    default:
      withAnimation(.easeInOut(duration: 0.18)) {
        rootEntries.insert(draggedEntry, at: targetIndex)
      }
      return false
    }
  }

  private func applySavedLayout(to entries: [CatalogEntry]) async -> [CatalogEntry] {
    guard let snapshot = await layoutPersistence.loadSnapshot() else { return entries }

    var appsByID: [String: AppItem] = [:]
    var foldersByID: [String: FolderItem] = [:]

    for entry in entries {
      switch entry {
      case .app(let app):
        appsByID[app.id] = app
      case .folder(let folder):
        foldersByID[folder.id] = folder
        for app in folder.apps {
          appsByID[app.id] = app
        }
      }
    }

    var consumedAppIDs: Set<String> = []
    var resolved: [CatalogEntry] = []

    for layoutEntry in snapshot.entries {
      switch layoutEntry {
      case .app(let id):
        guard let app = appsByID[id] else { continue }
        consumedAppIDs.insert(id)
        resolved.append(.app(app))
      case .folder(let folderLayout):
        var apps: [AppItem] = []
        for appID in folderLayout.appIDs {
          guard let app = appsByID[appID] else { continue }
          apps.append(app)
          consumedAppIDs.insert(appID)
        }
        guard !apps.isEmpty else { continue }
        if var existing = foldersByID[folderLayout.id] {
          existing.name = folderLayout.name
          existing.apps = apps
          resolved.append(.folder(existing))
        } else {
          let folder = FolderItem(id: folderLayout.id, name: folderLayout.name, apps: apps)
          resolved.append(.folder(folder))
        }
      }
    }

    let snapshotFolderIDs = Set(snapshot.entries.compactMap { $0.folderID })

    for entry in entries {
      switch entry {
      case .folder(var folder):
        if snapshotFolderIDs.contains(folder.id) { continue }
        folder.apps = folder.apps.filter { !consumedAppIDs.contains($0.id) }
        guard !folder.apps.isEmpty else { continue }
        resolved.append(.folder(folder))
      case .app(let app):
        if consumedAppIDs.contains(app.id) { continue }
        resolved.append(.app(app))
      }
    }

    return resolved
  }

  private func persistLayout() {
    let entries = rootEntries
    Task {
      await layoutPersistence.save(entries: entries)
    }
  }

  private func finalizeFolderDragContext() {
    guard let context = folderDragContext else { return }
    folderDragContext = nil
    if context.folderRemoved {
      presentedFolder = nil
    } else if let updated = context.updatedFolder {
      presentedFolder = updated
    }
  }

  private func restoreFolderDragContext() {
    guard let context = folderDragContext else { return }

    if let entryIndex = rootEntries.firstIndex(where: { $0.id == context.entryID }) {
      withAnimation(.easeInOut(duration: 0.18)) {
        _ = rootEntries.remove(at: entryIndex)
      }
    }

    if context.folderRemoved {
      withAnimation(.easeInOut(duration: 0.18)) {
        rootEntries.insert(
          .folder(context.originalFolder),
          at: min(context.folderIndex, rootEntries.count)
        )
      }
      presentedFolder = context.originalFolder
    } else if let updated = context.updatedFolder {
      if let folderIndex = rootEntries.firstIndex(where: { entry in
        if case .folder(let folder) = entry {
          return folder.id == updated.id
        }
        return false
      }) {
        var folder = updated
        folder.apps.insert(context.app, at: context.appIndex)
        withAnimation(.easeInOut(duration: 0.18)) {
          rootEntries[folderIndex] = .folder(folder)
        }
        presentedFolder = folder
      } else {
        withAnimation(.easeInOut(duration: 0.18)) {
          rootEntries.insert(
            .folder(context.originalFolder),
            at: min(context.folderIndex, rootEntries.count)
          )
        }
        presentedFolder = context.originalFolder
      }
    }

    folderDragContext = nil
    draggingFromFolder = false
    persistLayout()
  }

  private struct FolderDragContext {
    let originalFolder: FolderItem
    let updatedFolder: FolderItem?
    let folderIndex: Int
    let app: AppItem
    let appIndex: Int
    let entryID: String
    let insertionIndex: Int
    let folderRemoved: Bool
  }
  private func shouldMergeDrop(at location: CGPoint?, tileSize: CGSize?) -> Bool {
    guard let location, let tileSize else { return false }
    let center = CGPoint(x: tileSize.width / 2, y: tileSize.height / 2)
    let dx = location.x - center.x
    let dy = location.y - center.y
    let distance = sqrt(dx * dx + dy * dy)
    let radius = min(tileSize.width, tileSize.height) * 0.5
    return distance <= max(radius, folderCreationThreshold)
  }

  func renameFolder(id folderID: String, to newName: String) {
    let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    guard
      let index = rootEntries.firstIndex(where: { entry in
        if case .folder(let folder) = entry {
          return folder.id == folderID
        }
        return false
      })
    else { return }

    guard case .folder(var folder) = rootEntries[index] else { return }
    guard folder.name != trimmed else { return }
    folder.name = trimmed
    rootEntries[index] = .folder(folder)
    if let presented = presentedFolder, presented.id == folder.id {
      presentedFolder = folder
    }
    persistLayout()
  }

  private func suggestedFolderName(primary: String, secondary: String) -> String {
    let primaryToken = primary.split(separator: " ").first.map(String.init) ?? primary
    let secondaryToken = secondary.split(separator: " ").first.map(String.init) ?? secondary
    return "\(primaryToken) & \(secondaryToken)"
  }

  func dissolveFolder(id folderID: String) {
    guard isEditing else { return }
    guard
      let index = rootEntries.firstIndex(where: { entry in
        if case .folder(let folder) = entry {
          return folder.id == folderID
        }
        return false
      }),
      case .folder(let folder) = rootEntries[index]
    else { return }

    guard !folder.apps.isEmpty else {
      withAnimation(.easeInOut(duration: 0.18)) {
        _ = rootEntries.remove(at: index)
      }
      presentedFolder = nil
      persistLayout()
      return
    }

    withAnimation(.easeInOut(duration: 0.18)) {
      _ = rootEntries.remove(at: index)
      let entries = folder.apps.map { CatalogEntry.app($0) }
      rootEntries.insert(contentsOf: entries, at: index)
    }
    presentedFolder = nil
    persistLayout()
  }
}
