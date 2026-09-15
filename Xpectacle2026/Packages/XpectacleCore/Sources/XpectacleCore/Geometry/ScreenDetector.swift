#if canImport(AppKit)
import AppKit
#endif
import CoreGraphics
import Foundation

/// Determines which screen a window action should target.
///
/// Mirrors `SpectacleScreenDetector`: by default the window stays on its
/// current screen (the one whose `frame` overlaps the window most), but the
/// `nextDisplay` / `previousDisplay` actions advance through the ordered
/// screen list.
public struct ScreenDetector: Sendable {
    public init() {}

    public func targetScreen(for action: WindowAction, windowFrame: CGRect, screens: [ScreenInfo]) -> ScreenInfo? {
        let screens = screens.filter { $0.frame.isUsableWindowFrame && $0.visibleFrame.isUsableWindowFrame }
        guard !screens.isEmpty, windowFrame.isUsableWindowFrame else { return nil }
        let current = screen(containing: windowFrame, in: screens) ?? screens[0]
        guard let idx = screens.firstIndex(where: { $0.id == current.id }) else { return current }

        switch action {
        case .nextDisplay:
            return screens[(idx + 1) % screens.count]
        case .previousDisplay:
            return screens[(idx - 1 + screens.count) % screens.count]
        default:
            return current
        }
    }

    /// Returns the screen with the largest intersection area with `frame`.
    public func screen(containing frame: CGRect, in screens: [ScreenInfo]) -> ScreenInfo? {
        guard frame.isUsableWindowFrame else { return nil }
        let validScreens = screens.filter { $0.frame.isUsableWindowFrame }
        let overlapping = validScreens.max { lhs, rhs in
            lhs.frame.intersection(frame).area < rhs.frame.intersection(frame).area
        }
        if let overlapping, overlapping.frame.intersection(frame).area > 0 { return overlapping }
        // A display can disappear while an application retains its old frame.
        // Recover on the closest remaining screen instead of an arbitrary one.
        return validScreens.min {
            $0.frame.distanceSquared(to: CGPoint(x: frame.midX, y: frame.midY))
                < $1.frame.distanceSquared(to: CGPoint(x: frame.midX, y: frame.midY))
        }
    }
}

/// Plain-data snapshot of an `NSScreen`. Decoupled so the geometry layer is
/// AppKit-free and unit-testable.
public struct ScreenInfo: Hashable, Sendable, Identifiable {
    public let id: String          // CGDirectDisplayID, unique even for identical display models
    public let frame: CGRect       // full frame (AppKit coords)
    public let visibleFrame: CGRect // frame minus menu bar + Dock + Stage Manager strip

    public init(id: String, frame: CGRect, visibleFrame: CGRect) {
        self.id = id
        self.frame = frame
        self.visibleFrame = visibleFrame
    }

    #if canImport(AppKit)
    @MainActor
    public static var current: [ScreenInfo] {
        NSScreen.screens.enumerated().map { idx, s in
            let displayID = (s.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            return ScreenInfo(
                id: displayID.map(String.init) ?? "Display \(idx)",
                frame: s.frame,
                visibleFrame: s.visibleFrame
            )
        }
    }
    #endif
}

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
    func distanceSquared(to point: CGPoint) -> CGFloat {
        let dx = max(minX - point.x, 0, point.x - maxX)
        let dy = max(minY - point.y, 0, point.y - maxY)
        return dx * dx + dy * dy
    }
}
