# Architecture

## Module dependency direction

```
                ┌────────────────────────────────────┐
                │             App target              │  SwiftUI, AppKit
                │   XpectacleApp · AppModel · Views   │
                └─────────────────┬───────────────────┘
                                  │ depends on
                ┌─────────────────▼───────────────────┐
                │            XpectacleCore             │  one SPM target
                │                                      │
                │  WindowController (actor)            │
                │   ├─ Accessibility (AXWindow/App)    │
                │   ├─ Geometry (PositionCalculator)   │
                │   ├─ Movers (Standard/Quant/BestEff) │
                │   ├─ Hotkeys (KeyboardShortcuts)     │
                │   ├─ Storage (Settings, Importer)    │
                │   ├─ Tiling (SnapZone, DragMonitor)  │
                │   ├─ Layouts (Layout, LayoutEngine)  │
                │   ├─ StageManager (Probe)            │
                │   ├─ Intents (App Intents)           │
                │   ├─ History (UndoStack)             │
                │   └─ Permissions                     │
                └──────────────────────────────────────┘
```

Geometry and storage are AppKit-free so they are exercised by `swift test` on plain `macos-14` runners without launching a UI.

## Concurrency

- `WindowController`, `SettingsStore`, `LayoutEngine` are `actor`s. They serialize all AX I/O and JSON file writes.
- `HotkeyService`, `DragMonitor`, all SwiftUI views are `@MainActor`.
- The package is compiled with Swift 6 strict concurrency. There are no shared mutable globals — `WindowController.shared` is a process-wide actor.

## Why a single AX actor

`AXUIElementCopyAttributeValue` and `AXUIElementSetAttributeValue` are technically thread-safe per Apple docs, but on Sonoma+ both calls can stall for hundreds of ms when the active space is mid-transition (Stage Manager, Mission Control). Concurrent calls from multiple threads compound the stalls and occasionally produce stale frame reads. A single serial actor avoids this without a meaningful throughput cost — humans don't trigger more than a few actions per second.

## Coordinate spaces

- AX uses **top-left origin** of the primary display. Positive y goes down.
- AppKit (`NSScreen`, `CGRect.integral`) uses **bottom-left origin** of the primary display. Positive y goes up.
- All geometry math is in AppKit space. Conversion happens at the AX boundary in `AXWindow.flip(_:primaryHeight:)`.

## Testing strategy

- Geometry, Screen detection, Undo, Snap zones, Normalized rects: pure-Swift unit tests under `XpectacleCoreTests`. No AppKit, no AX, runs on any Mac runner.
- Movers: protocol-based; tests inject a fake `AXWindow` (TODO once the Xcode project is generated and AX can be linked under XCTest as well).
- App-level UI: manual smoke testing per the verification checklist in `MIGRATION.md`.
