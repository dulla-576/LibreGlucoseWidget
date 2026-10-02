# Libre Glucose Lock Screen Widget Design

## Summary

Build a personal iPhone app and rectangular Lock Screen widget for iOS 26. The widget displays the latest glucose reading shared through the user's German LibreLinkUp account, including the value, Libre-configured unit, trend arrow, and source timestamp. It is a convenience display only, not an alarm, diagnostic tool, dosing aid, or replacement for the official Libre app.

The first version runs entirely on the iPhone and uses LibreLinkUp's undocumented European service interface. This is acceptable to the user for personal use, with the explicit understanding that Abbott may change or block the interface. Public distribution is outside this version's scope and would require an authorized Abbott integration plus App Store privacy and medical-app review work.

## Goals

- Show the newest available Libre 3 glucose reading in an `accessoryRectangular` Lock Screen widget.
- Show the reading's trend direction and the same unit configured by Libre (`mg/dL` or `mmol/L`).
- Always show the source reading time and its age so delayed data is unambiguous.
- Refresh opportunistically through WidgetKit, accepting an expected real-world interval of roughly 15–60 minutes.
- Retain the last successful, timestamped reading when the network or upstream service is unavailable.
- Keep LibreLinkUp credentials and session material on the device in Keychain.
- Keep the LibreLinkUp implementation replaceable through a narrow data-source interface.
- Support development signing with a free Apple Developer account, including its approximately seven-day reprovisioning requirement.

## Non-goals

- Real-time or one-minute glucose updates.
- Glucose alarms, notifications, predictions, treatment recommendations, or insulin calculations.
- Direct Bluetooth communication with the Libre sensor.
- Charts, historical analytics, multiple followed profiles, Apple Watch support, or Home Screen widgets.
- Always-On-specific behavior.
- A hosted backend, Nightscout deployment, analytics, advertising, or third-party data collection.
- App Store, TestFlight, or public distribution in the first version.

## User Experience

### Companion app

The SwiftUI companion app has three states:

1. **Signed out:** Presents LibreLinkUp email and password fields, a concise personal-use disclaimer, and a sign-in button.
2. **Connected:** Shows the selected shared profile, latest normalized reading, source time, last refresh result, and a manual refresh button.
3. **Needs attention:** Explains authentication or upstream failures and offers reconnect or sign-out without discarding the last cached reading until the user signs out.

The app automatically selects the first LibreLinkUp connection. Supporting profile selection is intentionally deferred. Signing out removes credentials, tokens, connection metadata, and cached glucose data, then reloads the widget.

### Lock Screen widget

The widget uses the rectangular Lock Screen family only.

- Primary line: glucose value, unit, and semantic trend arrow, for example `112 mg/dL  →`.
- Secondary line: absolute local source time and relative age, for example `14:32 · 8 min ago`.
- A reading older than 60 minutes is explicitly rendered as `STALE · 14:32`.
- A failed refresh continues to show the last successful reading with its original timestamp.
- With no cached reading and no valid session, the widget displays `Open app to reconnect`.
- Tapping the widget opens the companion app.

The view uses system typography, tinting, and accessibility behavior. No dedicated Always-On implementation is included. The layout must remain readable with larger accessibility text sizes and monochrome Lock Screen rendering.

## Architecture

### Targets

- `LibreGlucoseWidgetApp`: SwiftUI iOS application.
- `LibreGlucoseLockWidget`: WidgetKit extension supporting `accessoryRectangular`.
- Shared Swift sources compiled into both targets for domain models, caching, networking abstractions, and formatting rules.
- Unit-test target for all non-UI behavior.

### Core boundaries

`GlucoseDataSource` exposes authentication state and a single operation that returns the latest normalized `GlucoseReading`. The UI and widget do not depend on LibreLinkUp response types or endpoint details.

`LibreLinkUpClient` implements `GlucoseDataSource`. It authenticates against the European LibreLinkUp service, resolves the first shared connection, fetches the latest reading, and converts the undocumented response into the domain model. All endpoint paths, headers, raw response models, and raw trend codes remain inside this adapter.

`CredentialStore` reads and writes the LibreLinkUp email, password, and session material in a shared Keychain access group. Plaintext credentials must not be written to logs, app-group preferences, source files, or test fixtures.

`ReadingCache` stores only the latest normalized reading and minimal connection display metadata in the shared App Group container. Writes are atomic. Cached data uses file protection appropriate for data that must be readable by a Lock Screen widget after first device unlock.

`ReadingCoordinator` owns the fetch flow used by the companion app and widget:

1. Load credentials and any reusable session.
2. Request the latest reading through `GlucoseDataSource`.
3. If authentication has expired, perform one reauthentication attempt and retry once.
4. Normalize and validate the response.
5. Atomically update the cache and request a widget timeline reload when invoked by the app.
6. On failure, return a typed error plus the last cached reading, if present.

### Domain model

`GlucoseReading` contains:

- Decimal display value without avoidable floating-point formatting errors.
- Unit enum: `mgDL` or `mmolL`.
- Semantic trend enum: `rapidlyFalling`, `falling`, `slowlyFalling`, `steady`, `slowlyRising`, `rising`, `rapidlyRising`, or `unknown`.
- Source timestamp from LibreLinkUp.
- Optional upstream connection identifier used only internally.

Raw LibreLinkUp trend codes are converted to the semantic enum in the adapter. The widget maps semantic trends to familiar directional arrows. Unknown or absent trend data displays a neutral `?` rather than inventing a direction.

## Refresh and Timeline Behavior

The widget performs a network refresh when WidgetKit requests a timeline. It returns one current entry and asks WidgetKit for another refresh no sooner than 15 minutes later. This is a request, not a guarantee; iOS controls the actual schedule and may defer it according to the widget budget.

The timeline entry always carries the reading's source timestamp independently from the timeline-generation time. Relative age is derived from that source timestamp. The stale threshold is 60 minutes.

The companion app also refreshes when it becomes active and when the user taps manual refresh. A successful app refresh updates the shared cache and calls `WidgetCenter` to reload the widget timeline. No background push server or continuous background task is used.

## Error Handling

Errors are typed into these user-relevant categories:

- Invalid credentials or consent/terms action required.
- No shared LibreLinkUp connection.
- Session expired and reauthentication failed.
- Offline, timeout, or transient service failure.
- Rate limited by the upstream service.
- Unsupported or malformed upstream response, indicating a probable API change.
- Cache or Keychain access failure.

The companion app shows actionable, nontechnical messages while retaining diagnostic detail suitable for local debugging without secrets. The widget never shows raw errors. It displays the cached reading with the unchanged timestamp when possible, otherwise the reconnect/unavailable state.

## Security and Privacy

- All processing occurs on the iPhone; the project introduces no developer-operated server.
- Credentials and tokens use a Keychain group shared only by the app and its widget extension.
- The App Group cache contains the latest reading but no password or reusable authentication secret.
- Network access uses HTTPS and rejects non-success responses before parsing.
- Logs redact credentials, authorization tokens, patient identifiers, and response bodies containing health data.
- Sign-out deletes both Keychain and App Group data.
- The app states that it is an unofficial personal display and directs the user to the official Libre app for alarms and treatment decisions.

## Signing and Installation

The app and widget share App Group and Keychain Sharing entitlements. Apple currently permits these capabilities for free Apple Developer accounts. With a free Personal Team, development provisioning profiles expire after approximately seven days, so the user must rebuild or reinstall from Xcode regularly. Paid Apple Developer Program membership removes that short development-provisioning cycle and is required for TestFlight or App Store distribution.

The project defaults to `com.abdullah.libreglucosewidget` for the app, a derived identifier for the widget extension, and `group.com.abdullah.libreglucosewidget` for shared storage. These are build configuration values and can be changed if the user's Apple account reports an identifier collision.

## Testing and Acceptance Criteria

Automated tests use injected transports and sanitized response fixtures. They cover:

- Successful and failed authentication, including a single retry after session expiry.
- First-connection selection and the no-connection case.
- Parsing both units without conversion.
- Every supported raw trend mapping plus unknown values.
- Source timestamp parsing and local-time presentation.
- Fresh, delayed, and over-60-minute stale classification at boundary values.
- Cache round trips and preservation of cached data after network failure.
- Secret redaction and sign-out data removal.
- Widget view models for fresh, stale, signed-out, and unavailable states.

Widget previews cover the same visible states at standard and accessibility text sizes. Simulator and physical-device verification cover app launch, sign-in, manual refresh, offline fallback, widget installation on the Lock Screen, tap-through, sign-out, and re-signing with the free Personal Team.

The feature is accepted when a physical iPhone on iOS 26 can display the latest available LibreLinkUp reading, correct unit, correct trend arrow, and source timestamp in the rectangular Lock Screen widget; delayed or failed refreshes must never obscure the reading's true age.

## Known Risks

- Abbott does not provide this project with a supported public consumer API, and its terms restrict automated access. The personal integration may stop working or be blocked without notice.
- LibreLinkUp response formats, authentication steps, regional routing, or required headers can change. The adapter boundary and fixture-based tests limit the resulting code changes but cannot prevent service interruption.
- WidgetKit refresh timing is opportunistic. The application cannot guarantee a 15-minute update interval.
- Free development signing requires recurring installation maintenance.
