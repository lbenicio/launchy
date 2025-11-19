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

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            context.coordinator.onWindowSizeChange = onWindowSizeChange
            DispatchQueue.main.async {
                configureIfNeeded(using: view, coordinator: context.coordinator)
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            context.coordinator.onWindowSizeChange = onWindowSizeChange
            DispatchQueue.main.async {
                configureIfNeeded(using: nsView, coordinator: context.coordinator)
            }
        }

        private func configureIfNeeded(using hostView: NSView, coordinator: Coordinator) {
            guard let window = hostView.window, let screen = window.screen ?? NSScreen.main else {
                return
            }

            coordinator.attach(to: window, useFullScreenLayout: useFullScreenLayout)

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.title = ""
            window.toolbar = nil
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = useFullScreenLayout ? false : true
            window.level = useFullScreenLayout ? .mainMenu : .floating
            window.setContentBorderThickness(0, for: .maxY)
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle,
            ]

            var style: NSWindow.StyleMask = [.borderless, .fullSizeContentView]
            if !useFullScreenLayout {
                style.insert(.resizable)
            }
            if window.styleMask != style {
                window.styleMask = style
            }

            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.isMovableByWindowBackground = true

            if useFullScreenLayout {
                if window.frame != screen.frame {
                    window.setFrame(screen.frame, display: true)
                }
            } else {
                let visibleFrame = screen.visibleFrame
                window.contentView?.layoutSubtreeIfNeeded()

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
                    || window.frame.origin != targetFrame.origin
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
