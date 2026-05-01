import CoreGraphics

/// When an app refuses to grow beyond its current size (Photo Booth, some
/// games), nudge the window so its center stays aligned with the requested
/// frame's center even if the size is wrong. Equivalent to
/// `SpectacleBestEffortWindowMover`.
public struct BestEffortMover: WindowMover {
    public init() {}
    public func move(window: AXWindow, to target: CGRect, primaryHeight: CGFloat) throws {
        let actual = try window.frameInAppKit(primaryHeight: primaryHeight)
        guard actual.size != target.size else { return }
        let centeredOrigin = CGPoint(
            x: target.midX - actual.width / 2,
            y: target.midY - actual.height / 2
        )
        let recentered = CGRect(origin: centeredOrigin, size: actual.size)
        try window.setFrameInAppKit(recentered, primaryHeight: primaryHeight)
    }
}
