import SwiftUI

#if os(macOS)
    import AppKit

    /// NSSearchField subclass that grabs first-responder status as soon as
    /// the view is attached to a window — more reliable than using a `Task`
    /// which can fire before the window is key.
    private final class AutoFocusSearchField: NSSearchField {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window, window.isKeyWindow {
                window.makeFirstResponder(self)
            }
        }
    }

    struct LaunchySearchField: NSViewRepresentable {
        @Binding var text: String

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func makeNSView(context: Context) -> NSSearchField {
            let field = AutoFocusSearchField(string: text)
            field.placeholderString = "Search"
            field.delegate = context.coordinator
            field.sendsSearchStringImmediately = true
            field.sendsWholeSearchString = false
            field.focusRingType = .none
            field.isBordered = true
            field.bezelStyle = .roundedBezel
            field.translatesAutoresizingMaskIntoConstraints = false
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            field.setAccessibilityLabel("Search apps")
            field.setAccessibilityIdentifier("LaunchySearchField")
            return field
        }

        func updateNSView(_ nsView: NSSearchField, context: Context) {
            // Keep the coordinator up-to-date so its text binding writes to the
            // current instance rather than a stale captured copy.
            context.coordinator.parent = self
            if nsView.stringValue != text {
                nsView.stringValue = text
            }
        }

        final class Coordinator: NSObject, NSSearchFieldDelegate {
            var parent: LaunchySearchField

            init(parent: LaunchySearchField) {
                self.parent = parent
            }

            func controlTextDidChange(_ obj: Notification) {
                guard let field = obj.object as? NSSearchField else { return }
                parent.text = field.stringValue
            }
        }
    }
#else
    struct LaunchySearchField: View {
        @Binding var text: String

        var body: some View {
            TextField("Search", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
#endif
