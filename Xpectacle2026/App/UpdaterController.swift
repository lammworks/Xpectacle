import Sparkle
import SwiftUI
import UserNotifications

/// Wraps Sparkle's `SPUStandardUpdaterController` and implements the
/// "gentle reminders" pattern Sparkle requires for background/menu-bar
/// apps: when an update is found in the background, we suppress Sparkle's
/// modal and post a User Notification instead.
///
/// Sparkle's delegate protocols aren't `@MainActor`-annotated, so this
/// type stays at module isolation and hops to main only when touching
/// AppKit/SwiftUI state.
final class UpdaterController: NSObject, ObservableObject {
    private(set) var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: self
        )
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }
    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }
}

extension UpdaterController: SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        let content = UNMutableNotificationContent()
        content.title = "Xpectacle update available"
        content.body = "Version \(update.displayVersionString) is ready to install."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "xpectacle.update.\(update.versionString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["xpectacle.update.\(update.versionString)"]
        )
    }

    func standardUserDriverWillFinishUpdateSession() {
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

extension UpdaterController: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { self.controller.checkForUpdates(nil) }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
