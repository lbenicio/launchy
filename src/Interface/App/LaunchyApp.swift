import AppKit
import Combine
import SwiftUI

@main
struct LaunchyApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
  @StateObject private var catalogStore: AppCatalogStore
  @StateObject private var settings: AppSettings

    init() {
    let store = AppCatalogStore()
    let appSettings = AppSettings()
    _catalogStore = StateObject(wrappedValue: store)
    _settings = StateObject(wrappedValue: appSettings)
    appDelegate.catalogStore = store
    appDelegate.activationHandler = { [weak delegate = appDelegate] in
      guard let delegate else { return }
      Task { @MainActor in
        delegate.presentPrimaryWindow()
      }
    }
    appDelegate.settings = appSettings
  }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(catalogStore)
                .environmentObject(settings)
                .background(
                    VisualEffectView(
                        material: .fullScreenUI,
                        blendingMode: .behindWindow
                    )
                )
        .ignoresSafeArea()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
          openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
            CommandGroup(replacing: .appTermination) {
                Button("Quit Launchy") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            CommandMenu("Catalog") {
                Button("Reload Catalog") {
                    Task { await catalogStore.reloadCatalog() }
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
    }
    }

  @MainActor
    private func openSettingsWindow() {
    SettingsWindowManager.shared.settingsProvider = { settings }
    SettingsWindowManager.shared.show()
    }
}

final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
  static weak var shared: AppLifecycleDelegate?

    var activationHandler: (() -> Void)?
  weak var catalogStore: AppCatalogStore? {
    didSet {
      guard catalogStore !== oldValue else { return }
      if let store = catalogStore {
        KeyboardMonitor.shared.configure(with: store)
      } else {
        KeyboardMonitor.shared.teardown()
      }
    }
  }
  var settings: AppSettings? {
    didSet {
      guard settings !== oldValue else { return }
      Task { @MainActor [weak self] in
        guard let self else { return }
        self.cancellables.removeAll()
        if let settings = self.settings {
          self.daemonModeEnabled = settings.daemonModeEnabled
          settings.$daemonModeEnabled
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
              self?.handleDaemonPreferenceChange(enabled)
            }
            .store(in: &self.cancellables)
        } else {
          self.daemonModeEnabled = true
        }
      }
    }
  }

  private var cancellables: Set<AnyCancellable> = []
    private var storedPresentationOptions: NSApplication.PresentationOptions = []
    private var presentationStored = false
    private var statusItem: NSStatusItem?
  private var daemonModeEnabled = true
  private var currentActivationPolicy: NSApplication.ActivationPolicy?
  private var suppressNextPresentation = false
  private var hasPresentedPrimaryWindow = false
  private var primaryWindowReference: NSWindow?
  private var didHandleInitialActivation = false

  override init() {
    super.init()
    AppLifecycleDelegate.shared = self
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .vibrantDark)
    setupStatusItem()
        AccessibilityPermission.requestIfNeeded()
    updateActivationPolicy()
    if daemonModeEnabled {
      suppressNextPresentation = true
    }
    }

  @MainActor
    func applicationDidBecomeActive(_ notification: Notification) {
    let isInitialActivation = !didHandleInitialActivation
    didHandleInitialActivation = true
    updateActivationPolicy()
    guard let window = primaryWindow else { return }
        if !presentationStored {
            storedPresentationOptions = NSApp.presentationOptions
            presentationStored = true
        }
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        if let screen = window.screen ?? NSScreen.main {
            window.setFrame(screen.frame, display: true)
        }
    if isInitialActivation && daemonModeEnabled && !hasPresentedPrimaryWindow {
      return
    }
    guard !skipPresentationForDaemonMode else {
      return
    }
    if daemonModeEnabled && !hasPresentedPrimaryWindow {
      presentPrimaryWindow()
      return
    }
    let settingsVisible = SettingsWindowManager.shared.isShowing
    if !settingsVisible && (NSApp.keyWindow === window || NSApp.keyWindow == nil) {
      window.makeKeyAndOrderFront(nil)
      window.orderFrontRegardless()
    }
    }

    func applicationDidResignActive(_ notification: Notification) {
        restorePresentationOptions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        restorePresentationOptions()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }

  @MainActor
  func presentPrimaryWindow() {
    hasPresentedPrimaryWindow = true
    if let store = catalogStore {
      KeyboardMonitor.shared.configure(with: store)
    }
    showPrimaryWindow()
  }

  @MainActor
  func hideToBackground() {
    suppressNextPresentation = true
    _ = hidePrimaryWindow()
  }

    @objc private func openMainWindow() {
        activationHandler?()
    }

  @objc private func openSettings() {
    guard let settings else { return }
    Task { @MainActor in
      SettingsWindowManager.shared.settingsProvider = { settings }
      SettingsWindowManager.shared.show()
    }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private func restorePresentationOptions() {
        guard presentationStored else { return }
        NSApp.presentationOptions = storedPresentationOptions
    }

    private func setupStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = makeStatusMenu()
        if let button = statusItem.button {
            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
                let image = NSImage(contentsOf: iconURL)
            {
                image.size = NSSize(width: 18, height: 18)
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Launchy"
            }
        }
        self.statusItem = statusItem
    }

    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Open Launchy", action: #selector(openMainWindow), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Launchy", action: #selector(quitApp), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

  @MainActor
  private func handleDaemonPreferenceChange(_ enabled: Bool) {
    let previous = daemonModeEnabled
    daemonModeEnabled = enabled
    updateActivationPolicy()
    if enabled {
      suppressNextPresentation = true
      _ = hidePrimaryWindow()
    } else if previous {
      hasPresentedPrimaryWindow = true
      showPrimaryWindow()
    }
  }

  @MainActor
  private func updateActivationPolicy() {
    let target: NSApplication.ActivationPolicy = daemonModeEnabled ? .accessory : .regular
    guard currentActivationPolicy != target else { return }
    if NSApp.setActivationPolicy(target) {
      currentActivationPolicy = target
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool)
    -> Bool
  {
    if daemonModeEnabled {
      DispatchQueue.main.async { [weak self] in
        self?.presentPrimaryWindow()
      }
      return false
    }
    return true
  }

  private var primaryWindow: NSWindow? {
    if let window = primaryWindowReference, window.level == .launchyPrimary {
      return window
    }
    let resolved = NSApp.windows.first { $0.level == .launchyPrimary }
    if let resolved {
      primaryWindowReference = resolved
    }
    return resolved
  }

  @MainActor
  private func showPrimaryWindow() {
    updateActivationPolicy()
    suppressNextPresentation = false
    hasPresentedPrimaryWindow = true
    guard let window = primaryWindow else { return }
    window.setIsVisible(true)
    window.alphaValue = 1
    window.isReleasedWhenClosed = false
    window.orderFrontRegardless()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  @discardableResult
  @MainActor
  private func hidePrimaryWindow() -> Bool {
    updateActivationPolicy()
    guard let window = primaryWindow else { return false }
    window.alphaValue = 0
    window.setIsVisible(false)
    window.orderOut(nil)
    if daemonModeEnabled {
      NSApp.deactivate()
    }
    return true
  }

  var isDaemonModeActive: Bool {
    daemonModeEnabled
  }

  private var skipPresentationForDaemonMode: Bool {
    daemonModeEnabled && !hasPresentedPrimaryWindow && !didHandleInitialActivation
  }

  @MainActor
  func consumeSuppressedPresentation(for window: NSWindow) {
    guard suppressNextPresentation else { return }
    window.alphaValue = 0
    window.setIsVisible(false)
    window.orderOut(nil)
  }

  var shouldSuppressWindowPresentation: Bool {
    suppressNextPresentation || skipPresentationForDaemonMode
  }

  @MainActor
  func registerPrimaryWindow(_ window: NSWindow) {
    if primaryWindowReference !== window {
      primaryWindowReference = window
    }
  }
}
