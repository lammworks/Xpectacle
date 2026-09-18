import KeyboardShortcuts
import SwiftUI
import XpectacleCore

struct SettingsView: View {
    let model: AppModel

    var body: some View {
        TabView(selection: Binding(
            get: { model.selectedSettingsTab },
            set: { model.selectedSettingsTab = $0 }
        )) {
            ShortcutsTab().tabItem { Label("Shortcuts", systemImage: "command") }.tag(SettingsTab.shortcuts)
            SnapZonesTab(model: model).tabItem { Label("Snap Zones", systemImage: "rectangle.split.3x1") }.tag(SettingsTab.snapZones)
            LayoutsTab(model: model).tabItem { Label("Layouts", systemImage: "square.grid.2x2") }.tag(SettingsTab.layouts)
            GeneralTab(model: model).tabItem { Label("General", systemImage: "gearshape") }.tag(SettingsTab.general)
            UpdatesTab(model: model).tabItem { Label("Updates", systemImage: "arrow.down.circle") }.tag(SettingsTab.updates)
            PermissionsTab(model: model).tabItem { Label("Permissions", systemImage: "lock.shield") }.tag(SettingsTab.permissions)
        }
        .padding()
        .disabled(!model.settingsLoaded)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            model.refreshSystemState()
        }
        .alert("Xpectacle", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
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
            Text("Snapping uses the usable area reported by macOS for each display.")
                .font(.callout)
                .foregroundStyle(.secondary)
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
                        do {
                            let layout = try await LayoutEngine.shared.capture(named: name)
                            model.update { $0.layouts.append(layout) }
                            newLayoutName = ""
                        } catch {
                            model.errorMessage = "Couldn’t capture layout: \(error.localizedDescription)"
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
                        Button("Apply") { model.apply(layout) }
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
            if model.launchAtLoginNeedsApproval {
                LabeledContent("Launch at login needs approval") {
                    Button("Open Login Items") { LaunchAtLogin.openSettings() }
                    Button("Cancel") { model.setLaunchAtLogin(false) }
                }
            }
            Toggle("Show in Dock", isOn: Binding(
                get: { model.settings.showInDock },
                set: { v in model.update { $0.showInDock = v } }
            ))
            Text("Xpectacle remains available in the menu bar.")
                .font(.callout)
                .foregroundStyle(.secondary)
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
                model.update {
                    if !$0.disabledBundleIDs.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                        $0.disabledBundleIDs.append(trimmed)
                    }
                }
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
                Text("Xpectacle \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")")
                Spacer()
                Button("Check for Updates…") { model.updater.checkForUpdates() }
                    .disabled(!model.updater.canCheckForUpdates)
            }
            Text("Check GitHub for the latest release and installation instructions.")
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
            Section {
                HStack {
                    Image(systemName: model.accessibilityTrusted ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(model.accessibilityTrusted ? .green : .red)
                        .accessibilityHidden(true)
                    Text(model.accessibilityTrusted ? "Access granted" : "Access required")
                        .fontWeight(.medium)
                    Spacer()
                    Button("Check Again") { model.refreshSystemState() }
                }
                Text("Xpectacle needs permission to read and move other apps’ windows.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if !model.accessibilityTrusted {
                    Text("System Settings → Privacy & Security → \(Permissions.accessibilitySettingsName)")
                        .font(.callout)
                    Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                }
            }

            if !model.accessibilityTrusted {
                Section("If Xpectacle’s switch is already on") {
                    Text("After an update, macOS may keep permission for the previous copy of Xpectacle. The switch can be on while this copy is still denied.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. In \(Permissions.accessibilitySettingsName), select Xpectacle and click the minus (−) button.")
                        Text("2. Click the plus (+) button, choose the app shown below, and turn its switch on.")
                        Text("3. Quit Xpectacle, then reopen that same app.")
                    }
                    .font(.callout)
                }
            }

            Section("This copy of Xpectacle") {
                Text(Permissions.currentApplicationURL.path)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Show in Finder") { Permissions.revealCurrentApplication() }
            }
        }
        .formStyle(.grouped)
    }
}
