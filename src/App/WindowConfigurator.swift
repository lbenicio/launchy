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
                let screen = Self.preferredScreen(useFullScreenLayout: useFullScreenLayout) ?? Self.screenContainingCursor() ?? window.screen ?? NSScreen.main
            else { return }

            coordinator.attach(to: window, useFullScreenLayout: useFullScreenLayout)

            // Set a stable identifier so window lookup elsewhere doesn't rely
            // on SwiftUI's internal identifier strings which may change.
            if window.identifier == nil
                || window.identifier?.rawValue.hasPrefix("com_apple_") == true
            {
                window.identifier = NSUserInterfaceItemIdentifier("dev.lbenicio.launchy.main")
            }

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
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.35
                        context.timingFunction = CAMediaTimingFunction(
                            name: .easeInEaseOut
                        )
                        window.animator().setFrame(targetFrame, display: true)
                    }
                }
            }

            if !window.isKeyWindow {
                NSApp.activate()
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
            
            // First try to find the screen that contains the cursor
            for screen in NSScreen.screens {
                if screen.frame.contains(mouseLocation) {
                    return screen
                }
            }
            
            // Fallback to main screen if cursor is outside all screens
            return NSScreen.main
        }
        
        /// Returns the screen where Launchpad should appear based on user preference or cursor location
        private static func preferredScreen(useFullScreenLayout: Bool) -> NSScreen? {
            if useFullScreenLayout {
                // In fullscreen mode, always follow the cursor
                return screenContainingCursor()
            } else {
                // In windowed mode, remember the last used screen or use the main screen
                // This could be enhanced to store user preference
                return NSScreen.main ?? screenContainingCursor()
            }
        }
        
        /// Gets the optimal frame for Launchpad on the given screen
        private static func optimalFrame(for screen: NSScreen, useFullScreenLayout: Bool) -> NSRect {
            if useFullScreenLayout {
                return screen.frame
            } else {
                return screen.visibleFrame
            }
        }
        
        /// Handles screen configuration changes (disconnected/connected monitors)
        private func handleScreenConfigurationChange() {
            guard let window = NSApp.windows.first(where: {
                $0.identifier?.rawValue == "dev.lbenicio.launchy.main"
            }) else { return }
            
            // Get the current preferred screen
            let preferredScreen = Self.preferredScreen(useFullScreenLayout: useFullScreenLayout)
            
            // If the current window is on a screen that no longer exists, move it
            if let windowScreen = window.screen, !NSScreen.screens.contains(windowScreen) {
                if let newScreen = preferredScreen {
                    let newFrame = Self.optimalFrame(for: newScreen, useFullScreenLayout: useFullScreenLayout)
                    
                    if useFullScreenLayout {
                        window.setFrame(newFrame, display: true, animate: false)
                    } else {
                        // Center the window on the new screen
                        let windowSize = window.frame.size
                        let screenCenter = NSPoint(
                            x: newFrame.midX - windowSize.width / 2,
                            y: newFrame.midY - windowSize.height / 2
                        )
                        let centeredFrame = NSRect(
                            origin: screenCenter,
                            size: windowSize
                        )
                        window.setFrame(centeredFrame, display: true, animate: true)
                    }
                }
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
