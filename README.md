# DR Timer

An iPhone dead-reckoning timer for flying. You plan a flight as a list of legs (a landmark and a time in mm:ss), then fly it: each leg counts down, rings and vibrates when it ends, and you tap to advance to the next leg. Flights and the in-progress run are saved on the device as JSON files.

The timing and data model live in `DRCore`, a Foundation-only Swift package that is shared by the iPhone app and (later) the Apple Watch.

## Generate the project

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```
xcodegen generate
```

Then open `DRTimer.xcodeproj`.

## Run the tests

```
swift test --package-path DRCore
xcodegen generate && xcodebuild -project DRTimer.xcodeproj -scheme DRTimer -destination 'platform=iOS Simulator,id=2AAC40F4-AD93-441C-ABE1-8B484C8D007D' test
```

The simulator id is specific to this machine; list yours with `xcrun simctl list devices`.

## Before relying on it in flight

Simulator tests cannot verify audio, vibration, the silent switch or the locked-phone behaviour. Run [docs/device-test-checklist.md](docs/device-test-checklist.md) on the real phone first.

## Known follow-ups

1. AlarmKit (iOS 26) is the only robust fix for the app being force-quit while the silent switch is on.
2. The device test checklist must be run before relying on the app in flight.
3. The spec says "iPhone 17 on iOS 17", which is likely inconsistent (iPhone 17 ships with iOS 26 or later). Confirm the real iOS version on the phone.

## Next: Apple Watch

Open items:

- Find the Watch model and watchOS version first. The user said it is "not new", so the minimum watchOS target may need to be lower than the `.watchOS(.v10)` set in `DRCore/Package.swift`.
- Standalone Watch timers: the Watch must run its own timers and haptics, and must never depend on the phone once a leg is running.
- WatchConnectivity: send flights from the phone to the Watch, and sync run state in both directions.

Already prepared: `DRCore` imports only Foundation, declares a watchOS platform, and `PortabilityTests` pins the JSON keys of a `Flight` (`id`, `name`, `legs`, `landmark`, `seconds`) so the transfer format cannot drift silently.

Not verified: a real watchOS build was not run, because the watchOS platform runtime is not installed on the development machine. `DRCore` was only typechecked against the WatchOS SDK with:

```
swiftc -typecheck -sdk $(xcrun --sdk watchos --show-sdk-path) -target arm64_32-apple-watchos10.0 DRCore/Sources/DRCore/*.swift
```

Once the runtime is installed, run `xcodebuild -scheme DRCore -destination 'generic/platform=watchOS' build` from `DRCore/`.
