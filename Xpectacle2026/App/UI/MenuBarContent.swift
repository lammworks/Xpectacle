import SwiftUI
import XpectacleCore

struct MenuBarContent: View {
    let model: AppModel

    var body: some View {
        if !model.accessibilityTrusted {
            Button("Grant Accessibility Access…") { Permissions.promptForAccessibility() }
            Divider()
        }
        Section("Halves") {
            actionButton(.leftHalf); actionButton(.rightHalf)
            actionButton(.topHalf); actionButton(.bottomHalf)
        }
        Section("Corners") {
            actionButton(.upperLeft); actionButton(.upperRight)
            actionButton(.lowerLeft); actionButton(.lowerRight)
        }
        Section("Other") {
            actionButton(.fullscreen); actionButton(.center)
            actionButton(.nextThirdHorizontal); actionButton(.nextThirdVertical)
            actionButton(.nextDisplay); actionButton(.previousDisplay)
            actionButton(.undoLastMove); actionButton(.redoLastMove)
        }
        if !model.settings.layouts.isEmpty {
            Divider()
            Section("Layouts") {
                ForEach(model.settings.layouts) { layout in
                    Button(layout.name) {
                        Task { try? await LayoutEngine.shared.apply(layout) }
                    }
                }
            }
        }
        Divider()
        SettingsLink { Text("Settings…") }
        Button("Quit Xpectacle") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func actionButton(_ action: WindowAction) -> some View {
        Button(action.localizedTitle) {
            Task { try? await WindowController.shared.perform(action) }
        }
    }
}
