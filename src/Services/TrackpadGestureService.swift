import Foundation

#if os(macOS)
    import AppKit
    import CoreGraphics

    /// Listens for four-finger pinch-in gestures on the trackpad to toggle Launchy,
    /// matching real Launchpad's activation gesture.
    ///
    /// Uses `NSEvent.addGlobalMonitorForEvents` to detect magnification (pinch) gestures.
    /// A rapid pinch-in (negative magnification crossing a threshold) triggers the toggle callback.
    @MainActor
    final class TrackpadGestureService {
        static let shared = TrackpadGestureService()

        /// Called on the main thread when a qualifying pinch-in gesture is detected.
        var onPinchIn: (() -> Void)?

        /// Called on the main thread when a qualifying pinch-out (spread) gesture is detected.
        /// Real Launchpad opens on pinch-out; use this to show the launcher.
        var onPinchOut: (() -> Void)?

        /// The magnification delta threshold that must be crossed in a single
        /// gesture to count as a "pinch in". Negative values = pinch in.
        var threshold: CGFloat = -0.4

        /// The magnification delta threshold for a pinch-out (spread) gesture.
        /// Positive values = spread/zoom out.
        var outThreshold: CGFloat = 0.4

        /// Whether the service is currently listening.
        private(set) var isRunning: Bool = false

        private var globalMonitor: Any?
        private var localMonitor: Any?
        private var accumulatedMagnification: CGFloat = 0
        private var gestureActive: Bool = false

        private init() {}

        /// Starts listening for trackpad pinch gestures.
        func start() {
            guard !isRunning else { return }
            isRunning = true

            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .magnify) {
                [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleMagnification(event)
                }
            }

            localMonitor = NSEvent.addLocalMonitorForEvents(matching: .magnify) {
                [weak self] event in
                Task { @MainActor [weak self] in
                    self?.handleMagnification(event)
                }
                return event
            }
        }

        /// Stops listening for trackpad pinch gestures.
        func stop() {
            if let monitor = globalMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let monitor = localMonitor {
                NSEvent.removeMonitor(monitor)
            }
            globalMonitor = nil
            localMonitor = nil
            isRunning = false
            resetState()
        }

        private func handleMagnification(_ event: NSEvent) {
            switch event.phase {
            case .began:
                accumulatedMagnification = 0
                gestureActive = true
            case .changed:
                guard gestureActive else { return }
                accumulatedMagnification += event.magnification
            case .ended, .cancelled:
                guard gestureActive else { return }
                if accumulatedMagnification <= threshold {
                    onPinchIn?()
                } else if accumulatedMagnification >= outThreshold {
                    onPinchOut?()
                }
                resetState()
            default:
                break
            }
        }

        private func resetState() {
            accumulatedMagnification = 0
            gestureActive = false
        }
    }
#endif
