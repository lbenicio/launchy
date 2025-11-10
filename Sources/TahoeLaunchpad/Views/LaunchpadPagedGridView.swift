import SwiftUI

struct LaunchpadPagedGridView: View {
    @ObservedObject var viewModel: LaunchpadViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore
    let pages: [[LaunchpadItem]]
    let fillsAvailableSpace: Bool
    var onBackgroundTap: () -> Void = {}
    @State private var scrollPosition: Int? = 0

    var body: some View {
        GeometryReader { proxy in
            let metrics = GridLayoutMetrics(for: settingsStore.settings, in: proxy.size)
            let width = max(proxy.size.width, 1)
            let height = proxy.size.height
            let enumeratedPages = Array(pages.enumerated())

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(enumeratedPages, id: \.offset) { index, page in
                        LaunchpadGridPageView(viewModel: viewModel, items: page, metrics: metrics)
                            .frame(width: width, height: height)
                            .containerRelativeFrame(.horizontal)
                            .id(index)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .frame(width: width, height: height)
            .onChange(of: scrollPosition) { _, newValue in
                guard let newValue else { return }
                viewModel.selectPage(newValue, totalPages: max(enumeratedPages.count, 1))
            }
            .onChange(of: viewModel.currentPage) { _, newValue in
                let totalPages = max(enumeratedPages.count, 1)
                let clamped = min(max(newValue, 0), totalPages - 1)
                if scrollPosition != clamped {
                    scrollPosition = clamped
                }
            }
            .onAppear {
                let totalPages = max(enumeratedPages.count, 1)
                scrollPosition = min(viewModel.currentPage, totalPages - 1)
            }
        }
        .frame(
            maxWidth: fillsAvailableSpace ? .infinity : nil,
            maxHeight: fillsAvailableSpace ? .infinity : nil,
            alignment: .top
        )
        .contentShape(Rectangle())
        .gesture(
            TapGesture().onEnded {
                onBackgroundTap()
            },
            including: .gesture
        )
        .onChange(of: pages.count) { _, newCount in
            let clampedIndex = min(viewModel.currentPage, max(newCount - 1, 0))
            viewModel.selectPage(clampedIndex, totalPages: newCount)
            if scrollPosition != clampedIndex {
                scrollPosition = clampedIndex
            }
        }
        #if os(macOS)
            .overlay(
                PageNavigationKeyHandler(
                    scrollSensitivity: settingsStore.settings.scrollSensitivity,
                    onPrevious: { viewModel.goToPreviousPage(totalPages: max(pages.count, 1)) },
                    onNext: { viewModel.goToNextPage(totalPages: max(pages.count, 1)) }
                )
                .allowsHitTesting(false)
            )
        #endif
    }
}
