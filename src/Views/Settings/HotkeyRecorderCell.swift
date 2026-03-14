#if os(macOS)
    import AppKit
    import SwiftUI

    /// An inline control that lets the user record a new global hotkey by
    /// clicking the button and pressing a key. Pressing Escape cancels recording.
    struct HotkeyRecorderCell: View {
        @Binding var keyCode: Int
        @State private var isRecording = false
        @State private var eventMonitor: Any?

        var body: some View {
            Button {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            } label: {
                Text(isRecording ? "Press a key…" : keyDisplayName(keyCode))
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isRecording ? Color.yellow : Color.white.opacity(0.85))
                    .frame(minWidth: 96, alignment: .center)
            }
            .buttonStyle(.bordered)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isRecording ? Color.yellow.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .accessibilityLabel(
                isRecording
                    ? "Recording global hotkey"
                    : "Global hotkey: \(keyDisplayName(keyCode))"
            )
            .accessibilityHint(
                isRecording
                    ? "Press any key to set it as the new hotkey, or press Escape to cancel"
                    : "Double tap to record a new hotkey"
            )
            .onDisappear { stopRecording() }
        }

        private func startRecording() {
            isRecording = true
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                // Escape cancels without changing the key
                if event.keyCode == 53 {
                    stopRecording()
                    return nil
                }
                keyCode = Int(event.keyCode)
                stopRecording()
                return nil
            }
        }

        private func stopRecording() {
            isRecording = false
            if let monitor = eventMonitor {
                NSEvent.removeMonitor(monitor)
                eventMonitor = nil
            }
        }

        private func keyDisplayName(_ code: Int) -> String {
            let fKeyMap: [Int: String] = [
                122: "F1", 120: "F2", 99: "F3", 118: "F4",
                96: "F5", 97: "F6", 98: "F7", 100: "F8",
                101: "F9", 109: "F10", 103: "F11", 111: "F12",
            ]
            if let name = fKeyMap[code] { return name }

            // Attempt to resolve printable character via CGEvent
            let src = CGEventSource(stateID: .hidSystemState)
            if let cgEvent = CGEvent(
                keyboardEventSource: src, virtualKey: CGKeyCode(code), keyDown: true),
                let nsEvent = NSEvent(cgEvent: cgEvent)
            {
                let chars = nsEvent.charactersIgnoringModifiers?.uppercased() ?? ""
                if !chars.isEmpty { return chars }
            }
            return "Key \(code)"
        }
    }
#endif
