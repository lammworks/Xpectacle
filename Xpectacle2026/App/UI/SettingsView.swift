import KeyboardShortcuts
import SwiftUI
import XpectacleCore

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView {
            ShortcutsTab().tabItem { Label("Shortcuts", systemImage: "command") }
            SnapZonesTab(model: model).tabItem { Label("Snap Zones", systemImage: "rectangle.split.3x1") }
            LayoutsTab(model: model).tabItem { Label("Layouts", systemImage: "square.grid.2x2") }
            GeneralTab(model: model).tabItem { Label("General", systemImage: "gearshape") }
            PermissionsTab(model: model).tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .padding()
    }
}

struct ShortcutsTab: View {
    var body: some View {
        Form {
            ForEach(WindowAction.allCases, id: \.identifier) { action in
                KeyboardShortcuts.Recorder(action.localizedTitle, name: .forAction(action))
            }
        }
        .formStyle(.grouped)
    }
}

struct SnapZonesTab: View {
    let model: AppModel
    var body: some View {
        Form {
            Toggle("Enable drag-to-edge snapping", isOn: Binding(
                get: { model.settings.dragSnapEnabled },
                set: { v in model.update { $0.dragSnapEnabled = v } }
            ))
            Slider(value: Binding(
                get: { model.settings.snapZoneActivationDelay },
                set: { v in model.update { $0.snapZoneActivationDelay = v } }
            ), in: 0...0.5) { Text("Activation delay") }
            Toggle("Stage Manager aware", isOn: Binding(
                get: { model.settings.stageManagerAware },
                set: { v in model.update { $0.stageManagerAware = v } }
            ))
        }
        .formStyle(.grouped)
    }
}

struct LayoutsTab: View {
    let model: AppModel
    @State private var newLayoutName = ""

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                TextField("New layout name", text: $newLayoutName)
                Button("Capture Current Windows") {
                    let name = newLayoutName.isEmpty ? "Untitled" : newLayoutName
                    Task {
                        if let layout = try? await LayoutEngine.shared.capture(named: name) {
                            model.update { $0.layouts.append(layout) }
                            newLayoutName = ""
                        }
                    }
                }
            }
            List {
                ForEach(model.settings.layouts) { layout in
                    HStack {
                        Text(layout.name)
                        Spacer()
                        Button("Apply") { Task { try? await LayoutEngine.shared.apply(layout) } }
                        Button(role: .destructive) {
                            model.update { $0.layouts.removeAll { $0.id == layout.id } }
                        } label: { Image(systemName: "trash") }
                    }
                }
            }
        }
    }
}

struct GeneralTab: View {
    let model: AppModel
    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { model.settings.launchAtLogin },
                set: { v in model.update { $0.launchAtLogin = v } }
            ))
            Toggle("Show in menu bar", isOn: Binding(
                get: { model.settings.showInMenuBar },
                set: { v in model.update { $0.showInMenuBar = v } }
            ))
            Toggle("Show in Dock", isOn: Binding(
                get: { model.settings.showInDock },
                set: { v in model.update { $0.showInDock = v } }
            ))
        }
        .formStyle(.grouped)
    }
}

struct PermissionsTab: View {
    let model: AppModel
    var body: some View {
        Form {
            HStack {
                Image(systemName: model.accessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(model.accessibilityTrusted ? .green : .red)
                Text("Accessibility")
                Spacer()
                if !model.accessibilityTrusted {
                    Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                }
            }
            Text("Xpectacle uses Apple's Accessibility API to read and set window frames. Without this permission no window actions will work.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
    }
}
