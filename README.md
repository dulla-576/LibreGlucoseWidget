# Libre Glucose Lock Screen Widget

A native iPhone companion app and rectangular Lock Screen widget that shows the latest glucose value, the unit reported by LibreLinkUp, a trend arrow, and the reading's source time. The project targets iOS 26 and runs entirely on the phone; it has no developer-operated backend.

This is an independent, unofficial open-source project. It is not affiliated with, endorsed by, or supported by Abbott, FreeStyle Libre, or LibreLinkUp. Libre, FreeStyle Libre, and LibreLinkUp are trademarks of their respective owners.

> This is a personal convenience display. It is not an alarm, a dosing aid, or a replacement for the official Libre app. Always use the official app and your clinician's guidance for treatment decisions.

## What it does

- Signs in to a LibreLinkUp follower account.
- Fetches the first shared profile's latest reading.
- Preserves Libre's `mg/dL` or `mmol/L` unit without conversion.
- Shows the value, trend, local source time, and age in the app and widget.
- Marks a reading `STALE` only when its source timestamp is more than 60 minutes old.
- Requests another widget timeline after 15 minutes. WidgetKit controls the actual schedule, so updates can be later.
- Keeps the LibreLinkUp password and session in the device-only Keychain and the latest normalized reading in the app's shared container.

## Requirements

- A Mac with Xcode 26.6 or newer.
- XcodeGen (`brew install xcodegen`).
- An iPhone running iOS 26 or newer. The intended iPhone 13 Pro is supported; it uses the normal Lock Screen widget flow and has no Always-On Display setup.
- An Apple Account added to Xcode. A free Personal Team can install development builds on your own devices, but its provisioning profiles expire after seven days and the app must then be rebuilt and reinstalled. If Xcode refuses the App Groups or Keychain Sharing entitlements for the free team, an Apple Developer Program membership is required.
- A LibreLinkUp follower account that already sees the sensor owner's readings in the official LibreLinkUp app. Do not use or share anyone else's credentials without their permission.

## Generate and open the project

1. Open Xcode once and accept its license and any requested platform installation.
2. From the repository root, generate the Xcode project:

   ```sh
   xcodegen generate
   ```

3. Open `LibreGlucoseWidget.xcodeproj`.

The generated `.xcodeproj` is committed for convenience, but `project.yml` is the source of truth. Run `xcodegen generate` again after changing project settings.

## Configure signing for your iPhone

1. In Xcode, select the `LibreGlucoseWidgetApp` target, open **Signing & Capabilities**, enable automatic signing, and choose your team.
2. Repeat for the `LibreGlucoseLockWidget` target using the same team.
3. If any identifier is already taken, replace the default identifiers with values unique to you:

   - App: `com.abdullah.libreglucosewidget`
   - Widget: `com.abdullah.libreglucosewidget.widget`
   - App Group: `group.com.abdullah.libreglucosewidget`

   Search before editing so every occurrence remains aligned:

   ```sh
   rg -n 'com\.abdullah\.libreglucosewidget|group\.com\.abdullah\.libreglucosewidget' \
     project.yml Config SharedIOS
   ```

   Change the two bundle identifiers and the shared App Group consistently in `project.yml`, both files in `Config/`, and `SharedIOS/Infrastructure/SharedContainer.swift`. Keep the widget bundle identifier as a child of the app identifier. Then run `xcodegen generate` again.
4. In both targets, confirm **App Groups** contains the same group and **Keychain Sharing** contains the same group. Let Xcode repair provisioning if prompted.
5. Connect the iPhone, select it as the run destination, and run the `LibreGlucoseWidgetApp` scheme.

With a free Personal Team, Apple limits free provisioning and the profile expires after seven days. Reconnect the phone and run the app from Xcode again when it expires.

## Connect LibreLinkUp

1. On the iPhone, open the installed app.
2. Enter the LibreLinkUp follower account email and password directly on the phone. Never put credentials in source files, screenshots, issues, or test fixtures.
3. Tap **Connect**. The app should show the shared profile and latest reading.
4. Use **Refresh now** to request a new reading. If the network is unavailable, the app and widget can show the last saved reading with its original timestamp.

LibreLinkUp access in this project uses an unofficial, undocumented interface. Abbott can change or disable it, require new terms, rate-limit it, or restrict accounts without notice. A service error is deliberately shown without logging credentials, tokens, patient identifiers, or raw glucose payloads.

## Add the Lock Screen widget

1. Touch and hold the iPhone Lock Screen, then tap **Customize** and choose **Lock Screen**.
2. Tap the widget area below the clock.
3. Choose **Libre Glucose** and add its rectangular widget.
4. Tap **Done**.

The widget displays health information while the Lock Screen is visible. Only add it if that visibility is acceptable to you. Tapping it opens the companion app. On the iPhone 13 Pro there is no Always-On Display step, and this project does not add one.

## Tests and local verification

Run package tests:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/libreglucose-swiftpm-module-cache \
CLANG_MODULE_CACHE_PATH=/private/tmp/libreglucose-clang-module-cache \
swift test --scratch-path /private/tmp/libreglucose-spm-build
```

Generate the project and build the app plus widget for the iPhone Simulator:

```sh
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project LibreGlucoseWidget.xcodeproj \
  -scheme LibreGlucoseWidgetApp \
  -sdk iphonesimulator \
  -derivedDataPath /private/tmp/libreglucose-widget-derived-data \
  CODE_SIGNING_ALLOWED=NO build
```

The generated app scheme also contains a lightweight integration test. Xcode tests require a concrete installed simulator, for example:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project LibreGlucoseWidget.xcodeproj \
  -scheme LibreGlucoseWidgetApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' \
  -derivedDataPath /private/tmp/libreglucose-widget-derived-data \
  CODE_SIGNING_ALLOWED=NO test
```

Replace the simulator name and OS with an installed simulator shown by `xcrun simctl list devices available`. This simulator choice does not limit installation on the iPhone 13 Pro.

See `docs/manual-test-checklist.md` for the final simulator and physical-device checks.

## Publishing later

Personal installation is a development build. Making this public would additionally require a paid Apple Developer Program membership, unique production identifiers, App Store Connect metadata and privacy disclosures, App Review, a support/privacy policy, and a sustainable security and maintenance process. The larger issue is LibreLinkUp: before distribution, obtain permission or a supported integration agreement from Abbott and have the API use and health-data handling reviewed. Do not ship a public app that depends on an undocumented service without that authorization.
