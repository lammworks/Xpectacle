# Xpectacle

A native macOS window manager based on Spectacle. The maintained app is in
[`Xpectacle2026/`](Xpectacle2026/), with SwiftUI settings, keyboard shortcuts,
window snapping, named layouts, and undo/redo.

## Download

Get the DMG from [GitHub Releases](https://github.com/lammworks/Xpectacle/releases).
The initial 2.0.0 Golden Gate compatibility release is a preview: it is ad-hoc
signed and **not notarized**. Read its release notes and installation instructions.

Requires macOS 14 or newer. The DMG includes native Apple Silicon and Intel code.
Development and compatibility checks use Xcode 27 and macOS 27 Golden Gate.

## Build and verify

```bash
# Requires full Xcode and XcodeGen (brew install xcodegen).
cd Xpectacle2026
xcodegen generate
open Xpectacle.xcodeproj
```

Run tests and create a verified DMG with the [release script](Xpectacle2026/scripts/build-release.sh).
See [build and release documentation](Xpectacle2026/distribution/README.md) for
signing, notarization, and acceptance checks.

## Permissions and operation

Grant Accessibility access in System Settings > Privacy & Security > Accessibility.
Use the menu bar icon for Settings. Xpectacle does not need Screen Recording or
Apple Events permission. Quit other window managers if their shortcuts conflict.

Updates are manual through GitHub Releases. Windows may enforce minimum sizes;
Xpectacle respects application constraints. Layouts apply to already-open windows.

## Project history and license

The original Objective-C Spectacle source remains for reference; its Xcode project
is not the maintained app. [Legacy documentation](docs/LEGACY-SPECTACLE.md).
Xpectacle preserves Spectacle's MIT license and attribution; see [LICENSE.md](LICENSE.md).
