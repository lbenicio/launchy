import SwiftUI

#if os(macOS)
    import AppKit

    struct PageNavigationKeyHandler: NSViewRepresentable {
        let scrollSensitivity: Double
        let isEnabled: Bool
        let onPrevious: () -> Void
        let onNext: () -> Void
        let onEscape: () -> Void
        let onReturn: () -> Void

        func makeCoordinator() -> Coordinator {
            Coordinator(
                scrollSensitivity: scrollSensitivity,
                isEnabled: isEnabled,
                onPrevious: onPrevious,
                onNext: onNext,
                onEscape: onEscape,
                onReturn: onReturn
            )
        }

        func makeNSView(context: Context) -> RelayView {
            let view = RelayView()
            view.coordinator = context.coordinator
            return view
        }

        func updateNSView(_ nsView: RelayView, context: Context) {
            context.coordinator.updateScrollSensitivity(scrollSensitivity)
            context.coordinator.isEnabled = isEnabled
            context.coordinator.onPrevious = onPrevious
            context.coordinator.onNext = onNext
            context.coordinator.onEscape = onEscape
            context.coordinator.onReturn = onReturn
            nsView.coordinator = context.coordinator
        }

        static func dismantleNSView(_ nsView: RelayView, coordinator: Coordinator) {
            coordinator.teardown()
        }

        @MainActor
        final class Coordinator {
            private(set) var scrollSensitivity: Double
            var isEnabled: Bool
            var onPrevious: () -> Void
            var onNext: () -> Void
            var onEscape: () -> Void
            var onReturn: () -> Void

            private var monitor: Any?
            private weak var observedWindow: NSWindow?
            private var scrollAccumulator: CGFloat = 0

            init(
                scrollSensitivity: Double,
                isEnabled: Bool,
                onPrevious: @escaping () -> Void,
                onNext: @escaping () -> Void,
                onEscape: @escaping () -> Void,
                onReturn: @escaping () -> Void
            ) {
                self.scrollSensitivity = PageNavigationKeyHandler.clamp(scrollSensitivity)
                self.isEnabled = isEnabled
                self.onPrevious = onPrevious
                self.onNext = onNext
                self.onEscape = onEscape
                self.onReturn = onReturn
            }

            func updateScrollSensitivity(_ value: Double) {
                scrollSensitivity = PageNavigationKeyHandler.clamp(value)
            }

            func installMonitorIfNeeded(for window: NSWindow?) {
                guard monitor == nil else { return }
                guard let window else { return }

                observedWindow = window
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) {
                    [weak self, weak window] event in
                    guard let self, let window, event.window === window else { return event }
                    let isEscape = event.type == .keyDown && event.keyCode == 53
                    let isReturn =
                        event.type == .keyDown && (event.keyCode == 36 || event.keyCode == 76)
                    guard isEscape || isReturn || self.isEnabled else { return event }
                    return self.handle(event: event) ? nil : event
                }

                // Observe resign-key to remove the event monitor while hidden,
                // and become-key to re-install it when the window is shown again.
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowDidResignKey(_:)),
                    name: NSWindow.didResignKeyNotification,
                    object: window
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowDidBecomeKey(_:)),
                    name: NSWindow.didBecomeKeyNotification,
                    object: window
                )
            }

            func teardown() {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }

                if let window = observedWindow {
                    NotificationCenter.default.removeObserver(
                        self,
                        name: NSWindow.didResignKeyNotification,
                        object: window
                    )
                    NotificationCenter.default.removeObserver(
                        self,
                        name: NSWindow.didBecomeKeyNotification,
                        object: window
                    )
                }

                observedWindow = nil
            }

            /// Remove only the event monitor when the window loses focus.
            /// Window observers are kept so `windowDidBecomeKey` can re-install.
            @objc private func windowDidResignKey(_ notification: Notification) {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }
            }

            /// Re-attach the event monitor when the launcher window regains key status.
            @objc private func windowDidBecomeKey(_ notification: Notification) {
                installMonitorIfNeeded(for: observedWindow)
            }

            private func handle(event: NSEvent) -> Bool {
                switch event.type {
                case .keyDown:
                    return handleKey(event)
                case .scrollWheel:
                    return handleScroll(event)
                default:
                    return false
                }
            }

            private func handleKey(_ event: NSEvent) -> Bool {
                // Command-[ / Command-] navigate pages regardless of current responder,
                // matching real Launchpad's keyboard shortcut behaviour.
                if event.modifierFlags.contains(.command) {
                    if event.keyCode == 33 {  // [
                        guard isEnabled else { return false }
                        onPrevious()
                        return true
                    }
                    if event.keyCode == 30 {  // ]
                        guard isEnabled else { return false }
                        onNext()
                        return true
                    }
                }

                guard shouldHandleKey(event) else { return false }

                switch event.keyCode {
                case 123, 115:
                    onPrevious()
                    return true
                case 124, 119:
                    onNext()
                    return true
                case 116:
                    onPrevious()
                    return true
                case 121:
                    onNext()
                    return true
                case 36, 76:  // Return / Enter
                    onReturn()
                    return true
                case 53:
                    onEscape()
                    return true
                default:
                    return false
                }
            }

            private func shouldHandleKey(_ event: NSEvent) -> Bool {
                // Escape should always be handled regardless of responder
                if event.keyCode == 53 {
                    return true
                }

                // Return/Enter should launch the top result even from the search field
                if event.keyCode == 36 || event.keyCode == 76 {
                    return true
                }

                if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) {
                    return false
                }

                guard let responder = event.window?.firstResponder else { return true }

                if responder is NSTextView || responder is NSTextField {
                    return false
                }

                if responder.responds(to: #selector(NSResponder.insertText(_:))) {
                    return false
                }

                return true
            }

            private func handleScroll(_ event: NSEvent) -> Bool {
                // Reset at the start of a new gesture so residual momentum from the
                // previous swipe doesn't bleed into the next one.
                if event.phase == .began {
                    scrollAccumulator = 0
                    return false
                }

                let horizontalMagnitude = abs(event.scrollingDeltaX)
                let verticalMagnitude = abs(event.scrollingDeltaY)

                let primaryDelta: CGFloat
                if horizontalMagnitude > verticalMagnitude {
                    primaryDelta = event.scrollingDeltaX
                } else {
                    primaryDelta = event.scrollingDeltaY
                }

                guard primaryDelta != 0 else { return false }

                let multiplier = CGFloat(scrollSensitivity)
                let baseThreshold: CGFloat = event.hasPreciseScrollingDeltas ? 40 : 4
                let threshold = max(8, baseThreshold * multiplier)
                scrollAccumulator += primaryDelta

                if scrollAccumulator <= -threshold {
                    onNext()
                    scrollAccumulator = 0
                    return true
                } else if scrollAccumulator >= threshold {
                    onPrevious()
                    scrollAccumulator = 0
                    return true
                }

                if event.momentumPhase == .ended || event.phase == .ended {
                    scrollAccumulator = 0
                }

                return false
            }
        }

        final class RelayView: NSView {
            weak var coordinator: PageNavigationKeyHandler.Coordinator? {
                didSet {
                    coordinator?.installMonitorIfNeeded(for: window)
                }
            }

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                coordinator?.installMonitorIfNeeded(for: window)
            }
        }

        private static func clamp(_ value: Double) -> Double {
            min(max(value, 0.2), 2.0)
        }
    }
#else
    struct PageNavigationKeyHandler: View {
        let isEnabled: Bool
        var onPrevious: () -> Void
        var onNext: () -> Void
        var onEscape: () -> Void = {}
        var onReturn: () -> Void = {}

        var body: some View {
            Color.clear
        }
    }
#endif
