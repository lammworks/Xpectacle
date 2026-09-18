# Contributing to Xpectacle

Thank you for helping keep a useful Mac workflow available. Reproducible bug
reports, compatibility checks, documentation improvements, and focused code
changes are welcome. Xpectacle is an independent project inspired by Spectacle;
please report current app issues here rather than to Spectacle's original author.

## Report an issue

Check [Support](docs/SUPPORT.md) and search existing
[issues](https://github.com/lammworks/Xpectacle/issues) first. Use the bug-report
or feature-request template and describe one problem or proposal at a time.

For a bug, include the Xpectacle version, macOS version, Apple Silicon or Intel,
affected app, display setup, reproduction steps, and expected versus actual
behavior. Tell us whether Xpectacle's Permissions tab reports **Access granted**.
Screenshots or a short recording help when they show the problem safely.

GitHub issues are public. Remove personal information from screenshots and logs.
Saved layout settings can contain document names and other window titles; do not
attach an unreviewed settings file. See [Privacy](docs/PRIVACY.md).

## Build the maintained app

The current Swift/SwiftUI implementation is in **`Xpectacle2026/`**. The root-level
Objective-C project and its old tests are historical Spectacle source, not the
current build. See the [architecture overview](Xpectacle2026/README.md).

You need a Mac, full Xcode with a macOS SDK supporting the deployment target,
and [XcodeGen](https://github.com/yonaskolb/XcodeGen). The deployment target is
macOS 14; the source uses Swift 5.10 language mode. CI is the reference for the
current build commands.

```sh
# From the repository root:
cd Xpectacle2026
xcodegen generate
open Xpectacle.xcodeproj
```

Choose the **Xpectacle** scheme in Xcode and configure your local signing as
needed to run. The generated project is derived from `project.yml`; make shared
project configuration changes there. KeyboardShortcuts is pinned to 2.4.0.

A locally rebuilt app has a different signing identity from the published app.
Use a separate development copy, and expect macOS to require its own Accessibility
approval. Avoid replacing a working installation just to test a patch.

## Verify a change

Run the core tests from the repository root:

```sh
cd Xpectacle2026/Packages/XpectacleCore
swift test --build-system native
```

For the same unsigned universal build used by CI, start from the repository root:

```sh
cd Xpectacle2026
xcodegen generate
xcodebuild -project Xpectacle.xcodeproj -scheme Xpectacle \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build
```

Tests cover core logic; they do not prove that real apps, permission prompts,
multiple displays, Stage Manager, or login behavior work. For changes affecting
those paths, record the manual scenarios you tried and what remains untested.
Add regression tests when they meaningfully exercise changed behavior. Pure
documentation changes do not require an app build.

## Submit a pull request

1. Fork the repository and create a branch from `master`.
2. Keep the change focused and match the surrounding Swift style.
3. Preserve existing shortcuts, settings compatibility, and permission boundaries
   unless changing them is the stated purpose of the patch.
4. Explain the user-visible problem, resulting behavior, verification, and any
   limitations. Include screenshots for visual changes.
5. Keep credentials, signing files, personal layouts, and local build artifacts
   out of the commit.

Do not modify old Spectacle source just to modernize its formatting. Preserve
license and attribution notices. By contributing, you agree that your contribution
is available under the project's [MIT license](LICENSE.md).

## Release work

Signing, notarization, packaging, and public-download verification are described
in the [release documentation](Xpectacle2026/distribution/README.md). A successful
build alone is not a distribution-ready release. Contributors do not need the
maintainer's signing certificate or notarization credentials to submit changes.
