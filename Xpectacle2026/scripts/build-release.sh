#!/bin/bash
set -euo pipefail

# Run from any directory. XcodeGen and a full Xcode installation are required.
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_DIR="$(cd "$PROJECT_DIR/.." && pwd)"
BUILD_DIR="${XPECTACLE_BUILD_DIR:-$PROJECT_DIR/build}"
mkdir -p "$BUILD_DIR"
BUILD_DIR="$(cd "$BUILD_DIR" && pwd)"
DERIVED_DIR="$BUILD_DIR/DerivedData"
STAGING_DIR="$BUILD_DIR/dmg-root"
APP_PATH="$STAGING_DIR/Xpectacle.app"
SIGNING_IDENTITY="${XPECTACLE_SIGNING_IDENTITY:--}"

command -v xcodegen >/dev/null
xcrun --find swift >/dev/null
mkdir -p "$BUILD_DIR"
cd "$PROJECT_DIR"

# Xcode 27's default swiftbuild currently fails code-signing some test bundles.
# The native runner exercises the same package and XCTest suites.
swift test --package-path Packages/XpectacleCore --build-system native \
  --scratch-path "$BUILD_DIR/tests"
xcodegen generate
xcodebuild -project Xpectacle.xcodeproj -scheme Xpectacle \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$DERIVED_DIR" CODE_SIGNING_ALLOWED=NO \
  'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build

if [[ -e "$STAGING_DIR" ]]; then
  echo "Staging directory already exists: $STAGING_DIR. Choose a fresh XPECTACLE_BUILD_DIR." >&2
  exit 1
fi
mkdir -p "$STAGING_DIR"
ditto --norsrc --noextattr "$DERIVED_DIR/Build/Products/Release/Xpectacle.app" "$APP_PATH"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  echo "Invalid CFBundleShortVersionString in built app: $VERSION" >&2
  exit 1
fi
KEYBOARD_SHORTCUTS_LICENSE="$PROJECT_DIR/distribution/ThirdPartyLicenses/KeyboardShortcuts-LICENSE.txt"
RESOLVED_KEYBOARD_SHORTCUTS_LICENSE="$DERIVED_DIR/SourcePackages/checkouts/KeyboardShortcuts/license"
if ! cmp -s "$KEYBOARD_SHORTCUTS_LICENSE" "$RESOLVED_KEYBOARD_SHORTCUTS_LICENSE"; then
  echo 'KeyboardShortcuts license is missing or differs from the resolved package. Update the bundled notice before releasing.' >&2
  exit 1
fi
mkdir -p "$APP_PATH/Contents/Resources/ThirdPartyLicenses" "$STAGING_DIR/Licenses"
install -m 644 "$REPO_DIR/LICENSE.md" "$APP_PATH/Contents/Resources/LICENSE.md"
install -m 644 "$REPO_DIR/LICENSE.md" "$STAGING_DIR/Licenses/LICENSE.md"
# Package-cache notices can be read-only. Staged copies need owner write access
# so metadata can be stripped before signing, without changing source notices.
install -m 644 "$KEYBOARD_SHORTCUTS_LICENSE" "$APP_PATH/Contents/Resources/ThirdPartyLicenses/KeyboardShortcuts-LICENSE.txt"
install -m 644 "$KEYBOARD_SHORTCUTS_LICENSE" "$STAGING_DIR/Licenses/KeyboardShortcuts-LICENSE.txt"
cp "$PROJECT_DIR/distribution/INSTALL.txt" "$STAGING_DIR/READ ME.txt"
ln -s /Applications "$STAGING_DIR/Applications"
# Strip filesystem metadata only from our newly built bundle before signing.
xattr -cr "$APP_PATH"
SIGN_OPTIONS=(--force --sign "$SIGNING_IDENTITY" --options runtime)
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  SIGN_OPTIONS+=(--timestamp=none)
else
  SIGN_OPTIONS+=(--timestamp)
fi
codesign "${SIGN_OPTIONS[@]}" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
ARCHITECTURES="$(lipo -archs "$APP_PATH/Contents/MacOS/Xpectacle")"
[[ " $ARCHITECTURES " == *" arm64 "* && " $ARCHITECTURES " == *" x86_64 "* ]]

if [[ -n "${XPECTACLE_NOTARY_PROFILE:-}" ]]; then
  if [[ "$SIGNING_IDENTITY" == "-" ]]; then
    echo 'Notarization requires XPECTACLE_SIGNING_IDENTITY to be a Developer ID identity.' >&2
    exit 1
  fi
  ditto -c -k --keepParent "$APP_PATH" "$BUILD_DIR/Xpectacle-notarization.zip"
  xcrun notarytool submit "$BUILD_DIR/Xpectacle-notarization.zip" \
    --keychain-profile "$XPECTACLE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
  spctl --assess --type execute --verbose=2 "$APP_PATH"
fi

DMG_PATH="$BUILD_DIR/Xpectacle-$VERSION.dmg"
hdiutil create -volname "Xpectacle $VERSION" -srcfolder "$STAGING_DIR" \
  -format UDZO "$DMG_PATH"
hdiutil verify "$DMG_PATH"
if [[ "$SIGNING_IDENTITY" != "-" ]]; then
  codesign --force --sign "$SIGNING_IDENTITY" --timestamp "$DMG_PATH"
  codesign --verify --strict --verbose=2 "$DMG_PATH"
fi
if [[ -n "${XPECTACLE_NOTARY_PROFILE:-}" ]]; then
  xcrun notarytool submit "$DMG_PATH" --keychain-profile "$XPECTACLE_NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG_PATH"
fi
(cd "$BUILD_DIR" && shasum -a 256 "Xpectacle-$VERSION.dmg" > SHA256SUMS.txt)
printf '\nBuilt %s\n' "$DMG_PATH"
if [[ "$SIGNING_IDENTITY" == "-" ]]; then
  echo 'Ad-hoc signed; NOT notarized. Publish only with that limitation disclosed.'
fi
