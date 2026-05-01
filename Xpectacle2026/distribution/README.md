# Distribution

## One-time setup

1. Generate Sparkle EdDSA keys:
   ```bash
   ./scripts/generate_keys
   ```
   This prints a public key — paste it into `project.yml` under `SUPublicEDKey` and re-run `xcodegen`.

2. Apple Developer ID signing certificate installed in Keychain.

## Release flow

```bash
xcodegen                      # regen project from project.yml
xcodebuild -scheme Xpectacle -configuration Release -archivePath build/Xpectacle.xcarchive archive
xcodebuild -exportArchive -archivePath build/Xpectacle.xcarchive \
    -exportOptionsPlist distribution/exportOptions.plist \
    -exportPath build/Export

# Sign + notarize
xcrun notarytool submit build/Export/Xpectacle.app --keychain-profile "AC_PROFILE" --wait
xcrun stapler staple build/Export/Xpectacle.app

# Build DMG
hdiutil create -volname Xpectacle -srcfolder build/Export/Xpectacle.app -ov -format UDZO build/Xpectacle-2.0.0.dmg

# Sparkle signature
./scripts/sign_update build/Xpectacle-2.0.0.dmg
# → outputs sparkle:edSignature attribute; paste into appcast.xml
```

## Hosting the appcast

Push `appcast.xml` and the `.dmg` to the `gh-pages` branch of `lammworks/xpectacle`. The app's `SUFeedURL` points at `https://lammworks.github.io/xpectacle/appcast.xml`.
