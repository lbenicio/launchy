import AppKit
@preconcurrency import ApplicationServices

@MainActor
enum AccessibilityPermission {
    private static var hasPrompted = false

    static func requestIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        guard !hasPrompted else { return }
        hasPrompted = true
        let promptKey: String = MainActor.assumeIsolated {
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        }
        let options: CFDictionary = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
}
