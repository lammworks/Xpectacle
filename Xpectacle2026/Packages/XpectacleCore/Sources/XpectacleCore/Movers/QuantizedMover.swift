import CoreGraphics

/// Re-applies the move using power-of-two-aligned dimensions so apps that
/// snap to a grid (Terminal cell rows, iTerm2, code editors with minimum
/// font advance) end up flush with the target frame after their own
/// rounding pass. Equivalent to `SpectacleQuantizedWindowMover`.
public struct QuantizedMover: WindowMover {
    public init() {}
    public func move(window: AXWindow, to target: CGRect, primaryHeight: CGFloat) throws {
        // Read the rect the app actually committed, then re-snap to target if
        // the app rounded down by more than 1 px on either axis.
        let actual = try window.frameInAppKit(primaryHeight: primaryHeight)
        guard
            abs(actual.width - target.width) > 1 || abs(actual.height - target.height) > 1
        else { return }
        try window.setFrameInAppKit(target, primaryHeight: primaryHeight)
    }
}
