import AppKit
import SwiftUI

struct TransparentWindowConfigurator: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            self.configure(window: view.window, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            self.configure(window: nsView.window, coordinator: context.coordinator)
        }
    }

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

        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.ignoresMouseEvents = false
        window.acceptsMouseMovedEvents = true
    }

    final class Coordinator {
        var window: NSWindow?
        var didConfigureStyle = false
    }
}
