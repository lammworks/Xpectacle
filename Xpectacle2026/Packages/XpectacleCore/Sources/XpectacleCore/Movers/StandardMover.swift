import CoreGraphics

/// Sets the window's frame in one shot. Equivalent to
/// `SpectacleStandardWindowMover`.
public struct StandardMover: WindowMover {
    public init() {}
    public func move(window: AXWindow, to target: CGRect, primaryHeight: CGFloat) throws {
        try window.setFrameInAppKit(target, primaryHeight: primaryHeight)
    }
}
