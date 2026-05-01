import Sparkle
import SwiftUI
import UserNotifications

/// Wraps Sparkle's `SPUStandardUpdaterController` and implements the
/// "gentle reminders" pattern Sparkle requires for background/menu-bar
/// apps: when an update is found in the background, we suppress Sparkle's
/// modal and post a User Notification instead. Tapping the notification
/// surfaces the regular update flow.
@MainActor
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
    /// Tells Sparkle we'll handle the UI ourselves for scheduled (background)
    /// update checks — so the user gets a notification, not a hidden modal.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        // If the app is frontmost we let Sparkle show its normal alert;
        // otherwise we'll post a gentle notification below.
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
        // Clear any leftover update notifications when Sparkle's flow ends.
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

extension UpdaterController: UNUserNotificationCenterDelegate {
    /// When the user taps the notification, ask Sparkle to surface the
    /// regular update prompt.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { self.controller.checkForUpdates(nil) }
    }

    /// Show notifications even while the app is technically active — for a
    /// menu-bar app "active" means the menu was open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
