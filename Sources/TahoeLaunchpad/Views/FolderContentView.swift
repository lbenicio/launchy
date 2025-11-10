import SwiftUI
import UniformTypeIdentifiers

struct FolderContentView: View {
    let folder: LaunchpadFolder
    @ObservedObject var viewModel: LaunchpadViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore

    var body: some View {
        GeometryReader { proxy in
            let settings = settingsStore.settings
            let maxWidth = min(proxy.size.width * 0.55, 520)
            let spacing: CGFloat = 22
            let totalSpacing = CGFloat(max(settings.folderColumns - 1, 0)) * spacing
            let tileWidth = (maxWidth - 56 - totalSpacing) / CGFloat(max(settings.folderColumns, 1))
            let tileDimension = max(72, tileWidth)
            let columns = Array(
                repeating: GridItem(.fixed(tileDimension), spacing: spacing),
                count: max(settings.folderColumns, 1))

            VStack(spacing: 20) {
                HStack {
                    Text(folder.name)
                        .font(.system(size: 20, weight: .semibold))
                        .textCase(.none)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
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

                LazyVGrid(columns: columns, alignment: .center, spacing: spacing) {
                    ForEach(folder.apps) { app in
                        folderIconTile(app: app, tileDimension: tileDimension)
                    }

                    if viewModel.isEditing {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: tileDimension, height: tileDimension)
                            .onDrop(
                                of: [.launchpadItemIdentifier],
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

    private func makeProvider(for payload: LaunchpadDragIdentifier) -> NSItemProvider {
        let provider = NSItemProvider()
        provider.registerDataRepresentation(
            forTypeIdentifier: UTType.launchpadItemIdentifier.identifier, visibility: .all
        ) { completion -> Progress? in
            do {
                let data = try JSONEncoder().encode(payload)
                completion(data, nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }
        return provider
    }

    @ViewBuilder
    private func folderIconTile(app: AppIcon, tileDimension: CGFloat) -> some View {
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
                    return makeProvider(
                        for: LaunchpadDragIdentifier(itemID: app.id, sourceFolderID: folder.id))
                }
                .onDrop(
                    of: [.launchpadItemIdentifier],
                    delegate: FolderAppDropDelegate(
                        folderID: folder.id, targetAppID: app.id, viewModel: viewModel))
        } else {
            base
        }
    }
}
