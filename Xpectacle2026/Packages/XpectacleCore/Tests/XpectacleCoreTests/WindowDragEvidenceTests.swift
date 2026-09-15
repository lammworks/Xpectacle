import CoreGraphics
import XCTest
@testable import XpectacleCore

final class WindowDragEvidenceTests: XCTestCase {
    private let initial = CGRect(x: 100, y: 200, width: 800, height: 600)

    func testDraggingContentDoesNotCountAsMovingWindow() {
        XCTAssertFalse(WindowDragEvidence.isWindowMove(initial: initial, current: initial))
    }

    func testMovingWindowAcrossDisplayCoordinatesCounts() {
        let moved = CGRect(x: -900, y: 1000, width: 800, height: 600)
        XCTAssertTrue(WindowDragEvidence.isWindowMove(initial: initial, current: moved))
    }

    func testResizeFromTopLeftMustNotSnap() {
        let resized = CGRect(x: 80, y: 180, width: 820, height: 620)
        XCTAssertFalse(WindowDragEvidence.isWindowMove(initial: initial, current: resized))
    }

    func testSubpointRoundingDoesNotCountAsMoving() {
        let noise = CGRect(x: 100.5, y: 199.5, width: 800, height: 600)
        XCTAssertFalse(WindowDragEvidence.isWindowMove(initial: initial, current: noise))
    }

    func testNonFiniteGeometryCannotTriggerSnapping() {
        let invalid = CGRect(x: CGFloat.infinity, y: 200, width: 800, height: 600)
        XCTAssertFalse(WindowDragEvidence.isWindowMove(initial: initial, current: invalid))
    }
}
