import SwiftUI
import UniformTypeIdentifiers

struct FolderContentView: View {
    let folderID: UUID
    @ObservedObject var viewModel: LaunchyViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore
    @State private var editingName: String = ""

    var body: some View {
        let folder = viewModel.folder(by: folderID)
        GeometryReader { proxy in
            if let folder {
                let settings = settingsStore.settings
                let maxWidth = min(proxy.size.width * 0.55, 520)
                let spacing: CGFloat = 22
                let totalSpacing = CGFloat(max(settings.folderColumns - 1, 0)) * spacing
                let tileWidth =
                    (maxWidth - 56 - totalSpacing) / CGFloat(max(settings.folderColumns, 1))
                let tileDimension = max(72, tileWidth)
                let columns = Array(
                    repeating: GridItem(.fixed(tileDimension), spacing: spacing),
                    count: max(settings.folderColumns, 1))

                VStack(spacing: 20) {
                    HStack {
                        if viewModel.isEditing {
                            TextField(
                                "Folder Name", text: $editingName,
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
                    }

                    if viewModel.isEditing {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(IconColor.allCases, id: \.self) { iconColor in
                                    Button {
                                        viewModel.updateFolderColor(folderID, to: iconColor)
                                    } label: {
                                        Circle()
                                            .fill(iconColor.color)
                                            .frame(width: 24, height: 24)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        Color.white,
                                                        lineWidth: folder.color == iconColor
                                                            ? 2.5 : 0)
                                            )
                                            .overlay(
                                                folder.color == iconColor
                                                    ? Image(systemName: "checkmark")
                                                        .font(.system(size: 11, weight: .bold))
                                                        .foregroundStyle(.white)
                                                    : nil
                                            )
                                            .shadow(
                                                color: iconColor.color.opacity(
                                                    folder.color == iconColor ? 0.5 : 0), radius: 4)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
                        ForEach(folder.apps) { app in
                            folderIconTile(app: app, folder: folder, tileDimension: tileDimension)
                        }

                        if viewModel.isEditing {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: tileDimension, height: tileDimension)
                                .onDrop(
                                    of: [.launchyItemIdentifier],
                                    delegate: FolderTrailingDropDelegate(
                                        folderID: folder.id, viewModel: viewModel))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                }
                .padding(32)
                .background(
                    .ultraThinMaterial, in: RoundedRectangle(cornerRadius: 36, style: .continuous)
                )
                .frame(maxWidth: maxWidth)
                .contentShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                .shadow(color: Color.black.opacity(0.25), radius: 25, x: 0, y: 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func folderIconTile(app: AppIcon, folder: LaunchyFolder, tileDimension: CGFloat)
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

                        Button {
                            viewModel.shiftAppInFolder(folderID: folder.id, appID: app.id, by: 1)
                        } label: {
                            Image(systemName: "chevron.forward.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canMoveRight)
                        .opacity(canMoveRight ? 1 : 0.35)
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
                        folderID: folder.id, targetAppID: app.id, viewModel: viewModel))
        } else {
            base
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.launch(.app(app))
                }
        }
    }
}
