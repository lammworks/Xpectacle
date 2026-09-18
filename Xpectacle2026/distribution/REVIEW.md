# Golden Gate review — Xpectacle 2.0.0 preview

## Scope

Reviewed the Swift rewrite on `claude/apple-silicon-window-manager-3szMe`
(starting commit `7f9a4cb770b77dd1e1be330ed772bb59f2e4e6a1`), including its
app lifecycle, window geometry/Accessibility, shortcuts, storage, layouts,
App Intents, dependencies, and distribution. The legacy Objective-C source
remains reference material and is not part of this release binary.

## Findings addressed

| Area | Problem | Resolution |
|---|---|---|
| Distribution | Placeholder signing key/feed; CI app build did nothing | Manual GitHub updates, real universal build and verified DMG script |
| Drag snapping | Text/file drags could snap the wrong focused window | Capture original AX window, require actual movement, delay activation, use physical screen edges |
| Accessibility | Unchecked Core Foundation types and invalid geometry | Validate AX types, settable attributes, finite positive frames, and readable failures |
| Window history | Mutable titles collided; failed actions advanced history | AX identity, per-window bounded history, successful-move bookkeeping |
| Geometry | Thirds started in the middle; tiny-window shrinking moved opposite edge | Correct cycle and edge calculations with regression tests |
| Displays | Identical display names collided | Stable display IDs and nearest-screen recovery |
| Layouts | Bad indices/regex and repeated window selection | Validate matchers/indices and assign distinct windows |
| Settings | Missing keys discarded older settings; errors silently ignored | Default missing keys, serialize saves, preserve unreadable originals, display errors |
| Migration | Wrong Spectacle JSON/archive formats and modifier conversion | Read actual formats, preserve cleared shortcuts, one-time import |
| Permissions | Grant/revoke did not reconcile active services | Poll trust, stop/restart shortcuts and drag monitoring |
| Login items | Errors and approval requirements hidden | Show actual service status and approval/error feedback |
| Stage Manager | Undocumented hard-coded shelf inset | Respect the usable display area reported by AppKit |

## Verification scope

Build host: macOS 27.0 Golden Gate (26A5406e), Xcode 27.0 (27A5237l).
The app supports macOS 14+; its universal binary contains arm64 and x86_64.
Intel and older macOS runtime compatibility are not claimed as physically tested.

Automated regression suite: 50 Swift Testing tests plus 5 XCTest tests passed.
Cases cover geometry, layout validation, undo/redo transactions, migration,
storage failures, and distinguishing window moves from content drags/resizes.
Live desktop and package verification results are recorded in the release notes.

## Remaining limits

- Ad-hoc signed, not Developer ID signed or notarized; downloaded first launch
  can require an explicit Privacy & Security override.
- Real Accessibility interaction requires user-granted access. Unit tests do
  not prove real-window behavior for every application.
- Physical multi-display arrangements, full-screen Spaces, Stage Manager, and
  login/reboot require further manual testing.
- AX writes are best-effort remote operations, not atomic transactions.
  Applications can enforce minimum sizes or refuse movement.
- Legacy PreviousThird and symmetric MakeLarger/MakeSmaller shortcuts have no
  exact equivalent in the current rewrite and are not silently remapped.

## Installed-app permission investigation — 2026-09-16

On macOS 27.0 (26A428), System Settings showed Xpectacle enabled in Device
Control and Data Access, while the running installed app's public Accessibility
trust check returned false. Read-only `tccd` logs reported a failure to match
the saved code requirement for `com.xpectacle.Xpectacle` and
`kTCCServiceAccessibility`. The saved requirement belonged to an older build;
the installed bundle's current signature verified successfully.

This blocks shortcuts and drag monitoring before window movement runs. It is
not evidence of a missing Screen Recording permission or private entitlement.
Repair the existing grant by removing only Xpectacle from the privacy pane,
adding the installed app again, and reopening it. Ad-hoc builds can require this
again after updates; stable Developer ID signing is the distribution fix.

The app now exposes denied access through a warning menu-bar icon and a direct
Permissions action. That page reports actual trust, identifies the running app
path, and explains stale-grant recovery. Privacy settings remain under macOS
control; the app never edits the TCC database or grants itself access.

Live window movement remains pending the user's authentication of the permission
repair. A successful build or unit test does not establish that runtime result.

## Version 2.0.1 signing verification — 2026-09-17

- Built version 2.0.1 (build 2) on macOS 27.0 (26A428), Xcode 27.0 (27A266a).
- 50 Swift Testing tests and 5 XCTest tests passed; universal Release build passed.
- App and DMG signed with Developer ID Application: Ondemand Technologies Inc
  (K567UPF58F), with secure timestamps. The app uses hardened runtime.
- Strict signature verification passed. The app's designated requirement uses
  its bundle ID, Apple's Developer ID certificate chain, and team K567UPF58F,
  rather than a build-specific ad-hoc hash.
- DMG checksum verification and read-only mount passed.
- Apple notarization credentials were unavailable. Gatekeeper assessment reports
  `Unnotarized Developer ID`; this is a signed, unnotarized compatibility preview.
- Real window movement, physical multi-display behavior, Stage Manager, and
  login/reboot remain outside this release's verified runtime scope.

## Apple sources checked

- [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)
- [Golden Gate enterprise changes](https://support.apple.com/en-ge/148830)

The app uses public Accessibility APIs, has native Apple Silicon code, and does
not access the TCC database directly. Golden Gate's menu-bar overflow remains
managed by macOS.
