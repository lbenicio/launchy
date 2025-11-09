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

        if viewModel.isEditing {
            base
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
