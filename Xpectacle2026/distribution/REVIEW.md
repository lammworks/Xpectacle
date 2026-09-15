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

## Apple sources checked

- [macOS 27 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-27-release-notes)
- [Golden Gate enterprise changes](https://support.apple.com/en-ge/148830)

The app uses public Accessibility APIs, has native Apple Silicon code, and does
not access the TCC database directly. Golden Gate's menu-bar overflow remains
managed by macOS.
