#if canImport(AppKit)
import AppKit
import ApplicationServices
#endif
import CoreGraphics
import Foundation

/// Captures and applies named `Layout`s.
public actor LayoutEngine {
    public static let shared = LayoutEngine()
    private let mover: any WindowMover
    public init(mover: any WindowMover = MoverChain.standard()) { self.mover = mover }

    #if canImport(AppKit)
    public func apply(_ layout: Layout) async throws {
        try ensureAccessibilityTrusted()
        let (screens, primaryHeight) = await MainActor.run {
            (ScreenInfo.current, NSScreen.screens.first?.frame.height ?? 0)
        }
        guard !screens.isEmpty else { return }

        let runningApps = await MainActor.run { NSWorkspace.shared.runningApplications }

        for slot in layout.slots {
            guard let app = runningApps.first(where: {
                $0.bundleIdentifier?.caseInsensitiveCompare(slot.matcher.bundleID) == .orderedSame
            }) else { continue }
            let axApp = AXApplication(
                element: AXUIElementCreateApplication(app.processIdentifier),
                processIdentifier: app.processIdentifier,
                bundleIdentifier: app.bundleIdentifier
            )
            let windows = (try? axApp.allWindows()) ?? []
            let candidates: [AXWindow]
            if let pattern = slot.matcher.titleRegex,
               let regex = try? NSRegularExpression(pattern: pattern) {
                candidates = windows.filter { w in
                    guard let t = (try? w.title()) ?? nil else { return false }
                    let range = NSRange(t.startIndex..., in: t)
                    return regex.firstMatch(in: t, range: range) != nil
                }
            } else {
                candidates = windows
            }
            guard let target = candidates.first else { continue }

            let display = screens[min(slot.displayIndex, screens.count - 1)]
            let frame = slot.frame.denormalized(in: display.visibleFrame)
            try mover.move(window: target, to: frame, primaryHeight: primaryHeight)
        }
    }

    /// Snapshot all visible windows of running apps into a new `Layout`.
    public func capture(named name: String) async throws -> Layout {
        try ensureAccessibilityTrusted()
        let (screens, primaryHeight) = await MainActor.run {
            (ScreenInfo.current, NSScreen.screens.first?.frame.height ?? 0)
        }
        let runningApps = await MainActor.run {
            NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        }
        var slots: [LayoutSlot] = []
        for app in runningApps {
            guard let bid = app.bundleIdentifier else { continue }
            let axApp = AXApplication(
                element: AXUIElementCreateApplication(app.processIdentifier),
                processIdentifier: app.processIdentifier,
                bundleIdentifier: bid
            )
            for win in (try? axApp.allWindows()) ?? [] {
                guard let frame = try? win.frameInAppKit(primaryHeight: primaryHeight) else { continue }
                guard let display = (ScreenDetector().screen(containing: frame, in: screens)),
                      let displayIndex = screens.firstIndex(where: { $0.id == display.id })
                else { continue }
                let title = (try? win.title()) ?? nil
                let escaped = title.map { NSRegularExpression.escapedPattern(for: $0) }
                slots.append(.init(
                    matcher: AppMatcher(bundleID: bid, titleRegex: escaped),
                    displayIndex: displayIndex,
                    frame: NormalizedRect.from(frame, in: display.visibleFrame)
                ))
            }
        }
        return Layout(name: name, slots: slots)
    }
    #endif
}

extension AXApplication {
    public func allWindows() throws -> [AXWindow] {
        var raw: CFTypeRef?
        let r = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &raw)
        guard r == .success, let arr = raw as? [AXUIElement] else { return [] }
        return arr.map { AXWindow(element: $0, owner: self) }
    }
}

extension AXWindow {
    public func title() throws -> String? {
        var raw: CFTypeRef?
        let r = AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &raw)
        guard r == .success else { return nil }
        return raw as? String
    }
}
