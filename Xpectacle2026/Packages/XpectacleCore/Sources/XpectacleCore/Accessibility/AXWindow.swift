import ApplicationServices
import CoreGraphics
import Foundation

/// Swift wrapper around an `AXUIElement` representing a window. Replaces
/// `SpectacleAccessibilityElement`. All getters/setters bridge through
/// `AXValue` and convert between Accessibility coordinates (origin = top-left
/// of the primary display) and AppKit coordinates (origin = bottom-left).
public struct AXWindow: @unchecked Sendable {
    public let element: AXUIElement
    public let owner: AXApplication

    /// Frame in **AppKit** coordinates. Geometry code uses this exclusively.
    public func frameInAppKit(primaryHeight: CGFloat) throws -> CGRect {
        let rect = try axFrame()
        return Self.flip(rect, primaryHeight: primaryHeight)
    }

    public func setFrameInAppKit(_ frame: CGRect, primaryHeight: CGFloat) throws {
        try setAXFrame(Self.flip(frame, primaryHeight: primaryHeight))
    }

    /// Whether the window will accept resize/move requests.
    public func isMovableAndResizable() -> Bool {
        var movable: CFTypeRef?, resizable: CFTypeRef?
        AXUIElementCopyAttributeValue(element, "AXMovable" as CFString, &movable)
        AXUIElementCopyAttributeValue(element, "AXResizable" as CFString, &resizable)
        let m = (movable as? Bool) ?? true
        let r = (resizable as? Bool) ?? true
        return m && r
    }

    // MARK: - Private AX I/O

    private func axFrame() throws -> CGRect {
        var position = CGPoint.zero
        var size = CGSize.zero
        try readAXValue(attribute: kAXPositionAttribute, type: .cgPoint, into: &position)
        try readAXValue(attribute: kAXSizeAttribute, type: .cgSize, into: &size)
        return CGRect(origin: position, size: size)
    }

    private func setAXFrame(_ rect: CGRect) throws {
        var pos = rect.origin, size = rect.size
        let posValue = AXValueCreate(.cgPoint, &pos)!
        let sizeValue = AXValueCreate(.cgSize, &size)!
        // Order matters: set size first then position so that windows that resize
        // around their top-left don't overshoot the screen during the transition.
        let r1 = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        let r2 = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
        let r3 = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        for r in [r1, r2, r3] where r != .success { throw AXFailure.underlying(r) }
    }

    private func readAXValue<T>(attribute: String, type: AXValueType, into out: inout T) throws {
        var raw: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &raw)
        guard result == .success, let raw else { throw AXFailure.attributeUnavailable(attribute) }
        let axVal = raw as! AXValue
        let ok = withUnsafeMutablePointer(to: &out) { AXValueGetValue(axVal, type, $0) }
        guard ok else { throw AXFailure.attributeUnavailable(attribute) }
    }

    /// AX uses top-left origin globally; AppKit uses bottom-left. Flipping
    /// requires the **primary display height**.
    static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.size.height,
            width: rect.size.width,
            height: rect.size.height
        )
    }
}
