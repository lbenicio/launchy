import SwiftUI

struct LaunchyItemView: View {
    let item: LaunchyItem
    let dimension: CGFloat
    let isEditing: Bool
    let isSelected: Bool
    let isLaunching: Bool
    let canMoveLeft: Bool
    let canMoveRight: Bool
    let hasSelectedApps: Bool
    let isRecentlyAdded: Bool
    let onOpenFolder: (UUID) -> Void
    let onDelete: (UUID) -> Void
    let onLaunch: (LaunchyItem) -> Void
    let onSelect: (UUID) -> Void
    let onMoveLeft: (UUID) -> Void
    let onMoveRight: (UUID) -> Void
    let onAddSelectedAppsToFolder: (UUID) -> Void
    let onDisbandFolder: (UUID) -> Void
    let onToggleEditing: () -> Void
    let onShowInFinder: (LaunchyItem) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch item {
            case .app(let icon):
                AppIconTile(
                    icon: icon,
                    isEditing: isEditing,
                    dimension: dimension,
                    isRecentlyAdded: isRecentlyAdded
                )
            case .folder(let folder):
                FolderIconView(folder: folder, isEditing: isEditing, dimension: dimension)
            case .widget(let widget):
                WidgetIconView(widget: widget, isEditing: isEditing, dimension: dimension)
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
                case .widget:
                    onSelect(item.id)  // Widgets can be selected in edit mode
                }
            } else {
                switch item {
                case .folder:
                    onOpenFolder(item.id)
                case .app:
                    onLaunch(item)
                case .widget:
                    onLaunch(item)  // Launch the widget
                }
            }
        }
        .onLongPressGesture(minimumDuration: 0.2) {
            if !isEditing {
                switch item {
                case .app:
                    onToggleEditing()
                case .folder:
                    onOpenFolder(item.id)
                case .widget:
                    onToggleEditing()  // Allow editing widgets
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if isEditing {
                switch item {
                case .app:
                    selectionBadge
                case .folder:
                    disbandFolderBadge
                case .widget:
                    selectionBadge  // Widgets can be selected
                }
            }
        }
        .overlay(alignment: .bottom) {
            if isEditing {
                reorderControls
            }
        }
        .overlay(selectionHighlight)
        .contextMenu {
            if case .app = item {
                Button {
                    onLaunch(item)
                } label: {
                    Label("Open", systemImage: "arrow.up.forward.app")
                }

                Button {
                    onShowInFinder(item)
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete(item.id)
                } label: {
                    Label("Remove from Launchy", systemImage: "trash")
                }
            } else if case .folder(_) = item {
                Button {
                    onOpenFolder(item.id)
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }

                Button {
                    onDisbandFolder(item.id)
                } label: {
                    Label("Split Folder", systemImage: "square.stack.3d.down.forward")
                }

                Divider()

                Button(role: .destructive) {
                    onDelete(item.id)
                } label: {
                    Label("Remove Folder", systemImage: "trash")
                }
            }
        }
        .scaleEffect(isLaunching ? 1.5 : 1.0)
        .offset(y: isLaunching ? -30 : 0)
        .opacity(isLaunching ? 0.0 : 1.0)
        .animation(
            isLaunching
                ? .spring(response: 0.35, dampingFraction: 0.6).delay(0.05)
                : .easeOut(duration: 0.2),
            value: isLaunching
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(
            isEditing && isSelected
                ? [.isButton, .isSelected]
                : [.isButton]
        )
        .accessibilityAction(named: "Delete") { onDelete(item.id) }
        .accessibilityAction(named: isSelected ? "Deselect" : "Select") {
            if case .app = item { onSelect(item.id) }
        }
        .accessibilityAction(named: "Move left") {
            if canMoveLeft { onMoveLeft(item.id) }
        }
        .accessibilityAction(named: "Move right") {
            if canMoveRight { onMoveRight(item.id) }
        }
        .accessibilityAction(named: "Split folder") {
            if case .folder = item { onDisbandFolder(item.id) }
        }
    }

    private var deleteBadge: some View {
        Button {
            onDelete(item.id)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .black.opacity(0.55))
                .font(.system(size: dimension * 0.18, weight: .bold))
                .background(Color.black.opacity(0.5), in: Circle())
        }
        .buttonStyle(.plain)
        .offset(x: -dimension * 0.12, y: -dimension * 0.12)
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

    private var accessibilityLabel: String {
        switch item {
        case .app(let icon):
            return icon.name
        case .folder(let folder):
            return "\(folder.name) folder, \(folder.apps.count) apps"
        case .widget(let widget):
            return widget.name
        }
    }

    private var accessibilityHint: String {
        if isEditing {
            switch item {
            case .app:
                return "Double tap to select"
            case .folder:
                return hasSelectedApps
                    ? "Double tap to add selected apps"
                    : "Double tap to open"
            case .widget:
                return "Double tap to select"
            }
        } else {
            switch item {
            case .app:
                return "Double tap to open"
            case .folder:
                return "Double tap to open folder"
            case .widget:
                return "Double tap to launch widget"
            }
        }
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
