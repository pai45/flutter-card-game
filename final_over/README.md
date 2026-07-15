# Final Over

Final Over is an original, offline-first portrait cricket chase for Android. The player has six legal balls and two wickets to reach a deterministic target selected from 8, 10, 12, 14, 16, 18, and 20.

This package is a clean-room application. It does not import the parent app, share its services or persistence, or reference its game code, fonts, audio, and assets.

## Gameplay

- Read the revealed line and length during a three-second setup, then lock in
  Ground or Loft and an Off, Straight, or Leg direction.
- Hold HIT from ball release to load the bat, then release as the ball reaches
  the batter.
- Timing grades use the fixed Perfect, Good, Early/Late, Poor, and Miss windows.
- Wides and no-balls are deterministic illegal deliveries; no-balls establish a Free Hit.
- A single canonical ball simulation drives the batting camera, 360 ms transition, top-down fielding, catches, pickups, boundaries, and throws.
- Running supports Hold, Run Again, three completed runs, and Turn Back through 45% progress.
- Productive shots build combo and Power Shot charge. Each chase includes one target-compatible objective and a three-star result.

## Architecture

- `lib/domain/`: immutable pure-Dart rules, field vectors, tuning, PRNG, generation, contact, physics, and scoring
- `lib/application/`: `MatchController`, commands, fixed-step state machine, state/events, exact-once delivery ledger
- `lib/game/`: Flame loop and code-native visual system
- `lib/presentation/`: splash, home, how-to-play, gameplay HUD/controls, pause, and results
- `lib/services/`: local settings, optional audio, and optional haptics
- `tool/`: reproducible audio/icon production, clean-room audit, and 10,000-match simulation
- `docs/`: art bible and asset-provenance manifest

## Run and verify

From `final_over/` with Flutter 3.44.4:

```powershell
flutter pub get
dart run tool/clean_room_audit.dart
flutter analyze
flutter test
dart run tool/simulate_matches.dart --matches=10000
dart run tool/simulate_tiers.dart --matches-per-target=1000
flutter build apk --release
```

The fixed 10,000-match competent-bot gate is recorded in `test/verification/balance_report.md`. The release application does not request internet access.

## Identity

- Package: `final_over`
- Android application ID: `com.statoz.finalover`
- Display name: `Final Over`
- Version: `1.0.0+1`
- Orientation: portrait-up
