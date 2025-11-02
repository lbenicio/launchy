import SwiftUI

private let launchyCoordinateSpaceName = "launchySpace"

struct FolderOverlay: View {
    let folder: FolderItem
    let anchor: CGRect
    let containerSize: CGSize
    let tileFrames: [String: CGRect]
    let onDragLocationChange: (CGPoint?) -> Void

    @EnvironmentObject private var store: AppCatalogStore
    @EnvironmentObject private var settings: AppSettings
    @State private var isExpanded = false
    @State private var isClosing = false
    @State private var localFolder: FolderItem
    @State private var pendingFolderUpdate: FolderItem? = nil
    @State private var activeDragAppID: String? = nil
    @State private var currentPage = 0
    @State private var folderHorizontalDragOffset: CGFloat = 0

    private let animation = Animation.spring(
        response: 0.36,
        dampingFraction: 0.82,
        blendDuration: 0.12
    )

    private let overlayHorizontalPadding: CGFloat = 32
    private let overlayVerticalPadding: CGFloat = 44
    private let overlayMargin: CGFloat = 200

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

    private var metrics: GridMetrics {
        GridMetricsCalculator.make(
            containerSize: containerSize,
            columns: settings.gridColumns,
            rows: settings.gridRows
        )
    }

    private var pages: [[AppItem]] {
        let apps = localFolder.apps
        let capacity = max(1, metrics.capacity)
        guard !apps.isEmpty else { return [[]] }

        var result: [[AppItem]] = []
        var index = 0
        while index < apps.count {
            let end = min(index + capacity, apps.count)
            result.append(Array(apps[index ..< end]))
            index = end
        }
        return result
    }

    private var targetSize: CGSize {
        let desiredWidth = metrics.contentWidth + overlayHorizontalPadding * 2
        let desiredHeight = metrics.contentHeight + overlayVerticalPadding * 2
        let maxWidth = max(anchor.width, containerSize.width - overlayMargin)
        let maxHeight = max(anchor.height, containerSize.height - overlayMargin)
        let width = min(maxWidth, desiredWidth)
        let height = min(maxHeight, desiredHeight)
        return CGSize(width: max(width, anchor.width), height: max(height, anchor.height))
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
        .onChange(of: localFolder.apps.map(\.id)) { _ in
            let pageCount = pages.count
            currentPage = min(currentPage, max(0, pageCount - 1))
            folderHorizontalDragOffset = 0
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
            header

            if store.isEditing, localFolder.apps.isEmpty {
                emptyFolderView
            } else {
                folderPages
            }
        }
        .padding(.vertical, overlayVerticalPadding)
        .padding(.horizontal, overlayHorizontalPadding)
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

    private var header: some View {
        HStack(spacing: 12) {
            Text(localFolder.name)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))
                .lineLimit(1)
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
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(activeDragAppID != nil)
        }
    }

    private var folderPages: some View {
        let layout = metrics
        let pages = self.pages
        let pageCount = pages.count
        let pageWidth = layout.contentWidth
        let pageHeight = layout.contentHeight

        return VStack(spacing: 16) {
            GeometryReader { _ in
                HStack(spacing: 0) {
                    ForEach(pages.indices, id: \.self) { index in
                        let apps = pages[index]
                        folderPage(apps: apps, metrics: layout)
                            .frame(width: pageWidth, height: pageHeight, alignment: .top)
                    }
                }
                .frame(width: pageWidth * CGFloat(max(pageCount, 1)), alignment: .leading)
                .offset(x: -CGFloat(currentPage) * pageWidth + folderHorizontalDragOffset)
                .animation(.easeInOut(duration: 0.2), value: currentPage)
                .gesture(
                    DragGesture(minimumDistance: 6)
                        .onChanged { value in
                            folderHorizontalDragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold = pageWidth * 0.2
                            var newPage = currentPage
                            if value.translation.width < -threshold {
                                newPage = min(currentPage + 1, pageCount - 1)
                            } else if value.translation.width > threshold {
                                newPage = max(currentPage - 1, 0)
                            }
                            currentPage = newPage
                            withAnimation(.easeInOut(duration: 0.2)) {
                                folderHorizontalDragOffset = 0
                            }
                        }
                )
            }
            .frame(width: pageWidth, height: pageHeight)
            .clipped()

            if pageCount > 1 {
                FolderPageIndicator(currentPage: currentPage, totalPages: pageCount) { index in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        currentPage = index
                        folderHorizontalDragOffset = 0
                    }
                }
            }
        }
    }

    private func folderPage(apps: [AppItem], metrics: GridMetrics) -> some View {
        LazyVGrid(columns: metrics.columns, spacing: metrics.spacing) {
            ForEach(apps) { app in
                folderTile(for: app, metrics: metrics)
            }

            let placeholders = max(0, metrics.capacity - apps.count)
            ForEach(0 ..< placeholders, id: \.self) { _ in
                Color.clear
                    .frame(width: metrics.tileSize.width, height: metrics.tileSize.height)
            }
        }
        .frame(width: metrics.contentWidth, height: metrics.contentHeight, alignment: .top)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private func folderTile(for app: AppItem, metrics: GridMetrics) -> some View {
        if store.isEditing {
            FolderEditableAppTile(
                app: app,
                folderID: localFolder.id,
                tileFrames: tileFrames,
                activeDragAppID: $activeDragAppID,
                onDragLocationChange: onDragLocationChange
            )
            .frame(width: metrics.tileSize.width, height: metrics.tileSize.height)
        } else {
            AppIconView(app: app)
                .frame(width: metrics.tileSize.width, height: metrics.tileSize.height)
                .allowsHitTesting(activeDragAppID == nil)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        store.beginEditing(preservingFolder: true)
                    }
                )
        }
    }

    private var emptyFolderView: some View {
        VStack(spacing: 12) {
            Text("No apps remain in this folder")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            Text("Drag items back in or dissolve the folder to remove it.")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct FolderPageIndicator: View {
    let currentPage: Int
    let totalPages: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< totalPages, id: \.self) { index in
                Button {
                    onSelect(index)
                } label: {
                    Circle()
                        .fill(Color.white.opacity(index == currentPage ? 0.9 : 0.35))
                        .frame(width: index == currentPage ? 10 : 8, height: index == currentPage ? 10 : 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule().fill(Color.white.opacity(0.12))
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
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
        if !frame.isNull, !frame.isInfinite {
            tileFrame = frame
        }
    }
}
