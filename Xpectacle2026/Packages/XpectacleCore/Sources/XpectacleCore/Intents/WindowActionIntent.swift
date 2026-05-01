#if canImport(AppIntents)
import AppIntents
import Foundation

/// One App Intent surface for every `WindowAction`. App Intents auto-register
/// with Shortcuts, Spotlight, and Siri, so once this file is in the app bundle
/// the user can say "Hey Siri, snap window to left half".
public struct PerformWindowAction: AppIntent {
    public static var title: LocalizedStringResource = "Perform Window Action"
    public static var description = IntentDescription("Apply a Xpectacle window action to the frontmost window.")
    public static var openAppWhenRun: Bool = false

    @Parameter(title: "Action") public var action: WindowActionEntity

    public init() {}
    public init(action: WindowAction) { self.action = .init(action: action) }

    public func perform() async throws -> some IntentResult {
        try await WindowController.shared.perform(action.action)
        return .result()
    }
}

public struct ApplyLayoutIntent: AppIntent {
    public static var title: LocalizedStringResource = "Apply Layout"
    public static var description = IntentDescription("Apply a saved Xpectacle layout.")

    @Parameter(title: "Layout") public var layoutName: String

    public init() {}
    public init(layoutName: String) { self.layoutName = layoutName }

    public func perform() async throws -> some IntentResult {
        let settings = await SettingsStore.shared.current
        guard let layout = settings.layouts.first(where: { $0.name == layoutName }) else {
            throw $layoutName.needsValueError("No layout named \(layoutName).")
        }
        try await LayoutEngine.shared.apply(layout)
        return .result()
    }
}

public struct WindowActionEntity: AppEntity {
    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Window Action"
    public static var defaultQuery = WindowActionQuery()

    public var id: String { action.identifier }
    public let action: WindowAction
    public init(action: WindowAction) { self.action = action }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(action.localizedTitle)")
    }
}

public struct WindowActionQuery: EntityQuery {
    public init() {}
    public func entities(for identifiers: [WindowActionEntity.ID]) async -> [WindowActionEntity] {
        WindowAction.allCases
            .filter { identifiers.contains($0.identifier) }
            .map(WindowActionEntity.init)
    }
    public func suggestedEntities() async -> [WindowActionEntity] {
        WindowAction.allCases.map(WindowActionEntity.init)
    }
}

#endif
