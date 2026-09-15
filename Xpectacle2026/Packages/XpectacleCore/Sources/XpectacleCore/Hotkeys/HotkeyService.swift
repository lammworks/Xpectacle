import AppKit
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
            let name = KeyboardShortcuts.Name.forAction(action)
            KeyboardShortcuts.removeHandler(for: name)
            KeyboardShortcuts.enable(name)
            KeyboardShortcuts.onKeyDown(for: name) { perform(action) }
        }
    }

    public func unregisterAll() {
        guard registered else { return }
        for action in WindowAction.allCases {
            KeyboardShortcuts.disable(.forAction(action))
            KeyboardShortcuts.removeHandler(for: .forAction(action))
        }
        registered = false
    }

    /// Bootstrap once before registration. The marker remains even if the
    /// user never changes settings, so later launches preserve cleared keys.
    public func importLegacyShortcutsIfNeeded() {
        let defaults = UserDefaults.standard
        let marker = "Xpectacle.shortcutMigrationCompleted.v1"
        guard !defaults.bool(forKey: marker) else { return }
        defer { defaults.set(true, forKey: marker) }
        // An existing rewrite installation may have intentionally cleared its
        // shortcuts. Do not replace those choices with old Spectacle settings.
        guard !FileManager.default.fileExists(atPath: SettingsStore.defaultURL.path) else { return }
        let imported = LegacyImporter.importIfPresent()
        for action in WindowAction.allCases {
            let name = KeyboardShortcuts.Name.forAction(action)
            guard KeyboardShortcuts.getShortcut(for: name) == nil else { continue }
            if let legacy = imported[action] {
                guard !legacy.isCleared else { continue }
                let key = KeyboardShortcuts.Key(rawValue: legacy.keyCode)
                KeyboardShortcuts.setShortcut(.init(key, modifiers: .init(rawValue: legacy.modifierFlags)), for: name)
            } else if let binding = Self.defaultBindings[action],
                      let shortcut = LegacyImporter.decode(binding: binding) {
                let key = KeyboardShortcuts.Key(rawValue: shortcut.keyCode)
                KeyboardShortcuts.setShortcut(.init(key, modifiers: .init(rawValue: shortcut.modifierFlags)), for: name)
            }
        }
    }

    private static let defaultBindings: [WindowAction: String] = [
        .center: "alt+cmd+c", .fullscreen: "alt+cmd+f",
        .leftHalf: "alt+cmd+left", .rightHalf: "alt+cmd+right",
        .topHalf: "alt+cmd+up", .bottomHalf: "alt+cmd+down",
        .upperLeft: "ctrl+cmd+left", .upperRight: "ctrl+cmd+right",
        .lowerLeft: "ctrl+shift+cmd+left", .lowerRight: "ctrl+shift+cmd+right",
        .nextDisplay: "ctrl+alt+cmd+right", .previousDisplay: "ctrl+alt+cmd+left",
        .nextThirdHorizontal: "ctrl+alt+right",
        .undoLastMove: "alt+cmd+z", .redoLastMove: "alt+shift+cmd+z"
    ]
}
