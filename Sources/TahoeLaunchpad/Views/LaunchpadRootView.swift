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
    @FocusState private var isFolderNameFieldFocused: Bool

    private var pages: [[LaunchpadItem]] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.pagedItems }
        return viewModel.pagedItems(matching: query)
    }

    private var hasResults: Bool {
        pages.contains { !$0.isEmpty }
    }

    var body: some View {
        let fillScreen = settingsStore.settings.useFullScreenLayout

        ZStack {
            backgroundLayer(fillScreen: fillScreen)

            VStack(spacing: 24) {
                header
                    .padding(.horizontal, 80)
                    .padding(.top, 40)
                    .zIndex(1)

                ZStack(alignment: .bottom) {
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
                .padding(.bottom, 60)
            }
            .frame(
                maxWidth: fillScreen ? .infinity : nil,
                maxHeight: fillScreen ? .infinity : nil,
                alignment: .top
            )

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
        }
        .frame(minWidth: 1024, minHeight: 720)
        #if os(macOS)
            .background(WindowConfigurator(useFullScreenLayout: fillScreen))
        #endif
        .onChange(of: searchText) { _, _ in
            viewModel.selectPage(0, totalPages: pages.count)
        }
        .onChange(of: pages.count) { _, newCount in
            let maxIndex = max(newCount - 1, 0)
            if viewModel.currentPage > maxIndex {
                viewModel.selectPage(maxIndex, totalPages: newCount)
            }
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView(store: settingsStore)
                .padding(20)
                .frame(width: 480, height: 360)
        }
        .sheet(isPresented: $isCreatingFolder) {
            newFolderSheet
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
            isShowingSettings = true
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
