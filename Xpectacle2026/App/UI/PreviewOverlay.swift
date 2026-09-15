import AppKit
import SwiftUI
import XpectacleCore

/// A borderless, click-through window that shows the rectangle a snap zone
/// will produce while the user is still dragging.
@MainActor
final class PreviewOverlay {
    private var window: NSWindow?

    func show(action: WindowAction, on screen: ScreenInfo) {
        let visible = screen.visibleFrame
        guard let frame = PositionCalculator.calculate(
            action: action,
            windowFrame: visible,
            visibleFrame: visible
        ) else { return }
        ensureWindow(on: screen).setFrame(frame, display: true)
        window?.alphaValue = 0.45
        window?.orderFrontRegardless()
    }

    func hide() {
        // An old fade completion could otherwise hide a newly shown zone.
        window?.orderOut(nil)
    }

    private func ensureWindow(on screen: ScreenInfo) -> NSWindow {
        if let w = window { return w }
        let w = NSWindow(
            contentRect: screen.visibleFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        w.isOpaque = false
        w.backgroundColor = .clear
        w.level = .floating
        w.ignoresMouseEvents = true
        w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .stationary]
        w.contentView = NSHostingView(rootView: PreviewShape())
        window = w
        return w
    }
}

private struct PreviewShape: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.accentColor.opacity(0.6))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.8), lineWidth: 2)
            )
            .padding(4)
    }
}
