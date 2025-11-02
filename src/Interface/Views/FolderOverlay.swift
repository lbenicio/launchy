import SwiftUI

private let launchyCoordinateSpaceName = "launchySpace"

struct FolderOverlay: View {
  let folder: FolderItem
  let anchor: CGRect
  let containerSize: CGSize
  let tileFrames: [String: CGRect]
  let onDragLocationChange: (CGPoint?) -> Void

    @EnvironmentObject private var store: AppCatalogStore
    @State private var isExpanded = false
    @State private var isClosing = false
  @State private var localFolder: FolderItem
  @State private var pendingFolderUpdate: FolderItem? = nil
  @State private var activeDragAppID: String? = nil

    private let animation = Animation.spring(
    response: 0.36,
    dampingFraction: 0.82,
    blendDuration: 0.12
  )

    private var gridLayout: [GridItem] {
        [GridItem(.adaptive(minimum: 110, maximum: 140), spacing: 22)]
    }

    private var targetSize: CGSize {
        let width = max(min(containerSize.width - 160, 520), anchor.width)
    let rows = max(1, ceil(Double(max(localFolder.apps.count, 1)) / 4.0))
        let gridHeight = rows * 120.0
        let height = max(min(containerSize.height - 160, gridHeight + 120), anchor.height)
        return CGSize(width: width, height: height)
    }

  init(
    folder: FolderItem,
    anchor: CGRect,
    containerSize: CGSize,
    tileFrames: [String: CGRect],
    onDragLocationChange: @escaping (CGPoint?) -> Void
  ) {
    self.folder = folder
    self.anchor = anchor
    self.containerSize = containerSize
    self.tileFrames = tileFrames
    self.onDragLocationChange = onDragLocationChange
    _localFolder = State(initialValue: folder)
    }

    var body: some View {
        ZStack {
      Color.black.opacity(isExpanded ? 0.72 : 0)
                .ignoresSafeArea()
                .animation(animation, value: isExpanded)
                .onTapGesture { close() }

            folderCard
                .frame(width: targetSize.width, height: targetSize.height)
                .scaleEffect(
                    x: isExpanded ? 1 : collapsedScaleX,
                    y: isExpanded ? 1 : collapsedScaleY,
                    anchor: .center
                )
                .position(
                    x: isExpanded ? containerSize.width / 2 : anchor.midX,
                    y: isExpanded ? containerSize.height / 2 : anchor.midY
                )
                .shadow(
                    color: .black.opacity(isExpanded ? 0.28 : 0.12),
                    radius: isExpanded ? 22 : 10,
                    y: isExpanded ? 14 : 4
                )
                .contentShape(Rectangle())
        .allowsHitTesting(activeDragAppID == nil)
        }
        .animation(animation, value: isExpanded)
        .onAppear {
      withAnimation(animation) { isExpanded = true }
    }
    .onChange(of: folder) { newFolder in
      if activeDragAppID == nil {
        localFolder = newFolder
      } else {
        pendingFolderUpdate = newFolder
      }
    }
    .onChange(of: activeDragAppID) { value in
      if value == nil, let pending = pendingFolderUpdate {
        localFolder = pending
        pendingFolderUpdate = nil
      }
    }
  }

  private var collapsedScaleX: CGFloat {
    guard targetSize.width > 0 else { return 1 }
    let ratio = anchor.width / targetSize.width
    return min(max(ratio, 0.32), 1)
  }

  private var collapsedScaleY: CGFloat {
    guard targetSize.height > 0 else { return 1 }
    let ratio = anchor.height / targetSize.height
    return min(max(ratio, 0.32), 1)
  }

    private var folderCard: some View {
        VStack(spacing: 22) {
            HStack {
        Text(localFolder.name)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                Spacer()
        if store.isEditing {
          if !localFolder.apps.isEmpty {
            Button("Dissolve") {
              store.dissolveFolder(id: localFolder.id)
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(.white.opacity(0.85))
            .buttonStyle(.borderless)
            .disabled(activeDragAppID != nil)
          }
        } else {
          Button("Edit") {
            store.beginEditing(preservingFolder: true)
          }
          .font(.system(size: 14, weight: .semibold, design: .rounded))
          .foregroundColor(.white.opacity(0.85))
          .buttonStyle(.borderless)
        }
                Button(action: close) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(radius: 6, y: 3)
                }
                .buttonStyle(.plain)
        .disabled(activeDragAppID != nil)
            }
            .padding(.horizontal, 4)

            ScrollView {
                LazyVGrid(columns: gridLayout, spacing: 22) {
          if store.isEditing {
            if localFolder.apps.isEmpty {
              Text("No apps remain in this folder")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.65))
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            } else {
              ForEach(localFolder.apps) { app in
                FolderEditableAppTile(
                  app: app,
                  folderID: localFolder.id,
                  tileFrames: tileFrames,
                  activeDragAppID: $activeDragAppID,
                  onDragLocationChange: onDragLocationChange
                )
              }
            }
          } else {
            ForEach(localFolder.apps) { app in
              AppIconView(app: app)
                .allowsHitTesting(activeDragAppID == nil)
                .simultaneousGesture(
                  LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    store.beginEditing(preservingFolder: true)
                  }
                )
            }
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
        }
        .padding(28)
        .background(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
        .fill(Color.black.opacity(0.62))
                .background(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
            .fill(Color.black.opacity(0.45))
            .blur(radius: 24)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 34, style: .continuous)
        .stroke(Color.white.opacity(0.24), lineWidth: 1.2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
    }

    private func close() {
    guard !isClosing, activeDragAppID == nil else { return }
    onDragLocationChange(nil)
        isClosing = true
    withAnimation(animation) { isExpanded = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            store.dismissPresentedFolder()
            isClosing = false
        }
    }
}

private struct FolderEditableAppTile: View {
  let app: AppItem
  let folderID: String
  let tileFrames: [String: CGRect]
  @Binding var activeDragAppID: String?
  let onDragLocationChange: (CGPoint?) -> Void

  @EnvironmentObject private var store: AppCatalogStore
  @State private var tileFrame: CGRect = .zero
  @State private var dragOffset: CGSize = .zero
  @State private var dropLocation: CGPoint? = nil
  @State private var dropTileSize: CGSize? = nil
  @State private var hasBegunDrag = false

  private var entryID: String { CatalogEntry.app(app).id }

  var body: some View {
    AppIconView(app: app)
      .allowsHitTesting(false)
      .opacity(activeDragAppID == app.id ? 0.35 : 1)
      .scaleEffect(store.draggingEntryID == entryID ? 1.05 : 1)
      .offset(hasBegunDrag ? dragOffset : .zero)
      .background(frameTracker)
      .zIndex(store.draggingEntryID == entryID ? 1 : 0)
      .contentShape(Rectangle())
      .gesture(dragGesture)
  }

  private var dragGesture: some Gesture {
    DragGesture(minimumDistance: 6)
      .onChanged { value in
        if !hasBegunDrag {
          store.beginDraggingAppFromFolder(folderID: folderID, appID: app.id)
          activeDragAppID = app.id
          hasBegunDrag = true
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
        let success = store.completeDrop(
          on: store.targetedEntryID,
          location: dropLocation,
          tileSize: dropTileSize
        )
        if !success {
          store.abandonDrag()
        }
        onDragLocationChange(nil)
        resetDragState()
      }
  }

  private func resetDragState() {
    dragOffset = .zero
    dropLocation = nil
    dropTileSize = nil
    hasBegunDrag = false
    DispatchQueue.main.async {
      activeDragAppID = nil
    }
    onDragLocationChange(nil)
  }

  private func targetInfo(for globalPoint: CGPoint) -> (
    id: String, location: CGPoint, size: CGSize
  )? {
    let candidates = tileFrames.filter { key, _ in key != entryID }
    guard let match = candidates.first(where: { $0.value.contains(globalPoint) }) else {
      return nil
    }
    let frame = match.value
    let localPoint = CGPoint(x: globalPoint.x - frame.minX, y: globalPoint.y - frame.minY)
    return (match.key, localPoint, frame.size)
  }

  private var frameTracker: some View {
    GeometryReader { geometry in
      Color.clear
        .onAppear { updateGeometry(with: geometry) }
        .onChange(of: geometry.size) { _ in updateGeometry(with: geometry) }
        .onChange(of: geometry.frame(in: .named(launchyCoordinateSpaceName)).origin) { _ in
          updateGeometry(with: geometry)
        }
    }
    .allowsHitTesting(false)
  }

  private func updateGeometry(with geometry: GeometryProxy) {
    let frame = geometry.frame(in: .named(launchyCoordinateSpaceName))
    if !frame.isNull && !frame.isInfinite {
      tileFrame = frame
    }
  }
}
