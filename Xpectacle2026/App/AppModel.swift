import AppKit
import Observation
import XpectacleCore

@MainActor
@Observable
final class AppModel {
    var settings: Settings = .default
    var settingsLoaded = false
    var accessibilityTrusted = Permissions.isAccessibilityTrusted
    var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    var launchAtLoginNeedsApproval = LaunchAtLogin.requiresApproval
    var errorMessage: String?
    let updater = UpdaterController()

    private let dragMonitor = DragMonitor()
    private let preview = PreviewOverlay()
    private var permissionsTimer: Timer?
    private var settingsTask: Task<Void, Never>?

    init() {
        HotkeyService.shared.importLegacyShortcutsIfNeeded()
        setupDragMonitor()
        setupPermissionsPolling()
        settingsTask = Task { [weak self] in
            guard let self else { return }
            self.settings = await SettingsStore.shared.current
            self.settings.launchAtLogin = LaunchAtLogin.isEnabled
            self.errorMessage = await SettingsStore.shared.loadError
            self.settingsLoaded = true
            await self.applySettings()
        }
    }

    func update(_ mutate: (inout Settings) -> Void) {
        guard settingsLoaded else { return }
        // Update bindings immediately; serialize persistence so rapid slider or
        // toggle changes cannot overwrite a later edit with an older snapshot.
        mutate(&settings)
        settings.normalize()
        let snapshot = settings
        let previous = settingsTask
        settingsTask = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                try await SettingsStore.shared.update { $0 = snapshot }
            } catch {
                self.errorMessage = "Couldn’t save settings: \(error.localizedDescription)"
            }
            await self.applySettings()
        }
        applyAppearance()
        synchronizePermissions()
    }

    private func applySettings() async {
        applyAppearance()
        synchronizePermissions()
        await WindowController.shared.setDisabledBundleIDs(settings.disabledBundleIDs)
    }

    private func applyAppearance() {
        NSApp.setActivationPolicy(settings.showInDock ? .regular : .accessory)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            refreshSystemState()
            let actualState = launchAtLoginEnabled
            update { $0.launchAtLogin = actualState }
        } catch {
            refreshSystemState()
            errorMessage = "Couldn’t update launch at login: \(error.localizedDescription)"
        }
    }

    func perform(_ action: WindowAction) {
        guard settingsLoaded else { return }
        refreshSystemState()
        guard accessibilityTrusted else {
            Permissions.openAccessibilitySettings()
            return
        }
        Task {
            do { try await WindowController.shared.perform(action) }
            catch { errorMessage = "Couldn’t move this window: \(error.localizedDescription)" }
        }
    }

    func apply(_ layout: Layout) {
        Task {
            do { try await LayoutEngine.shared.apply(layout) }
            catch { errorMessage = "Couldn’t apply layout: \(error.localizedDescription)" }
        }
    }

    func refreshSystemState() {
        accessibilityTrusted = Permissions.isAccessibilityTrusted
        launchAtLoginEnabled = LaunchAtLogin.isEnabled
        launchAtLoginNeedsApproval = LaunchAtLogin.requiresApproval
        synchronizePermissions()
    }

    private func synchronizePermissions() {
        if accessibilityTrusted && settingsLoaded {
            HotkeyService.shared.registerAll { [weak self] action in self?.perform(action) }
        } else {
            HotkeyService.shared.unregisterAll()
        }
        dragMonitor.activationDelay = settings.snapZoneActivationDelay
        dragMonitor.disabledBundleIDs = Set(settings.disabledBundleIDs.map { $0.lowercased() })
        if accessibilityTrusted && settingsLoaded && settings.dragSnapEnabled {
            dragMonitor.start()
        } else {
            dragMonitor.stop()
            preview.hide()
        }
    }

    private func setupDragMonitor() {
        dragMonitor.onZoneEnter = { [weak self] zone, screen in
            self?.preview.show(action: zone.action, on: screen)
        }
        dragMonitor.onZoneExit = { [weak self] in self?.preview.hide() }
        dragMonitor.onCommit = { [weak self] zone, screen, window in
            guard let self else { return }
            self.preview.hide()
            guard self.settings.dragSnapEnabled, Permissions.isAccessibilityTrusted else { return }
            Task {
                do {
                    try await WindowController.shared.perform(zone.action, on: window, targetScreenID: screen.id)
                } catch {
                    self.errorMessage = "Couldn’t snap this window: \(error.localizedDescription)"
                }
            }
        }
    }

    private func setupPermissionsPolling() {
        permissionsTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshSystemState() }
        }
        permissionsTimer?.tolerance = 1
    }
}
