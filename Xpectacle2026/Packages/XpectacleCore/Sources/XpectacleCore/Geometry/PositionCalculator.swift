import CoreGraphics
import Foundation

/// Pure-function port of `SpectacleWindowPositionCalculator`.
///
/// All math operates in **AppKit screen coordinates** (origin in lower-left,
/// y grows up). Callers convert to/from Accessibility coordinates (origin in
/// upper-left of the primary display) at the boundary — see `AXWindow`.
public enum PositionCalculator {

    /// Given the window's current frame, the target action, and the visible
    /// frame of the destination screen, return the desired new frame.
    ///
    /// Returns `nil` when the action is purely cycle-state-dependent and the
    /// caller must consult `ThirdsCycler`/`UndoStack` instead.
    public static func calculate(
        action: WindowAction,
        windowFrame: CGRect,
        visibleFrame: CGRect,
        thirdsState: ThirdsCycler.State = .init()
    ) -> CGRect? {
        switch action {
        case .leftHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY,
                          width: floor(visibleFrame.width / 2), height: visibleFrame.height)
        case .rightHalf:
            let w = floor(visibleFrame.width / 2)
            return CGRect(x: visibleFrame.minX + visibleFrame.width - w, y: visibleFrame.minY,
                          width: w, height: visibleFrame.height)
        case .topHalf:
            let h = floor(visibleFrame.height / 2)
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY + visibleFrame.height - h,
                          width: visibleFrame.width, height: h)
        case .bottomHalf:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY,
                          width: visibleFrame.width, height: floor(visibleFrame.height / 2))
        case .upperLeft:
            let w = floor(visibleFrame.width / 2)
            let h = floor(visibleFrame.height / 2)
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY + visibleFrame.height - h,
                          width: w, height: h)
        case .upperRight:
            let w = floor(visibleFrame.width / 2)
            let h = floor(visibleFrame.height / 2)
            return CGRect(x: visibleFrame.minX + visibleFrame.width - w,
                          y: visibleFrame.minY + visibleFrame.height - h,
                          width: w, height: h)
        case .lowerLeft:
            return CGRect(x: visibleFrame.minX, y: visibleFrame.minY,
                          width: floor(visibleFrame.width / 2),
                          height: floor(visibleFrame.height / 2))
        case .lowerRight:
            let w = floor(visibleFrame.width / 2)
            let h = floor(visibleFrame.height / 2)
            return CGRect(x: visibleFrame.minX + visibleFrame.width - w, y: visibleFrame.minY,
                          width: w, height: h)
        case .fullscreen:
            return visibleFrame
        case .center:
            return CGRect(
                x: visibleFrame.minX + (visibleFrame.width - windowFrame.width) / 2,
                y: visibleFrame.minY + (visibleFrame.height - windowFrame.height) / 2,
                width: windowFrame.width,
                height: windowFrame.height
            ).integral
        case .nextThirdHorizontal:
            return horizontalThird(visibleFrame: visibleFrame, slot: thirdsState.nextHorizontal)
        case .nextThirdVertical:
            return verticalThird(visibleFrame: visibleFrame, slot: thirdsState.nextVertical)
        case .largerLeft:
            return resize(windowFrame, edge: .minX, by: +sizingStep, in: visibleFrame)
        case .largerRight:
            return resize(windowFrame, edge: .maxX, by: +sizingStep, in: visibleFrame)
        case .largerTop:
            return resize(windowFrame, edge: .maxY, by: +sizingStep, in: visibleFrame)
        case .largerBottom:
            return resize(windowFrame, edge: .minY, by: +sizingStep, in: visibleFrame)
        case .smallerLeft:
            return resize(windowFrame, edge: .minX, by: -sizingStep, in: visibleFrame)
        case .smallerRight:
            return resize(windowFrame, edge: .maxX, by: -sizingStep, in: visibleFrame)
        case .smallerTop:
            return resize(windowFrame, edge: .maxY, by: -sizingStep, in: visibleFrame)
        case .smallerBottom:
            return resize(windowFrame, edge: .minY, by: -sizingStep, in: visibleFrame)
        case .nextDisplay, .previousDisplay,
             .undoLastMove, .redoLastMove,
             .undoLastMoveAcrossDisplays, .redoLastMoveAcrossDisplays:
            return nil
        }
    }

    /// Pixel step used by extend/shrink edge actions, matches Spectacle's 30 px.
    public static let sizingStep: CGFloat = 30

    // MARK: - Thirds

    public static func horizontalThird(visibleFrame f: CGRect, slot: ThirdSlot) -> CGRect {
        let w = floor(f.width / 3)
        let x: CGFloat = switch slot {
        case .first:  f.minX
        case .second: f.minX + w
        case .third:  f.minX + f.width - w
        }
        return CGRect(x: x, y: f.minY, width: w, height: f.height)
    }

    public static func verticalThird(visibleFrame f: CGRect, slot: ThirdSlot) -> CGRect {
        let h = floor(f.height / 3)
        let y: CGFloat = switch slot {
        case .first:  f.minY + f.height - h     // top
        case .second: f.minY + h                 // middle
        case .third:  f.minY                     // bottom
        }
        return CGRect(x: f.minX, y: y, width: f.width, height: h)
    }

    // MARK: - Resize

    private enum Edge { case minX, maxX, minY, maxY }

    private static func resize(_ frame: CGRect, edge: Edge, by delta: CGFloat, in bounds: CGRect) -> CGRect {
        var f = frame
        switch edge {
        case .minX:
            // Extending left: x decreases, width grows. Shrinking: opposite.
            let dx = min(delta, f.minX - bounds.minX)
            f.origin.x -= dx; f.size.width += dx
        case .maxX:
            let dx = min(delta, bounds.maxX - f.maxX)
            f.size.width += dx
        case .minY:
            let dy = min(delta, f.minY - bounds.minY)
            f.origin.y -= dy; f.size.height += dy
        case .maxY:
            let dy = min(delta, bounds.maxY - f.maxY)
            f.size.height += dy
        }
        // Clamp minimum size so we never produce negative dimensions when shrinking.
        f.size.width = max(f.size.width, 1)
        f.size.height = max(f.size.height, 1)
        return f.integral
    }
}

public enum ThirdSlot: Int, Sendable, Codable { case first = 0, second = 1, third = 2 }

/// Tracks where a window currently sits among the three thirds slots so the
/// next press of the same hotkey advances to the next slot — matches Spectacle's
/// behavior where Cmd+Opt+Ctrl+Left cycles left → center → right → left.
public struct ThirdsCycler: Sendable {
    public struct State: Sendable, Equatable {
        public var horizontal: ThirdSlot = .first
        public var vertical: ThirdSlot = .first
        public init() {}
        public var nextHorizontal: ThirdSlot { advance(horizontal) }
        public var nextVertical: ThirdSlot { advance(vertical) }
        private func advance(_ s: ThirdSlot) -> ThirdSlot {
            ThirdSlot(rawValue: (s.rawValue + 1) % 3)!
        }
    }
}
