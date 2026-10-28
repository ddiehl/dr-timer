# Apple Watch Flight Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A standalone Apple Watch app that lists flights synced from the iPhone and flies them leg by leg, with a repeating wrist vibration at the end of each leg.

**Architecture:** Move the phone's run logic (`RunViewModel` and its seams) into the shared `DRCore` package so the Watch reuses it unchanged. Add Watch-only logic (sync payload and store, repeating alert controller, Watch app model) to `DRCore` behind small protocols so it is tested fast with `swift test` on the Mac. The new `DRTimerWatch` target holds only SwiftUI views and thin platform adapters (WatchConnectivity, haptics, notifications, workout session).

**Tech Stack:** Swift 5, SwiftUI, Observation, WatchConnectivity, HealthKit (workout session), UserNotifications, XcodeGen, XCTest.

**Spec:** `docs/superpowers/specs/2026-10-23-apple-watch-design.md` (builds on `docs/superpowers/specs/2026-10-21-dr-timer-design.md`). Read both.

## Global Constraints

- Watch app has **flight mode only**: no creating, editing or deleting flights on the Watch.
- Target device: Apple Watch Series 7, watchOS 26.6. Watch deployment target watchOS 10.0 (matches `DRCore`).
- Leg time range is 1...5999 s (`Leg.secondsRange`); the user's longest real leg is 15 min.
- `Flight` JSON keys must not change (`PortabilityTests`): `id`, `name`, `legs`, `landmark`, `seconds`.
- The next leg only starts when the pilot taps; the Watch never advances on its own.
- Time-up: vibrate repeatedly until tapped; overdue time counts up from the original end time, starting at `+00:00`.
- Skip needs a long-press, then a confirming tap. The big Next leg / Finish button at time up needs no confirmation.
- Slice 1: no reporting from Watch to phone, no Watch sound, no complications.
- `DRCore` stays free of UIKit, WatchKit, HealthKit and WatchConnectivity (it may import Foundation and Observation).
- Bundle IDs: phone `com.spartatechnology.drtimer`, Watch `com.spartatechnology.drtimer.watchkitapp`; team `675JQKFZ8G`.
- The phone app's behaviour must not change except where a task says so.

## Review Focus

- Relaunch mid-leg after the end time has passed: goes straight to time up, vibrates, overdue counts from the original end (Task 2, Task 8).
- Sync delivers an empty flight list: the Watch shows the empty state instead of keeping stale flights (Task 3).
- Sync delivers undecodable data: the Watch keeps the flights it already has (Task 3).
- Phone deletes or edits a flight while the Watch is mid-run: the run continues with its own copy (Task 8).
- Tapping Next leg during repeated vibration stops the vibration and the backup notification, and does not fire twice; on the last leg the button reads Finish (Task 5, Task 8).

---

### Task 1: Move the run logic into DRCore

**Files:**
- Create: `DRCore/Sources/DRCore/RunViewModel.swift` (moved from `DRTimer/Flight/RunViewModel.swift`)
- Delete: `DRTimer/Flight/RunViewModel.swift`
- Move: `DRTimerTests/RunViewModelTests.swift` to `DRCore/Tests/DRCoreTests/RunViewModelTests.swift` (with its fakes)
- Modify: phone files that reference `Clock` or `RunViewModel` (`DRTimer/AppModel.swift`, `DRTimer/Flight/*.swift`, `DRTimer/Alerts/AlertAdapters.swift`, `DRTimerTests/AlertIntegrationTests.swift`, `DRTimerApp.swift`)

**Interfaces:**
- Produces (all `public`): `protocol RunClock { var now: Date { get } }`, `struct SystemClock: RunClock`, `protocol AlertControlling` (unchanged requirements: `scheduleTimeUp(at: Date, landmark: String)`, `startRinging()`, `stopRinging()`, `cancelScheduled()`), `final class RunViewModel` with the same members as today (`run`, `remainingSeconds`, `saveError`, `init(run:store:clock:alerts:)`, `static restoreIfAny(store:clock:alerts:)`, `refresh()`, `primaryTapped()`, `pauseTapped()`, `resumeTapped()`, `nextLegTapped()`, `endFlightConfirmed()`, `persistInitial()`).

- [ ] **Step 1: Move the test file** into `DRCoreTests`, change its import to `@testable import DRCore`, rename `Clock` to `RunClock` in it. Run `swift test --package-path DRCore`. Expected: FAIL (types not found).
- [ ] **Step 2: Move `RunViewModel.swift` into `DRCore`**, make the types and members listed above `public`, and rename the protocol `Clock` to `RunClock` (it would clash with Swift's own `Clock`). Add `import Observation`. `DRCore/Package.swift` needs no change.
- [ ] **Step 3: Fix the phone target:** `import DRCore` where needed, rename `Clock` to `RunClock`. Fix `DRTimerTests/AlertIntegrationTests.swift` and any other test that used the moved fakes.
- [ ] **Step 4: Verify.** Run `swift test --package-path DRCore` and the phone test command from the README. Expected: all pass, test count unchanged from before the move.
- [ ] **Step 5: Commit** `refactor: move run view model into DRCore`.

---

### Task 2: Record when a leg ended (overdue time)

**Files:**
- Modify: `DRCore/Sources/DRCore/FlightRun.swift`, `DRCore/Sources/DRCore/RunViewModel.swift` (only if needed), phone code or tests that pattern match `.timeUp`
- Test: `DRCore/Tests/DRCoreTests/FlightRunTests.swift`, `DRCore/Tests/DRCoreTests/StoreTests.swift`, `DRCore/Tests/DRCoreTests/RunViewModelTests.swift`

**Interfaces:**
- Produces: `RunPhase.timeUp(leg: Int, endedAt: Date)`; `FlightRun.overdue(at now: Date) -> Int` (whole seconds since `endedAt`, rounded down, never negative; 0 in any non-timeUp phase). `tick` sets `endedAt` to the original `endsAt`. `skipToNextLeg` goes through timeUp and must still end up counting the next leg (it uses `now` as `endedAt` internally).

- [ ] **Step 1: Write failing tests.**
  - `testTickPastEndRecordsOriginalEndAsEndedAt`: counting 750 s from T, `tick(at: T+800)`, phase equals `.timeUp(leg: 0, endedAt: T+750)`.
  - `testOverdueCountsUpFromEnd`: same run, `overdue(at: T+750)` is 0, `overdue(at: T+797.9)` is 47, `overdue(at: T+9999)` is 9249; `overdue(at:)` is 0 while counting.
  - `testOverdueIsZeroBeforeEnd`: `overdue(at: T)` while counting is 0.
  - `testRunSavedInOldTimeUpFormatLoadsAsNil` in `StoreTests`: write JSON for a run whose phase is the old `{"timeUp":{"leg":0}}` shape, `RunStore.load()` returns nil (no crash).
  - `testRestoreAfterEndPassedGoesToTimeUpWithOriginalEnd` in `RunViewModelTests`: saved counting run whose end is 90 s before the fake clock's now; after `restoreIfAny`, phase is `.timeUp(leg: 0, endedAt: end)`, ringing has started, and `run.overdue(at: now)` is 90.
  - Update existing `.timeUp(leg: 0)` assertions (`FlightRunTests`, `RunViewModelTests` lines near 62, 122, 167) to the new shape.
- [ ] **Step 2: Run** `swift test --package-path DRCore`. Expected: FAIL (compile errors).
- [ ] **Step 3: Implement** the changes in `FlightRun`. Check `isLastLeg`, `currentLegIndex`, `endFlight`, `advance` still compile with the new payload.
- [ ] **Step 4: Fix phone code** that matches `.timeUp` with a payload (the repo grep showed `RunView.swift:15` and `VolumeMonitor.swift` use it without a payload; confirm). Run both test suites. Expected: pass.
- [ ] **Step 5: Commit** `feat: record leg end time and overdue seconds`.

---

### Task 3: Sync payload and Watch flight store

**Files:**
- Create: `DRCore/Sources/DRCore/FlightSync.swift`
- Test: `DRCore/Tests/DRCoreTests/FlightSyncTests.swift`

**Interfaces:**
- Produces:
  - `public struct FlightSyncPayload: Codable, Equatable, Sendable { public let flights: [Flight]; public let sentAt: Date; public init(flights: [Flight], sentAt: Date); public static let contextKey = "flightSync"; public func contextDictionary() throws -> [String: Any]; public static func from(context: [String: Any]) -> FlightSyncPayload? }` (the dictionary holds the encoded payload as `Data` under `contextKey`; `from` returns nil when the key is missing or the data does not decode).
  - `public final class SyncedFlightStore { public init(fileURL: URL); public func load() -> FlightSyncPayload?; public func save(_ payload: FlightSyncPayload) throws; public func apply(context: [String: Any]) -> FlightSyncPayload? }` (`apply` decodes, saves and returns the payload; returns nil and leaves the saved file untouched when the context is undecodable).

- [ ] **Step 1: Write failing tests.**
  - `testContextRoundTrip`: encode a payload with two flights, `from(context:)` returns an equal payload.
  - `testFlightJSONInsidePayloadKeepsPinnedKeys`: decode the payload's `Data` as JSON, check its `flights[0]` keys are `id`, `name`, `legs`.
  - `testEmptyFlightListIsAValidPayload`: a payload with zero flights round-trips and `apply` replaces a previously saved non-empty list with an empty one.
  - `testUndecodableContextKeepsExistingFlights`: save a payload, `apply(context: ["flightSync": Data("junk".utf8)])` returns nil, `load()` still returns the saved payload.
  - `testMissingKeyReturnsNil`.
  - `testLoadOfMissingOrCorruptFileIsNil`.
- [ ] **Step 2: Run** `swift test --package-path DRCore`. Expected: FAIL.
- [ ] **Step 3: Implement** with `JSONEncoder`/`JSONDecoder` default settings (same as `FlightRepository`), atomic file write.
- [ ] **Step 4: Run tests.** Expected: pass.
- [ ] **Step 5: Commit** `feat: flight sync payload and Watch flight store`.

---

### Task 4: Phone sends flights to the Watch

**Files:**
- Create: `DRTimer/Sync/WatchConnectivitySender.swift`
- Modify: `DRTimer/AppModel.swift`, `DRTimer/DRTimerApp.swift`
- Test: `DRTimerTests/AppModelTests.swift`

**Interfaces:**
- Consumes: `FlightSyncPayload` (Task 3).
- Produces: `protocol FlightSyncing { func send(_ flights: [Flight]) }` (in the phone target); `final class WatchConnectivitySender: NSObject, WCSessionDelegate, FlightSyncing` (activates `WCSession` when supported, remembers the latest flights, calls `updateApplicationContext(payload.contextDictionary())` whenever it sends and again when activation completes). `AppModel.init(repository:runStore:sync: FlightSyncing? = nil)`; `AppModel.production()` passes a `WatchConnectivitySender`.

- [ ] **Step 1: Write failing tests** with a `FakeSync` that records calls:
  - `testInitSendsCurrentFlights`: repository has two flights, creating the model sends those two.
  - `testAddUpdateDeleteDuplicateEachSendFullList`: after each, the last sent list equals `model.flights`.
  - `testFailedSaveDoesNotSend`: when the repository save throws, nothing new is sent.
- [ ] **Step 2: Run** the phone tests (README command). Expected: FAIL.
- [ ] **Step 3: Implement** the hook in `AppModel.persist()` (send only after a successful save) and the sender. The sender swallows `updateApplicationContext` errors but must not crash when no Watch is paired.
- [ ] **Step 4: Run phone tests.** Expected: pass.
- [ ] **Step 5: Commit** `feat: send flights to the Watch via WatchConnectivity`.

---

### Task 5: Repeating alert controller

**Files:**
- Create: `DRCore/Sources/DRCore/RepeatingAlertController.swift`
- Test: `DRCore/Tests/DRCoreTests/RepeatingAlertControllerTests.swift`

**Interfaces:**
- Produces:
  - `public protocol HapticPlaying { func play() }`
  - `public protocol BackupNotifying { func schedule(at: Date, landmark: String); func cancel(); func requestAuthorization() }` (`schedule` replaces any earlier request; `cancel` removes pending and delivered)
  - `public protocol CancellableTimer: AnyObject { func cancel() }`
  - `public protocol RepeatingTimerScheduling { func repeating(every: TimeInterval, _ action: @escaping () -> Void) -> CancellableTimer }`
  - `public final class RepeatingAlertController: AlertControlling { public init(haptics: HapticPlaying, notifier: BackupNotifying, timers: RepeatingTimerScheduling, interval: TimeInterval = 1.5) }`

- [ ] **Step 1: Write failing tests** with fakes (a fake timer the test fires manually):
  - `testStartRingingPlaysImmediatelyAndOnEveryTimerFire`.
  - `testStartRingingTwiceDoesNotCreateSecondTimer`.
  - `testStopRingingCancelsTimerAndBackupNotification`: after `stopRinging`, firing the old timer plays nothing and `notifier.cancel` was called.
  - `testScheduleTimeUpPassesDateAndLandmarkToNotifier`.
  - `testCancelScheduledCancelsNotifier`.
  - `testStopRingingWhenNotRingingIsHarmless`.
- [ ] **Step 2: Run** `swift test --package-path DRCore`. Expected: FAIL.
- [ ] **Step 3: Implement.** Default interval 1.5 s is my choice; keep it a parameter.
- [ ] **Step 4: Run tests.** Expected: pass.
- [ ] **Step 5: Commit** `feat: repeating alert controller for the Watch`.

---

### Task 6: Watch app model

**Files:**
- Create: `DRCore/Sources/DRCore/WatchAppModel.swift`
- Test: `DRCore/Tests/DRCoreTests/WatchAppModelTests.swift`

**Interfaces:**
- Consumes: `SyncedFlightStore`, `RunStore`, `RunClock`, `AlertControlling`, `RunViewModel`.
- Produces:
  - `public protocol WorkoutSessionKeeping { func begin(); func end() }`
  - `@Observable public final class WatchAppModel { public private(set) var flights: [Flight]; public private(set) var lastSyncedAt: Date?; public private(set) var run: RunViewModel?; public init(store: SyncedFlightStore, runStore: RunStore, clock: RunClock, alerts: AlertControlling, session: WorkoutSessionKeeping); public func applySync(context: [String: Any]); public func start(_ flight: Flight); public func finishAndClose(); public func restore() }`
  - Behaviour: `init` loads saved flights. `applySync` replaces `flights` and `lastSyncedAt` only when the context decodes (an empty list is valid). `start` creates a `FlightRun`, a `RunViewModel`, calls `persistInitial()` and `session.begin()`. `finishAndClose` sets `run` to nil, clears the saved run, cancels alerts and calls `session.end()`. `restore()` uses `RunViewModel.restoreIfAny`; if a run exists it calls `session.begin()`.

- [ ] **Step 1: Write failing tests** with fakes:
  - `testInitLoadsSavedFlightsAndSyncTime`.
  - `testApplySyncReplacesFlights`; `testApplyEmptyListShowsNoFlights`; `testApplyUndecodableKeepsOldFlights`.
  - `testStartCreatesReadyRunAndBeginsSession`.
  - `testFinishAndCloseEndsSessionAndClearsSavedRun`.
  - `testRestoreResumesSavedRunAndBeginsSession`; `testRestoreWithNothingSavedLeavesRunNil`.
  - `testSyncDeletingFlightDoesNotAffectRunInProgress`: start a flight, then apply a sync without it, `run?.run.flight` is unchanged and still usable.
- [ ] **Step 2: Run** `swift test --package-path DRCore`. Expected: FAIL.
- [ ] **Step 3: Implement.** Workout session spans a whole run (begins when a flight is picked, ends on finish or Done); that is my choice.
- [ ] **Step 4: Run tests.** Expected: pass.
- [ ] **Step 5: Commit** `feat: Watch app model`.

---

### Task 7: Watch target, connectivity receiver and flight list

**Files:**
- Modify: `project.yml`
- Create: `DRTimerWatch/DRTimerWatchApp.swift`, `DRTimerWatch/Sync/PhoneSyncReceiver.swift`, `DRTimerWatch/Views/WatchRootView.swift`, `DRTimerWatch/Views/FlightListView.swift`, `DRTimerWatch/DRTimerWatch.entitlements` (generated by XcodeGen from `project.yml`)

**Interfaces:**
- Consumes: `WatchAppModel` (Task 6).
- Produces: a buildable Watch app. `PhoneSyncReceiver: NSObject, WCSessionDelegate` activates `WCSession` and, on activation and on every `didReceiveApplicationContext`, calls `model.applySync(context:)` on the main actor (it must also read `session.receivedApplicationContext` once activation completes, so flights arrive when the Watch app launches). `FlightListView` shows name, leg count and total time per flight (`Flight.totalSeconds`, `TimeFormat.mmss`), a "Synced <relative time>" footer from `lastSyncedAt`, and an empty state ("No flights. Send flights from the iPhone.").

- [ ] **Step 1: Add the target.** In `project.yml` add `DRTimerWatch`: `type: application`, `platform: watchOS`, deployment target 10.0, `sources: [DRTimerWatch]`, `DRCore` package dependency, bundle ID and team from Global Constraints, `SWIFT_VERSION: "5.0"`, `GENERATE_INFOPLIST_FILE: YES`. Info keys: `WKApplication: true`, `WKCompanionAppBundleIdentifier: com.spartatechnology.drtimer`, `WKRunsIndependentlyOfCompanionApp: true`, `NSHealthShareUsageDescription` and `NSHealthUpdateUsageDescription` (short plain text saying the workout keeps the timer running). Entitlement `com.apple.developer.healthkit: true`. Make `DRTimer` depend on `DRTimerWatch` so it is embedded. Add `DRTimerWatch` to the schemes if needed.
- [ ] **Step 2: Check the watchOS simulator runtime exists:** `xcrun simctl list runtimes | grep -i watchOS`. If missing, install it (`xcodebuild -downloadPlatform watchOS`) and tell the user it was needed.
- [ ] **Step 3: Implement the app entry, receiver, root view and list.** The app creates the `WatchAppModel` with production wiring (Task 8's adapters, or temporary no-op ones if Task 8 is not done yet; replace them in Task 8). Files live in the Watch app's Documents directory (`synced-flights.json`, `run.json`).
- [ ] **Step 4: Verify build.** `xcodegen generate && xcodebuild -project DRTimer.xcodeproj -scheme DRTimerWatch -destination 'generic/platform=watchOS' build`. Expected: BUILD SUCCEEDED. Also rebuild the phone scheme and run `swift test --package-path DRCore`.
- [ ] **Step 5: Commit** `feat: Watch app target with flight list and phone sync`.

---

### Task 8: Watch run screens, alerts and workout session

**Files:**
- Create: `DRTimerWatch/Views/RunScreen.swift`, `DRTimerWatch/Views/ReadyView.swift`, `DRTimerWatch/Views/CountingView.swift`, `DRTimerWatch/Views/TimeUpView.swift`, `DRTimerWatch/Views/FlightCompleteView.swift`, `DRTimerWatch/Alerts/WatchAdapters.swift`, `DRTimerWatch/Alerts/WorkoutSessionKeeper.swift`
- Modify: `DRTimerWatch/DRTimerWatchApp.swift`, `DRTimerWatch/Views/WatchRootView.swift`

**Interfaces:**
- Consumes: `WatchAppModel`, `RunViewModel`, `RepeatingAlertController` and its protocols, `WorkoutSessionKeeping`.
- Produces: `WatchHaptics: HapticPlaying` (plays `WKInterfaceDevice.current().play(.notification)`); `WatchBackupNotifier: BackupNotifying` (a `UNUserNotificationCenter` request with a fixed identifier, title "Time's up", body the landmark, default sound; `requestAuthorization` called once at launch); `WatchRepeatingTimers: RepeatingTimerScheduling` (a `Timer`-based adapter); `WorkoutSessionKeeper: WorkoutSessionKeeping` (starts an `HKWorkoutSession` of activity type `.other` after requesting share authorization for workouts, ends it on `end()`; failures are logged and never crash or block flying).

- [ ] **Step 1: Wire production adapters** in the app entry (replacing any temporary no-ops from Task 7) and call `model.restore()` at launch so an interrupted run resumes.
- [ ] **Step 2: Build the screens to match the approved mockup** (the mockup file is at `.superpowers/brainstorm/*/content/watch-flow.html`; open it for the layout).
  - `RunScreen` switches on `run.run.phase`: `.ready` is `ReadyView` (flight name, "Leg N of M", landmark, dimmed leg time, large green **Start** calling `primaryTapped()`); `.counting` and `.paused` are `CountingView` (large mm:ss, next landmark in small text, no big button, paused state is clearly labelled); `.timeUp` is `TimeUpView` (landmark, red `+mm:ss` from `run.overdue(at:)`, large orange **Next leg**, or **Finish** on the last leg, calling `primaryTapped()`); `.finished` is `FlightCompleteView` (**Done** calls `model.finishAndClose()`).
  - A one-second `TimelineView` (or timer) calls `run.refresh()` so ticks and the time-up transition happen while the app is frontmost.
  - Long-press on `CountingView` opens a menu with Pause/Resume and "Skip to next leg"; Skip shows a second confirmation ("Skip leg?") before calling `nextLegTapped()`. A single tap does nothing.
  - Also call `refresh()` when the scene becomes active, so a raise-to-wake after the end time shows time up immediately.
- [ ] **Step 3: Build** with the Task 7 command. Expected: BUILD SUCCEEDED.
- [ ] **Step 4: Check in the Watch simulator** if the runtime is installed: run the app with a flight pushed through a debug-only seed (do not ship a seed), walk ready, counting, time up, overdue, finish, and compare each with the mockup. If the simulator is unavailable, say so in the hand-off; do not claim visual verification.
- [ ] **Step 5: Run all suites** (`swift test --package-path DRCore`, phone tests). Expected: pass.
- [ ] **Step 6: Commit** `feat: Watch run screens, repeating haptics and workout session`.

---

### Task 9: Device checklist and docs

**Files:**
- Modify: `docs/device-test-checklist.md`, `README.md`

- [ ] **Step 1: Add a "Watch" section to the device checklist** (same table style as the existing one) with checks: (a) flights appear on the Watch after saving on the phone, also with the phone Bluetooth off or left behind once synced; (b) fly a 1-minute leg with the wrist down, expect repeating vibration at time up and the overdue count when raised; (c) a 15-minute leg with the wrist down the whole time, expect the vibration at the end; (d) app killed or suspended mid-leg, expect one backup notification buzz; (e) Next leg stops the vibration and starts the next leg; (f) long-press, Skip, confirm skips; a single tap does not; (g) pause and resume; (h) relaunch the app mid-leg and after the end time has passed; (i) first-run Health permission prompt and the workout indicator; (j) battery used per hour; (k) phone deletes the flight mid-run on the Watch, the run continues; (l) Watch with zero flights shows the empty state.
- [ ] **Step 2: Update the README** "Next: Apple Watch" section into a description of the finished slice: what is built, the workout-session choice, the `DRCore` pieces, and the follow-ups (reporting to the phone, Watch sound, complications). Remove the answered open items (device model: Series 7, watchOS 26.6).
- [ ] **Step 3: Commit** `docs: Watch device checklist and README`.
