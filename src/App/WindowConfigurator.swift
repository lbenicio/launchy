import SwiftUI

#if os(macOS)
    import AppKit

    struct WindowConfigurator: NSViewRepresentable {
        var useFullScreenLayout: Bool = true
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
                let screen = Self.screenContainingCursor() ?? window.screen ?? NSScreen.main
            else { return }

            coordinator.attach(to: window, useFullScreenLayout: useFullScreenLayout)

            // --- Chrome ---
            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.title = ""
            window.toolbar = nil
            window.isOpaque = false
            window.backgroundColor = .clear
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true

            // --- Style mask ---
            var style: NSWindow.StyleMask = [.borderless, .fullSizeContentView]
            if !useFullScreenLayout {
                style.insert(.resizable)
            }
            if window.styleMask != style {
                window.styleMask = style
            }

            if useFullScreenLayout {
                // Launchpad-like: cover the entire display including menubar
                window.hasShadow = false
                // Level above the menubar so the window covers it completely
                window.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
                window.collectionBehavior = [
                    .canJoinAllSpaces,
                    .fullScreenAuxiliary,
                    .stationary,
                    .ignoresCycle,
                ]
                window.isMovableByWindowBackground = false

                // Hide the dock and menubar while the app is active, like real Launchpad
                NSApp.presentationOptions = [
                    .autoHideDock,
                    .autoHideMenuBar,
                ]

                // Use the full screen frame (including menubar area)
                let targetFrame = screen.frame
                if !window.frame.equalTo(targetFrame) {
                    window.setFrame(targetFrame, display: true, animate: false)
                }
            } else {
                window.hasShadow = true
                window.level = .floating
                window.collectionBehavior = [
                    .canJoinAllSpaces,
                    .fullScreenAuxiliary,
                    .stationary,
                    .ignoresCycle,
                ]
                window.isMovableByWindowBackground = true

                // Restore normal presentation options
                NSApp.presentationOptions = []

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

                if !targetContentSize.width.isFinite || !targetContentSize.height.isFinite
                    || targetContentSize.width <= 0 || targetContentSize.height <= 0
                {
                    targetContentSize = minimumContentSize
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

                if abs(window.frame.width - targetFrame.width) > 1
                    || abs(window.frame.height - targetFrame.height) > 1
                    || abs(window.frame.origin.x - targetFrame.origin.x) > 1
                    || abs(window.frame.origin.y - targetFrame.origin.y) > 1
                {
                    window.setFrame(targetFrame, display: true)
                }
            }

            if !window.isKeyWindow {
                NSApp.activate(ignoringOtherApps: true)
                window.makeKeyAndOrderFront(nil)
            }

            if let contentView = window.contentView,
                window.firstResponder == nil || window.firstResponder === window
            {
                window.makeFirstResponder(contentView)
            }
        }

        /// Returns the screen that currently contains the mouse cursor,
        /// matching real Launchpad's multi-display behavior.
        private static func screenContainingCursor() -> NSScreen? {
            let mouseLocation = NSEvent.mouseLocation
            return NSScreen.screens.first { screen in
                screen.frame.contains(mouseLocation)
            }
        }

        /// A custom NSView that notifies immediately when it is added to a window,
        /// allowing synchronous configuration without DispatchQueue.main.async delays.
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
            private var useFullScreenLayout: Bool = true

            init(onWindowSizeChange: @escaping (CGSize) -> Void) {
                self.onWindowSizeChange = onWindowSizeChange
            }

            func attach(to window: NSWindow, useFullScreenLayout: Bool) {
                if observedWindow !== window {
                    observedWindow = window
                    window.delegate = self
                }
                self.useFullScreenLayout = useFullScreenLayout
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

            private func reportSizeIfNeeded(from window: NSWindow) {
                guard !useFullScreenLayout else { return }
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
