import Foundation

/// Top-level user-facing settings model. Persisted as JSON at
/// `~/Library/Application Support/Xpectacle/settings.json`.
public struct Settings: Codable, Sendable, Equatable {
    public var launchAtLogin: Bool
    public var showInMenuBar: Bool
    public var showInDock: Bool
    public var dragSnapEnabled: Bool
    public var snapZoneActivationDelay: TimeInterval
    public var stageManagerAware: Bool
    public var layouts: [Layout]
    public var disabledBundleIDs: [String]

    public init(
        launchAtLogin: Bool = true,
        showInMenuBar: Bool = true,
        showInDock: Bool = false,
        dragSnapEnabled: Bool = true,
        snapZoneActivationDelay: TimeInterval = 0.1,
        stageManagerAware: Bool = true,
        layouts: [Layout] = [],
        disabledBundleIDs: [String] = []
    ) {
        self.launchAtLogin = launchAtLogin
        self.showInMenuBar = showInMenuBar
        self.showInDock = showInDock
        self.dragSnapEnabled = dragSnapEnabled
        self.snapZoneActivationDelay = snapZoneActivationDelay
        self.stageManagerAware = stageManagerAware
        self.layouts = layouts
        self.disabledBundleIDs = disabledBundleIDs
    }

    public static let `default` = Settings()

    private enum CodingKeys: String, CodingKey {
        case launchAtLogin, showInMenuBar, showInDock, dragSnapEnabled
        case snapZoneActivationDelay, stageManagerAware, layouts, disabledBundleIDs
    }

    /// New settings must not discard the rest of an older settings file.
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.default
        launchAtLogin = try values.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? defaults.launchAtLogin
        showInMenuBar = try values.decodeIfPresent(Bool.self, forKey: .showInMenuBar) ?? defaults.showInMenuBar
        showInDock = try values.decodeIfPresent(Bool.self, forKey: .showInDock) ?? defaults.showInDock
        dragSnapEnabled = try values.decodeIfPresent(Bool.self, forKey: .dragSnapEnabled) ?? defaults.dragSnapEnabled
        snapZoneActivationDelay = try values.decodeIfPresent(TimeInterval.self, forKey: .snapZoneActivationDelay) ?? defaults.snapZoneActivationDelay
        stageManagerAware = try values.decodeIfPresent(Bool.self, forKey: .stageManagerAware) ?? defaults.stageManagerAware
        layouts = try values.decodeIfPresent([Layout].self, forKey: .layouts) ?? defaults.layouts
        disabledBundleIDs = try values.decodeIfPresent([String].self, forKey: .disabledBundleIDs) ?? defaults.disabledBundleIDs
        normalize()
    }

    public mutating func normalize() {
        snapZoneActivationDelay = snapZoneActivationDelay.isFinite ? min(0.5, max(0, snapZoneActivationDelay)) : Self.default.snapZoneActivationDelay
        // Keep an entry point to Settings and Quit available.
        if !showInMenuBar && !showInDock { showInMenuBar = true }
        var seen = Set<String>()
        disabledBundleIDs = disabledBundleIDs.compactMap {
            let id = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return !id.isEmpty && seen.insert(id.lowercased()).inserted ? id : nil
        }
    }
}

public actor SettingsStore {
    public static let shared = SettingsStore()
    private let url: URL
    private(set) public var current: Settings
    private(set) public var loadError: String?
    private var preserveOriginalBeforeSaving = false

    public init(url: URL? = nil) {
        let resolved = url ?? Self.defaultURL
        self.url = resolved
        self.current = .default
        if FileManager.default.fileExists(atPath: resolved.path) {
            do {
                let data = try Data(contentsOf: resolved)
                self.current = try JSONDecoder().decode(Settings.self, from: data)
            } catch {
                self.loadError = "Saved settings could not be loaded. Defaults are in use; the original file will be backed up before saving. \(error.localizedDescription)"
                self.preserveOriginalBeforeSaving = true
            }
        }
    }

    public func update(_ mutate: @Sendable (inout Settings) -> Void) throws {
        var s = current
        mutate(&s)
        s.normalize()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(s)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if preserveOriginalBeforeSaving {
            let backup = url.deletingPathExtension().appendingPathExtension("unreadable-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: url, to: backup)
            preserveOriginalBeforeSaving = false
        }
        try data.write(to: url, options: .atomic)
        current = s
    }

    public static var defaultURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Xpectacle/settings.json")
    }
}
