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
        let dropTypes: [UTType] = [.launchpadItemIdentifier]

        var wrappedView: AnyView = AnyView(
            LaunchpadItemView(
                item: item,
                dimension: metrics.itemDimension,
                isEditing: viewModel.isEditing,
                onOpenFolder: { viewModel.openFolder(with: $0) },
                onDelete: { viewModel.deleteItem($0) },
                onLaunch: handleLaunch
            )
            .frame(width: metrics.itemDimension, height: metrics.itemDimension + 36)
            .onDrop(
                of: dropTypes, delegate: LaunchpadItemDropDelegate(item: item, viewModel: viewModel)
            )
        )

        if case .folder(let folder) = item {
            wrappedView = AnyView(
                wrappedView.onDrop(
                    of: dropTypes,
                    delegate: FolderDropDelegate(folderID: folder.id, viewModel: viewModel))
            )
        }

        if viewModel.isEditing {
            return AnyView(
                wrappedView.onDrag {
                    viewModel.beginDrag(for: item.id)
                    return makeProvider(for: LaunchpadDragIdentifier(itemID: item.id))
                }
            )
        } else {
            return wrappedView
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

    private func handleLaunch(_ item: LaunchpadItem) {
        guard case .app(let app) = item else { return }
        #if os(macOS)
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: app.bundleURL, configuration: configuration) {
                _, error in
                if let error {
                    print(
                        "LaunchpadGridPageView: Failed to launch \(app.name) => \(error.localizedDescription)"
                    )
                }
            }
        #endif
    }
}
