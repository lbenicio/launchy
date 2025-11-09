import SwiftUI

struct LaunchpadPagedGridView: View {
    @ObservedObject var viewModel: LaunchpadViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore
    let pages: [[LaunchpadItem]]

    @State private var scrollPosition: Int? = 0

    var body: some View {
        GeometryReader { proxy in
            let metrics = GridLayoutMetrics(for: settingsStore.settings, in: proxy.size)
            let width = max(proxy.size.width, 1)
            let height = proxy.size.height

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
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
                let clamped = min(max(newValue, 0), max(pages.count - 1, 0))
                if viewModel.currentPage != clamped {
                    viewModel.currentPage = clamped
                }
            }
            .onChange(of: viewModel.currentPage) { _, newValue in
                let clamped = min(max(newValue, 0), max(pages.count - 1, 0))
                if scrollPosition != clamped {
                    scrollPosition = clamped
                }
            }
        }
        .onAppear {
            scrollPosition = min(viewModel.currentPage, max(pages.count - 1, 0))
        }
        .onChange(of: pages.count) { _, newCount in
            let clamped = min(viewModel.currentPage, max(newCount - 1, 0))
            if viewModel.currentPage != clamped {
                viewModel.currentPage = clamped
            }
            if scrollPosition != clamped {
                scrollPosition = clamped
            }
        }
    }
}
