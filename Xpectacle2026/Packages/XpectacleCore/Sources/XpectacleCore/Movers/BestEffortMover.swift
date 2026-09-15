import CoreGraphics

/// Reposition windows constrained by the application's minimum or maximum
/// size. Keep the title bar reachable when the window exceeds the target.
public struct BestEffortMover: WindowMover {
    public init() {}
    public func move(window: AXWindow, to target: CGRect, primaryHeight: CGFloat) throws {
        let actual = try window.frameInAppKit(primaryHeight: primaryHeight)
        guard actual.size != target.size else { return }
        let recentered = Self.adjustedFrame(actual: actual, target: target)
        try window.setFrameInAppKit(recentered, primaryHeight: primaryHeight)
    }

    static func adjustedFrame(actual: CGRect, target: CGRect) -> CGRect {
        CGRect(
            x: actual.width > target.width ? target.minX : target.midX - actual.width / 2,
            y: actual.height > target.height ? target.maxY - actual.height : target.midY - actual.height / 2,
            width: actual.width,
            height: actual.height
        )
    }
}
