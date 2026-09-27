# Anya Baby

A baby daily-routine tracker inspired by Nara Baby — log feedings, diapers,
sleep, and growth, with timers, history, stats, and an Apple Watch companion
for one-tap logging.

## What's inside

```
anya-baby/
├── flutter_app/   # Flutter app — iOS + Android
│   ├── lib/       # Dart source (models, screens, state, services)
│   └── ios/       # iOS Runner incl. WatchBridge.swift (WatchConnectivity)
└── watchos/       # Native watchOS companion app (SwiftUI)
    └── AnyaBabyWatch/
```

### Phone app (Flutter)

- **Home** — today's timeline, live timers, quick-log buttons
- **Feeding** — nursing timer (left/right), bottle (ml/oz), solids
- **Diaper** — wet / dirty / mixed, one tap
- **Sleep** — start/stop timer, nap vs night
- **Growth** — weight / height / head circumference with charts
- **History** — full log grouped by day, edit & delete
- **Stats** — last 7 days: feeds, sleep totals, diapers
- **Settings** — baby profile, metric/imperial units, JSON export
- All data stays on-device (Hive local storage). No account, no cloud.

### Apple Watch app (native watchOS)

Quick-log from the wrist: nursing, bottle, diaper, start/stop sleep.
Talks to the iPhone app over WatchConnectivity; the phone stays the
source of truth and pushes a live snapshot (last feed/diaper/sleep,
active timers) to the watch.

## Getting started

### Phone app

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install)
   (stable channel).
2. `cd flutter_app && flutter pub get`
3. `flutter run` (or open `ios/Runner.xcworkspace` in Xcode for iOS).

### Watch app

The watchOS app is a native companion target:

1. Open `flutter_app/ios/Runner.xcworkspace` in Xcode.
2. File → New → Target → watchOS → App. Name it `AnyaBabyWatch`,
   bundle id `<your-ios-bundle-id>.watchkitapp`.
3. Add the Swift files from `watchos/AnyaBabyWatch/` to the new target.
4. The iOS side is already wired: `ios/Runner/WatchBridge.swift` +
   `AppDelegate.swift` expose the `anya_baby/watch` method channel and
   relay messages between Dart and the watch.

See `watchos/README.md` for the message protocol details.

## Tech

- Flutter + Material 3, `flutter_riverpod` for state, `hive` for local storage
- watchOS: SwiftUI + WatchConnectivity
- License: MIT
