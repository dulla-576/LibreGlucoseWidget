# Libre Glucose Lock Screen Widget

A native iPhone companion app and rectangular Lock Screen widget that shows the latest glucose value, the unit reported by LibreLinkUp, a trend arrow, and the reading's source time. The project targets iOS 26 and runs entirely on the phone; it has no developer-operated backend.

This is an independent, unofficial open-source project. It is not affiliated with, endorsed by, or supported by Abbott, FreeStyle Libre, or LibreLinkUp. Libre, FreeStyle Libre, and LibreLinkUp are trademarks of their respective owners.

## What it does

- Signs in to a LibreLinkUp follower account.
- Fetches the first shared profile's latest reading.
- Preserves Libre's unit without conversion.
- Shows the value, trend, local source time, and age in the app and widget.
- Marks a reading `STALE` only when its source timestamp is more than 60 minutes old.
- Requests another widget timeline after 15 minutes. WidgetKit controls the actual schedule, so updates can be later.
- Keeps the LibreLinkUp password and session in the device-only Keychain and the latest normalized reading in the app's shared container.

## Requirements

- A Mac with Xcode 26.6 or newer.
- XcodeGen 
- An iPhone running iOS 26 or newer. 
- An Apple Account added to Xcode. 
- A LibreLinkUp follower account that already sees the sensor owner's readings in the official LibreLinkUp app. 

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

The widget displays health information while the Lock Screen is visible. Only add it if that visibility is acceptable to you. Tapping it opens the companion app.

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

## Publishing

Personal installation is a development build.
