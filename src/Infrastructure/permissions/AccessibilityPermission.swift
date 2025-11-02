import AppKit
@preconcurrency import ApplicationServices

@MainActor
enum AccessibilityPermission {
    private static var hasPrompted = false
  private static var isRunningUnitTests: Bool {
    ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
  }

    static func requestIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        guard !hasPrompted else { return }
        hasPrompted = true
    if isRunningUnitTests {
      return
    }
        let promptKey: String = MainActor.assumeIsolated {
            kAXTrustedCheckOptionPrompt.takeRetainedValue() as String
        }
        let options: CFDictionary = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

  #if DEBUG
    static func resetPromptStateForTesting() {
      hasPrompted = false
    }

    static var hasPromptedForTesting: Bool {
      hasPrompted
    }
  #endif
}
