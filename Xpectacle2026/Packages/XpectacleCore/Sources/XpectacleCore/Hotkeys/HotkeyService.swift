import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    public static func forAction(_ action: WindowAction) -> KeyboardShortcuts.Name {
        .init("Xpectacle.\(action.identifier)")
    }
}

/// Registers a global hotkey for every `WindowAction`.
@MainActor
public final class HotkeyService {
    public static let shared = HotkeyService()
    private var registered = false

    public func registerAll(perform: @escaping @MainActor (WindowAction) -> Void) {
        guard !registered else { return }
        registered = true
        for action in WindowAction.allCases {
            KeyboardShortcuts.onKeyDown(for: .forAction(action)) { perform(action) }
        }
    }

    public func unregisterAll() {
        for action in WindowAction.allCases {
            KeyboardShortcuts.disable(.forAction(action))
        }
        registered = false
    }
}
