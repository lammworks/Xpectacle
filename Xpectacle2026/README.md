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

## Verification

```bash
cd Packages/XpectacleCore
swift test --build-system native
```

These tests require macOS because the package imports AppKit/ApplicationServices.
CI runs the package tests and a universal app build. Local compatibility evidence
and remaining manual checks belong in the release notes.

## Distribution limits

Version 2.0.1 uses Developer ID signing. Upgrading from the earlier ad-hoc
preview may require refreshing Xpectacle's existing Accessibility permission
once. The Permissions tab explains this recovery. Notarization status is recorded
in each GitHub release; signing alone does not imply notarization.

Updates open GitHub Releases; there is no background downloader or automatic
installer. The release script supports Developer ID signing and optional Apple
notarization through a local Keychain credential profile.
