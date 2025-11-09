import SwiftUI

#if os(macOS)
    import AppKit

    struct WindowConfigurator: NSViewRepresentable {
        var useFullScreenLayout: Bool = true

        func makeNSView(context: Context) -> NSView {
            let view = NSView()
            DispatchQueue.main.async {
                configureIfNeeded(using: view)
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            DispatchQueue.main.async {
                configureIfNeeded(using: nsView)
            }
        }

        private func configureIfNeeded(using hostView: NSView) {
            guard let window = hostView.window, let screen = window.screen ?? NSScreen.main else {
                return
            }

            window.titleVisibility = .hidden
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = useFullScreenLayout ? false : true
            window.level = useFullScreenLayout ? .mainMenu : .floating
            window.collectionBehavior = [
                .canJoinAllSpaces,
                .fullScreenAuxiliary,
                .stationary,
                .ignoresCycle,
            ]
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true

            if useFullScreenLayout {
                if window.frame != screen.frame {
                    window.setFrame(screen.frame, display: true)
                }
            } else {
                let visibleFrame = screen.visibleFrame
                window.contentView?.layoutSubtreeIfNeeded()

                let minimumContentSize = NSSize(width: 1024, height: 720)
                var contentSize = window.contentView?.fittingSize ?? minimumContentSize
                if !contentSize.width.isFinite || !contentSize.height.isFinite
                    || contentSize.width <= 0 || contentSize.height <= 0
                {
                    contentSize = minimumContentSize
                }

                let clampedContentSize = NSSize(
                    width: max(contentSize.width, minimumContentSize.width),
                    height: max(contentSize.height, minimumContentSize.height)
                )

                let windowFrameSize = window.frameRect(
                    forContentRect: NSRect(origin: .zero, size: clampedContentSize)
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
        }
    }
#endif
