import SwiftUI
import UniformTypeIdentifiers

struct FolderContentView: View {
    let folderID: UUID
    @ObservedObject var viewModel: LaunchyViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore
    @State private var editingName: String = ""
    @State private var folderPage: Int = 0

    var body: some View {
        let folder = viewModel.folder(by: folderID)
        GeometryReader { proxy in
            if let folder {
                let settings = settingsStore.settings
                // Tile sizing: cap the tile-content area for readability on wide windows
                let tileAreaWidth = min(proxy.size.width - 72, 480)
                let spacing: CGFloat = 22
                let totalSpacing = CGFloat(max(settings.folderColumns - 1, 0)) * spacing
                let tileWidth =
                    (tileAreaWidth - 24 - totalSpacing) / CGFloat(max(settings.folderColumns, 1))
                let tileDimension = max(72, tileWidth)
                let columns = Array(
                    repeating: GridItem(.fixed(tileDimension), spacing: spacing),
                    count: max(settings.folderColumns, 1)
                )

                let pageCapacity = max(1, settings.folderColumns * settings.folderRows)
                let appPages = folder.apps.chunked(into: pageCapacity)
                let totalFolderPages = max(appPages.count, 1)
                let safePageIndex = min(folderPage, totalFolderPages - 1)
                let currentApps = appPages.isEmpty ? [] : appPages[safePageIndex]

                VStack(spacing: 20) {
                    // MARK: Header
                    HStack {
                        if viewModel.isEditing {
                            TextField(
                                "Folder Name",
                                text: $editingName,
                                onCommit: {
                                    viewModel.renameFolder(folderID, to: editingName)
                                }
                            )
                            .font(.system(size: 20, weight: .semibold))
                            .textFieldStyle(.plain)
                            .onAppear { editingName = folder.name }
                            .onChange(of: folder.name) { _, newName in
                                editingName = newName
                            }
                        } else {
                            Text(folder.name)
                                .font(.system(size: 20, weight: .semibold))
                                .textCase(.none)
                        }
                        Spacer()
                        if viewModel.isEditing {
                            Button {
                                viewModel.disbandFolder(folder.id)
                            } label: {
                                Label("Split", systemImage: "square.stack.3d.down.forward.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .labelStyle(.iconOnly)
                                    .padding(8)
                                    .background(Color.white.opacity(0.18), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 8)
                            .accessibilityLabel("Split folder")
                            .accessibilityHint("Removes the folder and returns its apps to the grid")
                        }
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                viewModel.closeFolder()
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24, weight: .bold))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.black.opacity(0.35))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close folder")
                    }

                    if viewModel.isEditing {
                        IconColorPicker(
                            selectedColor: Binding(
                                get: { folder.color },
                                set: { viewModel.updateFolderColor(folderID, to: $0) }
                            )
                        )
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: Grid
                    LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
                        ForEach(currentApps) { app in
                            folderIconTile(app: app, folder: folder, tileDimension: tileDimension)
                        }

                        // Trailing drop target only on the last page
                        if viewModel.isEditing && safePageIndex == totalFolderPages - 1 {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: tileDimension, height: tileDimension)
                                .onDrop(
                                    of: [.launchyItemIdentifier],
                                    delegate: FolderTrailingDropDelegate(
                                        folderID: folder.id,
                                        viewModel: viewModel
                                    )
                                )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .animation(.spring(response: 0.28, dampingFraction: 0.68), value: currentApps.map(\.id))
                    .animation(.easeInOut(duration: 0.2), value: safePageIndex)

                    // MARK: Page dots
                    if totalFolderPages > 1 {
                        HStack(spacing: 8) {
                            ForEach(0..<totalFolderPages, id: \.self) { idx in
                                let isActive = idx == safePageIndex
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        folderPage = idx
                                    }
                                } label: {
                                    Circle()
                                        .fill(Color.white.opacity(isActive ? 0.85 : 0.35))
                                        .frame(width: 7, height: 7)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(
                                    "Page \(idx + 1) of \(totalFolderPages)"
                                )
                                .accessibilityAddTraits(isActive ? [.isSelected] : [])
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .overlay(alignment: .top) {
                    // Decorative pointer notch pointing upward toward the folder icon
                    Path { path in
                        path.move(to: CGPoint(x: 11, y: 0))
                        path.addLine(to: CGPoint(x: 22, y: 12))
                        path.addLine(to: CGPoint(x: 0, y: 12))
                        path.closeSubpath()
                    }
                    .fill(.ultraThinMaterial)
                    .frame(width: 22, height: 12)
                    .offset(y: -12)
                }
                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.22), radius: 20, x: 0, y: 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .gesture(
                    DragGesture(minimumDistance: 30)
                        .onEnded { value in
                            let dx = value.translation.width
                            if dx < -40 && safePageIndex < totalFolderPages - 1 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    folderPage = safePageIndex + 1
                                }
                            } else if dx > 40 && safePageIndex > 0 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    folderPage = safePageIndex - 1
                                }
                            }
                        }
                )
                .onExitCommand {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.closeFolder()
                    }
                }
                .onChange(of: folder.apps.count) { _, newCount in
                    let newPageCount = max(
                        1,
                        (newCount + pageCapacity - 1) / max(pageCapacity, 1)
                    )
                    if folderPage >= newPageCount {
                        folderPage = max(newPageCount - 1, 0)
                    }
                }
                .onChange(of: folderID) { _, _ in
                    folderPage = 0
                }
            }
        }
    }

    @ViewBuilder
    private func folderIconTile(
        app: AppIcon,
        folder: LaunchyFolder,
        tileDimension: CGFloat
    )
        -> some View
    {
        let base = AppIconTile(icon: app, isEditing: viewModel.isEditing, dimension: tileDimension)
            .frame(width: tileDimension, height: tileDimension + 32)
        let appIndex = folder.apps.firstIndex(where: { $0.id == app.id }) ?? 0
        let canMoveLeft = appIndex > 0
        let canMoveRight = appIndex < max(folder.apps.count - 1, 0)

        if viewModel.isEditing {
            base
                .overlay(alignment: .bottom) {
                    HStack(spacing: 12) {
                        Button {
                            viewModel.shiftAppInFolder(folderID: folder.id, appID: app.id, by: -1)
                        } label: {
                            Image(systemName: "chevron.backward.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canMoveLeft)
                        .opacity(canMoveLeft ? 1 : 0.35)
                        .accessibilityLabel("Move \(app.name) left")

                        Button {
                            viewModel.shiftAppInFolder(folderID: folder.id, appID: app.id, by: 1)
                        } label: {
                            Image(systemName: "chevron.forward.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canMoveRight)
                        .opacity(canMoveRight ? 1 : 0.35)
                        .accessibilityLabel("Move \(app.name) right")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.35), in: Capsule())
                    .foregroundStyle(Color.white.opacity(0.95))
                    .padding(.bottom, 4)
                }
                .onDrag {
                    viewModel.beginDrag(for: app.id, sourceFolder: folder.id)
                    return LaunchyDragIdentifier(itemID: app.id, sourceFolderID: folder.id)
                        .makeProvider()
                }
                .onDrop(
                    of: [.launchyItemIdentifier],
                    delegate: FolderAppDropDelegate(
                        folderID: folder.id,
                        targetAppID: app.id,
                        viewModel: viewModel
                    )
                )
        } else {
            base
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.launch(.app(app))
                }
                .accessibilityLabel(app.name)
                .accessibilityHint("Double tap to open")
                .accessibilityAddTraits(.isButton)
        }
    }
}
