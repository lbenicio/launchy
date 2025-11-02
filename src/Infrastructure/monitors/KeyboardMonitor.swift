import AppKit
import ApplicationServices
import Combine

final class KeyboardMonitor {
    static let shared = KeyboardMonitor()

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private weak var store: AppCatalogStore?
    private let accessQueue = DispatchQueue(label: "launchy.keyboard-monitor")

    private init() {}

    func configure(with store: AppCatalogStore) {
        accessQueue.sync {
            if self.store === store {
                return
            }
            self.store = store
            installMonitors()
        }
    }

    func teardown() {
        accessQueue.sync {
            removeMonitors()
            store = nil
        }
    }

    private func installMonitors() {
        removeMonitors()

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            let shouldConsume = self.handle(event: event)
            return shouldConsume ? nil : event
        }

        AccessibilityPermission.requestIfNeeded()
        if AXIsProcessTrusted() {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) {
                [weak self] event in
                _ = self?.handle(event: event)
            }
        }
    }

    private func removeMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    @discardableResult
    private func handle(event: NSEvent) -> Bool {
        guard event.type == .keyDown else { return false }
        switch event.keyCode {
        case 53:  // Escape key
            Task { @MainActor [weak self] in
                guard let self, let store = self.store else { return }
                var clearedState = false
                if store.isEditing {
                    store.endEditing()
                    clearedState = true
                }
                if store.presentedFolder != nil {
                    store.dismissPresentedFolder()
                    clearedState = true
                }
                if !store.query.isEmpty {
                    store.query = ""
                    clearedState = true
                }
                if let delegate = NSApp.delegate as? AppLifecycleDelegate {
                    if delegate.isDaemonModeActive {
                        delegate.hideToBackground()
                    } else if !clearedState {
                        NSApp.terminate(nil)
                    }
                } else if !clearedState {
                    NSApp.terminate(nil)
                }
            }
            return true
        default:
            break
        }
        return false
    }
}
