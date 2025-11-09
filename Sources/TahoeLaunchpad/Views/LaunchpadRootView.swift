import SwiftUI

#if os(macOS)
    import AppKit
#endif

struct LaunchpadRootView: View {
    @ObservedObject var viewModel: LaunchpadViewModel

    @State private var searchText: String = ""

    private var pages: [[LaunchpadItem]] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return viewModel.pagedItems }
        return viewModel.pagedItems(matching: query)
    }

    private var hasResults: Bool {
        pages.contains { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 24) {
                header
                    .padding(.horizontal, 80)
                    .padding(.top, 40)
                    .zIndex(1)

                ZStack(alignment: .bottom) {
                    LaunchpadPagedGridView(viewModel: viewModel, pages: pages)

                    if !hasResults {
                        Text("No Matching Apps")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .padding(24)
                            .background(Color.black.opacity(0.35), in: Capsule())
                    }

                    if pages.count > 1 {
                        PageControlView(currentPage: viewModel.currentPage, totalPages: pages.count)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.bottom, 60)
            }

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
            .background(WindowConfigurator())
        #endif
        .onChange(of: searchText) { _, _ in
            viewModel.currentPage = 0
        }
        .onChange(of: pages.count) { _, newCount in
            let maxIndex = max(newCount - 1, 0)
            if viewModel.currentPage > maxIndex {
                viewModel.currentPage = maxIndex
            }
        }
    }

    #if os(macOS)
        private var backgroundLayer: some View {
            DesktopBackdropView()
                .overlay {
                    backgroundGradient
                        .opacity(0.25)
                }
                .ignoresSafeArea()
        }
    #else
        private var backgroundLayer: some View {
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
        TextField("Search", text: $searchText)
            .textFieldStyle(.roundedBorder)
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
            showSettings()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.9))
                .padding(10)
                .background(Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func showSettings() {
        #if os(macOS)
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        #endif
    }
}

struct PageControlView: View {
    let currentPage: Int
    let totalPages: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalPages, id: \.self) { index in
                Capsule()
                    .fill(
                        index == currentPage ? Color.white.opacity(0.8) : Color.white.opacity(0.3)
                    )
                    .frame(width: index == currentPage ? 28 : 10, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.25), in: Capsule())
    }
}
