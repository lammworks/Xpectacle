import CoreGraphics
import Testing
@testable import XpectacleCore

private let ultrawide = CGRect(x: -3440, y: 40, width: 3440, height: 1400)
private let initialWindow = CGRect(x: -3000, y: 100, width: 900, height: 700)

@Test(arguments: [WindowAction.leftHalf, .rightHalf])
func repeatedSideActionCyclesHalfTwoThirdsThirdThenHalf(_ action: WindowAction) throws {
    var previous: SideWidthCycle?
    var current = initialWindow
    for (expectedWidth, expectedPoints) in [
        (SideWidth.half, CGFloat(1720)), (.twoThirds, 2294), (.third, 1146), (.half, 1720)
    ] {
        let width = SideWidthCycle.nextWidth(
            after: previous, action: action, screenID: "ultrawide",
            visibleFrame: ultrawide, currentFrame: current
        )
        #expect(width == expectedWidth)
        let target = try #require(PositionCalculator.calculate(
            action: action, windowFrame: current, visibleFrame: ultrawide, sideWidth: width
        ))
        #expect(target.width == expectedPoints)
        #expect(target.height == ultrawide.height)
        #expect(target.minY == ultrawide.minY)
        #expect(ultrawide.contains(target))
        if action == .leftHalf { #expect(target.minX == ultrawide.minX) }
        else { #expect(target.maxX == ultrawide.maxX) }
        previous = SideWidthCycle(
            action: action, width: width, screenID: "ultrawide",
            visibleFrame: ultrawide, actualFrame: target
        )
        current = target
    }
}

@Test(arguments: [CGFloat(3440), 3441, 3442, 1720.5])
func opposingThirdAndTwoThirdWindowsMeetWithoutGapOrOverlap(_ screenWidth: CGFloat) throws {
    let bounds = CGRect(x: -screenWidth, y: -900, width: screenWidth, height: 877)
    for leftWidth in [SideWidth.third, .twoThirds] {
        let rightWidth: SideWidth = leftWidth == .third ? .twoThirds : .third
        let left = try #require(PositionCalculator.calculate(
            action: .leftHalf, windowFrame: initialWindow, visibleFrame: bounds, sideWidth: leftWidth
        ))
        let right = try #require(PositionCalculator.calculate(
            action: .rightHalf, windowFrame: initialWindow, visibleFrame: bounds, sideWidth: rightWidth
        ))
        #expect(left.maxX == right.minX)
        #expect(left.union(right) == bounds)
        #expect(bounds.contains(left))
        #expect(bounds.contains(right))
    }
}

private func cycle(
    action: WindowAction = .leftHalf,
    width: SideWidth = .half,
    actualFrame: CGRect = CGRect(x: -3440, y: 40, width: 1720, height: 1400)
) -> SideWidthCycle {
    SideWidthCycle(
        action: action, width: width, screenID: "ultrawide",
        visibleFrame: ultrawide, actualFrame: actualFrame
    )
}

@Test func changedSideRestartsAtHalf() {
    let previous = cycle(width: .third)
    #expect(SideWidthCycle.nextWidth(
        after: previous, action: .rightHalf, screenID: "ultrawide",
        visibleFrame: ultrawide, currentFrame: previous.actualFrame
    ) == .half)
}

@Test func changedDisplayEvenWithIdenticalBoundsRestartsAtHalf() {
    let previous = cycle()
    #expect(SideWidthCycle.nextWidth(
        after: previous, action: .leftHalf, screenID: "replacement-display",
        visibleFrame: ultrawide, currentFrame: previous.actualFrame
    ) == .half)
}

@Test func changedVisibleBoundsRestartsAtHalf() {
    let previous = cycle()
    let dockChangedBounds = CGRect(x: -3440, y: 90, width: 3440, height: 1350)
    #expect(SideWidthCycle.nextWidth(
        after: previous, action: .leftHalf, screenID: "ultrawide",
        visibleFrame: dockChangedBounds, currentFrame: previous.actualFrame
    ) == .half)
}

@Test(arguments: [
    CGRect(x: -3430, y: 40, width: 1720, height: 1400),
    CGRect(x: -3440, y: 50, width: 1720, height: 1400),
    CGRect(x: -3440, y: 40, width: 1700, height: 1400),
    CGRect(x: -3440, y: 40, width: 1720, height: 1300)
])
func manuallyMovedOrResizedWindowRestartsAtHalf(_ current: CGRect) {
    #expect(SideWidthCycle.nextWidth(
        after: cycle(), action: .leftHalf, screenID: "ultrawide",
        visibleFrame: ultrawide, currentFrame: current
    ) == .half)
}

@Test func onePointAccessibilityRoundingStillAdvances() {
    #expect(SideWidthCycle.nextWidth(
        after: cycle(), action: .leftHalf, screenID: "ultrawide",
        visibleFrame: ultrawide,
        currentFrame: CGRect(x: -3439, y: 39, width: 1719, height: 1401)
    ) == .twoThirds)
}

@Test func appConstrainedThirdCanAdvanceToHalf() {
    // The application cannot shrink below half; its actual frame stays at
    // 1720 points even after a successful request to move to one third.
    let constrained = cycle(width: .third)
    #expect(SideWidthCycle.nextWidth(
        after: constrained, action: .leftHalf, screenID: "ultrawide",
        visibleFrame: ultrawide, currentFrame: constrained.actualFrame
    ) == .half)
}

@Test func appQuantizedFrameStillAdvancesFromActualResult() {
    let quantized = cycle(actualFrame: CGRect(x: -3435, y: 43, width: 1710, height: 1394))
    #expect(SideWidthCycle.nextWidth(
        after: quantized, action: .leftHalf, screenID: "ultrawide",
        visibleFrame: ultrawide, currentFrame: quantized.actualFrame
    ) == .twoThirds)
}

@Test func aNewOrResetWindowStartsAtHalfEvenIfAlreadyAtHalf() {
    #expect(SideWidthCycle.nextWidth(
        after: nil, action: .leftHalf, screenID: "ultrawide",
        visibleFrame: ultrawide, currentFrame: cycle().actualFrame
    ) == .half)
}

@Test func independentWindowCyclesDoNotShareProgress() {
    let first = cycle(width: .third)
    let second = cycle(width: .half)
    #expect(SideWidthCycle.nextWidth(
        after: first, action: .leftHalf, screenID: "ultrawide",
        visibleFrame: ultrawide, currentFrame: first.actualFrame
    ) == .half)
    #expect(SideWidthCycle.nextWidth(
        after: second, action: .leftHalf, screenID: "ultrawide",
        visibleFrame: ultrawide, currentFrame: second.actualFrame
    ) == .twoThirds)
}

@Test(arguments: [WindowAction.leftHalf, .rightHalf])
func unqualifiedGeometryKeepsDragAndPreviewAtHalf(_ action: WindowAction) throws {
    let alreadySnapped = try #require(PositionCalculator.calculate(
        action: action, windowFrame: initialWindow, visibleFrame: ultrawide
    ))
    #expect(PositionCalculator.calculate(
        action: action, windowFrame: alreadySnapped, visibleFrame: ultrawide
    ) == alreadySnapped)
}

@Test(arguments: [
    CGSize(width: 721, height: 601),
    CGSize(width: 720.25, height: 600.75)
])
func centeringKeepsOddAndFractionalWindowSizes(_ size: CGSize) throws {
    let centered = try #require(PositionCalculator.calculate(
        action: .center, windowFrame: CGRect(origin: .zero, size: size), visibleFrame: ultrawide
    ))
    #expect(centered.size == size)
    #expect(centered.midX == ultrawide.midX)
    #expect(centered.midY == ultrawide.midY)
}

@Test(arguments: [WindowAction.leftHalf, .rightHalf])
func minimumWidthLargerThanThirdStaysInsideTheIntendedSide(_ action: WindowAction) throws {
    let target = try #require(PositionCalculator.calculate(
        action: action, windowFrame: initialWindow, visibleFrame: ultrawide, sideWidth: .third
    ))
    let constrained = CGRect(x: target.minX, y: target.minY, width: 1500, height: target.height)
    let anchored = PositionCalculator.reanchoredSideFrame(
        actual: constrained, target: target, visibleFrame: ultrawide, action: action
    )
    #expect(anchored.size == constrained.size)
    #expect(ultrawide.contains(anchored))
    if action == .leftHalf { #expect(anchored.minX == ultrawide.minX) }
    else { #expect(anchored.maxX == ultrawide.maxX) }
}

@Test func minimumWidthLargerThanScreenKeepsLeftControlsReachable() throws {
    let target = try #require(PositionCalculator.calculate(
        action: .rightHalf, windowFrame: initialWindow, visibleFrame: ultrawide, sideWidth: .third
    ))
    let constrained = CGRect(x: target.minX, y: target.minY, width: 4000, height: target.height)
    let anchored = PositionCalculator.reanchoredSideFrame(
        actual: constrained, target: target, visibleFrame: ultrawide, action: .rightHalf
    )
    #expect(anchored.minX == ultrawide.minX)
    #expect(anchored.size == constrained.size)
}

@Test func unconstrainedSideAndNonSideFramesAreNotReanchored() throws {
    let target = try #require(PositionCalculator.calculate(
        action: .rightHalf, windowFrame: initialWindow, visibleFrame: ultrawide, sideWidth: .third
    ))
    #expect(PositionCalculator.reanchoredSideFrame(
        actual: target, target: target, visibleFrame: ultrawide, action: .rightHalf
    ) == target)
    #expect(PositionCalculator.reanchoredSideFrame(
        actual: initialWindow, target: target, visibleFrame: ultrawide, action: .center
    ) == initialWindow)
}
