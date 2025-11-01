import AppKit
import ApplicationServices
import Combine

final class KeyboardMonitor {
  static let shared = KeyboardMonitor()

  private var localMonitor: Any?
  private var globalMonitor: Any?
  private weak var store: AppCatalogStore?
  private let accessQueue = DispatchQueue(label: "launchpad.keyboard-monitor")

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
      self?.handle(event: event)
      return event
    }

    AccessibilityPermission.requestIfNeeded()
    if AXIsProcessTrusted() {
      globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
        self?.handle(event: event)
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

  private func handle(event: NSEvent) {
    guard event.type == .keyDown else { return }
    switch event.keyCode {
    case 53:  // Escape key
      Task { @MainActor [weak self] in
        guard let store = self?.store else { return }
        if store.isEditing {
          store.endEditing()
        } else if store.presentedFolder != nil {
          store.dismissPresentedFolder()
        } else if !store.query.isEmpty {
          store.query = ""
        }
      }
    default:
      break
    }
  }
}
