import CoreGraphics
import Testing
@testable import XpectacleCore

/// Mirrors Spectacle's 9 calculation specs. Visible frame is 1440×900 at
/// origin (0, 0) for parity with the legacy fixtures.
private let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let win = CGRect(x: 100, y: 100, width: 800, height: 600)

@Test func leftHalf() {
    let r = PositionCalculator.calculate(action: .leftHalf, windowFrame: win, visibleFrame: visible)!
    #expect(r == CGRect(x: 0, y: 0, width: 720, height: 900))
}

@Test func rightHalf() {
    let r = PositionCalculator.calculate(action: .rightHalf, windowFrame: win, visibleFrame: visible)!
    #expect(r == CGRect(x: 720, y: 0, width: 720, height: 900))
}

@Test func topHalf() {
    let r = PositionCalculator.calculate(action: .topHalf, windowFrame: win, visibleFrame: visible)!
    #expect(r == CGRect(x: 0, y: 450, width: 1440, height: 450))
}

@Test func bottomHalf() {
    let r = PositionCalculator.calculate(action: .bottomHalf, windowFrame: win, visibleFrame: visible)!
    #expect(r == CGRect(x: 0, y: 0, width: 1440, height: 450))
}

@Test func upperLeft() {
    let r = PositionCalculator.calculate(action: .upperLeft, windowFrame: win, visibleFrame: visible)!
    #expect(r == CGRect(x: 0, y: 450, width: 720, height: 450))
}

@Test func upperRight() {
    let r = PositionCalculator.calculate(action: .upperRight, windowFrame: win, visibleFrame: visible)!
    #expect(r == CGRect(x: 720, y: 450, width: 720, height: 450))
}

@Test func lowerLeft() {
    let r = PositionCalculator.calculate(action: .lowerLeft, windowFrame: win, visibleFrame: visible)!
    #expect(r == CGRect(x: 0, y: 0, width: 720, height: 450))
}

@Test func lowerRight() {
    let r = PositionCalculator.calculate(action: .lowerRight, windowFrame: win, visibleFrame: visible)!
    #expect(r == CGRect(x: 720, y: 0, width: 720, height: 450))
}

@Test func fullscreen() {
    let r = PositionCalculator.calculate(action: .fullscreen, windowFrame: win, visibleFrame: visible)!
    #expect(r == visible)
}

@Test func centerKeepsSize() {
    let r = PositionCalculator.calculate(action: .center, windowFrame: win, visibleFrame: visible)!
    #expect(r.size == win.size)
    #expect(r.midX == visible.midX)
    #expect(r.midY == visible.midY)
}

@Test func horizontalThirdsCycle() {
    let f = visible
    #expect(PositionCalculator.horizontalThird(visibleFrame: f, slot: .first)
            == CGRect(x: 0, y: 0, width: 480, height: 900))
    #expect(PositionCalculator.horizontalThird(visibleFrame: f, slot: .second)
            == CGRect(x: 480, y: 0, width: 480, height: 900))
    #expect(PositionCalculator.horizontalThird(visibleFrame: f, slot: .third)
            == CGRect(x: 960, y: 0, width: 480, height: 900))
}

@Test(arguments: [
    (WindowAction.largerLeft, CGRect(x: 70, y: 100, width: 830, height: 600)),
    (WindowAction.largerRight, CGRect(x: 100, y: 100, width: 830, height: 600)),
    (WindowAction.smallerLeft, CGRect(x: 130, y: 100, width: 770, height: 600)),
])
func resizeEdges(action: WindowAction, expected: CGRect) {
    let r = PositionCalculator.calculate(action: action, windowFrame: win, visibleFrame: visible)!
    #expect(r == expected)
}
