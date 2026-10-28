# Apple Watch Flight Mode: Design (slice 1)

Extends [the iPhone design](2026-10-21-dr-timer-design.md). Read that first for the pilot's situation and the leg-by-leg flow.

## Intent and why

The pilot flies solo, navigating by dead reckoning with timed legs. A wrist device is easier to feel than a phone: a vibration on the wrist ends each leg without looking at, or hearing, anything. The Watch app is a pure **flying** tool. All planning stays on the iPhone.

Success: the pilot picks a flight on the Watch, taps Start, flies, feels the wrist vibrate when the leg ends, taps Next leg over the landmark, and repeats until the flight is done. It works with the phone left in the bag, or at home.

## Decided with the user

- **Watch has flight mode only.** No creating, editing or deleting flights on the Watch.
- **Flights come from the phone** and are stored on the Watch ahead of time. The pilot can pick a flight and fly it on the Watch alone, without starting anything on the phone.
- **Flow:** pick a flight, see leg 1 ready, tap Start, countdown, vibration at the end, tap Next leg, repeat, then a "Flight complete" screen.
- **At the end of a leg the Watch vibrates and then waits.** It never advances by itself, because the pilot may not have reached the landmark yet. While waiting it shows the time overdue, counting up from +00:00 (the user liked this).
- **A way to jump to the next leg at any time**, even mid-countdown.
- **Simple to use.** One main button per screen; large text. The user approved the mockup of the five screens: flight list, leg ready (Start), counting down, time up/overdue (Next leg), flight complete.
- **Target device:** Apple Watch Series 7 running watchOS 26.6.
- **Slice 1 has no reporting back to the phone.** The Watch does not send run results or progress to the phone.

## Goals

- Reliable, hard-to-miss end-of-leg vibration, even with the wrist down or the screen dimmed.
- Works entirely standalone once flights are on the Watch. Once a leg is running, nothing depends on the phone.
- Reuse the shared `DRCore` package (`Flight`, `Leg`, `FlightRun`) for timing and data, so Watch and phone behave identically.

## Non-goals

- Planning or editing on the Watch.
- Sending run results, progress or live state to the phone (a later slice).
- Complications, widgets or Smart Stack entries.
- Sound from the Watch speaker (haptics only, unless the builder finds it nearly free).
- Watch-to-phone control or mirroring of a run.

## Anti-goals (a failure even if it technically works)

- A missed vibration at the end of a leg.
- The countdown stopping or drifting because the screen went dark or the app was backgrounded.
- A Watch that has no flights because syncing silently failed, with nothing to tell the pilot.
- An accidental skip while gloved or in turbulence.

## Screens and behaviour

All screens follow the approved mockup. The leg screens show the flight name and "Leg N of M", the landmark name, and one large time. They show the next landmark in small text while counting.

1. **Flight list:** each flight shows name, leg count and total time. Tap to open it. An empty state says to send flights from the iPhone.
2. **Ready:** landmark, the leg's full time (dimmed), large green Start button.
3. **Counting:** large countdown, next landmark in small text. No big button, so nothing can be tapped by accident.
4. **Time up:** the Watch vibrates. The screen shows the landmark and "+00:00" in red with a large orange **Next leg** button (**Finish** on the last leg). The overdue time counts up, and vibration keeps repeating until the pilot taps.
5. **Flight complete:** large Done button, which returns to the flight list.

**Pause and skip (long-press on the counting screen):** a deliberate gesture that opens a small menu with Pause/Resume and Skip to next leg. These map to the existing `FlightRun.pause`, `resume` and `skipToNextLeg`. (The exact gesture is the builder's call, but it must not be a single casual tap.)

## Answered by the user

- A **workout-style session** during a flight is acceptable (workout indicator, one-time Health permission, extra battery use).
- Flights can be long (over an hour); **no single leg is longer than 15 minutes.**
- The user has a **paid Apple Developer account** (team `675JQKFZ8G` in `project.yml`), so HealthKit and Watch provisioning are available.

## Decisions I made (the user has not confirmed these; please check)

- Vibration repeats until tapped while the app is active. If the app is suspended, a scheduled Watch notification gives a single buzz as backup.
- On relaunch mid-run with the end time already passed, the Watch goes straight to time up and vibrates. Overdue time counts from the original end time.
- The leg end time is added to the shared `FlightRun` time-up phase. Old saved runs that no longer decode are discarded, not migrated.
- The phone is the master copy of flights; each sync replaces the Watch's list. A run in progress keeps its own copy of its flight (`FlightRun` embeds it).
- The flight list shows a "last synced" line so a failed sync is visible.
- Pause/resume is on the Watch (reusing `FlightRun`). Skip needs a long-press, then a confirming tap. The large **Next leg** button at time up needs no confirmation.
- No on-Watch sound in slice 1.
- Flights reach the Watch via WatchConnectivity (application context carrying the same JSON as `FlightRepository`), on every save on the phone and whenever the Watch app launches with the phone reachable.
- A run in progress is saved on the Watch (`RunStore`) so it survives a relaunch.
- The Watch app is a companion embedded in the iPhone app, targeting watchOS 10 or later (matching `DRCore`), runs independently of the phone, and needs the HealthKit entitlement.
- The phone and Watch can each run the same flight independently; there is no mirroring.
- The Watch wakes and lights up at time up. It follows normal wake and dim behaviour otherwise.

## Constraints and facts

- `DRCore` is Foundation-only and already declares a watchOS platform (currently `.v10`). A Watch app target must be added to `project.yml` (XcodeGen), embedded in the iPhone app.
- `FlightRun` does not record when a leg ended. The overdue count-up needs this: add the leg's end time to the time-up phase (or compute it from the stored end date). This changes a persisted format, so old saved runs must still load or be discarded cleanly.
- `PortabilityTests` pins the `Flight` JSON keys. They must not change.
- The Watch runtime for the simulator wasn't installed at the time of the README, so a watchOS build may need that installed first.
- Real-device checks are essential: haptics, wrist-down behaviour, extended runtime. Extend `docs/device-test-checklist.md` with a Watch section.

## Left to the builder

- Screen layout and exact fonts and colours, following the approved mockup.
- Haptic pattern and repeat interval.
- The exact long-press and menu design.
- The sync mechanism details (as long as flights arrive reliably and the Watch shows what it has).
- Watch app structure and test approach.
