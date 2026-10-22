import AppKit
import AppIntents
import SwiftUI
import XpectacleCore

@main
struct XpectacleApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra(
            appModel.accessibilityTrusted ? "Xpectacle" : "Xpectacle — Access Required",
            image: "MenuBarTemplate"
        ) {
            if !appModel.accessibilityTrusted {
                Text("Window control is blocked by macOS.")
                ReviewPermissionsButton(model: appModel)
                Divider()
            }

            ForEach(menuActionGroups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.actions, id: \.identifier) { action in
                        Button(action.localizedTitle) {
                            appModel.perform(action)
                        }
                        .disabled(!appModel.accessibilityTrusted || !appModel.settingsLoaded)
                    }
                }
            }

            if !appModel.settings.layouts.isEmpty {
                Divider()
                Section("Layouts") {
                    ForEach(appModel.settings.layouts) { layout in
                        Button(layout.name) {
                            appModel.apply(layout)
                        }
                        .disabled(!appModel.accessibilityTrusted || !appModel.settingsLoaded)
                    }
                }
            }

            Divider()
            if let errorMessage = appModel.errorMessage {
                Text(errorMessage)
                Button("Dismiss Error") { appModel.errorMessage = nil }
                Divider()
            }
            SettingsLink { Text("Settings…") }
            .keyboardShortcut(",")
            Button("Check for Updates…") { appModel.updater.checkForUpdates() }
                .disabled(!appModel.updater.canCheckForUpdates)
            Button("Quit Xpectacle") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(model: appModel)
                .frame(minWidth: 720, minHeight: 480)
        }
    }
}

private struct ReviewPermissionsButton: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Review Permissions…") {
            model.selectedSettingsTab = .permissions
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
    }
}

struct XpectacleAppIntentsPackage: AppIntentsPackage {
    static var includedPackages: [any AppIntentsPackage.Type] { [XpectacleCoreAppIntentsPackage.self] }
}

private struct MenuActionGroup {
    let title: String
    let actions: [WindowAction]
}

private let menuActionGroups: [MenuActionGroup] = [
    .init(title: "Halves", actions: [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
    .init(title: "Corners", actions: [.upperLeft, .upperRight, .lowerLeft, .lowerRight]),
    .init(title: "Other", actions: [
        .fullscreen, .center,
        .nextThirdHorizontal, .nextThirdVertical,
        .nextDisplay, .previousDisplay,
        .undoLastMove, .redoLastMove,
    ]),
]
