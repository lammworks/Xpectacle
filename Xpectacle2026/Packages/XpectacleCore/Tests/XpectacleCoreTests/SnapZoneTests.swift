import CoreGraphics
import Testing
@testable import XpectacleCore

private let frame = CGRect(x: 0, y: 0, width: 1000, height: 800)
private let zones = SnapZone.defaultZones

@Test func leftEdgeHits() {
    let z = SnapHitTester.zone(at: CGPoint(x: 2, y: 400), in: frame, zones: zones)
    #expect(z?.kind == .left)
}

@Test func upperLeftCornerPreferredOverEdge() {
    let z = SnapHitTester.zone(at: CGPoint(x: 5, y: 795), in: frame, zones: zones)
    #expect(z?.kind == .upperLeft)
}

@Test func centerOfScreenHasNoZone() {
    let z = SnapHitTester.zone(at: CGPoint(x: 500, y: 400), in: frame, zones: zones)
    #expect(z == nil)
}

@Test func outsideFrameReturnsNil() {
    let z = SnapHitTester.zone(at: CGPoint(x: -5, y: 400), in: frame, zones: zones)
    #expect(z == nil)
}
