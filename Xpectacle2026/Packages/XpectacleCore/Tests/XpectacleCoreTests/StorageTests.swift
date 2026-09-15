import AppKit
import Carbon
import Foundation
import Testing
@testable import XpectacleCore

@Test func settingsLoadOlderFilesWithoutDiscardingChoices() throws {
    let json = Data(#"{"dragSnapEnabled":false,"disabledBundleIDs":["com.apple.Safari"]}"#.utf8)
    let settings = try JSONDecoder().decode(Settings.self, from: json)
    #expect(!settings.dragSnapEnabled)
    #expect(settings.disabledBundleIDs == ["com.apple.Safari"])
    #expect(settings.snapZoneActivationDelay == Settings.default.snapZoneActivationDelay)
}

@Test func settingsNormalizeUnsafeDelayAndInaccessibleUI() throws {
    let json = Data(#"{"showInMenuBar":false,"showInDock":false,"snapZoneActivationDelay":-100,"disabledBundleIDs":[" com.apple.Safari ","COM.APPLE.SAFARI",""]}"#.utf8)
    let settings = try JSONDecoder().decode(Settings.self, from: json)
    #expect(settings.showInMenuBar)
    #expect(settings.snapZoneActivationDelay == 0)
    #expect(settings.disabledBundleIDs == ["com.apple.Safari"])
}

@Test func settingsStorePreservesMalformedOriginalBeforeSaving() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("settings.json")
    let original = Data("not JSON".utf8)
    try original.write(to: url)
    let store = SettingsStore(url: url)
    #expect(await store.loadError != nil)
    try await store.update { $0.dragSnapEnabled = false }
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    let backup = try #require(files.first { $0.lastPathComponent.contains("unreadable-") })
    #expect(try Data(contentsOf: backup) == original)
    let reloaded = SettingsStore(url: url)
    #expect(await reloaded.current.dragSnapEnabled == false)
}

@Test func failedSettingsSaveDoesNotCommitMemory() async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let blockingFile = directory.appendingPathComponent("file")
    try Data().write(to: blockingFile)
    let store = SettingsStore(url: blockingFile.appendingPathComponent("settings.json"))
    await #expect(throws: (any Error).self) {
        try await store.update { $0.dragSnapEnabled = false }
    }
    #expect(await store.current.dragSnapEnabled)
}

@Test func legacyJSONImportsActualFormatAndExplicitClear() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent("Shortcuts.json")
    try Data(#"[{"shortcut_name":"MoveToLeftHalf","shortcut_key_binding":"ctrl+alt+left"},{"shortcut_name":"MoveToCenter","shortcut_key_binding":"cmd+a"},{"shortcut_name":"MoveToRightHalf","shortcut_key_binding":null},{"shortcut_name":"MoveToNextThird","shortcut_key_binding":"ctrl+alt+right"},{"shortcut_name":"MoveToTopHalf","shortcut_key_binding":"unknown+up"}]"#.utf8).write(to: url)
    let suite = "XpectacleTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let shortcuts = LegacyImporter.importIfPresent(defaults: defaults, jsonURL: url)
    #expect(shortcuts[.leftHalf]?.keyCode == 123)
    #expect(shortcuts[.leftHalf]?.modifierFlags == NSEvent.ModifierFlags([.control, .option]).rawValue)
    #expect(shortcuts[.center]?.keyCode == 0)
    #expect(shortcuts[.rightHalf]?.isCleared == true)
    #expect(shortcuts[.nextThirdHorizontal]?.keyCode == 124)
    #expect(shortcuts[.topHalf] == nil)
}

@Test func legacyArchiveImportsRootObjectAndConvertsCarbonFlags() throws {
    let suite = "XpectacleTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    let archiver = NSKeyedArchiver(requiringSecureCoding: true)
    archiver.setClassName("SpectacleShortcut", for: LegacyArchiveFixture.self)
    archiver.encode(LegacyArchiveFixture(keyCode: 0, modifiers: Int(cmdKey | optionKey)), forKey: NSKeyedArchiveRootObjectKey)
    archiver.finishEncoding()
    defaults.set(archiver.encodedData, forKey: "MoveToCenter")
    let shortcuts = LegacyImporter.importIfPresent(defaults: defaults, jsonURL: nil)
    #expect(shortcuts[.center]?.keyCode == 0)
    #expect(shortcuts[.center]?.modifierFlags == NSEvent.ModifierFlags([.command, .option]).rawValue)
}

@objc(XpectacleLegacyArchiveFixture)
private final class LegacyArchiveFixture: NSObject, NSSecureCoding {
    static var supportsSecureCoding: Bool { true }
    let keyCode: Int
    let modifiers: Int
    init(keyCode: Int, modifiers: Int) { self.keyCode = keyCode; self.modifiers = modifiers }
    init?(coder: NSCoder) { keyCode = 0; modifiers = 0 }
    func encode(with coder: NSCoder) {
        coder.encode("MoveToCenter", forKey: "name")
        coder.encode(keyCode, forKey: "keyCode")
        coder.encode(modifiers, forKey: "modifiers")
    }
}
