import Sparkle
import SwiftUI

/// Wraps Sparkle's `SPUStandardUpdaterController` and exposes a simple
/// "Check for Updates…" command to the menu bar.
@MainActor
final class UpdaterController: ObservableObject {
    let controller: SPUStandardUpdaterController

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() { controller.checkForUpdates(nil) }

    var canCheckForUpdates: Bool { controller.updater.canCheckForUpdates }
}
