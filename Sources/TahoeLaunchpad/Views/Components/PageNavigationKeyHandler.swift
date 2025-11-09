import SwiftUI

#if os(macOS)
    import AppKit

    struct PageNavigationKeyHandler: NSViewRepresentable {
        let onPrevious: () -> Void
        let onNext: () -> Void

        func makeCoordinator() -> Coordinator {
            Coordinator(onPrevious: onPrevious, onNext: onNext)
        }

        func makeNSView(context: Context) -> RelayView {
            let view = RelayView()
            view.coordinator = context.coordinator
            return view
        }

        func updateNSView(_ nsView: RelayView, context: Context) {
            context.coordinator.onPrevious = onPrevious
            context.coordinator.onNext = onNext
            nsView.coordinator = context.coordinator
        }

        static func dismantleNSView(_ nsView: RelayView, coordinator: Coordinator) {
            coordinator.teardown()
        }

        @MainActor
        final class Coordinator {
            var onPrevious: () -> Void
            var onNext: () -> Void

            private var monitor: Any?
            private weak var observedWindow: NSWindow?
            private var scrollAccumulator: CGFloat = 0

            init(onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
                self.onPrevious = onPrevious
                self.onNext = onNext
            }

            func installMonitorIfNeeded(for window: NSWindow?) {
                guard monitor == nil else { return }
                guard let window else { return }

                observedWindow = window
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .scrollWheel]) {
                    [weak self, weak window] event in
                    guard let self, let window, event.window === window else { return event }
                    return self.handle(event: event) ? nil : event
                }

                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(windowDidResignKey(_:)),
                    name: NSWindow.didResignKeyNotification,
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
                }

                observedWindow = nil
            }

            @objc private func windowDidResignKey(_ notification: Notification) {
                teardown()
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
                default:
                    return false
                }
            }

            private func shouldHandleKey(_ event: NSEvent) -> Bool {
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
                let horizontalMagnitude = abs(event.scrollingDeltaX)
                let verticalMagnitude = abs(event.scrollingDeltaY)

                let primaryDelta: CGFloat
                if horizontalMagnitude > verticalMagnitude {
                    primaryDelta = event.scrollingDeltaX
                } else {
                    primaryDelta = event.scrollingDeltaY
                }

                guard primaryDelta != 0 else { return false }

                let threshold: CGFloat = event.hasPreciseScrollingDeltas ? 40 : 4
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
                didSet { coordinator?.installMonitorIfNeeded(for: window) }
            }

            override func viewDidMoveToWindow() {
                super.viewDidMoveToWindow()
                coordinator?.installMonitorIfNeeded(for: window)
            }
        }
    }
#else
    struct PageNavigationKeyHandler: View {
        var onPrevious: () -> Void
        var onNext: () -> Void

        var body: some View {
            Color.clear
        }
    }
#endif
