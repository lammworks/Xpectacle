import CoreGraphics
import Foundation

/// A normalized rectangle in 0…1 space relative to a screen's visible frame.
/// Storing layouts in normalized space lets them apply unchanged when the
/// user moves between displays of different sizes.
public struct NormalizedRect: Codable, Sendable, Hashable {
    public var x: Double, y: Double, width: Double, height: Double
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x; self.y = y; self.width = width; self.height = height
    }
    public func denormalized(in visible: CGRect) -> CGRect {
        CGRect(
            x: visible.minX + visible.width * x,
            y: visible.minY + visible.height * y,
            width: visible.width * width,
            height: visible.height * height
        ).integral
    }
    public static func from(_ rect: CGRect, in visible: CGRect) -> NormalizedRect {
        guard visible.width > 0, visible.height > 0 else {
            return .init(x: 0, y: 0, width: 1, height: 1)
        }
        return .init(
            x: Double((rect.minX - visible.minX) / visible.width),
            y: Double((rect.minY - visible.minY) / visible.height),
            width: Double(rect.width / visible.width),
            height: Double(rect.height / visible.height)
        )
    }
}

public struct AppMatcher: Codable, Sendable, Hashable {
    /// Bundle identifier (`com.apple.Safari`). Matches case-insensitively.
    public var bundleID: String
    /// Optional regex matched against the window title; nil = any window.
    public var titleRegex: String?
    public init(bundleID: String, titleRegex: String? = nil) {
        self.bundleID = bundleID; self.titleRegex = titleRegex
    }
}

public struct LayoutSlot: Codable, Sendable, Hashable {
    public var matcher: AppMatcher
    public var displayIndex: Int
    public var frame: NormalizedRect
    public init(matcher: AppMatcher, displayIndex: Int, frame: NormalizedRect) {
        self.matcher = matcher; self.displayIndex = displayIndex; self.frame = frame
    }
}

public struct Layout: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var slots: [LayoutSlot]
    /// Optional Focus mode identifier (e.g. `com.apple.donotdisturb.mode.work`)
    /// — when set, the layout auto-applies when that focus engages.
    public var focusModeID: String?

    public init(id: UUID = UUID(), name: String, slots: [LayoutSlot], focusModeID: String? = nil) {
        self.id = id; self.name = name; self.slots = slots; self.focusModeID = focusModeID
    }
}
