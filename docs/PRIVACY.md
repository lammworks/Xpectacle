# Privacy

This describes the maintained Xpectacle 2.0.2 app in `Xpectacle2026/`, based on its
source code. Historical Spectacle code in this repository is not shipped as the
current app.

## What Accessibility access means

macOS Accessibility access is a broad permission: it can allow an app to inspect
and control accessible interface elements in other apps. It is not a permission
limited by macOS to window size and position.

Xpectacle uses that permission to identify windows, read their position and size,
check whether they can move or resize, and set their position and size. Layouts
also read window titles so a saved arrangement can match the right windows.
Edge snapping inspects the accessible element under the pointer to find its
containing window.

The maintained app does not implement document-content scraping, screenshot
capture, or typed-text recording. It registers selected global shortcuts and,
when edge snapping is enabled, observes mouse-down, drag, and mouse-up events.
It does not request Screen Recording or Apple Events permission.

## What is stored on your Mac

| Data | Storage and use |
| --- | --- |
| Preferences, excluded app identifiers, and named layouts | `~/Library/Application Support/Xpectacle/settings.json` |
| Captured layout slots | App identifiers, window-title matching patterns, display indexes, and normalized window positions in the same settings file |
| Keyboard shortcuts and migration marker | macOS preferences for `com.xpectacle.Xpectacle`, using KeyboardShortcuts and UserDefaults |
| Recent window moves | In memory for undo/redo; not written to a move-history file |
| Unreadable settings backup | A `settings.unreadable-<identifier>.json` file beside settings, created before replacing unreadable settings |

**Window titles can contain document names, browser-page titles, or other sensitive
text.** “Capture Current Windows” saves exact title-matching patterns when a title
is available. The settings file is ordinary JSON, not encrypted by Xpectacle.
Access depends on your Mac's account, filesystem, and disk-security settings.

On first setup, Xpectacle may read existing Spectacle shortcut preferences and
`~/Library/Application Support/Spectacle/Shortcuts.json` to import bindings. It
does not need to upload those files.

Delete a saved layout in Settings to remove it from the active settings file.
Copies in backups or files you shared are separate. Quit Xpectacle before
manually changing or removing its local settings. Removing the app does not
automatically remove its preferences, saved layouts, or macOS permission entry.

## Network activity and external services

Xpectacle's maintained source has no account system, advertising, analytics,
telemetry uploader, cloud sync, or AI service integration. Window actions do not
require a project server or an Internet connection.

“Check for Updates…” opens the project's GitHub Releases page in your default
browser. Updates are downloaded and installed manually. Requests made by that
browser are subject to GitHub's and your browser's policies. macOS may separately
perform signing, notarization, or other system checks; this document does not
claim that your Mac makes no network requests while using the app.

Claude and ChatGPT helped develop the project. They are not part of the app's
window-control runtime, and the app does not send your windows to them.

## Support and diagnostics

Xpectacle does not automatically send diagnostic reports to the project.
macOS may record its own diagnostics, and the shortcut library can log shortcut
registration errors locally. GitHub issues and anything you attach there are
public. Review screenshots, logs, and settings before sharing them; redact titles,
names, and unrelated information.

You can revoke Xpectacle's access at any time in System Settings → Privacy &
Security → Accessibility (called Device Control and Data Access on macOS 27).
Window control stops working without that access. See [Support](SUPPORT.md) for
permission and installation help.
