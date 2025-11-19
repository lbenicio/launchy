import SwiftUI

struct LaunchpadItemView: View {
    let item: LaunchpadItem
    let dimension: CGFloat
    let isEditing: Bool
    let isSelected: Bool
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let hasSelectedApps: Bool
    let onOpenFolder: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onLaunch: (LaunchpadItem) -> Void
    let onSelect: (UUID) -> Void
    let onMoveLeft: (UUID) -> Void
    let onMoveRight: (UUID) -> Void
    let onAddSelectedAppsToFolder: (UUID) -> Void
    let onDisbandFolder: (UUID) -> Void

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
            if isEditing {
                switch item {
                case .app:
                    onSelect(item.id)
                case .folder:
                    if hasSelectedApps {
                        onAddSelectedAppsToFolder(item.id)
                    } else {
                        onOpenFolder(item.id)
                    }
                }
            } else {
                switch item {
                case .folder:
                    onOpenFolder(item.id)
                case .app:
                    onLaunch(item)
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.2) {
            if case .folder = item, !isEditing {
                onOpenFolder(item.id)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEditing {
                switch item {
                case .app:
                    selectionBadge
                case .folder:
                    disbandFolderBadge
                }
            }
        }
        .overlay(alignment: .bottom) {
            if isEditing {
                reorderControls
            }
        }
        .overlay(selectionHighlight)
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

    private var selectionBadge: some View {
        Button {
            onSelect(item.id)
        } label: {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? Color.accentColor : Color.white.opacity(0.8))
                .font(.system(size: dimension * 0.28, weight: .semibold))
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(isSelected ? 0.6 : 0.4), lineWidth: 1.5)
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .padding(.trailing, 6)
    }

    private var reorderControls: some View {
        HStack(spacing: 12) {
            Button {
                onMoveLeft(item.id)
            } label: {
                Image(systemName: "chevron.backward.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!canMoveLeft)
            .opacity(canMoveLeft ? 1 : 0.35)

            Button {
                onMoveRight(item.id)
            } label: {
                Image(systemName: "chevron.forward.circle.fill")
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(.plain)
            .disabled(!canMoveRight)
            .opacity(canMoveRight ? 1 : 0.35)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.35), in: Capsule())
        .foregroundStyle(Color.white.opacity(0.95))
        .padding(.bottom, 6)
    }

    private var disbandFolderBadge: some View {
        Button {
            onDisbandFolder(item.id)
        } label: {
            Image(systemName: "square.stack.3d.down.forward.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.white.opacity(0.95))
                .font(.system(size: dimension * 0.24, weight: .semibold))
                .padding(6)
                .background(Color.blue.opacity(0.85), in: Circle())
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
        .padding(.trailing, 6)
        .help("Split Folder")
    }

    private var isApp: Bool {
        if case .app = item { return true }
        return false
    }

    @ViewBuilder
    private var selectionHighlight: some View {
        if isEditing, isSelected, isApp {
            RoundedRectangle(cornerRadius: dimension * 0.36, style: .continuous)
                .fill(Color.accentColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: dimension * 0.36, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.75), lineWidth: 2)
                )
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                .allowsHitTesting(false)
        }
    }
}
