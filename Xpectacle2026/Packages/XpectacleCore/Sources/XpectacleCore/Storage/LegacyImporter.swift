import Foundation

/// Reads the original `com.divisiblebyzero.Spectacle` defaults domain (and
/// the legacy `Shortcuts.json` if present) and produces a `[WindowAction:
/// LegacyShortcut]` map suitable for handing to `KeyboardShortcuts`.
///
/// Run-once on first launch. The check is the absence of the new settings
/// file; we don't write a separate "imported" marker.
public enum LegacyImporter {
    public struct LegacyShortcut: Sendable, Equatable {
        public let keyCode: Int
        public let modifierFlags: UInt
    }

    public static func importIfPresent(
        defaults: UserDefaults = .init(suiteName: "com.divisiblebyzero.Spectacle") ?? .standard,
        jsonURL: URL? = legacyJSONURL
    ) -> [WindowAction: LegacyShortcut] {
        var out: [WindowAction: LegacyShortcut] = [:]
        for action in WindowAction.allCases {
            // Old key format: "MoveToLeftHalf" → archived NSData of SpectacleShortcut.
            if let data = defaults.data(forKey: action.identifier),
               let shortcut = decode(legacyData: data) {
                out[action] = shortcut
            }
        }
        // JSON file overrides defaults if present (matches Spectacle's own
        // migrating storage precedence).
        if let url = jsonURL,
           let data = try? Data(contentsOf: url),
           let raw = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
            for (key, value) in raw {
                guard let action = WindowAction.allCases.first(where: { $0.identifier == key }),
                      let keyCode = value["keyCode"] as? Int,
                      let mods = value["modifiers"] as? UInt
                else { continue }
                out[action] = LegacyShortcut(keyCode: keyCode, modifierFlags: mods)
            }
        }
        return out
    }

    public static var legacyJSONURL: URL? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return appSupport?.appendingPathComponent("Spectacle/Shortcuts.json")
    }

    /// Spectacle archived `SpectacleShortcut` via `NSKeyedArchiver`. We
    /// decode just the two fields we care about — keyCode and modifierFlags.
    private static func decode(legacyData data: Data) -> LegacyShortcut? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.requiresSecureCoding = false
        let keyCode = unarchiver.decodeInteger(forKey: "shortcutCode")
        let mods = UInt(bitPattern: unarchiver.decodeInteger(forKey: "shortcutModifiers"))
        guard keyCode != 0 else { return nil }
        return LegacyShortcut(keyCode: keyCode, modifierFlags: mods)
    }
}
