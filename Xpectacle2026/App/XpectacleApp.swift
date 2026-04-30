import SwiftUI
import XpectacleCore

@main
struct XpectacleApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("Xpectacle", systemImage: "rectangle.split.2x2") {
            MenuBarContent(model: appModel)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: appModel)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}
