import ServiceManagement

/// Uses the system registration state rather than a saved preference.
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status == .notRegistered || service.status == .notFound {
                try service.register()
            }
            if service.status == .requiresApproval { openSettings() }
        } else if service.status == .enabled || service.status == .requiresApproval {
            // A registration awaiting approval still needs to be unregistered.
            try service.unregister()
        }
    }
}
