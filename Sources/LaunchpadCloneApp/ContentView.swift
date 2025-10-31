import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: AppCatalogStore
    @FocusState private var searchFocused: Bool

    private let gridLayout = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 24)
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                SearchBar(text: $store.query, isFocused: $searchFocused)
                    .padding(.top, 32)
                ScrollView {
                    LazyVGrid(columns: gridLayout, spacing: 24) {
                        ForEach(store.activeEntries) { entry in
                            CatalogEntryTile(entry: entry)
                        }
                    }
                    .padding(.horizontal, 72)
                    .padding(.bottom, 48)
                }
                .scrollIndicators(.hidden)
                .onDrop(of: [.utf8PlainText], delegate: CatalogBackgroundDropDelegate(store: store))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottom) {
                ControlFooter()
                    .padding(.bottom, 24)
            }

            if let folder = store.presentedFolder {
                FolderOverlay(folder: folder)
                    .transition(.opacity.combined(with: .scale))
                    .zIndex(1)
            }
        }
        .onAppear {
            Task { await store.refreshCatalogIfNeeded() }
            searchFocused = true
        }
        .onChange(of: store.presentedFolder?.id) { folderID in
            if folderID == nil {
                searchFocused = true
            }
        }
        .onChange(of: store.isEditing) { editing in
            if editing {
                searchFocused = false
            } else if store.presentedFolder == nil && store.query.isEmpty {
                searchFocused = true
            }
        }
        .onExitCommand {
            if store.dismissPresentedFolderOrClearSearch() {
                return
            }
            NSApp.terminate(nil)
        }
        .overlay(alignment: .topTrailing) {
            RefreshButton()
                .padding(32)
        }
        .background(TransparentWindowConfigurator())
        .animation(.easeInOut(duration: 0.2), value: store.activeEntries.count)
        .animation(.easeInOut(duration: 0.2), value: store.presentedFolder?.id ?? "")
    }
}

private struct SearchBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.7))
            TextField("Search Applications", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(.white)
                .disableAutocorrection(true)
                .focused($isFocused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: 480)
    }
}

private struct ControlFooter: View {
    var body: some View {
        HStack(spacing: 24) {
            ControlRow(icon: "esc", description: "Close / cancel edit")
            ControlRow(icon: "Hold", description: "Drag to move or folder")
            ControlRow(icon: "⌘R", description: "Reload catalog")
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct ControlRow: View {
    let icon: String
    let description: String

    var body: some View {
        HStack(spacing: 10) {
            KeyCap(symbol: icon)
            Text(description)
                .font(.footnote)
                .foregroundColor(.white.opacity(0.75))
        }
    }
}

private struct KeyCap: View {
    let symbol: String

    var body: some View {
        Text(symbol)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

private struct RefreshButton: View {
    @EnvironmentObject private var store: AppCatalogStore

    var body: some View {
        Button {
            Task { await store.reloadCatalog() }
        } label: {
            Image(systemName: "arrow.clockwise.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .foregroundColor(.white.opacity(0.8))
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .help("Reload installed applications")
    }
}

private struct CatalogEntryTile: View {
    let entry: CatalogEntry

    @EnvironmentObject private var store: AppCatalogStore
    @State private var tileSize: CGSize = CGSize(width: 140, height: 150)
    @State private var wiggleSeed: Double = Double.random(in: 0...(Double.pi * 2))

    var body: some View {
        Group {
            switch entry {
            case .app(let app):
                AppIconView(app: app)
            case .folder(let folder):
                FolderIconView(folder: folder)
            }
        }
        .background(sizeTracker)
        .modifier(WiggleModifier(isActive: store.isEditing, seed: wiggleSeed))
        .scaleEffect(store.draggingEntryID == entry.id ? 1.05 : 1.0)
        .overlay(dropHighlight)
        .contentShape(Rectangle())
        .onDrag {
            store.beginDragging(entryID: entry.id)
            return NSItemProvider(object: NSString(string: entry.id))
        }
        .onDrop(
            of: [.utf8PlainText],
            delegate: CatalogEntryDropDelegate(entry: entry, store: store, tileSize: tileSize)
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in store.beginEditing() }
        )
    }

    private var sizeTracker: some View {
        GeometryReader { geometry in
            Color.clear
                .onAppear { updateSize(with: geometry.size) }
                .onChange(of: geometry.size) { newSize in
                    updateSize(with: newSize)
                }
        }
        .allowsHitTesting(false)
    }

    private func updateSize(with size: CGSize) {
        guard size.width.isFinite, size.height.isFinite else { return }
        tileSize = size
    }

    private var dropHighlight: some View {
        RoundedRectangle(cornerRadius: 18)
            .stroke(
                Color.white.opacity(store.isEditing && store.targetedEntryID == entry.id ? 0.6 : 0),
                lineWidth: store.isEditing && store.targetedEntryID == entry.id ? 2 : 0
            )
            .animation(
                .easeInOut(duration: 0.15),
                value: store.targetedEntryID == entry.id && store.isEditing)
    }
}

private struct WiggleModifier: ViewModifier {
    let isActive: Bool
    let seed: Double

    func body(content: Content) -> some View {
        Group {
            if isActive {
                TimelineView(.animation) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    let angle = sin(time * 8 + seed) * 2.4
                    let scaleVariance = sin(time * 6 + seed) * 0.015
                    content
                        .rotationEffect(.degrees(angle))
                        .scaleEffect(1 + scaleVariance)
                }
            } else {
                content
            }
        }
    }
}

private final class CatalogEntryDropDelegate: DropDelegate {
    private let entry: CatalogEntry
    private let store: AppCatalogStore
    private let tileSize: CGSize

    init(entry: CatalogEntry, store: AppCatalogStore, tileSize: CGSize) {
        self.entry = entry
        self.store = store
        self.tileSize = tileSize
    }

    func dropEntered(info: DropInfo) {
        guard store.isEditing else { return }
        store.relocateDraggingEntry(before: entry.id)
        store.updateDraggingTarget(entryID: entry.id)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard store.isEditing else { return DropProposal(operation: .forbidden) }
        store.updateDraggingTarget(entryID: entry.id)
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        guard store.isEditing else { return }
        if store.targetedEntryID == entry.id {
            store.updateDraggingTarget(entryID: nil)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        guard store.isEditing else {
            store.abandonDrag()
            return false
        }
        store.updateDraggingTarget(entryID: nil)
        return store.completeDrop(on: entry.id, location: info.location, tileSize: tileSize)
    }
}

private final class CatalogBackgroundDropDelegate: DropDelegate {
    private let store: AppCatalogStore

    init(store: AppCatalogStore) {
        self.store = store
    }

    func dropEntered(info: DropInfo) {
        guard store.isEditing else { return }
        store.updateDraggingTarget(entryID: nil)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        guard store.isEditing else { return DropProposal(operation: .forbidden) }
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard store.isEditing else {
            store.abandonDrag()
            return false
        }
        return store.completeDrop(on: nil, location: nil, tileSize: nil)
    }

    func dropExited(info: DropInfo) {
        guard store.isEditing else { return }
        store.updateDraggingTarget(entryID: nil)
    }
}
