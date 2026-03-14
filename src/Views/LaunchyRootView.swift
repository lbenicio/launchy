import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
    import AppKit
#endif

struct LaunchyRootView: View {
    @ObservedObject var viewModel: LaunchyViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore

    @State private var searchText: String = ""
    @State private var isShowingSettings: Bool = false
    @State private var isCreatingFolder: Bool = false
    @State private var newFolderName: String = ""
    @State private var newFolderColor: IconColor = .blue
    @State private var folderCreationError: String?
    @State private var didActivateWindow = false
    @State private var isPresented: Bool = false
    @State private var editingBannerHeight: CGFloat = 0
    @State private var showHeaderControls: Bool = true
    @State private var headerControlsTimer: Timer?
    @FocusState private var isFolderNameFieldFocused: Bool

    private var pages: [[LaunchyItem]] {
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
            .background(
                WindowConfigurator(
                    useFullScreenLayout: fillScreen,
                    preferredWindowSize: fillScreen ? nil : settingsStore.settings.windowedSize,
                    onWindowSizeChange: { newSize in
                        settingsStore.update(
                            windowedWidth: Double(newSize.width),
                            windowedHeight: Double(newSize.height)
                        )
                    }
                )
            )
        #endif
        .onChange(of: searchText) { _, newValue in
            let latestPages = buildPages(for: newValue)
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectPage(0, totalPages: max(latestPages.count, 1))
            }
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
        .onReceive(NotificationCenter.default.publisher(for: .toggleInAppSettings)) { _ in
            withAnimation(.easeInOut(duration: 0.24)) {
                isShowingSettings.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .launcherDidReappear)) { _ in
            reappearLauncher()
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissLauncher)) { _ in
            dismissLauncher()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportLayout)) { _ in
            viewModel.exportLayout()
        }
        .onReceive(NotificationCenter.default.publisher(for: .importLayout)) { _ in
            viewModel.importLayout()
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetToDefaultLayout)) { _ in
            viewModel.resetToDefaultLayout()
        }
    }

    @ViewBuilder
    private func loadedContent(fillScreen: Bool) -> some View {
        ZStack {
            backgroundLayer(fillScreen: fillScreen)

            let edgePadding = fillScreen ? 80.0 : 24.0
            let headerTopPadding = fillScreen ? 40.0 : 24.0
            let gridHorizontalPadding = fillScreen ? 0.0 : 8.0
            let gridBottomPadding = fillScreen ? 60.0 : 24.0

            VStack(spacing: 32) {
                header
                    .padding(.horizontal, edgePadding)
                    .padding(.top, headerTopPadding)
                    .zIndex(1)

                if viewModel.isEditing {
                    editingGuidance
                        .padding(.horizontal, edgePadding)
                        .transition(.opacity)
                }

                VStack(spacing: 28) {
                    ZStack {
                        LaunchyPagedGridView(
                            viewModel: viewModel,
                            pages: pages,
                            fillsAvailableSpace: fillScreen,
                            onBackgroundTap: handleBackgroundTap,
                            onEscape: handleEscape,
                            onReturn: handleReturn,
                            isOverlayPresented: viewModel.presentedFolderID != nil
                                || isShowingSettings
                        )
                        .onDrop(of: [.fileURL], delegate: FinderDropDelegate(viewModel: viewModel))

                        if !hasResults {
                            VStack(spacing: 16) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 42, weight: .light))
                                    .foregroundStyle(Color.white.opacity(0.5))
                                Text("No Matching Apps")
                                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.white.opacity(0.8))
                                if !searchText.isEmpty {
                                    Text("Try a different search term")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.5))
                                }
                            }
                            .padding(.horizontal, 40)
                            .padding(.vertical, 32)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.black.opacity(0.3))
                            )
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.25), value: hasResults)

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
                .padding(.horizontal, gridHorizontalPadding)
                .padding(.bottom, gridBottomPadding)
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

            if let folderID = viewModel.presentedFolderID {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(2)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            viewModel.closeFolder()
                        }
                    }

                FolderContentView(folderID: folderID, viewModel: viewModel)
                    .padding(.horizontal, 120)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.45).combined(with: .opacity),
                            removal: .scale(scale: 0.45).combined(with: .opacity)
                        )
                    )
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
                    .frame(
                        maxWidth: 680,
                        maxHeight: 540
                    )
                    .frame(
                        minWidth: 480,
                        minHeight: 400
                    )
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .shadow(color: Color.black.opacity(0.4), radius: 32, x: 0, y: 18)
                    .padding(60)
                    .transition(.scale(scale: 0.92).combined(with: .opacity))
                    .zIndex(5)
                    .onTapGesture {}
            }
        }
        .scaleEffect(isPresented ? 1.0 : 0.8)
        .opacity(isPresented ? 1.0 : 0)
        .onAppear {
            activateWindowIfNeeded()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                isPresented = true
            }
            scheduleHeaderControlsHide()
        }
        .onChange(of: viewModel.isEditing) { _, isEditing in
            if isEditing {
                showHeaderControls = true
                headerControlsTimer?.invalidate()
            } else {
                editingBannerHeight = 0
                scheduleHeaderControlsHide()
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
                in: RoundedRectangle(cornerRadius: 24, style: .continuous)
            )
        }
    }

    #if os(macOS)
        @ViewBuilder
        private func themedBackgroundContent(fillScreen: Bool) -> some View {
            let settings = settingsStore.settings
            switch settings.backgroundMode {
            case .wallpaperBlur:
                if fillScreen {
                    DesktopBackdropView()
                        .overlay {
                            backgroundGradient
                                .opacity(settings.blurIntensity)
                        }
                        .ignoresSafeArea()
                } else {
                    backgroundGradient
                        .ignoresSafeArea()
                }
            case .solidColor:
                Color(hex: settings.solidColorHex ?? "1A2030")
                    .ignoresSafeArea()
            case .gradient:
                LinearGradient(
                    colors: [
                        Color(hex: settings.gradientStartHex ?? "212833"),
                        Color(hex: settings.gradientEndHex ?? "080A0D"),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
        }

        private func backgroundLayer(fillScreen: Bool) -> some View {
            themedBackgroundContent(fillScreen: fillScreen)
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
        dismissLauncher()
    }

    /// Handles the Return/Enter key: launches the top search result if searching,
    /// matching real Launchpad's instant-launch behavior.
    private func handleReturn() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Find the top search result
        let results = viewModel.pagedItems(matching: trimmed)
        guard let firstPage = results.first, let topResult = firstPage.first else { return }
        viewModel.launch(topResult)
    }

    /// Handles the Escape key with a layered dismiss priority:
    /// 1. Close an open folder overlay
    /// 2. Close the settings overlay
    /// 3. Clear search text
    /// 4. Exit editing / wiggle mode
    /// 5. Dismiss (hide) the launcher
    private func handleEscape() {
        if viewModel.presentedFolderID != nil {
            withAnimation(.easeInOut(duration: 0.24)) {
                viewModel.closeFolder()
            }
            return
        }
        if isShowingSettings {
            withAnimation(.easeInOut(duration: 0.24)) {
                isShowingSettings = false
            }
            return
        }
        if !searchText.isEmpty {
            searchText = ""
            return
        }
        if viewModel.isEditing {
            viewModel.toggleEditing()
            return
        }
        dismissLauncher()
    }

    private func activateWindowIfNeeded() {
        #if os(macOS)
            guard !didActivateWindow else { return }
            didActivateWindow = true
            Task { @MainActor in
                NSApp.activate()
                if let window = NSApp.windows.first(where: {
                    $0.isVisible
                        && $0.identifier?.rawValue == "dev.lbenicio.launchy.main"
                }) {
                    window.makeKeyAndOrderFront(nil)
                    window.makeFirstResponder(window.contentView)
                }
            }
        #endif
    }

    /// Re-show the launcher after it was hidden. Resets transient view state
    /// so the user gets a clean grid (no leftover search text, open folders, etc.).
    private func reappearLauncher() {
        #if os(macOS)
            searchText = ""
            if viewModel.presentedFolderID != nil {
                viewModel.closeFolder()
            }
            if isShowingSettings {
                isShowingSettings = false
            }
            viewModel.resetLaunchState()
            didActivateWindow = false
            isPresented = false
            activateWindowIfNeeded()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                isPresented = true
            }
            scheduleHeaderControlsHide()
        #endif
    }

    /// Schedules the header controls (wiggle toggle and settings button)
    /// to fade out after a period of inactivity when not in edit mode.
    private func scheduleHeaderControlsHide() {
        headerControlsTimer?.invalidate()
        showHeaderControls = true
        guard !viewModel.isEditing, !isShowingSettings else { return }
        headerControlsTimer = Timer.scheduledTimer(
            withTimeInterval: 3.0,
            repeats: false
        ) { _ in
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.3)) {
                    showHeaderControls = false
                }
            }
        }
    }

    private func buildPages(for query: String) -> [[LaunchyItem]] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return viewModel.pagedItems
        }
        let filtered = viewModel.pagedItems(matching: trimmed)
        return filtered.isEmpty ? [[]] : filtered
    }

    #if os(macOS)
        /// Hides the launcher window and returns to the desktop,
        /// matching real Launchpad behavior. The app stays alive so
        /// it can be re-shown via the dock icon, Cmd-Tab, or a global hotkey.
        private func dismissLauncher() {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                isPresented = false
            }
            Task { @MainActor in
                // Short delay to let the zoom-out animation begin before window fades
                try? await Task.sleep(for: .milliseconds(120))
                NSApp.presentationOptions = []
                if let window = NSApp.windows.first(where: {
                    $0.isVisible
                        && $0.identifier?.rawValue == "dev.lbenicio.launchy.main"
                }) {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.18
                        window.animator().alphaValue = 0
                    } completionHandler: {
                        MainActor.assumeIsolated {
                            window.orderOut(nil)
                            NSApp.hide(nil)
                        }
                    }
                } else {
                    NSApp.hide(nil)
                }
            }
        }
    #else
        private func dismissLauncher() {}
    #endif

    private var header: some View {
        ZStack {
            // Centered search field
            searchField

            // Left-aligned editing controls, right-aligned buttons
            HStack(spacing: 16) {
                if viewModel.isEditing {
                    selectionSummary
                    if !viewModel.recentlyRemovedApps.isEmpty {
                        restoreRemovedButton
                    }
                    newFolderButton
                }
                Spacer()
                wiggleToggle
                    .opacity(
                        showHeaderControls || viewModel.isEditing ? 1 : 0
                    )
                settingsButton
                    .opacity(
                        showHeaderControls || viewModel.isEditing ? 1 : 0
                    )
            }
            .animation(.easeInOut(duration: 0.3), value: showHeaderControls)
        }
        .onHover { isHovering in
            if isHovering {
                withAnimation(.easeIn(duration: 0.2)) {
                    showHeaderControls = true
                }
                headerControlsTimer?.invalidate()
            } else {
                scheduleHeaderControlsHide()
            }
        }
    }

    private var restoreRemovedButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.24)) {
                viewModel.restoreRemovedApps()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text("Restore Removed (\(viewModel.recentlyRemovedApps.count))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .accessibilityLabel(
            "Restore \(viewModel.recentlyRemovedApps.count) removed app\(viewModel.recentlyRemovedApps.count == 1 ? "" : "s")"
        )
        .accessibilityHint("Returns removed apps to the end of the grid")
    }

    private var searchField: some View {
        LaunchySearchField(text: $searchText)
            .frame(width: 240)
            .accessibilityLabel("Search apps")
            .accessibilityHint("Type to filter apps by name")
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
        .accessibilityLabel(viewModel.isEditing ? "Done editing" : "Edit layout")
        .accessibilityHint(
            viewModel.isEditing
                ? "Exits wiggle mode and saves your arrangement"
                : "Enter wiggle mode to rearrange or delete apps"
        )
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
        .accessibilityLabel("Settings")
        .accessibilityHint("Opens Launchy settings")
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "Wiggle mode active. Select apps to make folders, drag or use arrows to reorder."
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
        newFolderColor = .blue
        folderCreationError = nil
        isCreatingFolder = true
        DispatchQueue.main.async {
            isFolderNameFieldFocused = true
        }
    }

    private func commitFolderCreation() {
        let ids = Array(viewModel.selectedItemIDs)
        guard viewModel.createFolder(named: newFolderName, color: newFolderColor, from: ids) != nil
        else {
            folderCreationError = "Select at least two apps to create a folder."
            return
        }

        folderCreationError = nil
        newFolderName = ""
        newFolderColor = .blue
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

            VStack(alignment: .leading, spacing: 10) {
                Text("Folder Color")
                    .font(.system(size: 13, weight: .semibold))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(IconColor.allCases, id: \.self) { iconColor in
                            Button {
                                newFolderColor = iconColor
                            } label: {
                                Circle()
                                    .fill(iconColor.color)
                                    .frame(width: 24, height: 24)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                Color.white,
                                                lineWidth: newFolderColor == iconColor
                                                    ? 2.5 : 0
                                            )
                                    )
                                    .overlay(
                                        newFolderColor == iconColor
                                            ? Image(systemName: "checkmark")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundStyle(.white)
                                            : nil
                                    )
                                    .shadow(
                                        color: iconColor.color.opacity(
                                            newFolderColor == iconColor ? 0.5 : 0
                                        ),
                                        radius: 4
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
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
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                let isActive = index == currentPage
                Button {
                    onSelect(index)
                } label: {
                    Circle()
                        .fill(Color.white.opacity(isActive ? 0.85 : 0.4))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.2), value: currentPage)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Page \(index + 1) of \(totalPages)")
                .accessibilityHint(isActive ? "Current page" : "Go to page \(index + 1)")
                .accessibilityAddTraits(isActive ? [.isSelected] : [])
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.28), in: Capsule())
        .accessibilityElement(children: .contain)
    }
}
