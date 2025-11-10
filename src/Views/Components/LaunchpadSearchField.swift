import SwiftUI

#if os(macOS)
    import AppKit

    struct LaunchpadSearchField: NSViewRepresentable {
        @Binding var text: String

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func makeNSView(context: Context) -> NSSearchField {
            let field = NSSearchField(string: text)
            field.placeholderString = "Search"
            field.delegate = context.coordinator
            field.sendsSearchStringImmediately = true
            field.sendsWholeSearchString = false
            field.focusRingType = .none
            field.isBordered = true
            field.bezelStyle = .roundedBezel
            field.translatesAutoresizingMaskIntoConstraints = false
            field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            return field
        }

        func updateNSView(_ nsView: NSSearchField, context: Context) {
            if nsView.stringValue != text {
                nsView.stringValue = text
            }
        }

        final class Coordinator: NSObject, NSSearchFieldDelegate {
            var parent: LaunchpadSearchField

            init(parent: LaunchpadSearchField) {
                self.parent = parent
            }

            func controlTextDidChange(_ obj: Notification) {
                guard let field = obj.object as? NSSearchField else { return }
                parent.text = field.stringValue
            }
        }
    }
#else
    struct LaunchpadSearchField: View {
        @Binding var text: String

        var body: some View {
            TextField("Search", text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
#endif
