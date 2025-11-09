import SwiftUI

#if os(macOS)
    import AppKit

    struct PageNavigationKeyHandler: NSViewRepresentable {
        let onPrevious: () -> Void
        let onNext: () -> Void

        func makeCoordinator() -> Coordinator {
            Coordinator(onPrevious: onPrevious, onNext: onNext)
        }

        func makeNSView(context: Context) -> NSView {
            let view = NSView(frame: .zero)
            DispatchQueue.main.async {
                context.coordinator.installMonitor(for: view.window)
            }
            return view
        }

        func updateNSView(_ nsView: NSView, context: Context) {
            context.coordinator.onPrevious = onPrevious
            context.coordinator.onNext = onNext
            DispatchQueue.main.async {
                context.coordinator.installMonitor(for: nsView.window)
            }
        }

        static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
            coordinator.removeMonitor()
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

            func installMonitor(for window: NSWindow?) {
                guard observedWindow !== window else { return }
                removeMonitor()
                observedWindow = window
                monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
                    [weak self, weak window] event in
                    guard let self, let window, event.window === window else { return event }
                    return self.handle(event: event) ? nil : event
                }
            }

            func removeMonitor() {
                if let monitor {
                    NSEvent.removeMonitor(monitor)
                    self.monitor = nil
                }
                observedWindow = nil
            }

            private func handle(event: NSEvent) -> Bool {
                guard shouldHandle(event: event) else { return false }

                switch event.keyCode {
                case 123, 115:  // left arrow, home
                    onPrevious()
                    return true
                case 124, 119:  // right arrow, end
                    onNext()
                    return true
                case 116:  // page up
                    onPrevious()
                    return true
                case 121:  // page down
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
