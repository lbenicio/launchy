import SwiftUI

#if os(macOS)
    import AppKit

    struct DesktopBackdropView: NSViewRepresentable {
        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = .fullScreenUI
            view.blendingMode = .behindWindow
            view.state = .active
            view.isEmphasized = false
            return view
        }

        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
    }
#endif
