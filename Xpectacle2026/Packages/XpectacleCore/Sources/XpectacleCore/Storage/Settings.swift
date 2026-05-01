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
}

public actor SettingsStore {
    public static let shared = SettingsStore()
    private let url: URL
    private(set) public var current: Settings

    public init(url: URL? = nil) {
        let resolved = url ?? Self.defaultURL
        self.url = resolved
        if let data = try? Data(contentsOf: resolved),
           let decoded = try? JSONDecoder().decode(Settings.self, from: data) {
            self.current = decoded
        } else {
            self.current = .default
        }
    }

    public func update(_ mutate: (inout Settings) -> Void) throws {
        var s = current
        mutate(&s)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(s)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        current = s
    }

    public static var defaultURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return appSupport.appendingPathComponent("Xpectacle/settings.json")
    }
}
