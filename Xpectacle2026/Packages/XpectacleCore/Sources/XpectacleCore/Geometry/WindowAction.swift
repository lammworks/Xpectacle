import Foundation

/// All discrete window manipulations Xpectacle supports.
///
/// Ported from Spectacle's `SpectacleWindowAction` enum but flattened — the
/// repeated cycling cases (e.g. centerProminently, leftThird/centerThird/rightThird)
/// are now associated values so callers don't have to know about cycle order.
public enum WindowAction: Hashable, Sendable, CaseIterable, Codable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case upperLeft, upperRight, lowerLeft, lowerRight
    case fullscreen, center
    case nextThirdHorizontal, nextThirdVertical
    case largerLeft, largerRight, largerTop, largerBottom
    case smallerLeft, smallerRight, smallerTop, smallerBottom
    case nextDisplay, previousDisplay
    case undoLastMove, redoLastMove
    case undoLastMoveAcrossDisplays, redoLastMoveAcrossDisplays

    /// Stable identifier used for storage, App Intents, and the legacy
    /// importer mapping from old `com.divisiblebyzero.Spectacle` defaults keys.
    public var identifier: String {
        switch self {
        case .leftHalf: "MoveToLeftHalf"
        case .rightHalf: "MoveToRightHalf"
        case .topHalf: "MoveToTopHalf"
        case .bottomHalf: "MoveToBottomHalf"
        case .upperLeft: "MoveToUpperLeft"
        case .upperRight: "MoveToUpperRight"
        case .lowerLeft: "MoveToLowerLeft"
        case .lowerRight: "MoveToLowerRight"
        case .fullscreen: "MoveToFullscreen"
        case .center: "MoveToCenter"
        case .nextThirdHorizontal: "MoveToNextThirdHorizontal"
        case .nextThirdVertical: "MoveToNextThirdVertical"
        case .largerLeft: "MakeLargerLeft"
        case .largerRight: "MakeLargerRight"
        case .largerTop: "MakeLargerTop"
        case .largerBottom: "MakeLargerBottom"
        case .smallerLeft: "MakeSmallerLeft"
        case .smallerRight: "MakeSmallerRight"
        case .smallerTop: "MakeSmallerTop"
        case .smallerBottom: "MakeSmallerBottom"
        case .nextDisplay: "MoveToNextDisplay"
        case .previousDisplay: "MoveToPreviousDisplay"
        case .undoLastMove: "UndoLastMove"
        case .redoLastMove: "RedoLastMove"
        case .undoLastMoveAcrossDisplays: "UndoLastMoveAcrossDisplays"
        case .redoLastMoveAcrossDisplays: "RedoLastMoveAcrossDisplays"
        }
    }

    public var localizedTitle: String {
        switch self {
        case .leftHalf: String(localized: "Left Half")
        case .rightHalf: String(localized: "Right Half")
        case .topHalf: String(localized: "Top Half")
        case .bottomHalf: String(localized: "Bottom Half")
        case .upperLeft: String(localized: "Upper Left")
        case .upperRight: String(localized: "Upper Right")
        case .lowerLeft: String(localized: "Lower Left")
        case .lowerRight: String(localized: "Lower Right")
        case .fullscreen: String(localized: "Fullscreen")
        case .center: String(localized: "Center")
        case .nextThirdHorizontal: String(localized: "Next Third (Horizontal)")
        case .nextThirdVertical: String(localized: "Next Third (Vertical)")
        case .largerLeft: String(localized: "Extend Left")
        case .largerRight: String(localized: "Extend Right")
        case .largerTop: String(localized: "Extend Top")
        case .largerBottom: String(localized: "Extend Bottom")
        case .smallerLeft: String(localized: "Shrink Left")
        case .smallerRight: String(localized: "Shrink Right")
        case .smallerTop: String(localized: "Shrink Top")
        case .smallerBottom: String(localized: "Shrink Bottom")
        case .nextDisplay: String(localized: "Next Display")
        case .previousDisplay: String(localized: "Previous Display")
        case .undoLastMove: String(localized: "Undo Last Move")
        case .redoLastMove: String(localized: "Redo Last Move")
        case .undoLastMoveAcrossDisplays: String(localized: "Undo Last Move (All Displays)")
        case .redoLastMoveAcrossDisplays: String(localized: "Redo Last Move (All Displays)")
        }
    }

    public var changesDisplay: Bool {
        self == .nextDisplay || self == .previousDisplay
    }
}
