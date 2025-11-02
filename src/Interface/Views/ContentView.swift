import AppKit
import SwiftUI

private let launchyCoordinateSpace = "launchySpace"

struct ContentView: View {
  @EnvironmentObject private var store: AppCatalogStore
  @EnvironmentObject private var settings: AppSettings
  @FocusState private var searchFocused: Bool
  @State private var tileFrames: [String: CGRect] = [:]
  @State private var folderAnchor: CGRect? = nil
  @State private var selectedPage: Int = 0
  @State private var horizontalDragOffset: CGFloat = 0
  @State private var containerDimensions: CGSize = .zero
  @State private var currentPageCount: Int = 1
  @State private var edgeAutoAdvanceDirection: EdgeAutoAdvanceDirection? = nil
  @State private var edgeAutoAdvanceTask: Task<Void, Never>? = nil
  @State private var lastEdgeDragLocation: CGPoint? = nil
  @State private var scrollAccumulation: CGFloat = 0

  var body: some View {
    GeometryReader { proxy in
      let containerSize = proxy.size
      let metrics = GridMetricsCalculator.make(
        containerSize: containerSize,
        columns: settings.gridColumns,
        rows: settings.gridRows
      )
      ZStack {
        backgroundLayer
        contentLayer(gridMetrics: metrics)
      }
      .overlay {
        ScrollWheelCaptureView(onScroll: { delta in
          Task { @MainActor in
            handleScrollInput(delta: delta)
          }
        })
        .allowsHitTesting(false)
      }
      .overlay {
        KeyPressCaptureView { event in
          handleKeyPress(event)
        }
        .allowsHitTesting(false)
      }
      .overlay {
        folderOverlay(for: containerSize)
      }
      .overlay(alignment: .bottomTrailing) {
        settingsShortcut
      }
      .background(TransparentWindowConfigurator())
      .task { await store.refreshCatalogIfNeeded() }
      .onAppear {
        searchFocused = true
        KeyboardMonitor.shared.configure(with: store)
        containerDimensions = containerSize
      }
      .onChange(of: containerSize) { containerDimensions = $0 }
      .onExitCommand {
        NSApp.terminate(nil)
      }
      .onChange(of: store.presentedFolder) {
        updateFolderAnchor(for: $0)
        if $0 == nil {
          Task { @MainActor in
            handleEdgeHover(with: nil)
          }
        }
      }
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
        if !editing {
          Task { @MainActor in
            handleEdgeHover(with: nil)
          }
        }
      }
      .onChange(of: store.activeEntries.map { $0.id }) { ids in
        let valid = Set(ids)
        tileFrames = tileFrames.filter { valid.contains($0.key) }
      }
      .onChange(of: store.draggingEntryID) { id in
        if id == nil {
          Task { @MainActor in
            handleEdgeHover(with: nil)
          }
        }
      }
      .onChange(of: store.query) { _ in
        selectedPage = 0
        horizontalDragOffset = 0
        Task { @MainActor in
          handleEdgeHover(with: nil)
        }
      }
      .animation(.easeInOut(duration: 0.2), value: store.activeEntries.count)
      .animation(.easeInOut(duration: 0.2), value: store.presentedFolder?.id ?? "")
    }
    .onDisappear { cancelEdgeAutoAdvance() }
    .coordinateSpace(name: launchyCoordinateSpace)
  }

  private var backgroundLayer: some View {
    Color.black.opacity(0.35)
      .ignoresSafeArea()
      .contentShape(Rectangle())
      .onTapGesture {
        NSApp.terminate(nil)
      }
  }

  private var settingsShortcut: some View {
    Button {
      SettingsWindowManager.shared.settingsProvider = { settings }
      SettingsWindowManager.shared.show()
    } label: {
      Image(systemName: "gearshape.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(.white.opacity(0.85))
        .padding(8)
        .background(
          Circle().fill(Color.white.opacity(0.08))
        )
        .overlay(
          Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .padding(.trailing, 24)
    .padding(.bottom, 24)
    .opacity(0.9)
    .accessibilityLabel("Open Settings")
    .help("Open Settings")
  }

  private func contentLayer(gridMetrics: GridMetrics) -> some View {
    let pages = paginatedEntries(using: gridMetrics)
    let pageCount = pages.count
    updateCurrentPageCount(pageCount)

    return VStack(spacing: 24) {
      SearchBar(text: $store.query, isFocused: $searchFocused)
        .padding(.top, 32)
      GeometryReader { pagingProxy in
        let pageWidth = max(1, pagingProxy.size.width)
        let pageHeight = pagingProxy.size.height

        HStack(spacing: 0) {
          ForEach(pages.indices, id: \.self) { index in
            let entries = pages[index]
            LazyVGrid(columns: gridMetrics.columns, spacing: gridMetrics.spacing) {
              ForEach(entries) { entry in
                CatalogEntryTile(
                  entry: entry,
                  tileFrames: tileFrames,
                  onFrameChange: { frame in tileFrames[entry.id] = frame },
                  preferredSize: gridMetrics.tileSize,
                  onDragLocationChange: { point in
                    Task { @MainActor in
                      handleEdgeHover(with: point)
                    }
                  }
                )
              }
            }
            .padding(.horizontal, gridMetrics.horizontalPadding)
            .padding(.bottom, 48)
            .frame(width: pageWidth, height: pageHeight, alignment: .top)
          }
        }
        .offset(x: -CGFloat(selectedPage) * pageWidth + horizontalDragOffset)
        .animation(.easeInOut(duration: 0.25), value: selectedPage)
        .simultaneousGesture(
          DragGesture(minimumDistance: 10)
            .onChanged { value in
              guard store.draggingEntryID == nil else {
                horizontalDragOffset = 0
                return
              }
              let translation = value.translation.width
              if (selectedPage == 0 && translation > 0)
                || (selectedPage == pageCount - 1 && translation < 0)
              {
                horizontalDragOffset = translation / 3
              } else {
                horizontalDragOffset = translation
              }
            }
            .onEnded { value in
              guard store.draggingEntryID == nil else {
                horizontalDragOffset = 0
                return
              }
              let threshold = pageWidth * 0.2
              var newPage = selectedPage
              if value.translation.width < -threshold {
                newPage = min(selectedPage + 1, pageCount - 1)
              } else if value.translation.width > threshold {
                newPage = max(selectedPage - 1, 0)
              }
              selectedPage = newPage
              horizontalDragOffset = 0
            }
        )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .clipped()

      if pageCount > 1 {
        PageIndicator(currentPage: selectedPage, totalPages: pageCount) { index in
          guard index >= 0 && index < pageCount else { return }
          selectedPage = index
          horizontalDragOffset = 0
        }
        .padding(.bottom, 12)
        .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .onChange(of: pageCount) { newValue in
      let maxPage = max(0, newValue - 1)
      if selectedPage > maxPage {
        selectedPage = maxPage
      }
      horizontalDragOffset = 0
    }
  }

  @ViewBuilder
  private func folderOverlay(for containerSize: CGSize) -> some View {
    if let folder = store.presentedFolder,
      let anchor = folderAnchor
    {
      FolderOverlay(
        folder: folder,
        anchor: anchor,
        containerSize: containerSize,
        tileFrames: tileFrames,
        onDragLocationChange: { point in
          Task { @MainActor in
            handleEdgeHover(with: point)
          }
        }
      )
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

  private func updateCurrentPageCount(_ newValue: Int) {
    guard currentPageCount != newValue else { return }
    Task { @MainActor in
      currentPageCount = newValue
      if selectedPage >= newValue {
        selectedPage = max(0, newValue - 1)
      }
    }
  }

  @MainActor
  private func handleEdgeHover(with globalPoint: CGPoint?) {
    guard store.draggingEntryID != nil else {
      cancelEdgeAutoAdvance()
      lastEdgeDragLocation = nil
      return
    }

    guard containerDimensions.width > 0 else { return }

    guard let point = globalPoint else {
      lastEdgeDragLocation = nil
      cancelEdgeAutoAdvance()
      return
    }

    lastEdgeDragLocation = point

    let inset: CGFloat = 96
    var direction: EdgeAutoAdvanceDirection? = nil
    if point.x <= inset {
      direction = .previous
    } else if point.x >= containerDimensions.width - inset {
      direction = .next
    }

    guard let resolvedDirection = direction else {
      cancelEdgeAutoAdvance()
      return
    }

    if edgeAutoAdvanceDirection != resolvedDirection {
      edgeAutoAdvanceDirection = resolvedDirection
      edgeAutoAdvanceTask?.cancel()
      edgeAutoAdvanceTask = scheduleEdgeAutoAdvance(direction: resolvedDirection)
    } else if edgeAutoAdvanceTask == nil {
      edgeAutoAdvanceTask = scheduleEdgeAutoAdvance(direction: resolvedDirection)
    }
  }

  private func scheduleEdgeAutoAdvance(direction: EdgeAutoAdvanceDirection)
    -> Task<Void, Never>
  {
    Task {
      try? await Task.sleep(nanoseconds: 260_000_000)
      if Task.isCancelled { return }
      await MainActor.run {
        applyEdgeAutoAdvance(direction)
      }
    }
  }

  @MainActor
  private func applyEdgeAutoAdvance(_ direction: EdgeAutoAdvanceDirection) {
    guard currentPageCount > 1 else {
      cancelEdgeAutoAdvance()
      return
    }

    switch direction {
    case .previous:
      guard selectedPage > 0 else {
        cancelEdgeAutoAdvance()
        return
      }
      selectedPage -= 1
    case .next:
      guard selectedPage < currentPageCount - 1 else {
        cancelEdgeAutoAdvance()
        return
      }
      selectedPage += 1
    }

    horizontalDragOffset = 0
    scrollAccumulation = 0
    edgeAutoAdvanceTask = nil

    if let lastPoint = lastEdgeDragLocation {
      handleEdgeHover(with: lastPoint)
    }
  }

  @MainActor
  private func cancelEdgeAutoAdvance() {
    edgeAutoAdvanceTask?.cancel()
    edgeAutoAdvanceTask = nil
    edgeAutoAdvanceDirection = nil
    lastEdgeDragLocation = nil
  }

  @MainActor
  private func handleScrollInput(delta: CGFloat) {
    guard store.draggingEntryID == nil else { return }
    guard currentPageCount > 1 else { return }
    guard store.presentedFolder == nil else { return }
    let adjustedDelta = delta * 1.25
    guard abs(adjustedDelta) > 0.5 else { return }

    if (scrollAccumulation > 0 && adjustedDelta < 0)
      || (scrollAccumulation < 0 && adjustedDelta > 0)
    {
      scrollAccumulation = adjustedDelta
    } else {
      scrollAccumulation += adjustedDelta
    }

    let threshold = CGFloat(settings.scrollThreshold)
    if scrollAccumulation <= -threshold {
      if selectedPage < currentPageCount - 1 {
        selectedPage += 1
        horizontalDragOffset = 0
      }
      scrollAccumulation = 0
    } else if scrollAccumulation >= threshold {
      if selectedPage > 0 {
        selectedPage -= 1
        horizontalDragOffset = 0
      }
      scrollAccumulation = 0
    }
  }

  @MainActor
  private func handleKeyPress(_ event: NSEvent) -> Bool {
    guard event.type == .keyDown else { return false }
    guard !searchFocused else { return false }
    guard let keyWindow = NSApp.keyWindow, keyWindow.level == .launchyPrimary else {
      return false
    }

    let disallowedModifiers: NSEvent.ModifierFlags = [.command, .option, .control]
    if !event.modifierFlags.intersection(disallowedModifiers).isEmpty {
      return false
    }

    guard let characters = event.characters, !characters.isEmpty else { return false }
    let scalars = characters.unicodeScalars
    guard !scalars.contains(where: { $0.properties.generalCategory == .control }) else {
      return false
    }

    if store.isEditing {
      store.endEditing()
    }
    if store.presentedFolder != nil {
      store.dismissPresentedFolder()
    }

    searchFocused = true
    store.query.append(contentsOf: characters)
    scrollAccumulation = 0

    return true
  }

  private func paginatedEntries(using metrics: GridMetrics) -> [[CatalogEntry]] {
    let entries = store.activeEntries
    let capacity = metrics.capacity
    guard capacity > 0 else { return entries.isEmpty ? [[]] : [entries] }

    if entries.isEmpty {
      return [[]]
    }

    var pages: [[CatalogEntry]] = []
    var index = 0
    while index < entries.count {
      let end = min(index + capacity, entries.count)
      pages.append(Array(entries[index..<end]))
      index = end
    }
    return pages
  }

}

private enum EdgeAutoAdvanceDirection {
  case previous
  case next
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

private struct PageIndicator: View {
  let currentPage: Int
  let totalPages: Int
  let onSelect: (Int) -> Void

  var body: some View {
    HStack(spacing: 10) {
      ForEach(0..<totalPages, id: \.self) { index in
        Button {
          onSelect(index)
        } label: {
          Circle()
            .fill(Color.white.opacity(index == currentPage ? 0.9 : 0.35))
            .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
            .animation(.easeInOut(duration: 0.2), value: currentPage)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 6)
    .background(
      Capsule()
        .fill(Color.white.opacity(0.12))
    )
    .overlay(
      Capsule()
        .stroke(Color.white.opacity(0.18), lineWidth: 1)
    )
  }
}

private struct CatalogEntryTile: View {
  let entry: CatalogEntry
  let tileFrames: [String: CGRect]
  let onFrameChange: (CGRect) -> Void
  let preferredSize: CGSize
  let onDragLocationChange: (CGPoint?) -> Void

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
      .opacity(isHiddenDuringFolderDrag ? 0 : 1)
      .allowsHitTesting(!isHiddenDuringFolderDrag)
      .overlay(dropHighlight)
      .contentShape(tileHitShape)
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
        onDragLocationChange(globalPoint)
      }
      .onEnded { _ in
        completeDrop()
        onDragLocationChange(nil)
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
    onDragLocationChange(nil)
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

  private var isHiddenDuringFolderDrag: Bool {
    store.draggingFromFolder && store.draggingEntryID == entry.id
  }

  private var tileHitShape: CatalogTileHitShape {
    let targetWidth = min(preferredSize.width, 128)
    let targetHeight = min(preferredSize.height, 168)
    return CatalogTileHitShape(targetWidth: targetWidth, targetHeight: targetHeight)
  }
}

private struct CatalogTileHitShape: Shape {
  let targetWidth: CGFloat
  let targetHeight: CGFloat

  func path(in rect: CGRect) -> Path {
    let width = min(rect.width, targetWidth)
    let height = min(rect.height, targetHeight)
    let dx = max(0, (rect.width - width) / 2)
    let dy = max(0, (rect.height - height) / 2)
    let insetRect = rect.insetBy(dx: dx, dy: dy)
    let cornerRadius: CGFloat = 24
    return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      .path(in: insetRect)
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
          let angle = sin(time * 5 + seed) * 2.4
          let scaleVariance = sin(time * 3.5 + seed) * 0.015
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

private struct ScrollWheelCaptureView: NSViewRepresentable {
  let onScroll: (CGFloat) -> Void

  func makeNSView(context: Context) -> NSView {
    let view = ScrollCaptureView()
    view.onScroll = onScroll
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let view = nsView as? ScrollCaptureView {
      view.onScroll = onScroll
    }
  }

  private final class ScrollCaptureView: NSView {
    var onScroll: ((CGFloat) -> Void)?
    private var eventMonitor: Any?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window != nil {
        installMonitor()
      } else {
        removeMonitor()
      }
    }

    deinit {
      removeMonitor()
    }

    private func installMonitor() {
      guard eventMonitor == nil else { return }
      eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
        self?.forward(event: event)
        return event
      }
    }

    private func removeMonitor() {
      if let eventMonitor {
        NSEvent.removeMonitor(eventMonitor)
        self.eventMonitor = nil
      }
    }

    private func forward(event: NSEvent) {
      guard let handler = onScroll else { return }

      let horizontal = event.scrollingDeltaX
      let vertical = event.scrollingDeltaY
      var delta: CGFloat = 0
      if abs(horizontal) >= abs(vertical), horizontal != 0 {
        delta = horizontal
      } else if vertical != 0 {
        delta = -vertical
      }
      guard delta != 0 else { return }

      var adjusted = delta
      if event.hasPreciseScrollingDeltas {
        adjusted *= 10
      }
      if event.isDirectionInvertedFromDevice {
        adjusted = -adjusted
      }

      DispatchQueue.main.async {
        handler(adjusted)
      }
    }
  }
}

private struct KeyPressCaptureView: NSViewRepresentable {
  let onKeyPress: (NSEvent) -> Bool

  func makeNSView(context: Context) -> NSView {
    let view = KeyCaptureView()
    view.onKeyPress = onKeyPress
    return view
  }

  func updateNSView(_ nsView: NSView, context: Context) {
    if let view = nsView as? KeyCaptureView {
      view.onKeyPress = onKeyPress
    }
  }

  private final class KeyCaptureView: NSView {
    var onKeyPress: ((NSEvent) -> Bool)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window != nil {
        installMonitor()
      } else {
        removeMonitor()
      }
    }

    deinit {
      removeMonitor()
    }

    private func installMonitor() {
      guard monitor == nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self else { return event }
        let consumed = self.onKeyPress?(event) ?? false
        return consumed ? nil : event
      }
    }

    private func removeMonitor() {
      if let monitor {
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
      }
    }
  }
}
