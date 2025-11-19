import SwiftUI

struct LaunchpadPagedGridView: View {
    @ObservedObject var viewModel: LaunchpadViewModel
    @EnvironmentObject private var settingsStore: GridSettingsStore
    let pages: [[LaunchpadItem]]
    let fillsAvailableSpace: Bool
    var onBackgroundTap: () -> Void = {}

    @State private var scrollPosition: Int? = 0
    @State private var lastSettledPage: Int = 0
    @State private var isProgrammaticScroll: Bool = false

    private let pageAnimation = Animation.interactiveSpring(
        response: 0.48,
        dampingFraction: 0.82,
        blendDuration: 0.25
    )

    var body: some View {
        GeometryReader { proxy in
            let metrics = GridLayoutMetrics(for: settingsStore.settings, in: proxy.size)
            let width = max(proxy.size.width, 1)
            let height = proxy.size.height
            let enumeratedPages = Array(pages.enumerated())
            let totalPages = max(enumeratedPages.count, 1)
            let dragThreshold = max(width * 0.12, 80)

            let dragGesture = DragGesture(minimumDistance: 6, coordinateSpace: .local)
                .onEnded { value in
                    let translation = value.translation.width
                    let predicted = value.predictedEndTranslation.width
                    let effective = abs(predicted) > abs(translation) ? predicted : translation

                    if effective < -dragThreshold {
                        let target = min(lastSettledPage + 1, totalPages - 1)
                        guard target != lastSettledPage else { return }
                        isProgrammaticScroll = true
                        withAnimation(pageAnimation) {
                            scrollPosition = target
                        }
                    } else if effective > dragThreshold {
                        let target = max(lastSettledPage - 1, 0)
                        guard target != lastSettledPage else { return }
                        isProgrammaticScroll = true
                        withAnimation(pageAnimation) {
                            scrollPosition = target
                        }
                    } else {
                        if scrollPosition != lastSettledPage {
                            isProgrammaticScroll = true
                            withAnimation(pageAnimation) {
                                scrollPosition = lastSettledPage
                            }
                        }
                    }
                }

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
            .scrollBounceBehavior(.always)
            .scrollPosition(id: $scrollPosition)
            .frame(width: width, height: height)
            .simultaneousGesture(dragGesture)
            .onChange(of: scrollPosition) { _, newValue in
                guard let newValue else { return }
                let clamped = min(max(newValue, 0), totalPages - 1)

                if clamped != newValue {
                    isProgrammaticScroll = true
                    scrollPosition = clamped
                    return
                }

                if isProgrammaticScroll {
                    isProgrammaticScroll = false
                    lastSettledPage = clamped
                    if clamped != viewModel.currentPage {
                        viewModel.selectPage(clamped, totalPages: totalPages)
                    }
                    return
                }

                let delta = clamped - lastSettledPage
                if abs(delta) > 1 {
                    let limited = lastSettledPage + (delta > 0 ? 1 : -1)
                    isProgrammaticScroll = true
                    withAnimation(pageAnimation) {
                        scrollPosition = limited
                    }
                    return
                }

                lastSettledPage = clamped
                if clamped != viewModel.currentPage {
                    viewModel.selectPage(clamped, totalPages: totalPages)
                }
            }
            .onChange(of: viewModel.currentPage) { _, newValue in
                let clamped = min(max(newValue, 0), totalPages - 1)
                if scrollPosition != clamped {
                    isProgrammaticScroll = true
                    withAnimation(pageAnimation) {
                        scrollPosition = clamped
                    }
                }
            }
            .onAppear {
                let initial = min(viewModel.currentPage, totalPages - 1)
                scrollPosition = initial
                lastSettledPage = initial
            }
        }
        .frame(
            maxWidth: fillsAvailableSpace ? .infinity : nil,
            maxHeight: fillsAvailableSpace ? .infinity : nil,
            alignment: .top
        )
        .contentShape(Rectangle())
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    onBackgroundTap()
                }
        }
        .onChange(of: pages.count) { _, newCount in
            let clampedIndex = min(viewModel.currentPage, max(newCount - 1, 0))
            viewModel.selectPage(clampedIndex, totalPages: newCount)
            lastSettledPage = clampedIndex
            if scrollPosition != clampedIndex {
                isProgrammaticScroll = true
                withAnimation(pageAnimation) {
                    scrollPosition = clampedIndex
                }
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