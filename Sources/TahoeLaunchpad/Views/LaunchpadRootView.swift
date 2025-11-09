import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct LaunchpadRootView: View {
    @ObservedObject var viewModel: LaunchpadViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore

    @State private var searchText: String = ""
    @State private var isShowingSettings: Bool = false

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
                        fillsAvailableSpace: fillScreen
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
        }
    #else
        private func backgroundLayer(fillScreen _: Bool) -> some View {
            backgroundGradient
                .ignoresSafeArea()
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

    private var header: some View {
        HStack(spacing: 16) {
            searchField
            Spacer()
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
