import CoreGraphics
import Testing
@testable import XpectacleCore

private let visible = CGRect(x: 0, y: 0, width: 1000, height: 800)

@Test func roundTrip() {
    let frame = CGRect(x: 250, y: 200, width: 500, height: 400)
    let n = NormalizedRect.from(frame, in: visible)
    #expect(n.x == 0.25)
    #expect(n.width == 0.5)
    #expect(n.denormalized(in: visible) == frame)
}

@Test func appliesAcrossDifferentDisplay() {
    let frame = CGRect(x: 0, y: 0, width: 500, height: 400)
    let n = NormalizedRect.from(frame, in: visible)
    let bigger = CGRect(x: 100, y: 100, width: 2000, height: 1600)
    #expect(n.denormalized(in: bigger) == CGRect(x: 100, y: 100, width: 1000, height: 800))
}
