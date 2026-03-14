import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
#endif

struct LaunchyGridPageView: View {
    @ObservedObject var viewModel: LaunchyViewModel
    let items: [LaunchyItem]
    let metrics: GridLayoutMetrics

    private static let rearrangeSpring = Animation.spring(response: 0.28, dampingFraction: 0.68)

    var body: some View {
        LazyVGrid(columns: metrics.columns, alignment: .center, spacing: metrics.verticalSpacing) {
            ForEach(items) { item in
                launchyTile(for: item)
                    .transition(
                        .scale(scale: 0.78, anchor: .center).combined(with: .opacity)
                    )
            }

            if viewModel.isEditing {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: metrics.itemDimension, height: metrics.itemDimension)
                    .onDrop(
                        of: [.launchyItemIdentifier],
                        delegate: LaunchyTrailingDropDelegate(viewModel: viewModel)
                    )
            }
        }
        .padding(.horizontal, metrics.padding)
        .padding(.vertical, metrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(Self.rearrangeSpring, value: items.map(\.id))
    }

    @ViewBuilder
    private func launchyTile(for item: LaunchyItem) -> some View {
        let dropTypes: [UTType] = [.launchyItemIdentifier]
        let globalIndex = viewModel.indexOfItem(item.id) ?? 0
        let canMoveLeft = globalIndex > 0
        let canMoveRight = globalIndex < max(viewModel.items.count - 1, 0)

        let recentlyAdded: Bool = {
            if case .app(let icon) = item {
                return viewModel.recentlyAddedBundleIDs
                    .contains(icon.bundleIdentifier)
            }
            return false
        }()

        let baseContent = LaunchyItemView(
            item: item,
            dimension: metrics.itemDimension,
            isEditing: viewModel.isEditing,
            isSelected: viewModel.isItemSelected(item.id),
            isLaunching: viewModel.launchingItemID == item.id,
            canMoveLeft: canMoveLeft,
            canMoveRight: canMoveRight,
            hasSelectedApps: viewModel.hasSelectedApps,
            isRecentlyAdded: recentlyAdded,
            onOpenFolder: { id in
                #if os(macOS)
                    let screenX = NSEvent.mouseLocation.x
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.openFolder(with: id, screenX: screenX)
                    }
                #else
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        viewModel.openFolder(with: id)
                    }
                #endif
            },
            onDelete: { viewModel.deleteItem($0) },
            onLaunch: { viewModel.launch($0) },
            onSelect: { viewModel.toggleSelection(for: $0) },
            onMoveLeft: { id in withAnimation(Self.rearrangeSpring) { viewModel.shiftItem(id, by: -1) } },
            onMoveRight: { id in withAnimation(Self.rearrangeSpring) { viewModel.shiftItem(id, by: 1) } },
            onAddSelectedAppsToFolder: { viewModel.addSelectedApps(toFolder: $0) },
            onDisbandFolder: { viewModel.disbandFolder($0) },
            onToggleEditing: { viewModel.toggleEditing() },
            onShowInFinder: { viewModel.showInFinder($0) }
        )
        .frame(width: metrics.itemDimension, height: metrics.itemDimension + 36)
        .contentShape(Rectangle())

        // Use a single, unified drop delegate that handles both reordering
        // and folder-specific drops (like adding into a folder).
        // This avoids the problem of stacking multiple .onDrop modifiers.
        let tileWithDrop =
            baseContent
            .onDrop(
                of: dropTypes,
                delegate: LaunchyItemDropDelegate(
                    item: item,
                    viewModel: viewModel,
                    frameProvider: {
                        CGRect(
                            origin: .zero,
                            size: CGSize(
                                width: metrics.itemDimension,
                                height: metrics.itemDimension + 36
                            )
                        )
                    }
                )
            )

        if viewModel.isEditing {
            tileWithDrop.onDrag {
                viewModel.beginDrag(for: item.id)
                return LaunchyDragIdentifier(itemID: item.id).makeProvider()
            }
        } else {
            tileWithDrop
        }
    }

}
