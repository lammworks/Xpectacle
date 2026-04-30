import ApplicationServices
#if canImport(AppKit)
import AppKit
#endif
import Foundation

/// Wraps an `AXUIElement` representing a running application.
public struct AXApplication: @unchecked Sendable {
    public let element: AXUIElement
    public let processIdentifier: pid_t
    public let bundleIdentifier: String?

    #if canImport(AppKit)
    @MainActor
    public static func frontmost() throws -> AXApplication {
        guard let app = NSWorkspace.shared.frontmostApplication else { throw AXFailure.noFrontmostApp }
        return AXApplication(
            element: AXUIElementCreateApplication(app.processIdentifier),
            processIdentifier: app.processIdentifier,
            bundleIdentifier: app.bundleIdentifier
        )
    }
    #endif

    public func focusedWindow() throws -> AXWindow {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &value)
        guard result == .success, let raw = value else { throw AXFailure.noFocusedWindow }
        // CFTypeRef returned here is an AXUIElement; force-cast is the documented pattern.
        let win = raw as! AXUIElement
        return AXWindow(element: win, owner: self)
    }
}
