#if canImport(AppKit)
import AppKit
#endif
import CoreGraphics
import Foundation

/// Serializes all Accessibility I/O. AX is not thread-safe and on Sonoma+
/// has surprising retry semantics around space/Stage Manager transitions —
/// funneling everything through one actor avoids both classes of race.
public actor WindowController {
    /// Process-wide controller used by App Intents, the menu bar, and hotkeys.
    public static let shared = WindowController()

    private let mover: any WindowMover
    private let detector: ScreenDetector
    private let stageManager: StageManagerProbe
    private var thirds = ThirdsCycler.State()
    private var history = UndoStack()
    /// Bundle IDs that should bypass all window actions. Mirrors
    /// `Settings.disabledBundleIDs`; the App tier pushes updates via
    /// `setDisabledBundleIDs(_:)` so the actor doesn't read settings on the hot path.
    private var disabledBundleIDs: Set<String> = []

    public init(
        mover: any WindowMover = MoverChain.standard(),
        detector: ScreenDetector = ScreenDetector(),
        stageManager: StageManagerProbe = StageManagerProbe()
    ) {
        self.mover = mover
        self.detector = detector
        self.stageManager = stageManager
    }

    public func setDisabledBundleIDs(_ ids: [String]) {
        disabledBundleIDs = Set(ids.map { $0.lowercased() })
    }

    /// Run an action against the frontmost window.
    public func perform(_ action: WindowAction) async throws {
        try ensureAccessibilityTrusted()

        let (window, screens, primaryHeight, currentFrame) = try await readContext()
        if let bid = window.owner.bundleIdentifier?.lowercased(),
           disabledBundleIDs.contains(bid) { return }

        // Undo / redo short-circuit before any geometry math.
        switch action {
        case .undoLastMove:
            if let prev = history.undo(for: window.identityKey) {
                try mover.move(window: window, to: prev, primaryHeight: primaryHeight)
            }
            return
        case .redoLastMove:
            if let next = history.redo(for: window.identityKey) {
                try mover.move(window: window, to: next, primaryHeight: primaryHeight)
            }
            return
        default:
            break
        }

        guard let target = detector.targetScreen(for: action, windowFrame: currentFrame, screens: screens)
        else { return }

        // Stage Manager: when the shelf is auto-hidden, NSScreen.visibleFrame
        // doesn't account for it, so we conservatively shrink the usable rect.
        let visible = stageManager.adjustedVisibleFrame(target.visibleFrame)
        let newFrame: CGRect
        if action.changesDisplay {
            newFrame = scaled(currentFrame, fromVisible: detector.screen(containing: currentFrame, in: screens)?.visibleFrame ?? visible, toVisible: visible)
        } else if let calc = PositionCalculator.calculate(
            action: action,
            windowFrame: currentFrame,
            visibleFrame: visible,
            thirdsState: thirds
        ) {
            newFrame = calc
        } else {
            return
        }

        history.record(for: window.identityKey, before: currentFrame, after: newFrame)
        try mover.move(window: window, to: newFrame, primaryHeight: primaryHeight)

        // Update thirds cycle bookkeeping.
        switch action {
        case .nextThirdHorizontal: thirds.horizontal = thirds.nextHorizontal
        case .nextThirdVertical: thirds.vertical = thirds.nextVertical
        default: break
        }
    }

    private func readContext() async throws -> (AXWindow, [ScreenInfo], CGFloat, CGRect) {
        try await MainActor.run {
            let app = try AXApplication.frontmost()
            let window = try app.focusedWindow()
            let screens = ScreenInfo.current
            let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
            let frame = try window.frameInAppKit(primaryHeight: primaryHeight)
            return (window, screens, primaryHeight, frame)
        }
    }

    /// When moving across displays, scale the window proportionally to the
    /// destination's visible frame.
    private func scaled(_ frame: CGRect, fromVisible from: CGRect, toVisible to: CGRect) -> CGRect {
        guard from.width > 0, from.height > 0 else { return frame }
        let sx = to.width / from.width
        let sy = to.height / from.height
        return CGRect(
            x: to.minX + (frame.minX - from.minX) * sx,
            y: to.minY + (frame.minY - from.minY) * sy,
            width: frame.width * sx,
            height: frame.height * sy
        ).integral
    }
}

extension AXWindow {
    /// Stable enough key to bucket undo history per-window. AX doesn't expose
    /// a window UUID, so we combine pid + title hash. Good enough for undo.
    var identityKey: String {
        var titleRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleRef)
        let title = (titleRef as? String) ?? ""
        return "\(owner.processIdentifier):\(title)"
    }
}
