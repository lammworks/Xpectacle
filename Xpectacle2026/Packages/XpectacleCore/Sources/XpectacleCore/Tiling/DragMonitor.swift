#if canImport(AppKit)
import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Only an actual move of the window captured at mouse-down can activate a
/// snap zone. Dragging text, files, sliders or resize handles must not snap.
@MainActor
public final class DragMonitor {
    public var zones: [SnapZone] = SnapZone.defaultZones
    public var activationDelay: TimeInterval = 0.1
    public var disabledBundleIDs: Set<String> = []

    public var onZoneEnter: ((SnapZone, ScreenInfo) -> Void)?
    public var onZoneExit: (() -> Void)?
    public var onCommit: ((SnapZone, ScreenInfo, AXWindow) -> Void)?

    private var monitors: [Any] = []
    private var draggedWindow: AXWindow?
    private var initialFrame: CGRect?
    private var pendingZone: (zone: SnapZone, screen: ScreenInfo)?
    private var zoneIsActive = false
    private var hoverTimer: Timer?

    public init() {}

    public func start() {
        guard monitors.isEmpty, Permissions.isAccessibilityTrusted else { return }
        // AppKit delivers event monitor callbacks on the main thread. Avoid
        // asynchronous hops that could reorder mouse-down/drag/up observations.
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMouseDown(at: NSEvent.mouseLocation) }
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.handleDrag(at: NSEvent.mouseLocation) }
        }) { monitors.append(monitor) }
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp, handler: { [weak self] _ in
            MainActor.assumeIsolated { self?.handleMouseUp() }
        }) { monitors.append(monitor) }
        if monitors.count != 3 { stop() }
    }

    public func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        resetDrag()
    }

    private func handleMouseDown(at point: CGPoint) {
        resetDrag()
        guard Permissions.isAccessibilityTrusted,
              let window = window(at: point),
              !disabledBundleIDs.contains(window.owner.bundleIdentifier?.lowercased() ?? ""),
              window.isMovableAndResizable(),
              let height = NSScreen.screens.first?.frame.height,
              let frame = try? window.frameInAppKit(primaryHeight: height) else { return }
        draggedWindow = window
        initialFrame = frame
    }

    private func handleDrag(at point: CGPoint) {
        guard isMovingCapturedWindow() else { clearPending(); return }
        guard let screen = ScreenInfo.current.first(where: { $0.frame.contains(point) }),
              let zone = SnapHitTester.zone(at: point, in: screen.frame, zones: zones) else {
            clearPending()
            return
        }
        if let pendingZone, pendingZone.zone == zone, pendingZone.screen.id == screen.id { return }
        clearPending()
        pendingZone = (zone, screen)
        if activationDelay <= 0 {
            activatePendingZone()
        } else {
            let timer = Timer(timeInterval: activationDelay, repeats: false) { [weak self] _ in
                MainActor.assumeIsolated { self?.activatePendingZone() }
            }
            hoverTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func activatePendingZone() {
        guard NSEvent.pressedMouseButtons & 1 != 0,
              isMovingCapturedWindow(), let pendingZone,
              pendingZone.screen.frame.contains(NSEvent.mouseLocation),
              SnapHitTester.zone(at: NSEvent.mouseLocation, in: pendingZone.screen.frame, zones: zones) == pendingZone.zone
        else { clearPending(); return }
        zoneIsActive = true
        onZoneEnter?(pendingZone.zone, pendingZone.screen)
    }

    private func handleMouseUp() {
        // Releasing before the delay expires never commits a snap. Use the
        // captured window, even if app focus changed during the drag.
        if zoneIsActive, isMovingCapturedWindow(), let pendingZone, let draggedWindow,
           SnapHitTester.zone(at: NSEvent.mouseLocation, in: pendingZone.screen.frame, zones: zones) == pendingZone.zone {
            onCommit?(pendingZone.zone, pendingZone.screen, draggedWindow)
        }
        resetDrag()
    }

    private func isMovingCapturedWindow() -> Bool {
        guard Permissions.isAccessibilityTrusted, let draggedWindow, let initialFrame,
              !disabledBundleIDs.contains(draggedWindow.owner.bundleIdentifier?.lowercased() ?? ""),
              let height = NSScreen.screens.first?.frame.height,
              let current = try? draggedWindow.frameInAppKit(primaryHeight: height) else { return false }
        return WindowDragEvidence.isWindowMove(initial: initialFrame, current: current)
    }

    private func resetDrag() {
        clearPending()
        draggedWindow = nil
        initialFrame = nil
    }

    private func clearPending() {
        if zoneIsActive { onZoneExit?() }
        pendingZone = nil
        zoneIsActive = false
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    /// Resolve the window under the original pointer, rather than assuming the
    /// previously focused application owns the window being dragged.
    private func window(at point: CGPoint) -> AXWindow? {
        guard let height = NSScreen.screens.first?.frame.height else { return nil }
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.1)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(system, Float(point.x), Float(height - point.y), &hit) == .success,
              var element = hit else { return nil }
        for _ in 0..<16 {
            AXUIElementSetMessagingTimeout(element, 0.1)
            var role: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
            if role as? String == kAXWindowRole {
                var pid: pid_t = 0
                guard AXUIElementGetPid(element, &pid) == .success,
                      pid != ProcessInfo.processInfo.processIdentifier else { return nil }
                let owner = AXApplication(
                    element: AXUIElementCreateApplication(pid),
                    processIdentifier: pid,
                    bundleIdentifier: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
                )
                AXUIElementSetMessagingTimeout(element, 0.1)
                return AXWindow(element: element, owner: owner)
            }
            var parent: CFTypeRef?
            // Most controls expose their enclosing window directly. Fall back
            // to walking parents for custom title bars and application chrome.
            let windowResult = AXUIElementCopyAttributeValue(element, kAXWindowAttribute as CFString, &parent)
            if windowResult != .success || parent == nil {
                AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &parent)
            }
            guard let parent, CFGetTypeID(parent) == AXUIElementGetTypeID() else { return nil }
            let next = parent as! AXUIElement
            guard !CFEqual(next, element) else { return nil }
            element = next
        }
        return nil
    }
}

/// Pure drag evidence used by the monitor and regression tests.
enum WindowDragEvidence {
    static func isWindowMove(initial: CGRect, current: CGRect) -> Bool {
        guard initial.width > 0, initial.height > 0,
              initial.width.isFinite, initial.height.isFinite,
              initial.origin.x.isFinite, initial.origin.y.isFinite,
              current.width.isFinite, current.height.isFinite,
              current.origin.x.isFinite, current.origin.y.isFinite else { return false }
        let moved = abs(current.minX - initial.minX) > 1 || abs(current.minY - initial.minY) > 1
        let sameSize = abs(current.width - initial.width) <= 1 && abs(current.height - initial.height) <= 1
        return moved && sameSize
    }
}
#endif
