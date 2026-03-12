import Foundation

#if os(macOS)
    import AppKit
    import CoreGraphics

    /// Registers a system-wide hotkey (default: F4) to toggle Launchy's visibility,
    /// matching real Launchpad's activation behavior.
    ///
    /// Uses a `CGEvent` tap to intercept key-down events globally. Requires
    /// Accessibility permissions (System Settings → Privacy & Security → Accessibility).
    @MainActor
    final class GlobalHotkeyService {
        static let shared = GlobalHotkeyService()

        /// Stored in a box so the C callback can read it without actor isolation.
        fileprivate let state = HotkeyState()

        /// The virtual key code to listen for. Default is 118 (F4), matching real Launchpad.
        var keyCode: CGKeyCode {
            get { state.keyCode }
            set { state.keyCode = newValue }
        }

        /// Called on the main thread when the hotkey is pressed.
        var onToggle: (() -> Void)? {
            get { state.onToggle }
            set { state.onToggle = newValue }
        }

        private init() {}

        /// Starts listening for the global hotkey. Call once at app launch.
        func start() {
            guard state.eventTap == nil else { return }

            let refcon = Unmanaged.passUnretained(state).toOpaque()

            let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

            guard
                let tap = CGEvent.tapCreate(
                    tap: .cgSessionEventTap,
                    place: .headInsertEventTap,
                    options: .defaultTap,
                    eventsOfInterest: mask,
                    callback: globalHotkeyCallback,
                    userInfo: refcon
                )
            else {
                print(
                    "Launchy: Could not create event tap — Accessibility permission may be required."
                )
                return
            }

            state.eventTap = tap
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            state.runLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        /// Stops listening for the global hotkey.
        func stop() {
            if let tap = state.eventTap {
                CGEvent.tapEnable(tap: tap, enable: false)
                if let source = state.runLoopSource {
                    CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
                }
            }
            state.eventTap = nil
            state.runLoopSource = nil
        }
    }

    /// Shared mutable state accessed by both the `@MainActor` service and
    /// the nonisolated C callback. Marked `nonisolated(unsafe)` / `@unchecked Sendable`
    /// because all mutations happen on the main thread in practice — the C callback
    /// only reads `keyCode` and `eventTap`.
    private final class HotkeyState: @unchecked Sendable {
        nonisolated(unsafe) var eventTap: CFMachPort?
        nonisolated(unsafe) var runLoopSource: CFRunLoopSource?
        nonisolated(unsafe) var keyCode: CGKeyCode = 118  // F4
        nonisolated(unsafe) var onToggle: (() -> Void)?
    }

    /// C-function callback for the CGEvent tap.
    private func globalHotkeyCallback(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        userInfo: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        // Re-enable the tap if it gets disabled by the system (e.g. due to timeout)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let userInfo {
                let state = Unmanaged<HotkeyState>.fromOpaque(userInfo)
                    .takeUnretainedValue()
                if let tap = state.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .keyDown, let userInfo else {
            return Unmanaged.passRetained(event)
        }

        let state = Unmanaged<HotkeyState>.fromOpaque(userInfo).takeUnretainedValue()
        let pressedKey = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if pressedKey == state.keyCode {
            // Swallow the event and fire the toggle on the main thread
            let callback = state.onToggle
            DispatchQueue.main.async {
                callback?()
            }
            return nil  // consume the event
        }

        return Unmanaged.passRetained(event)
    }
#endif
