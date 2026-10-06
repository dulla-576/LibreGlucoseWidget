# Manual verification checklist

Use synthetic values for simulator checks. Enter real LibreLinkUp credentials only on the user's iPhone. Never paste credentials, tokens, patient identifiers, sensor serials, or raw health payloads into this document, logs, issues, or screenshots.

## Recorded local verification — 2026-10-06

- [x] Xcode 26.6 license/toolchain check passed.
- [x] XcodeGen project generation passed.
- [x] Swift package suite passed: 37 tests, 0 failures.
- [x] Unsigned iPhone Simulator app and widget build passed.
- [x] Generated Xcode scheme integration test passed on an iPhone 17 Pro simulator: 1 test, 0 failures.
- [x] Widget extension plist contains `com.apple.widgetkit-extension`.
- [x] App plist registers the `libreglucose` URL scheme.
- [x] Widget preview configurations compile for fresh, delayed, stale, reconnect, unavailable, and accessibility-size states.
- [x] Secret/log scan found no credential-bearing logging or committed live health values.

## Simulator visual checks

Open the SwiftUI previews in Xcode and use only the included synthetic readings.

- [ ] Signed-out form is readable and the password field is secure.
- [ ] Connected app state shows value, unit, arrow, timestamp, and age without clipping.
- [ ] Needs-attention state provides retry and reconnect actions.
- [ ] Fresh widget preview shows value, unit, arrow, timestamp, and age.
- [ ] Delayed widget preview remains readable.
- [ ] Stale widget preview visibly says `STALE` and includes the source time.
- [ ] Reconnect and unavailable previews have clear, non-sensitive text.
- [ ] Accessibility-size preview remains understandable without overlapping text.
- [ ] Light and dark appearances remain legible.

## Physical iPhone checks

Prerequisites: both targets use the same signing team, App Group, and Keychain sharing group. The iPhone 13 Pro runs iOS 26 or later. The follower account already shows readings in LibreLinkUp.

- [ ] The app installs and launches on the iPhone.
- [ ] Signing in with credentials entered directly on-device loads the expected shared profile.
- [ ] The app shows the same value and unit as LibreLinkUp.
- [ ] The trend arrow matches LibreLinkUp.
- [ ] The displayed source timestamp is correct in the phone's current time zone.
- [ ] **Refresh now** requests and displays a current reading.
- [ ] The rectangular widget can be added below the Lock Screen clock.
- [ ] The widget shows value, unit, trend, and timestamp while the phone is locked.
- [ ] Tapping the widget opens the companion app.
- [ ] With networking disabled, the last saved reading remains visible with its original timestamp/age.
- [ ] A reading older than 60 minutes is marked `STALE`.
- [ ] Re-enabling networking and refreshing replaces the cached reading.
- [ ] Signing out removes the app reading and causes the widget to request reconnection.
- [ ] After a device restart, the widget becomes available after the first unlock.

## Safety acceptance

- [ ] The user understands that WidgetKit controls refresh timing and may update later than the requested 15 minutes.
- [ ] The user accepts that glucose information is visible on the Lock Screen.
- [ ] The user will use the official Libre app for alarms, treatment decisions, and confirmation of unexpected readings.
- [ ] No credentials or real health data were added to Git.
