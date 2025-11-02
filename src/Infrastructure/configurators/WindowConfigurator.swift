import AppKit
import SwiftUI

extension NSWindow.Level {
    static let launchyPrimary = NSWindow.Level.screenSaver
    static let launchyAuxiliary = NSWindow.Level(
        rawValue: NSWindow.Level.screenSaver.rawValue + 1
    )
}

struct TransparentWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
    Task { @MainActor in
            self.configure(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
    Task { @MainActor in
            self.configure(window: nsView.window, coordinator: context.coordinator)
        }
    }

  @MainActor
    private func configure(window: NSWindow?, coordinator: Coordinator) {
        guard let window else { return }

        if coordinator.window !== window {
            coordinator.window = window
            coordinator.didConfigureStyle = false
        }

        if !coordinator.didConfigureStyle {
            window.styleMask = [.borderless]
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.isMovable = false
            window.isMovableByWindowBackground = false
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            coordinator.didConfigureStyle = true
        }

        if let screen = window.screen ?? NSScreen.main {
            if window.frame != screen.frame {
                window.setFrame(screen.frame, display: true)
            }
        }

        window.level = .launchyPrimary
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true

    AppLifecycleDelegate.shared?.consumeSuppressedPresentation(for: window)
    }

    final class Coordinator {
        var window: NSWindow?
        var didConfigureStyle = false
    }
}

struct AuxiliaryWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            self.configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }
        if window.level != .launchyAuxiliary {
            window.level = .launchyAuxiliary
            window.collectionBehavior.insert(.fullScreenAuxiliary)
            window.orderFrontRegardless()
        }
    }
}
