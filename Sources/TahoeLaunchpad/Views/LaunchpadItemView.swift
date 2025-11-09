import SwiftUI

struct LaunchpadItemView: View {
    let item: LaunchpadItem
    let dimension: CGFloat
    let isEditing: Bool
    let onOpenFolder: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onLaunch: (LaunchpadItem) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch item {
            case .app(let icon):
                AppIconTile(icon: icon, isEditing: isEditing, dimension: dimension)
            case .folder(let folder):
                FolderIconView(folder: folder, isEditing: isEditing, dimension: dimension)
            }

            if isEditing {
                deleteBadge
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isEditing else { return }
            switch item {
            case .folder:
                onOpenFolder(item.id)
            case .app:
                onLaunch(item)
            }
        }
        .onLongPressGesture(minimumDuration: 0.2) {
            if case .folder = item, !isEditing {
                onOpenFolder(item.id)
            }
        }
    }

    private var deleteBadge: some View {
        Button {
            onDelete(item.id)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.4))
                .font(.system(size: dimension * 0.28, weight: .bold))
                .background(Color.red.opacity(0.9), in: Circle())
        }
        .buttonStyle(.plain)
        .offset(x: -dimension * 0.2, y: -dimension * 0.35)
        .allowsHitTesting(true)
    }
}
