# Xpectacle support

## Install or update

1. Download the DMG from [GitHub Releases](https://github.com/lammworks/Xpectacle/releases).
   The current 2.0.2 compatibility preview is Developer ID signed and Apple
   notarized, for macOS 14 or later on Apple Silicon and Intel.
2. Quit any running copy of Xpectacle.
3. Open the DMG and copy Xpectacle to Applications, replacing the older app if
   needed. Open `/Applications/Xpectacle.app`, then eject the DMG.
4. Open Xpectacle's menu-bar icon → **Settings → Permissions** and follow the
   permission instructions.

Updates are manual. **Check for Updates…** opens GitHub Releases; it does not check
a version feed, download a package, or install it for you.

## Why does macOS ask whether I want to open it?

“Downloaded from the Internet” is a normal first-launch confirmation. Click
**Open** for the copy you downloaded from this repository. A signed, notarized app
can still show that confirmation. Signing identifies the publisher; notarization
checks a submitted build and does not guarantee all its features work.

The signing identity for the published 2.0.2 app is **Developer ID Application:
Ondemand Technologies Inc (K567UPF58F)**. This is the developer account used to sign
Xpectacle, not the original Spectacle creator's identity.

If macOS instead says the app is damaged or cannot be checked, download the current
release again and report the exact message. Do not disable Gatekeeper to install
Xpectacle.

## I cannot find the app

Xpectacle runs in the **menu bar** by default; it does not open a main document
window. Use its icon for window actions, Settings, and Quit. **Settings → General →
Show in Dock** is optional. A warning-triangle menu icon means window control is
blocked until permission is granted.

## Access is required even though the switch is on

macOS can retain an Accessibility grant for an older, differently signed copy.
This is especially relevant when upgrading from an early ad-hoc signed preview.

1. In Xpectacle, open **Settings → Permissions** and check **This copy of
   Xpectacle**. Use **Show in Finder** to confirm you are running the installed copy.
2. Open System Settings → Privacy & Security → **Accessibility**. On macOS 27
   Golden Gate, the pane is called **Device Control and Data Access**.
3. Select the old Xpectacle entry and click **−**. Click **+**, choose the copy in
   Applications, and turn its switch on.
4. Quit Xpectacle and reopen that same copy. Its Permissions tab should report
   **Access granted**; use **Check Again** if needed.

No Screen Recording or Apple Events permission is required. Granting unrelated
permissions does not repair a stale Accessibility entry.

## A shortcut or window action does nothing

- Check **Settings → Permissions** first. Then focus a normal, resizable window
  and try the action from Xpectacle's menu.
- Check **Settings → Shortcuts** for the binding actually assigned. Imported
  Spectacle bindings or custom shortcuts may differ from the defaults.
- Temporarily quit other window managers or resolve a shortcut conflict.
- Check **Settings → General → Disabled Apps**. Individual window actions and
  edge snapping ignore the app identifiers listed there.
- Some apps expose incomplete Accessibility information, enforce minimum sizes,
  or have windows that cannot be moved. Include the affected app and window type
  in a bug report.

The action labeled **Fullscreen** fills the usable screen area. It does not enter
macOS's separate full-screen Space.

## Snapping or saved layouts behave unexpectedly

For snapping, enable **Settings → Snap Zones → Enable drag-to-edge snapping**.
Move the window itself to an edge, wait for the preview, then release. A click,
text drag, or window resize is not meant to trigger a snap.

Layouts act on **already-open windows**. They match the saved app and, when
available, the window title. A document or browser page whose title changed may
no longer match. Capturing a layout does not arrange for documents to be reopened.
The Disabled Apps list applies to individual actions and edge snapping; it is not
a filter for captured or applied layouts in 2.0.2.

## Launch at login

Enable **Settings → General → Launch at login**. If macOS requires approval, use
the app's **Open Login Items** button and approve Xpectacle there. The app shows
the system registration state rather than assuming the request succeeded.

## Report a problem

Search [existing issues](https://github.com/lammworks/Xpectacle/issues), then use
the **Bug report** template. Include:

- Xpectacle version, macOS version, and Apple Silicon or Intel.
- Affected app and version, display arrangement, and whether Stage Manager or a
  full-screen Space is involved.
- Steps to reproduce, expected behavior, actual behavior, and permission status.
- Whether the menu action works when the keyboard shortcut does not.

Never include credentials. Review screenshots, logs, and settings before posting:
captured layouts can contain sensitive window titles. See [Privacy](PRIVACY.md).
Support is community-based, with no guaranteed response time. Please direct
Xpectacle issues here rather than to Eric Czarny or the archived Spectacle project.
