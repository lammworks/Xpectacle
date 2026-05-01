import AppKit
import SwiftUI
import XpectacleCore

@main
struct XpectacleApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        MenuBarExtra("Xpectacle", systemImage: "rectangle.split.2x2") {
            // SwiftUI's MenuBarExtra(.menu) builder is finicky about custom
            // subviews — inline every item here so the menu always renders.
            if !appModel.accessibilityTrusted {
                Button("Grant Accessibility Access…") { Permissions.promptForAccessibility() }
                Divider()
            }

            ForEach(menuActionGroups, id: \.title) { group in
                Section(group.title) {
                    ForEach(group.actions, id: \.identifier) { action in
                        Button(action.localizedTitle) {
                            Task { try? await WindowController.shared.perform(action) }
                        }
                    }
                }
            }

            if !appModel.settings.layouts.isEmpty {
                Divider()
                Section("Layouts") {
                    ForEach(appModel.settings.layouts) { layout in
                        Button(layout.name) {
                            Task { try? await LayoutEngine.shared.apply(layout) }
                        }
                    }
                }
            }

            Divider()
            SettingsLink { Text("Settings…") }
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
