import AppKit
import SwiftUI

struct AppIconView: View {
    let app: AppItem
    @EnvironmentObject private var store: AppCatalogStore
    @State private var isHighlighted = false

    var body: some View {
        Button {
            store.launch(app)
        } label: {
            VStack(spacing: 12) {
                AppIconImage(app: app)
                Text(app.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 140)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isHighlighted ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(isHighlighted ? 0.35 : 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHighlighted = hovering
            }
        }
        .contextMenu {
            if !store.isEditing {
                Button("Show in Finder") {
                    store.revealInFinder(app)
                }
            }
        }
        .help(app.bundleIdentifier ?? app.displayName)
    }
}

private struct AppIconImage: View {
    let app: AppItem
    @State private var icon: NSImage? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.05))
                .frame(width: 96, height: 96)
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
                    .shadow(radius: 4, y: 3)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white.opacity(0.8))
            }
        }
        .task {
            icon = IconStore.shared.icon(for: app.bundleURL)
        }
    }
}

struct FolderIconView: View {
    let folder: FolderItem
    @EnvironmentObject private var store: AppCatalogStore
    @State private var isHighlighted = false

    var body: some View {
        Button {
            store.present(folder)
        } label: {
            VStack(spacing: 12) {
                FolderGlyph()
                Text(folder.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 140)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(isHighlighted ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(isHighlighted ? 0.35 : 0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHighlighted = hovering
            }
        }
        .help("Open folder")
    }
}

private struct FolderGlyph: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.blue.opacity(0.28))
                .frame(width: 96, height: 96)
            Image(systemName: "square.grid.3x3.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}
