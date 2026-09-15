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
        guard primaryHeight.isFinite, primaryHeight > 0 else { throw AXFailure.invalidFrame }
        return Self.flip(rect, primaryHeight: primaryHeight)
    }

    public func setFrameInAppKit(_ frame: CGRect, primaryHeight: CGFloat) throws {
        guard frame.isUsableWindowFrame, primaryHeight.isFinite, primaryHeight > 0
        else { throw AXFailure.invalidFrame }
        try setAXFrame(Self.flip(frame, primaryHeight: primaryHeight))
    }

    /// Whether the window will accept resize/move requests.
    public func isMovableAndResizable() -> Bool {
        var movable = DarwinBoolean(false)
        var resizable = DarwinBoolean(false)
        let moveResult = AXUIElementIsAttributeSettable(element, kAXPositionAttribute as CFString, &movable)
        let resizeResult = AXUIElementIsAttributeSettable(element, kAXSizeAttribute as CFString, &resizable)
        return moveResult == .success && resizeResult == .success && movable.boolValue && resizable.boolValue
    }

    // MARK: - Private AX I/O

    private func axFrame() throws -> CGRect {
        var position = CGPoint.zero
        var size = CGSize.zero
        try readAXValue(attribute: kAXPositionAttribute, type: .cgPoint, into: &position)
        try readAXValue(attribute: kAXSizeAttribute, type: .cgSize, into: &size)
        let frame = CGRect(origin: position, size: size)
        guard frame.isUsableWindowFrame else { throw AXFailure.invalidFrame }
        return frame
    }

    private func setAXFrame(_ rect: CGRect) throws {
        var pos = rect.origin, size = rect.size
        guard let posValue = AXValueCreate(.cgPoint, &pos),
              let sizeValue = AXValueCreate(.cgSize, &size)
        else { throw AXFailure.invalidFrame }
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
        guard result == .success, let raw, CFGetTypeID(raw) == AXValueGetTypeID()
        else { throw AXFailure.attributeUnavailable(attribute) }
        let axVal = raw as! AXValue
        guard AXValueGetType(axVal) == type else { throw AXFailure.attributeUnavailable(attribute) }
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

extension CGRect {
    var isUsableWindowFrame: Bool {
        !isNull && !isInfinite && origin.x.isFinite && origin.y.isFinite
            && size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0
    }
}

/// Accessibility equality identifies the remote window, including when AX
/// returns a new wrapper. Titles change and are shared by unrelated windows.
struct AXWindowIdentity: Hashable, @unchecked Sendable {
    let element: AXUIElement
    let processIdentifier: pid_t

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.processIdentifier == rhs.processIdentifier && CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(processIdentifier)
        hasher.combine(CFHash(element))
    }
}
