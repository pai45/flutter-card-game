# Grand Prix Dash (F1 racing) — Implementation & Porting Reference

> **Status:** BUILT · **Written:** 2026-09-16 · **Audience:** Flutter engineers rebuilding this game in another project
>
> **Source of truth:** `lib/games/grand_prix/` plus the files listed in §3.
> Everything under Appendix A–B is copied **verbatim** from the source repo by
> script. Appendix C is the source repo's host screen, for reference only.
> Appendix D contains the stand-ins you need so A–B compile on their own.
>
> **This document is self-contained.** Copy the files from Appendix A, B and D
> into a Flutter project at the same relative paths, add the dependencies in
> §4, and the game compiles and its test suite (Appendix E) passes. That exact
> check was run against this document (see §12).

---

## 1. What the game is

Grand Prix Dash is a **top-down arcade F1 race**: you against 19 CPU cars on
a vertically scrolling road.

| Rule | Value |
|---|---|
| Field | 20 cars. You start from a random slot **P8–P16** on a staggered two-wide grid (7 m apart, ±1.8 m lateral) |
| Distance | 1 lap (SPRINT), 3 laps (GRAND PRIX) or 5 laps (ENDURANCE); the XP multiplier is ×1 / ×2 / ×3 |
| Start | Five red lights come on 1 s apart, then go out after a random 0.2–1.5 s hold. Your **first ACCEL press** is graded on reaction time. Pressing before lights-out is a **jump start** |
| Controls | Hold ◀ / ▶ to steer, and hold BRAKE / ACCEL. All four are simultaneously holdable |
| Corners | Every corner has a **safe speed**. Carrying more scrubs speed. The road bends on screen and an unsteered car drifts to the outside, so you must steer into the bend |
| Failure | Stay below 14 m/s for **10 s** (stuck on the grass or against a wall) and the race ends as a **DNF** |
| Result | Finishing position, total time, personal best per circuit + distance, best overtake ("MVP move"), XP |

Five circuits (A.5):

| Circuit | Type | Stars | Lap length | Safe-speed range (m/s) |
|---|---|---|---|---|
| HARBOUR STREET | STREET | 4 | 2,635 m | 23–30 |
| DESERT MILE | SPEEDWAY | 2 | 4,736 m | 34–60 |
| EMERALD PARK | BALANCED | 3 | 3,347 m | 30–52 |
| MOUNTAIN PASS | TECHNICAL | 4 | 2,922 m | 28–38 |
| COASTAL SPRINT | FLOWING | 3 | 3,204 m | 42–64 |

## 2. Architecture

```
GrandPrixRaceScreen (Appendix C)       ← lights rig, HUD, toasts, controls, result; sound & haptics
 ├─ GrandPrixCubit (A)                 ← lobby picks, RaceSetup, five-lights timers + launch grading, settlement
 ├─ GameWidget(GrandPrixGame) (A)      ← Flame: fixed-step loop, camera, track + car components, sparks
 │    └─ GrandPrixEngine + RaceField (A) ← PURE Dart 1D simulation (distance + lateral per car), CPU drivers
 └─ GrandPrixControls (B)              ← four raw-Listener hold pads
```

Hard rules:

1. **The simulation is 1D per car.** Each car has a `distance` along the lap
   and a `lateral` offset (negative = left). Corners affect physics only
   through `safeSpeed`. The on-screen bend (`centerlineX` /
   `raceCenterlineX`) is rendering, **except** that the engine drifts
   unsteered cars outward by the same `kBendCompression = 0.21` ratio the
   renderer uses. Keep the two in sync.
2. **Fixed 1/120 s substeps**, with wall `dt` clamped to 1/30, "so a dropped
   frame can't tunnel a braking zone."
3. **Determinism:**
   - the field is built from `Random(setup.seed)`
   - the engine uses `Random(seed ^ 0x51f15eed)`
   - launches use `Random(seed ^ 0x1a)`
   - sparks use an unseeded `_fxRng`
4. **Only coarse callbacks go up:** `onPositionChanged`, `onOvertake`,
   `onPlayerFinished` and `onAudioEvent`. HUD values are `ValueNotifier`s:
   - `speedKph`
   - `lapProgress`
   - `currentLap`
   - `slipstreamActive`
   - `stuckSeconds`
5. **The start sequence lives in the cubit** (Dart `Timer`s), not in Flame.
   The Flame loop doesn't run the race until `game.startRace(grade)`.

## 3. File map

| Target path | Role | Where |
|---|---|---|
| `lib/games/grand_prix/grand_prix_engine.dart` | Tuning constants, launch grading, `CarState`/`RaceField`/`RaceSetup`, geometry, `buildField`, `applyLaunch`, `GrandPrixEngine` (physics, CPU, contact, finish) | A.1 |
| `lib/games/grand_prix/grand_prix_game.dart` | `FlameGame`: loop, input, camera/world mapping, track and car components, sparks, notifiers | A.2 |
| `lib/games/grand_prix/grand_prix_car_painter.dart` | Procedural top-down F1 car painter (also the lobby preview painter) | A.3 |
| `lib/models/grand_prix.dart` | Enums, `TrackSection`, `GrandPrixCircuit`, `OvertakeEvent`, `GrandPrixResult`, persisted `GrandPrixStats` | A.4 |
| `lib/data/grand_prix_circuits.dart` | The 5 circuits (section lists) | A.5 |
| `lib/data/grand_prix_drivers.dart` | CPU driver name generator | A.6 |
| `lib/data/grand_prix_liveries.dart` | Livery specs (colours) + ownership helpers | A.7 |
| `lib/blocs/grand_prix/grand_prix_state.dart` | `GrandPrixPhase` + state | A.8 |
| `lib/blocs/grand_prix/grand_prix_cubit.dart` | Lobby, lights, launch, settlement | A.9 |
| `lib/screens/grand_prix/widgets/grand_prix_controls.dart` | ◀ ▶ BRAKE ACCEL hold pads | B.1 |
| `lib/screens/grand_prix/grand_prix_race_screen.dart` | Host screen: `_RaceHud`, `_LightsRig`, `_LaunchGradeFlash`, `_LapFlash`, `_StuckWarning`, `_OvertakeToast`, `_ResultLayer` (**reference**) | C.1 |
| `lib/screens/grand_prix/widgets/grand_prix_result.dart` | Result overlay (**reference**) | C.2 |
| `lib/config/theme.dart` | **Stand-in** tokens | D.1 |
| `lib/models/progression.dart` | **Stand-in**: `cpuSmartness`, `grandPrixXpMultiplier`, `calculateGrandPrixXP` (verbatim) | D.2 |
| `lib/services/secure_storage_service.dart` | **Stand-in**: stats persistence (verbatim methods) | D.3 |
| `lib/utils/sound_effects.dart` | **Stand-in**: `SoundEffect` + `playSound` | D.4 |
| `lib/widgets/cyber/cyber_widgets.dart` | **Subset** of shared HUD widgets used by C (verbatim classes) | D.5 |
| `lib/widgets/cyber/cyber_cta_button.dart` | `HudCtaButton` (verbatim) | D.6 |
| `test/grand_prix_engine_test.dart` | Acceptance suite | E |

Not ported: the lobby (circuit/livery/lap pickers), the pit-deck
(racing-card) screen, the livery shop and selector, the starter-pack economy,
leaderboards, the global `GameBloc` and the audio controller.

The lobby now has its own port doc,
[grand-prix-lobby-port.md](grand-prix-lobby-port.md), built on top of this
one. The shipped lobby picks circuit and distance only; livery lives in the
Pit Deck.

## 4. Dependencies

```yaml
environment:
  sdk: ^3.12.2
dependencies:
  flutter: { sdk: flutter }
  flame: ^1.18.0              # verified against 1.38.0
  flutter_bloc: ^9.1.1
  shared_preferences: ^2.5.3  # storage stand-in
dev_dependencies:
  flutter_test: { sdk: flutter }
flutter:
  fonts:               # add `fonts: - asset:` entries pointing at your font files
    - family: Orbitron
    - family: Onest
```

No assets are needed; the track, kerbs, grass, finish line and cars are all
drawn on Canvas. **Rename `package:card_game/` in the test to your package
name.**

## 5. Rules reference (engine, A.1)

### 5.1 Tuning constants

Units are m, m/s, m/s² and seconds.

| Constant | Value | Meaning |
|---|---|---|
| `kTopSpeed` | 88 | ~316 km/h |
| `kAccel` / `kCoast` / `kBrake` | 26 / 10 / 44 | Throttle accel (× headroom), lift-off decay, braking |
| `kTrackHalfWidth` / `kWallLateral` | 4.5 / 6.5 | Asphalt edge / wall clamp |
| `kGrassTopSpeedFactor` / `kGrassDrag` | 0.55 / 22 | Off-track penalty |
| `kSteerRate` | 7.5 | Lateral m/s at full stick |
| `kBendCompression` | 0.21 | Outward drift ratio (matches the renderer) |
| `kStuckSpeed` / `kStuckTimeout` | 14 / 10 | DNF watchdog |
| `kSlipstreamMin/Max/Boost/Align` | 4 / 28 / 0.08 / 1.8 | Tow on straights: +8 % top speed when 4–28 m behind and within 1.8 m laterally |
| `kScrub` | 2.2 | Speed lost per s per m/s of corner overspeed |
| `kWallHitSpeedFactor` / `kWallSpinMinSpeed` / `kSpinSeconds` / `kSpinSpeedFactor` | 0.35 / 30 / 0.8 / 0.25 | Corner wall impact → spin |
| `kContactRearDecel` / `kContactFrontDecel` / `kContactPushRate` / `kHeavyContactClosingSpeed` | 22 / 10 / 12 / 22 | Car contact |
| `kJumpStartCutSeconds` | 2.0 | Throttle cut after a jump start |
| `kFieldSize` / `kGridGap` | 20 / 7 | Grid |
| `kMaxCornerError` | 0.35 | Weakest-CPU corner-entry overspeed |

`TrackSection.wallThreshold` is carried by the model and the circuit data,
but the current engine does not read it. Wall spins are decided by
`kWallSpinMinSpeed`.

### 5.2 Launch

| Reaction | Grade | Start speed | Accel × | Boost duration |
|---|---|---|---|---|
| < 150 ms | PERFECT | 14 | 1.5 | 3.0 s |
| < 300 ms | GREAT | 10 | 1.35 | 2.5 s |
| < 500 ms | GOOD | 7 | 1.2 | 2.0 s |
| otherwise (or no press within 2 s) | SLOW | 2 | 1.0 | — |
| before lights-out | JUMP | 0 | 1.0 | — plus a 2 s throttle cut |

- **CPU reaction:** each CPU samples `140 + (1−s)·160 + U·(120 + (1−s)·240)`
  ms, where `s` = strength. CPUs never jump-start.
- **Reduced motion:** the reaction test is skipped and you get GOOD.

### 5.3 Per-car step (`_stepCar`)

1. **Timers:** spin, throttle-cut and launch-boost timers count down.
2. **Slipstream:** checked on straights, and not while spinning.
3. **Effective top speed:** `88 × (slip ? 1.08) × CPU(0.9 + 0.1·strength +
   paceJitter) × (grass ? 0.55)`.
4. **Speed:**
   - brake: −44 dt
   - throttle: +26·launchAccel·(1 − v/top)·dt
   - neither: −10 dt
   - above top speed: ease down at 2×coast
   - spinning: capped at 88 × 0.25
5. **Corner overspeed:** `v −= 2.2·(v − safe)·dt`. This never moves the car
   sideways, and it raises the player's `tireScrub` event.
6. **Lateral:** `+= 7.5·steer·dt`, then `−= (centerline(ahead) −
   centerline(now)) × 0.21`.
7. **Grass:** `v −= 22·dt`.
8. **Wall at ±6.5:**
   - Clamp the car to the wall.
   - A *fresh* hit in a corner above 30 m/s means ×0.35 speed plus a 0.8 s
     spin.
   - Otherwise it's a graze that bleeds `44·0.75·dt`.
   - Either way, raise `wallContact` for the player.
9. **Distance:** `distance += v·dt`.

### 5.4 CPU drivers (`_cpuInputs`)

Each CPU gets these properties at build time:

- **Strength:** `cpuSmartness(playerLevel) = min(1, level/12)` ± 0.15.
- **Pace jitter:** ± 0.02.
- **Corner noise:** 0.2–1.

**Braking:** a physics stopping-distance check against the next corner
within 450 m (it wraps across the line on multi-lap races). The believed safe
speed is inflated by `0.35·(1−strength)·cornerNoise`, so weak CPUs arrive
hot. Inside a corner, any car above the *true* safe speed brakes.

**Steering:** toward a racing line: inside apex at 55 % of half-width in
corners, entry then exit side in chicanes, centre on straights. Strong CPUs
(> 0.5) occasionally cover an attacker on straights.

**Avoidance:** when a slower car is ahead within 3 car lengths and 1.3 widths
laterally, a CPU pulls to the free side on straights, and lifts inside 1.4
lengths.

### 5.5 Contact, position, finish

- **Contact:** adjacent cars (sorted by distance) overlapping within 5.5 m ×
  2.0 m both lose speed (rear 22, front 10 m/s²) and are pushed apart at
  12 m/s.
  - CPU↔CPU contact is softened ×0.35.
  - A closing speed > 22 spins the rear car for 0.56 s, at ≤ 78 % of the
    front car's speed.
- **Position:** `positionOf` = 1 + cars ahead. Finished cars rank by finish
  time and always beat running cars.
- **Finish:** at `distance ≥ lapLength × laps`, with sub-tick interpolated
  finish time. The player's crossing raises `playerCrossedLine`, and the
  game reports `PlayerRaceOutcome(position, lapTimeMs, bestOvertakeName)`.
- **DNF:** `playerStuckOut` reports `PlayerRaceOutcome(position: 20,
  lapTimeMs: 0, dnf: true)`.
- **Overtakes:** a CPU car that was ahead last tick and is now behind emits
  an `OvertakeEvent`. The game keeps the best one (highest place passed) for
  the result.

### 5.6 Settlement

`GrandPrixCubit.onRaceFinished` handles settlement:

- **Personal best:** decided per circuit + lap count (never on a DNF).
- **Result:** builds `GrandPrixResult`.
- **Stats:** updates `GrandPrixStats` (races, wins, podiums, best times, last
  picks) and persists it.

XP (`calculateGrandPrixXP`, D.2):

- **Base by position:** P1 26 · P2 22 · P3 18 · P4–6 12 · P7–10 8 · else 4.
- **Distance multiplier:** × 1/2/3 by lap count.
- **Personal best:** +3.
- **Coins:** never. XP is never negative.

The verdict (`grandPrixVerdict`) is win (P1), podium (≤ 3), points (≤ 10) or
finished.

## 6. Controls (B.1)

`GrandPrixControls(onLeft, onRight, onThrottle, onBrake)` renders four
`_HoldPad`s built on raw `Listener`, so they work multi-touch:

- `onPointerDown` → `true`
- `onPointerUp` / `onPointerCancel` → `false`

The screen wires them as follows:

```dart
onLeft:  (down) => game.setInputs(left: down),
onRight: (down) => game.setInputs(right: down),
onBrake: (down) => game.setInputs(brake: down),
onThrottle: (down) {
  game.setInputs(throttle: down);
  if (down && cubit.state.phase == GrandPrixPhase.lights) cubit.registerThrottleTap();
},
```

Steer is `right − left` (−1, 0 or +1). The player car sprite leans ±0.12 rad
while steering. Spinning cars wobble `sin(spinTimer·24)·0.7`.

## 7. Session flow and the host contract

`GrandPrixPhase`: `idle → grid → lights → racing → finished → result`.

1. **Setup:**
   - `cubit.load()`, then `selectCircuit`, `selectLivery(…, ownedLiveryIds:)`
     and `selectLaps(1|3|5)`.
   - `cubit.buildRace(playerLevel)` creates the seeded `RaceSetup` and enters
     `grid`.
2. **Push the race screen:**
   - In `initState`, build `GrandPrixGame(setup:, onPositionChanged:
     cubit.onPlayerPositionChanged, onOvertake:, onPlayerFinished:,
     onAudioEvent:, reducedMotion:)`.
   - Post-frame, wait **1200 ms**, then call
     `cubit.beginLights(reducedMotion:)`.
3. **Drive from a `BlocListener`** (on phase, launchGrade, lightsOn or
   lightsOut changes):
   - lightsOn increased → `gpLightOn`
   - lightsOut (and not a jump start) → `gpLightsOut`
   - `racing` → `game.startRace(grade)`, `gpJumpStart` on a jump start, start
     the engine loop, then a heavy (jump) or medium haptic
   - `finished` → go to step 5
4. **During the race:**
   - `onOvertake` → `cubit.onOvertake(e)` + `gpOvertake` + selection haptic.
   - `onAudioEvent` → `gpTireScrub` / `gpWallImpact` / `gpCarImpact`.
   - A lap increase → `_LapFlash` with `gpLap` and a medium haptic.
   - `stuckSeconds` climbing → `_StuckWarning`.
5. **`onPlayerFinished`:**
   - Play `gpFinish` unless it was a DNF, then call
     `cubit.onRaceFinished(outcome)`.
   - On `finished` (guard it to run once):
     - `game.stopRace()`, and stop the engine audio.
     - Play the result cue: `gpDnf` if retired, `gpPodium` if ≤ P3,
       `gpPoints` if in the points.
     - Heavy haptic.
     - Dispatch the XP.
     - After **900 ms**, `cubit.showResult()`.
6. **Leaving mid-race** (grid, lights or racing) calls `cubit.abandonRace()`
   (no stats, no reward). Guard it with `identical(cubit.state.setup,
   setupAtInit)`. RACE AGAIN calls `buildRace` again and replaces the route.

**Engine audio:** the source runs a dynamic engine loop whose pitch is
`speedKph / 320`, updated every 120 ms.

## 8. Feedback map

| Moment | Visual | Sound | Haptic |
|---|---|---|---|
| Each red light | `_LightsRig` lamp | gpLightOn | — |
| Lights out | lamps off | gpLightsOut | — |
| Launch graded | `_LaunchGradeFlash`: PERFECT LAUNCH (gold) / GREAT LAUNCH (success) / GOOD LAUNCH (cyan) / SLOW AWAY (amber) / JUMP START — THROTTLE CUT (danger) | gpJumpStart on JUMP | medium, or heavy on JUMP |
| Overtake | `_OvertakeToast` (`P{n} ▲ PASSED {NAME}`) | gpOvertake | selection |
| Wall contact | 18 danger sparks (unless reduced motion) | gpWallImpact | — |
| Car contact | 8 amber sparks | gpCarImpact | — |
| Tyre scrub | — | gpTireScrub | — |
| Slipstream | `TOW` chip in `_RaceHud` (`slipstreamActive`) | — | — |
| New lap | `_LapFlash` | gpLap | medium |
| Stuck | `_StuckWarning` countdown | — | — |
| Finish | result overlay (verdict banner, position readout, stats, XP) | gpFinish, then gpPodium / gpPoints / gpDnf | heavy |

## 9. Host touch-points in the reference screen (Appendix C)

| Source symbol | Replace with |
|---|---|
| `GameBloc` / `GrandPrixFinished(...)` | Your XP and history service |
| `AudioController` (scene, `startDynamicLoop` / `updateDynamicLoop` / `stopDynamicLoop`) | Your audio engine (a pitch-shifted engine loop) |
| `grandPrixEventSound`, `SoundEffect.gp*` | Your cues (§8) |
| `LevelUpCelebration`, level read-outs in C.2 | Your level-up UI |

## 10. Design rules carried by this code

- Colours come from `Cyber` tokens only, except livery colours
  (`GrandPrixLiverySpec`).
- Pads are calm plates with an accent fill when pressed, never a glow.
- The camera is locked to the centreline under the player, with no
  smoothing. Smoothing reads as the car sliding on its own.

## 11. Port checklist

1. Copy A, B and D. Add the §4 dependencies.
2. Build a lobby that calls `selectCircuit` / `selectLivery` / `selectLaps` /
   `buildRace`. See [grand-prix-lobby-port.md](grand-prix-lobby-port.md).
3. Port C.1 and C.2, applying §9. Keep the `BlocListener` drive and the
   post-frame lights kickoff.
4. Wire the §8 audio, including the engine loop.
5. Copy Appendix E, rename the package import, and run `flutter test`.
6. On device, verify:
   - a jump start (2 s throttle cut)
   - a perfect launch
   - running wide in a corner without steering
   - a wall spin
   - a stuck DNF after 10 s
   - a 3-lap race with the LAP flash

## 12. Verification performed for this document

A script read **only this markdown file**, wrote every Appendix A, B, D and E
code block to its heading's path in an empty Flutter package, and added the §4
dependencies (Flutter 3.44.4, flame 1.38.0, flutter_bloc 9.1.1).

- **Verbatim check:** every Appendix A and B block is byte-identical to the
  source repo file.
- **Analyze:** `flutter analyze` → **No issues found!**
- **Tests:** `flutter test` on Appendix E → **25 tests, all passed**, including the seeded 20-car full-race and 3-lap soak tests.
- **Not checked:** Appendix C was not compiled; it depends on the host
  systems in §9.

---

## Appendix A — Game code (verbatim)

Copy each file to the path in its heading. These are byte-for-byte copies of the source repo.

### A.1 `lib/games/grand_prix/grand_prix_engine.dart`

<sub>830 lines</sub>

```dart
/// Pure race simulation for Grand Prix Dash.
///
/// No Flutter/Flame imports — everything here is deterministic given a seeded
/// [Random] and a fixed tick, so it is fully unit-testable (mirrors
/// `football_chess_engine.dart`). The simulation is 1D: each car is a distance
/// along the lap centerline plus a lateral offset. Corners affect physics only
/// through their `safeSpeed`; how the road bends on screen is rendering-only
/// (see [centerlineX]).
library;

import 'dart:math';

import '../../models/grand_prix.dart';
import '../../models/progression.dart' show cpuSmartness;

// ---------------------------------------------------------------------------
// Tuning constants (m, m/s, m/s², seconds). All race feel lives here.
// ---------------------------------------------------------------------------

const double kTopSpeed = 88; // ~316 kph
const double kAccel = 26; // peak acceleration off the line
const double kCoast = 10; // speed decay with throttle released
const double kBrake = 44; // braking deceleration
const double kCarLength = 5.5;
const double kCarWidth = 2.0;

/// Drivable asphalt half-width (~4 car-widths of total band + margins).
const double kTrackHalfWidth = 4.5;

/// Grass runs from the asphalt edge to the wall; the wall is a hard clamp.
const double kWallLateral = 6.5;
const double kGrassTopSpeedFactor = 0.55;

/// Off the asphalt the car bogs down hard — enough that a car that runs wide
/// and is NOT steered back grinds to a crawl and gets stuck (below
/// [kStuckSpeed]), which eventually ends the race (see [kStuckTimeout]).
const double kGrassDrag = 22; // direct m/s² lost while off the asphalt

const double kSteerRate = 7.5; // lateral m/s at full stick

/// The rendered road compresses corner curvature to this fraction of lane
/// widths (`bendPxPerMeter = pxPerMeterX * kBendCompression` in the Flame
/// game). The physics drifts the car to the OUTSIDE of a bend by the same
/// amount as the road curves, so a straight-heading (un-steered) car runs wide
/// and the player must steer INTO the corner to follow it. Keep the two in sync.
const double kBendCompression = 0.21;

/// Below this forward speed (m/s) the player counts as stuck — reached only by
/// running off / into a barrier and stopping, never by normal cornering (the
/// slowest safe corner is ~23 m/s).
const double kStuckSpeed = 14;

/// Seconds the player may stay stuck (below [kStuckSpeed]) before the race is
/// over — steer back onto the track and get moving to reset it.
const double kStuckTimeout = 10.0;
const double kSlipstreamMin = 4;
const double kSlipstreamMax = 28;
const double kSlipstreamBoost = 0.08;
const double kSlipstreamAlign = 1.8;

/// Speed scrubbed per second per m/s of corner overspeed (tyres scrubbing when
/// the car carries more than the safe entry speed). Overspeed bleeds off as a
/// pure speed loss — it never pushes the car sideways, so the driver keeps full
/// lateral control through the bend and the car only leaves its line on steer.
const double kScrub = 2.2;

const double kWallHitSpeedFactor = 0.35;

/// A corner wall impact only spins the car (the one hard-shake in a turn) when
/// it arrives with real speed — a slow graze along the barrier just scrubs.
const double kWallSpinMinSpeed = 30;
const double kSpinSeconds = 0.8;
const double kSpinSpeedFactor = 0.25; // crawl speed multiplier while spinning
const double kContactRearDecel = 22; // m/s² lost by the rear car while touching
const double kContactFrontDecel = 10; // m/s² lost by the car hit from behind
const double kContactPushRate = 12; // lateral separation m/s while overlapping
const double kHeavyContactClosingSpeed = 22;
const double kJumpStartCutSeconds = 2.0;
const int kFieldSize = 20;
const double kGridGap = 7.0; // metres between grid slots
const double kMaxCornerError = 0.35; // weak-CPU corner-entry overspeed fraction

// ---------------------------------------------------------------------------
// Launch grading (the lights-out skill moment)
// ---------------------------------------------------------------------------

LaunchGrade gradeLaunch(Duration reaction) {
  final ms = reaction.inMilliseconds;
  if (ms < 150) return LaunchGrade.perfect;
  if (ms < 300) return LaunchGrade.great;
  if (ms < 500) return LaunchGrade.good;
  return LaunchGrade.slow;
}

/// Off-the-line reward for a launch grade: an instant rolling start speed plus
/// a temporary acceleration multiplier. A jump start gets nothing — the
/// throttle cut is applied separately in [applyLaunch].
({double initialSpeed, double accelFactor, double boostSeconds}) launchBoost(
  LaunchGrade grade,
) => switch (grade) {
  LaunchGrade.perfect => (
    initialSpeed: 14,
    accelFactor: 1.5,
    boostSeconds: 3.0,
  ),
  LaunchGrade.great => (initialSpeed: 10, accelFactor: 1.35, boostSeconds: 2.5),
  LaunchGrade.good => (initialSpeed: 7, accelFactor: 1.2, boostSeconds: 2.0),
  LaunchGrade.slow => (initialSpeed: 2, accelFactor: 1.0, boostSeconds: 0),
  LaunchGrade.jump => (initialSpeed: 0, accelFactor: 1.0, boostSeconds: 0),
};

/// CPU reaction sample: stronger fields launch better (never jump-start).
Duration sampleCpuReaction(double strength, Random random) {
  final bestMs = 140 + (1 - strength) * 160;
  final spreadMs = 120 + (1 - strength) * 240;
  return Duration(
    milliseconds: (bestMs + random.nextDouble() * spreadMs).round(),
  );
}

// ---------------------------------------------------------------------------
// Car / field state
// ---------------------------------------------------------------------------

enum CarMode { racing, spinning, finished }

class CarState {
  CarState({
    required this.index,
    required this.isPlayer,
    required this.name,
    required this.livery,
    required this.distance,
    required this.lateral,
    this.strength = 0,
    this.paceJitter = 0,
    this.cornerNoise = 0,
  });

  final int index;
  final bool isPlayer;
  final String name;
  final GrandPrixLivery livery;

  double distance; // m along the lap; negative on the grid behind the line
  double lateral; // m, negative = left
  double speed = 0;
  int sectionIndex = 0;
  CarMode mode = CarMode.racing;
  double spinTimer = 0;
  double throttleCutTimer = 0;
  double launchBoostTimer = 0;
  double launchAccelFactor = 1.0;
  bool slipstreaming = false;
  double finishTimeMs = -1;

  // CPU personality (seeded at build; player leaves these at 0/1).
  final double strength; // cpuSmartness(level) with per-car spread
  final double paceJitter; // small ± on top speed
  final double cornerNoise; // 0..1 — how hot this driver enters corners
  double targetLateral = 0;

  bool get finished => mode == CarMode.finished;
  bool get spinning => mode == CarMode.spinning;
  bool get onGrass => lateral.abs() > kTrackHalfWidth;
}

class RaceInputs {
  const RaceInputs({this.steer = 0, this.throttle = false, this.brake = false});

  final double steer; // −1 (left) .. 1 (right)
  final bool throttle;
  final bool brake;
}

/// Everything the cubit fixes at race start so the Flame game and the engine
/// replay the same race for the same seed.
class RaceSetup {
  const RaceSetup({
    required this.circuit,
    required this.playerLivery,
    required this.playerLevel,
    required this.startPosition,
    required this.seed,
    this.laps = 1,
  });

  final GrandPrixCircuit circuit;
  final GrandPrixLivery playerLivery;
  final int playerLevel;
  final int startPosition; // grid slot, P8–P16
  final int seed;

  /// Race distance in laps (1 = sprint).
  final int laps;
}

class RaceField {
  RaceField({required this.circuit, required this.cars, this.laps = 1})
    : sectionStarts = _cumulative(circuit.sections);

  final GrandPrixCircuit circuit;
  final List<CarState> cars;
  final List<double> sectionStarts;
  final int laps;
  double raceClockMs = 0;

  /// Full race distance — the finish line's position on the distance axis.
  double get raceLength => circuit.lapLength * laps;

  /// How long the player has been stuck (below [kStuckSpeed]) without a break.
  /// Resets the instant the player is moving again; [kStuckTimeout] ends it.
  double playerStuckSeconds = 0;

  CarState get player => cars.firstWhere((car) => car.isPlayer);

  static List<double> _cumulative(List<TrackSection> sections) {
    final starts = <double>[];
    var s = 0.0;
    for (final section in sections) {
      starts.add(s);
      s += section.length;
    }
    return starts;
  }
}

/// What the Flame game reports up to the cubit when the player crosses the
/// line — everything needed to settle the race.
class PlayerRaceOutcome {
  const PlayerRaceOutcome({
    required this.position,
    required this.lapTimeMs,
    this.bestOvertakeName,
    this.dnf = false,
  });

  final int position;
  final int lapTimeMs;

  /// Name of the highest-placed car the player passed on track (MVP move).
  final String? bestOvertakeName;

  /// True when the player never finished — they got stuck and timed out.
  final bool dnf;
}

/// Coarse per-tick events — everything the HUD/cubit cares about. High-
/// frequency values (speed, exact distances) are read straight off the field.
class RaceTickEvents {
  int? playerPosition; // set only on change
  final List<OvertakeEvent> overtakes = [];
  bool playerWallContact = false;
  bool playerContact = false;
  bool playerTireScrub = false;
  bool playerCrossedLine = false;

  /// The player stayed stuck past [kStuckTimeout] — the race is over (DNF).
  bool playerStuckOut = false;

  bool get isEmpty =>
      playerPosition == null &&
      overtakes.isEmpty &&
      !playerWallContact &&
      !playerContact &&
      !playerTireScrub &&
      !playerCrossedLine &&
      !playerStuckOut;
}

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

int sectionAt(
  List<double> sectionStarts,
  List<TrackSection> sections,
  double s,
) {
  if (s <= 0) return 0;
  for (var i = sections.length - 1; i >= 0; i--) {
    if (s >= sectionStarts[i]) return i;
  }
  return 0;
}

double _smoothstep(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Distance within the current lap. Grid distances (≤ 0, behind the line)
/// pass through untouched so grid cars still resolve to section 0.
double lapLocalDistance(double lapLength, double distance) =>
    distance <= 0 ? distance : distance % lapLength;

/// Multi-lap centerline: continuous across the start/finish line so cars on
/// different laps agree on where the road is. Each completed lap contributes
/// the full-lap shift; the current lap adds the usual [centerlineX].
double raceCenterlineX(
  GrandPrixCircuit circuit,
  List<double> sectionStarts,
  double s,
) {
  if (s <= 0) return 0;
  final lapLength = circuit.lapLength;
  final lap = s ~/ lapLength;
  final local = s - lap * lapLength;
  if (lap == 0) return centerlineX(circuit, sectionStarts, local);
  return lap * centerlineX(circuit, sectionStarts, lapLength) +
      centerlineX(circuit, sectionStarts, local);
}

/// Rendering-only: the sideways world offset of the track centerline at lap
/// distance [s]. Straights hold their offset; a corner eases across by its
/// signed bend; a chicane swings out and back (an S through the section).
double centerlineX(
  GrandPrixCircuit circuit,
  List<double> sectionStarts,
  double s,
) {
  var x = 0.0;
  final clamped = s.clamp(0.0, circuit.lapLength);
  for (var i = 0; i < circuit.sections.length; i++) {
    final section = circuit.sections[i];
    final start = sectionStarts[i];
    final end = start + section.length;
    if (clamped <= start) break;
    final t = ((clamped.clamp(start, end)) - start) / section.length;
    switch (section.type) {
      case TrackSectionType.straight:
        break;
      case TrackSectionType.corner:
        x += section.signedBend * _smoothstep(t);
      case TrackSectionType.chicane:
        // Out by half the bend, then back — net zero shift.
        x += section.signedBend * sin(t * pi) * 0.5;
    }
  }
  return x;
}

/// 1 + the number of cars ahead. Finished cars rank by finish time and always
/// beat running cars.
int positionOf(RaceField field, CarState car) {
  var ahead = 0;
  for (final other in field.cars) {
    if (identical(other, car)) continue;
    if (car.finished) {
      if (other.finished && other.finishTimeMs < car.finishTimeMs) ahead++;
    } else if (other.finished || other.distance > car.distance) {
      ahead++;
    }
  }
  return 1 + ahead;
}

// ---------------------------------------------------------------------------
// Field construction + launch
// ---------------------------------------------------------------------------

RaceField buildField(RaceSetup setup, List<String> driverNames, Random random) {
  assert(driverNames.length >= kFieldSize - 1);
  final baseStrength = cpuSmartness(setup.playerLevel);
  final cpuLiveries = GrandPrixLivery.values
      .where((livery) => livery != setup.playerLivery)
      .toList();

  final cars = <CarState>[];
  var cpuCount = 0;
  for (var slot = 1; slot <= kFieldSize; slot++) {
    final isPlayer = slot == setup.startPosition;
    // Staggered two-wide grid behind the start line.
    final gridDistance = -kGridGap * slot;
    final gridLateral = (slot.isOdd ? -1.8 : 1.8);
    if (isPlayer) {
      cars.add(
        CarState(
          index: cars.length,
          isPlayer: true,
          name: 'YOU',
          livery: setup.playerLivery,
          distance: gridDistance,
          lateral: gridLateral,
        ),
      );
    } else {
      cars.add(
        CarState(
          index: cars.length,
          isPlayer: false,
          name: driverNames[cpuCount],
          livery: cpuLiveries[cpuCount % cpuLiveries.length],
          distance: gridDistance,
          lateral: gridLateral,
          strength: (baseStrength + (random.nextDouble() - 0.5) * 0.3).clamp(
            0.0,
            1.0,
          ),
          paceJitter: (random.nextDouble() - 0.5) * 0.04,
          cornerNoise: 0.2 + random.nextDouble() * 0.8,
        ),
      );
      cpuCount++;
    }
  }
  return RaceField(circuit: setup.circuit, cars: cars, laps: setup.laps);
}

/// Applies lights-out launches: the player's graded boost (or jump-start
/// throttle cut) and a sampled reaction for every CPU. Call once when racing
/// goes live.
void applyLaunch(RaceField field, LaunchGrade playerGrade, Random random) {
  for (final car in field.cars) {
    final grade = car.isPlayer
        ? playerGrade
        : gradeLaunch(sampleCpuReaction(car.strength, random));
    final boost = launchBoost(grade);
    car.speed = boost.initialSpeed;
    car.launchBoostTimer = boost.boostSeconds;
    car.launchAccelFactor = boost.accelFactor;
    if (car.isPlayer && grade == LaunchGrade.jump) {
      car.throttleCutTimer = kJumpStartCutSeconds;
    }
  }
}

// ---------------------------------------------------------------------------
// The engine
// ---------------------------------------------------------------------------

class GrandPrixEngine {
  GrandPrixEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Advances the whole field by [dt] seconds. Mutates [field]; returns the
  /// coarse events of this tick.
  RaceTickEvents tick(RaceField field, RaceInputs playerInputs, double dt) {
    final events = RaceTickEvents();
    final player = field.player;
    final prevPlayerPosition = positionOf(field, player);
    final prevAhead = <int>{
      for (final car in field.cars)
        if (!car.isPlayer && !player.finished && car.distance > player.distance)
          car.index,
    };

    field.raceClockMs += dt * 1000;

    for (final car in field.cars) {
      if (car.finished) {
        // Coast over the line so finishers glide out of frame.
        car.speed = max(0, car.speed - kCoast * dt);
        car.distance += car.speed * dt;
        continue;
      }
      final inputs = car.isPlayer ? playerInputs : _cpuInputs(field, car);
      _stepCar(field, car, inputs, dt, events);
    }

    _resolveContacts(field, dt, events);
    _detectFinishes(field, dt, events);

    // Position + overtake diff (player only — the HUD cares about the player).
    final newPosition = positionOf(field, player);
    if (newPosition != prevPlayerPosition) events.playerPosition = newPosition;
    if (!player.finished) {
      for (final car in field.cars) {
        if (car.isPlayer || !prevAhead.contains(car.index)) continue;
        if (car.distance <= player.distance && !car.finished) {
          events.overtakes.add(
            OvertakeEvent(
              overtakenName: car.name,
              overtakenPosition: newPosition,
              atDistance: player.distance,
            ),
          );
        }
      }
    }

    // Stuck watchdog: if the player runs off / into a barrier and grinds to a
    // crawl, the clock runs out and the race is over. Reset the moment they're
    // moving again — steering back onto the track is the escape.
    if (!player.finished) {
      if (player.speed < kStuckSpeed) {
        field.playerStuckSeconds += dt;
        if (field.playerStuckSeconds >= kStuckTimeout) {
          events.playerStuckOut = true;
        }
      } else {
        field.playerStuckSeconds = 0;
      }
    }
    return events;
  }

  // -- per-car step ---------------------------------------------------------

  void _stepCar(
    RaceField field,
    CarState car,
    RaceInputs inputs,
    double dt,
    RaceTickEvents events,
  ) {
    final sections = field.circuit.sections;
    car.sectionIndex = sectionAt(
      field.sectionStarts,
      sections,
      lapLocalDistance(field.circuit.lapLength, car.distance),
    );
    final section = sections[car.sectionIndex];
    final prevLateral = car.lateral;

    // Timers.
    if (car.spinTimer > 0) {
      car.spinTimer = max(0, car.spinTimer - dt);
      if (car.spinTimer == 0 && car.mode == CarMode.spinning) {
        car.mode = CarMode.racing;
      }
    }
    if (car.throttleCutTimer > 0) {
      car.throttleCutTimer = max(0, car.throttleCutTimer - dt);
    }
    if (car.launchBoostTimer > 0) {
      car.launchBoostTimer = max(0, car.launchBoostTimer - dt);
      if (car.launchBoostTimer == 0) car.launchAccelFactor = 1.0;
    }

    // Slipstream (straights only).
    car.slipstreaming = false;
    if (section.isStraight && !car.spinning) {
      for (final other in field.cars) {
        if (identical(other, car)) continue;
        final gap = other.distance - car.distance;
        if (gap >= kSlipstreamMin &&
            gap <= kSlipstreamMax &&
            (other.lateral - car.lateral).abs() < kSlipstreamAlign) {
          car.slipstreaming = true;
          break;
        }
      }
    }

    // Effective top speed.
    var effTop = kTopSpeed;
    if (car.slipstreaming) effTop *= 1 + kSlipstreamBoost;
    if (!car.isPlayer) effTop *= 0.9 + 0.1 * car.strength + car.paceJitter;
    if (car.onGrass) effTop *= kGrassTopSpeedFactor;

    // Speed integration.
    final throttleOn =
        inputs.throttle && car.throttleCutTimer == 0 && !car.spinning;
    if (inputs.brake && !car.spinning) {
      car.speed = max(0, car.speed - kBrake * dt);
    } else if (throttleOn) {
      final headroom = max(0.0, 1 - car.speed / effTop);
      car.speed += kAccel * car.launchAccelFactor * headroom * dt;
    } else {
      car.speed = max(0, car.speed - kCoast * dt);
    }
    if (car.speed > effTop) {
      // Ease down when boost/slipstream expires instead of snapping.
      car.speed = max(effTop, car.speed - kCoast * 2 * dt);
    }
    if (car.spinning) car.speed = min(car.speed, kTopSpeed * kSpinSpeedFactor);

    // Corner resolution — carrying more than the safe entry speed scrubs speed
    // (tyres fighting for grip) but NEVER moves the car sideways on its own.
    // The driver keeps full lateral control, so the car holds its line through
    // a corner and only leaves it when the player actually steers. Steering all
    // the way into the outside wall is what spins the car — handled at the wall
    // clamp below.
    final safeSpeed = section.safeSpeed;
    if (safeSpeed != null && !car.spinning && car.speed > safeSpeed) {
      car.speed = max(0, car.speed - kScrub * (car.speed - safeSpeed) * dt);
      if (car.isPlayer) events.playerTireScrub = true;
    }

    // Lateral integration: steering, then the corner's curvature drift.
    if (!car.spinning) {
      car.lateral += kSteerRate * inputs.steer.clamp(-1.0, 1.0) * dt;

      // Curvature drift: the car holds a straight heading unless steered, so as
      // the road bends its centerline slides out from under it. Without steering
      // the car runs to the OUTSIDE of the corner (matching the drawn bend);
      // the player must steer INTO the bend to follow the road. Straights don't
      // bend, so they add no drift — the car only moves on the player's input.
      final ahead = car.distance + car.speed * dt;
      final centerShift =
          raceCenterlineX(field.circuit, field.sectionStarts, ahead) -
          raceCenterlineX(field.circuit, field.sectionStarts, car.distance);
      car.lateral -= centerShift * kBendCompression;
    }
    if (car.onGrass) {
      car.speed = max(0, car.speed - kGrassDrag * dt);
    }
    if (car.lateral.abs() >= kWallLateral) {
      // Fresh hit = the car was strictly inside the wall last tick and reached
      // it this tick. Reaching the wall exactly (steering lands on the clamp)
      // still counts; once pinned, prevLateral == kWallLateral so it reads as a
      // graze, not a repeat spin.
      final freshHit = prevLateral.abs() < kWallLateral;
      car.lateral = car.lateral.clamp(-kWallLateral, kWallLateral);
      if (freshHit &&
          !section.isStraight &&
          !car.spinning &&
          car.speed > kWallSpinMinSpeed) {
        // Ran clean off the road into the outside barrier mid-corner: big loss
        // + spin. This is the ONLY hard-shake in a turn, and it can't trigger
        // until the car is past the kerb and actually into the wall.
        car.speed *= kWallHitSpeedFactor;
        car.mode = CarMode.spinning;
        car.spinTimer = kSpinSeconds;
      } else {
        // A graze, or scraping the wall down a straight, just bleeds speed.
        car.speed = max(0, car.speed - kBrake * 0.75 * dt);
      }
      if (car.isPlayer) events.playerWallContact = true;
    }

    // Distance integration.
    car.distance += car.speed * dt;
  }

  // -- CPU driver -----------------------------------------------------------

  RaceInputs _cpuInputs(RaceField field, CarState car) {
    var brake = _shouldBrake(
      field,
      car,
      errorFactor: kMaxCornerError * (1 - car.strength) * car.cornerNoise,
    );

    // Steering: ease toward the racing line; defend the inside on straights.
    var target = _racingLineLateral(field, car);
    final section = field.circuit.sections[car.sectionIndex];
    if (section.isStraight && car.strength > 0.5) {
      final attacker = _attackerBehind(field, car);
      if (attacker != null && _random.nextDouble() < car.strength * 0.03) {
        // Occasional covering move toward the attacker's side.
        car.targetLateral = attacker.lateral.clamp(
          -kTrackHalfWidth * 0.8,
          kTrackHalfWidth * 0.8,
        );
      }
      if (car.targetLateral != 0) target = car.targetLateral;
    } else {
      car.targetLateral = 0;
    }

    // Avoidance/passing: never plow into a slower car ahead — pull to the
    // free side (on straights this doubles as the overtake setup) and lift
    // when right on its gearbox.
    final blocker = _blockerAhead(field, car);
    if (blocker != null) {
      if (section.isStraight) {
        final passSide = blocker.lateral >= car.lateral ? -1 : 1;
        target = (car.lateral + passSide * kCarWidth * 1.6).clamp(
          -kTrackHalfWidth,
          kTrackHalfWidth,
        );
      }
      if (blocker.distance - car.distance < kCarLength * 1.4) brake = true;
    }

    final delta = target - car.lateral;
    final steer = delta.abs() < 0.25
        ? 0.0
        : (delta.sign * min(1, delta.abs() / 2));
    return RaceInputs(steer: steer, throttle: !brake, brake: brake);
  }

  /// The nearest meaningfully slower car directly ahead within a couple of
  /// car lengths — the one this CPU must steer around or lift for.
  CarState? _blockerAhead(RaceField field, CarState car) {
    CarState? nearest;
    var nearestGap = double.infinity;
    for (final other in field.cars) {
      if (identical(other, car) || other.finished) continue;
      final gap = other.distance - car.distance;
      if (gap <= 0 || gap > kCarLength * 3) continue;
      if ((other.lateral - car.lateral).abs() > kCarWidth * 1.3) continue;
      if (other.speed > car.speed - 1) continue;
      if (gap < nearestGap) {
        nearest = other;
        nearestGap = gap;
      }
    }
    return nearest;
  }

  /// Physics stopping-distance check against the next corner. [errorFactor]
  /// inflates the believed-safe entry speed — weak CPUs arrive hot and pay in
  /// the corner resolution.
  bool _shouldBrake(
    RaceField field,
    CarState car, {
    required double errorFactor,
  }) {
    final sections = field.circuit.sections;
    final lapLength = field.circuit.lapLength;
    final localDistance = lapLocalDistance(lapLength, car.distance);
    final index = car.sectionIndex;
    final current = sections[index];
    double believed(double safe) => safe * (1 + errorFactor);

    // Already inside a corner and over the TRUE safe speed → back off. The
    // error inflation only applies to the entry lookahead (below), so a weak
    // CPU still brakes late and arrives hot; but once in the corner no car
    // keeps the throttle pinned above the grip limit and slowly runs itself
    // off onto the grass.
    final currentSafe = current.safeSpeed;
    if (currentSafe != null && car.speed > currentSafe) return true;

    // Look ahead to the next corner within braking range, wrapping across the
    // start/finish line on multi-lap races (every circuit opens with a long
    // straight, so the wrap never triggers braking before the actual finish).
    for (
      var step = currentSafe != null ? 1 : 0;
      step < sections.length;
      step++
    ) {
      final i = (index + step) % sections.length;
      var distTo = field.sectionStarts[i] - localDistance;
      if (i < index || (i == index && step > 0)) distTo += lapLength;
      if (distTo > 450) break;
      final nextSafe = sections[i].safeSpeed;
      if (nextSafe == null) continue;
      final target = believed(nextSafe);
      if (car.speed <= target) break;
      final need =
          (car.speed * car.speed - target * target) / (2 * kBrake) +
          car.speed * 0.15;
      if (need >= distTo) return true;
      break;
    }
    return false;
  }

  /// The lateral the racing line wants at the car's current spot: apex on the
  /// inside through corners/chicanes, track middle on straights.
  double _racingLineLateral(RaceField field, CarState car) {
    final section = field.circuit.sections[car.sectionIndex];
    switch (section.type) {
      case TrackSectionType.straight:
        return 0;
      case TrackSectionType.corner:
        final insideSign = section.direction == CornerDirection.left ? -1 : 1;
        return insideSign * kTrackHalfWidth * 0.55;
      case TrackSectionType.chicane:
        // Flick to the entry side then across — approximate with the entry
        // side for the first half, exit side for the second.
        final start = field.sectionStarts[car.sectionIndex];
        final local = lapLocalDistance(field.circuit.lapLength, car.distance);
        final t = (local - start) / section.length;
        final entrySign = section.direction == CornerDirection.left ? -1 : 1;
        return (t < 0.5 ? entrySign : -entrySign) * kTrackHalfWidth * 0.45;
    }
  }

  CarState? _attackerBehind(RaceField field, CarState car) {
    CarState? nearest;
    var nearestGap = double.infinity;
    for (final other in field.cars) {
      if (identical(other, car) || other.finished) continue;
      final gap = car.distance - other.distance;
      if (gap > 0 && gap < kSlipstreamMax && gap < nearestGap) {
        nearest = other;
        nearestGap = gap;
      }
    }
    return nearest;
  }

  // -- contact --------------------------------------------------------------

  void _resolveContacts(RaceField field, double dt, RaceTickEvents events) {
    final ordered = [...field.cars]
      ..sort((a, b) => a.distance.compareTo(b.distance));
    for (var i = 0; i < ordered.length - 1; i++) {
      final rear = ordered[i];
      final front = ordered[i + 1];
      if (rear.finished || front.finished) continue;
      if (front.distance - rear.distance > kCarLength) continue;
      if ((front.lateral - rear.lateral).abs() > kCarWidth) continue;

      // Contact costs BOTH cars speed — it's a downside, not a weapon. CPU↔CPU
      // touches are softened: full contact physics is a player experience, and
      // unsoftened it bunches high-level fields into slow contact trains.
      final playerInvolved = rear.isPlayer || front.isPlayer;
      final softening = playerInvolved ? 1.0 : 0.35;
      final closing = rear.speed - front.speed;
      rear.speed = max(0, rear.speed - kContactRearDecel * softening * dt);
      front.speed = max(0, front.speed - kContactFrontDecel * softening * dt);
      // Nudge apart laterally.
      final push =
          (rear.lateral <= front.lateral ? -1 : 1) * kContactPushRate * dt;
      rear.lateral = (rear.lateral + push).clamp(-kWallLateral, kWallLateral);
      front.lateral = (front.lateral - push).clamp(-kWallLateral, kWallLateral);

      if (closing > kHeavyContactClosingSpeed && !rear.spinning) {
        rear.mode = CarMode.spinning;
        // A car-contact spin is lighter than a wall smash: a shorter spin (vs
        // the full kSpinSeconds a mid-corner wall hit keeps) and much less speed
        // lost, so a heavy rear-end is a setback, not a race-ender.
        rear.spinTimer = kSpinSeconds * 0.7;
        rear.speed = min(rear.speed, front.speed * 0.78);
      }
      if (rear.isPlayer || front.isPlayer) events.playerContact = true;
    }
  }

  // -- finish ---------------------------------------------------------------

  void _detectFinishes(RaceField field, double dt, RaceTickEvents events) {
    final raceLength = field.raceLength;
    for (final car in field.cars) {
      if (car.finished || car.distance < raceLength) continue;
      // Sub-tick interpolation for a fair classification.
      final overshoot = car.distance - raceLength;
      final overshootMs = car.speed > 0 ? (overshoot / car.speed) * 1000 : 0;
      car.mode = CarMode.finished;
      car.finishTimeMs = field.raceClockMs - overshootMs;
      if (car.isPlayer) events.playerCrossedLine = true;
    }
  }
}
```

### A.2 `lib/games/grand_prix/grand_prix_game.dart`

<sub>569 lines</sub>

```dart
import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../config/theme.dart';
import '../../data/grand_prix_drivers.dart';
import '../../data/grand_prix_liveries.dart';
import '../../models/grand_prix.dart';
import 'grand_prix_car_painter.dart';
import 'grand_prix_engine.dart';

enum GrandPrixAudioEvent { tireScrub, wallContact, carContact }

/// Flame renderer + real-time loop for Grand Prix Dash.
///
/// Unlike turn-based Football Chess (where the cubit owns the clock), the 60fps
/// simulation lives HERE: `update(dt)` advances the pure engine in fixed
/// substeps and only coarse events (position change, overtake, finish) are
/// called back up to the cubit. High-frequency HUD values (speed, lap
/// progress) are exposed as [ValueNotifier]s so nothing emits bloc state per
/// frame. All drawing is procedural Canvas on `Cyber` tokens — livery colors
/// are the one content-color exception.
class GrandPrixGame extends FlameGame {
  GrandPrixGame({
    required this.setup,
    required this.onPositionChanged,
    required this.onOvertake,
    required this.onPlayerFinished,
    required this.onAudioEvent,
    this.reducedMotion = false,
  });

  final RaceSetup setup;
  final void Function(int position) onPositionChanged;
  final void Function(OvertakeEvent event) onOvertake;
  final void Function(PlayerRaceOutcome outcome) onPlayerFinished;
  final void Function(GrandPrixAudioEvent event) onAudioEvent;
  final bool reducedMotion;

  // HUD bindings — cheap 60fps reads, never bloc emissions.
  final ValueNotifier<double> speedKph = ValueNotifier(0);
  final ValueNotifier<double> lapProgress = ValueNotifier(0);
  final ValueNotifier<bool> slipstreamActive = ValueNotifier(false);

  /// 1-based lap the player is on (clamped to [laps]); the HUD shows LAP n/N
  /// and the race screen flashes a beat when it climbs.
  final ValueNotifier<int> currentLap = ValueNotifier(1);

  int get laps => setup.laps;

  /// Seconds the player has been stuck; the HUD raises a get-moving warning as
  /// this climbs toward [kStuckTimeout].
  final ValueNotifier<double> stuckSeconds = ValueNotifier(0);

  late final RaceField field;
  late final GrandPrixEngine _engine;
  final List<_CarComponent> _carSprites = [];
  final Random _fxRng = Random();

  bool _running = false;
  bool _finishedReported = false;
  bool _left = false, _right = false, _throttle = false, _brake = false;
  double _accumulator = 0;
  double _cameraRefX = 0;
  OvertakeEvent? _bestOvertake;

  static const double _subDt = 1 / 120;

  /// Player car's fixed screen row (fraction of height from the top).
  static const double _anchorFrac = 0.68;

  // -- camera / world→screen mapping ----------------------------------------

  /// Vertical px per metre — sized so the player can see ~95m up the road.
  double get pxPerMeterY => max(3.0, size.y * _anchorFrac / 95);

  /// Lateral px per metre for lane offsets — the asphalt band spans ~42% of
  /// the screen width.
  double get pxPerMeterX => size.x * 0.42 / (kTrackHalfWidth * 2);

  /// Curvature is compressed relative to lane widths so a 30m corner bend
  /// sweeps across the screen instead of off it (pseudo-scroller trick). The
  /// engine drifts the car wide by this same ratio (see [kBendCompression]) so
  /// the physics and the drawn road agree on how sharp the bend is.
  double get bendPxPerMeter => pxPerMeterX * kBendCompression;

  double get anchorY => size.y * _anchorFrac;

  Offset worldToScreen(double distance, double lateral) {
    final bend =
        raceCenterlineX(field.circuit, field.sectionStarts, distance) *
        bendPxPerMeter;
    return Offset(
      size.x / 2 + (bend - _cameraRefX) + lateral * pxPerMeterX,
      anchorY - (distance - field.player.distance) * pxPerMeterY,
    );
  }

  /// How far up the road (m) is still on screen.
  double get viewAheadMeters => anchorY / pxPerMeterY + 20;

  @override
  Color backgroundColor() => Cyber.bg;

  @override
  Future<void> onLoad() async {
    final rng = Random(setup.seed);
    field = buildField(setup, generateDriverNames(kFieldSize - 1, rng), rng);
    _engine = GrandPrixEngine(random: Random(setup.seed ^ 0x51f15eed));
    _cameraRefX =
        raceCenterlineX(
          field.circuit,
          field.sectionStarts,
          field.player.distance,
        ) *
        bendPxPerMeter;

    add(_TrackComponent()..priority = -10);
    for (final car in field.cars) {
      final sprite = _CarComponent(
        car: car,
        spec: grandPrixLiverySpec(car.livery),
      )..priority = car.isPlayer ? 20 : 10;
      _carSprites.add(sprite);
      add(sprite);
    }
    _syncSprites();
  }

  // -- inputs from the HUD control pad ---------------------------------------

  void setInputs({bool? left, bool? right, bool? throttle, bool? brake}) {
    _left = left ?? _left;
    _right = right ?? _right;
    _throttle = throttle ?? _throttle;
    _brake = brake ?? _brake;
  }

  RaceInputs get _playerInputs => RaceInputs(
    steer: (_right ? 1.0 : 0.0) - (_left ? 1.0 : 0.0),
    throttle: _throttle,
    brake: _brake,
  );

  // -- race lifecycle ---------------------------------------------------------

  /// Lights out: applies the graded launches and arms the simulation.
  void startRace(LaunchGrade playerGrade) {
    if (_running || _finishedReported) return;
    applyLaunch(field, playerGrade, Random(setup.seed ^ 0x1a));
    _running = true;
  }

  void stopRace() => _running = false;

  @override
  void update(double dt) {
    super.update(dt);
    if (_running) {
      // Clamp + fixed substeps so a dropped frame can't tunnel a braking zone.
      _accumulator += min(dt, 1 / 30);
      while (_accumulator >= _subDt && _running) {
        _accumulator -= _subDt;
        final events = _engine.tick(field, _playerInputs, _subDt);
        _handleEvents(events);
      }
    }
    _syncCamera();
    _syncSprites();
    _syncNotifiers();
  }

  void _handleEvents(RaceTickEvents events) {
    if (events.playerPosition case final position?) {
      onPositionChanged(position);
    }
    for (final overtake in events.overtakes) {
      final best = _bestOvertake;
      if (best == null || overtake.overtakenPosition < best.overtakenPosition) {
        _bestOvertake = overtake;
      }
      onOvertake(overtake);
    }
    if (events.playerTireScrub) {
      onAudioEvent(GrandPrixAudioEvent.tireScrub);
    }
    if (events.playerWallContact) {
      onAudioEvent(GrandPrixAudioEvent.wallContact);
    } else if (events.playerContact) {
      onAudioEvent(GrandPrixAudioEvent.carContact);
    }
    if ((events.playerWallContact || events.playerContact) && !reducedMotion) {
      _spawnSparks(
        events.playerWallContact ? Cyber.danger : Cyber.amber,
        events.playerWallContact ? 18 : 8,
      );
    }
    if (events.playerCrossedLine && !_finishedReported) {
      _finishedReported = true;
      _running = false;
      final player = field.player;
      onPlayerFinished(
        PlayerRaceOutcome(
          position: positionOf(field, player),
          lapTimeMs: player.finishTimeMs.round(),
          bestOvertakeName: _bestOvertake?.overtakenName,
        ),
      );
    }
    if (events.playerStuckOut && !_finishedReported) {
      // Game over: stuck too long. Classified last (DNF), no lap time.
      _finishedReported = true;
      _running = false;
      onPlayerFinished(
        const PlayerRaceOutcome(position: kFieldSize, lapTimeMs: 0, dnf: true),
      );
    }
  }

  void _syncCamera() {
    // Lock the camera exactly onto the centerline under the player so the
    // player car keeps a fixed horizontal screen position — offset only by its
    // own lateral, i.e. only when the player steers. Any lag/smoothing here
    // reads as the car sliding sideways on its own through a bend.
    _cameraRefX =
        raceCenterlineX(
          field.circuit,
          field.sectionStarts,
          field.player.distance,
        ) *
        bendPxPerMeter;
  }

  void _syncSprites() {
    if (!isLoaded) return;
    final playerDistance = field.player.distance;
    final window = viewAheadMeters;
    for (final sprite in _carSprites) {
      final delta = sprite.car.distance - playerDistance;
      sprite.visibleOnTrack = delta > -60 && delta < window;
      if (!sprite.visibleOnTrack) continue;
      final at = worldToScreen(sprite.car.distance, sprite.car.lateral);
      sprite.position = Vector2(at.dx, at.dy);
      // Slimmer + longer than the old 1.75 block — real F1 proportions.
      final carW = kCarWidth * pxPerMeterX * 0.68;
      sprite.size = Vector2(carW, carW * 2.05);
      sprite.angle = sprite.car.spinning
          ? sin(sprite.car.spinTimer * 24) * 0.7
          : (_steerLean(sprite.car));
    }
  }

  double _steerLean(CarState car) {
    if (!car.isPlayer) return 0;
    return ((_right ? 1 : 0) - (_left ? 1 : 0)) * 0.12;
  }

  void _syncNotifiers() {
    final player = field.player;
    speedKph.value = player.speed * 3.6;
    final lapLength = field.circuit.lapLength;
    if (player.finished) {
      currentLap.value = field.laps;
      lapProgress.value = 1.0;
    } else {
      final lapIndex = player.distance <= 0
          ? 0
          : min(field.laps - 1, player.distance ~/ lapLength);
      currentLap.value = lapIndex + 1;
      lapProgress.value = ((player.distance - lapIndex * lapLength) / lapLength)
          .clamp(0.0, 1.0);
    }
    slipstreamActive.value = player.slipstreaming;
    stuckSeconds.value = _running ? field.playerStuckSeconds : 0;
  }

  void _spawnSparks(Color color, int count) {
    if (!isLoaded) return;
    final player = field.player;
    final at = worldToScreen(player.distance, player.lateral);
    add(
      ParticleSystemComponent(
        position: Vector2(at.dx, at.dy),
        priority: 30,
        particle: Particle.generate(
          count: count,
          lifespan: 0.45,
          generator: (_) {
            final angle = _fxRng.nextDouble() * pi * 2;
            final speed = 60 + _fxRng.nextDouble() * 160;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              acceleration: Vector2(0, 260),
              child: CircleParticle(
                radius: 1.4 + _fxRng.nextDouble() * 1.8,
                paint: Paint()..color = color,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void onRemove() {
    speedKph.dispose();
    lapProgress.dispose();
    slipstreamActive.dispose();
    stuckSeconds.dispose();
    currentLap.dispose();
    super.onRemove();
  }
}

/// Draws the vertically-scrolling road: grass, walls, asphalt band, kerbs on
/// corner sections, braking boards, the centre dashes, and the start/finish
/// checker line. Everything is sampled around the player each frame from the
/// same world→screen mapping the cars use, so the road bends exactly where the
/// physics says the corner is.
class _TrackComponent extends PositionComponent
    with HasGameReference<GrandPrixGame> {
  static const double _sampleStep = 6;

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    if (!gameRef.isLoaded) return;
    final field = gameRef.field;
    final player = field.player;
    final from = player.distance - 60;
    final to = player.distance + gameRef.viewAheadMeters;

    final leftWall = <Offset>[];
    final rightWall = <Offset>[];
    final leftEdge = <Offset>[];
    final rightEdge = <Offset>[];
    for (var s = from; s <= to; s += _sampleStep) {
      leftWall.add(gameRef.worldToScreen(s, -kWallLateral));
      rightWall.add(gameRef.worldToScreen(s, kWallLateral));
      leftEdge.add(gameRef.worldToScreen(s, -kTrackHalfWidth));
      rightEdge.add(gameRef.worldToScreen(s, kTrackHalfWidth));
    }
    if (leftWall.length < 2) return;

    // Grass: the full corridor between the walls.
    canvas.drawPath(
      _band(leftWall, rightWall),
      Paint()..color = const Color(0xff07230f),
    );
    // Asphalt.
    canvas.drawPath(
      _band(leftEdge, rightEdge),
      Paint()..color = const Color(0xff11161f),
    );

    // Track edge lines.
    final edgePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Cyber.cyan.withValues(alpha: 0.18);
    canvas.drawPath(_polyline(leftEdge), edgePaint);
    canvas.drawPath(_polyline(rightEdge), edgePaint);

    // Walls.
    final wallPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Cyber.muted.withValues(alpha: 0.55);
    canvas.drawPath(_polyline(leftWall), wallPaint);
    canvas.drawPath(_polyline(rightWall), wallPaint);

    _renderCentreDashes(canvas, gameRef, from, to);
    _renderKerbsAndBoards(canvas, gameRef, from, to);
    _renderFinishLine(canvas, gameRef);
  }

  Path _band(List<Offset> left, List<Offset> right) {
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    for (final p in left.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in right.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  Path _polyline(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  /// Centre-line dashes every 12m — the main speed-feel cue.
  void _renderCentreDashes(
    Canvas canvas,
    GrandPrixGame gameRef,
    double from,
    double to,
  ) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Cyber.cyan.withValues(alpha: 0.10);
    final start = (from / 12).floor() * 12.0;
    for (var s = start; s <= to; s += 12) {
      final a = gameRef.worldToScreen(s, 0);
      final b = gameRef.worldToScreen(s + 5, 0);
      canvas.drawLine(a, b, paint);
    }
  }

  /// Kerb dashes along corner/chicane edges + amber braking boards 60m and
  /// 110m before each braking zone, repeated for every lap in view.
  void _renderKerbsAndBoards(
    Canvas canvas,
    GrandPrixGame gameRef,
    double from,
    double to,
  ) {
    final field = gameRef.field;
    final sections = field.circuit.sections;
    final lapLength = field.circuit.lapLength;
    final firstLap = max(0, (from / lapLength).floor());
    final lastLap = min(field.laps - 1, (to / lapLength).floor());
    for (var lap = firstLap; lap <= lastLap; lap++) {
      final lapBase = lap * lapLength;
      for (var i = 0; i < sections.length; i++) {
        final section = sections[i];
        if (section.isStraight) continue;
        final sectionStart = lapBase + field.sectionStarts[i];
        final sectionEnd = sectionStart + section.length;
        if (sectionEnd < from || sectionStart > to) continue;

        // Kerbs: alternating dashes on both edges through the section.
        var red = true;
        for (
          var s = max(sectionStart, from);
          s < min(sectionEnd, to);
          s += 5, red = !red
        ) {
          final paint = Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = (red ? Cyber.danger : const Color(0xffe8ecf2)).withValues(
              alpha: 0.55,
            );
          for (final side in const [-1.0, 1.0]) {
            final a = gameRef.worldToScreen(s, side * kTrackHalfWidth);
            final b = gameRef.worldToScreen(
              min(s + 3.4, sectionEnd),
              side * kTrackHalfWidth,
            );
            canvas.drawLine(a, b, paint);
          }
        }

        // Braking boards ahead of the zone.
        for (final lead in const [60.0, 110.0]) {
          final s = sectionStart - lead;
          if (s < from || s > to) continue;
          final paint = Paint()..color = Cyber.amber.withValues(alpha: 0.7);
          for (final side in const [-1.0, 1.0]) {
            final at = gameRef.worldToScreen(s, side * (kTrackHalfWidth + 1.0));
            canvas.drawRect(
              Rect.fromCenter(center: at, width: 10, height: 4),
              paint,
            );
          }
        }
      }
    }
  }

  /// Start line, a slim marker at every intermediate lap boundary, and the
  /// full checkered flag at the race's finish.
  void _renderFinishLine(Canvas canvas, GrandPrixGame gameRef) {
    final field = gameRef.field;
    final lapLength = field.circuit.lapLength;
    for (var lap = 0; lap <= field.laps; lap++) {
      final at = lap * lapLength;
      final delta = at - field.player.distance;
      if (delta < -30 || delta > gameRef.viewAheadMeters) continue;
      final isFinish = lap == field.laps;
      _checker(canvas, gameRef, at, rows: isFinish || lap == 0 ? 2 : 1);
    }
  }

  void _checker(
    Canvas canvas,
    GrandPrixGame gameRef,
    double at, {
    int rows = 2,
  }) {
    const cells = 8;
    final cellW = kTrackHalfWidth * 2 / cells;
    for (var row = 0; row < rows; row++) {
      for (var i = 0; i < cells; i++) {
        final even = (i + row).isEven;
        final a = gameRef.worldToScreen(
          at + row * 2.0,
          -kTrackHalfWidth + i * cellW,
        );
        final b = gameRef.worldToScreen(
          at + (row + 1) * 2.0,
          -kTrackHalfWidth + (i + 1) * cellW,
        );
        canvas.drawRect(
          Rect.fromPoints(a, b),
          Paint()
            ..color = even ? const Color(0xffe8ecf2) : const Color(0xff0a0e14),
        );
      }
    }
  }
}

/// A detailed top-down F1 car (see [paintGrandPrixCar]): multi-element wings,
/// halo + helmet, coke-bottle sidepods and a diffuser — tinted with the
/// livery. The player's car is the one glowing element on the track (THE GLOW
/// RULE).
class _CarComponent extends PositionComponent {
  _CarComponent({required this.car, required GrandPrixLiverySpec spec})
    : _glowColor = spec.accent,
      _style = GrandPrixCarStyle(spec) {
    anchor = Anchor.center;
  }

  final CarState car;
  final Color _glowColor;
  final GrandPrixCarStyle _style;
  bool visibleOnTrack = true;

  @override
  void render(Canvas canvas) {
    if (!visibleOnTrack) return;
    final w = size.x;
    final h = size.y;

    if (car.isPlayer) {
      canvas.drawOval(
        Rect.fromLTWH(-w * 0.25, -h * 0.15, w * 1.5, h * 1.3),
        Paint()
          ..color = _glowColor.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    paintGrandPrixCar(canvas, w, h, _style);

    if (car.spinning) {
      canvas.drawCircle(
        Offset(w * 0.5, h * 0.5),
        w * 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Cyber.danger.withValues(alpha: 0.6),
      );
    }
  }
}
```

### A.3 `lib/games/grand_prix/grand_prix_car_painter.dart`

<sub>183 lines</sub>

```dart
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../data/grand_prix_liveries.dart';

/// Shared top-down F1 car drawing for Grand Prix Dash.
///
/// One procedural car, drawn twice: by the Flame `_CarComponent` on track and
/// by [GrandPrixCarPreviewPainter] on the lobby's livery picker, so the car
/// you pick is exactly the car you race. Proportions follow a modern F1 car —
/// multi-element front wing with endplates, slim nose, halo over the cockpit,
/// coke-bottle sidepods, engine-cover spine, diffuser and a DRS rear wing —
/// kept bold enough to read at ~26px wide.
///
/// Like the liveries themselves, the carbon/tyre/rim greys here are CONTENT
/// colors (the documented exception to the no-raw-hex rule): they belong to
/// the car, not the UI chrome.
class GrandPrixCarStyle {
  GrandPrixCarStyle(this.spec)
    : body = Paint()..color = spec.primary,
      bodyEdge = Paint()
        ..style = PaintingStyle.stroke
        ..color = Color.lerp(spec.primary, const Color(0xFF000000), 0.45)!,
      accent = Paint()..color = spec.accent,
      accentDark = Paint()
        ..color = Color.lerp(spec.accent, const Color(0xFF000000), 0.30)!,
      carbon = Paint()..color = const Color(0xFF060910),
      tyre = Paint()..color = const Color(0xFF05070B),
      rim = Paint()..color = const Color(0xFF4A5462),
      halo = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF39424F),
      suspension = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A313C),
      shadow = Paint()..color = const Color(0xFF000000).withValues(alpha: 0.28),
      glint = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.45);

  final GrandPrixLiverySpec spec;
  final Paint body;
  final Paint bodyEdge;
  final Paint accent;
  final Paint accentDark;
  final Paint carbon;
  final Paint tyre;
  final Paint rim;
  final Paint halo;
  final Paint suspension;
  final Paint shadow;
  final Paint glint;
}

RRect _rr(double l, double t, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r));

/// Draws the car into a `w`×`h` box (nose up at y=0, rear wing at y=h).
/// Looks right around a 1:2 width:length box — [GrandPrixCarPreviewPainter]
/// letterboxes arbitrary canvases to that aspect.
void paintGrandPrixCar(Canvas canvas, double w, double h, GrandPrixCarStyle s) {
  final r = w * 0.05;
  final thin = max(1.0, w * 0.030);

  // Ground shadow.
  canvas.drawOval(Rect.fromLTWH(w * 0.01, h * 0.02, w * 0.98, h * 0.96), s.shadow);

  // Front wing (under the nose): endplates, upper flap, main plane.
  canvas.drawRRect(_rr(w * 0.005, h * 0.005, w * 0.060, h * 0.115, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.935, h * 0.005, w * 0.060, h * 0.115, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.09, h * 0.018, w * 0.82, h * 0.032, r), s.accentDark);
  canvas.drawRRect(_rr(w * 0.05, h * 0.055, w * 0.90, h * 0.048, r), s.accent);

  // Suspension wishbones (under the tyres).
  final susp = s.suspension..strokeWidth = thin;
  canvas.drawLine(Offset(w * 0.42, h * 0.200), Offset(w * 0.10, h * 0.185), susp);
  canvas.drawLine(Offset(w * 0.42, h * 0.245), Offset(w * 0.10, h * 0.240), susp);
  canvas.drawLine(Offset(w * 0.58, h * 0.200), Offset(w * 0.90, h * 0.185), susp);
  canvas.drawLine(Offset(w * 0.58, h * 0.245), Offset(w * 0.90, h * 0.240), susp);
  canvas.drawLine(Offset(w * 0.38, h * 0.725), Offset(w * 0.10, h * 0.715), susp);
  canvas.drawLine(Offset(w * 0.38, h * 0.785), Offset(w * 0.10, h * 0.780), susp);
  canvas.drawLine(Offset(w * 0.62, h * 0.725), Offset(w * 0.90, h * 0.715), susp);
  canvas.drawLine(Offset(w * 0.62, h * 0.785), Offset(w * 0.90, h * 0.780), susp);

  // Tyres — rears run wider, with a grey rim slot in each.
  void tyreAt(double l, double t, double tw, double th) {
    canvas.drawRRect(_rr(l, t, tw, th, w * 0.055), s.tyre);
    canvas.drawRRect(
      _rr(l + tw * 0.32, t + th * 0.24, tw * 0.36, th * 0.52, w * 0.03),
      s.rim,
    );
  }

  tyreAt(-w * 0.005, h * 0.145, w * 0.195, h * 0.135);
  tyreAt(w * 0.810, h * 0.145, w * 0.195, h * 0.135);
  tyreAt(-w * 0.015, h * 0.685, w * 0.215, h * 0.155);
  tyreAt(w * 0.800, h * 0.685, w * 0.215, h * 0.155);

  // Body: slim nose → chassis → sidepod flare → coke-bottle taper → rear.
  final body = Path()
    ..moveTo(w * 0.50, h * 0.010)
    ..quadraticBezierTo(w * 0.575, h * 0.045, w * 0.585, h * 0.16)
    ..lineTo(w * 0.615, h * 0.33)
    ..quadraticBezierTo(w * 0.830, h * 0.375, w * 0.835, h * 0.47)
    ..quadraticBezierTo(w * 0.815, h * 0.600, w * 0.660, h * 0.685)
    ..lineTo(w * 0.635, h * 0.86)
    ..lineTo(w * 0.365, h * 0.86)
    ..lineTo(w * 0.340, h * 0.685)
    ..quadraticBezierTo(w * 0.185, h * 0.600, w * 0.165, h * 0.47)
    ..quadraticBezierTo(w * 0.170, h * 0.375, w * 0.385, h * 0.33)
    ..lineTo(w * 0.415, h * 0.16)
    ..quadraticBezierTo(w * 0.425, h * 0.045, w * 0.50, h * 0.010)
    ..close();
  canvas.drawPath(body, s.body);
  canvas.drawPath(body, s.bodyEdge..strokeWidth = max(1.0, w * 0.022));

  // Sidepod radiator intakes.
  canvas.drawRRect(_rr(w * 0.205, h * 0.445, w * 0.115, h * 0.045, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.680, h * 0.445, w * 0.115, h * 0.045, r), s.carbon);

  // Accent nose stripe + engine-cover spine.
  canvas.drawRRect(_rr(w * 0.474, h * 0.045, w * 0.052, h * 0.135, r), s.accent);
  canvas.drawRRect(_rr(w * 0.468, h * 0.565, w * 0.064, h * 0.270, r), s.accent);

  // Wing mirrors.
  canvas.drawRRect(_rr(w * 0.335, h * 0.372, w * 0.048, h * 0.020, r), s.accent);
  canvas.drawRRect(_rr(w * 0.617, h * 0.372, w * 0.048, h * 0.020, r), s.accent);

  // Cockpit, halo and the driver's helmet.
  canvas.drawRRect(_rr(w * 0.415, h * 0.360, w * 0.170, h * 0.185, w * 0.07), s.carbon);
  final haloPaint = s.halo..strokeWidth = max(1.0, w * 0.028);
  canvas.drawOval(Rect.fromLTWH(w * 0.400, h * 0.350, w * 0.200, h * 0.205), haloPaint);
  canvas.drawLine(Offset(w * 0.50, h * 0.350), Offset(w * 0.50, h * 0.440), haloPaint);
  canvas.drawCircle(Offset(w * 0.50, h * 0.475), w * 0.062, s.accent);
  canvas.drawCircle(Offset(w * 0.478, h * 0.462), w * 0.020, s.glint);

  // Diffuser with vertical strakes.
  canvas.drawRRect(_rr(w * 0.28, h * 0.860, w * 0.44, h * 0.080, r), s.carbon);
  for (final x in [0.39, 0.50, 0.61]) {
    canvas.drawLine(
      Offset(w * x, h * 0.872),
      Offset(w * x, h * 0.928),
      s.rim..strokeWidth = max(1.0, w * 0.018),
    );
  }

  // Rear wing (topmost at the rear): endplates, main plane + DRS slot, flap.
  canvas.drawRRect(_rr(w * 0.060, h * 0.845, w * 0.055, h * 0.135, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.885, h * 0.845, w * 0.055, h * 0.135, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.130, h * 0.845, w * 0.740, h * 0.028, r), s.accentDark);
  canvas.drawRRect(_rr(w * 0.100, h * 0.875, w * 0.800, h * 0.062, r), s.accent);
  canvas.drawLine(
    Offset(w * 0.12, h * 0.905),
    Offset(w * 0.88, h * 0.905),
    s.carbon..strokeWidth = max(1.0, w * 0.016),
  );
}

/// Letterboxed [paintGrandPrixCar] for regular widget trees (lobby livery
/// picker) — centres the car at its native 1:2 aspect inside any canvas.
class GrandPrixCarPreviewPainter extends CustomPainter {
  GrandPrixCarPreviewPainter(this.spec) : _style = GrandPrixCarStyle(spec);

  final GrandPrixLiverySpec spec;
  final GrandPrixCarStyle _style;

  /// Car width as a fraction of its length.
  static const double aspect = 0.52;

  @override
  void paint(Canvas canvas, Size size) {
    final carW = min(size.width, size.height * aspect);
    final carH = carW / aspect;
    canvas.save();
    canvas.translate((size.width - carW) / 2, (size.height - carH) / 2);
    paintGrandPrixCar(canvas, carW, carH, _style);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GrandPrixCarPreviewPainter oldDelegate) =>
      oldDelegate.spec != spec;
}
```

### A.4 `lib/models/grand_prix.dart`

<sub>340 lines</sub>

```dart
/// Domain model for Grand Prix Dash — the one-lap top-down F1 arcade racer.
///
/// Pure data: enums, track geometry, race result, and the persisted lifetime
/// record. No Flutter/Flame imports so the race engine and tests stay pure.
library;

enum GrandPrixCircuitId {
  harbourStreet,
  desertMile,
  emeraldPark,
  mountainPass,
  coastalSprint,
}

enum GrandPrixLivery {
  gridLine,
  scarlet,
  silverArrow,
  papaya,
  midnight,
  racingGreen,
  skyBlue,
}

enum TrackSectionType { straight, corner, chicane }

enum CornerDirection { left, right }

enum LaunchGrade { perfect, great, good, slow, jump }

enum GrandPrixVerdict { win, podium, points, finished }

GrandPrixVerdict grandPrixVerdict(int position) => switch (position) {
  1 => GrandPrixVerdict.win,
  <= 3 => GrandPrixVerdict.podium,
  <= 10 => GrandPrixVerdict.points,
  _ => GrandPrixVerdict.finished,
};

GrandPrixCircuitId grandPrixCircuitFromName(String? name) =>
    GrandPrixCircuitId.values.firstWhere(
      (id) => id.name == name,
      orElse: () => GrandPrixCircuitId.emeraldPark,
    );

GrandPrixLivery grandPrixLiveryFromName(String? name) =>
    GrandPrixLivery.values.firstWhere(
      (livery) => livery.name == name,
      orElse: () => GrandPrixLivery.gridLine,
    );

/// One stretch of track. The simulation is 1D (distance along the lap plus a
/// lateral offset), so a corner only affects physics through [safeSpeed] and
/// pixels through [bend] — the sideways shift of the drawn centerline.
class TrackSection {
  const TrackSection._({
    required this.type,
    required this.length,
    this.direction,
    this.safeSpeed,
    this.wallThreshold = 14,
    this.bend = 0,
  });

  const TrackSection.straight(double length)
    : this._(type: TrackSectionType.straight, length: length);

  const TrackSection.corner({
    required double length,
    required CornerDirection direction,
    required double safeSpeed,
    double wallThreshold = 14,
    double bend = 24,
  }) : this._(
         type: TrackSectionType.corner,
         length: length,
         direction: direction,
         safeSpeed: safeSpeed,
         wallThreshold: wallThreshold,
         bend: bend,
       );

  const TrackSection.chicane({
    required double length,
    required CornerDirection direction,
    required double safeSpeed,
    double wallThreshold = 12,
    double bend = 14,
  }) : this._(
         type: TrackSectionType.chicane,
         length: length,
         direction: direction,
         safeSpeed: safeSpeed,
         wallThreshold: wallThreshold,
         bend: bend,
       );

  final TrackSectionType type;

  /// Section length in metres.
  final double length;

  /// Entry flick direction; null for straights.
  final CornerDirection? direction;

  /// Max clean entry speed (m/s); null for straights.
  final double? safeSpeed;

  /// Overspeed (m/s above [safeSpeed]) beyond which entry means wall contact.
  final double wallThreshold;

  /// Magnitude of the centerline's sideways shift through the section (m).
  /// Rendering only — see `centerlineX` in the engine.
  final double bend;

  bool get isStraight => type == TrackSectionType.straight;

  /// Signed bend: negative = left, positive = right (matches lateral axis).
  double get signedBend =>
      direction == CornerDirection.left ? -bend : bend;
}

class GrandPrixCircuit {
  const GrandPrixCircuit({
    required this.id,
    required this.name,
    required this.character,
    required this.flavor,
    required this.difficultyStars,
    required this.sections,
  });

  final GrandPrixCircuitId id;
  final String name;

  /// Short type tag, e.g. 'STREET', 'SPEEDWAY'.
  final String character;

  /// One-line lobby description.
  final String flavor;
  final int difficultyStars;
  final List<TrackSection> sections;

  double get lapLength =>
      sections.fold(0, (sum, section) => sum + section.length);
}

/// A single overtake, kept for the result screen's "MVP move" beat.
class OvertakeEvent {
  const OvertakeEvent({
    required this.overtakenName,
    required this.overtakenPosition,
    required this.atDistance,
  });

  final String overtakenName;

  /// Position the player took by the pass (lower = better move).
  final int overtakenPosition;
  final double atDistance;
}

class GrandPrixResult {
  const GrandPrixResult({
    required this.position,
    required this.fieldSize,
    required this.startPosition,
    required this.lapTimeMs,
    required this.personalBest,
    required this.launchGrade,
    required this.circuit,
    required this.xp,
    this.laps = 1,
    this.bestOvertakeName,
    this.retired = false,
  });

  final int position;
  final int fieldSize;
  final int startPosition;

  /// Total race time over all laps (single-lap races: the lap time).
  final int lapTimeMs;
  final bool personalBest;
  final LaunchGrade launchGrade;
  final GrandPrixCircuitId circuit;
  final int xp;

  /// Race distance the result was set over.
  final int laps;
  final String? bestOvertakeName;

  /// The player got stuck and timed out — a DNF, shown as GAME OVER.
  final bool retired;

  GrandPrixVerdict get verdict => grandPrixVerdict(position);
  int get placesGained => startPosition - position;
}

/// Formats a lap time in ms as `m:ss.mmm` (or `--:--.---` when unset).
String formatLapTime(int? lapTimeMs) {
  if (lapTimeMs == null || lapTimeMs <= 0) return '--:--.---';
  final minutes = lapTimeMs ~/ 60000;
  final seconds = (lapTimeMs % 60000) ~/ 1000;
  final millis = lapTimeMs % 1000;
  return '$minutes:${seconds.toString().padLeft(2, '0')}.'
      '${millis.toString().padLeft(3, '0')}';
}

/// Persisted lifetime racing record (on-device only — mirrors
/// [FootballChessStats]). Also remembers the last-used circuit/livery so a
/// returning racer can hit START RACE immediately.
class GrandPrixStats {
  const GrandPrixStats({
    this.races = 0,
    this.wins = 0,
    this.podiums = 0,
    this.bestPosition = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.bestLapMsByCircuit = const {},
    this.lastCircuit = GrandPrixCircuitId.emeraldPark,
    this.lastLivery = GrandPrixLivery.gridLine,
    this.lastLaps = 1,
  });

  factory GrandPrixStats.fromJson(Map<String, dynamic> json) {
    final rawLaps = json['bestLapMsByCircuit'];
    final laps = <String, int>{};
    if (rawLaps is Map) {
      for (final entry in rawLaps.entries) {
        final value = entry.value;
        if (value is int && value > 0) laps['${entry.key}'] = value;
      }
    }
    final lastLaps = json['lastLaps'] as int? ?? 1;
    return GrandPrixStats(
      races: json['races'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      podiums: json['podiums'] as int? ?? 0,
      bestPosition: json['bestPosition'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      bestLapMsByCircuit: laps,
      lastCircuit: grandPrixCircuitFromName(json['lastCircuit'] as String?),
      lastLivery: grandPrixLiveryFromName(json['lastLivery'] as String?),
      lastLaps: lastLaps >= 1 && lastLaps <= 9 ? lastLaps : 1,
    );
  }

  final int races;
  final int wins;
  final int podiums;

  /// Best finishing position ever; 0 means no race finished yet.
  final int bestPosition;
  final int currentStreak;
  final int bestStreak;

  /// Personal-best race time per circuit+distance. Single-lap bests are keyed
  /// by [GrandPrixCircuitId.name] (the legacy key); multi-lap bests append the
  /// lap count (`emeraldPark@3L`) so distances never race each other.
  final Map<String, int> bestLapMsByCircuit;
  final GrandPrixCircuitId lastCircuit;
  final GrandPrixLivery lastLivery;

  /// Last-used race distance in laps (persisted like circuit/livery).
  final int lastLaps;

  static String _bestKey(GrandPrixCircuitId circuit, int laps) =>
      laps <= 1 ? circuit.name : '${circuit.name}@${laps}L';

  int? bestLapMs(GrandPrixCircuitId circuit, {int laps = 1}) =>
      bestLapMsByCircuit[_bestKey(circuit, laps)];

  /// True when [lapTimeMs] beats (or sets) the stored best for this
  /// circuit+distance.
  bool isPersonalBest(GrandPrixCircuitId circuit, int lapTimeMs, {int laps = 1}) {
    final best = bestLapMs(circuit, laps: laps);
    return best == null || lapTimeMs < best;
  }

  GrandPrixStats copyWith({
    GrandPrixCircuitId? lastCircuit,
    GrandPrixLivery? lastLivery,
    int? lastLaps,
  }) => GrandPrixStats(
    races: races,
    wins: wins,
    podiums: podiums,
    bestPosition: bestPosition,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    bestLapMsByCircuit: bestLapMsByCircuit,
    lastCircuit: lastCircuit ?? this.lastCircuit,
    lastLivery: lastLivery ?? this.lastLivery,
    lastLaps: lastLaps ?? this.lastLaps,
  );

  GrandPrixStats recordResult({
    required int position,
    required int lapTimeMs,
    required GrandPrixCircuitId circuit,
    int laps = 1,
  }) {
    final won = position == 1;
    final nextStreak = won ? currentStreak + 1 : 0;
    final bests = Map<String, int>.from(bestLapMsByCircuit);
    if (lapTimeMs > 0 && isPersonalBest(circuit, lapTimeMs, laps: laps)) {
      bests[_bestKey(circuit, laps)] = lapTimeMs;
    }
    return GrandPrixStats(
      races: races + 1,
      wins: won ? wins + 1 : wins,
      podiums: position <= 3 ? podiums + 1 : podiums,
      bestPosition: bestPosition == 0 || position < bestPosition
          ? position
          : bestPosition,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
      bestLapMsByCircuit: bests,
      lastCircuit: circuit,
      lastLivery: lastLivery,
      lastLaps: laps,
    );
  }

  Map<String, dynamic> toJson() => {
    'races': races,
    'wins': wins,
    'podiums': podiums,
    'bestPosition': bestPosition,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'bestLapMsByCircuit': bestLapMsByCircuit,
    'lastCircuit': lastCircuit.name,
    'lastLivery': lastLivery.name,
    'lastLaps': lastLaps,
  };
}
```

### A.5 `lib/data/grand_prix_circuits.dart`

<sub>297 lines</sub>

```dart
import '../models/grand_prix.dart';

/// Seeded circuit catalog for Grand Prix Dash.
///
/// Names are generic archetypes (no real-circuit trademarks). Lengths are in
/// metres, speeds in m/s — the engine's top speed is ~88 m/s, so safe speeds
/// of ~24 (hairpin) to ~64 (fast sweeper) set how brutal each braking zone is.
/// Street-circuit sections carry a low `wallThreshold` so overcooking a corner
/// there means wall contact, not just running wide.
const List<GrandPrixCircuit> grandPrixCircuits = [
  GrandPrixCircuit(
    id: GrandPrixCircuitId.harbourStreet,
    name: 'HARBOUR STREET',
    character: 'STREET',
    flavor: 'Slow corners, punishing walls. Hard to pass.',
    difficultyStars: 4,
    sections: [
      TrackSection.straight(400),
      TrackSection.corner(
        length: 75,
        direction: CornerDirection.left,
        safeSpeed: 26,
        wallThreshold: 8,
        bend: 21,
      ),
      TrackSection.straight(180),
      TrackSection.corner(
        length: 69,
        direction: CornerDirection.right,
        safeSpeed: 24,
        wallThreshold: 8,
        bend: 18,
      ),
      TrackSection.straight(240),
      TrackSection.chicane(
        length: 113,
        direction: CornerDirection.left,
        safeSpeed: 24,
        wallThreshold: 8,
        bend: 18,
      ),
      TrackSection.straight(160),
      TrackSection.corner(
        length: 81,
        direction: CornerDirection.right,
        safeSpeed: 28,
        wallThreshold: 8,
        bend: 21,
      ),
      TrackSection.corner(
        length: 75,
        direction: CornerDirection.left,
        safeSpeed: 25,
        wallThreshold: 8,
        bend: 18,
      ),
      TrackSection.straight(320),
      TrackSection.corner(
        length: 88,
        direction: CornerDirection.right,
        safeSpeed: 30,
        wallThreshold: 8,
        bend: 23,
      ),
      TrackSection.straight(150),
      TrackSection.corner(
        length: 69,
        direction: CornerDirection.left,
        safeSpeed: 23,
        wallThreshold: 8,
        bend: 18,
      ),
      TrackSection.straight(200),
      TrackSection.corner(
        length: 75,
        direction: CornerDirection.right,
        safeSpeed: 26,
        wallThreshold: 8,
        bend: 20,
      ),
      TrackSection.straight(340),
    ],
  ),
  GrandPrixCircuit(
    id: GrandPrixCircuitId.desertMile,
    name: 'DESERT MILE',
    character: 'SPEEDWAY',
    flavor: 'Endless straights, heavy slipstream. Overtaking festival.',
    difficultyStars: 2,
    sections: [
      TrackSection.straight(900),
      TrackSection.corner(
        length: 175,
        direction: CornerDirection.right,
        safeSpeed: 60,
        bend: 44,
      ),
      TrackSection.straight(780),
      TrackSection.corner(
        length: 150,
        direction: CornerDirection.right,
        safeSpeed: 55,
        bend: 39,
      ),
      TrackSection.straight(950),
      TrackSection.chicane(
        length: 163,
        direction: CornerDirection.right,
        safeSpeed: 34,
        bend: 18,
      ),
      TrackSection.straight(700),
      TrackSection.corner(
        length: 188,
        direction: CornerDirection.right,
        safeSpeed: 58,
        bend: 44,
      ),
      TrackSection.straight(730),
    ],
  ),
  GrandPrixCircuit(
    id: GrandPrixCircuitId.emeraldPark,
    name: 'EMERALD PARK',
    character: 'BALANCED',
    flavor: 'An even mix of straights and corners. The classic.',
    difficultyStars: 3,
    sections: [
      TrackSection.straight(420),
      TrackSection.corner(
        length: 113,
        direction: CornerDirection.right,
        safeSpeed: 45,
        bend: 34,
      ),
      TrackSection.straight(300),
      TrackSection.corner(
        length: 100,
        direction: CornerDirection.left,
        safeSpeed: 38,
        bend: 29,
      ),
      TrackSection.straight(520),
      TrackSection.corner(
        length: 138,
        direction: CornerDirection.right,
        safeSpeed: 52,
        bend: 39,
      ),
      TrackSection.corner(
        length: 113,
        direction: CornerDirection.left,
        safeSpeed: 40,
        bend: 31,
      ),
      TrackSection.straight(260),
      TrackSection.chicane(
        length: 150,
        direction: CornerDirection.left,
        safeSpeed: 30,
        bend: 18,
      ),
      TrackSection.straight(340),
      TrackSection.corner(
        length: 125,
        direction: CornerDirection.right,
        safeSpeed: 45,
        bend: 34,
      ),
      TrackSection.straight(300),
      TrackSection.corner(
        length: 88,
        direction: CornerDirection.left,
        safeSpeed: 33,
        bend: 23,
      ),
      TrackSection.straight(380),
    ],
  ),
  GrandPrixCircuit(
    id: GrandPrixCircuitId.mountainPass,
    name: 'MOUNTAIN PASS',
    character: 'TECHNICAL',
    flavor: 'Chicanes and quick flicks. Rewards braking control.',
    difficultyStars: 4,
    sections: [
      TrackSection.straight(460),
      TrackSection.chicane(
        length: 138,
        direction: CornerDirection.right,
        safeSpeed: 32,
        bend: 18,
      ),
      TrackSection.straight(220),
      TrackSection.corner(
        length: 94,
        direction: CornerDirection.left,
        safeSpeed: 34,
        bend: 26,
      ),
      TrackSection.corner(
        length: 88,
        direction: CornerDirection.right,
        safeSpeed: 31,
        bend: 23,
      ),
      TrackSection.straight(300),
      TrackSection.chicane(
        length: 150,
        direction: CornerDirection.left,
        safeSpeed: 29,
        bend: 18,
      ),
      TrackSection.straight(260),
      TrackSection.corner(
        length: 106,
        direction: CornerDirection.right,
        safeSpeed: 38,
        bend: 29,
      ),
      TrackSection.chicane(
        length: 138,
        direction: CornerDirection.right,
        safeSpeed: 31,
        bend: 18,
      ),
      TrackSection.straight(280),
      TrackSection.corner(
        length: 113,
        direction: CornerDirection.left,
        safeSpeed: 36,
        bend: 29,
      ),
      TrackSection.corner(
        length: 75,
        direction: CornerDirection.right,
        safeSpeed: 28,
        bend: 21,
      ),
      TrackSection.straight(500),
    ],
  ),
  GrandPrixCircuit(
    id: GrandPrixCircuitId.coastalSprint,
    name: 'COASTAL SPRINT',
    character: 'FLOWING',
    flavor: 'Fast sweepers, one big stop. Carry the speed.',
    difficultyStars: 3,
    sections: [
      TrackSection.straight(450),
      TrackSection.corner(
        length: 175,
        direction: CornerDirection.right,
        safeSpeed: 62,
        bend: 39,
      ),
      TrackSection.straight(280),
      TrackSection.corner(
        length: 188,
        direction: CornerDirection.left,
        safeSpeed: 58,
        bend: 39,
      ),
      TrackSection.straight(360),
      TrackSection.corner(
        length: 200,
        direction: CornerDirection.right,
        safeSpeed: 64,
        bend: 44,
      ),
      TrackSection.corner(
        length: 150,
        direction: CornerDirection.left,
        safeSpeed: 55,
        bend: 34,
      ),
      TrackSection.straight(420),
      TrackSection.corner(
        length: 113,
        direction: CornerDirection.right,
        safeSpeed: 42,
        bend: 29,
      ),
      TrackSection.straight(300),
      TrackSection.corner(
        length: 188,
        direction: CornerDirection.left,
        safeSpeed: 60,
        bend: 39,
      ),
      TrackSection.straight(380),
    ],
  ),
];

GrandPrixCircuit grandPrixCircuit(GrandPrixCircuitId id) =>
    grandPrixCircuits.firstWhere((circuit) => circuit.id == id);
```

### A.6 `lib/data/grand_prix_drivers.dart`

<sub>62 lines</sub>

```dart
import 'dart:math';

/// Racing-flavored CPU driver name pool for Grand Prix Dash — same pattern as
/// `random_opponent_names.dart`, but with paddock-sounding names. Combinations
/// are invented (no real driver pairings).
const List<String> _grandPrixFirstNames = [
  'Luca',
  'Mika',
  'Jules',
  'Rio',
  'Kazuki',
  'Nico',
  'Theo',
  'Enzo',
  'Otto',
  'Dario',
  'Ivan',
  'Marco',
  'Alexi',
  'Bruno',
  'Felix',
  'Hugo',
  'Levi',
  'Mateo',
  'Ayaan',
  'Callum',
];

const List<String> _grandPrixLastNames = [
  'Vermeer',
  'Castellano',
  'Lindqvist',
  'Okada',
  'Ferrand',
  'Novak',
  'Almeida',
  'Baumann',
  'Kowalski',
  'Marchetti',
  'Sorensen',
  'Duval',
  'Ishida',
  'Petrakis',
  'Weller',
  'Zubarev',
  'Nakamura',
  'Herrero',
  'Vance',
  'Adeyemi',
];

final List<String> grandPrixDriverNames = List.unmodifiable([
  for (final firstName in _grandPrixFirstNames)
    for (final lastName in _grandPrixLastNames) '$firstName $lastName',
]);

/// Draws [count] unique driver names from the pool using [random].
List<String> generateDriverNames(int count, Random random) {
  assert(count <= grandPrixDriverNames.length);
  final pool = [...grandPrixDriverNames]..shuffle(random);
  return pool.take(count).toList();
}
```

### A.7 `lib/data/grand_prix_liveries.dart`

<sub>102 lines</sub>

```dart
import 'dart:ui';

import '../models/grand_prix.dart';

/// Constructor-color livery palette for Grand Prix Dash.
///
/// These are CONTENT colors (like card-rarity and team colors), not UI chrome
/// — the one documented exception to the "no hardcoded colors" rule. All UI
/// around them still uses `AppTheme`/`Cyber` tokens. Names are generic
/// archetypes to avoid constructor trademarks.
class GrandPrixLiverySpec {
  const GrandPrixLiverySpec({
    required this.livery,
    required this.name,
    required this.primary,
    required this.accent,
  });

  final GrandPrixLivery livery;
  final String name;
  final Color primary;
  final Color accent;
}

const List<GrandPrixLiverySpec> grandPrixLiveries = [
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.gridLine,
    name: 'GRID LINE',
    primary: Color(0xFF0A0E14),
    accent: Color(0xFF35E7FF),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.scarlet,
    name: 'SCARLET',
    primary: Color(0xFFD8232A),
    accent: Color(0xFFFFE24A),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.silverArrow,
    name: 'SILVER ARROW',
    primary: Color(0xFFB9BFC6),
    accent: Color(0xFF00D2BE),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.papaya,
    name: 'PAPAYA',
    primary: Color(0xFFFF8000),
    accent: Color(0xFF2A9DF4),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.midnight,
    name: 'MIDNIGHT',
    primary: Color(0xFF16265C),
    accent: Color(0xFF35E7FF),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.racingGreen,
    name: 'RACING GREEN',
    primary: Color(0xFF0B5B3C),
    accent: Color(0xFFD4AF37),
  ),
  GrandPrixLiverySpec(
    livery: GrandPrixLivery.skyBlue,
    name: 'SKY BLUE',
    primary: Color(0xFF6FC5F0),
    accent: Color(0xFFF4F7FA),
  ),
];

/// The one livery every player starts with — no coin cost.
const grandPrixFreeLivery = GrandPrixLivery.gridLine;

/// Coin price for every non-free livery in the Shop.
const grandPrixLiveryCoinPrice = 100;

GrandPrixLiverySpec grandPrixLiverySpec(GrandPrixLivery livery) =>
    grandPrixLiveries.firstWhere((spec) => spec.livery == livery);

bool isGrandPrixLiveryFree(GrandPrixLivery livery) =>
    livery == grandPrixFreeLivery;

int grandPrixLiveryPrice(GrandPrixLivery livery) =>
    isGrandPrixLiveryFree(livery) ? 0 : grandPrixLiveryCoinPrice;

List<String> defaultOwnedGrandPrixLiveryIds() => [grandPrixFreeLivery.name];

List<String> normalizeOwnedGrandPrixLiveryIds(Iterable<String> ids) {
  final owned = ids.toSet()..add(grandPrixFreeLivery.name);
  return owned.toList();
}

bool isGrandPrixLiveryOwned(String liveryId, Iterable<String> ownedLiveryIds) =>
    isGrandPrixLiveryFree(grandPrixLiveryFromName(liveryId)) ||
    ownedLiveryIds.contains(liveryId);

GrandPrixLivery ensureEquippedLiveryOwned(
  Iterable<String> ownedLiveryIds,
  GrandPrixLivery equipped,
) {
  if (isGrandPrixLiveryOwned(equipped.name, ownedLiveryIds)) return equipped;
  return grandPrixFreeLivery;
}
```

### A.8 `lib/blocs/grand_prix/grand_prix_state.dart`

<sub>85 lines</sub>

```dart
import '../../games/grand_prix/grand_prix_engine.dart';
import '../../models/grand_prix.dart';

const Object _sentinel = Object();

/// Race lifecycle. The 60fps simulation itself lives in the Flame game — this
/// phase machine only tracks the coarse beats around it.
enum GrandPrixPhase { idle, grid, lights, racing, finished, result }

class GrandPrixState {
  const GrandPrixState({
    this.loading = true,
    this.stats = const GrandPrixStats(),
    this.phase = GrandPrixPhase.idle,
    this.lightsOn = 0,
    this.lightsOut = false,
    this.launchGrade,
    this.playerPosition = 0,
    this.lastOvertake,
    this.eventTick = 0,
    this.setup,
    this.result,
  });

  final bool loading;
  final GrandPrixStats stats;
  final GrandPrixPhase phase;

  /// Lit start lamps, 0..5 (drops back to 0 the moment they go out).
  final int lightsOn;

  /// True once the lamps have gone dark — the launch window is open.
  final bool lightsOut;
  final LaunchGrade? launchGrade;

  /// Live position from the game's coarse callback (changes rarely).
  final int playerPosition;

  /// Last player overtake + a monotonic tick for toast listeners.
  final OvertakeEvent? lastOvertake;
  final int eventTick;

  final RaceSetup? setup;
  final GrandPrixResult? result;

  // Selection is persisted on stats so it survives restarts.
  GrandPrixCircuitId get circuitId => stats.lastCircuit;
  GrandPrixLivery get livery => stats.lastLivery;
  int get laps => stats.lastLaps;
  bool get jumpStart => launchGrade == LaunchGrade.jump;
  bool get raceLive =>
      phase == GrandPrixPhase.racing || phase == GrandPrixPhase.lights;

  GrandPrixState copyWith({
    bool? loading,
    GrandPrixStats? stats,
    GrandPrixPhase? phase,
    int? lightsOn,
    bool? lightsOut,
    Object? launchGrade = _sentinel,
    int? playerPosition,
    Object? lastOvertake = _sentinel,
    int? eventTick,
    Object? setup = _sentinel,
    Object? result = _sentinel,
  }) => GrandPrixState(
    loading: loading ?? this.loading,
    stats: stats ?? this.stats,
    phase: phase ?? this.phase,
    lightsOn: lightsOn ?? this.lightsOn,
    lightsOut: lightsOut ?? this.lightsOut,
    launchGrade: identical(launchGrade, _sentinel)
        ? this.launchGrade
        : launchGrade as LaunchGrade?,
    playerPosition: playerPosition ?? this.playerPosition,
    lastOvertake: identical(lastOvertake, _sentinel)
        ? this.lastOvertake
        : lastOvertake as OvertakeEvent?,
    eventTick: eventTick ?? this.eventTick,
    setup: identical(setup, _sentinel) ? this.setup : setup as RaceSetup?,
    result: identical(result, _sentinel)
        ? this.result
        : result as GrandPrixResult?,
  );
}
```

### A.9 `lib/blocs/grand_prix/grand_prix_cubit.dart`

<sub>280 lines</sub>

```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/grand_prix_circuits.dart';
import '../../data/grand_prix_liveries.dart' as gp_liveries;
import '../../games/grand_prix/grand_prix_engine.dart';
import '../../models/grand_prix.dart';
import '../../models/progression.dart';
import '../../services/secure_storage_service.dart';
import 'grand_prix_state.dart';

/// Drives a Grand Prix Dash session: lobby selections, the five-lights start
/// sequence (with jump-start detection and launch grading), the coarse race
/// beats reported up by the Flame game, and settlement + stats persistence.
///
/// The 60fps simulation never touches this cubit — the Flame game owns the
/// [RaceField] and only calls back on position changes, overtakes, and the
/// finish. Rewards are dispatched by the race screen (GameBloc lives in the
/// widget tree), mirroring the Football Chess pattern.
class GrandPrixCubit extends Cubit<GrandPrixState> {
  GrandPrixCubit(this._storage, {Random? random})
    : _random = random ?? Random(),
      super(const GrandPrixState());

  final SecureGameStorage _storage;
  final Random _random;
  final List<Timer> _lightTimers = [];
  DateTime? _lightsOutAt;

  static const _lightIntervalMs = 1000;
  static const _minHoldMs = 200;
  static const _maxHoldMs = 1500;

  /// No launch tap this long after lights-out auto-grades a Slow start.
  static const _launchTimeout = Duration(seconds: 2);

  Future<void> load() async {
    final stats = await _storage.loadGrandPrixStats();
    emit(state.copyWith(loading: false, stats: stats));
  }

  /// Clamps an equipped livery the player no longer owns back to the free
  /// default.
  void ensureEquippedLiveryOwned(Iterable<String> ownedLiveryIds) {
    final clamped = gp_liveries.ensureEquippedLiveryOwned(
      ownedLiveryIds,
      state.stats.lastLivery,
    );
    if (clamped == state.stats.lastLivery) return;
    _persistStats(state.stats.copyWith(lastLivery: clamped));
  }

  // -- lobby ----------------------------------------------------------------

  void selectCircuit(GrandPrixCircuitId id) {
    if (id == state.stats.lastCircuit) return;
    _persistStats(state.stats.copyWith(lastCircuit: id));
  }

  void selectLivery(
    GrandPrixLivery livery, {
    required Iterable<String> ownedLiveryIds,
  }) {
    if (!gp_liveries.isGrandPrixLiveryOwned(livery.name, ownedLiveryIds)) return;
    if (livery == state.stats.lastLivery) return;
    _persistStats(state.stats.copyWith(lastLivery: livery));
  }

  void selectLaps(int laps) {
    if (laps == state.stats.lastLaps) return;
    _persistStats(state.stats.copyWith(lastLaps: laps));
  }

  void _persistStats(GrandPrixStats stats) {
    emit(state.copyWith(stats: stats));
    unawaited(_storage.saveGrandPrixStats(stats));
  }

  // -- race lifecycle -------------------------------------------------------

  /// Seeds a fresh race from the current selections. The [RaceSetup] is the
  /// single source the Flame game rebuilds the whole field from.
  void buildRace(int playerLevel) {
    _cancelTimers();
    final setup = RaceSetup(
      circuit: grandPrixCircuit(state.stats.lastCircuit),
      playerLivery: state.stats.lastLivery,
      playerLevel: playerLevel,
      startPosition: 8 + _random.nextInt(9), // P8–P16
      seed: _random.nextInt(1 << 31),
      laps: state.stats.lastLaps,
    );
    emit(
      state.copyWith(
        phase: GrandPrixPhase.grid,
        setup: setup,
        result: null,
        launchGrade: null,
        lightsOn: 0,
        lightsOut: false,
        playerPosition: setup.startPosition,
        lastOvertake: null,
      ),
    );
  }

  /// Runs the five-lights sequence. With [reducedMotion] the reaction test is
  /// skipped entirely and the car gets a fixed average launch (spec).
  void beginLights({required bool reducedMotion}) {
    if (state.phase != GrandPrixPhase.grid) return;
    _cancelTimers();
    if (reducedMotion) {
      emit(
        state.copyWith(
          phase: GrandPrixPhase.racing,
          launchGrade: LaunchGrade.good,
          lightsOut: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        phase: GrandPrixPhase.lights,
        lightsOn: 0,
        lightsOut: false,
      ),
    );
    for (var lamp = 1; lamp <= 5; lamp++) {
      final lit = lamp;
      _lightTimers.add(
        Timer(Duration(milliseconds: _lightIntervalMs * lamp), () {
          if (state.phase == GrandPrixPhase.lights) {
            emit(state.copyWith(lightsOn: lit));
          }
        }),
      );
    }
    final outMs =
        _lightIntervalMs * 5 +
        _minHoldMs +
        _random.nextInt(_maxHoldMs - _minHoldMs + 1);
    _lightTimers.add(
      Timer(Duration(milliseconds: outMs), () {
        if (state.phase != GrandPrixPhase.lights) return;
        _lightsOutAt = DateTime.now();
        emit(state.copyWith(lightsOn: 0, lightsOut: true));
        _lightTimers.add(
          Timer(_launchTimeout, () {
            if (state.phase == GrandPrixPhase.lights) {
              _goRacing(LaunchGrade.slow);
            }
          }),
        );
      }),
    );
  }

  /// First Accelerate press during the start sequence. Before lights-out this
  /// is a jump start; after, the reaction time grades the launch.
  void registerThrottleTap() {
    if (state.phase != GrandPrixPhase.lights) return;
    if (!state.lightsOut) {
      _goRacing(LaunchGrade.jump);
      return;
    }
    final outAt = _lightsOutAt;
    final reaction = outAt == null
        ? Duration.zero
        : DateTime.now().difference(outAt);
    _goRacing(gradeLaunch(reaction));
  }

  void _goRacing(LaunchGrade grade) {
    _cancelTimers();
    emit(
      state.copyWith(
        phase: GrandPrixPhase.racing,
        launchGrade: grade,
        lightsOn: 0,
        lightsOut: true,
      ),
    );
  }

  // -- callbacks from the Flame game (coarse, on-change only) ----------------

  void onPlayerPositionChanged(int position) {
    if (state.phase != GrandPrixPhase.racing) return;
    if (position == state.playerPosition) return;
    emit(state.copyWith(playerPosition: position));
  }

  void onOvertake(OvertakeEvent event) {
    if (state.phase != GrandPrixPhase.racing) return;
    emit(
      state.copyWith(lastOvertake: event, eventTick: state.eventTick + 1),
    );
  }

  Future<void> onRaceFinished(PlayerRaceOutcome outcome) async {
    final setup = state.setup;
    if (setup == null || state.phase != GrandPrixPhase.racing) return;
    final circuitId = setup.circuit.id;
    final laps = setup.laps;
    // A DNF sets no lap and can never be a personal best.
    final personalBest = !outcome.dnf &&
        state.stats.isPersonalBest(circuitId, outcome.lapTimeMs, laps: laps);
    final result = GrandPrixResult(
      position: outcome.position,
      fieldSize: kFieldSize,
      startPosition: setup.startPosition,
      lapTimeMs: outcome.lapTimeMs,
      personalBest: personalBest,
      launchGrade: state.launchGrade ?? LaunchGrade.slow,
      circuit: circuitId,
      xp: calculateGrandPrixXP(
        outcome.position,
        personalBest: personalBest,
        laps: laps,
      ),
      laps: laps,
      bestOvertakeName: outcome.bestOvertakeName,
      retired: outcome.dnf,
    );
    final stats = state.stats.recordResult(
      position: outcome.position,
      lapTimeMs: outcome.lapTimeMs,
      circuit: circuitId,
      laps: laps,
    );
    emit(
      state.copyWith(
        phase: GrandPrixPhase.finished,
        result: result,
        stats: stats,
        playerPosition: outcome.position,
      ),
    );
    await _storage.saveGrandPrixStats(stats);
  }

  /// The race screen calls this after its finish beat to raise the overlay.
  void showResult() {
    if (state.phase != GrandPrixPhase.finished) return;
    emit(state.copyWith(phase: GrandPrixPhase.result));
  }

  /// Leaving mid-race discards the attempt — no stats, no reward (spec).
  void abandonRace() {
    _cancelTimers();
    emit(
      state.copyWith(
        phase: GrandPrixPhase.idle,
        setup: null,
        result: null,
        launchGrade: null,
        lightsOn: 0,
        lightsOut: false,
        lastOvertake: null,
      ),
    );
  }

  void _cancelTimers() {
    for (final timer in _lightTimers) {
      timer.cancel();
    }
    _lightTimers.clear();
    _lightsOutAt = null;
  }

  @override
  Future<void> close() {
    _cancelTimers();
    return super.close();
  }
}
```

## Appendix B — Play-layer widgets (verbatim)

Controls and HUD. These compile against Appendix A + D with no edits.

### B.1 `lib/screens/grand_prix/widgets/grand_prix_controls.dart`

<sub>152 lines</sub>

```dart
import 'package:flutter/material.dart';

import '../../../config/theme.dart';

/// The race control pad: [◀][▶] steering on the left, [BRAKE][ACCEL] pedals on
/// the right. Each pad is a raw [Listener] (not a GestureDetector) so
/// multi-touch works — steering and throttle must be holdable simultaneously.
/// Pads are calm plates; pressed state is an accent fill, never a glow.
class GrandPrixControls extends StatelessWidget {
  const GrandPrixControls({
    required this.onLeft,
    required this.onRight,
    required this.onThrottle,
    required this.onBrake,
    super.key,
  });

  final ValueChanged<bool> onLeft;
  final ValueChanged<bool> onRight;
  final ValueChanged<bool> onThrottle;
  final ValueChanged<bool> onBrake;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0.94),
            Cyber.bg.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Row(
        children: [
          _HoldPad(
            icon: Icons.chevron_left,
            accent: Cyber.cyan,
            onHold: onLeft,
          ),
          const SizedBox(width: 10),
          _HoldPad(
            icon: Icons.chevron_right,
            accent: Cyber.cyan,
            onHold: onRight,
          ),
          const Spacer(),
          _HoldPad(
            icon: Icons.stacked_line_chart,
            label: 'BRAKE',
            accent: Cyber.danger,
            wide: true,
            onHold: onBrake,
          ),
          const SizedBox(width: 10),
          _HoldPad(
            icon: Icons.keyboard_double_arrow_up,
            label: 'ACCEL',
            accent: Cyber.success,
            wide: true,
            onHold: onThrottle,
          ),
        ],
      ),
    );
  }
}

class _HoldPad extends StatefulWidget {
  const _HoldPad({
    required this.icon,
    required this.accent,
    required this.onHold,
    this.label,
    this.wide = false,
  });

  final IconData icon;
  final String? label;
  final Color accent;
  final bool wide;
  final ValueChanged<bool> onHold;

  @override
  State<_HoldPad> createState() => _HoldPadState();
}

class _HoldPadState extends State<_HoldPad> {
  bool _down = false;

  void _set(bool down) {
    if (_down == down) return;
    setState(() => _down = down);
    widget.onHold(down);
  }

  @override
  void dispose() {
    if (_down) widget.onHold(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: widget.wide ? 92 : 64,
        height: 68,
        decoration: BoxDecoration(
          color: _down
              ? accent.withValues(alpha: 0.28)
              : Cyber.panel.withValues(alpha: 0.85),
          border: Border.all(
            color: accent.withValues(alpha: _down ? 0.9 : 0.4),
            width: _down ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.icon,
              color: _down ? accent : accent.withValues(alpha: 0.75),
              size: widget.label == null ? 30 : 22,
            ),
            if (widget.label != null) ...[
              const SizedBox(height: 3),
              Text(
                widget.label!,
                style: TextStyle(
                  color: _down ? accent : Cyber.muted,
                  fontFamily: Cyber.displayFont,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

## Appendix C — Host screens (verbatim, reference only)

Shown so the wiring in §7 can be read in full. **Not compile-checked**: these import source-app systems listed in §9 (global `GameBloc`, audio scenes, matchmaking gate, level-up celebration, confirm dialog). Port them by applying §9.

### C.1 `lib/screens/grand_prix/grand_prix_race_screen.dart`

<sub>754 lines</sub>

```dart
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/grand_prix/grand_prix_cubit.dart';
import '../../blocs/grand_prix/grand_prix_state.dart';
import '../../config/theme.dart';
import '../../data/grand_prix_circuits.dart';
import '../../games/grand_prix/grand_prix_engine.dart';
import '../../games/grand_prix/grand_prix_game.dart';
import '../../models/grand_prix.dart';
import '../../utils/game_audio_mappings.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/grand_prix_controls.dart';
import 'widgets/grand_prix_result.dart';

/// The live race: full-bleed Flame scroller under a slim cyber HUD (position,
/// lap progress, speed), the five-lights start rig, overtake toasts, the
/// control pad, and the result overlay. The cubit owns the phase machine; the
/// Flame game owns the 60fps simulation; this screen bridges the two and
/// dispatches the reward exactly once at the finish.
class GrandPrixRaceScreen extends StatefulWidget {
  const GrandPrixRaceScreen({
    required this.onExit,
    required this.onRaceAgain,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onRaceAgain;

  @override
  State<GrandPrixRaceScreen> createState() => _GrandPrixRaceScreenState();
}

class _GrandPrixRaceScreenState extends State<GrandPrixRaceScreen> {
  late final GrandPrixCubit _cubit;
  late final GrandPrixGame _game;
  RaceSetup? _setup;
  bool _rewardsDispatched = false;
  bool _lightsScheduled = false;
  bool _lightsOutSounded = false;
  bool _engineStarted = false;
  int _lastLightsOn = 0;
  Timer? _engineTimer;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<GrandPrixCubit>();
    _setup = _cubit.state.setup;
    final reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _game = GrandPrixGame(
      setup: _setup!,
      onPositionChanged: _cubit.onPlayerPositionChanged,
      onOvertake: _onOvertake,
      onPlayerFinished: _onPlayerFinished,
      onAudioEvent: _onRaceAudioEvent,
      reducedMotion: reducedMotion,
    );
    AudioController.instance.enterScene(AudioScene.grandPrix);
    // The phase is already `grid` when this screen mounts, so the
    // BlocListener never fires for it — kick off the lights beat here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scheduleLights(context);
    });
  }

  void _scheduleLights(BuildContext context) {
    if (_lightsScheduled) return;
    _lightsScheduled = true;
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _cubit.beginLights(reducedMotion: reducedMotion);
    });
  }

  @override
  void dispose() {
    _engineTimer?.cancel();
    AudioController.instance.stopDynamicLoop();
    AudioController.instance.leaveScene(AudioScene.grandPrix);
    _game.stopRace();
    // Leaving mid-race discards the attempt (no stats, no reward). A RACE
    // AGAIN relaunch has already replaced the setup by the time this route
    // is disposed — the identity check keeps us from resetting the new race.
    final phase = _cubit.state.phase;
    final midRace =
        phase == GrandPrixPhase.grid ||
        phase == GrandPrixPhase.lights ||
        phase == GrandPrixPhase.racing;
    if (midRace && identical(_cubit.state.setup, _setup)) {
      _cubit.abandonRace();
    }
    super.dispose();
  }

  void _onOvertake(OvertakeEvent event) {
    _cubit.onOvertake(event);
    playSound(SoundEffect.gpOvertake);
    HapticFeedback.selectionClick();
  }

  void _onPlayerFinished(PlayerRaceOutcome outcome) {
    if (!outcome.dnf) playSound(SoundEffect.gpFinish);
    _cubit.onRaceFinished(outcome);
  }

  void _onRaceAudioEvent(GrandPrixAudioEvent event) {
    playSound(grandPrixEventSound(event));
  }

  void _drive(BuildContext context, GrandPrixState state) {
    if (state.lightsOn > _lastLightsOn) {
      playSound(SoundEffect.gpLightOn);
    }
    if (state.lightsOut &&
        !_lightsOutSounded &&
        state.launchGrade != LaunchGrade.jump) {
      _lightsOutSounded = true;
      playSound(SoundEffect.gpLightsOut);
    }
    _lastLightsOn = state.lightsOn;
    switch (state.phase) {
      case GrandPrixPhase.grid:
        _scheduleLights(context);
      case GrandPrixPhase.racing:
        final grade = state.launchGrade;
        if (grade != null) {
          _game.startRace(grade);
          if (grade == LaunchGrade.jump) {
            playSound(SoundEffect.gpJumpStart);
          }
          _startEngineAudio();
          if (grade == LaunchGrade.jump) {
            HapticFeedback.heavyImpact();
          } else {
            HapticFeedback.mediumImpact();
          }
        }
      case GrandPrixPhase.finished:
        _onFinished(state);
      case GrandPrixPhase.idle:
      case GrandPrixPhase.lights:
      case GrandPrixPhase.result:
        break;
    }
  }

  void _startEngineAudio() {
    if (_engineStarted) return;
    _engineStarted = true;
    AudioController.instance.startDynamicLoop();
    _engineTimer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      AudioController.instance.updateDynamicLoop(
        (_game.speedKph.value / 320).clamp(0.0, 1.0),
      );
    });
  }

  void _onFinished(GrandPrixState state) {
    final result = state.result;
    if (_rewardsDispatched || result == null) return;
    _rewardsDispatched = true;
    _game.stopRace();
    _engineTimer?.cancel();
    AudioController.instance.stopDynamicLoop();
    final resultCue = result.retired
        ? SoundEffect.gpDnf
        : result.position <= 3
        ? SoundEffect.gpPodium
        : result.verdict == GrandPrixVerdict.points
        ? SoundEffect.gpPoints
        : null;
    if (resultCue != null) playSound(resultCue);
    HapticFeedback.heavyImpact();
    final verdictLabel = result.retired
        ? 'Retired'
        : switch (result.verdict) {
            GrandPrixVerdict.win => 'Victory',
            GrandPrixVerdict.podium => 'Podium',
            GrandPrixVerdict.points => 'Points',
            GrandPrixVerdict.finished => 'Finished',
          };
    // Distance rides along in the label so history + XP ledger read
    // 'EMERALD PARK · 3 LAPS' without touching the event shape.
    final circuitLabel = result.laps > 1
        ? '${grandPrixCircuit(result.circuit).name} · ${result.laps} LAPS'
        : grandPrixCircuit(result.circuit).name;
    context.read<GameBloc>().add(
      GrandPrixFinished(
        position: result.position,
        fieldSize: result.fieldSize,
        circuitName: circuitLabel,
        lapTimeMs: result.lapTimeMs,
        verdictLabel: verdictLabel,
        xp: result.xp,
      ),
    );
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _cubit.showResult();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: BlocListener<GrandPrixCubit, GrandPrixState>(
        listenWhen: (p, c) =>
            p.phase != c.phase ||
            p.launchGrade != c.launchGrade ||
            p.lightsOn != c.lightsOn ||
            p.lightsOut != c.lightsOut,
        listener: _drive,
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(child: GameWidget(game: _game)),
              Align(
                alignment: Alignment.topCenter,
                child: _RaceHud(game: _game, onExit: widget.onExit),
              ),
              Align(child: _LightsRig()),
              _LaunchGradeFlash(),
              _LapFlash(game: _game),
              _StuckWarning(game: _game),
              _OvertakeToast(),
              Align(
                alignment: Alignment.bottomCenter,
                child: GrandPrixControls(
                  onLeft: (down) => _game.setInputs(left: down),
                  onRight: (down) => _game.setInputs(right: down),
                  onBrake: (down) => _game.setInputs(brake: down),
                  onThrottle: (down) {
                    _game.setInputs(throttle: down);
                    if (down && _cubit.state.phase == GrandPrixPhase.lights) {
                      _cubit.registerThrottleTap();
                    }
                  },
                ),
              ),
              _ResultLayer(
                onExit: widget.onExit,
                onRaceAgain: widget.onRaceAgain,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top HUD: exit · position · lap bar · speed
// ---------------------------------------------------------------------------

class _RaceHud extends StatelessWidget {
  const _RaceHud({required this.game, required this.onExit});

  final GrandPrixGame game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0.92),
            Cyber.bg.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close, color: Cyber.muted, size: 20),
                visualDensity: VisualDensity.compact,
              ),
              const Spacer(),
              BlocBuilder<GrandPrixCubit, GrandPrixState>(
                buildWhen: (p, c) => p.playerPosition != c.playerPosition,
                builder: (context, state) => Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'P${state.playerPosition}',
                      style: Cyber.display(26, color: Cyber.cyan).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      '/$kFieldSize',
                      style: Cyber.display(13, color: Cyber.muted).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              ValueListenableBuilder<double>(
                valueListenable: game.speedKph,
                builder: (context, kph, _) => SizedBox(
                  width: 84,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${kph.round()} KPH',
                      maxLines: 1,
                      softWrap: false,
                      style: Cyber.display(13, color: Colors.white).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 12),
              ValueListenableBuilder<int>(
                valueListenable: game.currentLap,
                builder: (context, lap, _) => Text(
                  game.laps == 1 ? 'LAP' : 'LAP $lap/${game.laps}',
                  style: const TextStyle(
                    color: Cyber.muted,
                    fontFamily: Cyber.displayFont,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ValueListenableBuilder<double>(
                  valueListenable: game.lapProgress,
                  builder: (context, progress, _) => CyberProgressBar(
                    value: progress,
                    accent: Cyber.f1Red,
                    height: 5,
                    radius: 2,
                    animate: false,
                    trackColor: Cyber.f1Red.withValues(alpha: 0.14),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: game.slipstreamActive,
                builder: (context, tow, _) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: tow ? 1 : 0,
                  child: const CyberChip(label: 'TOW', color: Cyber.cyan),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Start lights rig
// ---------------------------------------------------------------------------

class _LightsRig extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrandPrixCubit, GrandPrixState>(
      buildWhen: (p, c) =>
          p.phase != c.phase ||
          p.lightsOn != c.lightsOn ||
          p.lightsOut != c.lightsOut,
      builder: (context, state) {
        final visible =
            state.phase == GrandPrixPhase.grid ||
            state.phase == GrandPrixPhase.lights;
        if (!visible) return const SizedBox.shrink();
        final waiting = state.phase == GrandPrixPhase.grid;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.85),
                border: Border.all(color: Cyber.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var lamp = 1; lamp <= 5; lamp++) ...[
                    _Lamp(on: lamp <= state.lightsOn),
                    if (lamp < 5) const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              waiting
                  ? 'ON THE GRID'
                  : state.lightsOut
                  ? 'GO GO GO!'
                  : 'WAIT FOR LIGHTS OUT…',
              style: Cyber.label(
                10,
                color: state.lightsOut ? Cyber.success : Cyber.muted,
                letterSpacing: 2.4,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Lamp extends StatelessWidget {
  const _Lamp({required this.on});

  final bool on;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? Cyber.danger : Cyber.panel,
        border: Border.all(color: on ? Cyber.danger : Cyber.border, width: 1.4),
        boxShadow: on ? Cyber.glow(Cyber.danger, alpha: 0.6, blur: 14) : null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Launch-grade flash (PERFECT LAUNCH / JUMP START …)
// ---------------------------------------------------------------------------

class _LaunchGradeFlash extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrandPrixCubit, GrandPrixState>(
      buildWhen: (p, c) => p.launchGrade != c.launchGrade || p.phase != c.phase,
      builder: (context, state) {
        final grade = state.launchGrade;
        if (grade == null || state.phase != GrandPrixPhase.racing) {
          return const SizedBox.shrink();
        }
        final (label, color) = switch (grade) {
          LaunchGrade.perfect => ('PERFECT LAUNCH', Cyber.gold),
          LaunchGrade.great => ('GREAT LAUNCH', Cyber.success),
          LaunchGrade.good => ('GOOD LAUNCH', Cyber.cyan),
          LaunchGrade.slow => ('SLOW AWAY', Cyber.amber),
          LaunchGrade.jump => ('JUMP START — THROTTLE CUT', Cyber.danger),
        };
        return Align(
          alignment: const Alignment(0, -0.45),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(grade),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1900),
            builder: (context, t, child) {
              final appear = (t * 6).clamp(0.0, 1.0);
              final fade = t > 0.75 ? (1 - (t - 0.75) / 0.25) : 1.0;
              return Opacity(
                // Clamped: the fade math can dip a hair below 0 at t == 1.0
                // (binary float), which trips Opacity's assert.
                opacity: (appear * fade).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.8 + 0.2 * Curves.easeOutBack.transform(appear),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.8),
                border: Border.all(color: color),
                boxShadow: Cyber.glow(color, alpha: 0.35),
              ),
              child: Text(
                label,
                style: Cyber.display(15, color: color, letterSpacing: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Lap-cross flash — a beat every time the player takes the line (multi-lap)
// ---------------------------------------------------------------------------

class _LapFlash extends StatefulWidget {
  const _LapFlash({required this.game});

  final GrandPrixGame game;

  @override
  State<_LapFlash> createState() => _LapFlashState();
}

class _LapFlashState extends State<_LapFlash> {
  int _shownLap = 1;

  @override
  void initState() {
    super.initState();
    widget.game.currentLap.addListener(_onLap);
  }

  @override
  void dispose() {
    widget.game.currentLap.removeListener(_onLap);
    super.dispose();
  }

  void _onLap() {
    final lap = widget.game.currentLap.value;
    // Only fires forwards: a fresh race mounts a fresh screen, so no resets.
    if (lap <= 1 || lap == _shownLap) return;
    setState(() => _shownLap = lap);
    playSound(SoundEffect.gpLap);
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    if (_shownLap <= 1) return const SizedBox.shrink();
    final finalLap = _shownLap == widget.game.laps;
    final color = finalLap ? Cyber.gold : Cyber.cyan;
    return Align(
      alignment: const Alignment(0, -0.45),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(_shownLap),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1600),
        builder: (context, t, child) {
          final appear = (t * 5).clamp(0.0, 1.0);
          final fade = t > 0.72 ? (1 - (t - 0.72) / 0.28) : 1.0;
          return Opacity(
            // Clamped: the fade math can dip a hair below 0 at t == 1.0
            // (binary float), which trips Opacity's assert.
            opacity: (appear * fade).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.85 + 0.15 * Curves.easeOutBack.transform(appear),
              child: child,
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Cyber.bg.withValues(alpha: 0.8),
            border: Border.all(color: color),
            // FINAL LAP is the moment; ordinary lap crossings stay calm.
            boxShadow: finalLap ? Cyber.glow(color, alpha: 0.35) : null,
          ),
          child: Text(
            finalLap ? 'FINAL LAP' : 'LAP $_shownLap / ${widget.game.laps}',
            style: Cyber.display(
              15,
              color: color,
              letterSpacing: 2,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stuck warning — get moving or the race is over
// ---------------------------------------------------------------------------

class _StuckWarning extends StatelessWidget {
  const _StuckWarning({required this.game});

  final GrandPrixGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: game.stuckSeconds,
      builder: (context, stuck, _) {
        // Only warn once the player has been stuck a beat — brief dips (a hard
        // brake or a spin) shouldn't flash it.
        if (stuck < 2.5) return const SizedBox.shrink();
        final remaining = (kStuckTimeout - stuck).clamp(0.0, kStuckTimeout);
        return Align(
          alignment: const Alignment(0, -0.12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: 0.85),
              border: Border.all(color: Cyber.danger, width: 1.5),
              boxShadow: Cyber.glow(Cyber.danger, alpha: 0.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Cyber.danger,
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  'GET BACK ON TRACK',
                  style: Cyber.display(
                    16,
                    color: Cyber.danger,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'RETIRING IN ${remaining.ceil()}s',
                  style: Cyber.label(11, color: Cyber.danger, letterSpacing: 2)
                      .copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Overtake toast
// ---------------------------------------------------------------------------

class _OvertakeToast extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrandPrixCubit, GrandPrixState>(
      buildWhen: (p, c) => p.eventTick != c.eventTick,
      builder: (context, state) {
        final overtake = state.lastOvertake;
        if (overtake == null || state.phase != GrandPrixPhase.racing) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: const Alignment(0, -0.72),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(state.eventTick),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 1500),
            builder: (context, t, child) {
              final appear = (t * 5).clamp(0.0, 1.0);
              final fade = t > 0.7 ? (1 - (t - 0.7) / 0.3) : 1.0;
              return Opacity(
                // Clamped: (1 - 0.7) / 0.3 > 1 in binary float, so the fade
                // ends ~-2e-16 at t == 1.0 and trips Opacity's assert.
                opacity: (appear * fade).clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - appear) * 10),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.78),
                border: Border.all(color: Cyber.cyan.withValues(alpha: 0.6)),
              ),
              child: Text(
                'P${overtake.overtakenPosition} ▲ PASSED '
                '${overtake.overtakenName.toUpperCase()}',
                style: Cyber.label(9, color: Cyber.cyan, letterSpacing: 1.4),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Result overlay layer
// ---------------------------------------------------------------------------

class _ResultLayer extends StatelessWidget {
  const _ResultLayer({required this.onExit, required this.onRaceAgain});

  final VoidCallback onExit;
  final VoidCallback onRaceAgain;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GrandPrixCubit, GrandPrixState>(
      buildWhen: (p, c) =>
          (p.phase == GrandPrixPhase.result) !=
          (c.phase == GrandPrixPhase.result),
      builder: (context, state) {
        final result = state.result;
        if (state.phase != GrandPrixPhase.result || result == null) {
          return const SizedBox.shrink();
        }
        return GrandPrixResultOverlay(
          result: result,
          circuitName: grandPrixCircuit(result.circuit).name,
          onExit: onExit,
          onRaceAgain: onRaceAgain,
        );
      },
    );
  }
}
```

### C.2 `lib/screens/grand_prix/widgets/grand_prix_result.dart`

<sub>475 lines</sub>

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/grand_prix.dart';
import '../../../models/progression.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/level_up_celebration.dart';

/// Post-race cinematic, modelled on the Football Chess full-time screen: a
/// sequenced reveal — verdict banner → giant finishing position + places
/// gained → race stat rows (lap time/PB, launch grade, MVP move) → XP
/// count-up — over a fixed RACE AGAIN / EXIT dock. A level-up crossing plays
/// the shared celebration after the sequence.
class GrandPrixResultOverlay extends StatefulWidget {
  const GrandPrixResultOverlay({
    required this.result,
    required this.circuitName,
    required this.onExit,
    required this.onRaceAgain,
    super.key,
  });

  final GrandPrixResult result;
  final String circuitName;
  final VoidCallback onExit;
  final VoidCallback onRaceAgain;

  @override
  State<GrandPrixResultOverlay> createState() => _GrandPrixResultState();
}

class _GrandPrixResultState extends State<GrandPrixResultOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _seq = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  late final Animation<double> _banner = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.0, 0.20, curve: Curves.easeOut),
  );
  late final Animation<double> _position = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.10, 0.36, curve: Curves.easeOutBack),
  );
  late final Animation<double> _statRows = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.28, 0.52, curve: Curves.easeOutCubic),
  );
  late final Animation<double> _xpPanel = CurvedAnimation(
    parent: _seq,
    curve: const Interval(0.40, 0.62, curve: Curves.easeOutCubic),
  );

  bool _showLevelUp = false;

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      _seq.value = 1;
      _maybeLevelUp();
    } else {
      _seq.forward();
      _seq.addStatusListener((status) {
        if (status == AnimationStatus.completed) _maybeLevelUp();
      });
    }
  }

  void _maybeLevelUp() {
    if (!mounted) return;
    if (context.read<GameBloc>().state.pendingLevelUps.isNotEmpty) {
      setState(() => _showLevelUp = true);
    }
  }

  @override
  void dispose() {
    _seq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final (verdictText, accent, icon) = result.retired
        ? ('RETIRED', Cyber.danger, Icons.warning_amber_rounded)
        : switch (result.verdict) {
            GrandPrixVerdict.win => ('WIN', Cyber.gold, Icons.emoji_events),
            GrandPrixVerdict.podium =>
              ('PODIUM', Cyber.f1Red, Icons.military_tech),
            GrandPrixVerdict.points => ('POINTS', Cyber.cyan, Icons.flag),
            GrandPrixVerdict.finished =>
              ('FINISHED', Cyber.amber, Icons.sports_score),
          };
    final game = context.watch<GameBloc>().state;
    final prog = game.progression;

    return Positioned.fill(
      child: Container(
        color: Cyber.bg.withValues(alpha: 0.94),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: AnimatedBuilder(
                      animation: _seq,
                      builder: (context, _) {
                        final xpT =
                            ((_seq.value - 0.48) / 0.42).clamp(0.0, 1.0);
                        final shownXp = (result.xp * xpT).round();
                        final barFill = (prog.xpToNextLevel == 0
                                ? 0.0
                                : prog.xpIntoLevel / prog.xpToNextLevel) *
                            xpT;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                          child: Column(
                            children: [
                              FadeTransition(
                                opacity: _banner,
                                child: _VerdictBanner(
                                  verdict: verdictText,
                                  accent: accent,
                                  icon: icon,
                                  circuitName: result.laps > 1
                                      ? '${widget.circuitName} · '
                                          '${result.laps} LAPS'
                                      : widget.circuitName,
                                ),
                              ),
                              const SizedBox(height: 18),
                              ScaleTransition(
                                scale: _position,
                                child: _PositionReadout(result: result),
                              ),
                              const SizedBox(height: 18),
                              FadeTransition(
                                opacity: _statRows,
                                child: _RaceStats(
                                  result: result,
                                ),
                              ),
                              const SizedBox(height: 16),
                              FadeTransition(
                                opacity: _xpPanel,
                                child: SlideTransition(
                                  position: Tween(
                                    begin: const Offset(0, 0.4),
                                    end: Offset.zero,
                                  ).animate(_xpPanel),
                                  child: _XpPanel(
                                    shownXp: shownXp,
                                    barFill: barFill.clamp(0.0, 1.0),
                                    level: prog.playerLevel,
                                    into: prog.xpIntoLevel,
                                    span: prog.xpToNextLevel,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  _Dock(
                    onExit: widget.onExit,
                    onRaceAgain: widget.onRaceAgain,
                  ),
                ],
              ),
              if (_showLevelUp)
                LevelUpCelebration(
                  levels: game.pendingLevelUps,
                  progression: game.progression,
                  xpEarned: game.lastMatchXP ?? 0,
                  trackLabel: game.pendingLevelUpTrack?.displayLabel,
                  onDismissed: () => setState(() => _showLevelUp = false),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  const _VerdictBanner({
    required this.verdict,
    required this.accent,
    required this.icon,
    required this.circuitName,
  });

  final String verdict;
  final Color accent;
  final IconData icon;
  final String circuitName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent, width: 1.5),
        boxShadow: Cyber.glow(accent),
      ),
      child: Column(
        children: [
          Icon(icon, color: accent, size: 34),
          const SizedBox(height: 6),
          Text(verdict, style: Cyber.display(34, color: accent, letterSpacing: 3)),
          const SizedBox(height: 4),
          Text(
            circuitName,
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}

class _PositionReadout extends StatelessWidget {
  const _PositionReadout({required this.result});

  final GrandPrixResult result;

  @override
  Widget build(BuildContext context) {
    if (result.retired) {
      return Column(
        children: [
          Text(
            'DNF',
            style: Cyber.display(64, color: Cyber.danger).copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'GAME OVER · STUCK ON TRACK',
            style: Cyber.label(10, color: Cyber.danger, letterSpacing: 1.8),
          ),
        ],
      );
    }
    final gained = result.placesGained;
    final (deltaText, deltaColor) = gained > 0
        ? ('▲ $gained PLACES GAINED', Cyber.success)
        : gained < 0
            ? ('▼ ${-gained} PLACES LOST', Cyber.danger)
            : ('HELD POSITION', Cyber.muted);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              'P${result.position}',
              style: Cyber.display(64, color: Cyber.cyan).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            Text(
              '/${result.fieldSize}',
              style: Cyber.display(28, color: Cyber.muted).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          deltaText,
          style: Cyber.label(10, color: deltaColor, letterSpacing: 1.8),
        ),
      ],
    );
  }
}

class _RaceStats extends StatelessWidget {
  const _RaceStats({required this.result});

  final GrandPrixResult result;

  @override
  Widget build(BuildContext context) {
    final launch = switch (result.launchGrade) {
      LaunchGrade.perfect => ('PERFECT', Cyber.gold),
      LaunchGrade.great => ('GREAT', Cyber.success),
      LaunchGrade.good => ('GOOD', Cyber.cyan),
      LaunchGrade.slow => ('SLOW', Cyber.amber),
      LaunchGrade.jump => ('JUMP START', Cyber.danger),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.85),
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        children: [
          _StatRow(
            label: result.laps > 1 ? 'RACE TIME' : 'LAP TIME',
            valueWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatLapTime(result.lapTimeMs),
                  style: Cyber.display(13, color: Colors.white).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (result.personalBest) ...[
                  const SizedBox(width: 8),
                  const CyberChip(label: 'PB', color: Cyber.gold),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          _StatRow(
            label: 'LAUNCH',
            valueWidget: CyberChip(label: launch.$1, color: launch.$2),
          ),
          if (result.bestOvertakeName != null) ...[
            const SizedBox(height: 10),
            _StatRow(
              label: 'MVP MOVE',
              valueWidget: Text(
                'PASSED ${result.bestOvertakeName!.toUpperCase()}',
                style: Cyber.label(10, color: Cyber.cyan, letterSpacing: 1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.valueWidget});

  final String label;
  final Widget valueWidget;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.6),
        ),
        const Spacer(),
        valueWidget,
      ],
    );
  }
}

class _XpPanel extends StatelessWidget {
  const _XpPanel({
    required this.shownXp,
    required this.barFill,
    required this.level,
    required this.into,
    required this.span,
  });

  final int shownXp;
  final double barFill;
  final int level;
  final int into;
  final int span;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Cyber.panel.withValues(alpha: 0.85),
        border: Border.all(color: Cyber.f1Red.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '+$shownXp XP',
            style: const TextStyle(
              fontFamily: Cyber.displayFont,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
              color: Cyber.f1Red,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 12),
          CyberProgressBar(
            value: barFill,
            accent: Cyber.f1Red,
            height: 6,
            radius: 3,
            animate: false,
            trackColor: Cyber.f1Red.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 8),
          Text(
            '$into / $span XP · LEVEL $level',
            style: Cyber.label(9, color: Cyber.muted, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.onExit, required this.onRaceAgain});

  final VoidCallback onExit;
  final VoidCallback onRaceAgain;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: CyberCtaButton(
              label: 'EXIT',
              onPressed: () {
                playSound(SoundEffect.uiTap);
                onExit();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: CyberCtaButton(
              label: 'RACE AGAIN',
              primary: true,
              onPressed: () {
                playSound(SoundEffect.playMatch);
                onRaceAgain();
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

## Appendix D — Stand-ins for host-app dependencies

The source app's versions of these files are large and app-wide. These are the minimal replacements the game code needs. Classes and methods marked *verbatim* are copied from the source; the rest are thin stand-ins. Replace them with your own systems whenever you like — keep the names and signatures.

### D.1 `lib/config/theme.dart`

<sub>111 lines</sub>

```dart
// STAND-IN for the host app's lib/config/theme.dart.
// Every token the four ported games read, resolved to the source app's
// literal values. If the target project already has a design system, map
// these names onto it instead of shipping a second palette.
import 'package:flutter/material.dart';

class AppTheme {
  static const Color textContrast = Color.fromRGBO(255, 255, 255, 1);
}

class Cyber {
  // Surfaces
  static const Color bg = Color.fromRGBO(13, 17, 26, 1);
  static const Color bg2 = Color.fromRGBO(7, 12, 31, 1);
  static const Color card = Color.fromRGBO(15, 23, 43, 1);
  static const Color panel = Color.fromRGBO(29, 41, 61, 1);
  static const Color panel2 = Color.fromRGBO(15, 23, 43, 1);

  // Accents
  static const Color cyan = Color.fromRGBO(92, 223, 255, 1);
  static const Color magenta = Color.fromRGBO(194, 122, 255, 1);
  static const Color violet = Color.fromRGBO(194, 122, 255, 1);
  static const Color lime = Color.fromRGBO(81, 255, 148, 1);
  static const Color amber = Color.fromRGBO(255, 137, 4, 1);
  static const Color gold = Color.fromRGBO(253, 199, 0, 1);
  static const Color danger = Color.fromRGBO(255, 77, 77, 1);
  static const Color success = Color.fromRGBO(5, 223, 114, 1);
  static const Color pink = Color(0xFFFF94C1);

  // Lines & text
  static const Color border = Color.fromRGBO(49, 65, 88, 1);
  static const Color line = Color.fromRGBO(69, 85, 108, 1);
  static const Color muted = Color.fromRGBO(144, 161, 185, 1);
  static const Color textPrimary = Color.fromRGBO(92, 223, 255, 1);
  static const Color borderMuted = Color(0xFF243654);

  // Arena backdrop
  static const Color arenaSky = Color(0xFF020812);
  static const Color arenaHorizon = Color(0xFF071522);
  static const Color arenaVioletHorizon = Color(0xFF101024);
  static const Color arenaFloor = Color(0xFF02050B);

  // Fonts — Orbitron (display/labels) and Onest (body). Declare both in
  // pubspec.yaml or swap in the target project's families.
  static const String displayFont = 'Orbitron';
  static const String bodyFont = 'Onest';

  static List<BoxShadow> glow(
    Color color, {
    double alpha = 0.3,
    double blur = 16,
    double spread = -2,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

  static TextStyle display(
    double size, {
    Color color = Colors.white,
    double letterSpacing = 1.5,
    FontWeight weight = FontWeight.w900,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: 1,
    decoration: TextDecoration.none,
  );

  static TextStyle body(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
    double height = 1.35,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: bodyFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );

  static TextStyle label(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = 0.9,
    double height = 1,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );
}
```

### D.2 `lib/models/progression.dart`

<sub>33 lines</sub>

```dart
// STAND-IN for the host app's lib/models/progression.dart — only the
// functions these games call, copied verbatim. In the source app XP is
// banked by a global GameBloc; wire the returned value to your own
// progression system.
import 'dart:math';

double cpuSmartness(int level) => min(1.0, level / 12);

// Longer Grand Prix race distances multiply the position payout — a 5-lap
// endurance run is worth the grind. Shown on the lobby's distance selector so
// keep the lobby chip and the payout reading from this one function.
int grandPrixXpMultiplier(int laps) => switch (laps) {
  >= 5 => 3,
  >= 3 => 2,
  _ => 1,
};

// XP for Grand Prix Dash — an arcade race, so it pays by finishing position:
// a one-lap win matches Football Chess's ceiling, a backmarker finish still
// earns a little, and longer distances multiply the position payout (see
// [grandPrixXpMultiplier]). A new personal best on the circuit+distance adds
// +3. XP only — racing never subtracts XP and never pays coins.
int calculateGrandPrixXP(int position, {bool personalBest = false, int laps = 1}) {
  final base = switch (position) {
    1 => 26,
    2 => 22,
    3 => 18,
    <= 6 => 12,
    <= 10 => 8,
    _ => 4,
  };
  return base * grandPrixXpMultiplier(laps) + (personalBest ? 3 : 0);
}
```

### D.3 `lib/services/secure_storage_service.dart`

<sub>31 lines</sub>

```dart
// STAND-IN for the host app's lib/services/secure_storage_service.dart.
// The real class also holds secure-storage data for other modes; the game
// records below live in plain SharedPreferences (verbatim methods + keys).
// Add `shared_preferences` to pubspec.yaml.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/grand_prix.dart';

class SecureGameStorage {
  static const _grandPrixStatsKey = 'pd_grand_prix_stats_v1';

  Future<GrandPrixStats> loadGrandPrixStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_grandPrixStatsKey);
      if (raw == null || raw.isEmpty) return const GrandPrixStats();
      return GrandPrixStats.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const GrandPrixStats();
    }
  }

  Future<void> saveGrandPrixStats(GrandPrixStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_grandPrixStatsKey, jsonEncode(stats.toJson()));
  }
}
```

### D.4 `lib/utils/sound_effects.dart`

<sub>10 lines</sub>

```dart
// STAND-IN for the host app's lib/utils/sound_effects.dart.
// The source app plays short one-shot cues through a pooled audio player.
// Wire these to your own audio layer (audioplayers / flame_audio / etc).
// Only the cues the ported widgets reference directly are listed here; the
// per-game event→cue tables are in each game doc's "Sound map" section.
enum SoundEffect { playMatch, cardSelect, riser }

void playSound(SoundEffect effect) {
  // no-op stand-in
}
```

### D.5 `lib/widgets/cyber/cyber_widgets.dart`

<sub>499 lines</sub>

```dart
// SUBSET of the host app's lib/widgets/cyber/cyber_widgets.dart — the
// shared HUD primitives the ported play layers use, copied verbatim.
import 'package:flutter/material.dart';

import '../../config/theme.dart';

class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Cyber.cyan.withValues(alpha: 0.7),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class CyberClipper extends CustomClipper<Path> {
  static const double cut = 12;

  static Path buildPath(Size size, {double cut = cut}) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// Angular HUD silhouette shared by the primary CTA ([HudCtaButton]) and player
/// cards: a strong chamfer on the top-left and bottom-right corners with smaller
/// accent cuts on the top-right and bottom-left. Keeping one silhouette across
/// buttons and cards makes them read as the same "HUD hardware" family.
class HudChamferClipper extends CustomClipper<Path> {
  const HudChamferClipper({required this.bigCut, required this.smallCut});

  final double bigCut;
  final double smallCut;

  Path buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(bigCut, 0) // after the top-left chamfer
      ..lineTo(w - smallCut, 0) // top edge
      ..lineTo(w, smallCut) // top-right accent
      ..lineTo(w, h - bigCut) // right edge
      ..lineTo(w - bigCut, h) // bottom-right chamfer
      ..lineTo(smallCut, h) // bottom edge
      ..lineTo(0, h - smallCut) // bottom-left accent
      ..lineTo(0, bigCut) // left edge
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant HudChamferClipper old) =>
      old.bigCut != bigCut || old.smallCut != smallCut;
}

/// Clips an interactive surface and strokes that exact path in the foreground.
///
/// A rectangular [BoxDecoration.border] is clipped along with its child and
/// therefore cannot paint the diagonal chamfer segments. CTA implementations
/// use this shell so every straight and cut edge receives the same border.
class ChamferedActionSurface extends StatelessWidget {
  const ChamferedActionSurface({
    required this.clipper,
    required this.borderColor,
    required this.child,
    this.borderWidth = 1,
    this.glowColor,
    this.glow = 0,
    super.key,
  });

  final CustomClipper<Path> clipper;
  final Color borderColor;
  final double borderWidth;
  final Color? glowColor;
  final double glow;
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: ChamferedActionBorderPainter(
      clipper: clipper,
      color: borderColor,
      width: borderWidth,
      glowColor: glowColor,
      glow: glow,
    ),
    child: ClipPath(clipper: clipper, child: child),
  );
}

/// Border painter shared by app CTAs that use a clipped action silhouette.
class ChamferedActionBorderPainter extends CustomPainter {
  const ChamferedActionBorderPainter({
    required this.clipper,
    required this.color,
    required this.width,
    this.glowColor,
    this.glow = 0,
  });

  final CustomClipper<Path> clipper;
  final Color color;
  final double width;
  final Color? glowColor;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final path = clipper.getClip(size);
    if (glow > 0 && glowColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glowColor!.withValues(alpha: 0.22 * glow.clamp(0, 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = width + 1.5
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * glow),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(covariant ChamferedActionBorderPainter oldDelegate) =>
      oldDelegate.clipper != clipper ||
      oldDelegate.color != color ||
      oldDelegate.width != width ||
      oldDelegate.glowColor != glowColor ||
      oldDelegate.glow != glow;
}

/// What a [CyberChargeMeter] needs to draw itself. Every field is a 0..1
/// fraction of the track, so the meter never has to know what it is measuring —
/// Hoop Duel feeds it a jump, Final Over feeds it a backlift.
class ChargeMeterView {
  const ChargeMeterView({
    required this.progress,
    required this.perfectCenter,
    required this.perfectHalf,
    required this.goodHalf,
    this.overswingFrom,
    this.hot = false,
  });

  /// Where the needle sits.
  final double progress;

  /// Centre of the PERFECT band, and its half-width.
  final double perfectCenter;
  final double perfectHalf;

  /// How far the GOOD band extends *beyond* the perfect band on each side.
  final double goodHalf;

  /// Above this, you have overcooked it — drawn as a danger zone. Null for
  /// meters where holding longer simply cannot hurt you.
  final double? overswingFrom;

  /// The moment to release is NOW. Lights the track's edge — the only thing in
  /// here that glows, because it is the one live beat.
  final bool hot;
}

/// A polished progress / meter bar shared by every XP, rank and power meter so
/// the "gradient flow" reads identically across the app. The fill ramps from a
/// soft translucent accent to full colour over ~70% of its width and finishes
/// on a bright leading edge, paired with a tight, subtle glow and a glossy top
/// sheen for a clean finish.
class CyberProgressBar extends StatelessWidget {
  const CyberProgressBar({
    required this.value,
    this.accent = Cyber.cyan,
    this.height = 7,
    this.radius = 2,
    this.animate = true,
    this.trackColor,
    this.trackBorderColor,
    super.key,
  });

  /// Fill fraction, 0..1.
  final double value;
  final Color accent;
  final double height;
  final double radius;

  /// When true the fill grows from 0 to [value] on first build. Leave false
  /// when the caller already animates [value] itself.
  final bool animate;
  final Color? trackColor;
  final Color? trackBorderColor;

  Widget _bar(double v) {
    final r = BorderRadius.circular(radius);
    return SizedBox(
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: trackColor ?? Cyber.bg.withValues(alpha: 0.7),
                borderRadius: r,
                border: trackBorderColor == null
                    ? null
                    : Border.all(color: trackBorderColor!),
              ),
            ),
          ),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 6,
                    spreadRadius: -1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: r,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // The flow: soft fade-in, full colour by ~70%, bright tip.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            accent.withValues(alpha: 0.45),
                            accent.withValues(alpha: 0.95),
                            accent,
                          ],
                          stops: const [0.0, 0.7, 1.0],
                        ),
                      ),
                    ),
                    // Glossy top sheen.
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: height * 0.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.22),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0).toDouble();
    if (!animate) return _bar(target);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => _bar(v),
    );
  }
}

/// The shot meter, shared by Hoop Duel and Final Over: a dim GOOD band, a bright
/// PERFECT band, and a gold needle riding up the track. Release inside the lime.
class CyberChargeMeter extends StatelessWidget {
  const CyberChargeMeter({required this.view, super.key});

  final ChargeMeterView view;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 26,
    height: 150,
    child: CustomPaint(painter: _ChargeMeterPainter(view)),
  );
}

class _ChargeMeterPainter extends CustomPainter {
  _ChargeMeterPainter(this.view);

  final ChargeMeterView view;

  @override
  void paint(Canvas canvas, Size size) {
    final left = size.width / 2 - 5;
    final right = size.width / 2 + 5;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, 0, 10, size.height),
      const Radius.circular(2),
    );
    canvas.drawRRect(track, Paint()..color = Cyber.bg.withValues(alpha: 0.75));
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = view.hot ? 1.6 : 1
        ..color = view.hot ? Cyber.lime : Cyber.border,
    );

    double y(double frac) => size.height * (1 - frac.clamp(0.0, 1.0));

    // Charged-so-far fill goes UNDER the bands: it tints the empty track, it
    // does not wash out the very zones you are aiming at.
    final needleY = y(view.progress);
    canvas.drawRect(
      Rect.fromLTRB(left, needleY, right, size.height),
      Paint()..color = Cyber.gold.withValues(alpha: 0.42),
    );

    // Good window (wider, dimmer) behind the perfect band.
    canvas.drawRect(
      Rect.fromLTRB(
        left,
        y(view.perfectCenter + view.perfectHalf + view.goodHalf),
        right,
        y(view.perfectCenter - view.perfectHalf - view.goodHalf),
      ),
      Paint()..color = Cyber.cyan.withValues(alpha: 0.26),
    );
    // Overswing: held too long, and it costs you control.
    final overswing = view.overswingFrom;
    if (overswing != null) {
      canvas.drawRect(
        Rect.fromLTRB(left, y(1), right, y(overswing)),
        Paint()..color = Cyber.danger.withValues(alpha: 0.55),
      );
    }
    // Perfect band.
    canvas.drawRect(
      Rect.fromLTRB(
        left,
        y(view.perfectCenter + view.perfectHalf),
        right,
        y(view.perfectCenter - view.perfectHalf),
      ),
      Paint()..color = Cyber.lime.withValues(alpha: 0.85),
    );

    // The needle.
    canvas.drawLine(
      Offset(0, needleY),
      Offset(size.width, needleY),
      Paint()
        ..color = Cyber.gold
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_ChargeMeterPainter old) =>
      old.view.progress != view.progress ||
      old.view.perfectCenter != view.perfectCenter ||
      old.view.perfectHalf != view.perfectHalf ||
      old.view.overswingFrom != view.overswingFrom ||
      old.view.hot != view.hot;
}

class CyberChip extends StatelessWidget {
  const CyberChip({required this.label, required this.color, super.key});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontFamily: 'Onest',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class CyberPanel extends StatelessWidget {
  const CyberPanel({
    required this.child,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  /// Whether this is a focal / active surface that should glow. Off by default:
  /// most panels are plain surfaces and rely on the fill + border for depth.
  /// Reserve [glow] for the panel the user should look at first on a screen.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent.withValues(alpha: 0.5);
    return CustomPaint(
      foregroundPainter: _CyberPanelBorderPainter(color: borderColor),
      child: ClipPath(
        clipper: CyberClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Cyber.panel,
            boxShadow: glow
                ? Cyber.glow(accent, alpha: 0.18, blur: 18, spread: 1)
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _CyberPanelBorderPainter extends CustomPainter {
  const _CyberPanelBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CyberClipper.buildPath(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CyberPanelBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
```

### D.6 `lib/widgets/cyber/cyber_cta_button.dart`

<sub>460 lines</sub>

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

/// Accent blue used alongside [Cyber.cyan] for this button's gradient glow,
/// matching the primary CTA gradient elsewhere in the app.
const Color _accentBlue = Color(0xff5cb4ff);

/// Bright blue fill gradient (top-lit) for the inverted CTA treatment.
const Color _fillTop = Color(0xFF6FC4FF);
const Color _fillBottom = Color(0xFF2E90F5);

/// Dark ink used for the icon, divider and label sitting on the bright fill.
const Color _ink = Color(0xFF0C1422);

/// Angular HUD silhouette: a strong chamfer on the top-left and bottom-right
/// corners, with smaller angular accents on the top-right and bottom-left.
class _HudButtonClipper extends CustomClipper<Path> {
  final double bigCut;
  final double smallCut;
  const _HudButtonClipper({required this.bigCut, required this.smallCut});

  Path buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(bigCut, 0) // after the top-left chamfer
      ..lineTo(w - smallCut, 0) // top edge
      ..lineTo(w, smallCut) // top-right accent
      ..lineTo(w, h - bigCut) // right edge
      ..lineTo(w - bigCut, h) // bottom-right chamfer
      ..lineTo(smallCut, h) // bottom edge
      ..lineTo(0, h - smallCut) // bottom-left accent
      ..lineTo(0, bigCut) // left edge
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant _HudButtonClipper old) =>
      old.bigCut != bigCut || old.smallCut != smallCut;
}

/// Paints the glowing cyan/blue border by stroking the same HUD path twice:
/// a soft blurred glow stroke under a crisp gradient stroke.
class _HudBorderPainter extends CustomPainter {
  final double glow; // 0..1 intensity
  final double bigCut;
  final double smallCut;
  final Color glowColor;
  final Color borderColor;
  const _HudBorderPainter({
    required this.glow,
    required this.bigCut,
    required this.smallCut,
    required this.glowColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _HudButtonClipper(
      bigCut: bigCut,
      smallCut: smallCut,
    ).buildPath(size);

    // Soft halo only when intensity > 0 — glow:false CTAs stay crisp/flat.
    if (glow > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = glowColor.withValues(alpha: 0.30 + 0.40 * glow)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + 6 * glow);
      canvas.drawPath(path, glowPaint);
    }

    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.80 + 0.15 * glow),
          borderColor.withValues(alpha: 0.90),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _HudBorderPainter old) =>
      old.glow != glow ||
      old.bigCut != bigCut ||
      old.smallCut != smallCut ||
      old.glowColor != glowColor ||
      old.borderColor != borderColor;
}

/// Reusable gamified sci-fi HUD call-to-action button.
///
/// Angular clipped silhouette, glowing cyan border, bright gradient fill with
/// a chevron compartment and a glowing label. Pulses
/// gently while idle and intensifies on tap. Reuse it for any primary CTA via
/// [label] and the optional [icon].
class HudCtaButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final double height;
  final bool enabled;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final VoidCallback? onPressCancel;

  /// Primary accent for the glow, border and fill. Defaults to the Play Match
  /// cyan; pass e.g. [Cyber.violet] to recolour the button for another role.
  final Color accent;

  /// Cue played on tap. Defaults to the Play Match whoosh.
  final SoundEffect tapSound;

  /// Optional small sub-line rendered under [label] (e.g. an odds readout).
  final String? helper;

  /// Optional copy used while the pointer is held down. Hold-to-charge actions
  /// use this to tell the player exactly what releasing will do.
  final String? pressedLabel;
  final String? pressedHelper;

  /// When true (default) the button carries the pulsing neon halo. Set false
  /// for a calmer flat treatment (crisp border, no neon glow, no drop shadow)
  /// — e.g. on the hold-to-lock dock or profile-setup flow.
  final bool glow;

  /// Calm secondary action with a flat panel fill and accent-colored content.
  final bool outlined;
  final TextStyle? labelStyle;

  const HudCtaButton({
    super.key,
    this.label = 'PLAY MATCH',
    this.icon = Icons.keyboard_double_arrow_right,
    this.onTap,
    this.height = 64,
    this.accent = Cyber.cyan,
    this.tapSound = SoundEffect.playMatch,
    this.helper,
    this.pressedLabel,
    this.pressedHelper,
    this.glow = true,
    this.outlined = false,
    this.labelStyle,
    this.enabled = true,
    this.onPressStart,
    this.onPressEnd,
    this.onPressCancel,
  });

  @override
  State<HudCtaButton> createState() => _HudCtaButtonState();
}

class _HudCtaButtonState extends State<HudCtaButton>
    with SingleTickerProviderStateMixin {
  static const double _bigCut = 18;
  static const double _smallCut = 8;

  late final AnimationController _pulse;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HudCtaButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled && _pressed) {
      _pressed = false;
      widget.onPressCancel?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent;
    // The default cyan keeps the exact original Play Match palette; any other
    // accent derives a lighter companion tone and a bright fill from it.
    final bool isCyan = accent == Cyber.cyan;
    final Color secondary = isCyan
        ? _accentBlue
        : Color.lerp(accent, Colors.white, 0.30)!;
    final Color fillTop = widget.enabled
        ? (isCyan ? _fillTop : Color.lerp(accent, Colors.white, 0.34)!)
        : Cyber.panel2;
    final Color fillBottom = widget.enabled
        ? (isCyan ? _fillBottom : accent)
        : Cyber.panel;
    final contentColor = widget.enabled
        ? (widget.outlined ? accent : _ink)
        : Cyber.muted;
    final displayLabel = _pressed
        ? widget.pressedLabel ?? widget.label
        : widget.label;
    final displayHelper = _pressed
        ? widget.pressedHelper ?? widget.helper
        : widget.helper;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: displayLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled
            ? (_) {
                setState(() => _pressed = true);
                widget.onPressStart?.call();
              }
            : null,
        onTapUp: widget.enabled
            ? (_) {
                setState(() => _pressed = false);
                widget.onPressEnd?.call();
              }
            : null,
        onTapCancel: widget.enabled
            ? () {
                setState(() => _pressed = false);
                widget.onPressCancel?.call();
              }
            : null,
        onTap: widget.enabled && widget.onTap != null
            ? () {
                HapticFeedback.mediumImpact();
                playSound(widget.tapSound);
                widget.onTap!.call();
              }
            : null,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            // Idle pulse (0..1); fully lit while pressed for clear feedback.
            // With glow off the halo is dropped (a faint press tick only) and
            // the border stays crisp.
            final glow = widget.enabled && widget.glow
                ? (_pressed ? 1.0 : 0.25 + 0.45 * _pulse.value)
                : (_pressed ? 0.3 : 0.0);
            return Opacity(
              opacity: widget.enabled ? 1 : 0.58,
              child: Container(
                height: widget.height,
                width: double.infinity,
                decoration: BoxDecoration(
                  // Glow rule: halo only when [glow] is on. Flat otherwise —
                  // crisp border only, no drop shadow.
                  boxShadow: widget.enabled && widget.glow
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.18 + 0.22 * glow),
                            blurRadius: 24 + 16 * glow,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: secondary.withValues(
                              alpha: 0.12 + 0.18 * glow,
                            ),
                            blurRadius: 40 + 22 * glow,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: CustomPaint(
                  foregroundPainter: _HudBorderPainter(
                    glow: glow,
                    bigCut: _bigCut,
                    smallCut: _smallCut,
                    glowColor: widget.enabled ? accent : Cyber.line,
                    borderColor: widget.enabled ? secondary : Cyber.line,
                  ),
                  child: ClipPath(
                    clipper: const _HudButtonClipper(
                      bigCut: _bigCut,
                      smallCut: _smallCut,
                    ),
                    child: Stack(
                      children: [
                        // Bright interior with a subtle top-lit fade.
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: widget.outlined ? Cyber.panel : null,
                              gradient: widget.outlined
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [fillTop, fillBottom],
                                    ),
                            ),
                          ),
                        ),
                        // Chevron compartment | divider | label.
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(
                            children: [
                              Icon(
                                widget.icon,
                                color: contentColor,
                                size: 26,
                                shadows: [
                                  Shadow(
                                    color: Colors.white.withValues(alpha: 0.30),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Container(
                                width: 1.4,
                                height: widget.height * 0.42,
                                color: contentColor.withValues(alpha: 0.30),
                              ),
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          displayLabel,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                          style:
                                              (widget.labelStyle ??
                                                      DefaultTextStyle.of(
                                                        context,
                                                      ).style)
                                                  .copyWith(
                                                    color: contentColor,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 3,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.30,
                                                            ),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ),
                                      if (displayHelper != null) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          displayHelper,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: contentColor.withValues(
                                              alpha: 0.72,
                                            ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              // Balances the left chevron compartment so the
                              // label reads optically centred.
                              const SizedBox(width: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Primary HUD CTA with an explicit press/hold/release lifecycle.
///
/// It shares [HudCtaButton]'s chrome while avoiding a tap callback after the
/// release, which is important for charge controls that must resolve once.
class HudHoldCtaButton extends StatelessWidget {
  const HudHoldCtaButton({
    required this.label,
    required this.enabled,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onPressCancel,
    this.icon = Icons.keyboard_double_arrow_right,
    this.height = 64,
    this.accent = Cyber.cyan,
    this.glow = true,
    this.helper,
    this.pressedLabel,
    this.pressedHelper,
    super.key,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onPressCancel;
  final IconData icon;
  final double height;
  final Color accent;
  final bool glow;
  final String? helper;
  final String? pressedLabel;
  final String? pressedHelper;

  @override
  Widget build(BuildContext context) => HudCtaButton(
    label: label,
    icon: icon,
    height: height,
    accent: accent,
    glow: glow,
    enabled: enabled,
    helper: helper,
    pressedLabel: pressedLabel,
    pressedHelper: pressedHelper,
    onPressStart: onPressStart,
    onPressEnd: onPressEnd,
    onPressCancel: onPressCancel,
  );
}
```

## Appendix E — Acceptance tests (verbatim)

Run these after porting. Replace `package:card_game/` with your app's package name. Files under `final_over/test/` belong to the package and run from inside `final_over/`.

### E.1 `test/grand_prix_engine_test.dart`

<sub>631 lines</sub>

```dart
import 'dart:math';

import 'package:card_game/data/grand_prix_circuits.dart';
import 'package:card_game/data/grand_prix_drivers.dart';
import 'package:card_game/games/grand_prix/grand_prix_engine.dart';
import 'package:card_game/models/grand_prix.dart';
import 'package:flutter_test/flutter_test.dart';

const _dt = 1 / 120;

RaceSetup _setup({
  GrandPrixCircuitId circuit = GrandPrixCircuitId.emeraldPark,
  int playerLevel = 6,
  int startPosition = 10,
  int seed = 7,
  int laps = 1,
}) => RaceSetup(
  circuit: grandPrixCircuit(circuit),
  playerLivery: GrandPrixLivery.scarlet,
  playerLevel: playerLevel,
  startPosition: startPosition,
  seed: seed,
  laps: laps,
);

/// A one-car field on a bare test circuit for isolated physics assertions.
RaceField _soloField(List<TrackSection> sections, {int laps = 1}) {
  final circuit = GrandPrixCircuit(
    id: GrandPrixCircuitId.emeraldPark,
    name: 'TEST',
    character: 'TEST',
    flavor: '',
    difficultyStars: 1,
    sections: sections,
  );
  final car = CarState(
    index: 0,
    isPlayer: true,
    name: 'YOU',
    livery: GrandPrixLivery.scarlet,
    distance: 0,
    lateral: 0,
  );
  return RaceField(
    circuit: circuit,
    cars: [car],
    laps: laps,
  );
}

void _run(
  GrandPrixEngine engine,
  RaceField field,
  RaceInputs inputs,
  double seconds,
) {
  for (var t = 0.0; t < seconds; t += _dt) {
    engine.tick(field, inputs, _dt);
  }
}

RaceInputs _manualInputs(RaceField field) {
  final car = field.player;
  final section = field.circuit.sections[car.sectionIndex];
  var target = 0.0;
  switch (section.type) {
    case TrackSectionType.straight:
      target = 0;
    case TrackSectionType.corner:
      final insideSign = section.direction == CornerDirection.left ? -1 : 1;
      target = insideSign * kTrackHalfWidth * 0.55;
    case TrackSectionType.chicane:
      final start = field.sectionStarts[car.sectionIndex];
      final local = lapLocalDistance(field.circuit.lapLength, car.distance);
      final t = (local - start) / section.length;
      final entrySign = section.direction == CornerDirection.left ? -1 : 1;
      target = (t < 0.5 ? entrySign : -entrySign) * kTrackHalfWidth * 0.45;
  }

  final delta = target - car.lateral;
  final steer = delta.abs() < 0.25 ? 0.0 : delta.sign * min(1.0, delta.abs() / 2);
  final safe = section.safeSpeed;
  final brake = safe != null && car.speed > safe;
  return RaceInputs(steer: steer, throttle: !brake, brake: brake);
}

void main() {
  group('speed integration', () {
    test('throttle ramps toward top speed and never exceeds it', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      final car = field.player;
      _run(engine, field, const RaceInputs(throttle: true), 2);
      final early = car.speed;
      expect(early, greaterThan(20));
      _run(engine, field, const RaceInputs(throttle: true), 30);
      expect(car.speed, greaterThan(early));
      expect(car.speed, lessThanOrEqualTo(kTopSpeed + 0.001));
      expect(car.speed, greaterThan(kTopSpeed * 0.95));
    });

    test('braking sheds speed faster than coasting', () {
      final engine = GrandPrixEngine(random: Random(1));

      final coasting = _soloField(const [TrackSection.straight(5000)]);
      coasting.player.speed = 60;
      _run(engine, coasting, const RaceInputs(), 1);

      final braking = _soloField(const [TrackSection.straight(5000)]);
      braking.player.speed = 60;
      _run(engine, braking, const RaceInputs(brake: true), 1);

      expect(coasting.player.speed, lessThan(60));
      expect(braking.player.speed, lessThan(coasting.player.speed));
      expect(braking.player.speed, greaterThanOrEqualTo(0));
    });
  });

  group('cornering', () {
    const corner = TrackSection.corner(
      length: 100,
      direction: CornerDirection.left,
      safeSpeed: 40,
      wallThreshold: 14,
      bend: 24,
    );

    test('a straight adds no drift — the car only moves when steered', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(2000)]);
      final car = field.player..speed = 60;
      _run(engine, field, const RaceInputs(throttle: true), 1.0);
      expect(car.lateral.abs(), lessThan(0.001));
      expect(car.spinning, isFalse);
    });

    test('a corner runs the car wide unless the player steers into it', () {
      final engine = GrandPrixEngine(random: Random(1));

      RaceField drive(RaceInputs inputs) {
        final field = _soloField(const [TrackSection.straight(50), corner]);
        field.player
          ..speed = 45
          ..distance = 49;
        _run(engine, field, inputs, 1.2);
        return field;
      }

      // No steer: the car keeps a straight heading and drifts to the OUTSIDE of
      // the (left) corner — positive lateral.
      final drifting = drive(const RaceInputs(throttle: true));
      expect(drifting.player.lateral, greaterThan(1.0));

      // Steering into the bend (left) follows the road — ends up on the inside,
      // nowhere near the outside drift.
      final steering = drive(const RaceInputs(throttle: true, steer: -0.5));
      expect(steering.player.lateral, lessThan(0));
      expect(steering.player.lateral, lessThan(drifting.player.lateral));
    });

    test('overspeed scrubs speed, and the hotter entry sheds more', () {
      final engine = GrandPrixEngine(random: Random(1));

      double scrubLoss(double speed) {
        final field = _soloField(const [TrackSection.straight(50), corner]);
        field.player
          ..speed = speed
          ..distance = 49;
        _run(engine, field, const RaceInputs(), 0.4);
        return speed - field.player.speed;
      }

      final mildLoss = scrubLoss(46); // +6 over
      final hotLoss = scrubLoss(52); // +12 over
      expect(hotLoss, greaterThan(kCoast * 0.4)); // more than coasting alone
      expect(hotLoss, greaterThan(mildLoss)); // worse when faster
    });

    test('a mid-corner wall hit is the only thing that hard-shakes the car', () {
      final engine = GrandPrixEngine(random: Random(1));
      // A long corner so there is room to slide out to the barrier. Outside of
      // a left corner is to the right (+lateral), so we steer hard right.
      const longCorner = TrackSection.corner(
        length: 600,
        direction: CornerDirection.left,
        safeSpeed: 40,
        wallThreshold: 14,
        bend: 24,
      );
      final field = _soloField(const [longCorner]);
      final car = field.player..speed = 60;
      const drivingIntoWall = RaceInputs(throttle: true, steer: 1);

      var sawWall = false;
      var spunWhileOnTrack = false;
      double? lateralAtSpin;
      for (var t = 0.0; t < 4 && lateralAtSpin == null; t += _dt) {
        // While still on the racing surface the car must never hard-shake.
        if (car.spinning && car.lateral.abs() < kTrackHalfWidth) {
          spunWhileOnTrack = true;
        }
        final events = engine.tick(field, drivingIntoWall, _dt);
        sawWall = sawWall || events.playerWallContact;
        if (car.spinning) lateralAtSpin = car.lateral.abs();
      }

      expect(car.spinning, isTrue, reason: 'slamming the wall spins the car');
      expect(sawWall, isTrue);
      expect(spunWhileOnTrack, isFalse);
      // The spin only fires at the wall — well past the red/white kerb line.
      expect(lateralAtSpin, isNotNull);
      expect(lateralAtSpin!, greaterThanOrEqualTo(kWallLateral - 0.001));
    });

    test('scraping the wall down a straight scrubs speed but never spins', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(3000)]);
      final car = field.player..speed = 70;
      const drivingIntoWall = RaceInputs(throttle: true, steer: 1);

      var sawWall = false;
      for (var t = 0.0; t < 2; t += _dt) {
        final events = engine.tick(field, drivingIntoWall, _dt);
        sawWall = sawWall || events.playerWallContact;
        expect(car.spinning, isFalse); // straights never hard-shake
      }
      expect(sawWall, isTrue);
      expect(car.lateral.abs(), closeTo(kWallLateral, 0.001));
    });
  });

  group('stuck watchdog', () {
    test('staying stopped past the timeout ends the race (DNF)', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      field.player.speed = 0; // parked, and the player does nothing

      var stuckOut = false;
      for (var t = 0.0; t < kStuckTimeout + 1 && !stuckOut; t += _dt) {
        stuckOut = stuckOut || engine.tick(field, const RaceInputs(), _dt).playerStuckOut;
      }
      expect(stuckOut, isTrue);
      expect(field.playerStuckSeconds, greaterThanOrEqualTo(kStuckTimeout));
    });

    test('getting moving again resets the stuck clock', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(20000)]);
      field.player.speed = 0;

      // Stall a while — but under the timeout, so no DNF yet.
      _run(engine, field, const RaceInputs(), 5);
      expect(field.playerStuckSeconds, greaterThan(4));

      // Get back up to racing speed — the clock resets to zero.
      _run(engine, field, const RaceInputs(throttle: true), 3);
      expect(field.player.speed, greaterThan(kStuckSpeed));
      expect(field.playerStuckSeconds, 0);
    });

    test('normal racing speed never trips the watchdog', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(30000)]);
      field.player.speed = kTopSpeed;

      var stuckOut = false;
      for (var t = 0.0; t < kStuckTimeout + 2; t += _dt) {
        stuckOut = stuckOut || engine.tick(field, const RaceInputs(throttle: true), _dt).playerStuckOut;
      }
      expect(stuckOut, isFalse);
      expect(field.playerStuckSeconds, 0);
    });
  });

  group('slipstream', () {
    test('grants a tow on straights when aligned and in range', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(8000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'CPU',
          livery: GrandPrixLivery.papaya,
          distance: 15,
          lateral: 0,
        )..speed = kTopSpeed,
      );
      field.player.speed = kTopSpeed;
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.slipstreaming, isTrue);

      // Pull out of line — tow lost.
      field.player.lateral = 3;
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.slipstreaming, isFalse);

      // Too far back — tow lost.
      field.player.lateral = 0;
      field.cars[1].distance = field.player.distance + kSlipstreamMax + 10;
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.slipstreaming, isFalse);
    });

    test('tow lifts speed above solo top speed', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(20000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'CPU',
          livery: GrandPrixLivery.papaya,
          distance: 12,
          lateral: 0,
        )..speed = kTopSpeed,
      );
      field.player.speed = kTopSpeed;
      // Keep the leader pinned ahead so the tow persists.
      for (var t = 0.0; t < 3; t += _dt) {
        field.cars[1]
          ..distance = field.player.distance + 12
          ..speed = field.player.speed;
        engine.tick(field, const RaceInputs(throttle: true), _dt);
      }
      expect(field.player.speed, greaterThan(kTopSpeed + 1));
      expect(
        field.player.speed,
        lessThanOrEqualTo(kTopSpeed * (1 + kSlipstreamBoost) + 0.001),
      );
    });
  });

  group('contact', () {
    test('rear-ending slows both cars', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'CPU',
          livery: GrandPrixLivery.papaya,
          distance: 4,
          lateral: 0,
        )..speed = 50,
      );
      field.player.speed = 58;
      final events = engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(events.playerContact, isTrue);
      expect(field.player.speed, lessThan(58));
      expect(field.cars[1].speed, lessThan(50));
    });

    test('heavy closing speed spins the rear car', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'CPU',
          livery: GrandPrixLivery.papaya,
          distance: 4,
          lateral: 0,
        )..speed = 30,
      );
      field.player.speed = 30 + kHeavyContactClosingSpeed + 10;
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.spinning, isTrue);
    });
  });

  group('positions and overtakes', () {
    test('position counts cars ahead; finishers always rank first', () {
      final field = _soloField(const [TrackSection.straight(1000)]);
      final player = field.player..distance = 500;
      field.cars.addAll([
        CarState(
          index: 1,
          isPlayer: false,
          name: 'AHEAD',
          livery: GrandPrixLivery.papaya,
          distance: 700,
          lateral: 0,
        ),
        CarState(
          index: 2,
          isPlayer: false,
          name: 'BEHIND',
          livery: GrandPrixLivery.midnight,
          distance: 300,
          lateral: 0,
        ),
        CarState(
          index: 3,
          isPlayer: false,
          name: 'DONE',
          livery: GrandPrixLivery.skyBlue,
          distance: 1001,
          lateral: 0,
        )
          ..mode = CarMode.finished
          ..finishTimeMs = 60000,
      ]);
      expect(positionOf(field, player), 3); // behind AHEAD and DONE
      player.distance = 900;
      expect(positionOf(field, player), 2); // passed AHEAD, DONE still counts
    });

    test('passing a car emits an overtake event with its name', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(5000)]);
      field.cars.add(
        CarState(
          index: 1,
          isPlayer: false,
          name: 'TARGET',
          livery: GrandPrixLivery.papaya,
          distance: 3,
          lateral: 3.5, // offline so there is no contact
        )..speed = 10,
      );
      field.player.speed = 60;
      final seen = <String>[];
      for (var t = 0.0; t < 1; t += _dt) {
        final events = engine.tick(field, const RaceInputs(throttle: true), _dt);
        seen.addAll(events.overtakes.map((o) => o.overtakenName));
      }
      expect(seen, contains('TARGET'));
    });
  });

  group('launch grading', () {
    test('grades map to the spec reaction bands', () {
      expect(gradeLaunch(const Duration(milliseconds: 149)), LaunchGrade.perfect);
      expect(gradeLaunch(const Duration(milliseconds: 150)), LaunchGrade.great);
      expect(gradeLaunch(const Duration(milliseconds: 299)), LaunchGrade.great);
      expect(gradeLaunch(const Duration(milliseconds: 300)), LaunchGrade.good);
      expect(gradeLaunch(const Duration(milliseconds: 499)), LaunchGrade.good);
      expect(gradeLaunch(const Duration(milliseconds: 500)), LaunchGrade.slow);
    });

    test('better launches give strictly better boosts; jump start cuts throttle', () {
      final perfect = launchBoost(LaunchGrade.perfect);
      final great = launchBoost(LaunchGrade.great);
      final good = launchBoost(LaunchGrade.good);
      final slow = launchBoost(LaunchGrade.slow);
      expect(perfect.initialSpeed, greaterThan(great.initialSpeed));
      expect(great.initialSpeed, greaterThan(good.initialSpeed));
      expect(good.initialSpeed, greaterThan(slow.initialSpeed));
      expect(launchBoost(LaunchGrade.jump).initialSpeed, 0);

      final setup = _setup();
      final rng = Random(setup.seed);
      final field = buildField(setup, generateDriverNames(19, rng), rng);
      applyLaunch(field, LaunchGrade.jump, rng);
      expect(field.player.throttleCutTimer, kJumpStartCutSeconds);

      // Throttle does nothing while the jump-start cut is active.
      final engine = GrandPrixEngine(random: rng);
      engine.tick(field, const RaceInputs(throttle: true), _dt);
      expect(field.player.speed, 0);
    });

    test('cpu reactions improve with strength and never jump', () {
      final rng = Random(3);
      for (var i = 0; i < 200; i++) {
        final weak = sampleCpuReaction(0.1, rng);
        expect(weak.inMilliseconds, greaterThan(0));
      }
      final strongAvg =
          List.generate(300, (_) => sampleCpuReaction(1.0, rng).inMilliseconds)
                  .reduce((a, b) => a + b) /
              300;
      final weakAvg =
          List.generate(300, (_) => sampleCpuReaction(0.0, rng).inMilliseconds)
                  .reduce((a, b) => a + b) /
              300;
      expect(strongAvg, lessThan(weakAvg));
    });
  });

  group('field generation', () {
    test('20 cars, unique names, player at the chosen slot', () {
      final setup = _setup(startPosition: 12);
      final rng = Random(setup.seed);
      final field = buildField(setup, generateDriverNames(19, rng), rng);
      expect(field.cars.length, kFieldSize);
      expect(field.cars.where((c) => c.isPlayer).length, 1);
      expect(positionOf(field, field.player), 12);
      final names = field.cars.map((c) => c.name).toSet();
      expect(names.length, kFieldSize);
      // No CPU wears the player's livery.
      expect(
        field.cars
            .where((c) => !c.isPlayer && c.livery == GrandPrixLivery.scarlet),
        isEmpty,
      );
    });

    test('stronger fields finish faster (CPU pace scales with level)', () {
      double cpuAverageFinish(int level) {
        final setup = _setup(playerLevel: level, seed: 11);
        final rng = Random(setup.seed);
        final field = buildField(setup, generateDriverNames(19, rng), rng);
        applyLaunch(field, LaunchGrade.slow, rng);
        final engine = GrandPrixEngine(random: Random(5));
        // Player never throttles — only the CPU field races.
        const raceDt = 1 / 60;
        for (var t = 0.0; t < 240; t += raceDt) {
          engine.tick(field, const RaceInputs(), raceDt);
          if (field.cars.where((c) => !c.isPlayer).every((c) => c.finished)) {
            break;
          }
        }
        final cpus = field.cars.where((c) => !c.isPlayer).toList();
        expect(cpus.every((c) => c.finished), isTrue);
        return cpus.map((c) => c.finishTimeMs).reduce((a, b) => a + b) /
            cpus.length;
      }

      expect(cpuAverageFinish(12), lessThan(cpuAverageFinish(1)));
    });
  });

  group('multi-lap races', () {
    test('raceCenterlineX is continuous across the start/finish line', () {
      final circuit = grandPrixCircuit(GrandPrixCircuitId.emeraldPark);
      final starts = RaceField(circuit: circuit, cars: []).sectionStarts;
      final lapLength = circuit.lapLength;

      final before = raceCenterlineX(circuit, starts, lapLength - 0.01);
      final at = raceCenterlineX(circuit, starts, lapLength);
      final after = raceCenterlineX(circuit, starts, lapLength + 0.01);
      expect((at - before).abs(), lessThan(0.01));
      expect((after - at).abs(), lessThan(0.01));

      // Lap 2 repeats lap 1's shape, offset by the full-lap shift.
      final fullLapShift = centerlineX(circuit, starts, lapLength);
      expect(
        raceCenterlineX(circuit, starts, lapLength + 500),
        closeTo(fullLapShift + centerlineX(circuit, starts, 500), 1e-9),
      );
    });

    test('the finish only comes after every lap is run', () {
      final engine = GrandPrixEngine(random: Random(1));
      final field = _soloField(const [TrackSection.straight(1000)], laps: 3);
      final car = field.player..speed = kTopSpeed;

      var crossed = false;
      for (var t = 0.0; t < 60 && !crossed; t += _dt) {
        crossed = engine
            .tick(field, const RaceInputs(throttle: true), _dt)
            .playerCrossedLine;
        if (car.distance > 1000 && car.distance < 2900) {
          expect(car.finished, isFalse,
              reason: 'crossing an intermediate lap line must not finish');
        }
      }
      expect(crossed, isTrue);
      expect(car.distance, greaterThanOrEqualTo(field.raceLength));
    });

    test('a seeded 20-car 3-lap race completes with no NaNs', () {
      final setup = _setup(seed: 9, laps: 3);
      final rng = Random(setup.seed);
      final field = buildField(setup, generateDriverNames(19, rng), rng);
      applyLaunch(field, LaunchGrade.good, rng);
      final engine = GrandPrixEngine(random: Random(setup.seed));
      const raceDt = 1 / 60;
      for (var t = 0.0; t < 900; t += raceDt) {
        engine.tick(field, _manualInputs(field), raceDt);
        for (final car in field.cars) {
          if (car.speed.isNaN || car.distance.isNaN || car.lateral.isNaN) {
            fail('NaN state for ${car.name} at t=$t');
          }
          if (car.lateral.abs() > kWallLateral + 0.001) {
            fail('${car.name} escaped the wall at t=$t');
          }
        }
        if (field.cars.every((c) => c.finished)) break;
      }
      // Every car finishing proves the CPU brake lookahead wraps the lap
      // line — a hot turn-1 entry on laps 2/3 would strand cars on the grass.
      expect(field.cars.every((c) => c.finished), isTrue);
      for (final car in field.cars) {
        expect(car.distance, greaterThanOrEqualTo(field.raceLength));
      }
    });
  });

  group('full-race soak', () {
    test('a seeded 20-car race completes deterministically with no NaNs', () {
      List<String> classification(int seed) {
        final setup = _setup(seed: seed, circuit: GrandPrixCircuitId.emeraldPark);
        final rng = Random(setup.seed);
        final field = buildField(setup, generateDriverNames(19, rng), rng);
        applyLaunch(field, LaunchGrade.good, rng);
        final engine = GrandPrixEngine(random: Random(setup.seed));
        // Lightweight manual driver for the soak: follows the racing line and
        // brakes when already above the current section's safe speed.
        const raceDt = 1 / 60;
        for (var t = 0.0; t < 300; t += raceDt) {
          engine.tick(field, _manualInputs(field), raceDt);
          for (final car in field.cars) {
            // Plain checks (not expect) — this loop runs tens of thousands
            // of times; fail loudly only when an invariant actually breaks.
            if (car.speed.isNaN || car.distance.isNaN || car.lateral.isNaN) {
              fail('NaN state for ${car.name} at t=$t');
            }
            if (car.lateral.abs() > kWallLateral + 0.001) {
              fail('${car.name} escaped the wall at t=$t');
            }
          }
          if (field.cars.every((c) => c.finished)) break;
        }
        expect(field.cars.every((c) => c.finished), isTrue);
        final ordered = [...field.cars]
          ..sort((a, b) => a.finishTimeMs.compareTo(b.finishTimeMs));
        return ordered.map((c) => c.name).toList();
      }

      final first = classification(21);
      final second = classification(21);
      expect(first, second); // same seed → same result
      expect(first.toSet().length, kFieldSize);
    });
  });
}
```
