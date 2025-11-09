import SwiftUI

#if os(macOS)
    import AppKit

    struct DesktopBackdropView: NSViewRepresentable {
        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = .underWindowBackground
            view.blendingMode = .behindWindow
            view.state = .active
            view.isEmphasized = true
            return view
        }

        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
    }
#endif
