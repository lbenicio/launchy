import SwiftUI

#if os(macOS)
    import AppKit

    struct WindowConfigurator: NSViewRepresentable {
        var preferredWindowSize: CGSize?
        var onWindowSizeChange: (CGSize) -> Void = { _ in }

        func makeCoordinator() -> Coordinator {
            Coordinator(onWindowSizeChange: onWindowSizeChange)
        }

        func makeNSView(context: Context) -> ConfiguratorView {
            let view = ConfiguratorView()
            view.onAttach = { [coordinator = context.coordinator] hostView in
                configureWindow(using: hostView, coordinator: coordinator)
            }
            context.coordinator.onWindowSizeChange = onWindowSizeChange
            return view
        }

        func updateNSView(_ nsView: ConfiguratorView, context: Context) {
            context.coordinator.onWindowSizeChange = onWindowSizeChange
            configureWindow(using: nsView, coordinator: context.coordinator)
        }

        private func configureWindow(using hostView: NSView, coordinator: Coordinator) {
            guard let window = hostView.window,
                let screen = NSScreen.main
            else { return }

            coordinator.attach(to: window)

            // Set a stable identifier
            if window.identifier == nil
                || window.identifier?.rawValue.hasPrefix("com_apple_") == true
            {
                window.identifier = NSUserInterfaceItemIdentifier("com.launchy.app.main")
            }

            // Basic window setup
            window.title = "Launchy"
            window.titlebarAppearsTransparent = false
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor

            // Normal window style
            let style: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .resizable]
            if window.styleMask != style {
                window.styleMask = style
            }

            // Normal window level and behavior
            window.level = .normal
            window.collectionBehavior = [.canJoinAllSpaces]

            // Set window size
            let visibleFrame = screen.visibleFrame
            let minimumContentSize = NSSize(width: 1024, height: 720)
            var targetContentSize: NSSize

            if let preferredWindowSize {
                targetContentSize = NSSize(
                    width: preferredWindowSize.width,
                    height: preferredWindowSize.height
                )
            } else {
                targetContentSize = window.contentView?.fittingSize ?? minimumContentSize
            }

            targetContentSize = NSSize(
                width: max(targetContentSize.width, minimumContentSize.width),
                height: max(targetContentSize.height, minimumContentSize.height)
            )

            let windowFrameSize = window.frameRect(
                forContentRect: NSRect(origin: .zero, size: targetContentSize)
            ).size
            let targetOrigin = NSPoint(
                x: visibleFrame.midX - windowFrameSize.width / 2,
                y: visibleFrame.midY - windowFrameSize.height / 2
            )
            let targetFrame = NSRect(origin: targetOrigin, size: windowFrameSize)

            if !window.frame.equalTo(targetFrame) {
                window.setFrame(targetFrame, display: true, animate: false)
            }

            // Make window key and visible
            if !window.isKeyWindow {
                window.makeKeyAndOrderFront(nil)
            }

            // Ensure app is brought to front
            NSApp.activate(ignoringOtherApps: true)

            if let contentView = window.contentView,
                window.firstResponder == nil || window.firstResponder === window
            {
                window.makeFirstResponder(contentView)
            }
        }

        /// A custom NSView that notifies immediately when it is added to a window
        final class ConfiguratorView: NSView {
            var onAttach: ((NSView) -> Void)?

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                if window != nil {
                    onAttach?(self)
                }
            }
        }

        @MainActor
        final class Coordinator: NSObject, NSWindowDelegate {
            var onWindowSizeChange: (CGSize) -> Void
            private weak var observedWindow: NSWindow?
            private var lastReportedSize: CGSize?

            init(onWindowSizeChange: @escaping (CGSize) -> Void) {
                self.onWindowSizeChange = onWindowSizeChange
            }

            func attach(to window: NSWindow) {
                if observedWindow !== window {
                    observedWindow = window
                    window.delegate = self
                }
                reportSizeIfNeeded(from: window)
            }

            func windowDidResize(_ notification: Notification) {
                guard let window = notification.object as? NSWindow else { return }
                reportSizeIfNeeded(from: window)
            }

            func windowDidEndLiveResize(_ notification: Notification) {
                guard let window = notification.object as? NSWindow else { return }
                reportSizeIfNeeded(from: window)
            }

            func windowShouldClose(_ sender: NSWindow) -> Bool {
                // When window closes, quit the app
                NSApp.terminate(nil)
                return true
            }

            private func reportSizeIfNeeded(from window: NSWindow) {
                let contentRect = window.contentRect(forFrameRect: window.frame)
                let size = contentRect.size
                guard size.width.isFinite, size.height.isFinite else { return }
                if let last = lastReportedSize,
                    abs(last.width - size.width) < 1,
                    abs(last.height - size.height) < 1
                {
                    return
                }
                lastReportedSize = size
                onWindowSizeChange(size)
            }
        }
    }
#endif
