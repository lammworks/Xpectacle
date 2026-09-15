#if canImport(AppKit)
import AppKit
#endif
import CoreGraphics
import Foundation

/// Serializes window actions and their history updates. Screen and frontmost
/// application snapshots are read on the main actor before Accessibility I/O.
public actor WindowController {
    public static let shared = WindowController()

    private let mover: any WindowMover
    private let detector: ScreenDetector
    private let stageManager: StageManagerProbe
    private var thirdsByWindow: [String: ThirdsCycler.State] = [:]
    private var history = UndoStack()
    private var disabledBundleIDs: Set<String> = []
    private var windowKeys: [AXWindowIdentity: (key: String, lastAccess: Int)] = [:]
    private var accessCounter = 0

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

    public func perform(_ action: WindowAction) async throws {
        try await perform(action, capturedWindow: nil, targetScreenID: nil)
    }

    /// Drag snapping must act on the captured dragged window and hovered
    /// display, even if focus changes between mouse-down and mouse-up.
    public func perform(_ action: WindowAction, on window: AXWindow, targetScreenID: String? = nil) async throws {
        try await perform(action, capturedWindow: window, targetScreenID: targetScreenID)
    }

    private func perform(_ action: WindowAction, capturedWindow: AXWindow?, targetScreenID: String?) async throws {
        try ensureAccessibilityTrusted()
        let (window, screens, primaryHeight) = try await readContext(window: capturedWindow)
        if let bid = window.owner.bundleIdentifier?.lowercased(), disabledBundleIDs.contains(bid) { return }
        guard window.isMovableAndResizable() else { throw AXFailure.windowNotMovable }
        // Read the frame after the final suspension point so rapidly queued
        // hotkeys observe the preceding move instead of a stale snapshot.
        let currentFrame = try window.frameInAppKit(primaryHeight: primaryHeight)
        let key = historyKey(for: window)
        let mover = self.mover

        switch action {
        case .undoLastMove, .undoLastMoveAcrossDisplays:
            try history.undo(for: key) { frame in
                try mover.move(window: window, to: frame, primaryHeight: primaryHeight)
            }
            return
        case .redoLastMove, .redoLastMoveAcrossDisplays:
            try history.redo(for: key) { frame in
                try mover.move(window: window, to: frame, primaryHeight: primaryHeight)
            }
            return
        default:
            break
        }

        let target: ScreenInfo?
        if let targetScreenID {
            // A disconnected display must not silently redirect a drag.
            target = screens.first { $0.id == targetScreenID }
        } else {
            target = detector.targetScreen(for: action, windowFrame: currentFrame, screens: screens)
        }
        guard let target else { return }
        let visible = stageManager.adjustedVisibleFrame(target.visibleFrame)
        var thirds = thirdsByWindow[key, default: .init()]
        let newFrame: CGRect
        if action.changesDisplay {
            newFrame = scaled(currentFrame, fromVisible: detector.screen(containing: currentFrame, in: screens)?.visibleFrame ?? visible, toVisible: visible)
        } else if let calc = PositionCalculator.calculate(
            action: action, windowFrame: currentFrame, visibleFrame: visible, thirdsState: thirds
        ) {
            newFrame = calc
        } else {
            return
        }
        guard newFrame.isUsableWindowFrame else { throw AXFailure.invalidFrame }
        if newFrame != currentFrame {
            try mover.move(window: window, to: newFrame, primaryHeight: primaryHeight)
            // Applications can impose minimum sizes or round to a text-cell grid.
            // Redo must restore the actual result, and a failed move must not
            // destroy the existing redo tail.
            let actualFrame = try window.frameInAppKit(primaryHeight: primaryHeight)
            history.record(for: key, before: currentFrame, after: actualFrame)
            guard actualFrame != currentFrame else { return }
        }

        switch action {
        case .nextThirdHorizontal: thirds.horizontal = thirds.nextHorizontal
        case .nextThirdVertical: thirds.vertical = thirds.nextVertical
        default: break
        }
        thirdsByWindow[key] = thirds
    }

    private func readContext(window: AXWindow?) async throws -> (AXWindow, [ScreenInfo], CGFloat) {
        try await MainActor.run {
            let targetWindow: AXWindow
            if let window {
                targetWindow = window
            } else {
                targetWindow = try AXApplication.frontmost().focusedWindow()
            }
            let screens = ScreenInfo.current
            guard let primaryHeight = NSScreen.screens.first?.frame.height, primaryHeight > 0
            else { throw AXFailure.invalidFrame }
            return (targetWindow, screens, primaryHeight)
        }
    }

    private func historyKey(for window: AXWindow) -> String {
        let identity = AXWindowIdentity(element: window.element, processIdentifier: window.owner.processIdentifier)
        accessCounter += 1
        if let entry = windowKeys[identity] {
            windowKeys[identity] = (entry.key, accessCounter)
            return entry.key
        }
        // Bound retained remote AX references and history in a long-running app.
        if windowKeys.count >= 128, let oldest = windowKeys.min(by: { $0.value.lastAccess < $1.value.lastAccess }) {
            windowKeys.removeValue(forKey: oldest.key)
            history.remove(for: oldest.value.key)
            thirdsByWindow.removeValue(forKey: oldest.value.key)
        }
        let key = UUID().uuidString
        windowKeys[identity] = (key, accessCounter)
        return key
    }

    private func scaled(_ frame: CGRect, fromVisible from: CGRect, toVisible to: CGRect) -> CGRect {
        guard from.isUsableWindowFrame, to.isUsableWindowFrame else { return frame }
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
