import CoreGraphics

/// Widths selected by repeated left/right keyboard or menu actions. Drag
/// snapping continues to request a half explicitly through the default.
public enum SideWidth: Sendable, CaseIterable {
    case half, third, twoThirds

    var next: Self {
        switch self {
        case .half: .twoThirds
        case .twoThirds: .third
        case .third: .half
        }
    }

    func points(in availableWidth: CGFloat) -> CGFloat {
        switch self {
        case .half: floor(availableWidth / 2)
        case .third: floor(availableWidth / 3)
        // Use the remainder so opposing 1/3 and 2/3 windows meet exactly,
        // including displays whose usable width is not divisible by three.
        case .twoThirds: availableWidth - floor(availableWidth / 3)
        }
    }
}

/// A successful side action's actual result, retained separately per window.
/// Comparing with the committed AX frame lets cell-grid or minimum-size apps
/// keep cycling, while a manually moved window starts again at one half.
struct SideWidthCycle: Sendable {
    let action: WindowAction
    let width: SideWidth
    let screenID: String
    let visibleFrame: CGRect
    let actualFrame: CGRect

    static func nextWidth(
        after previous: Self?,
        action: WindowAction,
        screenID: String,
        visibleFrame: CGRect,
        currentFrame: CGRect
    ) -> SideWidth {
        guard action == .leftHalf || action == .rightHalf,
              let previous,
              previous.action == action,
              previous.screenID == screenID,
              previous.visibleFrame == visibleFrame,
              approximatelyEqual(previous.actualFrame, currentFrame)
        else { return .half }
        return previous.width.next
    }

    private static func approximatelyEqual(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        guard lhs.isUsableWindowFrame, rhs.isUsableWindowFrame else { return false }
        return abs(lhs.minX - rhs.minX) <= 1
            && abs(lhs.minY - rhs.minY) <= 1
            && abs(lhs.width - rhs.width) <= 1
            && abs(lhs.height - rhs.height) <= 1
    }
}
