# Xpectacle 2026

A Swift 6 / SwiftUI rewrite of the legacy [Spectacle](https://github.com/eczarny/spectacle) macOS window manager. Native Apple Silicon, macOS 14 Sonoma+, and modernized for 2026.

## Status

Source-complete. The `.xcodeproj` is generated from `project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen) so it isn't checked in.

```bash
brew install xcodegen
cd Xpectacle2026
xcodegen
open Xpectacle.xcodeproj
```

Then in Xcode: select the `Xpectacle` scheme, Run. First launch will prompt for Accessibility access; grant it and the hotkeys, snap zones, layouts, and App Intents are all live. CI exercises the core package with `swift test` on `macos-14`.

## Why a rewrite

The original Spectacle was last updated in 2018:
- Pure Objective-C with manual `AXUIElementRef`/Carbon glue
- XIB-based UI and 18 IBOutlets in `SpectacleAppDelegate`
- Carthage + Sparkle 1.22
- macOS 10.9 deployment target

Xpectacle 2026 keeps all of Spectacle's geometry behavior — left/right/top/bottom halves, four corners, thirds with cycling, fullscreen, center, extend/shrink edges, next/previous display, undo/redo — and adds:

- **Drag-to-edge snap zones** with hover preview, similar to Magnet/Rectangle
- **Named layouts** stored in normalized space, applicable per display
- **App Intents** so every window action is callable from Shortcuts.app, Spotlight, and Siri
- **Stage Manager awareness** that respects the stage shelf
- **Sparkle 2** for notarized auto-updates
- A SwiftUI Settings scene with `KeyboardShortcuts.Recorder`

## Architecture

```
App/                  SwiftUI app target (MenuBarExtra + Settings scene)
Packages/XpectacleCore/
  Accessibility/      AXWindow, AXApplication wrappers around AXUIElement
  Geometry/           PositionCalculator (pure functions), ScreenDetector, WindowAction
  Movers/             StandardMover → QuantizedMover → BestEffortMover chain
  Hotkeys/            KeyboardShortcuts wrapper, one Name per WindowAction
  Storage/            Settings (Codable), SettingsStore (actor), LegacyImporter
  Tiling/             SnapZone, SnapHitTester, DragMonitor (CGEventTap-free)
  Layouts/            Layout, LayoutEngine (capture/apply)
  StageManager/       StageManagerProbe (defaults read of com.apple.WindowManager)
  Intents/            App Intents for every action + ApplyLayoutIntent
  History/            UndoStack (per-window ring buffer)
  Permissions/        Accessibility trust + System Settings deeplinks
  WindowController    Single actor that serializes all AX I/O
```

All Accessibility I/O is funneled through one `actor WindowController`. AX is not thread-safe and on Sonoma+ has surprising retry semantics around space/Stage Manager transitions; serialization avoids both classes of race.

## Migration from Spectacle

`LegacyImporter` reads the old `com.divisiblebyzero.Spectacle` `UserDefaults` domain and `~/Library/Application Support/Spectacle/Shortcuts.json`, mapping each archived `SpectacleShortcut` to a `KeyboardShortcuts.Name`. It runs once on first launch (detected by absence of `~/Library/Application Support/Xpectacle/settings.json`) so existing users keep their hotkeys.

## Build & test

```bash
# Run the cross-platform core tests (no Xcode required):
cd Packages/XpectacleCore && swift test

# Build the app (requires macOS 14+, Xcode 16+):
open Xpectacle.xcodeproj   # generated locally — see Status above
```

CI: `.github/workflows/ci.yml` runs `swift test` on `macos-14`.

## Distribution

Notarized DMG with Sparkle 2 EdDSA-signed appcast. Hardened runtime, no sandbox (Accessibility is not sandbox-compatible). MIT license, same as original Spectacle.

## License

MIT, same as the upstream Spectacle. See `../LICENSE.md`.
