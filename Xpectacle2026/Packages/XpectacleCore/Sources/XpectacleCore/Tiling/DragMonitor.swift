#if canImport(AppKit)
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Watches global mouse-drag events. When the user drags a window into a
/// `SnapZone` and lingers for `activationDelay`, fires `onZoneEnter` (so the
/// app can show a preview overlay). On mouse-up while a zone is active,
/// fires `onCommit` so the app can apply the corresponding `WindowAction`.
@MainActor
public final class DragMonitor {
    public var zones: [SnapZone] = SnapZone.defaultZones
    public var activationDelay: TimeInterval = 0.1

    public var onZoneEnter: ((SnapZone, ScreenInfo) -> Void)?
    public var onZoneExit: (() -> Void)?
    public var onCommit: ((SnapZone, ScreenInfo) -> Void)?

    private var mouseDownMonitor: Any?
    private var mouseUpMonitor: Any?
    private var dragMonitor: Any?
    private var dragging = false
    private var pendingZone: (zone: SnapZone, screen: ScreenInfo)?
    private var hoverTimer: Timer?

    public init() {}

    public func start() {
        guard mouseDownMonitor == nil else { return }
        mouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            self?.dragging = true
        }
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
            self?.handleDrag(at: NSEvent.mouseLocation)
            _ = event
        }
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            self?.handleMouseUp()
        }
    }

    public func stop() {
        [mouseDownMonitor, mouseUpMonitor, dragMonitor].forEach { m in
            if let m { NSEvent.removeMonitor(m) }
        }
        mouseDownMonitor = nil; mouseUpMonitor = nil; dragMonitor = nil
        clearPending()
    }

    private func handleDrag(at point: CGPoint) {
        guard dragging else { return }
        let screens = ScreenInfo.current
        guard let screen = screens.first(where: { $0.frame.contains(point) }) else { clearPending(); return }
        let zone = SnapHitTester.zone(at: point, in: screen.visibleFrame, zones: zones)
        switch (pendingZone, zone) {
        case (nil, let z?):
            pendingZone = (z, screen)
            scheduleEnter()
        case (let cur?, let z?) where cur.zone != z || cur.screen.id != screen.id:
            pendingZone = (z, screen)
            scheduleEnter()
        case (_, nil):
            clearPending()
        default:
            break
        }
    }

    private func scheduleEnter() {
        hoverTimer?.invalidate()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: activationDelay, repeats: false) { [weak self] _ in
            guard let self, let p = self.pendingZone else { return }
            Task { @MainActor in self.onZoneEnter?(p.zone, p.screen) }
        }
    }

    private func handleMouseUp() {
        defer { dragging = false }
        if let p = pendingZone { onCommit?(p.zone, p.screen) }
        clearPending()
    }

    private func clearPending() {
        if pendingZone != nil { onZoneExit?() }
        pendingZone = nil
        hoverTimer?.invalidate(); hoverTimer = nil
    }
}
#endif
