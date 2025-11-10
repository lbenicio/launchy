import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct LaunchpadRootView: View {
    @ObservedObject var viewModel: LaunchpadViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore

    @State private var searchText: String = ""
    @State private var isShowingSettings: Bool = false
    @State private var isCreatingFolder: Bool = false
    @State private var newFolderName: String = ""
    @State private var folderCreationError: String?
    @State private var didActivateWindow = false
    @State private var editingBannerHeight: CGFloat = 0
    @FocusState private var isFolderNameFieldFocused: Bool

    private var pages: [[LaunchpadItem]] {
        buildPages(for: searchText)
    }

    private var hasResults: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return !viewModel.items.isEmpty
        }
        return pages.contains { !$0.isEmpty }
    }

    var body: some View {
        let fillScreen = settingsStore.settings.useFullScreenLayout

        Group {
            if viewModel.isLayoutLoaded {
                loadedContent(fillScreen: fillScreen)
            } else {
                loadingView(fillScreen: fillScreen)
            }
        }
        .frame(minWidth: 1024, minHeight: 720)
        #if os(macOS)
            .background(WindowConfigurator(useFullScreenLayout: fillScreen))
        #endif
        .onChange(of: searchText) { _, newValue in
            let latestPages = buildPages(for: newValue)
            viewModel.selectPage(0, totalPages: max(latestPages.count, 1))
        }
        .onChange(of: pages.count) { _, newCount in
            let maxIndex = max(newCount - 1, 0)
            if viewModel.currentPage > maxIndex {
                viewModel.selectPage(maxIndex, totalPages: newCount)
            }
        }
        .sheet(isPresented: $isCreatingFolder) {
            newFolderSheet
        }
    }

    @ViewBuilder
    private func loadedContent(fillScreen: Bool) -> some View {
        ZStack {
            backgroundLayer(fillScreen: fillScreen)

            VStack(spacing: 32) {
                header
                    .padding(.horizontal, 80)
                    .padding(.top, 40)
                    .zIndex(1)

                if viewModel.isEditing {
                    editingGuidance
                        .padding(.horizontal, 80)
                        .transition(.opacity)
                }

                VStack(spacing: 28) {
                    ZStack {
                        LaunchpadPagedGridView(
                            viewModel: viewModel,
                            pages: pages,
                            fillsAvailableSpace: fillScreen,
                            onBackgroundTap: handleBackgroundTap
                        )

                        if !hasResults {
                            Text("No Matching Apps")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.7))
                                .padding(24)
                                .background(Color.black.opacity(0.35), in: Capsule())
                        }
                    }

                    if pages.count > 1 {
                        PageControlView(
                            currentPage: viewModel.currentPage,
                            totalPages: pages.count,
                            onSelect: { index in
                                viewModel.selectPage(index, totalPages: pages.count)
                            }
                        )
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, fillScreen ? 0 : 24)
                .padding(.bottom, 60)
                .padding(.top, viewModel.isEditing ? editingBannerHeight + 16 : 0)
                .animation(.easeInOut(duration: 0.24), value: editingBannerHeight)
                .animation(.easeInOut(duration: 0.24), value: viewModel.isEditing)
            }
            .frame(
                maxWidth: fillScreen ? .infinity : nil,
                maxHeight: fillScreen ? .infinity : nil,
                alignment: .top
            )
            .onPreferenceChange(EditingBannerHeightPreferenceKey.self) { editingBannerHeight = $0 }

            if let folderID = viewModel.presentedFolderID,
                let folder = viewModel.folder(by: folderID)
            {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(2)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            viewModel.closeFolder()
                        }
                    }

                FolderContentView(folder: folder, viewModel: viewModel)
                    .padding(.horizontal, 120)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .zIndex(3)
            }

            if isShowingSettings {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(4)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.24)) {
                            isShowingSettings = false
                        }
                    }

                SettingsView(store: settingsStore)
                    .frame(width: 680, height: 540)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: Color.black.opacity(0.4), radius: 32, x: 0, y: 18)
                    .padding(60)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(5)
                    .onTapGesture {}
            }
        }
        .onAppear {
            activateWindowIfNeeded()
        }
        .onChange(of: viewModel.isEditing) { _, isEditing in
            if !isEditing {
                editingBannerHeight = 0
            }
        }
    }

    @ViewBuilder
    private func loadingView(fillScreen: Bool) -> some View {
        ZStack {
            backgroundLayer(fillScreen: fillScreen)

            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading layout…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .padding(32)
            .background(
                Color.black.opacity(0.35),
                in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    #if os(macOS)
        private func backgroundLayer(fillScreen: Bool) -> some View {
            Group {
                if fillScreen {
                    DesktopBackdropView()
                        .overlay {
                            backgroundGradient
                                .opacity(0.14)
                        }
                        .ignoresSafeArea()
                } else {
                    backgroundGradient
                        .ignoresSafeArea()
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                handleBackgroundTap()
            }
        }
    #else
        private func backgroundLayer(fillScreen _: Bool) -> some View {
            backgroundGradient
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    handleBackgroundTap()
                }
        }
    #endif

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.13, green: 0.16, blue: 0.20),
                Color(red: 0.03, green: 0.04, blue: 0.05),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func handleBackgroundTap() {
        if viewModel.isLaunchingApp {
            return
        }
        if viewModel.isEditing {
            viewModel.clearSelection()
            return
        }
        guard viewModel.presentedFolderID == nil else { return }
        terminateLauncher()
    }

    private func activateWindowIfNeeded() {
        #if os(macOS)
            guard !didActivateWindow else { return }
            didActivateWindow = true
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.isVisible }) {
                    window.makeKeyAndOrderFront(nil)
                    window.makeFirstResponder(window.contentView)
                }
            }
        #endif
    }

    private func buildPages(for query: String) -> [[LaunchpadItem]] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return viewModel.pagedItems
        }
        let filtered = viewModel.pagedItems(matching: trimmed)
        return filtered.isEmpty ? [[]] : filtered
    }

    #if os(macOS)
        private func terminateLauncher() {
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        }
    #else
        private func terminateLauncher() {}
    #endif

    private var header: some View {
        HStack(spacing: 16) {
            searchField
            if viewModel.isEditing {
                selectionSummary
            }
            Spacer()
            if viewModel.isEditing {
                newFolderButton
            }
            wiggleToggle
            settingsButton
        }
    }

    private var searchField: some View {
        LaunchpadSearchField(text: $searchText)
            .frame(width: 240)
    }

    private var wiggleToggle: some View {
        Button {
            viewModel.toggleEditing()
        } label: {
            Label(
                viewModel.isEditing ? "Done" : "Edit",
                systemImage: viewModel.isEditing
                    ? "checkmark.circle.fill" : "arrow.up.arrow.down.circle"
            )
            .labelStyle(.iconOnly)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(viewModel.isEditing ? Color.green : Color.white.opacity(0.9))
            .padding(10)
            .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.24)) {
                isShowingSettings = true
            }
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(10)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var selectionSummary: some View {
        let count = selectedAppCount
        return Text(count == 0 ? "No Selection" : "\(count) Selected")
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(Color.white.opacity(count == 0 ? 0.6 : 0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12), in: Capsule())
            .animation(.easeInOut(duration: 0.2), value: count)
    }

    private var editingGuidance: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "square.on.square")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))

            VStack(alignment: .leading, spacing: 4) {
                Text("Wiggle Mode")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                Text(
                    "Select apps to make folders, drag or use arrows to reorder. Changes save automatically."
                )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.75))
            }

            Spacer(minLength: 12)

            if viewModel.isEditing, hasSelection {
                clearSelectionButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: EditingBannerHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        )
    }

    private var newFolderButton: some View {
        Button {
            startFolderCreation()
        } label: {
            Label("New Folder", systemImage: "folder.badge.plus")
                .font(.system(size: 14, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canCreateFolder)
        .opacity(canCreateFolder ? 1 : 0.45)
        .help("Select at least two apps to create a folder")
    }

    private var clearSelectionButton: some View {
        Button {
            viewModel.clearSelection()
        } label: {
            Label("Clear", systemImage: "xmark.circle")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.14), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!hasSelection)
        .opacity(hasSelection ? 1 : 0.4)
    }

    private var hasSelection: Bool {
        !viewModel.selectedItemIDs.isEmpty
    }

    private var selectedAppCount: Int {
        viewModel.selectedItemIDs.reduce(into: 0) { result, id in
            if let item = viewModel.item(with: id), case .app = item {
                result += 1
            }
        }
    }

    private var canCreateFolder: Bool {
        selectedAppCount >= 2
    }

    private func startFolderCreation() {
        guard canCreateFolder else { return }
        newFolderName = suggestedFolderName()
        folderCreationError = nil
        isCreatingFolder = true
        DispatchQueue.main.async {
            isFolderNameFieldFocused = true
        }
    }

    private func commitFolderCreation() {
        let ids = Array(viewModel.selectedItemIDs)
        guard viewModel.createFolder(named: newFolderName, from: ids) != nil else {
            folderCreationError = "Select at least two apps to create a folder."
            return
        }

        folderCreationError = nil
        newFolderName = ""
        isFolderNameFieldFocused = false
        isCreatingFolder = false
    }

    private func suggestedFolderName() -> String {
        guard let firstID = viewModel.selectedItemIDs.first,
            let item = viewModel.item(with: firstID)
        else {
            return "New Folder"
        }

        if case .app(let icon) = item {
            return "\(icon.name) Folder"
        }
        return "New Folder"
    }

    private var newFolderSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Create Folder")
                .font(.system(size: 20, weight: .semibold))

            Text("You have selected \(selectedAppCount) apps. They will be moved into this folder.")
                .font(.system(size: 13))
                .foregroundStyle(Color.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Folder Name")
                    .font(.system(size: 13, weight: .semibold))
                TextField("New Folder", text: $newFolderName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isFolderNameFieldFocused)
            }

            if let error = folderCreationError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.red)
            }

            Spacer(minLength: 12)

            HStack {
                Spacer()
                Button("Cancel") {
                    isFolderNameFieldFocused = false
                    isCreatingFolder = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    commitFolderCreation()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

private struct EditingBannerHeightPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct PageControlView: View {
    let currentPage: Int
    let totalPages: Int
    var onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<totalPages, id: \.self) { index in
                let isActive = index == currentPage
                Button {
                    onSelect(index)
                } label: {
                    Capsule()
                        .fill(isActive ? Color.white.opacity(0.85) : Color.white.opacity(0.3))
                        .frame(width: isActive ? 28 : 12, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Go to page \(index + 1)")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.28), in: Capsule())
    }
}
