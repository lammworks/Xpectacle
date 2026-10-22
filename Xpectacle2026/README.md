# Xpectacle 2026

The maintained Swift/SwiftUI app, targeting macOS 14+ and tested with the macOS 27
Golden Gate SDK. Source language mode is Swift 5.10 with complete concurrency
checking; the project does not claim Swift 6 language-mode conformance.

## Build

```bash
xcodegen generate
open Xpectacle.xcodeproj
```

For a universal release DMG, run `./scripts/build-release.sh` from this directory.
See [distribution/README.md](distribution/README.md). The only external runtime
package is KeyboardShortcuts 2.4.0, pinned in both package and XcodeGen manifests.
The icon and MIT attribution are retained from Spectacle.

## Architecture

- `App/`: menu bar, Settings, preview overlay, login service, and lifecycle.
- `Packages/XpectacleCore/Accessibility`: typed public AX API wrappers.
- `Geometry`: pure window positions and stable display identification.
- `WindowController`: serialized moves and per-window history.
- `Movers`: application size-constraint handling.
- `Tiling`: window-drag detection and delayed snap previews.
- `Storage`: persistent settings and Spectacle shortcut import.
- `Intents`: Shortcuts / App Intents entry points.
- `Layouts`: normalized placement of existing application windows.

Geometry uses AppKit coordinates; AX coordinates are converted at the boundary.
Visible screen bounds come from AppKit. No direct TCC database access or private
window-server API is used.

## Window shortcuts

- Press **Command + Option + Left** repeatedly to cycle the focused window
  through the left **1/2 → 2/3 → 1/3 → 1/2** of the usable display, matching
  Spectacle's familiar order.
- **Command + Option + Right** cycles the same widths, anchored to the right.
  Pair two-thirds on one side with one-third on the other for an ultrawide layout.
- **Command + Option + C** centers the window while keeping its size.
- The separate horizontal thirds action moves a one-third-width window among
  the left, middle, and right slots. Drag snapping to a side stays at one half.

Each window keeps its own side-width cycle. Moving or resizing it manually,
changing its display or available display bounds, or using another action on
that window restarts the cycle at one half. Application minimum sizes still
apply; when an app accepts a move but constrains its size, the next shortcut
still advances to the following size. An Accessibility error leaves the cycle
unchanged.

## Verification

```bash
cd Packages/XpectacleCore
swift test --build-system native
```

These tests require macOS because the package imports AppKit/ApplicationServices.
CI runs the package tests and a universal app build. Local compatibility evidence
and remaining manual checks belong in the release notes.

## Distribution limits

Version 2.0.3 uses Developer ID signing and Apple notarization. Upgrading from the
earlier ad-hoc preview may require refreshing Xpectacle's existing Accessibility
permission once. The Permissions tab explains this recovery. Each release records its
verification results and any remaining runtime limitations.

Updates open GitHub Releases; there is no background downloader or automatic
installer. The release script supports Developer ID signing and optional Apple
notarization through a local Keychain credential profile.
