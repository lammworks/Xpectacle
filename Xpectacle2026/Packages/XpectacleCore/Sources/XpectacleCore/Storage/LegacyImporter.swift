import AppKit
import Carbon
import Foundation

/// Imports Spectacle's real archive and JSON formats. Returned modifier flags
/// are Cocoa flags, even though Spectacle stored Carbon flags in its archives.
public enum LegacyImporter {
    public struct LegacyShortcut: Sendable, Equatable {
        public let keyCode: Int
        public let modifierFlags: UInt
        public var isCleared: Bool { keyCode < 0 }
    }

    public static func importIfPresent(
        defaults: UserDefaults = .init(suiteName: "com.divisiblebyzero.Spectacle") ?? .standard,
        jsonURL: URL? = legacyJSONURL
    ) -> [WindowAction: LegacyShortcut] {
        var result: [WindowAction: LegacyShortcut] = [:]
        for (identifier, action) in actionNames {
            if let data = defaults.data(forKey: identifier), let shortcut = decode(legacyData: data) {
                result[action] = shortcut
            }
        }
        guard let jsonURL, let data = try? Data(contentsOf: jsonURL),
              let json = try? JSONSerialization.jsonObject(with: data) else { return result }
        // Since Spectacle 1.x this is an array of name/binding pairs, not a
        // dictionary of numeric key codes. Explicit null means user-disabled.
        if let rows = json as? [[String: Any]] {
            for row in rows {
                guard let name = row["shortcut_name"] as? String, let action = actionNames[name] else { continue }
                if row["shortcut_key_binding"] is NSNull {
                    result[action] = .init(keyCode: -1, modifierFlags: 0)
                } else if let binding = row["shortcut_key_binding"] as? String,
                          let shortcut = decode(binding: binding) {
                    result[action] = shortcut
                }
            }
        }
        return result
    }

    public static var legacyJSONURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Spectacle/Shortcuts.json")
    }

    private static var actionNames: [String: WindowAction] {
        var names = Dictionary(uniqueKeysWithValues: WindowAction.allCases.map { ($0.identifier, $0) })
        names["MoveToNextThird"] = .nextThirdHorizontal
        return names
    }

    static func decode(binding: String) -> LegacyShortcut? {
        let parts = binding.uppercased().split(separator: "+", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let key = parts.last, let keyCode = keyCodes[key] else { return nil }
        var flags: NSEvent.ModifierFlags = []
        for part in parts.dropLast() {
            switch part {
            case "CMD", "COMMAND": flags.insert(.command)
            case "ALT", "OPTION": flags.insert(.option)
            case "CTRL", "CONTROL": flags.insert(.control)
            case "SHIFT": flags.insert(.shift)
            default: return nil
            }
        }
        return .init(keyCode: keyCode, modifierFlags: flags.rawValue)
    }

    private static func decode(legacyData data: Data) -> LegacyShortcut? {
        guard let unarchiver = try? NSKeyedUnarchiver(forReadingFrom: data) else { return nil }
        unarchiver.decodingFailurePolicy = .setErrorAndReturn
        unarchiver.requiresSecureCoding = true
        for name in ["SpectacleShortcut", "SpectacleHotKey", "ZeroKitHotKey", "ZKHotKey"] {
            unarchiver.setClass(ArchivedShortcut.self, forClassName: name)
        }
        defer { unarchiver.finishDecoding() }
        guard let archived = unarchiver.decodeObject(of: ArchivedShortcut.self, forKey: NSKeyedArchiveRootObjectKey),
              unarchiver.error == nil, (-1...127).contains(archived.keyCode), archived.modifiers >= 0 else { return nil }
        if archived.keyCode == -1 || (archived.keyCode == 0 && archived.modifiers == 0) {
            return .init(keyCode: -1, modifierFlags: 0)
        }
        let raw = UInt(archived.modifiers)
        let cocoaMask: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
        var flags = NSEvent.ModifierFlags(rawValue: raw).intersection(cocoaMask)
        if raw & UInt(cmdKey) != 0 { flags.insert(.command) }
        if raw & UInt(optionKey) != 0 { flags.insert(.option) }
        if raw & UInt(controlKey) != 0 { flags.insert(.control) }
        if raw & UInt(shiftKey) != 0 { flags.insert(.shift) }
        return .init(keyCode: archived.keyCode, modifierFlags: flags.rawValue)
    }

    // Spectacle's JSON uses physical ANSI key names rather than the active
    // keyboard layout. Keep this map aligned with its key-binding serializer.
    private static let keyCodes: [String: Int] = [
        "A": 0, "S": 1, "D": 2, "F": 3, "H": 4, "G": 5, "Z": 6, "X": 7,
        "C": 8, "V": 9, "B": 11, "Q": 12, "W": 13, "E": 14, "R": 15,
        "Y": 16, "T": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "9": 25, "7": 26, "-": 27, "8": 28, "0": 29,
        "]": 30, "O": 31, "U": 32, "[": 33, "I": 34, "P": 35, "L": 37,
        "J": 38, "'": 39, "K": 40, ";": 41, "\\": 42, ",": 43, "/": 44,
        "N": 45, "M": 46, ".": 47, "`": 50,
        "RETURN": 36, "TAB": 48, "SPACE": 49, "DELETE": 51, "ESCAPE": 53,
        "F1": 122, "F2": 120, "F3": 99, "F4": 118, "F5": 96,
        "F6": 97, "F7": 98, "F8": 100, "F9": 101, "F10": 109,
        "F11": 103, "F12": 111, "F13": 105, "F14": 107, "F15": 113,
        "F16": 106, "F17": 64, "F18": 79, "F19": 80, "F20": 90,
        "KEYPADDECIMAL": 65, "KEYPADMULTIPLY": 67, "KEYPADPLUS": 69,
        "KEYPADCLEAR": 71, "KEYPADDIVIDE": 75, "KEYPADENTER": 76,
        "KEYPADMINUS": 78, "KEYPADEQUALS": 81, "KEYPAD0": 82, "KEYPAD1": 83,
        "KEYPAD2": 84, "KEYPAD3": 85, "KEYPAD4": 86, "KEYPAD5": 87,
        "KEYPAD6": 88, "KEYPAD7": 89, "KEYPAD8": 91, "KEYPAD9": 92,
        "VOLUMEUP": 72, "VOLUMEDOWN": 73, "MUTE": 74, "HELP": 114,
        "HOME": 115, "PAGEUP": 116, "FORWARDDELETE": 117, "END": 119,
        "PAGEDOWN": 121, "LEFT": 123, "RIGHT": 124, "DOWN": 125, "UP": 126
    ]
}

/// Only scalar fields are decoded; never instantiate the old archived classes.
@objc(XpectacleArchivedShortcut)
private final class ArchivedShortcut: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let keyCode: Int
    let modifiers: Int

    init?(coder: NSCoder) {
        guard coder.containsValue(forKey: "keyCode"), coder.containsValue(forKey: "modifiers") else { return nil }
        keyCode = coder.decodeInteger(forKey: "keyCode")
        modifiers = coder.decodeInteger(forKey: "modifiers")
    }

    func encode(with coder: NSCoder) {
        coder.encode(keyCode, forKey: "keyCode")
        coder.encode(modifiers, forKey: "modifiers")
    }
}
