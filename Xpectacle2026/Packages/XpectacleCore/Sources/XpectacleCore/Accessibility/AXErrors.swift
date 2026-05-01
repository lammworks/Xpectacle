import ApplicationServices
import Foundation

public enum AXFailure: Error, Sendable {
    case notTrusted
    case noFrontmostApp
    case noFocusedWindow
    case attributeUnavailable(String)
    case underlying(AXError)

    public var localizedDescription: String {
        switch self {
        case .notTrusted: "Xpectacle is not a trusted Accessibility client. Grant access in System Settings → Privacy & Security → Accessibility."
        case .noFrontmostApp: "No frontmost application."
        case .noFocusedWindow: "Frontmost application has no focused window."
        case .attributeUnavailable(let attr): "AX attribute unavailable: \(attr)"
        case .underlying(let err): "AXError(\(err.rawValue))"
        }
    }
}

public func ensureAccessibilityTrusted(prompt: Bool = false) throws {
    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
    if !AXIsProcessTrustedWithOptions(opts) { throw AXFailure.notTrusted }
}
