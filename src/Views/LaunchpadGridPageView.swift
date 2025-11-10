import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
#endif

struct LaunchpadGridPageView: View {
    @ObservedObject var viewModel: LaunchpadViewModel
    let items: [LaunchpadItem]
    let metrics: GridLayoutMetrics

    var body: some View {
        LazyVGrid(columns: metrics.columns, alignment: .center, spacing: metrics.verticalSpacing) {
            ForEach(items) { item in
                launchpadTile(for: item)
            }

            if viewModel.isEditing {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: metrics.itemDimension, height: metrics.itemDimension)
                    .onDrop(
                        of: [.launchpadItemIdentifier],
                        delegate: LaunchpadTrailingDropDelegate(viewModel: viewModel))
            }
        }
        .padding(.horizontal, metrics.padding)
        .padding(.vertical, metrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func launchpadTile(for item: LaunchpadItem) -> some View {
        GeometryReader { proxy in
            let dropTypes: [UTType] = [.launchpadItemIdentifier]
            let frame = CGRect(origin: .zero, size: proxy.size)
            let globalIndex = viewModel.indexOfItem(item.id) ?? 0
            let canMoveLeft = globalIndex > 0
            let canMoveRight = globalIndex < max(viewModel.items.count - 1, 0)
            let baseView = LaunchpadItemView(
                item: item,
                dimension: metrics.itemDimension,
                isEditing: viewModel.isEditing,
                isSelected: viewModel.isItemSelected(item.id),
                canMoveLeft: canMoveLeft,
                canMoveRight: canMoveRight,
                hasSelectedApps: viewModel.hasSelectedApps,
                onOpenFolder: { viewModel.openFolder(with: $0) },
                onDelete: { viewModel.deleteItem($0) },
                onLaunch: { viewModel.launch($0) },
                onSelect: { viewModel.toggleSelection(for: $0) },
                onMoveLeft: { viewModel.shiftItem($0, by: -1) },
                onMoveRight: { viewModel.shiftItem($0, by: 1) },
                onAddSelectedAppsToFolder: { viewModel.addSelectedApps(toFolder: $0) }
            )
            .frame(width: metrics.itemDimension, height: metrics.itemDimension + 36)
            .contentShape(Rectangle())
            .onDrop(
                of: dropTypes,
                delegate: LaunchpadItemDropDelegate(
                    item: item,
                    viewModel: viewModel,
                    frameProvider: { frame }
                )
            )

            let folderAwareView: AnyView = {
                if case .folder(let folder) = item {
                    return AnyView(
                        baseView.onDrop(
                            of: dropTypes,
                            delegate: FolderDropDelegate(folderID: folder.id, viewModel: viewModel))
                    )
                } else {
                    return AnyView(baseView)
                }
            }()

            let dragReadyView: AnyView = {
                if viewModel.isEditing {
                    return AnyView(
                        folderAwareView.onDrag {
                            viewModel.beginDrag(for: item.id)
                            return makeProvider(for: LaunchpadDragIdentifier(itemID: item.id))
                        }
                    )
                } else {
                    return folderAwareView
                }
            }()

            dragReadyView
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .frame(width: metrics.itemDimension, height: metrics.itemDimension + 36)
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
}
