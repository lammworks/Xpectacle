import CoreGraphics

/// Uses AppKit's visible frame as the system's available workspace.
/// Stage Manager has no supported public API for shelf width or placement.
/// Guessing an inset from undocumented defaults can reserve the wrong edge
/// or leave a permanent gap after operating-system updates.
public struct StageManagerProbe: Sendable {
    public init() {}

    public func adjustedVisibleFrame(_ visible: CGRect) -> CGRect {
        visible
    }
}
