import ServiceManagement

/// Wrapper around `SMAppService.mainApp` for launch-at-login. macOS 13+
/// removed the old loginitems API; this is the modern replacement.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Swallow — surfaced via .isEnabled re-read on next UI tick.
        }
    }
}
