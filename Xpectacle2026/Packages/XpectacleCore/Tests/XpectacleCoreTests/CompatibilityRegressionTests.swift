import ApplicationServices
import CoreGraphics
import Foundation
import Testing
@testable import XpectacleCore

@Test(arguments: [
    CGRect(x: -1200, y: 100, width: 600, height: 500),
    CGRect(x: 100, y: 1200, width: 600, height: 500),
    CGRect(x: 100, y: -900, width: 600, height: 500)
])
func accessibilityCoordinateConversionRoundTripsAcrossDisplays(_ frame: CGRect) {
    let ax = AXWindow.flip(frame, primaryHeight: 900)
    #expect(AXWindow.flip(ax, primaryHeight: 900) == frame)
}

@Test func accessibilityErrorsHaveUserFacingDescriptionsThroughErrorProtocol() {
    let error: any Error = AXFailure.notTrusted
    #expect(error.localizedDescription.contains("Accessibility"))
}

@Test func rejectsUnavailableAndNonFiniteWindowFrames() {
    #expect(!CGRect.null.isUsableWindowFrame)
    #expect(!CGRect.infinite.isUsableWindowFrame)
    #expect(!CGRect.zero.isUsableWindowFrame)
    #expect(!CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1).isUsableWindowFrame)
    #expect(!CGRect(x: 0, y: 0, width: -1, height: 1).isUsableWindowFrame)
    #expect(CGRect(x: -300, y: -100, width: 300, height: 100).isUsableWindowFrame)
}

@Test func axIdentityUsesRemoteElementEquality() {
    let first = AXWindowIdentity(element: AXUIElementCreateApplication(42), processIdentifier: 42)
    let second = AXWindowIdentity(element: AXUIElementCreateApplication(42), processIdentifier: 42)
    let otherProcess = AXWindowIdentity(element: AXUIElementCreateApplication(43), processIdentifier: 43)
    #expect(first == second)
    #expect(Set([first, second, otherProcess]).count == 2)
}

@Test func stageManagerDoesNotApplyAnUndocumentedShelfInset() {
    let visible = CGRect(x: -1920, y: 40, width: 1800, height: 1015)
    #expect(StageManagerProbe().adjustedVisibleFrame(visible) == visible)
}

@Test func importedLayoutDisplayIndicesStayInBounds() {
    let matcher = AppMatcher(bundleID: "com.example.app")
    let rect = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
    #expect(LayoutSlot(matcher: matcher, displayIndex: -1, frame: rect).resolvedDisplayIndex(screenCount: 2) == 0)
    #expect(LayoutSlot(matcher: matcher, displayIndex: 8, frame: rect).resolvedDisplayIndex(screenCount: 2) == 1)
    #expect(LayoutSlot(matcher: matcher, displayIndex: 0, frame: rect).resolvedDisplayIndex(screenCount: 0) == nil)
}

@Test func minimumWindowSizeKeepsTitleBarInsideTarget() {
    let target = CGRect(x: 0, y: 0, width: 600, height: 400)
    let actual = CGRect(x: -100, y: -100, width: 800, height: 600)
    let corrected = BestEffortMover.adjustedFrame(actual: actual, target: target)
    #expect(corrected.minX == target.minX)
    #expect(corrected.maxY == target.maxY)
    #expect(corrected.size == actual.size)
}

@Test func maximumWindowSizeIsCenteredWithinTarget() {
    let target = CGRect(x: 0, y: 0, width: 600, height: 400)
    let actual = CGRect(x: 10, y: 20, width: 300, height: 200)
    let corrected = BestEffortMover.adjustedFrame(actual: actual, target: target)
    #expect(corrected.midX == target.midX)
    #expect(corrected.midY == target.midY)
}

@Test func firstThirdActionStartsAtLeftOrTop() {
    let visible = CGRect(x: 0, y: 0, width: 1200, height: 900)
    let window = CGRect(x: 50, y: 50, width: 300, height: 300)
    #expect(PositionCalculator.calculate(action: .nextThirdHorizontal, windowFrame: window, visibleFrame: visible)
            == CGRect(x: 0, y: 0, width: 400, height: 900))
    #expect(PositionCalculator.calculate(action: .nextThirdVertical, windowFrame: window, visibleFrame: visible)
            == CGRect(x: 0, y: 600, width: 1200, height: 300))
}

@Test func shrinkingSmallWindowKeepsOppositeEdgeFixed() {
    let visible = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    let window = CGRect(x: 50, y: 50, width: 10, height: 10)
    let left = PositionCalculator.calculate(action: .smallerLeft, windowFrame: window, visibleFrame: visible)!
    let bottom = PositionCalculator.calculate(action: .smallerBottom, windowFrame: window, visibleFrame: visible)!
    #expect(left.width == 1)
    #expect(left.maxX == window.maxX)
    #expect(bottom.height == 1)
    #expect(bottom.maxY == window.maxY)
}

@Test func extendingAnOffscreenEdgeDoesNotShrinkWindow() {
    let visible = CGRect(x: 0, y: 0, width: 1000, height: 1000)
    let window = CGRect(x: -50, y: 50, width: 300, height: 300)
    #expect(PositionCalculator.calculate(action: .largerLeft, windowFrame: window, visibleFrame: visible) == window)
}

@Test func calculationsRejectInvalidFrames() {
    #expect(PositionCalculator.calculate(action: .leftHalf, windowFrame: .null, visibleFrame: .zero) == nil)
}

@Test func screenRecoveryChoosesNearestRemainingDisplay() {
    let left = ScreenInfo(id: "left", frame: CGRect(x: 0, y: 0, width: 1000, height: 1000), visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 970))
    let right = ScreenInfo(id: "right", frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000), visibleFrame: CGRect(x: 1000, y: 0, width: 1000, height: 970))
    #expect(ScreenDetector().screen(containing: CGRect(x: 2500, y: 100, width: 100, height: 100), in: [right, left])?.id == "right")
    #expect(ScreenDetector().screen(containing: .null, in: [left, right]) == nil)
}

@Test func verticallyStackedDisplayIsDetectedByLargestIntersection() {
    let lower = ScreenInfo(id: "lower", frame: CGRect(x: 0, y: 0, width: 1000, height: 1000), visibleFrame: CGRect(x: 0, y: 0, width: 1000, height: 970))
    let upper = ScreenInfo(id: "upper", frame: CGRect(x: 0, y: 1000, width: 1000, height: 1000), visibleFrame: CGRect(x: 0, y: 1000, width: 1000, height: 970))
    #expect(ScreenDetector().screen(containing: CGRect(x: 100, y: 950, width: 400, height: 400), in: [lower, upper])?.id == "upper")
}

private enum SimulatedMoveFailure: Error { case refused }
private let frameA = CGRect(x: 0, y: 0, width: 100, height: 100)
private let frameB = CGRect(x: 100, y: 0, width: 100, height: 100)
private let frameC = CGRect(x: 200, y: 0, width: 100, height: 100)

@Test func failedUndoDoesNotAdvanceHistory() {
    var stack = UndoStack()
    stack.record(for: "window", before: frameA, after: frameB)
    do {
        try stack.undo(for: "window") { _ in throw SimulatedMoveFailure.refused }
        Issue.record("Expected simulated move failure")
    } catch {}
    #expect(stack.undo(for: "window") == frameA)
    #expect(stack.undo(for: "window") == nil)
}

@Test func failedRedoDoesNotAdvanceHistory() {
    var stack = UndoStack()
    stack.record(for: "window", before: frameA, after: frameB)
    _ = stack.undo(for: "window")
    do {
        try stack.redo(for: "window") { _ in throw SimulatedMoveFailure.refused }
        Issue.record("Expected simulated move failure")
    } catch {}
    #expect(stack.redo(for: "window") == frameB)
}

@Test func noOpMovePreservesRedo() {
    var stack = UndoStack()
    stack.record(for: "window", before: frameA, after: frameB)
    _ = stack.undo(for: "window")
    stack.record(for: "window", before: frameA, after: frameA)
    #expect(stack.redo(for: "window") == frameB)
}

@Test(arguments: [0, -1])
func zeroOrNegativeHistoryLimitsDisableHistory(_ limit: Int) {
    var stack = UndoStack(limit: limit)
    stack.record(for: "window", before: frameA, after: frameB)
    #expect(stack.undo(for: "window") == nil)
    #expect(stack.redo(for: "window") == nil)
}

@Test func boundedHistoryRetainsNewestTransition() {
    var stack = UndoStack(limit: 1)
    stack.record(for: "window", before: frameA, after: frameB)
    stack.record(for: "window", before: frameB, after: frameC)
    #expect(stack.undo(for: "window") == frameB)
    #expect(stack.undo(for: "window") == nil)
    #expect(stack.redo(for: "window") == frameC)
}

@Test func windowHistoriesAreIndependentAndCanBeEvicted() {
    var stack = UndoStack()
    stack.record(for: "first", before: frameA, after: frameB)
    stack.record(for: "second", before: frameB, after: frameC)
    stack.remove(for: "first")
    #expect(stack.undo(for: "first") == nil)
    #expect(stack.undo(for: "second") == frameB)
}
