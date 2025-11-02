import AppKit
import ApplicationServices

final class KeyboardMonitor {
    static let shared = KeyboardMonitor()

    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var monitorsInstalled = false
    private let accessQueue = DispatchQueue(label: "launchy.keyboard-monitor")

    private init() {}

    func configure(with _: AppCatalogStore) {
        accessQueue.sync {
            if monitorsInstalled {
                return
            }
            installMonitors()
            monitorsInstalled = true
        }
    }

    func teardown() {
        accessQueue.sync {
            removeMonitors()
            monitorsInstalled = false
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
            Task { @MainActor in
                NSApp.terminate(nil)
            }
            return true
        default:
            break
        }
        return false
    }
}
