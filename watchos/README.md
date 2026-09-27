# MiyaBabyWatch — watchOS companion app

Native SwiftUI Apple Watch app that pairs with the Miya Baby iPhone app
(Flutter) over WatchConnectivity.

## What it does

- One-tap logging from the wrist: nursing (left/right), bottle, diaper
  (wet/dirty/mixed), start/stop sleep.
- Live status card showing the last feed, diaper, and sleep, plus active
  timers — pushed from the phone via `updateApplicationContext`.
- If the iPhone isn't reachable, log actions are queued with
  `transferUserInfo` and delivered when the phone comes back.

The iPhone app is the source of truth: all persistence and timer logic
live in the Flutter app; the watch only sends intents and renders
snapshots.

## Message protocol (watch → phone, via `sendMessage`)

| action          | payload                              |
|-----------------|--------------------------------------|
| `logDiaper`     | `diaperKind`: wet / dirty / mixed    |
| `logBottle`     | `amountMl`: Double                   |
| `startNursing`  | `side`: left / right                 |
| `stopNursing`   | —                                    |
| `startSleep`    | —                                    |
| `stopSleep`     | —                                    |
| `requestSnapshot` | —                                  |

The phone replies to every message with `{"ok": true}` and, after each
mutation, pushes a snapshot to the watch via application context:

```
lastFeed: ActivityEvent JSON | null
lastDiaper: ActivityEvent JSON | null
lastSleep: ActivityEvent JSON | null
activeSleepStart: ISO8601 string | null
activeNursingStart: ISO8601 string | null
generatedAt: ISO8601 string
```

Event JSON matches the Dart `ActivityEvent.toJson()` shape
(`id`, `type`, `startTime`, `endTime`, `data`, `note`, `createdAt`).

## Adding it to the iOS project

1. Open `flutter_app/ios/Runner.xcworkspace` in Xcode.
2. File → New → Target → watchOS → App.
   - Product name: `MiyaBabyWatch`
   - Bundle Identifier: `<iOS-app-bundle-id>.watchkitapp`
   - Make sure the watch target's deployment target matches your watch.
3. Drag the four Swift files from this folder into the new target
   (check "Copy items if needed", select the watch target only).
4. Build & run on the watch simulator (or a real watch paired to the
   iPhone running the Flutter app).

The iPhone side needs no extra setup: `flutter_app/ios/Runner/`
already contains `WatchBridge.swift` and an `AppDelegate.swift` that
wires the `miya_baby/watch` method channel to `WCSession`.
