import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI
import XpectacleCore

@MainActor
@Observable
final class AppModel {
    var settings: Settings = .default
    var accessibilityTrusted: Bool = Permissions.isAccessibilityTrusted

    private let dragMonitor = DragMonitor()
    private var permissionsTimer: Timer?

    init() {
        Task { await load() }
        setupHotkeys()
        setupDragMonitor()
        setupPermissionsPolling()
        setupLegacyImport()
    }

    private func load() async {
        let store = SettingsStore.shared
        settings = await store.current
    }

    func update(_ mutate: @escaping (inout Settings) -> Void) {
        Task {
            try? await SettingsStore.shared.update(mutate)
            settings = await SettingsStore.shared.current
            applySettings()
        }
    }

    private func applySettings() {
        if settings.dragSnapEnabled { dragMonitor.start() } else { dragMonitor.stop() }
        dragMonitor.activationDelay = settings.snapZoneActivationDelay
    }

    private func setupHotkeys() {
        HotkeyService.shared.registerAll { action in
            Task { try? await WindowController.shared.perform(action) }
        }
    }

    private func setupDragMonitor() {
        dragMonitor.onCommit = { [weak self] zone, _ in
            guard let self else { return }
            if self.settings.dragSnapEnabled {
                Task { try? await WindowController.shared.perform(zone.action) }
            }
        }
        if settings.dragSnapEnabled { dragMonitor.start() }
    }

    private func setupPermissionsPolling() {
        permissionsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.accessibilityTrusted = Permissions.isAccessibilityTrusted
            }
        }
    }

    /// Run the legacy importer once, the very first time the app launches
    /// without a settings file already on disk. Any matched shortcuts are
    /// pushed into KeyboardShortcuts' storage.
    private func setupLegacyImport() {
        let url = SettingsStore.defaultURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let imported = LegacyImporter.importIfPresent()
        for (action, shortcut) in imported {
            // Mapping legacy carbon modifier flags → Cocoa is straightforward
            // (Carbon shifts are documented constants); KeyboardShortcuts
            // accepts NSEvent.ModifierFlags directly.
            let mods = NSEvent.ModifierFlags(rawValue: shortcut.modifierFlags)
            let key = KeyboardShortcuts.Key(rawValue: shortcut.keyCode) ?? .return
            KeyboardShortcuts.setShortcut(.init(key, modifiers: mods),
                                          for: .forAction(action))
        }
    }
}
