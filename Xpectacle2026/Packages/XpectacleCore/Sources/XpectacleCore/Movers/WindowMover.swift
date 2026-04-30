import CoreGraphics
import Foundation

/// Strategy for actually moving a window to a target frame.
///
/// Spectacle layered three movers via the decorator pattern. We model the
/// same chain explicitly with `MoverChain` so the order is obvious and
/// testable without spinning up real AX windows.
public protocol WindowMover: Sendable {
    func move(window: AXWindow, to target: CGRect, primaryHeight: CGFloat) throws
}

/// Composes movers: each mover runs in order, later movers can correct
/// inaccuracies introduced by earlier ones (Terminal-style cell snapping,
/// app-imposed minimum sizes, etc.).
public struct MoverChain: WindowMover {
    public let movers: [any WindowMover]
    public init(_ movers: [any WindowMover]) { self.movers = movers }

    public func move(window: AXWindow, to target: CGRect, primaryHeight: CGFloat) throws {
        for m in movers { try m.move(window: window, to: target, primaryHeight: primaryHeight) }
    }

    /// The default chain that matches Spectacle's behavior.
    public static func standard() -> MoverChain {
        MoverChain([StandardMover(), QuantizedMover(), BestEffortMover()])
    }
}
