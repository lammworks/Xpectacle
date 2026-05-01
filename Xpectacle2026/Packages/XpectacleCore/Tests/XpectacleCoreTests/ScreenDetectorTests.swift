import CoreGraphics
import Testing
@testable import XpectacleCore

private let s0 = ScreenInfo(id: "A",
    frame: CGRect(x: 0, y: 0, width: 1440, height: 900),
    visibleFrame: CGRect(x: 0, y: 0, width: 1440, height: 875))
private let s1 = ScreenInfo(id: "B",
    frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1055))
private let detector = ScreenDetector()

@Test func nextDisplayWraps() {
    let r1 = detector.targetScreen(for: .nextDisplay,
                                   windowFrame: CGRect(x: 100, y: 100, width: 200, height: 200),
                                   screens: [s0, s1])
    #expect(r1?.id == "B")
    let r2 = detector.targetScreen(for: .nextDisplay,
                                   windowFrame: CGRect(x: 1500, y: 100, width: 200, height: 200),
                                   screens: [s0, s1])
    #expect(r2?.id == "A")
}

@Test func previousDisplayWraps() {
    let r = detector.targetScreen(for: .previousDisplay,
                                  windowFrame: CGRect(x: 100, y: 100, width: 200, height: 200),
                                  screens: [s0, s1])
    #expect(r?.id == "B")
}

@Test func staysOnCurrentScreenForLocalActions() {
    let r = detector.targetScreen(for: .leftHalf,
                                  windowFrame: CGRect(x: 1500, y: 100, width: 200, height: 200),
                                  screens: [s0, s1])
    #expect(r?.id == "B")
}
