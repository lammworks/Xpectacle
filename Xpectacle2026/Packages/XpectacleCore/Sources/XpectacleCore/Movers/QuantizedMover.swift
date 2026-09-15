import CoreGraphics

/// Retries the requested frame once when an application rounds the initial
/// resize to a text-cell grid. The best-effort stage then positions any
/// remaining size difference without an unbounded resize loop.
public struct QuantizedMover: WindowMover {
    public init() {}
    public func move(window: AXWindow, to target: CGRect, primaryHeight: CGFloat) throws {
        // Read the rect the app actually committed, then re-snap to target if
        // the app rounded by more than 1 point on either axis.
        let actual = try window.frameInAppKit(primaryHeight: primaryHeight)
        guard
            abs(actual.width - target.width) > 1 || abs(actual.height - target.height) > 1
        else { return }
        try window.setFrameInAppKit(target, primaryHeight: primaryHeight)
    }
}
