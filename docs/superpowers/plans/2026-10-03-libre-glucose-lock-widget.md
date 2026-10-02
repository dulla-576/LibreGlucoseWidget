# Libre Glucose Lock Screen Widget Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a personal iOS 26 companion app and rectangular Lock Screen widget that securely displays the latest LibreLinkUp glucose value, Libre-configured unit, trend arrow, and source timestamp.

**Architecture:** A dependency-free Swift package contains the domain, formatting, LibreLinkUp adapter, secure-storage abstractions, cache, and coordinator so those behaviors can be tested on macOS. A SwiftUI iOS app and WidgetKit extension consume that package, share credentials through Keychain and the last normalized reading through an App Group, and use WidgetKit's opportunistic 15-minute timeline request without claiming a guaranteed refresh rate.

**Tech Stack:** Swift 6.3, Swift Package Manager, SwiftUI, WidgetKit, Foundation/URLSession, Security/Keychain, CryptoKit, XCTest, Xcode 26.6, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-03-libre-glucose-lock-widget-design.md`

## Global Constraints

- Deployment target is iOS 26.0; the widget supports `accessoryRectangular` only.
- Use no third-party runtime packages and no developer-operated backend.
- Default identifiers are `com.abdullah.libreglucosewidget`, `com.abdullah.libreglucosewidget.widget`, and `group.com.abdullah.libreglucosewidget`.
- Preserve the unit reported by LibreLinkUp; do not convert between `mg/dL` and `mmol/L`.
- A reading becomes stale only when its source timestamp is more than 60 minutes old.
- Request the next WidgetKit timeline no sooner than 15 minutes; never promise that iOS will honor that time.
- Never log credentials, tokens, patient identifiers, or glucose response bodies.
- Never commit live credentials, identifiers, sensor serials, glucose readings, or timestamps; fixtures are synthetic.
- This is a personal convenience display, not an alarm, dosing aid, or replacement for the official Libre app.
- LibreLinkUp access is unofficial and must remain isolated behind `GlucoseDataSource`.
- Execution prerequisite: the user must open Xcode once and personally accept Apple's Xcode/SDK license; commands use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer` without changing the global developer directory.

## Review Focus

- Region redirects, including `eu`/`eu2`, must accept only valid `*.libreview.io` HTTPS hosts and retry login exactly once; covered in Task 3.
- LibreLinkUp may return HTTP 200 with service status `4` or `429`; these must become terms-required and rate-limited errors, not successful parses; covered in Task 3.
- Source timestamps around DST transitions or in either ISO-8601 or Libre's locale-like format must resolve deterministically; covered in Task 4.
- Unknown trend values must render `?` rather than a guessed medical direction; covered in Tasks 2 and 4.
- Future timestamps caused by small clock skew must show age zero and remain fresh; covered in Task 2.

---

### Task 1: Reproducible project scaffold

**Files:**
- Create: `Package.swift`
- Create: `project.yml`
- Create: `.gitignore`
- Create: `Config/Shared.xcconfig`
- Create: `App/Info.plist`
- Create: `App/LibreGlucoseWidgetApp.swift`
- Create: `Widget/Info.plist`
- Create: `Widget/LibreGlucoseLockWidget.swift`
- Create: `Tests/LibreGlucoseCoreTests/ScaffoldTests.swift`

**Interfaces:**
- Consumes: approved design and identifiers from Global Constraints.
- Produces: local package product `LibreGlucoseCore`, app target `LibreGlucoseWidgetApp`, widget target `LibreGlucoseLockWidget`, and shared schemes usable by later tasks.

- [ ] **Step 1: Verify the user has accepted the Xcode license**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -version`
Expected: `Xcode 26.6` without a license-agreement error. If the error remains, stop and ask the user to open Xcode and accept the agreement.

- [ ] **Step 2: Write the failing package smoke test**

Create `ScaffoldTests.swift` with `testCoreModuleLoads()` asserting `LibreGlucoseCore.version == "0.1.0"`.

- [ ] **Step 3: Run the test to verify it fails**

Run: `swift test --filter ScaffoldTests/testCoreModuleLoads`
Expected: FAIL because `Package.swift` or `LibreGlucoseCore.version` does not exist.

- [ ] **Step 4: Add the package and minimal target entry points**

Define `public enum LibreGlucoseCore { public static let version = "0.1.0" }`. Configure `Package.swift` for macOS 13 and iOS 26 with one library and one test target. Configure `project.yml` with app and widget targets, the local package, automatic signing, the identifiers above, and generated schemes.

- [ ] **Step 5: Generate and verify the project**

Run: `brew list xcodegen >/dev/null 2>&1 || brew install xcodegen`, requesting approval if installation needs network access; then `xcodegen generate` and `swift test --filter ScaffoldTests/testCoreModuleLoads`.
Expected: project generation succeeds and the smoke test passes.

- [ ] **Step 6: Build unsigned simulator targets**

Run: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project LibreGlucoseWidget.xcodeproj -scheme LibreGlucoseWidgetApp -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build`
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 7: Commit**

Run: `git add Package.swift project.yml .gitignore Config App Widget Tests LibreGlucoseWidget.xcodeproj && git commit -m "build: scaffold iOS app and widget"`.

### Task 2: Domain model and timestamped presentation rules

**Files:**
- Create: `Sources/LibreGlucoseCore/Domain/GlucoseReading.swift`
- Create: `Sources/LibreGlucoseCore/Presentation/ReadingPresentation.swift`
- Create: `Tests/LibreGlucoseCoreTests/ReadingPresentationTests.swift`
- Remove: `Tests/LibreGlucoseCoreTests/ScaffoldTests.swift`

**Interfaces:**
- Consumes: package target from Task 1.
- Produces: `GlucoseReading`, `GlucoseUnit`, `GlucoseTrend`, `ReadingFreshness`, and `ReadingPresentation.make(reading:now:calendar:locale:)`.

- [ ] **Step 1: Write failing domain and presentation tests**

Test `GlucoseReading` Codable round trips; units display as `mg/dL` and `mmol/L`; trend cases map to `↓↓`, `↓`, `↘`, `→`, `↗`, `↑`, `↑↑`, and unknown to `?`; age is `8 min ago`; exactly 60 minutes is not stale; 60 minutes plus one second is stale; a future source time clamps to age zero.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter ReadingPresentationTests`
Expected: FAIL with missing domain types.

- [ ] **Step 3: Implement the immutable domain types**

Add `GlucoseReading(value: Decimal, unit: GlucoseUnit, trend: GlucoseTrend, timestamp: Date, connectionID: String?)`, Codable/Equatable/Sendable enums, and `ReadingFreshness.fresh`, `.delayed`, `.stale`; classify stale with `now.timeIntervalSince(timestamp) > 3600` and clamp negative ages to zero.

- [ ] **Step 4: Implement locale-aware presentation**

Add `ReadingPresentation` fields for value text, unit text, arrow, local absolute time, relative age, and stale label. Use injected `Calendar` and `Locale` for deterministic tests and system values in production.

- [ ] **Step 5: Run tests and commit**

Run: `swift test --filter ReadingPresentationTests && git add Sources Tests && git commit -m "feat: add glucose reading presentation rules"`.
Expected: all selected tests pass and the commit succeeds.

### Task 3: LibreLinkUp authentication and safe regional routing

**Files:**
- Create: `Sources/LibreGlucoseCore/Networking/HTTPTransport.swift`
- Create: `Sources/LibreGlucoseCore/LibreLinkUp/LibreLinkUpError.swift`
- Create: `Sources/LibreGlucoseCore/LibreLinkUp/LibreLinkUpModels.swift`
- Create: `Sources/LibreGlucoseCore/LibreLinkUp/LibreLinkUpAPI.swift`
- Create: `Tests/LibreGlucoseCoreTests/LibreLinkUpAuthenticationTests.swift`
- Create: `Tests/LibreGlucoseCoreTests/Fixtures/login-success.json`
- Create: `Tests/LibreGlucoseCoreTests/Fixtures/login-redirect-eu2.json`
- Create: `Tests/LibreGlucoseCoreTests/Fixtures/login-terms-required.json`
- Create: `Tests/LibreGlucoseCoreTests/Fixtures/login-rate-limited.json`

**Interfaces:**
- Consumes: Foundation and CryptoKit.
- Produces: `HTTPTransport.send(_:) async throws -> (Data, HTTPURLResponse)`, `LibreLinkUpAPI.login(credentials:) async throws -> AuthSession`, and typed `LibreLinkUpError` cases.

- [ ] **Step 1: Write failing request and authentication tests**

Using an actor-based `MockHTTPTransport`, assert login starts at `https://api.libreview.io/llu/auth/login`, sends JSON email/password and headers `product: llu.ios`, `version: 4.16.0`, follows one `eu2` redirect, rejects non-HTTPS/non-`libreview.io` redirect hosts, returns the token/user/expiry, maps service status `4` to `.termsRequired`, and maps service/HTTP 429 to `.rateLimited`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter LibreLinkUpAuthenticationTests`
Expected: FAIL with missing networking and API types.

- [ ] **Step 3: Implement transport and response envelopes**

Define a Sendable transport protocol, production `URLSessionTransport`, `Credentials(email:password:)`, `AuthSession(token:userID:expiresAt:baseURL:)`, response envelopes, and error enum without including secrets in error descriptions.

- [ ] **Step 4: Implement login and bounded redirect behavior**

Add `LibreLinkUpAPI(transport:configuration:)`; encode credentials with `JSONEncoder`, validate service status before data, permit only `https://api[-region].libreview.io`, and repeat login at most once after a valid redirect.

- [ ] **Step 5: Run tests and commit**

Run: `swift test --filter LibreLinkUpAuthenticationTests && git add Sources Tests && git commit -m "feat: authenticate with LibreLinkUp safely"`.
Expected: all authentication tests pass.

### Task 4: Connections, graph parsing, and trend normalization

**Files:**
- Modify: `Sources/LibreGlucoseCore/LibreLinkUp/LibreLinkUpModels.swift`
- Modify: `Sources/LibreGlucoseCore/LibreLinkUp/LibreLinkUpAPI.swift`
- Create: `Sources/LibreGlucoseCore/LibreLinkUp/LibreTimestampParser.swift`
- Create: `Tests/LibreGlucoseCoreTests/LibreLinkUpReadingTests.swift`
- Create: `Tests/LibreGlucoseCoreTests/Fixtures/connections-one.json`
- Create: `Tests/LibreGlucoseCoreTests/Fixtures/connections-empty.json`
- Create: `Tests/LibreGlucoseCoreTests/Fixtures/graph-mgdl.json`
- Create: `Tests/LibreGlucoseCoreTests/Fixtures/graph-mmoll.json`

**Interfaces:**
- Consumes: `AuthSession` and `HTTPTransport` from Task 3; domain model from Task 2.
- Produces: `LibreLinkUpAPI.firstConnection(session:) async throws -> Connection`, `LibreLinkUpAPI.latestReading(session:connection:) async throws -> GlucoseReading`, and `LibreTimestampParser.parse(_:)`.

- [ ] **Step 1: Write failing connection and graph tests**

Assert authorization is `Bearer <token>` and `Account-Id` is lowercase SHA-256 of `userID`; the first connection is selected; an empty list throws `.noConnections`; both units remain unchanged; raw trends 1–7 map in order from rapidly falling through rapidly rising; any other value maps `.unknown`; ISO-8601 and `M/d/yyyy h:mm:ss a` timestamps parse deterministically, including a DST fixture.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter LibreLinkUpReadingTests`
Expected: FAIL with missing connection and graph operations.

- [ ] **Step 3: Implement authorized request construction and connections**

Create the account hash with CryptoKit, add shared client headers plus authorization, decode `/llu/connections`, and return only the first connection.

- [ ] **Step 4: Implement graph decoding and normalization**

Decode `/llu/connections/{patientID}/graph`, read `data.connection.glucoseMeasurement`, preserve the server unit/value, map trends 1–7, parse the source timestamp with explicit formats/time zones, and reject missing or impossible values as `.malformedResponse`.

- [ ] **Step 5: Run all package tests and commit**

Run: `swift test && git add Sources Tests && git commit -m "feat: fetch and normalize LibreLinkUp readings"`.
Expected: all package tests pass.

### Task 5: Credentials, cache, and single-retry coordinator

**Files:**
- Create: `Sources/LibreGlucoseCore/DataSource/GlucoseDataSource.swift`
- Create: `Sources/LibreGlucoseCore/Security/CredentialStore.swift`
- Create: `Sources/LibreGlucoseCore/Storage/ReadingCache.swift`
- Create: `Sources/LibreGlucoseCore/Coordination/ReadingCoordinator.swift`
- Create: `Tests/LibreGlucoseCoreTests/ReadingCoordinatorTests.swift`
- Create: `Tests/LibreGlucoseCoreTests/ReadingCacheTests.swift`
- Create: `Tests/LibreGlucoseCoreTests/SecretRedactionTests.swift`

**Interfaces:**
- Consumes: `LibreLinkUpAPI`, `Credentials`, `AuthSession`, and `GlucoseReading`.
- Produces: `GlucoseDataSource.fetchLatest(credentials:session:) async throws -> FetchResult`, `CredentialStoreProtocol`, `ReadingCacheProtocol`, and `ReadingCoordinator.refresh() async -> RefreshOutcome`.

- [ ] **Step 1: Write failing cache and coordinator tests**

Assert atomic cache round trip; corrupt cache becomes `.cacheFailure` without crashing; a successful refresh stores session and reading; an unauthorized fetch clears only the expired session, reauthenticates once, and retries once; a second unauthorized result stops; network failure returns cached reading; sign-out clears credentials, session, connection metadata, and reading.

- [ ] **Step 2: Write failing redaction tests**

Construct every public error using sentinel email, password, token, patient ID, and glucose body text; assert `String(describing:)` contains none of the sentinels.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `swift test --filter 'Reading(Coordinator|Cache)Tests|SecretRedactionTests'`
Expected: FAIL with missing protocols and implementations.

- [ ] **Step 4: Implement file cache and data-source adapter**

Implement JSON cache writes through a sibling temporary file followed by atomic replacement. Add a `LibreLinkUpDataSource` that composes login, first connection, and graph fetch while keeping raw models private.

- [ ] **Step 5: Implement coordinator and abstract credential store**

Define the credential/session store protocol in the package and a memory implementation for tests. Implement exactly one authentication retry and typed outcomes `.updated`, `.cached`, `.signedOut`, and `.failed`.

- [ ] **Step 6: Run all package tests and commit**

Run: `swift test && git add Sources Tests && git commit -m "feat: coordinate secure cached glucose refreshes"`.
Expected: all tests pass.

### Task 6: Shared iOS storage and companion app

**Files:**
- Create: `Config/LibreGlucoseWidgetApp.entitlements`
- Create: `Config/LibreGlucoseLockWidget.entitlements`
- Modify: `project.yml`
- Create: `SharedIOS/Infrastructure/SharedContainer.swift`
- Create: `SharedIOS/Infrastructure/KeychainCredentialStore.swift`
- Create: `Sources/LibreGlucoseCore/Security/KeychainQueryBuilder.swift`
- Create: `App/AppModel.swift`
- Create: `App/RootView.swift`
- Create: `App/SignInView.swift`
- Create: `App/DashboardView.swift`
- Create: `App/DisclaimerView.swift`
- Create: `Tests/LibreGlucoseCoreTests/KeychainQueryTests.swift`

**Interfaces:**
- Consumes: package protocols and coordinator from Task 5.
- Produces: shared Keychain/App Group configuration, `KeychainCredentialStore`, and the signed-out/connected/needs-attention SwiftUI flows.

- [ ] **Step 1: Write failing Keychain query tests**

Add failing tests for the package-level pure query builder and assert generic-password class, shared access-group value, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, no synchronizable/iCloud flag, and deletion queries for credentials/session.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter KeychainQueryTests`
Expected: FAIL with missing Keychain query builder.

- [ ] **Step 3: Implement shared entitlements and storage adapters**

Add the same App Group to both targets and the shared group as the Keychain access group. Compile `SharedIOS` into both targets. Implement Keychain add/update/read/delete with `Security`; construct `ReadingCache` from the App Group container, apply complete-until-first-user-authentication file protection to cached data, and fail visibly if the entitlement is unavailable.

- [ ] **Step 4: Implement the companion app state model**

Add `@MainActor AppModel` methods `signIn(email:password:)`, `refresh()`, and `signOut()`. The model exposes only presentation-safe state and calls `WidgetCenter.shared.reloadTimelines(ofKind:)` after successful refresh or sign-out.

- [ ] **Step 5: Implement the SwiftUI screens**

Create accessible sign-in fields, disclaimer, progress/error states, connected reading preview, source timestamp, selected first-profile name, manual refresh, reconnect, and destructive sign-out confirmation. Do not show or log the stored password after submission.

- [ ] **Step 6: Regenerate, build, and commit**

Run: `xcodegen generate && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project LibreGlucoseWidget.xcodeproj -scheme LibreGlucoseWidgetApp -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build`.
Expected: `** BUILD SUCCEEDED **`; then commit with `git add Config App project.yml LibreGlucoseWidget.xcodeproj Tests && git commit -m "feat: add secure LibreLinkUp companion app"`.

### Task 7: Widget timeline and rectangular Lock Screen view

**Files:**
- Modify: `Widget/LibreGlucoseLockWidget.swift`
- Modify: `App/Info.plist`
- Create: `Widget/GlucoseTimelineProvider.swift`
- Create: `Widget/GlucoseWidgetEntry.swift`
- Create: `Widget/GlucoseWidgetView.swift`
- Create: `Sources/LibreGlucoseCore/Presentation/WidgetReadingViewModel.swift`
- Create: `Tests/LibreGlucoseCoreTests/WidgetViewModelTests.swift`

**Interfaces:**
- Consumes: coordinator/cache from Task 5 and presentation from Task 2.
- Produces: widget kind `LibreGlucoseLockWidget`, 15-minute requested timeline, deep link `libreglucose://open`, and fresh/stale/signed-out/unavailable rectangular views.

- [ ] **Step 1: Write failing widget view-model tests**

Assert fresh output contains value/unit/arrow and `14:32 · 8 min ago`; a value older than 60 minutes outputs `STALE · 14:32`; failed fetch with cache preserves that timestamp; no cache plus missing credentials outputs `Open app to reconnect`; unknown trend outputs `?`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `swift test --filter WidgetViewModelTests`
Expected: FAIL with missing widget presentation adapter.

- [ ] **Step 3: Implement entry and timeline provider**

Load cached data immediately for snapshots, refresh through the coordinator for timelines, emit one entry, and request `.after(now + 15 minutes)`. Map all errors to safe display states and never erase a valid cache after a transient error.

- [ ] **Step 4: Implement the widget view and previews**

Use `AccessoryWidgetBackground`, system fonts, `widgetURL`, and only `.accessoryRectangular`. Add previews for fresh, delayed, stale, signed-out, and unavailable states, including an accessibility-size preview; add no Always-On-specific code.

- [ ] **Step 5: Run tests, build the widget, and commit**

Run: `swift test && xcodegen generate && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project LibreGlucoseWidget.xcodeproj -scheme LibreGlucoseWidgetApp -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build`.
Expected: all tests pass and build succeeds; commit with `git add Widget Tests project.yml LibreGlucoseWidget.xcodeproj && git commit -m "feat: add glucose lock screen widget"`.

### Task 8: End-to-end verification and installation guide

**Files:**
- Create: `README.md`
- Create: `docs/manual-test-checklist.md`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: complete app and widget from Tasks 1–7.
- Produces: reproducible setup, safety limitations, personal-device signing instructions, and recorded verification results without sensitive data.

- [ ] **Step 1: Document setup and safety boundaries**

Document Xcode license acceptance, XcodeGen generation, free Personal Team signing for both targets, App Group identifier collision changes, installing to iPhone, adding the rectangular Lock Screen widget, seven-day reprovisioning, LibreLinkUp follower-account requirement, unofficial API risk, and official-app medical disclaimer.

- [ ] **Step 2: Run automated verification**

Run: `swift test` and `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project LibreGlucoseWidget.xcodeproj -scheme LibreGlucoseWidgetApp -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO test`.
Expected: all tests pass with zero failures.

- [ ] **Step 3: Scan for secrets and unsafe logging**

Run: `rg -n '(password|auth(orization)?|token|patientId|glucoseMeasurement)' Sources App Widget Tests --glob '*.swift'` and inspect every match; then `rg -n 'print\(|debugPrint\(|os_log|Logger\.' Sources App Widget`.
Expected: only intentional model/query/test references; no secret-bearing logs, live values, or credentials.

- [ ] **Step 4: Perform simulator UI verification**

Launch the app with synthetic/mock configuration and verify signed-out, connected, needs-attention, fresh, stale, and accessibility layouts; record only pass/fail results in `docs/manual-test-checklist.md`.

- [ ] **Step 5: Perform user-assisted physical-device verification**

Have the user select their Personal Team, resolve any unique bundle/App Group identifier collision, enter their LibreLinkUp credentials directly on their iPhone, and verify live fetch, Lock Screen placement, timestamp, trend, unit, manual refresh, offline fallback, tap-through, and sign-out. Do not ask the user to send credentials or raw health payloads.

- [ ] **Step 6: Commit final documentation**

Run: `git add README.md docs/manual-test-checklist.md .gitignore && git commit -m "docs: add installation and verification guide"`.

- [ ] **Step 7: Run final clean verification**

Run: `git status --short && swift test && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project LibreGlucoseWidget.xcodeproj -scheme LibreGlucoseWidgetApp -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build`.
Expected: clean status, all tests pass, and `** BUILD SUCCEEDED **`.
