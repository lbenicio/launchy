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

            init(onPrevious: @escaping () -> Void, onNext: @escaping () -> Void) {
                self.onPrevious = onPrevious
                self.onNext = onNext
            }

            func installMonitorIfNeeded(for window: NSWindow?) {
                guard monitor == nil else { return }
                guard let window else { return }

                observedWindow = window
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
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
                guard shouldHandle(event: event) else { return false }

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

            private func shouldHandle(event: NSEvent) -> Bool {
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
