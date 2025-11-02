import AppKit
import SwiftUI

private let launchyCoordinateSpace = "launchySpace"

struct ContentView: View {
  @EnvironmentObject private var store: AppCatalogStore
  @EnvironmentObject private var settings: AppSettings
  @FocusState private var searchFocused: Bool
  @State private var tileFrames: [String: CGRect] = [:]
  @State private var folderAnchor: CGRect? = nil

  var body: some View {
    GeometryReader { proxy in
      let containerSize = proxy.size
      let metrics = gridMetrics(for: containerSize)
      ZStack {
        backgroundLayer
        contentLayer(gridMetrics: metrics)
      }
      .overlay(alignment: .topTrailing) {
        RefreshButton()
          .padding(32)
      }
      .overlay {
        folderOverlay(for: containerSize)
      }
      .background(TransparentWindowConfigurator())
      .task { await store.refreshCatalogIfNeeded() }
      .onAppear {
        searchFocused = true
        KeyboardMonitor.shared.configure(with: store)
      }
      .onExitCommand {
        if store.dismissPresentedFolderOrClearSearch() {
          return
        }
        NSApp.terminate(nil)
      }
      .onChange(of: store.presentedFolder) { updateFolderAnchor(for: $0) }
      .onChange(of: tileFrames) { frames in
        if let folder = store.presentedFolder,
          let frame = frames[folderTileKey(for: folder)]
        {
          folderAnchor = frame
        }
      }
      .onChange(of: store.isEditing) { editing in
        if editing {
          searchFocused = false
        } else if store.presentedFolder == nil && store.query.isEmpty {
          searchFocused = true
        }
      }
      .onChange(of: store.activeEntries.map { $0.id }) { ids in
        let valid = Set(ids)
        tileFrames = tileFrames.filter { valid.contains($0.key) }
      }
      .animation(.easeInOut(duration: 0.2), value: store.activeEntries.count)
      .animation(.easeInOut(duration: 0.2), value: store.presentedFolder?.id ?? "")
    }
    .coordinateSpace(name: launchyCoordinateSpace)
  }

  private var backgroundLayer: some View {
    Color.black.opacity(0.35)
      .ignoresSafeArea()
  }

  private func contentLayer(gridMetrics: GridMetrics) -> some View {
    VStack(spacing: 24) {
      SearchBar(text: $store.query, isFocused: $searchFocused)
        .padding(.top, 32)
      ScrollView {
        LazyVGrid(columns: gridMetrics.columns, spacing: gridMetrics.spacing) {
          ForEach(store.activeEntries) { entry in
            CatalogEntryTile(
              entry: entry,
              tileFrames: tileFrames,
              onFrameChange: { frame in tileFrames[entry.id] = frame },
              preferredSize: gridMetrics.tileSize
            )
          }
        }
        .padding(.horizontal, gridMetrics.horizontalPadding)
        .padding(.bottom, 48)
      }
      .scrollIndicators(.hidden)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .overlay(alignment: .bottom) {
      ControlFooter()
        .padding(.bottom, 24)
    }
  }

  @ViewBuilder
  private func folderOverlay(for containerSize: CGSize) -> some View {
    if let folder = store.presentedFolder,
      let anchor = folderAnchor
    {
      FolderOverlay(folder: folder, anchor: anchor, containerSize: containerSize)
        .transition(.opacity)
        .zIndex(2)
    }
  }

  private func updateFolderAnchor(for folder: FolderItem?) {
    if let folder = folder {
      searchFocused = false
      let key = folderTileKey(for: folder)
      if let frame = tileFrames[key] {
        folderAnchor = frame
      }
    } else {
      folderAnchor = nil
      if store.query.isEmpty {
        searchFocused = true
      }
    }
  }

  private func folderTileKey(for folder: FolderItem) -> String {
    CatalogEntry.folder(folder).id
  }

  private func gridMetrics(for containerSize: CGSize) -> GridMetrics {
    let spacing: CGFloat = 24
    let horizontalPadding: CGFloat = 72
    var columns = max(1, min(settings.gridColumns, 8))
    let rows = max(1, min(settings.gridRows, 6))

    let availableWidth = max(0, containerSize.width - horizontalPadding * 2)
    var tileWidth: CGFloat = 140
    if availableWidth > 0 {
      var computedWidth: CGFloat = 0
      var candidateColumns = columns
      while candidateColumns >= 1 {
        let raw =
          (availableWidth - spacing * CGFloat(candidateColumns - 1)) / CGFloat(candidateColumns)
        if raw >= 120 {
          computedWidth = raw
          columns = candidateColumns
          break
        }
        candidateColumns -= 1
      }
      if computedWidth <= 0 {
        columns = 1
        computedWidth = availableWidth
      }
      tileWidth = max(120, computedWidth)
    }

    let verticalReserve: CGFloat = 320
    let availableHeight = max(160, containerSize.height - verticalReserve)
    let tileHeightRaw = (availableHeight - spacing * CGFloat(rows - 1)) / CGFloat(rows)
    let tileHeight = max(140, tileHeightRaw)

    let gridItems = Array(
      repeating: GridItem(.fixed(tileWidth), spacing: spacing, alignment: .top),
      count: columns
    )

    return GridMetrics(
      columns: gridItems,
      tileSize: CGSize(width: tileWidth, height: tileHeight),
      spacing: spacing,
      horizontalPadding: horizontalPadding
    )
  }
}

private struct GridMetrics {
  let columns: [GridItem]
  let tileSize: CGSize
  let spacing: CGFloat
  let horizontalPadding: CGFloat
}

private struct SearchBar: View {
  @Binding var text: String
  @FocusState.Binding var isFocused: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.white.opacity(0.7))
      TextField("Search Applications", text: $text)
        .textFieldStyle(.plain)
        .foregroundColor(.white)
        .disableAutocorrection(true)
        .focused($isFocused)
      if !text.isEmpty {
        Button {
          text = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.white.opacity(0.7))
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 16)
        .fill(Color.white.opacity(0.12))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color.white.opacity(0.15), lineWidth: 1)
    )
    .frame(maxWidth: 480)
  }
}

private struct ControlFooter: View {
  var body: some View {
    HStack(spacing: 24) {
      ControlRow(icon: "esc", description: "Close / cancel edit")
      ControlRow(icon: "Hold", description: "Drag to move or folder")
      ControlRow(icon: "⌘R", description: "Reload catalog")
    }
    .padding(.horizontal, 28)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color.white.opacity(0.08))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(Color.white.opacity(0.12), lineWidth: 1)
    )
  }
}

private struct ControlRow: View {
  let icon: String
  let description: String

  var body: some View {
    HStack(spacing: 10) {
      Text(icon)
        .font(.system(size: 16, weight: .semibold, design: .rounded))
        .foregroundColor(.white.opacity(0.85))
      Text(description)
        .font(.system(size: 15, weight: .medium, design: .rounded))
        .foregroundColor(.white.opacity(0.75))
    }
  }
}

private struct RefreshButton: View {
  @EnvironmentObject private var store: AppCatalogStore
  @State private var isRefreshing = false

  var body: some View {
    Button(action: refresh) {
      Image(systemName: "arrow.clockwise.circle.fill")
        .resizable()
        .scaledToFit()
        .frame(width: 36, height: 36)
        .foregroundColor(.white.opacity(0.8))
        .shadow(radius: 4, y: 2)
        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
        .animation(
          isRefreshing
            ? .linear(duration: 0.6).repeatForever(autoreverses: false) : .default,
          value: isRefreshing
        )
    }
    .buttonStyle(.plain)
    .help("Reload installed applications")
    .keyboardShortcut("r", modifiers: [.command])
  }

  private func refresh() {
    guard !isRefreshing else { return }
    isRefreshing = true
    Task {
      await store.reloadCatalog()
      await MainActor.run { isRefreshing = false }
    }
  }
}

private struct CatalogEntryTile: View {
  let entry: CatalogEntry
  let tileFrames: [String: CGRect]
  let onFrameChange: (CGRect) -> Void
  let preferredSize: CGSize

  @EnvironmentObject private var store: AppCatalogStore
  @State private var tileFrame: CGRect = .zero
  @State private var dragOffset: CGSize = .zero
  @State private var dropLocation: CGPoint? = nil
  @State private var dropTileSize: CGSize? = nil
  @State private var wiggleSeed: Double = Double.random(in: 0...(Double.pi * 2))

  var body: some View {
    content
      .frame(width: preferredSize.width, height: preferredSize.height)
      .background(frameTracker)
      .modifier(WiggleModifier(isActive: store.isEditing, seed: wiggleSeed))
      .scaleEffect(store.draggingEntryID == entry.id ? 1.05 : 1.0)
      .offset(store.draggingEntryID == entry.id ? dragOffset : .zero)
      .zIndex(store.draggingEntryID == entry.id ? 2 : 0)
      .overlay(dropHighlight)
      .contentShape(Rectangle())
      .simultaneousGesture(longPressToEdit)
      .highPriorityGesture(dragGesture)
  }

  @ViewBuilder
  private var content: some View {
    switch entry {
    case .app(let app):
      AppIconView(app: app)
    case .folder(let folder):
      FolderIconView(folder: folder)
    }
  }

  private var frameTracker: some View {
    GeometryReader { geometry in
      Color.clear
        .onAppear { updateGeometry(with: geometry) }
        .onChange(of: geometry.size) { _ in updateGeometry(with: geometry) }
        .onChange(of: geometry.frame(in: .named(launchyCoordinateSpace)).origin) { _ in
          updateGeometry(with: geometry)
        }
    }
    .allowsHitTesting(false)
  }

  private var longPressToEdit: some Gesture {
    LongPressGesture(minimumDuration: 0.5).onEnded { _ in store.beginEditing() }
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 6)
      .onChanged { value in
        if store.draggingEntryID != entry.id {
          store.beginDragging(entryID: entry.id)
        }
        dragOffset = value.translation

        let globalPoint = CGPoint(
          x: tileFrame.minX + value.location.x,
          y: tileFrame.minY + value.location.y
        )

        if let target = targetInfo(for: globalPoint) {
          store.updateDraggingTarget(
            entryID: target.id,
            location: target.location,
            tileSize: target.size
          )
          dropLocation = target.location
          dropTileSize = target.size
        } else {
          store.updateDraggingTarget(entryID: nil, location: nil, tileSize: nil)
          dropLocation = nil
          dropTileSize = nil
        }
      }
      .onEnded { _ in
        completeDrop()
      }
  }

  private func targetInfo(for globalPoint: CGPoint) -> (
    id: String, location: CGPoint, size: CGSize
  )? {
    let candidates = tileFrames.filter { key, _ in key != entry.id }
    guard let match = candidates.first(where: { $0.value.contains(globalPoint) }) else {
      return nil
    }
    let frame = match.value
    let localPoint = CGPoint(x: globalPoint.x - frame.minX, y: globalPoint.y - frame.minY)
    return (match.key, localPoint, frame.size)
  }

  private func completeDrop() {
    let success = store.completeDrop(
      on: store.targetedEntryID,
      location: dropLocation,
      tileSize: dropTileSize
    )
    if !success {
      store.abandonDrag()
    }
    resetDragState()
  }

  private func resetDragState() {
    dragOffset = .zero
    dropLocation = nil
    dropTileSize = nil
  }

  private func updateGeometry(with geometry: GeometryProxy) {
    let frame = geometry.frame(in: .named(launchyCoordinateSpace))
    if !frame.isNull && !frame.isInfinite {
      tileFrame = frame
      onFrameChange(frame)
    }
  }

  private var dropHighlight: some View {
    RoundedRectangle(cornerRadius: 18)
      .stroke(
        Color.white.opacity(store.isEditing && store.targetedEntryID == entry.id ? 0.6 : 0),
        lineWidth: store.isEditing && store.targetedEntryID == entry.id ? 2 : 0
      )
      .animation(
        .easeInOut(duration: 0.15),
        value: store.targetedEntryID == entry.id && store.isEditing
      )
  }
}

private struct WiggleModifier: ViewModifier {
  let isActive: Bool
  let seed: Double

  func body(content: Content) -> some View {
    Group {
      if isActive {
        TimelineView(.animation) { timeline in
          let time = timeline.date.timeIntervalSinceReferenceDate
          let angle = sin(time * 8 + seed) * 2.4
          let scaleVariance = sin(time * 6 + seed) * 0.015
          content
            .rotationEffect(.degrees(angle))
            .scaleEffect(1 + scaleVariance)
        }
      } else {
        content
      }
    }
  }
}
