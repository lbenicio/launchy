import Foundation

// MARK: - Paging helpers

extension LaunchyViewModel {

    func selectPage(_ index: Int, totalPages: Int) {
        let clamped = min(max(index, 0), max(totalPages - 1, 0))
        guard clamped != currentPage else { return }
        currentPage = clamped
        persistLastVisitedPageIfNeeded(clamped)
    }

    func goToPreviousPage(totalPages: Int) {
        selectPage(max(currentPage - 1, 0), totalPages: totalPages)
    }

    func goToNextPage(totalPages: Int) {
        selectPage(min(currentPage + 1, totalPages - 1), totalPages: totalPages)
    }

    // Internal — also called from init and settings-change sink in core file.
    func persistLastVisitedPageIfNeeded(_ page: Int) {
        guard !settings.useFullScreenLayout else { return }
        settingsStore.update(lastWindowedPage: page)
    }

    // Internal — also called from init, ApplicationWatcher, and ImportExport extensions.
    func ensureCurrentPageInBounds(shouldPersist: Bool = true) {
        let maxIndex = max(pageCount - 1, 0)
        if currentPage > maxIndex {
            currentPage = maxIndex
            if shouldPersist { persistLastVisitedPageIfNeeded(currentPage) }
        }
    }
}
