import ApplicationServices
#if canImport(AppKit)
import AppKit
#endif
import Foundation

@MainActor
public enum Permissions {
    public static var isAccessibilityTrusted: Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    public static func promptForAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    public static func openAccessibilitySettings() {
        #if canImport(AppKit)
        // Ensure macOS knows this executable requested access before opening
        // the list. Trust changes asynchronously; the app observes it later.
        promptForAccessibility()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            if !NSWorkspace.shared.open(url) {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
            }
        }
        #endif
    }
}
