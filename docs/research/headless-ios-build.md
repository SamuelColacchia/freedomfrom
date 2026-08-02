# Headless iOS build, sign, and install over SSH

## Verdict

Yes, this can be driven headlessly over SSH on Xcode 26 **if** the Mac already has the signing assets, the device is paired/trusted, and Apple has approved any managed capability such as Family Controls.

What works without the GUI:
- `xcodebuild` can do automatic signing headlessly with `-allowProvisioningUpdates`. Apple also documents `-allowProvisioningDeviceRegistration` and App Store Connect API-key auth flags. Source: Apple Developer Forum thread quoting the Xcode 26 help text: https://developer.apple.com/forums/thread/764554
- `xcodebuild` supports a device destination specifier of `platform=iOS,id=<udid>` for a physical iPhone/iPad. For archive builds, Apple recommends `generic/platform=iOS`. Sources: Xcode help (verified on `ssh mac`), and Apple docs on archive destinations: https://developer.apple.com/documentation/xcode/creating-a-multi-platform-binary-framework-bundle
- `xcrun devicectl` is the current Apple command-line path for install/launch on connected devices. On this Mac, `xcrun devicectl help` exposes `device install app` and `device process launch --console`. Apple’s Xcode 26 docs say to manage devices from shell scripts with `devicectl`: https://developer.apple.com/documentation/updates/xcode

## Exact headless sequence

This is the minimal command path for a cabled iPhone once the device is visible to CoreDevice and signing is already set up:

```sh
# one-time shell vars
SCHEME=FreedomFrom
APP_NAME=FreedomFrom
BUNDLE_ID=com.example.freedomfrom
UDID=<iphone-udid>
ASC_KEY_PATH=/path/to/AuthKey_ABC123.p8
ASC_KEY_ID=ABC123
ASC_ISSUER_ID=01234567-89ab-cdef-0123-456789abcdef
BUILD_DIR="$PWD/build"

# build + sign
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$BUILD_DIR/$SCHEME.xcarchive" \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  -authenticationKeyPath "$ASC_KEY_PATH" \
  -authenticationKeyID "$ASC_KEY_ID" \
  -authenticationKeyIssuerID "$ASC_ISSUER_ID" \
  archive

# install the signed .app from the archive
APP_PATH="$BUILD_DIR/$SCHEME.xcarchive/Products/Applications/$APP_NAME.app"
xcrun devicectl device install app --device "$UDID" "$APP_PATH"

# launch it
xcrun devicectl device process launch --device "$UDID" "$BUNDLE_ID" --console
```

Notes:
- `devicectl device install app` installs an app bundle with a `.app` extension. Source: `ssh mac 'xcrun devicectl help device install app'`.
- `devicectl device process launch` accepts a bundle identifier or path, and `--console` attaches stdout/stderr and waits for exit. Source: `ssh mac 'xcrun devicectl help device process launch'`.
- If you want a direct destination build rather than an archive, `xcodebuild` accepts `-destination 'platform=iOS,id=<udid>'`; I did not verify a separate install path for that output, so the archive path above is the conservative option.

## What still needs a human at the Mac

1. **Pair/trust the device and enable Developer Mode.** Apple documents pairing a physical device to Mac over cable in Device Hub, and says you may need to trust the computer and enable Developer Mode. It also says Wi-Fi deployment is possible only after pairing and only if the Mac and device are on the same IPv6 network. Sources: https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub and https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices
2. **Get Family Controls approved.** Apple says the Account Holder must request the Family Controls entitlement in Certificates, Identifiers & Profiles; Apple then adds it as a managed capability. Xcode can only use it after approval. Sources: https://developer.apple.com/documentation/familycontrols/requesting-the-family-controls-entitlement and https://developer.apple.com/help/account/reference/provisioning-with-managed-capabilities/
3. **Enable Family Controls on the App ID and target.** Xcode updates the app target entitlements file to include `com.apple.developer.family-controls = true`, and the App ID must also have the capability enabled. Sources: https://developer.apple.com/documentation/xcode/configuring-family-controls and https://developer.apple.com/help/account/capabilities/capability-requests/
4. **Keep the signing key readable to `codesign`.** On SSH sessions, `security unlock-keychain -p <password> <keychain>` is the non-GUI unlock path. Apple’s `security` man page says `set-key-partition-list` changes the key ACL, and that `apple:` must be in the partition list for `/usr/bin/codesign`. Sources from the local `man security` probe on `ssh mac` and the `security(1)` man page mirror: https://keith.github.io/xcode-man-pages/security.1.html.

## Keychain behavior

- I could not confirm a first-party doc that explicitly says an unlocked keychain survives reboot; operationally, `security unlock-keychain` is a per-session unlock.
- `security set-key-partition-list` changes the key ACL, so that part persists until the key or keychain is changed.
- A dedicated build keychain is therefore useful, but I could not confirm a first-party Apple doc that spells out the exact reboot behavior of a custom keychain versus the login keychain.

## Manual signing fallback

Manual signing can work headlessly once the provisioning profile already exists, but Apple’s docs say you must regenerate profiles when capabilities or registered devices change. That is the maintenance cost of manual signing. Sources: https://developer.apple.com/documentation/xcode/configuring-family-controls and https://developer.apple.com/help/account/reference/provisioning-with-managed-capabilities/

## Could not confirm

- I could not confirm any Apple-documented App Store Connect API for **requesting** or **enabling** the Family Controls capability. The docs route this through Certificates, Identifiers & Profiles and capability requests, while App Store Connect API keys are only documented by `xcodebuild` for provisioning updates.
- I could not confirm `ios-deploy` as current/supported on Xcode 26 from a first-party Apple source. The Apple-documented tool here is `devicectl`.
- I did not confirm a fully documented `devicectl` launch path for a newly built `.ipa`; the docs and local help I verified are for installing a `.app` bundle.

## Verified probes on `ssh mac`

- `xcodebuild -version` → Xcode 26.6 (Build 17F113).
- `xcodebuild -help` shows `-allowProvisioningUpdates`, `-allowProvisioningDeviceRegistration`, and App Store Connect authentication key flags.
- `xcrun devicectl help` shows `device install app` and `device process launch`.
- `xcrun devicectl list devices` returned `No devices found` at probe time, so a real run still depends on the iPhone being paired/visible.
