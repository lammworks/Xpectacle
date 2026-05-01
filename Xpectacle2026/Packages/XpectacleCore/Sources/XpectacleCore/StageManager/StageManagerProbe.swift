import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Detects whether Stage Manager is enabled and, if so, returns a usable
/// rect that excludes the stage shelf along the screen's left edge so
/// snapping doesn't place windows underneath it.
///
/// Uses only public APIs: the `com.apple.WindowManager` defaults domain
/// (set by System Settings) and `NSScreen.visibleFrame`. macOS already
/// excludes Stage Manager's strip from `visibleFrame`, but on older Sonoma
/// betas this lagged behind, so we sanity-check by reading the defaults.
public struct StageManagerProbe: Sendable {
    public init() {}

    public var isEnabled: Bool {
        let d = UserDefaults(suiteName: "com.apple.WindowManager") ?? .standard
        return d.bool(forKey: "GloballyEnabled")
    }

    /// True if the stage shelf is configured to auto-hide. When auto-hide is
    /// on, the shelf doesn't reduce `visibleFrame`, so we conservatively
    /// keep snapping clear of the leftmost 64 pt strip.
    public var shelfAutoHidden: Bool {
        let d = UserDefaults(suiteName: "com.apple.WindowManager") ?? .standard
        return d.bool(forKey: "AutoHide")
    }

    /// Adjust a screen's visible frame to be safe for tiling under the
    /// current Stage Manager configuration.
    public func adjustedVisibleFrame(_ visible: CGRect) -> CGRect {
        guard isEnabled, shelfAutoHidden else { return visible }
        let inset: CGFloat = 64
        return CGRect(
            x: visible.minX + inset,
            y: visible.minY,
            width: max(1, visible.width - inset),
            height: visible.height
        )
    }
}
