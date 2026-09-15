# Migrating from Spectacle to Xpectacle

## What carries over

On a fresh installation, Xpectacle imports matching shortcuts from:

1. The `com.divisiblebyzero.Spectacle` preferences domain, including historical archived shortcut class names.
2. `~/Library/Application Support/Spectacle/Shortcuts.json`, whose name/key-binding entries take precedence over archived preferences.

The importer converts archived Carbon modifiers to Cocoa modifiers, handles the `A` key's zero key code, and preserves explicitly cleared shortcuts. Halves, corners, maximize, center, display movement, undo, and redo retain their bindings. `MoveToNextThird` maps to horizontal thirds.

A dedicated `Xpectacle.shortcutMigrationCompleted.v1` preference records completion. Migration does not repeat every launch, and an existing rewrite settings file prevents old preferences from overwriting the user's new choices. Removing `settings.json` alone does not reset shortcuts or trigger migration.

Fresh installations receive Spectacle's default shortcuts for supported matching actions. Imported custom choices take precedence. Quit Spectacle before using Xpectacle so the two applications do not compete for the same global shortcuts. Grant Xpectacle its own Accessibility permission in System Settings.

## Differences to review

| Spectacle feature | Current Xpectacle behavior |
|---|---|
| Halves, corners, maximize, center | Available from the menu and configurable shortcuts |
| Thirds | Forward horizontal and vertical cycling |
| Previous third | No equivalent reverse action; its legacy shortcut is not imported |
| Make larger / smaller | Directional extend/shrink actions; old symmetric-resize bindings are not imported |
| Next / previous display | Preserves relative position and size on the target display |
| Undo / redo | Per-window history; failed moves do not advance history |
| Disabled applications | Bundle identifiers configurable in Settings |
| Stage Manager | Uses the system-reported available display frame; no guessed shelf inset |

## Storage and updates

- General settings and saved layouts live at `~/Library/Application Support/Xpectacle/settings.json`.
- Keyboard shortcuts remain in the application's preferences, managed by `KeyboardShortcuts`; backing up the JSON settings file alone does not back up shortcuts.
- Older JSON settings retain their existing values when new fields are introduced. An unreadable file is preserved in a sibling `settings.unreadable-<UUID>.json` backup before replacement.
- The app's bundle identifier is `com.xpectacle.Xpectacle`, separate from Spectacle. Its Accessibility permission and launch-at-login registration are separate too.
- “Check for Updates” opens this project's GitHub Releases page. The app does not claim an unconfigured signed automatic-update feed.
