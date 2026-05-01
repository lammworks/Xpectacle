import CoreGraphics
import Foundation

/// A region of a screen that, when the cursor enters during a window drag,
/// triggers a tiling action on mouse-up. Modeled as a band of pixels along
/// each edge plus four corners.
public struct SnapZone: Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable {
        case left, right, top, bottom
        case upperLeft, upperRight, lowerLeft, lowerRight
        case topThird, middleThird, bottomThird   // for vertical thirds
        case leftThird, centerThird, rightThird   // for horizontal thirds
    }
    public let kind: Kind
    public let action: WindowAction
    public init(kind: Kind, action: WindowAction) { self.kind = kind; self.action = action }

    public static let defaultZones: [SnapZone] = [
        .init(kind: .left, action: .leftHalf),
        .init(kind: .right, action: .rightHalf),
        .init(kind: .top, action: .fullscreen),
        .init(kind: .upperLeft, action: .upperLeft),
        .init(kind: .upperRight, action: .upperRight),
        .init(kind: .lowerLeft, action: .lowerLeft),
        .init(kind: .lowerRight, action: .lowerRight),
    ]
}

public enum SnapHitTester {
    /// Width/height of the activation band along each edge, in points.
    public static let edgeThickness: CGFloat = 8
    /// Side length of corner squares.
    public static let cornerSize: CGFloat = 30

    /// Returns the zone the cursor is currently hovering, if any.
    public static func zone(at point: CGPoint, in frame: CGRect, zones: [SnapZone]) -> SnapZone? {
        guard frame.contains(point) else { return nil }
        let kinds = candidateKinds(for: point, in: frame)
        // Prefer corners over edges if the cursor satisfies both.
        for kind in kinds {
            if let z = zones.first(where: { $0.kind == kind }) { return z }
        }
        return nil
    }

    static func candidateKinds(for point: CGPoint, in frame: CGRect) -> [SnapZone.Kind] {
        let nearLeft = point.x - frame.minX < cornerSize
        let nearRight = frame.maxX - point.x < cornerSize
        let nearTop = frame.maxY - point.y < cornerSize
        let nearBottom = point.y - frame.minY < cornerSize
        var out: [SnapZone.Kind] = []
        if nearLeft && nearTop { out.append(.upperLeft) }
        if nearRight && nearTop { out.append(.upperRight) }
        if nearLeft && nearBottom { out.append(.lowerLeft) }
        if nearRight && nearBottom { out.append(.lowerRight) }
        if point.x - frame.minX < edgeThickness { out.append(.left) }
        if frame.maxX - point.x < edgeThickness { out.append(.right) }
        if frame.maxY - point.y < edgeThickness { out.append(.top) }
        if point.y - frame.minY < edgeThickness { out.append(.bottom) }
        return out
    }
}
