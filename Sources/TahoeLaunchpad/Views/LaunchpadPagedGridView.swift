import SwiftUI

struct LaunchpadPagedGridView: View {
    @ObservedObject var viewModel: LaunchpadViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore
    let pages: [[LaunchpadItem]]

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let metrics = GridLayoutMetrics(for: settingsStore.settings, in: proxy.size)
            let width = max(proxy.size.width, 1)
            let height = proxy.size.height

            ZStack {
                HStack(spacing: 0) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        LaunchpadGridPageView(viewModel: viewModel, items: page, metrics: metrics)
                            .frame(width: width, height: height)
                            .id(index)
                    }
                }
                .frame(height: height)
                .offset(x: -CGFloat(viewModel.currentPage) * width + dragOffset)
                .animation(.easeInOut(duration: 0.25), value: viewModel.currentPage)
            }
            .frame(width: width, height: height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 10)
                    .updating($dragOffset) { value, state, _ in
                        state = value.translation.width
                    }
                    .onEnded { value in
                        guard pages.count > 1 else { return }
                        let threshold = width * 0.25
                        var newIndex = viewModel.currentPage
                        if value.translation.width < -threshold {
                            newIndex = min(newIndex + 1, max(pages.count - 1, 0))
                        } else if value.translation.width > threshold {
                            newIndex = max(newIndex - 1, 0)
                        }
                        withAnimation(.easeInOut(duration: 0.25)) {
                            viewModel.currentPage = newIndex
                        }
                    }
            )
        }
    }
}
