# Dead Reckoning Timer: Design

## Intent and why

The user is a student pilot, now flying solo. During dead reckoning (DR) navigation, they fly timed legs between landmarks. Previously their instructor ran the timers on his own phone. Solo, they are flying, navigating and talking on the radio at once, so every extra tap or glance costs attention.

The app replaces the instructor's phone. It counts down each leg and, when time is up, tells them loudly and unmistakably which landmark to look for. Everything else is deliberately left out so in-flight use takes almost no attention.

Success: in the cockpit, the pilot taps START, flies, is alerted by sound and vibration, reads one big landmark name, spots it, taps once, and the next leg starts. They never have to think about the app.

## Two phases of use

### Phase 1: Planning (on the ground, iPhone)

The pilot works out each leg's time themselves (winds, distance, groundspeed) and types the results in. The app does no wind, distance or navigation math. It only stores what they enter.

- **Flights list:** saved flights, each showing name, leg count and total time. Create, delete and duplicate flights.
- **Flight editor:** an ordered list of legs plus the total time. Add, reorder and delete legs.
- **Leg editor:** two fields: landmark name (free text) and leg time (minutes:seconds).

Planning screens may be denser than flight screens.

### Phase 2: In flight (iPhone first, Watch later)

Three screens, all with large text and one large button.

1. **Pick the flight:** a list of saved flights. Tap one to begin.
2. **Ready / counting:** shows "Leg N of M", the big countdown time, and the next landmark's name in smaller text. One large START button. While a leg is running the same screen counts down, with no other controls.
3. **Time's up:** the device rings and vibrates. The screen turns red and shows "LOOK FOR" with the landmark name as the biggest element on the screen. One large button: "OVER IT: START LEG N+1". On the last leg the button reads FINISH.

Key behaviour: the next leg only starts when the pilot taps. The tap confirms they are actually over the landmark, so each leg's timer starts from their real position and not from a planned time. The next leg never starts by itself.

Visual mockups the user approved ("perfect"): high-contrast dark screens, a green START button, a red time's-up screen. Planning mockups were shown and accepted ("great").

## Goals

- In-flight use needs minimal attention: one button per screen, big text.
- The alert is never missed (see Reliability).
- Structured so an Apple Watch app can be added next without rework.
- Flights persist on the device between sessions. No account and no server.

## Non-goals

- Wind, distance or groundspeed calculation.
- Maps, GPS, position tracking or any navigation logic.
- Restart and stop in flight. (Pause and NEXT LEG were added later at the user's request, 2026-10-22; they show only while a leg is counting or paused.)
- Any cloud or multi-user features.

## Anti-goals (a failure even if it technically works)

- A missed or silent alert at time-up.
- The screen locking or dimming during a flight.
- In-flight screens that need reading small text or choosing between buttons.

## Reliability requirements

- **Screen stays awake** while the app is in the foreground. The screen does not lock during a flight.
- **The main path is foreground use.** The pilot keeps the app open and the screen awake for the whole flight. They do not expect to unlock the phone or act from the lock screen. (User's answer.)
- **Safety net:** if the phone does lock or the app is backgrounded anyway, the alert should still sound and vibrate at time-up, even with the silent switch on. The pilot would then open the app and tap the button. No lock-screen or notification actions are needed. Normal notifications obey the silent switch, so the builder should choose an approach (for example a background audio session plus a local notification) and test it on a real device. This is a high-risk area.
- **Headset:** the pilot uses a Bluetooth headset. The alert sound must play through the connected headset. It should also be audible on the phone speaker if the headset is not connected (builder's call on whether to play on both when connected).
- **Visual alert:** at time-up the screen must grab attention visually as well as by sound: strong colours, red and blue, that alternate or flash. This replaces the plain solid-red screen in the earlier mockup. Keep the landmark name fully legible against the colours. (User's request.)
- Timers are based on absolute end times and not on a ticking counter, so they stay correct if the app is suspended.
- **In-progress state is saved.** The running flight, current leg and the absolute end time are persisted, so the app can recover after being suspended or killed. On return, if a leg's end time has already passed, show the time's-up screen with the alert active. (Author's call.)

## Apple Watch (next step, but prepared for now)

- The Watch shows the same flight screens as the phone: countdown, landmark, one button.
- **Standalone:** the Watch runs its own timers and alerts with a haptic tap and sound. Once a leg is running it must never depend on the phone being nearby. The user wants to be able to rely on the Watch even if the phone is not visible.
- **Mirrored:** when both are in use they stay in sync. Starting a leg on either starts it on both, and either can sound the alert.
- Flights are copied to the Watch ahead of time so it works without the phone.
- Planning stays on the phone only.

This step is not built now. The current build must be structured to make it straightforward: see Constraints.

## Constraints and decisions

Decided by the user:
- Platform: iPhone app now, Apple Watch later. The user has a Mac with Xcode.
- The user is a Java developer who can read Swift. Code should be clear and idiomatic, with explanation where useful.
- Project folder: `/Users/daniel/dev/git/dr-timer`.

- Devices (user's answer): iPhone 17, which the user says is on iOS 17. The user is not sure of the Apple Watch model, only that it is not new. Minimum target: iOS 17. The Watch model and watchOS version are still unknown. The Watch step must start by checking them, and must target an older watchOS if needed.

Author's calls (proposed, not yet agreed by the user):
- Swift with SwiftUI.
- Local on-device storage (for example SwiftData, which needs iOS 17). No server or account.
- Flight, leg and timer logic lives in a shared module that contains no UI and has no iOS-only dependencies, so the future Watch app can use it unchanged. It should be unit-tested.
- The shared module defines plain value types (for example Codable structs for flights and legs) with persistence kept in a separate layer. The Watch receives copies of the value types and does not share the database.
- Limits: leg time from 00:01 to 99:59 (minutes:seconds). A flight needs at least one leg and a leg time above zero, and the editor prevents saving otherwise. No other limits on leg or flight counts.
- Leaving a flight: before the first START, and again after FINISH, the pilot can go back to the flights list. During a running flight there is no stop control, as the user asked. As a safety valve against being stuck, a long-press on a small, unobtrusive "End flight" control is allowed on the ready screen only (between legs, never while counting down). Flights cannot be edited or deleted while one is running.

## Left to the builder

- Exact project structure and minimum iOS version.
- The alert approach that meets the reliability requirements.
- Alert sound choice and whether it repeats until tapped. The author's default is that it keeps ringing and vibrating until the pilot taps the button.
- Visual details beyond the approved mockups (fonts, exact colours, app icon), including how the red and blue flashing works.
- How flights are synced to the Watch later.
