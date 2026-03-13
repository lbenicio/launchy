#if os(macOS)
    import Foundation

    /// Watches application directories for filesystem changes (new installs, removals,
    /// or updates) and calls `onChange` after a debounce period. Used to automatically
    /// reconcile the Launchy grid when apps are installed or deleted without restarting.
    @MainActor
    final class ApplicationWatcher {
        private let directories: [URL]
        private let debounceInterval: TimeInterval
        private let onChange: () -> Void

        private var sources: [DispatchSourceFileSystemObject] = []
        private var debounceWorkItem: DispatchWorkItem?

        init(
            directories: [URL],
            debounceInterval: TimeInterval = 2.0,
            onChange: @escaping () -> Void
        ) {
            self.directories = directories
            self.debounceInterval = debounceInterval
            self.onChange = onChange
        }

        deinit {
            // Cancel all sources synchronously on dealloc.
            sources.forEach { $0.cancel() }
        }

        func start() {
            stop()
            for directory in directories {
                guard FileManager.default.fileExists(atPath: directory.path) else { continue }
                let fd = open(directory.path, O_EVTONLY)
                guard fd >= 0 else { continue }

                let source = DispatchSource.makeFileSystemObjectSource(
                    fileDescriptor: fd,
                    eventMask: [.write, .rename, .delete],
                    queue: .main
                )
                source.setEventHandler { [weak self] in
                    self?.scheduleCallback()
                }
                source.setCancelHandler {
                    close(fd)
                }
                source.resume()
                sources.append(source)
            }
        }

        func stop() {
            sources.forEach { $0.cancel() }
            sources.removeAll()
            debounceWorkItem?.cancel()
            debounceWorkItem = nil
        }

        private func scheduleCallback() {
            debounceWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.onChange()
            }
            debounceWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval, execute: work)
        }
    }
#endif
