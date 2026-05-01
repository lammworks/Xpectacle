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
    var launchAtLoginEnabled: Bool = LaunchAtLogin.isEnabled
    let updater = UpdaterController()

    private let dragMonitor = DragMonitor()
    private let preview = PreviewOverlay()
    private var permissionsTimer: Timer?

    init() {
        Task { await load() }
        setupHotkeys()
        setupDragMonitor()
        setupPermissionsPolling()
        setupLegacyImport()
    }

    private func load() async {
        settings = await SettingsStore.shared.current
        await applySettings()
    }

    func update(_ mutate: @escaping (inout Settings) -> Void) {
        Task {
            try? await SettingsStore.shared.update(mutate)
            settings = await SettingsStore.shared.current
            await applySettings()
        }
    }

    private func applySettings() async {
        if settings.dragSnapEnabled { dragMonitor.start() } else { dragMonitor.stop() }
        dragMonitor.activationDelay = settings.snapZoneActivationDelay
        await WindowController.shared.setDisabledBundleIDs(settings.disabledBundleIDs)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLogin.setEnabled(enabled)
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        update { $0.launchAtLogin = enabled }
    }

    private func setupHotkeys() {
        HotkeyService.shared.registerAll { action in
            Task { try? await WindowController.shared.perform(action) }
        }
    }

    private func setupDragMonitor() {
        dragMonitor.onZoneEnter = { [weak self] zone, screen in
            self?.preview.show(action: zone.action, on: screen)
        }
        dragMonitor.onZoneExit = { [weak self] in self?.preview.hide() }
        dragMonitor.onCommit = { [weak self] zone, _ in
            self?.preview.hide()
            guard let self, self.settings.dragSnapEnabled else { return }
            Task { try? await WindowController.shared.perform(zone.action) }
        }
        if settings.dragSnapEnabled { dragMonitor.start() }
    }

    private func setupPermissionsPolling() {
        permissionsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.accessibilityTrusted = Permissions.isAccessibilityTrusted
                self?.launchAtLoginEnabled = LaunchAtLogin.isEnabled
            }
        }
    }

    /// Run the legacy importer once, the very first time the app launches
    /// without a settings file already on disk.
    private func setupLegacyImport() {
        let url = SettingsStore.defaultURL
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        let imported = LegacyImporter.importIfPresent()
        for (action, shortcut) in imported {
            let mods = NSEvent.ModifierFlags(rawValue: shortcut.modifierFlags)
            guard let key = KeyboardShortcuts.Key(rawValue: shortcut.keyCode) else { continue }
            KeyboardShortcuts.setShortcut(.init(key, modifiers: mods),
                                          for: .forAction(action))
        }
    }
}
