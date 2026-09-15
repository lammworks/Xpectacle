import AppKit
import Combine

/// Releases remain manual until a Developer ID and signed update feed are configured.
/// Never start an updater with a placeholder signing key or an unverified feed.
@MainActor
final class UpdaterController: ObservableObject {
    let canCheckForUpdates = true

    func checkForUpdates() {
        NSWorkspace.shared.open(URL(string: "https://github.com/lammworks/Xpectacle/releases")!)
    }
}
