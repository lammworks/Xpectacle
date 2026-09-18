# Distribution

Releases from version 2.0.1 use Developer ID Application signing. Signing and Apple
notarization are separate; record the actual notarization result in release notes.
The earlier 2.0.0 compatibility preview was ad-hoc signed and not notarized.
Updates are manual through the GitHub Releases menu item. Automatic updates are
intentionally disabled until a signed update feed is configured.

## Build a reproducible release

Requirements: macOS, full Xcode, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).
The app and package pin KeyboardShortcuts 2.4.0. The app supports macOS 14+.

```bash
# Select the installed full Xcode for this command without changing system settings.
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
# Choose a fresh output directory for each release build.
export XPECTACLE_BUILD_DIR=/tmp/xpectacle-release-2.0.2
export XPECTACLE_SIGNING_IDENTITY='Developer ID Application: Ondemand Technologies Inc (K567UPF58F)'
export XPECTACLE_NOTARY_PROFILE='lavanda-notary'
./Xpectacle2026/scripts/build-release.sh
```

The script runs package tests, generates the Xcode project, builds arm64 + x86_64,
assembles the app and license, signs it, verifies the binary and signature,
creates/verifies and signs the DMG, and writes SHA256SUMS.txt. It does not publish
anything. Omitting the signing identity builds an ad-hoc development artifact;
do not publish that as the signed release.

The DMG contains the app, Applications shortcut, and installation instructions.
Attach the DMG and SHA256SUMS.txt to the GitHub release for the exact source commit.
Download the published asset again and compare its SHA-256 before declaring success.

## Developer ID / notarized release

Install the project's Developer ID certificate and configure a notarytool Keychain
profile first. Then set both values before invoking the same script:

```bash
export XPECTACLE_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export XPECTACLE_NOTARY_PROFILE='lavanda-notary'
```

On the maintainer's Mac, `lavanda-notary` is the shared profile for Xpectacle and
Gaugelet in the default local data-protection Keychain. Do not pass an explicit
login Keychain for notarization; the Developer ID signing key lives separately
in the login Keychain. Validate access before building:

```bash
xcrun notarytool history --keychain-profile "$XPECTACLE_NOTARY_PROFILE"
```

Keep the Mac unlocked while using this profile. In the verified local setup,
notarytool reported that the profile was missing while the screen was locked;
the same profile authenticated successfully immediately after unlocking.

The script submits a ZIP of the signed app, staples its ticket, then creates,
signs, notarizes, and staples the DMG. Verify the downloaded DMG with `spctl` on a
clean Mac. Do not describe a release as notarized until submission is accepted
and both tickets validate.

## Acceptance checks

- All package tests and the universal Release build pass.
- DMG verifies and mounts; the app's signature and both architectures verify.
- Launch on Golden Gate; inspect menu and Settings tabs.
- Grant/revoke Accessibility and verify actions disable/recover.
- Test halves, corners, thirds, undo/redo, and snapping in more than one app.
- Test two physical displays, full-screen Spaces, Stage Manager, and login/reboot.
- Record untested cases explicitly in release notes.
