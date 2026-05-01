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
            UpdatesTab(model: model).tabItem { Label("Updates", systemImage: "arrow.down.circle") }
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
            HStack {
                Text("Activation delay")
                Slider(value: Binding(
                    get: { model.settings.snapZoneActivationDelay },
                    set: { v in model.update { $0.snapZoneActivationDelay = v } }
                ), in: 0...0.5)
                Text("\(Int(model.settings.snapZoneActivationDelay * 1000)) ms")
                    .monospacedDigit()
                    .frame(width: 60, alignment: .trailing)
            }
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
            .padding(.bottom, 8)
            List {
                ForEach(model.settings.layouts) { layout in
                    HStack {
                        Text(layout.name)
                        Spacer()
                        Text("\(layout.slots.count) windows")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                        Button("Apply") { Task { try? await LayoutEngine.shared.apply(layout) } }
                        Button(role: .destructive) {
                            model.update { $0.layouts.removeAll { $0.id == layout.id } }
                        } label: { Image(systemName: "trash") }
                    }
                }
            }
        }
        .padding()
    }
}

struct GeneralTab: View {
    let model: AppModel
    var body: some View {
        Form {
            Toggle("Launch at login", isOn: Binding(
                get: { model.launchAtLoginEnabled },
                set: { v in model.setLaunchAtLogin(v) }
            ))
            Toggle("Show in menu bar", isOn: Binding(
                get: { model.settings.showInMenuBar },
                set: { v in model.update { $0.showInMenuBar = v } }
            ))
            Toggle("Show in Dock", isOn: Binding(
                get: { model.settings.showInDock },
                set: { v in model.update { $0.showInDock = v } }
            ))
            Section("Disabled Apps") {
                Text("Window actions are ignored for these bundle identifiers.")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                ForEach(model.settings.disabledBundleIDs, id: \.self) { id in
                    HStack {
                        Text(id).font(.system(.body, design: .monospaced))
                        Spacer()
                        Button(role: .destructive) {
                            model.update { $0.disabledBundleIDs.removeAll { $0 == id } }
                        } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                    }
                }
                AddBundleIDField(model: model)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AddBundleIDField: View {
    let model: AppModel
    @State private var input = ""
    var body: some View {
        HStack {
            TextField("com.example.App", text: $input)
                .textFieldStyle(.roundedBorder)
            Button("Add") {
                let trimmed = input.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                model.update { $0.disabledBundleIDs.append(trimmed) }
                input = ""
            }
            .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

struct UpdatesTab: View {
    let model: AppModel
    var body: some View {
        Form {
            HStack {
                Text("Xpectacle 2.0.0")
                Spacer()
                Button("Check for Updates…") { model.updater.checkForUpdates() }
                    .disabled(!model.updater.canCheckForUpdates)
            }
            Text("Updates are delivered via Sparkle 2 with EdDSA-signed appcasts. The feed URL is set in Info.plist (SUFeedURL).")
                .font(.callout)
                .foregroundStyle(.secondary)
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
