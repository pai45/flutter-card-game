# Final Over (Cricket) — Implementation & Porting Reference

> **Status:** BUILT · **Written:** 2026-09-16 · **Audience:** Flutter engineers rebuilding this game in another project
>
> **Source of truth:** the local rules package `final_over/` (domain +
> application) and the host renderer `lib/games/final_over/`, plus the files
> listed in §3. Appendix P and Appendix A–B are copied **verbatim** from the
> source repo by script. The one exception is the package barrel `final_over.dart`,
> whose final export of the package's own standalone UI is removed (§4.1).
> Appendix C is the source repo's host screen, for reference only.
> Appendix D contains the stand-ins you need so everything compiles on its own.
>
> **This document is self-contained.** Recreate the `final_over` package from
> Appendix P, copy Appendix A, B and D into the app at the same relative
> paths, add the §4 dependencies, and the game compiles and both test suites
> (Appendix E) pass. That exact check was run against this document (see §12).

---

## 1. What the game is

Final Over is a **timing-driven cricket run chase**. You bat; the CPU bowls
and fields.

| Rule | Value |
|---|---|
| Format | Up to **18 legal balls** (3 overs × 6). Each over has a different bowler (VOLT pace / EDGE seam / DRIFT spin, shuffled per match) |
| Target | Seeded from the ladder 32…66. The tier picks the rungs (§5.8) |
| Batting | Tap or swipe **anywhere on the pitch**. Release timing against the ball's arrival grades the shot. Swipe direction places it (left = off side, up = straight, right = leg side, down = behind), and an upward swipe or a fast flick **lofts** it |
| Outcomes | Boundary (4 along the ground, 6 on the full from a loft), caught, bowled, run out, dropped catch, or fielded |
| Running | After contact you choose **RUN / RUN AGAIN** (up to 3), **HOLD**, or **TURN BACK** (before 45 % of the run). A live risk light (SAFE / CLOSE / DANGER) shows the throw race |
| Extras | Wides (5 max) and no-balls (3 max) add 1 run and do not use a legal ball. A no-ball makes the next ball a **FREE HIT** (no caught or bowled) |
| OVERDRIVE | Scoring contacts charge a segmented meter. When full, tap to arm: the next swing gets ×1.18 power and +0.08 control |
| Objective | One per match: hit 2 boundaries, score 6 in the first 3 legal balls, or complete a double |
| End | Target reached (win, 1–3 ★) · balls exhausted · wickets lost (tier-dependent: 4 / 3 / 2) |

Two camera views cross-fade:

- **Batting view:** the incoming ball, drawn in perspective behind the bowler.
- **Field view:** a top-down oval with fielders, the ball, the runner and the
  throw.

## 2. Architecture

```
FinalOverMatchScreen (Appendix C)          ← phases, overlays, sound/haptics, XP, lifecycle
 ├─ FinalOverCubit (A)                     ← tier/kit picks, match config, coarse phases, career stats
 ├─ MatchController  (package, P)          ← THE ONLY GAMEPLAY AUTHORITY. Fixed 60 Hz, seeded, immutable MatchState
 │    └─ domain: DeliveryGenerator, ContactResolver, PhysicsResolver, FieldingResolver, ScoringResolver, GameplayTuning
 ├─ GameWidget(FinalOverGame) (A)          ← Flame projection: steps the controller, paints both cameras, notifiers, stings
 │    └─ final_over_rig.dart (A) + games/rig/athlete_rig.dart (A) ← code-drawn batter/bowler/umpire/fielders
 └─ SwingSurface / Controls / HUD / Overlays (B)
```

Hard rules:

1. **`MatchController` decides every run, wicket and score.** The Flame game
   only calls `controller.step(elapsed)`, sends `GameCommand`s and draws the
   immutable `MatchState`. If you find yourself adding a rule to the
   renderer, it belongs in the package.
2. **The package is pure Dart.** Domain and application have no Flutter or
   Flame imports. (`contact_ball_flight.dart` imports only
   `flutter/widgets.dart` for `Offset`.) The controller uses a fixed
   16,667 µs step, with frames capped at 250 ms.
3. **Seed streams.** `SeedStreams.forStream(matchSeed, deliveryOrdinal,
   RandomStream.x)` gives every random decision its own deterministic stream,
   so the same seed replays the same match for the same inputs. The streams
   are:
   - `objective`
   - `delivery`
   - `contact`
   - `catchOutcome`
   - `drop`
   - `throwOutcome`
4. **HUD values are `ValueNotifier`s on `FinalOverGame`:**
   - score and state: score, wickets, balls left, runs needed, target, over,
     bowler, next batter, combo, history
   - OVERDRIVE: power segments, power armed
   - shot state: free hit, elevation, direction, phase, prep seconds
   - input windows: `canConfigureShot`, `canSwing`, `canRun`,
     `canTurnBack`
   - running: risk, run progress, completed runs, successful contact
   - sting

   The cubit hears only the match end.
5. **Tuning split.** `GameplayTuning` (package) is the only thing that
   changes outcomes. `final_over_tuning.dart` (host) is presentation only:
   shake, zoom, sting and crowd timings.

## 3. File map

| Target path | Role | Where |
|---|---|---|
| `final_over/pubspec.yaml` | Trimmed package manifest (§4.1) | §4.1 |
| `final_over/lib/final_over.dart` | Package barrel (trimmed) | P.1 |
| `final_over/lib/domain/domain.dart` | Domain barrel | P.2 |
| `final_over/lib/domain/models.dart` | Phases, enums, `BowlerProfile`, `FieldVector`, `DeliverySpec`, `SwingIntent`, `ContactOutcome`, `BallKinematics`, `RunnerState`, `FielderState`, `FieldLayout`, `DeliveryLedger`, `BallResult`, `MatchState` | P.3 |
| `final_over/lib/domain/gameplay_tuning.dart` | All gameplay numbers, the rookie/pro/elite presets, target ladder, line offsets, 5 field layouts | P.4 |
| `final_over/lib/domain/deterministic_random.dart` | `DeterministicRandom`, `SeedStreams`, `RandomStream` | P.5 |
| `final_over/lib/domain/delivery_generator.dart` | Seeded delivery (line, length, pace, movement, extras, fair final ball) | P.6 |
| `final_over/lib/domain/resolvers.dart` | Timing, contact, physics, fielding and scoring resolvers | P.7 |
| `final_over/lib/application/application.dart` | Application barrel | P.8 |
| `final_over/lib/application/game_command.dart` | Sealed `GameCommand`s | P.9 |
| `final_over/lib/application/gameplay_event.dart` | `GameplayEventType`, `GameplayEvent` | P.10 |
| `final_over/lib/application/match_controller.dart` | The state machine | P.11 |
| `final_over/lib/game/contact_ball_flight.dart` | Render helper for the post-contact ball flight | P.12 |
| `lib/games/final_over/final_over_tuning.dart` | Presentation beats | A.1 |
| `lib/games/final_over/final_over_game.dart` | `FlameGame` projection: projection maths, input API, notifiers, stings, stadium, both cameras, effects | A.2 |
| `lib/games/final_over/final_over_rig.dart` | Batter/bowler/umpire/fielder poses and draw passes | A.3 |
| `lib/games/rig/athlete_rig.dart` | Shared stroke-rig primitives | A.4 |
| `lib/models/final_over.dart` | `FinalOverTier` (targets, XP multiplier, tuning), config, summary + grade, `FinalOverStats`, `calculateFinalOverXp` | A.5 |
| `lib/data/final_over_kits.dart` | 8 team kits, ownership, opponent kit, per-actor looks/numbers | A.6 |
| `lib/data/random_opponent_names.dart` | Cosmetic rival names | A.7 |
| `lib/blocs/final_over/final_over_state.dart` | `FinalOverPhase` + state | A.8 |
| `lib/blocs/final_over/final_over_cubit.dart` | Session | A.9 |
| `lib/screens/final_over/widgets/final_over_swing_surface.dart` | Whole-pitch tap/swipe batting surface + `classifyBattingGesture` | B.1 |
| `lib/screens/final_over/widgets/final_over_controls.dart` | Batting status strip (with rookie recommendation) / running deck (RUN · HOLD · TURN BACK) | B.2 |
| `lib/screens/final_over/widgets/final_over_hud.dart` | HUD bar (over chip, bowler, score, chase cluster, ball strip), OVERDRIVE rail, sting layer, `FinalOverGameScope` | B.3 |
| `lib/screens/final_over/widgets/final_over_overlays.dart` | Bowler-reveal and pause overlays | B.4 |
| `lib/screens/final_over/final_over_match_screen.dart` | Host screen (**reference**) | C.1 |
| `lib/screens/final_over/widgets/final_over_result.dart` | Result cinematic (**reference**) | C.2 |
| `lib/config/theme.dart` | **Stand-in** tokens | D.1 |
| `lib/services/secure_storage_service.dart` | **Stand-in**: stats persistence (verbatim methods) | D.2 |
| `lib/utils/sound_effects.dart` | **Stand-in**: `SoundEffect` + `playSound` | D.3 |
| `lib/widgets/cyber/cyber_widgets.dart` | **Subset** of shared HUD widgets (verbatim classes) | D.4 |
| `lib/widgets/cyber/cyber_cta_button.dart` | `HudCtaButton` (verbatim) | D.5 |
| `test/final_over_balance_test.dart` + `final_over/test/**` | Acceptance suites | E |

Not ported: the Final Over hub (tier tiles, career record), the kit picker
and kit shop, the batting deck builder, the cricket starter-pack/card economy,
matchmaking (`GameMatchGate`), the global `GameBloc`, the audio controller,
and the package's own standalone app (`presentation/`, `services/`,
`game/final_over_game.dart`, `game/visuals/`, audio, font and background
assets), which the host app does not use.

The hub now has its own port doc,
[final-over-hub-port.md](final-over-hub-port.md), built on top of this one.

## 4. Dependencies

### 4.1 The package (`final_over/`)

```yaml
name: final_over
description: "Final Over rules engine (trimmed: domain + application + contact flight)."
publish_to: none
version: 1.0.0+1

environment:
  sdk: ^3.11.5

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
```

The source package also lists `flame`, `audioplayers` and
`shared_preferences`, plus audio/font/background assets. Those serve only its
standalone presentation layer, so the trimmed package drops them. For the
same reason, its barrel (P.1) drops the source's last line:

```dart
/// The package's own arcade presentation. Only the standalone build uses this;
/// the host app ships its own screens.
export 'presentation/final_over_game_screen.dart' show FinalOverGameScreen;
```

### 4.2 The app

```yaml
environment:
  sdk: ^3.12.2
dependencies:
  flutter: { sdk: flutter }
  flame: ^1.18.0              # verified against 1.38.0
  flutter_bloc: ^9.1.1
  shared_preferences: ^2.5.3  # storage stand-in
  final_over:
    path: final_over
dev_dependencies:
  flutter_test: { sdk: flutter }
flutter:
  fonts:               # add `fonts: - asset:` entries pointing at your font files
    - family: Orbitron
    - family: Onest
```

No image or audio assets are required; the stadium, crowd, pitch and players
are all procedural. **Rename `package:card_game/` in
`final_over_balance_test.dart` to your package name.**

## 5. Rules reference (package)

### 5.1 Phase machine (`MatchPhase`)

```
idle → matchIntro ─StartCommand→ deliveryPreparation (3.0 s; shot can be configured, OVERDRIVE armed)
  → bowlerRunUp (0.9 s) → incomingBall (contact due 0.65 s after release)
  → contact (0.45 s hold) → cameraTransition (0.36 s) → fieldPlay ⇄ runDecision ⇄ runnersMoving ⇄ throwInProgress
  → deliveryResult (0.65 s) → betweenBalls (0.45 s) → next deliveryPreparation
terminal: won | lost | quit      pause: paused (resumes to suspendedPhase)
```

- **Field layout:** the layout rotates every physical delivery through 5
  shapes (BALANCED, OFF GUARD, LEG GUARD, STRAIGHT WALL, CLOSE ATTACK),
  starting from `seed % 5`.
- **Missed swing:** a miss or no swing skips field play and finalises
  straight away.

### 5.2 Delivery (`DeliveryGenerator`)

**Extras:** from delivery 2 onward, a no-ball (2 %, max 3) takes precedence
over a wide (5 %, max 5).

**Line and length** use the bowler's weights:

| Bowler | Line (off / middle / leg) | Length (yorker / full / good / short) |
|---|---|---|
| VOLT (pace) | 34 / 28 / 24 | 28 / 30 / 26 / 16 |
| EDGE (seam) | 28 / 36 / 22 | 18 / 26 / 36 / 20 |
| DRIFT (spin) | 22 / 30 / 34 | 12 / 30 / 28 / 30 |

Lateral line offsets are wideOff −0.11, off −0.035, middle 0, leg +0.035 and
wideLeg +0.11.

- **Anti-repeat:** a third consecutive yorker or short ball is swapped to
  full or good.
- **Pace and movement:** speed is 0.82–1.08 (×0.95 on the first ball), with
  movement of ±0.012.
- **Fair final ball:** on the last legal ball, when ≤ 6 runs are needed,
  there are no extras, the line is off/middle/leg, the length is full or
  good, and speed and movement are gentle.

### 5.3 Timing and contact (`TimingResolver`, `ContactResolver`)

**Swing input:** a swing is `SwingCommand(direction, elevation:)` at release
time. The error is `release − expectedContact` in ms (negative = early). No
swing by `contact + lateSwingGrace` is a MISS.

| Grade | Rookie | Pro | Elite (= defaults) |
|---|---|---|---|
| PERFECT ≤ | 80 ms | 65 | 50 |
| GOOD ≤ | 180 | 150 | 115 |
| EARLY / LATE ≤ | 300 | 245 | 190 |
| POOR ≤ | 400 | 330 | 275 |
| late-swing grace | 401 ms | 331 | 276 |

**Miss and bowled:**

- The contact is a miss if the grade is a miss or the ball is out of reach
  (`|contactX| > batterReach` — 0.100 / 0.092 / 0.085).
- A miss on a straight ball (`|x| ≤ 0.028`, not wide, not short) is
  **BOWLED**, unless it is a free hit or a no-ball.

**Technique** (`compatibility`) starts at 0.50:

- line match: +0.18/+0.20; mismatch: −0.08
- yorker + ground +0.10 · yorker + loft −0.08
- full + ground +0.08 · full + loft +0.04
- good length +0.08
- short + loft +0.12 · short + ground −0.08

**Profile by grade:**

| Grade | Power | Control |
|---|---|---|
| perfect | 1.0 | 1.0 |
| good | .90 | .88 |
| early / late | .74 | .66 |
| poor | .48 | .38 |

**Control and edges:**

```
control = profile.control·(0.65 + 0.55·technique) (+0.08 OVERDRIVE) · (1 − overswingPenalty·overswing)
edge    = {perfect .015, good .06, early/late .22, poor .44} + (1−technique)·0.12 (+overswing bonus), max 0.75
```

**Power:**

```
power = profile.power·(0.80 + 0.42·technique)·U(0.94,1.06)·backlift(charge)
        (×1.18 OVERDRIVE) (×U(.35,.65) if edged), clamp .12–1.20
```

**Shot angle:**

- nominal: off −45°, straight 0°, leg +45°, behind 180°
- early +(7 + 8·(1−control)); late −(7 + 8·(1−control))
- random spread ±16·(1−control) (±28 on poor)
- edges add ±18

**Speed:**

- ground: `0.36 + 0.64·power`
- loft: `0.42 + 0.59·power`, vertical `0.55 + 0.45·power`
- values shown are the elite defaults; rookie and pro are faster (P.4)

The shipped swing surface sends no `charge`, so backlift power = 1 and the
shot is judged on timing and technique.

### 5.4 Ball, fielding, catches, boundaries (`PhysicsResolver`, `FieldingResolver`)

**Field and ball:**

- The field is a unit circle; the boundary is at radius 1.
- Gravity is 1.65. A lofted ball keeps 54 % of its speed on landing.
- A ground ball loses 0.52/s and stops below 0.015.
- **Boundary:** radius ≥ 1 → **6** if lofted and not yet bounced, else **4**.
  A boundary beats a pickup on an exact tie.

**Chasers:**

- The two fielders with the best `reaction + distance/fielderSpeed` to the
  ball's predicted spot 2 s ahead chase it. The backup runs at ×0.65 toward
  a point 72 % of the way to the ball.
- Reaction times: keeper 0.14, close 0.24, deep 0.33 s (elite).

**Catch:**

- **Eligible:** the ball is aerial and within 0.06 of the primary chaser.
- **Chance:**
  - base: 0.82, or 0.88 for the keeper (elite)
  - running −0.12
  - hard hit (> 0.85) −0.12
  - edge +0.06
  - arrived early +0.08
  - clamped to 0.25–0.95
- **Taken:** CAUGHT, unless it is a free hit or no-ball, in which case the
  ball is just picked up.
- **Dropped:** the ball keeps 35–60 % of its speed along the ground.

**Pickup:** a ground ball within 0.045. The batter then has 0.5 s to decide
before the delivery auto-finalises.

### 5.5 Running and run-outs

- **Timing:** each run takes 1.20 s, up to 3 runs.
- **RUN window:** RUN becomes available once the camera transition is 70 %
  done.
- **HOLD:** before pickup, HOLD lets a possible boundary finish.
- **TURN BACK:** allowed while `progress ≤ 0.45`.
- **Throw:** once the ball is held and a run is live, the holder throws to
  the end the runner is heading for (±0.21). Arrival time is
  `distance/throwSpeed + 0.10 s`.
- **Run-out:** the throw arrives *strictly before* the runner reaches the
  crease. An exact tie is safe.
- **Risk light:** compares the estimated throw arrival with crease arrival:
  - margin > 0.22 s → SAFE
  - margin < −0.15 s → DANGER
  - otherwise CLOSE

  Before pickup, the estimate projects the moving ball 1 s ahead.

### 5.6 Scoring, combo, OVERDRIVE, stars (`ScoringResolver`)

- **Combo** (1–3):
  - +1 on productive contact
  - reset to 1 on a wicket or a zero-run contact
  - unchanged on a no-contact extra
- **OVERDRIVE charge per scoring contact:** `base (six 3, four 2, else 1) +
  (combo − 1)`, capped at the requirement (rookie 4 / pro 5 / elite 8).
  Arming uses it all.
- **Objective thresholds:** 2 boundaries · 6 runs in the first 3 legal
  balls · one completed double.
- **Stars on a win:** 1, then +1 if the objective is done, then +1 for ≥ 2
  balls to spare *or* 0 wickets lost.
- **History tokens:** each ball renders as e.g. `4`, `6`, `0`, `WD`,
  `NB+1`, `2+RUN OUT`.
- **Over complete:** every 6th legal ball, `overComplete` fires (bowler
  rotates, and the host shows a bowler reveal).

### 5.7 Host projection (`FinalOverGame`, A.2)

**Input API:**

- `start()`
- `beginSwing()` — renders the backlift only
- `releaseSwing(direction:, elevation:)`
- `cancelSwing()`
- `activatePowerShot()`
- `startRun()`, `holdBall()`, `turnBack()`
- `pause()`, `resume()`, `backgrounded()`
- `selectElevation` / `selectDirection` — pre-set shot, still supported

**Update loop:** clamp `dt` to 1/30, then `controller.step(Duration)`. After
that, sync the notifiers, capture the ball trail, advance the bowler run
cycle, and clear stings on time.

**Render:**

- `cameraTransition` cross-fades the batting view (ease-in out) into the
  field view (ease-out in).
- Shake and focal zoom are applied unless reduced motion is on.
- The last legal ball adds a vignette (0.62).

`FinalOverBattingProjection` is the single perspective used for pitch, ball
and bounce marker. The bounce point is at 42 / 56 / 70 / 82 % of the incoming
path for short / good / full / yorker.

### 5.8 Tiers, grade and XP (A.5)

| Tier | Targets | Wickets | OVERDRIVE cost | Catch (outfield / keeper) | XP × |
|---|---|---|---|---|---|
| ROOKIE | 32, 36, 40 | 4 | 4 | .58 / .68 | 0.8 |
| PRO | 44, 48, 52, 56 | 3 | 5 | .68 / .76 | 1.0 |
| ELITE | 58, 62, 66 | 2 | 8 | .82 / .88 | 1.35 |

**Grade:**

- **Loss:** C with ≥ 2★, otherwise D.
- **Win:** S with 3★ and ≥ 2 balls to spare · A with 3★ · B with 2★ · C
  otherwise.

**XP** (`calculateFinalOverXp`):

```
xp = (won ? 30 : 10) + runs + 8·stars + (objective ? 15)
   + (won ? 4·ballsToSpare) + (won && wickets == 0 ? 10)
xp = round(xp × tier multiplier)        // XP only, no coins
```

## 6. Controls → commands

| Surface | Gesture | Game call |
|---|---|---|
| Swing surface (B.1), live only while `canSwing` (`IgnorePointer` otherwise) | pointer down | `beginSwing()` (backlift coil; the renderer ramps it over 300 ms) |
| | pointer up | `releaseSwing(direction, elevation)` from `classifyBattingGesture` + light haptic |
| | cancel | `cancelSwing()` |
| OVERDRIVE rail (B.3), during delivery preparation | tap when READY | `activatePowerShot()` + medium haptic |
| Running deck (B.2), while running or `canRun` | RUN / RUN AGAIN | `startRun()` (glows only when risk ≠ SAFE) |
| | HOLD / TURN BACK | `holdBall()`, or `turnBack()` when `canTurnBack` |

`classifyBattingGesture(delta, velocity)`:

- **Tap:** travel under 24 px → tap (straight, ground).
- **Direction:** otherwise the dominant axis decides — left = offSide,
  right = legSide, up = straight, down = behind.
- **Loft:** a straight swipe rising more than 26 px, or any flick at
  ≥ 900 px/s.

A live aim arrow and a label (`FRONT · LOFT`) follow the finger; loft is
tinted violet. With `rookieAssist`, the status strip recommends a direction
from the delivery line and an elevation from its length.

## 7. Session flow and the host contract

`FinalOverPhase`: `idle → intro → playing → finished → result`.

1. **Lobby:**
   - `cubit.load()`, then `selectTier(t)` and `selectKit(id,
     ownedKitIds:)`.
   - `config = cubit.buildMatch(batsmanIds: [...3 ids])`. This produces the
     seed, a target from the tier ladder, the kit, the batsmen, a rival name
     and `showHints` (first chase only). It enters `intro`.
2. **Screen `initState`:**
   - `controller = MatchController(tuning: config.tier.tuning)`
   - `game = FinalOverGame(controller:, kit: finalOverKitById(kitId),
     opponentKit: finalOverOpponentKit(kitId), batsmanIds:, onEvents:,
     reducedMotion:)`
   - `controller.startMatch(seed:, target:)` — this parks the match in
     `matchIntro`
   - observe the app lifecycle
3. **When the intro finishes:** `cubit.beginPlay()`,
   `cubit.markHintsSeen()`, then `game.start()`.
4. **`onEvents(GameplayEvent)`:**
   - Play the sound and haptics in §8.
   - Tally sixes, fours and best combo from `state.lastResult` on
     `deliveryCompleted`.
   - Show the bowler reveal for **1600 ms** on `overComplete`.
   - Run `_onMatchEnded()` on `matchEnded`.
5. **`_onMatchEnded()`** (once):
   - Compute XP from the final `MatchState`.
   - Build `FinalOverMatchSummary` and call `cubit.onMatchEnded(summary)`
     (merges and persists stats).
   - Dispatch the XP.
   - Play the victory/defeat cue and a heavy haptic.
   - After **900 ms**, `cubit.showResult()`.
6. **Pause / background:**
   - Backgrounding (any state other than `resumed`) calls
     `game.backgrounded()` and shows the pause overlay.
   - Resume with `game.resume()`.
7. **Dispose:**
   - Always call `controller.dispose()`.
   - If still in intro/playing **and** this screen's match is still the
     cubit's current match, call `cubit.abandonMatch()` (no stats, no XP).
   - CHASE AGAIN builds the next config *before* replacing the route, which
     is why the check compares `matchId`.
8. **Layout:**
   - Measure the bottom control deck and call
     `game.setBattingControlDeckTop(y)`, so the perspective pitch never
     sits under the controls.
   - Stack order: `GameWidget` → swing surface → HUD bar → sting layer →
     OVERDRIVE rail + controls → overlays.

## 8. Feedback map

| Event | Visual (A.2 / B) | Sound (`finalOverSoundForEvent`) | Haptic |
|---|---|---|---|
| deliveryPrepared | new delivery staged | cricketFootstep | — |
| fieldLayoutChanged (every delivery after the first) | `FIELD SHIFT · LABEL` sting (cyan) | — | — |
| ballReleased | bowler run-up and delivery | cricketRelease | — |
| contactResolved | impact effect; PERFECT sting (lime) | perfect → cricketPerfect · good → cricketGreat · early/late → cricketGood · poor → cricketEdge · miss → cricketKeeper | perfect medium · good selection |
| cameraTransitionStarted | batting → field cross-fade | cricketRoll | — |
| boundary | SIX (gold, major) / FOUR (cyan, major), boundary pulse, crowd to full | cricketSix / cricketBoundary | heavy |
| wicket | OUT (danger, major), wicket burst, crowd 0.85 | cricketStumps | heavy |
| runOut | RUN OUT (danger, major), focal zoom | cricketRunOut | heavy |
| catchTaken / catchDropped | effect; DROPPED (lime) | cricketCatch / cricketDrop | heavy / — |
| powerShotActivated | POWER SHOT (magenta, major) | cricketPower | medium |
| extraAwarded | `NO BALL · FREE HIT` or `WIDE` (amber) | cricketExtra | — |
| runStarted / runnerTurnedBack / runCompleted | run bar; completed run gets a focal zoom | cricketRun / cricketRun / uiConfirm | — / — / selection |
| ballPickedUp / throwStarted | fielder carry / throw | cricketKeeper / cricketThrow | — |
| deliveryCompleted | ball-strip token | cricketCrowdPressure when 1 ball is left | — |
| overComplete | bowler reveal overlay | bannerSlam | medium |
| last legal ball | edge vignette | — | — |
| matchEnded | result cinematic after 900 ms | cricketVictory / cricketDefeat | heavy |

**Sting and effect timing:**

- Major stings hold 1.5 s; minor stings 1.0 s.
- Shake lasts 0.32 s (5 px on contact, 8 on a wicket).
- The focal zoom is 0.055 over 0.55 s.
- Effects live 1.1 s.
- Crowd hype idles at 0.22 and settles over 2.2 s.

## 9. Host touch-points in the reference screen (Appendix C)

| Source symbol | Replace with |
|---|---|
| `GameBloc` / `FinalOverFinished(...)` | Your XP and history service |
| `AudioController` scenes and `setSceneMusicEnabled` | Your music player |
| `finalOverSoundForEvent`, `SoundEffect.cricket*`, `bannerSlam`, `uiConfirm` | Your cues (§8) |
| `GameMatchGate` / `GameMatchmakingConfig`, avatar models | Your intro, or remove |
| `showCyberConfirmDialog` | Any confirm dialog |
| `LevelUpCelebration`, progression read-outs in C.2 | Your level-up UI |

## 10. Design rules carried by this code

- **Glow:** in the deck, only the RUN plate glows, and only when the risk
  is real. Everything else is a calm plate with an accent fill. The
  renderer's lamps are the only other thing allowed to bloom.
- **Colour:** everything comes from `Cyber` tokens, except kit and look
  colours (A.6).
- **Tuning separation:** changing any presentation constant must not change
  a single run scored.

## 11. Port checklist

1. Create the `final_over/` package from §4.1 and Appendix P. Add it as a
   path dependency.
2. Copy A, B and D into the app.
3. Build a hub that calls `selectTier`, `selectKit` and `buildMatch`
   (batsman ids — any stable strings; they seed the batters' looks and
   numbers). The source hub passes the full 5-batter squad; see
   [final-over-hub-port.md](final-over-hub-port.md) for the lobby itself.
4. Port C.1 and C.2, applying §9. Keep `setBattingControlDeckTop` and the
   lifecycle pause.
5. Wire the §8 cues.
6. Copy Appendix E:
   - package tests → `final_over/test/…`
   - the app test → `test/`, with the package import renamed
7. Run `flutter test` in both the package and the app.
8. On device, verify:
   - early / perfect / late taps
   - swipes to all four directions
   - lofts and sixes
   - a dropped catch
   - RUN → TURN BACK
   - a close run-out
   - a no-ball free hit
   - the over-change bowler reveal
   - OVERDRIVE arm + fire
   - the last-ball vignette

## 12. Verification performed for this document

A script read **only this markdown file**. It wrote Appendix P into a
`final_over/` package using the §4.1 manifest, and wrote Appendix A, B, D and
E into an empty Flutter app that depends on that package, with the §4.2
dependencies (Flutter 3.44.4, flame 1.38.0, flutter_bloc 9.1.1).

- **Verbatim check:** every Appendix P, A and B block is byte-identical to the
  source repo, except P.1 (the documented barrel trim).
- **Analyze:** `flutter analyze` → **No issues found!**
- **App tests:** `flutter test` (E.1, balance) → **4 tests, all passed**.
- **Package tests:** `flutter test` inside `final_over/` (E.2–E.9) →
  **56 tests, all passed**.
- **Not checked:** Appendix C was not compiled; it depends on the host
  systems in §9.

---

## Appendix P — `final_over` rules package (verbatim)

Create these files under a `final_over/` directory at the app root. Only P.1 differs from the source (its last export is removed — see §4.1).

### P.1 `final_over/lib/final_over.dart`

_Trimmed: the source file's final `presentation/` export is removed._

<sub>8 lines</sub>

```dart
library;

/// The rules engine. Deterministic, pure Dart, no Flutter or Flame types —
/// this is what the host app builds its own renderer and HUD on top of.
/// [MatchController] stays the only gameplay authority: a renderer may send
/// commands and observe state, but never decides a run, a wicket, or a score.
export 'application/application.dart';
export 'domain/domain.dart';
```

### P.2 `final_over/lib/domain/domain.dart`

<sub>5 lines</sub>

```dart
export 'delivery_generator.dart';
export 'deterministic_random.dart';
export 'gameplay_tuning.dart';
export 'models.dart';
export 'resolvers.dart';
```

### P.3 `final_over/lib/domain/models.dart`

<sub>808 lines</sub>

```dart
import 'dart:math' as math;

/// Every value in the domain layer is expressed without Flutter or Flame types.
enum MatchPhase {
  idle,
  matchIntro,
  deliveryPreparation,
  bowlerRunUp,
  incomingBall,
  contact,
  cameraTransition,
  fieldPlay,
  runDecision,
  runnersMoving,
  throwInProgress,
  deliveryResult,
  betweenBalls,
  paused,
  won,
  lost,
  quit,
}

enum Elevation { ground, loft }

enum ShotDirection { offSide, straight, legSide, behind }

enum TimingGrade { perfect, good, early, late, poor, miss }

enum DeliveryLine { wideOff, off, middle, leg, wideLeg }

enum DeliveryLength { yorker, full, good, short }

enum ExtraType { none, wide, noBall }

enum DismissalType { none, bowled, caught, runOut }

enum ContactType { none, miss, clean, edge }

enum RiskLevel { safe, close, danger }

enum ObjectiveType {
  twoBoundaries,
  sixRunsFirstThreeLegalBalls,
  completeDouble,
}

enum FielderRole { outfielder, wicketkeeper, bowler }

enum FielderMotion {
  idle,
  reacting,
  chasing,
  backup,
  catching,
  carrying,
  throwing,
}

enum MatchEndReason { targetReached, ballsExhausted, wicketsLost, quit }

/// Opponent bowler for one over — look + light delivery bias.
final class BowlerProfile {
  const BowlerProfile({
    required this.id,
    required this.name,
    required this.lookKey,
    required this.jerseyNumber,
    required this.lineWeights,
    required this.lengthWeights,
  });

  final String id;
  final String name;
  final String lookKey;
  final int jerseyNumber;
  final Map<DeliveryLine, int> lineWeights;
  final Map<DeliveryLength, int> lengthWeights;

  /// Pace / seam / spin presets used when seeding a three-over attack.
  static const pace = BowlerProfile(
    id: 'fo-bowler-pace',
    name: 'VOLT',
    lookKey: 'fo-bowler-pace',
    jerseyNumber: 7,
    lineWeights: {
      DeliveryLine.off: 34,
      DeliveryLine.middle: 28,
      DeliveryLine.leg: 24,
    },
    lengthWeights: {
      DeliveryLength.yorker: 28,
      DeliveryLength.full: 30,
      DeliveryLength.good: 26,
      DeliveryLength.short: 16,
    },
  );

  static const seam = BowlerProfile(
    id: 'fo-bowler-seam',
    name: 'EDGE',
    lookKey: 'fo-bowler-seam',
    jerseyNumber: 11,
    lineWeights: {
      DeliveryLine.off: 28,
      DeliveryLine.middle: 36,
      DeliveryLine.leg: 22,
    },
    lengthWeights: {
      DeliveryLength.yorker: 18,
      DeliveryLength.full: 26,
      DeliveryLength.good: 36,
      DeliveryLength.short: 20,
    },
  );

  static const spin = BowlerProfile(
    id: 'fo-bowler-spin',
    name: 'DRIFT',
    lookKey: 'fo-bowler-spin',
    jerseyNumber: 23,
    lineWeights: {
      DeliveryLine.off: 22,
      DeliveryLine.middle: 30,
      DeliveryLine.leg: 34,
    },
    lengthWeights: {
      DeliveryLength.yorker: 12,
      DeliveryLength.full: 30,
      DeliveryLength.good: 28,
      DeliveryLength.short: 30,
    },
  );

  static const attack = <BowlerProfile>[pace, seam, spin];
}

/// A small immutable vector used by rules and the simulation.
final class FieldVector {
  const FieldVector(this.x, this.y);

  static const zero = FieldVector(0, 0);

  final double x;
  final double y;

  double get lengthSquared => x * x + y * y;
  double get length => math.sqrt(lengthSquared);

  FieldVector get normalized {
    final magnitude = length;
    return magnitude == 0 ? zero : this / magnitude;
  }

  double distanceTo(FieldVector other) => (this - other).length;
  double dot(FieldVector other) => x * other.x + y * other.y;

  FieldVector operator +(FieldVector other) =>
      FieldVector(x + other.x, y + other.y);
  FieldVector operator -(FieldVector other) =>
      FieldVector(x - other.x, y - other.y);
  FieldVector operator *(double scale) => FieldVector(x * scale, y * scale);
  FieldVector operator /(double scale) => FieldVector(x / scale, y / scale);

  static FieldVector lerp(FieldVector a, FieldVector b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);

  static FieldVector fromShotAngle(double angleDegrees) {
    final radians = angleDegrees * math.pi / 180;
    return FieldVector(math.sin(radians), -math.cos(radians));
  }

  @override
  bool operator ==(Object other) =>
      other is FieldVector && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'FieldVector($x, $y)';
}

final class DeliverySpec {
  const DeliverySpec({
    required this.ordinal,
    required this.seed,
    required this.line,
    required this.length,
    required this.speed,
    required this.movement,
    required this.extra,
    required this.lineX,
    required this.expectedContactMicros,
    this.isFairFinalBall = false,
  });

  final int ordinal;
  final int seed;
  final DeliveryLine line;
  final DeliveryLength length;
  final double speed;
  final double movement;
  final ExtraType extra;
  final double lineX;
  final int expectedContactMicros;
  final bool isFairFinalBall;

  bool get isLegal => extra == ExtraType.none;
  bool get isWide => extra == ExtraType.wide;
  bool get isNoBall => extra == ExtraType.noBall;
  double get contactX => lineX + movement;
}

final class SwingIntent {
  const SwingIntent({
    required this.direction,
    required this.inputMicros,
    this.powerShot = false,
    this.charge,
  });

  final ShotDirection direction;
  final int inputMicros;
  final bool powerShot;

  /// How loaded the bat was when the swing was released, 0..1. Null means the
  /// input carried no backlift at all (a headless bot, a replay from before the
  /// backlift existed) — such a swing is judged on timing alone.
  final double? charge;
}

final class ContactOutcome {
  const ContactOutcome({
    required this.type,
    required this.timing,
    required this.timingErrorMs,
    required this.direction,
    required this.elevation,
    required this.power,
    required this.control,
    required this.shotAngleDegrees,
    required this.velocity,
    required this.verticalVelocity,
    required this.acceptedSwing,
    required this.powerShotUsed,
    this.bowledThreat = false,
  });

  const ContactOutcome.noSwing({
    required Elevation elevation,
    bool bowledThreat = false,
  }) : this(
         type: ContactType.miss,
         timing: TimingGrade.miss,
         timingErrorMs: 276,
         direction: ShotDirection.straight,
         elevation: elevation,
         power: 0,
         control: 0,
         shotAngleDegrees: 0,
         velocity: FieldVector.zero,
         verticalVelocity: 0,
         acceptedSwing: false,
         powerShotUsed: false,
         bowledThreat: bowledThreat,
       );

  final ContactType type;
  final TimingGrade timing;
  final int timingErrorMs;
  final ShotDirection direction;
  final Elevation elevation;
  final double power;
  final double control;
  final double shotAngleDegrees;
  final FieldVector velocity;
  final double verticalVelocity;
  final bool acceptedSwing;
  final bool powerShotUsed;
  final bool bowledThreat;

  bool get madeContact => type == ContactType.clean || type == ContactType.edge;
}

final class BallKinematics {
  const BallKinematics({
    required this.position,
    required this.velocity,
    required this.height,
    required this.verticalVelocity,
    required this.aerial,
    this.firstBounceOccurred = false,
    this.stopped = false,
  });

  static const atContact = BallKinematics(
    position: FieldVector(0, 0.19),
    velocity: FieldVector.zero,
    height: 0,
    verticalVelocity: 0,
    aerial: false,
  );

  final FieldVector position;
  final FieldVector velocity;
  final double height;
  final double verticalVelocity;
  final bool aerial;
  final bool firstBounceOccurred;
  final bool stopped;

  BallKinematics copyWith({
    FieldVector? position,
    FieldVector? velocity,
    double? height,
    double? verticalVelocity,
    bool? aerial,
    bool? firstBounceOccurred,
    bool? stopped,
  }) => BallKinematics(
    position: position ?? this.position,
    velocity: velocity ?? this.velocity,
    height: height ?? this.height,
    verticalVelocity: verticalVelocity ?? this.verticalVelocity,
    aerial: aerial ?? this.aerial,
    firstBounceOccurred: firstBounceOccurred ?? this.firstBounceOccurred,
    stopped: stopped ?? this.stopped,
  );
}

final class RunnerState {
  const RunnerState({
    this.active = false,
    this.returning = false,
    this.runNumber = 0,
    this.progress = 0,
    this.completedRuns = 0,
    this.risk = RiskLevel.safe,
  });

  final bool active;
  final bool returning;
  final int runNumber;
  final double progress;
  final int completedRuns;
  final RiskLevel risk;

  bool get canTurnBack => active && !returning && progress <= 0.45;

  RunnerState copyWith({
    bool? active,
    bool? returning,
    int? runNumber,
    double? progress,
    int? completedRuns,
    RiskLevel? risk,
  }) => RunnerState(
    active: active ?? this.active,
    returning: returning ?? this.returning,
    runNumber: runNumber ?? this.runNumber,
    progress: progress ?? this.progress,
    completedRuns: completedRuns ?? this.completedRuns,
    risk: risk ?? this.risk,
  );
}

final class FielderState {
  const FielderState({
    required this.id,
    required this.role,
    required this.homePosition,
    required this.position,
    this.velocity = FieldVector.zero,
    this.motion = FielderMotion.idle,
    this.hasBall = false,
    this.reactionRemainingSeconds = 0,
  });

  final int id;
  final FielderRole role;
  final FieldVector homePosition;
  final FieldVector position;
  final FieldVector velocity;
  final FielderMotion motion;
  final bool hasBall;
  final double reactionRemainingSeconds;

  FielderState copyWith({
    FieldVector? position,
    FieldVector? velocity,
    FielderMotion? motion,
    bool? hasBall,
    double? reactionRemainingSeconds,
  }) => FielderState(
    id: id,
    role: role,
    homePosition: homePosition,
    position: position ?? this.position,
    velocity: velocity ?? this.velocity,
    motion: motion ?? this.motion,
    hasBall: hasBall ?? this.hasBall,
    reactionRemainingSeconds:
        reactionRemainingSeconds ?? this.reactionRemainingSeconds,
  );
}

/// One named, immutable defensive shape for a delivery.
final class FieldLayout {
  FieldLayout({
    required this.id,
    required this.label,
    required List<FielderState> fielders,
  }) : fielders = List.unmodifiable(fielders);

  final String id;
  final String label;
  final List<FielderState> fielders;
}

final class DeliveryLedger {
  const DeliveryLedger({
    this.extraRuns = 0,
    this.batRuns = 0,
    this.completedRuns = 0,
    this.dismissal = DismissalType.none,
    this.boundary = 0,
    this.extraApplied = false,
    this.finalized = false,
  });

  final int extraRuns;
  final int batRuns;
  final int completedRuns;
  final DismissalType dismissal;
  final int boundary;
  final bool extraApplied;
  final bool finalized;

  int get totalRuns => extraRuns + batRuns + completedRuns;

  DeliveryLedger copyWith({
    int? extraRuns,
    int? batRuns,
    int? completedRuns,
    DismissalType? dismissal,
    int? boundary,
    bool? extraApplied,
    bool? finalized,
  }) => DeliveryLedger(
    extraRuns: extraRuns ?? this.extraRuns,
    batRuns: batRuns ?? this.batRuns,
    completedRuns: completedRuns ?? this.completedRuns,
    dismissal: dismissal ?? this.dismissal,
    boundary: boundary ?? this.boundary,
    extraApplied: extraApplied ?? this.extraApplied,
    finalized: finalized ?? this.finalized,
  );
}

final class BallResult {
  const BallResult({
    required this.deliveryOrdinal,
    required this.legalBallsBefore,
    required this.legal,
    required this.extra,
    required this.extraRuns,
    required this.runsOffBat,
    required this.completedRunningRuns,
    required this.boundary,
    required this.dismissal,
    required this.contactType,
    required this.timing,
    required this.freeHitDelivery,
    required this.historyToken,
  });

  final int deliveryOrdinal;
  final int legalBallsBefore;
  final bool legal;
  final ExtraType extra;
  final int extraRuns;
  final int runsOffBat;
  final int completedRunningRuns;
  final int boundary;
  final DismissalType dismissal;
  final ContactType contactType;
  final TimingGrade timing;
  final bool freeHitDelivery;
  final String historyToken;

  int get totalRuns => extraRuns + runsOffBat + completedRunningRuns;
  bool get isWicket => dismissal != DismissalType.none;
  bool get isBoundary => boundary == 4 || boundary == 6;
  bool get isProductiveContact =>
      contactType != ContactType.none &&
      contactType != ContactType.miss &&
      (runsOffBat + completedRunningRuns) > 0;
}

final class SimulationSnapshot {
  SimulationSnapshot({
    required this.simulationMicros,
    required this.phase,
    required this.ball,
    required this.cameraTransition,
    required this.runner,
    required List<FielderState> fielders,
    required this.risk,
    required this.canRun,
  }) : fielders = List.unmodifiable(fielders);

  final int simulationMicros;
  final MatchPhase phase;
  final BallKinematics? ball;
  final double cameraTransition;
  final RunnerState runner;
  final List<FielderState> fielders;
  final RiskLevel risk;
  final bool canRun;
}

const Object _unset = Object();

/// Immutable single source of truth for a match.
final class MatchState {
  MatchState({
    required this.matchSeed,
    required this.target,
    required this.phase,
    this.suspendedPhase,
    required this.committedScore,
    required this.legalBalls,
    required this.physicalDeliveries,
    required this.wickets,
    required this.pendingRuns,
    required this.pendingExtras,
    required this.pendingBatRuns,
    required this.freeHit,
    required this.currentDeliveryFreeHit,
    required this.combo,
    required this.powerSegments,
    required this.powerShotArmed,
    required this.selectedElevation,
    required this.selectedDirection,
    required this.objective,
    required this.objectiveProgress,
    required this.objectiveCompleted,
    required this.stars,
    required this.simulationMicros,
    required this.phaseElapsedMicros,
    this.currentDelivery,
    this.swingIntent,
    this.contactOutcome,
    this.ball,
    required this.cameraTransition,
    required this.runner,
    required List<FielderState> fielders,
    required this.ledger,
    required List<BallResult> history,
    this.lastResult,
    required this.deliveryFinalized,
    required this.canRun,
    required this.holdRequested,
    required this.ballHeld,
    required this.pickupDecisionMicros,
    required this.throwArrivalMicros,
    this.endReason,
    this.maximumLegalBalls = 18,
    this.ballsPerOver = 6,
    this.maximumOvers = 3,
    this.bowlerIndex = 0,
    List<BowlerProfile> bowlers = const [],
  }) : fielders = List.unmodifiable(fielders),
       history = List.unmodifiable(history),
       bowlers = List.unmodifiable(bowlers);

  factory MatchState.initial() => MatchState(
    matchSeed: 0,
    target: 48,
    phase: MatchPhase.idle,
    committedScore: 0,
    legalBalls: 0,
    physicalDeliveries: 0,
    wickets: 0,
    pendingRuns: 0,
    pendingExtras: 0,
    pendingBatRuns: 0,
    freeHit: false,
    currentDeliveryFreeHit: false,
    combo: 1,
    powerSegments: 0,
    powerShotArmed: false,
    selectedElevation: Elevation.ground,
    selectedDirection: ShotDirection.straight,
    objective: ObjectiveType.completeDouble,
    objectiveProgress: 0,
    objectiveCompleted: false,
    stars: 0,
    simulationMicros: 0,
    phaseElapsedMicros: 0,
    cameraTransition: 0,
    runner: const RunnerState(),
    fielders: const [],
    ledger: const DeliveryLedger(),
    history: const [],
    deliveryFinalized: false,
    canRun: false,
    holdRequested: false,
    ballHeld: false,
    pickupDecisionMicros: 0,
    throwArrivalMicros: 0,
    bowlers: BowlerProfile.attack,
  );

  final int matchSeed;
  final int target;
  final MatchPhase phase;
  final MatchPhase? suspendedPhase;
  final int committedScore;
  final int legalBalls;
  final int physicalDeliveries;
  final int wickets;
  final int pendingRuns;
  final int pendingExtras;
  final int pendingBatRuns;
  final bool freeHit;
  final bool currentDeliveryFreeHit;
  final int combo;
  final int powerSegments;
  final bool powerShotArmed;
  final Elevation selectedElevation;
  final ShotDirection selectedDirection;
  final ObjectiveType objective;
  final int objectiveProgress;
  final bool objectiveCompleted;
  final int stars;
  final int simulationMicros;
  final int phaseElapsedMicros;
  final DeliverySpec? currentDelivery;
  final SwingIntent? swingIntent;
  final ContactOutcome? contactOutcome;
  final BallKinematics? ball;
  final double cameraTransition;
  final RunnerState runner;
  final List<FielderState> fielders;
  final DeliveryLedger ledger;
  final List<BallResult> history;
  final BallResult? lastResult;
  final bool deliveryFinalized;
  final bool canRun;
  final bool holdRequested;
  final bool ballHeld;
  final int pickupDecisionMicros;
  final int throwArrivalMicros;
  final MatchEndReason? endReason;
  final int maximumLegalBalls;
  final int ballsPerOver;
  final int maximumOvers;
  final int bowlerIndex;
  final List<BowlerProfile> bowlers;

  int get score =>
      committedScore + pendingRuns + pendingExtras + pendingBatRuns;
  int get runsNeeded => math.max(0, target - score);
  int get ballsRemaining => math.max(0, maximumLegalBalls - legalBalls);

  /// 0-based over index for the next / current delivery.
  int get currentOver {
    if (ballsPerOver <= 0) return 0;
    final over = legalBalls ~/ ballsPerOver;
    return math.min(over, math.max(0, maximumOvers - 1));
  }

  /// Legal ball within the current over (0–5).
  int get ballInOver {
    if (ballsPerOver <= 0) return 0;
    return legalBalls % ballsPerOver;
  }

  BowlerProfile? get currentBowler {
    if (bowlers.isEmpty) return null;
    return bowlers[bowlerIndex.clamp(0, bowlers.length - 1)];
  }

  /// How many more you can lose. Takes the limit because the wickets in hand
  /// are a difficulty knob (`GameplayTuning.maximumWickets`), not a constant.
  int wicketsRemaining(int maximumWickets) =>
      math.max(0, maximumWickets - wickets);
  bool get isTerminal => phase == MatchPhase.won || phase == MatchPhase.lost;
  bool get isPaused => phase == MatchPhase.paused;
  bool get canConfigureShot => phase == MatchPhase.deliveryPreparation;
  bool get canSwing =>
      phase == MatchPhase.incomingBall &&
      swingIntent == null &&
      contactOutcome == null &&
      !deliveryFinalized &&
      currentDelivery != null;

  MatchState copyWith({
    int? matchSeed,
    int? target,
    MatchPhase? phase,
    Object? suspendedPhase = _unset,
    int? committedScore,
    int? legalBalls,
    int? physicalDeliveries,
    int? wickets,
    int? pendingRuns,
    int? pendingExtras,
    int? pendingBatRuns,
    bool? freeHit,
    bool? currentDeliveryFreeHit,
    int? combo,
    int? powerSegments,
    bool? powerShotArmed,
    Elevation? selectedElevation,
    ShotDirection? selectedDirection,
    ObjectiveType? objective,
    int? objectiveProgress,
    bool? objectiveCompleted,
    int? stars,
    int? simulationMicros,
    int? phaseElapsedMicros,
    Object? currentDelivery = _unset,
    Object? swingIntent = _unset,
    Object? contactOutcome = _unset,
    Object? ball = _unset,
    double? cameraTransition,
    RunnerState? runner,
    List<FielderState>? fielders,
    DeliveryLedger? ledger,
    List<BallResult>? history,
    Object? lastResult = _unset,
    bool? deliveryFinalized,
    bool? canRun,
    bool? holdRequested,
    bool? ballHeld,
    int? pickupDecisionMicros,
    int? throwArrivalMicros,
    Object? endReason = _unset,
    int? maximumLegalBalls,
    int? ballsPerOver,
    int? maximumOvers,
    int? bowlerIndex,
    List<BowlerProfile>? bowlers,
  }) => MatchState(
    matchSeed: matchSeed ?? this.matchSeed,
    target: target ?? this.target,
    phase: phase ?? this.phase,
    suspendedPhase: identical(suspendedPhase, _unset)
        ? this.suspendedPhase
        : suspendedPhase as MatchPhase?,
    committedScore: committedScore ?? this.committedScore,
    legalBalls: legalBalls ?? this.legalBalls,
    physicalDeliveries: physicalDeliveries ?? this.physicalDeliveries,
    wickets: wickets ?? this.wickets,
    pendingRuns: pendingRuns ?? this.pendingRuns,
    pendingExtras: pendingExtras ?? this.pendingExtras,
    pendingBatRuns: pendingBatRuns ?? this.pendingBatRuns,
    freeHit: freeHit ?? this.freeHit,
    currentDeliveryFreeHit:
        currentDeliveryFreeHit ?? this.currentDeliveryFreeHit,
    combo: combo ?? this.combo,
    powerSegments: powerSegments ?? this.powerSegments,
    powerShotArmed: powerShotArmed ?? this.powerShotArmed,
    selectedElevation: selectedElevation ?? this.selectedElevation,
    selectedDirection: selectedDirection ?? this.selectedDirection,
    objective: objective ?? this.objective,
    objectiveProgress: objectiveProgress ?? this.objectiveProgress,
    objectiveCompleted: objectiveCompleted ?? this.objectiveCompleted,
    stars: stars ?? this.stars,
    simulationMicros: simulationMicros ?? this.simulationMicros,
    phaseElapsedMicros: phaseElapsedMicros ?? this.phaseElapsedMicros,
    currentDelivery: identical(currentDelivery, _unset)
        ? this.currentDelivery
        : currentDelivery as DeliverySpec?,
    swingIntent: identical(swingIntent, _unset)
        ? this.swingIntent
        : swingIntent as SwingIntent?,
    contactOutcome: identical(contactOutcome, _unset)
        ? this.contactOutcome
        : contactOutcome as ContactOutcome?,
    ball: identical(ball, _unset) ? this.ball : ball as BallKinematics?,
    cameraTransition: cameraTransition ?? this.cameraTransition,
    runner: runner ?? this.runner,
    fielders: fielders ?? this.fielders,
    ledger: ledger ?? this.ledger,
    history: history ?? this.history,
    lastResult: identical(lastResult, _unset)
        ? this.lastResult
        : lastResult as BallResult?,
    deliveryFinalized: deliveryFinalized ?? this.deliveryFinalized,
    canRun: canRun ?? this.canRun,
    holdRequested: holdRequested ?? this.holdRequested,
    ballHeld: ballHeld ?? this.ballHeld,
    pickupDecisionMicros: pickupDecisionMicros ?? this.pickupDecisionMicros,
    throwArrivalMicros: throwArrivalMicros ?? this.throwArrivalMicros,
    endReason: identical(endReason, _unset)
        ? this.endReason
        : endReason as MatchEndReason?,
    maximumLegalBalls: maximumLegalBalls ?? this.maximumLegalBalls,
    ballsPerOver: ballsPerOver ?? this.ballsPerOver,
    maximumOvers: maximumOvers ?? this.maximumOvers,
    bowlerIndex: bowlerIndex ?? this.bowlerIndex,
    bowlers: bowlers ?? this.bowlers,
  );
}
```

### P.4 `final_over/lib/domain/gameplay_tuning.dart`

<sub>363 lines</sub>

```dart
import 'models.dart';

/// All changeable gameplay values live here so balancing never leaks into UI.
final class GameplayTuning {
  const GameplayTuning({
    this.fixedStepMicros = 16667,
    this.maximumFrameMicros = 250000,
    this.deliveryPreparationMicros = 3000000,
    this.runUpMicros = 900000,
    this.incomingToContactMicros = 650000,
    this.lateSwingGraceMicros = 276000,
    this.cameraTransitionMicros = 360000,
    this.impactHoldMicros = 450000,
    this.deliveryResultMicros = 650000,
    this.betweenBallsMicros = 450000,
    this.pickupDecisionMicros = 500000,
    this.perfectWindowMs = 50,
    this.goodWindowMs = 115,
    this.earlyLateWindowMs = 190,
    this.poorWindowMs = 275,
    this.batterReach = 0.085,
    this.stumpChannel = 0.028,
    this.maximumMovement = 0.012,
    this.groundBaseSpeed = 0.36,
    this.groundPowerSpeed = 0.64,
    this.groundDragPerSecond = 0.52,
    this.loftBaseSpeed = 0.42,
    this.loftPowerSpeed = 0.59,
    this.loftVerticalBaseSpeed = 0.55,
    this.loftVerticalPowerSpeed = 0.45,
    this.gravity = 1.65,
    this.landingSpeedRetention = 0.54,
    this.catchHeight = 0.025,
    this.fieldRadius = 1,
    this.pitchLength = 0.42,
    this.pitchWidth = 0.10,
    this.boundaryRadius = 1,
    this.ballPickupRadius = 0.045,
    this.catchRadius = 0.06,
    this.fielderSpeed = 0.29,
    this.backupSpeedFactor = 0.65,
    this.throwSpeed = 0.62,
    this.closeReactionSeconds = 0.24,
    this.deepReactionSeconds = 0.33,
    this.keeperReactionSeconds = 0.14,
    this.runDurationSeconds = 1.20,
    this.turnBackLimit = 0.45,
    this.closeCallSeconds = 0.09,
    this.safeMarginSeconds = 0.22,
    this.dangerMarginSeconds = -0.15,
    this.maximumRuns = 3,
    this.maximumLegalBalls = 18,
    this.maximumOvers = 3,
    this.ballsPerOver = 6,
    this.maximumWickets = 2,
    this.maximumNoBalls = 3,
    this.maximumWides = 5,
    this.noBallProbability = 0.02,
    this.wideProbability = 0.05,
    this.baseCatchChance = 0.82,
    this.keeperCatchChance = 0.88,
    this.catchChanceMinimum = 0.25,
    this.catchChanceMaximum = 0.95,
    this.dropSpeedMinimum = 0.35,
    this.dropSpeedMaximum = 0.60,
    this.powerShotSegments = 10,
    this.powerShotPowerMultiplier = 1.18,
    this.powerShotControlBonus = 0.08,
    this.chargeSeconds = 0.8125,
    this.chargePerfectCenter = 0.80,
    this.chargePerfectHalf = 0.10,
    this.chargeGoodHalf = 0.22,
    this.overswingFrom = 0.92,
    this.backliftPowerFloor = 0.55,
    this.overswingControlPenalty = 0.22,
    this.overswingEdgeBonus = 0.10,
  });

  final int fixedStepMicros;
  final int maximumFrameMicros;
  final int deliveryPreparationMicros;
  final int runUpMicros;
  final int incomingToContactMicros;
  final int lateSwingGraceMicros;
  final int cameraTransitionMicros;
  final int impactHoldMicros;
  final int deliveryResultMicros;
  final int betweenBallsMicros;
  final int pickupDecisionMicros;

  final int perfectWindowMs;
  final int goodWindowMs;
  final int earlyLateWindowMs;
  final int poorWindowMs;

  final double batterReach;
  final double stumpChannel;
  final double maximumMovement;
  final double groundBaseSpeed;
  final double groundPowerSpeed;
  final double groundDragPerSecond;
  final double loftBaseSpeed;
  final double loftPowerSpeed;
  final double loftVerticalBaseSpeed;
  final double loftVerticalPowerSpeed;
  final double gravity;
  final double landingSpeedRetention;
  final double catchHeight;
  final double fieldRadius;
  final double pitchLength;
  final double pitchWidth;
  final double boundaryRadius;
  final double ballPickupRadius;
  final double catchRadius;
  final double fielderSpeed;
  final double backupSpeedFactor;
  final double throwSpeed;
  final double closeReactionSeconds;
  final double deepReactionSeconds;
  final double keeperReactionSeconds;
  final double runDurationSeconds;
  final double turnBackLimit;
  final double closeCallSeconds;
  final double safeMarginSeconds;
  final double dangerMarginSeconds;
  final int maximumRuns;
  final int maximumLegalBalls;
  final int maximumOvers;
  final int ballsPerOver;
  final int maximumWickets;
  final int maximumNoBalls;
  final int maximumWides;
  final double noBallProbability;
  final double wideProbability;
  final double baseCatchChance;
  final double keeperCatchChance;
  final double catchChanceMinimum;
  final double catchChanceMaximum;
  final double dropSpeedMinimum;
  final double dropSpeedMaximum;

  /// Combo segments the batter must bank before OVERDRIVE can be armed. One
  /// source of truth: the HUD reads the same number the controller gates on.
  final int powerShotSegments;
  final double powerShotPowerMultiplier;
  final double powerShotControlBonus;

  // ── Backlift ───────────────────────────────────────────────────────────────
  // Hold a swing plate and the bat loads. How charged you are when you release
  // decides how hard you hit it; hold too long and you are slogging.

  /// Hold time from an empty bat to a fully loaded one.
  final double chargeSeconds;

  /// The charge that pays full power, and the band around it the meter draws.
  final double chargePerfectCenter;
  final double chargePerfectHalf;
  final double chargeGoodHalf;

  /// Past this you are overswinging: the power stays, the control does not.
  final double overswingFrom;

  /// Power multiplier on a completely uncharged swing — the safe little dab.
  final double backliftPowerFloor;
  final double overswingControlPenalty;
  final double overswingEdgeBonus;

  /// Shared difficulty presets used by the host app and balance tooling.
  static const rookie = GameplayTuning(
    perfectWindowMs: 80,
    goodWindowMs: 180,
    earlyLateWindowMs: 300,
    poorWindowMs: 400,
    lateSwingGraceMicros: 401000,
    maximumWickets: 4,
    baseCatchChance: 0.58,
    keeperCatchChance: 0.68,
    powerShotSegments: 4,
    fielderSpeed: 0.24,
    throwSpeed: 0.56,
    closeReactionSeconds: 0.30,
    deepReactionSeconds: 0.40,
    keeperReactionSeconds: 0.18,
    batterReach: 0.100,
    groundBaseSpeed: 0.396,
    groundPowerSpeed: 0.704,
    loftBaseSpeed: 0.462,
    loftPowerSpeed: 0.649,
    backliftPowerFloor: 0.75,
    overswingFrom: 0.98,
    overswingControlPenalty: 0.10,
    overswingEdgeBonus: 0.04,
  );

  static const pro = GameplayTuning(
    perfectWindowMs: 65,
    goodWindowMs: 150,
    earlyLateWindowMs: 245,
    poorWindowMs: 330,
    lateSwingGraceMicros: 331000,
    maximumWickets: 3,
    baseCatchChance: 0.68,
    keeperCatchChance: 0.76,
    powerShotSegments: 5,
    fielderSpeed: 0.27,
    throwSpeed: 0.59,
    closeReactionSeconds: 0.27,
    deepReactionSeconds: 0.36,
    keeperReactionSeconds: 0.16,
    batterReach: 0.092,
    groundBaseSpeed: 0.378,
    groundPowerSpeed: 0.672,
    loftBaseSpeed: 0.441,
    loftPowerSpeed: 0.627,
    backliftPowerFloor: 0.65,
    overswingFrom: 0.95,
    overswingControlPenalty: 0.16,
    overswingEdgeBonus: 0.07,
  );

  static const elite = GameplayTuning(
    perfectWindowMs: 50,
    goodWindowMs: 115,
    earlyLateWindowMs: 190,
    poorWindowMs: 275,
    lateSwingGraceMicros: 276000,
    maximumWickets: 2,
    baseCatchChance: 0.82,
    keeperCatchChance: 0.88,
    powerShotSegments: 8,
    fielderSpeed: 0.29,
    throwSpeed: 0.62,
    closeReactionSeconds: 0.24,
    deepReactionSeconds: 0.33,
    keeperReactionSeconds: 0.14,
    batterReach: 0.085,
    groundBaseSpeed: 0.36,
    groundPowerSpeed: 0.64,
    loftBaseSpeed: 0.42,
    loftPowerSpeed: 0.59,
    backliftPowerFloor: 0.55,
    overswingFrom: 0.92,
    overswingControlPenalty: 0.22,
    overswingEdgeBonus: 0.10,
  );

  /// Approved chase ladder for the three-over format (32–66).
  static const targetOptions = <int>[32, 36, 40, 44, 48, 52, 56, 58, 62, 66];

  static const targetMinimum = 32;
  static const targetMaximum = 66;

  static const lineX = <DeliveryLine, double>{
    DeliveryLine.wideOff: -0.11,
    DeliveryLine.off: -0.035,
    DeliveryLine.middle: 0,
    DeliveryLine.leg: 0.035,
    DeliveryLine.wideLeg: 0.11,
  };

  /// Five balanced shapes. The seed chooses the opening shape and every
  /// physical delivery advances one slot, so wides and no-balls trigger the
  /// same visible tactical reset as legal balls.
  static final List<FieldLayout> fieldLayouts = List.unmodifiable([
    _fieldLayout('balanced', 'BALANCED', const [
      FieldVector(-0.78, -0.12),
      FieldVector(0.78, -0.12),
      FieldVector(-0.45, -0.72),
      FieldVector(0.45, -0.72),
      FieldVector(-0.72, 0.48),
      FieldVector(0.72, 0.48),
      FieldVector(-0.18, -0.82),
      FieldVector(0.18, -0.82),
    ]),
    _fieldLayout('off-guard', 'OFF GUARD', const [
      FieldVector(-0.82, -0.10),
      FieldVector(-0.64, -0.50),
      FieldVector(-0.42, -0.78),
      FieldVector(-0.18, -0.88),
      FieldVector(-0.58, 0.38),
      FieldVector(0.64, -0.58),
      FieldVector(0.80, 0.14),
      FieldVector(0.42, 0.60),
    ]),
    _fieldLayout('leg-guard', 'LEG GUARD', const [
      FieldVector(0.82, -0.10),
      FieldVector(0.64, -0.50),
      FieldVector(0.42, -0.78),
      FieldVector(0.18, -0.88),
      FieldVector(0.58, 0.38),
      FieldVector(-0.64, -0.58),
      FieldVector(-0.80, 0.14),
      FieldVector(-0.42, 0.60),
    ]),
    _fieldLayout('straight-wall', 'STRAIGHT WALL', const [
      FieldVector(-0.74, -0.30),
      FieldVector(0.74, -0.30),
      FieldVector(-0.52, -0.72),
      FieldVector(0.52, -0.72),
      FieldVector(-0.26, -0.91),
      FieldVector(0.26, -0.91),
      FieldVector(-0.66, 0.43),
      FieldVector(0.66, 0.43),
    ]),
    _fieldLayout('close-attack', 'CLOSE ATTACK', const [
      FieldVector(-0.40, -0.32),
      FieldVector(0.40, -0.32),
      FieldVector(-0.28, -0.54),
      FieldVector(0.28, -0.54),
      FieldVector(-0.62, -0.66),
      FieldVector(0.62, -0.66),
      FieldVector(-0.48, 0.44),
      FieldVector(0.48, 0.44),
    ]),
  ]);

  /// Backwards-compatible alias for simulations that explicitly request the
  /// original neutral field.
  static final List<FielderState> balancedField = fieldLayouts.first.fielders;

  static FieldLayout fieldLayoutFor({
    required int matchSeed,
    required int physicalOrdinal,
  }) {
    final count = fieldLayouts.length;
    final seededStart = ((matchSeed % count) + count) % count;
    final deliveryOffset = physicalOrdinal <= 1 ? 0 : physicalOrdinal - 1;
    return fieldLayouts[(seededStart + deliveryOffset) % count];
  }

  static FieldLayout _fieldLayout(
    String id,
    String label,
    List<FieldVector> outfield,
  ) {
    assert(outfield.length == 8);
    return FieldLayout(
      id: id,
      label: label,
      fielders: [
        for (var index = 0; index < outfield.length; index++)
          FielderState(
            id: index,
            role: FielderRole.outfielder,
            homePosition: outfield[index],
            position: outfield[index],
          ),
        const FielderState(
          id: 8,
          role: FielderRole.wicketkeeper,
          homePosition: FieldVector(0, 0.27),
          position: FieldVector(0, 0.27),
        ),
        const FielderState(
          id: 9,
          role: FielderRole.bowler,
          homePosition: FieldVector(0, -0.05),
          position: FieldVector(0, -0.05),
        ),
      ],
    );
  }
}
```

### P.5 `final_over/lib/domain/deterministic_random.dart`

<sub>121 lines</sub>

```dart
/// Named random streams prevent unrelated decisions from perturbing each other.
enum RandomStream {
  delivery,
  contact,
  catchOutcome,
  drop,
  throwOutcome,
  objective,
}

/// SplitMix64 with explicitly masked unsigned 64-bit arithmetic.
///
/// Dart VM bitwise `int` operations are signed, so the internal state uses
/// [BigInt] to preserve all 64 bits on every supported Dart runtime. Public
/// integer results use the conventional signed two's-complement view of those
/// same bits. This keeps match seeds stable without relying on platform quirks.
final class DeterministicRandom {
  DeterministicRandom(int seed) : _state = BigInt.from(seed) & _mask64;

  static final BigInt _mask64 = BigInt.parse('ffffffffffffffff', radix: 16);
  static final BigInt _twoTo64 = BigInt.one << 64;
  static final BigInt _twoTo63 = BigInt.one << 63;
  static final BigInt _increment = BigInt.parse('9e3779b97f4a7c15', radix: 16);
  static final BigInt _mix1 = BigInt.parse('bf58476d1ce4e5b9', radix: 16);
  static final BigInt _mix2 = BigInt.parse('94d049bb133111eb', radix: 16);
  static const double _twoTo53 = 9007199254740992.0;

  BigInt _state;

  BigInt _nextBits() {
    _state = (_state + _increment) & _mask64;
    return _mixBits(_state);
  }

  /// Returns the signed two's-complement view of the next 64 random bits.
  int nextUint64() => _toSignedInt(_nextBits());

  double nextDouble() {
    final top53 = _nextBits() >> 11;
    return top53.toInt() / _twoTo53;
  }

  bool nextBool([double probability = 0.5]) {
    if (probability <= 0) return false;
    if (probability >= 1) return true;
    return nextDouble() < probability;
  }

  int nextInt(int maximum) {
    if (maximum <= 0) {
      throw ArgumentError.value(maximum, 'maximum', 'Must be positive');
    }
    final bound = BigInt.from(maximum);
    final threshold = _twoTo64 % bound;
    while (true) {
      final value = _nextBits();
      if (value >= threshold) return (value % bound).toInt();
    }
  }

  double range(double minimum, double maximum) {
    if (maximum < minimum) {
      throw ArgumentError('maximum must not be smaller than minimum');
    }
    return minimum + (maximum - minimum) * nextDouble();
  }

  T choose<T>(List<T> values) {
    if (values.isEmpty) throw ArgumentError('Cannot choose from an empty list');
    return values[nextInt(values.length)];
  }

  static int mix64(int value) =>
      _toSignedInt(_mixBits(BigInt.from(value) & _mask64));

  static BigInt _mixBits(BigInt value) {
    var z = value & _mask64;
    z = ((z ^ (z >> 30)) * _mix1) & _mask64;
    z = ((z ^ (z >> 27)) * _mix2) & _mask64;
    return (z ^ (z >> 31)) & _mask64;
  }

  static int _toSignedInt(BigInt bits) =>
      (bits >= _twoTo63 ? bits - _twoTo64 : bits).toInt();
}

final class SeedStreams {
  const SeedStreams._();

  static final _streamSalts = <BigInt>[
    BigInt.parse('243f6a8885a308d3', radix: 16),
    BigInt.parse('13198a2e03707344', radix: 16),
    BigInt.parse('a4093822299f31d0', radix: 16),
    BigInt.parse('082efa98ec4e6c89', radix: 16),
    BigInt.parse('452821e638d01377', radix: 16),
    BigInt.parse('be5466cf34e90c6c', radix: 16),
  ];
  static final BigInt _ordinalSalt = -BigInt.parse(
    '61c8864680b583eb',
    radix: 16,
  );

  /// Derives a unique stream seed from the match and physical delivery.
  static int seedFor(int matchSeed, int deliveryOrdinal, RandomStream stream) {
    final match = DeterministicRandom._mixBits(
      BigInt.from(matchSeed) & DeterministicRandom._mask64,
    );
    final ordinal = DeterministicRandom._mixBits(
      BigInt.from(deliveryOrdinal) * _ordinalSalt,
    );
    return DeterministicRandom._toSignedInt(
      DeterministicRandom._mixBits(match ^ ordinal ^ _streamSalts[stream.index]),
    );
  }

  static DeterministicRandom forStream(
    int matchSeed,
    int deliveryOrdinal,
    RandomStream stream,
  ) => DeterministicRandom(seedFor(matchSeed, deliveryOrdinal, stream));
}
```

### P.6 `final_over/lib/domain/delivery_generator.dart`

<sub>122 lines</sub>

```dart
import 'deterministic_random.dart';
import 'gameplay_tuning.dart';
import 'models.dart';

class DeliveryGenerator {
  const DeliveryGenerator({this.tuning = const GameplayTuning()});

  final GameplayTuning tuning;

  DeliverySpec generate({
    required int matchSeed,
    required int physicalOrdinal,
    required int legalBalls,
    required int score,
    required int target,
    required List<BallResult> history,
    required List<DeliverySpec> previousDeliveries,
    int expectedContactMicros = 0,
    BowlerProfile? bowler,
  }) {
    if (physicalOrdinal < 1) {
      throw ArgumentError.value(physicalOrdinal, 'physicalOrdinal');
    }
    final seed = SeedStreams.seedFor(
      matchSeed,
      physicalOrdinal,
      RandomStream.delivery,
    );
    final random = DeterministicRandom(seed);
    final noBalls = history.where((r) => r.extra == ExtraType.noBall).length;
    final wides = history.where((r) => r.extra == ExtraType.wide).length;
    final fairFinalBall =
        legalBalls == tuning.maximumLegalBalls - 1 && target - score <= 6;

    var extra = ExtraType.none;
    if (physicalOrdinal > 1 && !fairFinalBall) {
      // No-ball has explicit precedence, so a delivery can never be both.
      if (noBalls < tuning.maximumNoBalls &&
          random.nextBool(tuning.noBallProbability)) {
        extra = ExtraType.noBall;
      } else if (wides < tuning.maximumWides &&
          random.nextBool(tuning.wideProbability)) {
        extra = ExtraType.wide;
      }
    }

    final lineWeights = bowler?.lineWeights ??
        const {
          DeliveryLine.off: 30,
          DeliveryLine.middle: 34,
          DeliveryLine.leg: 28,
        };
    final lengthWeights = bowler?.lengthWeights ??
        const {
          DeliveryLength.yorker: 22,
          DeliveryLength.full: 28,
          DeliveryLength.good: 32,
          DeliveryLength.short: 18,
        };

    final line = fairFinalBall
        ? random.choose(const [
            DeliveryLine.off,
            DeliveryLine.middle,
            DeliveryLine.leg,
          ])
        : extra == ExtraType.wide
        ? random.choose(const [DeliveryLine.wideOff, DeliveryLine.wideLeg])
        : _weighted<DeliveryLine>(random, lineWeights);

    var length = fairFinalBall
        ? random.choose(const [DeliveryLength.full, DeliveryLength.good])
        : _weighted<DeliveryLength>(random, lengthWeights);
    if (previousDeliveries.length >= 2) {
      final previous = previousDeliveries[previousDeliveries.length - 1].length;
      final beforePrevious =
          previousDeliveries[previousDeliveries.length - 2].length;
      if (previous == beforePrevious &&
          previous == length &&
          (length == DeliveryLength.yorker || length == DeliveryLength.short)) {
        length = random.choose(const [
          DeliveryLength.full,
          DeliveryLength.good,
        ]);
      }
    }

    var movement = random.range(
      -tuning.maximumMovement,
      tuning.maximumMovement,
    );
    var speed = random.range(0.82, 1.08);
    if (physicalOrdinal == 1) speed *= 0.95;
    if (fairFinalBall) {
      movement = movement.clamp(-0.006, 0.006);
      speed = speed.clamp(0.82, 0.92);
    }

    return DeliverySpec(
      ordinal: physicalOrdinal,
      seed: seed,
      line: line,
      length: length,
      speed: speed,
      movement: movement,
      extra: extra,
      lineX: GameplayTuning.lineX[line]!,
      expectedContactMicros: expectedContactMicros,
      isFairFinalBall: fairFinalBall,
    );
  }

  T _weighted<T>(DeterministicRandom random, Map<T, int> weights) {
    final total = weights.values.fold<int>(0, (sum, weight) => sum + weight);
    var roll = random.nextInt(total);
    for (final entry in weights.entries) {
      if (roll < entry.value) return entry.key;
      roll -= entry.value;
    }
    return weights.keys.last;
  }
}
```

### P.7 `final_over/lib/domain/resolvers.dart`

<sub>433 lines</sub>

```dart
import 'dart:math' as math;

import 'deterministic_random.dart';
import 'gameplay_tuning.dart';
import 'models.dart';

final class TimingResolver {
  const TimingResolver._();

  static TimingGrade resolve(
    int errorMs, {
    bool hasInput = true,
    GameplayTuning tuning = const GameplayTuning(),
  }) {
    if (!hasInput) return TimingGrade.miss;
    final magnitude = errorMs.abs();
    if (magnitude <= tuning.perfectWindowMs) return TimingGrade.perfect;
    if (magnitude <= tuning.goodWindowMs) return TimingGrade.good;
    if (magnitude <= tuning.earlyLateWindowMs) {
      return errorMs < 0 ? TimingGrade.early : TimingGrade.late;
    }
    if (magnitude <= tuning.poorWindowMs) return TimingGrade.poor;
    return TimingGrade.miss;
  }
}

final class ContactResolver {
  const ContactResolver({this.tuning = const GameplayTuning()});

  final GameplayTuning tuning;

  double compatibility(
    DeliverySpec delivery,
    ShotDirection direction,
    Elevation elevation,
  ) {
    var score = 0.50;
    final lineMatch = switch (delivery.line) {
      DeliveryLine.off ||
      DeliveryLine.wideOff => direction == ShotDirection.offSide,
      DeliveryLine.middle => direction == ShotDirection.straight,
      DeliveryLine.leg || DeliveryLine.wideLeg =>
        direction == ShotDirection.legSide || direction == ShotDirection.behind,
    };
    if (lineMatch) {
      score += delivery.line == DeliveryLine.middle ? 0.20 : 0.18;
    } else {
      score -= 0.08;
    }

    score += switch ((delivery.length, elevation)) {
      (DeliveryLength.yorker, Elevation.ground) => 0.10,
      (DeliveryLength.yorker, Elevation.loft) => -0.08,
      (DeliveryLength.full, Elevation.ground) => 0.08,
      (DeliveryLength.full, Elevation.loft) => 0.04,
      (DeliveryLength.good, _) => 0.08,
      (DeliveryLength.short, Elevation.loft) => 0.12,
      (DeliveryLength.short, Elevation.ground) => -0.08,
    };
    return score.clamp(0.0, 1.0);
  }

  /// How hard a given backlift lets you hit: nothing at all still connects (a
  /// dab), and anything from [GameplayTuning.chargePerfectCenter] up swings the
  /// full blade. A null charge is a swing with no backlift input — judged on
  /// timing alone, exactly as the game behaved before the meter existed.
  double backliftPower(double? charge) {
    if (charge == null) return 1;
    final loaded = (charge / tuning.chargePerfectCenter).clamp(0.0, 1.0);
    return tuning.backliftPowerFloor + (1 - tuning.backliftPowerFloor) * loaded;
  }

  /// 0 until you pass [GameplayTuning.overswingFrom], then ramps to 1 at a
  /// fully wound-up bat. This is the cost of holding too long.
  double overswing(double? charge) {
    if (charge == null || charge <= tuning.overswingFrom) return 0;
    final past = (charge - tuning.overswingFrom) / (1 - tuning.overswingFrom);
    return past.clamp(0.0, 1.0);
  }

  ContactOutcome resolve({
    required DeliverySpec delivery,
    required Elevation elevation,
    required ShotDirection direction,
    required int timingErrorMs,
    required bool hasInput,
    required bool powerShot,
    required DeterministicRandom random,
    double? charge,
  }) {
    final timing = TimingResolver.resolve(
      timingErrorMs,
      hasInput: hasInput,
      tuning: tuning,
    );
    final bowledThreat =
        delivery.contactX.abs() <= tuning.stumpChannel &&
        delivery.extra != ExtraType.wide &&
        delivery.length != DeliveryLength.short;
    final reachable = delivery.contactX.abs() <= tuning.batterReach;
    if (!hasInput || timing == TimingGrade.miss || !reachable) {
      return ContactOutcome(
        type: ContactType.miss,
        timing: TimingGrade.miss,
        timingErrorMs: timingErrorMs,
        direction: direction,
        elevation: elevation,
        power: 0,
        control: 0,
        shotAngleDegrees: _nominalAngle(direction),
        velocity: FieldVector.zero,
        verticalVelocity: 0,
        acceptedSwing: hasInput,
        powerShotUsed: hasInput && powerShot,
        bowledThreat: bowledThreat,
      );
    }

    final profile = _profile(timing);
    final technique = compatibility(delivery, direction, elevation);
    final wild = overswing(charge);
    var control = profile.control * (0.65 + 0.55 * technique);
    if (powerShot) control += tuning.powerShotControlBonus;
    control *= 1 - tuning.overswingControlPenalty * wild;
    control = control.clamp(0.0, 1.0);

    final edgeChance =
        switch (timing) {
          TimingGrade.perfect => 0.015,
          TimingGrade.good => 0.06,
          TimingGrade.early || TimingGrade.late => 0.22,
          TimingGrade.poor => 0.44,
          TimingGrade.miss => 1.0,
        } +
        (1 - technique) * 0.12 +
        tuning.overswingEdgeBonus * wild;
    final edged = random.nextBool(edgeChance.clamp(0.0, 0.75));

    var power =
        profile.power * (0.80 + 0.42 * technique) * random.range(0.94, 1.06);
    power *= backliftPower(charge);
    if (powerShot) power *= tuning.powerShotPowerMultiplier;
    if (edged) power *= random.range(0.35, 0.65);
    power = power.clamp(0.12, 1.20);

    var angle = _nominalAngle(direction);
    if (timing == TimingGrade.early) angle += 7 + 8 * (1 - control);
    if (timing == TimingGrade.late) angle -= 7 + 8 * (1 - control);
    final maximumSpread = timing == TimingGrade.poor
        ? 28.0
        : 16.0 * (1 - control);
    angle += random.range(-maximumSpread, maximumSpread);
    if (edged) angle += random.range(-18, 18);

    final horizontalSpeed = elevation == Elevation.ground
        ? tuning.groundBaseSpeed + tuning.groundPowerSpeed * power
        : tuning.loftBaseSpeed + tuning.loftPowerSpeed * power;
    final verticalSpeed = elevation == Elevation.loft
        ? tuning.loftVerticalBaseSpeed + tuning.loftVerticalPowerSpeed * power
        : 0.0;
    return ContactOutcome(
      type: edged ? ContactType.edge : ContactType.clean,
      timing: timing,
      timingErrorMs: timingErrorMs,
      direction: direction,
      elevation: elevation,
      power: power,
      control: control,
      shotAngleDegrees: angle,
      velocity: FieldVector.fromShotAngle(angle) * horizontalSpeed,
      verticalVelocity: verticalSpeed,
      acceptedSwing: true,
      powerShotUsed: powerShot,
      bowledThreat: false,
    );
  }

  static double _nominalAngle(ShotDirection direction) => switch (direction) {
    ShotDirection.offSide => -45,
    ShotDirection.straight => 0,
    ShotDirection.legSide => 45,
    ShotDirection.behind => 180,
  };

  static ({double power, double control}) _profile(TimingGrade timing) =>
      switch (timing) {
        TimingGrade.perfect => (power: 1.0, control: 1.0),
        TimingGrade.good => (power: 0.90, control: 0.88),
        TimingGrade.early || TimingGrade.late => (power: 0.74, control: 0.66),
        TimingGrade.poor => (power: 0.48, control: 0.38),
        TimingGrade.miss => (power: 0.0, control: 0.0),
      };
}

final class PhysicsResolver {
  const PhysicsResolver({this.tuning = const GameplayTuning()});

  final GameplayTuning tuning;

  BallKinematics launch(ContactOutcome contact) => BallKinematics(
    position: BallKinematics.atContact.position,
    velocity: contact.velocity,
    height: contact.elevation == Elevation.loft ? 0.001 : 0,
    verticalVelocity: contact.verticalVelocity,
    aerial: contact.elevation == Elevation.loft,
  );

  BallKinematics step(BallKinematics ball, double seconds) {
    if (ball.stopped || seconds <= 0) return ball;
    var position = ball.position + ball.velocity * seconds;
    var velocity = ball.velocity;
    var height = ball.height;
    var verticalVelocity = ball.verticalVelocity;
    var aerial = ball.aerial;
    var bounced = ball.firstBounceOccurred;

    if (aerial) {
      height +=
          verticalVelocity * seconds - 0.5 * tuning.gravity * seconds * seconds;
      verticalVelocity -= tuning.gravity * seconds;
      if (height <= 0 && verticalVelocity <= 0) {
        height = 0;
        verticalVelocity = 0;
        aerial = false;
        bounced = true;
        velocity = velocity * tuning.landingSpeedRetention;
      }
    } else {
      final speed = velocity.length;
      final nextSpeed = math.max(
        0.0,
        speed - tuning.groundDragPerSecond * seconds,
      );
      velocity = speed == 0
          ? FieldVector.zero
          : velocity.normalized * nextSpeed;
    }
    final stopped = !aerial && velocity.length <= 0.015;
    if (stopped) velocity = FieldVector.zero;
    return BallKinematics(
      position: position,
      velocity: velocity,
      height: height,
      verticalVelocity: verticalVelocity,
      aerial: aerial,
      firstBounceOccurred: bounced,
      stopped: stopped,
    );
  }

  int boundaryValue(BallKinematics ball, Elevation elevation) {
    if (ball.position.length < tuning.boundaryRadius) return 0;
    // Ground can never produce a six. Any loft that bounced is also a four.
    return elevation == Elevation.loft && !ball.firstBounceOccurred ? 6 : 4;
  }

  /// A catch at the exact bounce time is a bounce, not a catch.
  bool catchPrecedesBounce(double catchTime, double firstBounceTime) =>
      catchTime < firstBounceTime;

  /// Boundary wins an exact tie against pickup.
  bool pickupPrecedesBoundary(double pickupTime, double boundaryTime) =>
      pickupTime < boundaryTime;
}

final class ChaserSelection {
  const ChaserSelection({required this.primaryId, required this.backupId});

  final int primaryId;
  final int backupId;
}

final class FieldingResolver {
  const FieldingResolver({this.tuning = const GameplayTuning()});

  final GameplayTuning tuning;

  ChaserSelection selectChasers(
    List<FielderState> fielders,
    FieldVector predictedPosition,
  ) {
    if (fielders.length < 2) {
      throw ArgumentError('At least two fielders are required');
    }
    final ranked = [...fielders]
      ..sort((a, b) {
        final aTime =
            reactionDelay(a) +
            a.position.distanceTo(predictedPosition) / tuning.fielderSpeed;
        final bTime =
            reactionDelay(b) +
            b.position.distanceTo(predictedPosition) / tuning.fielderSpeed;
        final comparison = aTime.compareTo(bTime);
        return comparison != 0 ? comparison : a.id.compareTo(b.id);
      });
    return ChaserSelection(primaryId: ranked[0].id, backupId: ranked[1].id);
  }

  double reactionDelay(FielderState fielder) {
    if (fielder.role == FielderRole.wicketkeeper) {
      return tuning.keeperReactionSeconds;
    }
    return fielder.position.length < 0.55
        ? tuning.closeReactionSeconds
        : tuning.deepReactionSeconds;
  }

  double catchChance({
    required FielderState fielder,
    required ContactOutcome contact,
    required bool runningCatch,
    required bool arrivedEarly,
  }) {
    var chance = fielder.role == FielderRole.wicketkeeper
        ? tuning.keeperCatchChance
        : tuning.baseCatchChance;
    if (runningCatch) chance -= 0.12;
    if (contact.power > 0.85) chance -= 0.12;
    if (contact.type == ContactType.edge) chance += 0.06;
    if (arrivedEarly) chance += 0.08;
    return chance.clamp(tuning.catchChanceMinimum, tuning.catchChanceMaximum);
  }

  RiskLevel riskForMargin(double marginSeconds) {
    if (marginSeconds > tuning.safeMarginSeconds) return RiskLevel.safe;
    if (marginSeconds < tuning.dangerMarginSeconds) return RiskLevel.danger;
    return RiskLevel.close;
  }

  /// The runner is safe when crease and stump break are simultaneous.
  bool isRunOut({required int stumpBreakMicros, required int creaseMicros}) =>
      stumpBreakMicros < creaseMicros;
}

final class ObjectiveUpdate {
  const ObjectiveUpdate(this.progress, this.completed);

  final int progress;
  final bool completed;
}

final class ScoringResolver {
  const ScoringResolver._();

  static String historyToken({
    required ExtraType extra,
    required int totalRuns,
    required int batAndRunningRuns,
    required int boundary,
    required DismissalType dismissal,
  }) {
    final parts = <String>[];
    if (extra == ExtraType.wide) parts.add('WD');
    if (extra == ExtraType.noBall) parts.add('NB');
    if (boundary > 0) {
      parts.add('$boundary');
    } else if (batAndRunningRuns > 0) {
      parts.add('$batAndRunningRuns');
    } else if (extra == ExtraType.none && totalRuns == 0) {
      parts.add('0');
    }
    if (dismissal != DismissalType.none) {
      parts.add(switch (dismissal) {
        DismissalType.bowled => 'BOWLED',
        DismissalType.caught => 'CAUGHT',
        DismissalType.runOut => 'RUN OUT',
        DismissalType.none => '',
      });
    }
    return parts.join('+');
  }

  static ObjectiveUpdate updateObjective(
    ObjectiveType objective,
    int currentProgress,
    BallResult result,
  ) {
    final progress = switch (objective) {
      ObjectiveType.twoBoundaries =>
        currentProgress + (result.isBoundary ? 1 : 0),
      ObjectiveType.sixRunsFirstThreeLegalBalls =>
        currentProgress + (result.legalBallsBefore < 3 ? result.totalRuns : 0),
      ObjectiveType.completeDouble => math.max(
        currentProgress,
        result.completedRunningRuns >= 2 ? 1 : 0,
      ),
    };
    final threshold = switch (objective) {
      ObjectiveType.twoBoundaries => 2,
      ObjectiveType.sixRunsFirstThreeLegalBalls => 6,
      ObjectiveType.completeDouble => 1,
    };
    return ObjectiveUpdate(progress, progress >= threshold);
  }

  static int nextCombo(int currentCombo, BallResult result) {
    if (result.isProductiveContact && !result.isWicket) {
      return math.min(3, currentCombo + 1);
    }
    if (result.isWicket ||
        (result.contactType != ContactType.none && result.totalRuns == 0)) {
      return 1;
    }
    // A no-contact extra does not alter combo.
    return currentCombo;
  }

  static int chargeFor(BallResult result, int increasedCombo) {
    final scoredFromContact = result.runsOffBat + result.completedRunningRuns;
    if (result.contactType == ContactType.none || scoredFromContact <= 0) {
      return 0;
    }
    final base = result.boundary == 6
        ? 3
        : result.boundary == 4
        ? 2
        : 1;
    return base + math.max(0, increasedCombo - 1);
  }

  static int starsForWin({
    required bool objectiveCompleted,
    required int legalBalls,
    required int wickets,
    int maximumLegalBalls = 18,
  }) {
    var stars = 1;
    if (objectiveCompleted) stars++;
    // Early finish (2+ balls spare) or an unbeaten chase earns the third star.
    if (maximumLegalBalls - legalBalls >= 2 || wickets == 0) stars++;
    return stars;
  }
}
```

### P.8 `final_over/lib/application/application.dart`

<sub>3 lines</sub>

```dart
export 'game_command.dart';
export 'gameplay_event.dart';
export 'match_controller.dart';
```

### P.9 `final_over/lib/application/game_command.dart`

<sub>90 lines</sub>

```dart
import 'package:final_over/domain/models.dart';

sealed class GameCommand {
  const GameCommand();

  const factory GameCommand.start() = StartCommand;
  const factory GameCommand.selectElevation(Elevation elevation) =
      SelectElevationCommand;
  const factory GameCommand.selectDirection(ShotDirection direction) =
      SelectDirectionCommand;
  const factory GameCommand.swing(
    ShotDirection direction, {
    double? charge,
    Elevation? elevation,
  }) = SwingCommand;
  const factory GameCommand.activatePowerShot() = ActivatePowerShotCommand;
  const factory GameCommand.startRun() = StartRunCommand;
  const factory GameCommand.holdBall() = HoldBallCommand;
  const factory GameCommand.turnBack() = TurnBackCommand;
  const factory GameCommand.pause() = PauseCommand;
  const factory GameCommand.resume() = ResumeCommand;
  const factory GameCommand.restart({int? seed, int? target}) = RestartCommand;
  const factory GameCommand.appBackgrounded() = AppBackgroundedCommand;
  const factory GameCommand.quitToHome() = QuitToHomeCommand;
}

final class StartCommand extends GameCommand {
  const StartCommand();
}

final class SelectElevationCommand extends GameCommand {
  const SelectElevationCommand(this.elevation);
  final Elevation elevation;
}

final class SelectDirectionCommand extends GameCommand {
  const SelectDirectionCommand(this.direction);
  final ShotDirection direction;
}

final class SwingCommand extends GameCommand {
  const SwingCommand(this.direction, {this.charge, this.elevation});
  final ShotDirection direction;

  /// Backlift at the moment of release, 0..1. See [SwingIntent.charge].
  final double? charge;

  /// Shot elevation chosen at the moment of the swing (tap = ground, upward
  /// flick = loft). When null the pre-selected [MatchState.selectedElevation]
  /// stands. See [MatchController].
  final Elevation? elevation;
}

final class ActivatePowerShotCommand extends GameCommand {
  const ActivatePowerShotCommand();
}

final class StartRunCommand extends GameCommand {
  const StartRunCommand();
}

final class HoldBallCommand extends GameCommand {
  const HoldBallCommand();
}

final class TurnBackCommand extends GameCommand {
  const TurnBackCommand();
}

final class PauseCommand extends GameCommand {
  const PauseCommand();
}

final class ResumeCommand extends GameCommand {
  const ResumeCommand();
}

final class RestartCommand extends GameCommand {
  const RestartCommand({this.seed, this.target});
  final int? seed;
  final int? target;
}

final class AppBackgroundedCommand extends GameCommand {
  const AppBackgroundedCommand();
}

final class QuitToHomeCommand extends GameCommand {
  const QuitToHomeCommand();
}
```

### P.10 `final_over/lib/application/gameplay_event.dart`

<sub>40 lines</sub>

```dart
enum GameplayEventType {
  matchStarted,
  deliveryPrepared,
  ballReleased,
  swingAccepted,
  powerShotActivated,
  extraAwarded,
  contactResolved,
  cameraTransitionStarted,
  runStarted,
  runCompleted,
  runnerTurnedBack,
  catchTaken,
  catchDropped,
  ballPickedUp,
  throwStarted,
  runOut,
  boundary,
  wicket,
  deliveryCompleted,
  overComplete,
  fieldLayoutChanged,
  paused,
  resumed,
  matchEnded,
  quitToHome,
}

/// A rendering-friendly event. Payload values are primitives or domain values.
final class GameplayEvent {
  GameplayEvent({
    required this.type,
    required this.simulationMicros,
    Map<String, Object?> payload = const {},
  }) : payload = Map.unmodifiable(payload);

  final GameplayEventType type;
  final int simulationMicros;
  final Map<String, Object?> payload;
}
```

### P.11 `final_over/lib/application/match_controller.dart`

<sub>1185 lines</sub>

```dart
import 'dart:async';
import 'dart:math' as math;

import 'package:final_over/domain/delivery_generator.dart';
import 'package:final_over/domain/deterministic_random.dart';
import 'package:final_over/domain/gameplay_tuning.dart';
import 'package:final_over/domain/models.dart';
import 'package:final_over/domain/resolvers.dart';
import 'game_command.dart';
import 'gameplay_event.dart';

/// The sole gameplay authority. Rendering may send commands and observe state,
/// but it never mutates score or simulation data directly.
final class MatchController {
  MatchController({
    this.tuning = const GameplayTuning(),
    DeliveryGenerator? deliveryGenerator,
  }) : _deliveryGenerator =
           deliveryGenerator ?? DeliveryGenerator(tuning: tuning),
       _contactResolver = ContactResolver(tuning: tuning),
       _physicsResolver = PhysicsResolver(tuning: tuning),
       _fieldingResolver = FieldingResolver(tuning: tuning);

  final GameplayTuning tuning;
  final DeliveryGenerator _deliveryGenerator;
  final ContactResolver _contactResolver;
  final PhysicsResolver _physicsResolver;
  final FieldingResolver _fieldingResolver;
  final StreamController<MatchState> _stateController =
      StreamController<MatchState>.broadcast(sync: true);
  final StreamController<GameplayEvent> _eventController =
      StreamController<GameplayEvent>.broadcast(sync: true);

  MatchState _state = MatchState.initial();
  int _accumulatorMicros = 0;
  bool _disposed = false;
  final List<DeliverySpec> _deliveries = [];
  int? _primaryChaserId;
  int? _backupChaserId;
  bool _catchResolved = false;

  MatchState get state => _state;
  Stream<MatchState> get stateStream => _stateController.stream;
  Stream<GameplayEvent> get eventStream => _eventController.stream;

  SimulationSnapshot get snapshot => SimulationSnapshot(
    simulationMicros: _state.simulationMicros,
    phase: _state.phase,
    ball: _state.ball,
    cameraTransition: _state.cameraTransition,
    runner: _state.runner,
    fielders: _state.fielders,
    risk: _state.runner.risk,
    canRun: _state.canRun,
  );

  /// Starts at the intro. [target] is injectable from 32-66 for tests/debug;
  /// production callers omit it to use the approved seeded target set.
  void startMatch({required int seed, int? target}) {
    _ensureAlive();
    if (target != null &&
        (target < GameplayTuning.targetMinimum ||
            target > GameplayTuning.targetMaximum)) {
      throw RangeError.range(
        target,
        GameplayTuning.targetMinimum,
        GameplayTuning.targetMaximum,
        'target',
      );
    }
    _accumulatorMicros = 0;
    _deliveries.clear();
    _resetTransientSimulation();

    final selectionRandom = SeedStreams.forStream(
      seed,
      0,
      RandomStream.objective,
    );
    final int selectedTarget =
        target ?? selectionRandom.choose<int>(GameplayTuning.targetOptions);
    final objectives = <ObjectiveType>[
      if (selectedTarget >= 8) ObjectiveType.twoBoundaries,
      if (selectedTarget >= 6) ObjectiveType.sixRunsFirstThreeLegalBalls,
      ObjectiveType.completeDouble,
    ];
    final objective = selectionRandom.choose(objectives);
    final bowlers = _shuffleBowlers(selectionRandom);
    final openingField = GameplayTuning.fieldLayoutFor(
      matchSeed: seed,
      physicalOrdinal: 1,
    );
    _setState(
      MatchState.initial().copyWith(
        matchSeed: seed,
        target: selectedTarget,
        phase: MatchPhase.matchIntro,
        objective: objective,
        fielders: openingField.fielders,
        maximumLegalBalls: tuning.maximumLegalBalls,
        ballsPerOver: tuning.ballsPerOver,
        maximumOvers: tuning.maximumOvers,
        bowlerIndex: 0,
        bowlers: bowlers,
      ),
    );
    _emit(GameplayEventType.matchStarted, {
      'seed': seed,
      'target': selectedTarget,
      'objective': objective,
      'bowler': bowlers.first.name,
    });
  }

  List<BowlerProfile> _shuffleBowlers(DeterministicRandom random) {
    final bowlers = List<BowlerProfile>.from(BowlerProfile.attack);
    for (var i = bowlers.length - 1; i > 0; i--) {
      final j = random.nextInt(i + 1);
      final tmp = bowlers[i];
      bowlers[i] = bowlers[j];
      bowlers[j] = tmp;
    }
    return bowlers;
  }

  /// Positional convenience for simulations and simple host integrations.
  void startMatchWithSeed(int seed, [int? target]) =>
      startMatch(seed: seed, target: target);

  void dispatch(GameCommand command) {
    _ensureAlive();
    switch (command) {
      case StartCommand():
        if (_state.phase == MatchPhase.matchIntro) _prepareDelivery();
      case SelectElevationCommand(:final elevation):
        if (_state.canConfigureShot) {
          _setState(_state.copyWith(selectedElevation: elevation));
        }
      case SelectDirectionCommand(:final direction):
        if (_state.canConfigureShot) {
          _setState(_state.copyWith(selectedDirection: direction));
        }
      case SwingCommand(:final direction, :final charge, :final elevation):
        _acceptSwing(direction, elevation, charge);
      case ActivatePowerShotCommand():
        _activatePowerShot();
      case StartRunCommand():
        _startRun();
      case HoldBallCommand():
        _holdBall();
      case TurnBackCommand():
        _turnBack();
      case PauseCommand():
        _pause();
      case ResumeCommand():
        _resume();
      case RestartCommand(:final seed, :final target):
        startMatch(seed: seed ?? _state.matchSeed + 1, target: target);
      case AppBackgroundedCommand():
        _pause();
      case QuitToHomeCommand():
        _quit();
    }
  }

  /// Adds elapsed wall time to a deterministic fixed 60 Hz accumulator.
  void step(Duration elapsed) {
    _ensureAlive();
    if (elapsed.isNegative || elapsed == Duration.zero || _state.isPaused) {
      return;
    }
    final bounded = math.min(elapsed.inMicroseconds, tuning.maximumFrameMicros);
    _accumulatorMicros += bounded;
    while (_accumulatorMicros >= tuning.fixedStepMicros) {
      _accumulatorMicros -= tuning.fixedStepMicros;
      _fixedTick(tuning.fixedStepMicros);
    }
  }

  void _fixedTick(int micros) {
    if (_state.isTerminal ||
        _state.phase == MatchPhase.idle ||
        _state.phase == MatchPhase.matchIntro ||
        _state.phase == MatchPhase.paused ||
        _state.phase == MatchPhase.quit) {
      return;
    }
    _setState(
      _state.copyWith(
        simulationMicros: _state.simulationMicros + micros,
        phaseElapsedMicros: _state.phaseElapsedMicros + micros,
      ),
    );

    switch (_state.phase) {
      case MatchPhase.deliveryPreparation:
        if (_state.phaseElapsedMicros >= tuning.deliveryPreparationMicros) {
          _enterPhase(MatchPhase.bowlerRunUp);
        }
      case MatchPhase.bowlerRunUp:
        if (_state.phaseElapsedMicros >= tuning.runUpMicros) {
          _enterPhase(MatchPhase.incomingBall);
          _emit(GameplayEventType.ballReleased, {
            'delivery': _state.currentDelivery,
          });
        }
      case MatchPhase.incomingBall:
        _advanceIncomingBall();
      case MatchPhase.contact:
        if (_state.phaseElapsedMicros >= tuning.impactHoldMicros) {
          final contact = _state.contactOutcome;
          if (contact != null && contact.madeContact) {
            _launchContactedBall(contact);
          } else {
            _finalizeDelivery();
          }
        }
      case MatchPhase.cameraTransition ||
          MatchPhase.fieldPlay ||
          MatchPhase.runDecision ||
          MatchPhase.runnersMoving ||
          MatchPhase.throwInProgress:
        _advanceLiveBall(micros);
      case MatchPhase.deliveryResult:
        if (_state.phaseElapsedMicros >= tuning.deliveryResultMicros) {
          _enterPhase(MatchPhase.betweenBalls);
        }
      case MatchPhase.betweenBalls:
        if (_state.phaseElapsedMicros >= tuning.betweenBallsMicros) {
          _prepareDelivery();
        }
      case MatchPhase.idle ||
          MatchPhase.matchIntro ||
          MatchPhase.paused ||
          MatchPhase.won ||
          MatchPhase.lost ||
          MatchPhase.quit:
        break;
    }
  }

  void _prepareDelivery() {
    if (_state.isTerminal || _state.phase == MatchPhase.quit) return;
    final ordinal = _state.physicalDeliveries + 1;
    final fieldLayout = GameplayTuning.fieldLayoutFor(
      matchSeed: _state.matchSeed,
      physicalOrdinal: ordinal,
    );
    final expectedContact =
        _state.simulationMicros +
        tuning.deliveryPreparationMicros +
        tuning.runUpMicros +
        tuning.incomingToContactMicros;
    final delivery = _deliveryGenerator.generate(
      matchSeed: _state.matchSeed,
      physicalOrdinal: ordinal,
      legalBalls: _state.legalBalls,
      score: _state.score,
      target: _state.target,
      history: _state.history,
      previousDeliveries: _deliveries,
      expectedContactMicros: expectedContact,
      bowler: _state.currentBowler,
    );
    _deliveries.add(delivery);
    _resetTransientSimulation();
    _setState(
      _state.copyWith(
        phase: MatchPhase.deliveryPreparation,
        phaseElapsedMicros: 0,
        physicalDeliveries: ordinal,
        currentDelivery: delivery,
        currentDeliveryFreeHit: _state.freeHit,
        swingIntent: null,
        contactOutcome: null,
        ball: null,
        cameraTransition: 0,
        runner: const RunnerState(),
        fielders: fieldLayout.fielders,
        ledger: const DeliveryLedger(),
        pendingRuns: 0,
        pendingExtras: 0,
        pendingBatRuns: 0,
        deliveryFinalized: false,
        canRun: false,
        holdRequested: false,
        ballHeld: false,
        pickupDecisionMicros: 0,
        throwArrivalMicros: 0,
        endReason: null,
      ),
    );
    _emit(GameplayEventType.deliveryPrepared, {'delivery': delivery});
    if (ordinal > 1) {
      _emit(GameplayEventType.fieldLayoutChanged, {
        'id': fieldLayout.id,
        'label': fieldLayout.label,
        'deliveryOrdinal': ordinal,
      });
    }
  }

  void _advanceIncomingBall() {
    final delivery = _state.currentDelivery;
    if (delivery == null) return;
    final now = _state.simulationMicros;
    if (now >= delivery.expectedContactMicros && !_state.ledger.extraApplied) {
      if (delivery.extra != ExtraType.none) _applyExtra(delivery.extra);
      if (_state.isTerminal || _state.deliveryFinalized) return;
      if (delivery.isWide) {
        // Wides are dead immediately: there is no wide running in this MVP.
        _finalizeDelivery();
        return;
      }
    }
    final swing = _state.swingIntent;
    if (swing != null && now >= delivery.expectedContactMicros) {
      _resolveContact(swing);
      return;
    }
    if (now >= delivery.expectedContactMicros + tuning.lateSwingGraceMicros) {
      _resolveContact(null);
    }
  }

  void _applyExtra(ExtraType extra) {
    if (_state.ledger.extraApplied || extra == ExtraType.none) return;
    final ledger = _state.ledger.copyWith(extraRuns: 1, extraApplied: true);
    _setState(_state.copyWith(ledger: ledger, pendingExtras: 1));
    _emit(GameplayEventType.extraAwarded, {'extra': extra, 'runs': 1});
    // A target-winning no-ball/wide extra ends the delivery before contact or
    // any subsequent wicket processing.
    if (_state.score >= _state.target) _finalizeDelivery();
  }

  void _acceptSwing(
    ShotDirection direction, [
    Elevation? elevation,
    double? charge,
  ]) {
    if (!_state.canSwing) {
      return;
    }
    final intent = SwingIntent(
      direction: direction,
      inputMicros: _state.simulationMicros,
      powerShot: _state.powerShotArmed,
      charge: charge?.clamp(0.0, 1.0),
    );
    // The swing itself is the commit point: a swipe/tap chooses direction (via
    // the intent) and elevation (here) at release, bypassing the setup-phase
    // gate. _resolveContact reads _state.selectedElevation, so writing it now
    // covers both the immediate and deferred resolution paths.
    _setState(
      _state.copyWith(
        swingIntent: intent,
        selectedElevation: elevation ?? _state.selectedElevation,
        powerShotArmed: intent.powerShot ? false : _state.powerShotArmed,
        powerSegments: intent.powerShot ? 0 : _state.powerSegments,
      ),
    );
    _emit(GameplayEventType.swingAccepted, {
      'direction': direction,
      'powerShot': intent.powerShot,
    });
    final delivery = _state.currentDelivery!;
    if (_state.phase == MatchPhase.incomingBall &&
        _state.simulationMicros >= delivery.expectedContactMicros &&
        !delivery.isWide) {
      _resolveContact(intent);
    }
  }

  void _resolveContact(SwingIntent? swing) {
    if (_state.phase != MatchPhase.incomingBall ||
        _state.contactOutcome != null ||
        _state.deliveryFinalized) {
      return;
    }
    final delivery = _state.currentDelivery!;
    final hasInput = swing != null;
    final errorMs = hasInput
        ? ((swing.inputMicros - delivery.expectedContactMicros) / 1000).round()
        : tuning.poorWindowMs + 1;
    final random = SeedStreams.forStream(
      _state.matchSeed,
      delivery.ordinal,
      RandomStream.contact,
    );
    final outcome = _contactResolver.resolve(
      delivery: delivery,
      elevation: _state.selectedElevation,
      direction: swing?.direction ?? ShotDirection.straight,
      timingErrorMs: errorMs,
      hasInput: hasInput,
      powerShot: swing?.powerShot ?? false,
      random: random,
      charge: swing?.charge,
    );
    var ledger = _state.ledger;
    final protectedDelivery =
        _state.currentDeliveryFreeHit || delivery.isNoBall;
    if (outcome.type == ContactType.miss &&
        outcome.bowledThreat &&
        !protectedDelivery) {
      ledger = ledger.copyWith(dismissal: DismissalType.bowled);
    }
    _setState(
      _state.copyWith(
        phase: MatchPhase.contact,
        phaseElapsedMicros: 0,
        contactOutcome: outcome,
        ledger: ledger,
      ),
    );
    _emit(GameplayEventType.contactResolved, {'outcome': outcome});
  }

  void _launchContactedBall(ContactOutcome contact) {
    final ball = _physicsResolver.launch(contact);
    final predicted = _predictPosition(ball, 2.0);
    final fielders = _state.fielders
        .map(
          (fielder) => fielder.copyWith(
            motion: FielderMotion.reacting,
            reactionRemainingSeconds: _fieldingResolver.reactionDelay(fielder),
          ),
        )
        .toList(growable: false);
    final chasers = _fieldingResolver.selectChasers(fielders, predicted);
    _primaryChaserId = chasers.primaryId;
    _backupChaserId = chasers.backupId;
    _setState(
      _state.copyWith(
        phase: MatchPhase.cameraTransition,
        phaseElapsedMicros: 0,
        ball: ball,
        fielders: fielders,
        cameraTransition: 0,
        canRun: false,
      ),
    );
    _emit(GameplayEventType.cameraTransitionStarted, {
      'primaryFielder': _primaryChaserId,
      'backupFielder': _backupChaserId,
    });
  }

  FieldVector _predictPosition(BallKinematics initial, double seconds) {
    var ball = initial;
    final steps = math.max(1, (seconds * 60).round());
    for (var i = 0; i < steps; i++) {
      ball = _physicsResolver.step(ball, 1 / 60);
      if (ball.position.length >= tuning.boundaryRadius || ball.stopped) break;
    }
    return ball.position;
  }

  void _advanceLiveBall(int micros) {
    if (_state.deliveryFinalized) return;
    if (_advanceRunner(micros)) return;

    final seconds = micros / Duration.microsecondsPerSecond;
    var camera = _state.cameraTransition;
    if (camera < 1) {
      camera = math.min(1.0, camera + micros / tuning.cameraTransitionMicros);
      _setState(
        _state.copyWith(
          cameraTransition: camera,
          canRun:
              camera >= 0.70 &&
              !_state.holdRequested &&
              !_state.runner.active &&
              _state.runner.completedRuns < tuning.maximumRuns,
        ),
      );
    }

    if (!_state.ballHeld) {
      final currentBall = _state.ball;
      if (currentBall == null) return;
      final nextBall = _physicsResolver.step(currentBall, seconds);
      _setState(_state.copyWith(ball: nextBall));

      // Boundary is evaluated before pickup; an exact tie is a boundary.
      final boundary = _physicsResolver.boundaryValue(
        nextBall,
        _state.contactOutcome!.elevation,
      );
      if (boundary > 0) {
        _awardBoundary(boundary);
        return;
      }

      _moveFielders(seconds);
      if (_state.deliveryFinalized || _state.ballHeld) return;
      _resolveCatchOrPickup();
      if (_state.deliveryFinalized) return;
    }

    if (_state.ballHeld && !_state.runner.active) {
      if (_state.holdRequested ||
          _state.runner.completedRuns >= tuning.maximumRuns ||
          (_state.pickupDecisionMicros > 0 &&
              _state.simulationMicros >= _state.pickupDecisionMicros)) {
        _finalizeDelivery();
        return;
      }
    }

    if (_state.canRun && !_state.runner.active && !_state.holdRequested) {
      _setState(
        _state.copyWith(runner: _state.runner.copyWith(risk: _currentRisk())),
      );
    }

    if (_state.cameraTransition >= 1 &&
        _state.phase == MatchPhase.cameraTransition) {
      _enterPhase(MatchPhase.fieldPlay);
    }
  }

  void _moveFielders(double seconds) {
    final ball = _state.ball!;
    final updated = <FielderState>[];
    for (final fielder in _state.fielders) {
      final isPrimary = fielder.id == _primaryChaserId;
      final isBackup = fielder.id == _backupChaserId;
      if (!isPrimary && !isBackup) {
        updated.add(fielder);
        continue;
      }
      var reaction = math.max(0.0, fielder.reactionRemainingSeconds - seconds);
      if (reaction > 0) {
        updated.add(fielder.copyWith(reactionRemainingSeconds: reaction));
        continue;
      }
      final target = isPrimary
          ? ball.position
          : FieldVector.lerp(fielder.homePosition, ball.position, 0.72);
      final delta = target - fielder.position;
      final speed =
          tuning.fielderSpeed * (isPrimary ? 1 : tuning.backupSpeedFactor);
      final travel = math.min(delta.length, speed * seconds);
      final velocity = delta.length == 0
          ? FieldVector.zero
          : delta.normalized * speed;
      updated.add(
        fielder.copyWith(
          position:
              fielder.position +
              (delta.length == 0
                  ? FieldVector.zero
                  : delta.normalized * travel),
          velocity: velocity,
          motion: isPrimary ? FielderMotion.chasing : FielderMotion.backup,
          reactionRemainingSeconds: 0,
        ),
      );
    }
    _setState(_state.copyWith(fielders: updated));
  }

  void _resolveCatchOrPickup() {
    final ball = _state.ball!;
    final primaryIndex = _state.fielders.indexWhere(
      (fielder) => fielder.id == _primaryChaserId,
    );
    if (primaryIndex < 0) return;
    final primary = _state.fielders[primaryIndex];
    final distance = primary.position.distanceTo(ball.position);
    if (!_catchResolved &&
        ball.aerial &&
        ball.height >= tuning.catchHeight &&
        distance <= tuning.catchRadius) {
      _catchResolved = true;
      final contact = _state.contactOutcome!;
      final chance = _fieldingResolver.catchChance(
        fielder: primary,
        contact: contact,
        runningCatch: primary.velocity.length > 0.02,
        arrivedEarly: distance < tuning.catchRadius * 0.55,
      );
      final catchRandom = SeedStreams.forStream(
        _state.matchSeed,
        _state.currentDelivery!.ordinal,
        RandomStream.catchOutcome,
      );
      if (catchRandom.nextBool(chance)) {
        final protected =
            _state.currentDeliveryFreeHit || _state.currentDelivery!.isNoBall;
        _emit(GameplayEventType.catchTaken, {
          'fielderId': primary.id,
          'protected': protected,
        });
        if (protected) {
          _pickUpBall(primary.id);
        } else {
          final ledger = _state.ledger.copyWith(
            dismissal: DismissalType.caught,
            completedRuns: 0,
          );
          _setState(
            _state.copyWith(
              ledger: ledger,
              pendingRuns: 0,
              runner: const RunnerState(),
            ),
          );
          _finalizeDelivery();
        }
        return;
      }
      final dropRandom = SeedStreams.forStream(
        _state.matchSeed,
        _state.currentDelivery!.ordinal,
        RandomStream.drop,
      );
      final retained = dropRandom.range(
        tuning.dropSpeedMinimum,
        tuning.dropSpeedMaximum,
      );
      _setState(
        _state.copyWith(
          ball: ball.copyWith(
            velocity: ball.velocity * retained,
            height: 0,
            verticalVelocity: 0,
            aerial: false,
            firstBounceOccurred: true,
          ),
        ),
      );
      _emit(GameplayEventType.catchDropped, {'fielderId': primary.id});
      return;
    }

    if (!ball.aerial && distance <= tuning.ballPickupRadius) {
      _pickUpBall(primary.id);
    }
  }

  void _pickUpBall(int fielderId) {
    if (_state.ballHeld || _state.deliveryFinalized) return;
    final fielders = _state.fielders
        .map(
          (fielder) => fielder.id == fielderId
              ? fielder.copyWith(
                  hasBall: true,
                  motion: FielderMotion.carrying,
                  velocity: FieldVector.zero,
                )
              : fielder,
        )
        .toList(growable: false);
    _setState(
      _state.copyWith(
        fielders: fielders,
        ballHeld: true,
        ball: _state.ball?.copyWith(
          velocity: FieldVector.zero,
          verticalVelocity: 0,
          aerial: false,
          stopped: true,
        ),
        phase: _state.runner.active
            ? MatchPhase.throwInProgress
            : MatchPhase.runDecision,
        phaseElapsedMicros: 0,
        canRun:
            !_state.holdRequested &&
            _state.runner.completedRuns < tuning.maximumRuns,
        pickupDecisionMicros:
            _state.simulationMicros + tuning.pickupDecisionMicros,
      ),
    );
    _emit(GameplayEventType.ballPickedUp, {'fielderId': fielderId});
    if (_state.runner.active) _startThrow(fielderId);
    if (_state.holdRequested && !_state.runner.active) _finalizeDelivery();
  }

  void _awardBoundary(int boundary) {
    final ledger = _state.ledger.copyWith(
      batRuns: boundary,
      completedRuns: 0,
      boundary: boundary,
    );
    _setState(
      _state.copyWith(
        ledger: ledger,
        pendingBatRuns: boundary,
        pendingRuns: 0,
        runner: const RunnerState(),
        canRun: false,
      ),
    );
    _emit(GameplayEventType.boundary, {'runs': boundary});
    _finalizeDelivery();
  }

  void _startRun() {
    if (!_state.canRun ||
        _state.runner.active ||
        _state.holdRequested ||
        _state.deliveryFinalized ||
        _state.runner.completedRuns >= tuning.maximumRuns) {
      return;
    }
    final runner = _state.runner.copyWith(
      active: true,
      returning: false,
      runNumber: _state.runner.completedRuns + 1,
      progress: 0,
      risk: _currentRisk(),
    );
    _setState(
      _state.copyWith(
        runner: runner,
        canRun: false,
        phase: MatchPhase.runnersMoving,
        phaseElapsedMicros: 0,
        pickupDecisionMicros: 0,
      ),
    );
    _emit(GameplayEventType.runStarted, {'run': runner.runNumber});
    if (_state.ballHeld) {
      final holder = _state.fielders
          .where((fielder) => fielder.hasBall)
          .map((fielder) => fielder.id)
          .firstOrNull;
      if (holder != null) _startThrow(holder);
    }
  }

  void _startThrow(int fielderId) {
    if (!_state.runner.active || _state.throwArrivalMicros > 0) return;
    final holder = _state.fielders.firstWhere(
      (fielder) => fielder.id == fielderId,
    );
    final targetEnd = _state.runner.runNumber.isOdd
        ? const FieldVector(0, -0.21)
        : const FieldVector(0, 0.21);
    final travelSeconds =
        holder.position.distanceTo(targetEnd) / tuning.throwSpeed + 0.10;
    final arrival =
        _state.simulationMicros +
        (travelSeconds * Duration.microsecondsPerSecond).round();
    final fielders = _state.fielders
        .map(
          (fielder) => fielder.id == fielderId
              ? fielder.copyWith(motion: FielderMotion.throwing)
              : fielder,
        )
        .toList(growable: false);
    _setState(
      _state.copyWith(
        fielders: fielders,
        throwArrivalMicros: arrival,
        phase: MatchPhase.throwInProgress,
        phaseElapsedMicros: 0,
        runner: _state.runner.copyWith(risk: _currentRisk(arrival)),
      ),
    );
    _emit(GameplayEventType.throwStarted, {
      'fielderId': fielderId,
      'arrivalMicros': arrival,
    });
  }

  bool _advanceRunner(int micros) {
    final runner = _state.runner;
    if (!runner.active) return false;
    final tickEnd = _state.simulationMicros;
    final tickStart = tickEnd - micros;
    final durationMicros =
        (tuning.runDurationSeconds * Duration.microsecondsPerSecond).round();
    final distanceRemaining = runner.returning
        ? runner.progress
        : 1 - runner.progress;
    final creaseMicros =
        tickStart + (distanceRemaining * durationMicros).round();
    final throwMicros = _state.throwArrivalMicros;

    if (throwMicros > 0 &&
        throwMicros <= tickEnd &&
        throwMicros < creaseMicros) {
      // Strict comparison makes an exact crease/stump tie safe.
      final elapsedFraction = (throwMicros - tickStart) / durationMicros;
      final progress = runner.returning
          ? math.max(0.0, runner.progress - elapsedFraction)
          : math.min(1.0, runner.progress + elapsedFraction);
      _setState(
        _state.copyWith(
          runner: runner.copyWith(active: false, progress: progress),
          ledger: _state.ledger.copyWith(dismissal: DismissalType.runOut),
          canRun: false,
        ),
      );
      _emit(GameplayEventType.runOut, {'run': runner.runNumber});
      _finalizeDelivery();
      return true;
    }

    if (creaseMicros <= tickEnd) {
      if (runner.returning) {
        _setState(
          _state.copyWith(
            runner: runner.copyWith(
              active: false,
              returning: false,
              progress: 0,
            ),
            throwArrivalMicros: 0,
            phase: MatchPhase.runDecision,
            phaseElapsedMicros: 0,
            canRun: !_state.holdRequested,
            pickupDecisionMicros: _state.ballHeld
                ? tickEnd + tuning.pickupDecisionMicros
                : 0,
          ),
        );
        return false;
      }
      _completeRun();
      return _state.deliveryFinalized || _state.isTerminal;
    }

    final delta = micros / durationMicros;
    final progress = runner.returning
        ? math.max(0.0, runner.progress - delta)
        : math.min(1.0, runner.progress + delta);
    _setState(
      _state.copyWith(
        runner: runner.copyWith(progress: progress, risk: _currentRisk()),
      ),
    );
    return false;
  }

  void _completeRun() {
    final completed = _state.runner.completedRuns + 1;
    final ledger = _state.ledger.copyWith(completedRuns: completed);
    _setState(
      _state.copyWith(
        ledger: ledger,
        pendingRuns: completed,
        runner: RunnerState(completedRuns: completed),
        throwArrivalMicros: 0,
        phase: MatchPhase.runDecision,
        phaseElapsedMicros: 0,
        canRun: completed < tuning.maximumRuns && !_state.holdRequested,
        pickupDecisionMicros: _state.ballHeld
            ? _state.simulationMicros + tuning.pickupDecisionMicros
            : 0,
      ),
    );
    _emit(GameplayEventType.runCompleted, {'run': completed});
    // A completed winning run is authoritative before a later stump break.
    if (_state.score >= _state.target) {
      _finalizeDelivery();
    } else if (_state.ballHeld && completed >= tuning.maximumRuns) {
      _finalizeDelivery();
    }
  }

  RiskLevel _currentRisk([int? knownThrowArrival]) {
    final durationMicros =
        (tuning.runDurationSeconds * Duration.microsecondsPerSecond).round();
    final runner = _state.runner;
    final remaining = runner.active
        ? (runner.returning ? runner.progress : 1 - runner.progress)
        : 1.0;
    final crease =
        _state.simulationMicros + (remaining * durationMicros).round();
    final throwArrival =
        knownThrowArrival ??
        (_state.throwArrivalMicros > 0
            ? _state.throwArrivalMicros
            : _estimatedThrowArrivalMicros());
    final margin = (throwArrival - crease) / Duration.microsecondsPerSecond;
    return _fieldingResolver.riskForMargin(margin);
  }

  int _estimatedThrowArrivalMicros() {
    final ball = _state.ball;
    if (ball == null) return _state.simulationMicros + 2000000;
    final runNumber = _state.runner.active
        ? _state.runner.runNumber
        : _state.runner.completedRuns + 1;
    final end = runNumber.isOdd
        ? const FieldVector(0, -0.21)
        : const FieldVector(0, 0.21);
    if (_state.ballHeld) {
      final holder = _state.fielders
          .where((fielder) => fielder.hasBall)
          .firstOrNull;
      final throwTime =
          (holder?.position ?? ball.position).distanceTo(end) /
              tuning.throwSpeed +
          0.10;
      return _state.simulationMicros +
          (throwTime * Duration.microsecondsPerSecond).round();
    }
    final primary = _state.fielders
        .where((fielder) => fielder.id == _primaryChaserId)
        .firstOrNull;
    final chaser =
        primary ??
        _state.fielders.reduce(
          (a, b) =>
              a.position.distanceTo(ball.position) <=
                  b.position.distanceTo(ball.position)
              ? a
              : b,
        );
    // Project the moving ball instead of treating its current position as a
    // stationary pickup point. That stationary estimate made every early run
    // look unsafe even when the ball was travelling into a gap.
    final predictedPickup = _predictPosition(ball, 1.0);
    final pickup = math.max(
      0.55,
      chaser.reactionRemainingSeconds +
          chaser.position.distanceTo(predictedPickup) / tuning.fielderSpeed,
    );
    final throwTime =
        predictedPickup.distanceTo(end) / tuning.throwSpeed + 0.10;
    return _state.simulationMicros +
        ((pickup + throwTime) * Duration.microsecondsPerSecond).round();
  }

  void _turnBack() {
    if (!_state.runner.canTurnBack ||
        _state.runner.progress > tuning.turnBackLimit) {
      return;
    }
    _setState(_state.copyWith(runner: _state.runner.copyWith(returning: true)));
    _emit(GameplayEventType.runnerTurnedBack, {'run': _state.runner.runNumber});
  }

  void _holdBall() {
    if (_state.deliveryFinalized ||
        !_isLiveBallPhase(_state.phase) ||
        _state.runner.active) {
      return;
    }
    _setState(_state.copyWith(holdRequested: true, canRun: false));
    // Before pickup, HOLD still lets a possible boundary finish.
    if (_state.ballHeld || _state.ball?.stopped == true) _finalizeDelivery();
  }

  void _activatePowerShot() {
    if (!_state.canConfigureShot ||
        _state.powerSegments < tuning.powerShotSegments ||
        _state.powerShotArmed) {
      return;
    }
    _setState(_state.copyWith(powerShotArmed: true));
    _emit(GameplayEventType.powerShotActivated);
  }

  void _finalizeDelivery() {
    if (_state.deliveryFinalized ||
        _state.ledger.finalized ||
        _state.currentDelivery == null) {
      return;
    }
    final delivery = _state.currentDelivery!;
    final ledger = _state.ledger.copyWith(finalized: true);
    final contact = _state.contactOutcome;
    final contactType = contact == null || !contact.acceptedSwing
        ? ContactType.none
        : contact.type;
    final timing = contact == null ? TimingGrade.miss : contact.timing;
    final token = ScoringResolver.historyToken(
      extra: delivery.extra,
      totalRuns: ledger.totalRuns,
      batAndRunningRuns: ledger.batRuns + ledger.completedRuns,
      boundary: ledger.boundary,
      dismissal: ledger.dismissal,
    );
    final result = BallResult(
      deliveryOrdinal: delivery.ordinal,
      legalBallsBefore: _state.legalBalls,
      legal: delivery.isLegal,
      extra: delivery.extra,
      extraRuns: ledger.extraRuns,
      runsOffBat: ledger.batRuns,
      completedRunningRuns: ledger.completedRuns,
      boundary: ledger.boundary,
      dismissal: ledger.dismissal,
      contactType: contactType,
      timing: timing,
      freeHitDelivery: _state.currentDeliveryFreeHit,
      historyToken: token,
    );

    final nextHistory = [..._state.history, result];
    final legalBalls = _state.legalBalls + (result.legal ? 1 : 0);
    final wickets = _state.wickets + (result.isWicket ? 1 : 0);
    final committedScore = _state.committedScore + ledger.totalRuns;
    final objectiveUpdate = ScoringResolver.updateObjective(
      _state.objective,
      _state.objectiveProgress,
      result,
    );

    final increasedCombo = result.isProductiveContact
        ? math.min(3, _state.combo + 1)
        : _state.combo;
    final charge = ScoringResolver.chargeFor(result, increasedCombo);
    final combo = result.isWicket
        ? 1
        : ScoringResolver.nextCombo(_state.combo, result);
    final powerSegments = math.min(
      tuning.powerShotSegments,
      _state.powerSegments + charge,
    );
    final nextFreeHit = switch (delivery.extra) {
      ExtraType.noBall => true,
      ExtraType.wide => _state.freeHit,
      ExtraType.none => false,
    };

    // History and legal-ball consumption are committed before terminal checks.
    var next = _state.copyWith(
      committedScore: committedScore,
      legalBalls: legalBalls,
      wickets: wickets,
      pendingRuns: 0,
      pendingExtras: 0,
      pendingBatRuns: 0,
      ledger: ledger,
      history: nextHistory,
      lastResult: result,
      deliveryFinalized: true,
      freeHit: nextFreeHit,
      combo: combo,
      powerSegments: powerSegments,
      objectiveProgress: objectiveUpdate.progress,
      objectiveCompleted: objectiveUpdate.completed,
      runner: RunnerState(completedRuns: ledger.completedRuns),
      canRun: false,
      throwArrivalMicros: 0,
      phase: MatchPhase.deliveryResult,
      phaseElapsedMicros: 0,
    );

    final won = committedScore >= next.target;
    if (won) {
      final stars = ScoringResolver.starsForWin(
        objectiveCompleted: objectiveUpdate.completed,
        legalBalls: legalBalls,
        wickets: wickets,
        maximumLegalBalls: tuning.maximumLegalBalls,
      );
      next = next.copyWith(
        phase: MatchPhase.won,
        stars: stars,
        endReason: MatchEndReason.targetReached,
      );
    } else if (wickets >= tuning.maximumWickets) {
      next = next.copyWith(
        phase: MatchPhase.lost,
        endReason: MatchEndReason.wicketsLost,
      );
    } else if (legalBalls >= tuning.maximumLegalBalls) {
      next = next.copyWith(
        phase: MatchPhase.lost,
        endReason: MatchEndReason.ballsExhausted,
      );
    } else if (result.legal &&
        legalBalls > 0 &&
        legalBalls % tuning.ballsPerOver == 0) {
      // Over complete — rotate to the next bowler before the next delivery.
      final nextBowlerIndex = math.min(
        next.bowlerIndex + 1,
        math.max(0, next.bowlers.length - 1),
      );
      next = next.copyWith(bowlerIndex: nextBowlerIndex);
    }
    _setState(next);
    _emit(GameplayEventType.deliveryCompleted, {'result': result});
    if (result.isWicket) {
      _emit(GameplayEventType.wicket, {'dismissal': result.dismissal});
    }
    if (result.legal &&
        legalBalls > 0 &&
        legalBalls % tuning.ballsPerOver == 0 &&
        !next.isTerminal) {
      final bowler = next.currentBowler;
      _emit(GameplayEventType.overComplete, {
        'over': legalBalls ~/ tuning.ballsPerOver,
        'nextOver': next.currentOver + 1,
        'bowler': bowler?.name,
        'bowlerId': bowler?.id,
        'lookKey': bowler?.lookKey,
        'jerseyNumber': bowler?.jerseyNumber,
      });
    }
    if (next.isTerminal) {
      _emit(GameplayEventType.matchEnded, {
        'won': next.phase == MatchPhase.won,
        'reason': next.endReason,
        'stars': next.stars,
      });
    }
  }

  void _pause() {
    if (_state.phase == MatchPhase.paused ||
        _state.isTerminal ||
        _state.phase == MatchPhase.idle ||
        _state.phase == MatchPhase.quit) {
      return;
    }
    _setState(
      _state.copyWith(suspendedPhase: _state.phase, phase: MatchPhase.paused),
    );
    _emit(GameplayEventType.paused);
  }

  void _resume() {
    if (_state.phase != MatchPhase.paused || _state.suspendedPhase == null) {
      return;
    }
    final resumePhase = _state.suspendedPhase!;
    _setState(_state.copyWith(phase: resumePhase, suspendedPhase: null));
    _emit(GameplayEventType.resumed);
  }

  void _quit() {
    if (_state.phase == MatchPhase.quit) return;
    _setState(
      _state.copyWith(phase: MatchPhase.quit, endReason: MatchEndReason.quit),
    );
    _emit(GameplayEventType.quitToHome);
  }

  void _enterPhase(MatchPhase phase) {
    _setState(_state.copyWith(phase: phase, phaseElapsedMicros: 0));
  }

  bool _isLiveBallPhase(MatchPhase phase) =>
      phase == MatchPhase.cameraTransition ||
      phase == MatchPhase.fieldPlay ||
      phase == MatchPhase.runDecision ||
      phase == MatchPhase.runnersMoving ||
      phase == MatchPhase.throwInProgress;

  void _resetTransientSimulation() {
    _primaryChaserId = null;
    _backupChaserId = null;
    _catchResolved = false;
  }

  void _setState(MatchState state) {
    _state = state;
    if (!_stateController.isClosed) _stateController.add(state);
  }

  void _emit(
    GameplayEventType type, [
    Map<String, Object?> payload = const {},
  ]) {
    if (_eventController.isClosed) return;
    _eventController.add(
      GameplayEvent(
        type: type,
        simulationMicros: _state.simulationMicros,
        payload: payload,
      ),
    );
  }

  void _ensureAlive() {
    if (_disposed) throw StateError('MatchController has been disposed');
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _stateController.close();
    await _eventController.close();
  }
}
```

### P.12 `final_over/lib/game/contact_ball_flight.dart`

<sub>45 lines</sub>

```dart
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../domain/models.dart';

/// Returns the presentation-only ball position during the contact beat.
///
/// The endpoint is deliberately beyond the batting viewport so the ball exits
/// in the played direction before the top-down field camera takes over.
Offset contactBallFlightPoint({
  required Size viewport,
  required Offset origin,
  required ShotDirection direction,
  required Elevation elevation,
  required double power,
  required double progress,
}) {
  final flightProgress = progress.clamp(0.0, 1.0);
  final normalizedPower = power.clamp(0.0, 1.0);
  final directionVector = switch (direction) {
    ShotDirection.offSide => const Offset(-1, 0),
    ShotDirection.straight => const Offset(0, -1),
    ShotDirection.legSide => const Offset(1, 0),
    ShotDirection.behind => const Offset(0, 1),
  };
  final distanceToEdge = switch (direction) {
    ShotDirection.offSide => math.max(0.0, origin.dx),
    ShotDirection.straight => math.max(0.0, origin.dy),
    ShotDirection.legSide => math.max(0.0, viewport.width - origin.dx),
    ShotDirection.behind => math.max(0.0, viewport.height - origin.dy),
  };
  // Include a distance-relative lead so even the longest route (usually the
  // straight drive toward the top edge) clears the viewport on the last
  // fixed-step contact frame, before the controller starts the camera blend.
  final overshoot =
      distanceToEdge * 0.065 +
      viewport.shortestSide * (0.012 + normalizedPower * 0.020);
  final flatPoint =
      origin + directionVector * (distanceToEdge + overshoot) * flightProgress;
  final loftLift = elevation == Elevation.loft
      ? math.sin(math.pi * flightProgress) * viewport.height * 0.075
      : 0.0;
  return flatPoint.translate(0, -loftLift);
}
```

## Appendix A — Game code (verbatim)

Copy each file to the path in its heading. These are byte-for-byte copies of the source repo.

### A.1 `lib/games/final_over/final_over_tuning.dart`

<sub>45 lines</sub>

```dart
/// Presentation beats for Final Over.
///
/// Gameplay tuning does NOT live here — that is `GameplayTuning` inside the
/// `final_over` package, and it is the only thing allowed to change how a match
/// plays out. Everything below is render-facing: how hard the camera kicks and
/// how long a celebration runs. Changing any of it must not change a single run
/// scored.
library;

/// Screen shake on contact / boundary / wicket.
const double kFoShakeSeconds = 0.32;
const double kFoShakeContact = 5.0;
const double kFoShakeWicket = 8.0;

/// Focal zoom-punch on a run-out or a completed run — the moment the chase
/// tightens.
const double kFoCineSeconds = 0.55;
const double kFoCineZoom = 0.055;

/// How long a full-screen effect (impact ring, boundary pulse, wicket burst)
/// lives.
const double kFoEffectSeconds = 1.1;

/// The last legal ball dims the edges of the world. Cheap, and it works.
const double kFoFinalBallVignette = 0.62;

/// How long a HUD sting (SIX / FOUR / OUT / PERFECT) stays up.
const double kFoStingMajorMs = 1500;
const double kFoStingMinorMs = 1000;

/// Bowler run-up leg-cycle speed, in radians of phase per unit of run-up
/// progress.
const double kFoRunUpCycle = 26.0;

/// The crowd. It never goes completely quiet, it goes berserk for a boundary or
/// a wicket, and it takes a couple of seconds to come back down.
const int kFoCrowdDots = 96;
const double kFoCrowdIdleHype = 0.22;
const double kFoCrowdHypeSeconds = 2.2;

/// How long a held swing takes to visually wind up to the fully-cocked
/// backlift, in microseconds of engine simulation time (same units as
/// `simulationMicros`/`swing.inputMicros`). Purely a render-facing ramp —
/// the grading engine only ever sees the real release timestamp.
const int kFoBackliftLoadMicros = 300000; // 300ms
```

### A.2 `lib/games/final_over/final_over_game.dart`

<sub>1715 lines</sub>

```dart
/// The Flame rendering boundary for Final Over.
///
/// [MatchController] (inside the `final_over` package) remains the ONLY
/// gameplay authority. This class advances its fixed-step clock and projects
/// the resulting immutable [MatchState] onto the canvas. It decides no run, no
/// wicket, no score — if you find yourself reaching for a rule here, it belongs
/// in the package.
///
/// The HUD is fed by [ValueNotifier]s, never by a bloc: a bloc emission per
/// frame at 60fps would rebuild the widget tree 60 times a second. The cubit
/// only ever hears about the coarse beats (match ended).
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:final_over/final_over.dart';
import 'package:final_over/game/contact_ball_flight.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../data/final_over_kits.dart';
import 'final_over_rig.dart';
import 'final_over_tuning.dart';

/// A short, loud banner: SIX / FOUR / OUT / PERFECT.
class FinalOverSting {
  const FinalOverSting(this.label, this.color, {this.major = false});
  final String label;
  final Color color;
  final bool major;
}

/// Visual progress along the incoming delivery at which it reaches the pitch.
double finalOverBounceProgress(DeliveryLength length) => switch (length) {
  DeliveryLength.short => 0.42,
  DeliveryLength.good => 0.56,
  DeliveryLength.full => 0.70,
  DeliveryLength.yorker => 0.82,
};

bool finalOverShouldShowBounceMarker({
  required MatchPhase phase,
  required MatchPhase? suspendedPhase,
  required DeliveryLength length,
  required double incomingProgress,
}) {
  final activePhase = phase == MatchPhase.paused ? suspendedPhase : phase;
  return activePhase == MatchPhase.deliveryPreparation ||
      activePhase == MatchPhase.bowlerRunUp ||
      (activePhase == MatchPhase.incomingBall &&
          incomingProgress < finalOverBounceProgress(length));
}

/// One perspective projection shared by every element in the batting camera.
@immutable
class FinalOverBattingProjection {
  const FinalOverBattingProjection._({
    required this.size,
    required this.farY,
    required this.nearY,
    required this.farHalfWidth,
    required this.nearHalfWidth,
  });

  factory FinalOverBattingProjection.forViewport(
    Size size, {
    double? controlDeckTop,
  }) {
    final farY = size.height * (FinalOverGame.horizonFraction + 0.055);
    final requestedNearY = (controlDeckTop ?? size.height * 0.78) - 12;
    final bandedNearY = requestedNearY.clamp(
      size.height * 0.68,
      size.height * 0.78,
    );
    // Prefer the 68–78% band, but let the measured CTA win on compact screens:
    // the pitch may shrink further, never overlap the controls.
    final nearY = math.min(bandedNearY, requestedNearY);
    return FinalOverBattingProjection._(
      size: size,
      farY: farY,
      nearY: nearY,
      farHalfWidth: size.width * 0.042,
      nearHalfWidth: size.width * 0.21 * 0.82,
    );
  }

  final Size size;
  final double farY;
  final double nearY;
  final double farHalfWidth;
  final double nearHalfWidth;

  double get centerX => size.width * 0.5;

  double halfWidthAt(double depth) =>
      farHalfWidth + (nearHalfWidth - farHalfWidth) * depth.clamp(0, 1);

  Offset pointAt({required double depth, double lateral = 0}) {
    final d = depth.clamp(0.0, 1.0);
    final lateralScale = size.width * (0.55 + (1.25 - 0.55) * d);
    return Offset(centerX + lateral * lateralScale, farY + (nearY - farY) * d);
  }

  Offset incomingPoint(DeliverySpec delivery, double progress) => pointAt(
    depth: 0.08 + 0.78 * progress.clamp(0.0, 1.0),
    lateral: delivery.contactX,
  );

  Offset bouncePoint(DeliverySpec delivery) =>
      incomingPoint(delivery, finalOverBounceProgress(delivery.length));
}

class FinalOverGame extends FlameGame {
  FinalOverGame({
    required this.controller,
    required this.kit,
    required this.opponentKit,
    required this.onEvents,
    this.batsmanIds = const [],
    this.reducedMotion = false,
  });

  final MatchController controller;
  final FinalOverKit kit;
  final FinalOverKit opponentKit;
  final List<String> batsmanIds;
  final bool reducedMotion;

  /// Coarse beats out to the screen (sound, haptics, cubit phase changes).
  final void Function(GameplayEvent event) onEvents;

  // ── HUD bindings — cheap 60fps reads, never bloc emissions. ────────────────
  final ValueNotifier<int> score = ValueNotifier(0);
  final ValueNotifier<int> wickets = ValueNotifier(0);
  final ValueNotifier<int> ballsLeft = ValueNotifier(18);
  final ValueNotifier<int> runsNeeded = ValueNotifier(0);
  final ValueNotifier<int> target = ValueNotifier(0);
  final ValueNotifier<int> currentOver = ValueNotifier(0);
  final ValueNotifier<int> maximumOvers = ValueNotifier(3);
  final ValueNotifier<String> bowlerName = ValueNotifier('VOLT');
  final ValueNotifier<String?> nextBatterLabel = ValueNotifier(null);
  final ValueNotifier<int> combo = ValueNotifier(1);
  final ValueNotifier<int> powerSegments = ValueNotifier(0);
  final ValueNotifier<bool> powerArmed = ValueNotifier(false);
  final ValueNotifier<bool> freeHit = ValueNotifier(false);
  final ValueNotifier<Elevation> elevation = ValueNotifier(Elevation.ground);
  final ValueNotifier<ShotDirection> selectedDirection = ValueNotifier(
    ShotDirection.straight,
  );
  final ValueNotifier<MatchPhase> phase = ValueNotifier(MatchPhase.idle);
  final ValueNotifier<int> preparationSeconds = ValueNotifier(0);
  final ValueNotifier<bool> canConfigureShot = ValueNotifier(false);
  final ValueNotifier<bool> canSwing = ValueNotifier(false);
  final ValueNotifier<bool> successfulContact = ValueNotifier(false);
  final ValueNotifier<RiskLevel> risk = ValueNotifier(RiskLevel.safe);
  final ValueNotifier<bool> canRun = ValueNotifier(false);
  final ValueNotifier<double> runProgress = ValueNotifier(0);
  final ValueNotifier<int> completedRuns = ValueNotifier(0);
  final ValueNotifier<bool> canTurnBack = ValueNotifier(false);

  final ValueNotifier<List<BallResult>> history = ValueNotifier(const []);
  final ValueNotifier<FinalOverSting?> sting = ValueNotifier(null);

  StreamSubscription<GameplayEvent>? _events;

  final List<FieldVector> _trail = <FieldVector>[];
  int _trailDeliveryOrdinal = -1;
  double _visualSeconds = 0;
  double _effectStartedAt = -10;
  GameplayEventType? _effect;
  int _effectSeed = 0;
  double _bowlerRunPhase = 0;
  double _stingClearAt = -1;
  double? _battingControlDeckTop;
  double _nextBatterClearAt = -1;

  int _syncedWickets = 0;
  int _nextBatterIndex = 2;
  late String _strikerActorId;
  late String _partnerActorId;

  /// The finger is on HIT. A hold is cancelled whenever the live-ball input
  /// window closes, so it can never leak into the next delivery.
  bool _swingHeld = false;

  /// Engine time (matches `s.simulationMicros`) the current hold began. Null
  /// whenever `_swingHeld` is false. Drives the backlift hold-to-load ramp in
  /// `_batterProgress`; purely a render concern — the grading engine only
  /// ever sees the real release timestamp.
  int? _swingHeldAtMicros;

  MatchState get state => controller.state;
  GameplayTuning get tuning => controller.tuning;

  /// Updates the visual safe boundary; it never participates in game rules.
  void setBattingControlDeckTop(double top) {
    if (top.isFinite) _battingControlDeckTop = top;
  }

  /// Combo segments OVERDRIVE costs. Read from the engine so the plate can
  /// never light up for a shot the controller will refuse.
  int get overdriveRequirement => tuning.powerShotSegments;

  @override
  Color backgroundColor() => Cyber.bg;

  @override
  Future<void> onLoad() async {
    _strikerActorId = batsmanIds.isNotEmpty ? batsmanIds.first : 'fo-striker';
    _partnerActorId = batsmanIds.length > 1
        ? batsmanIds[1]
        : batsmanIds.isNotEmpty
        ? batsmanIds.first
        : 'fo-partner';
    _events = controller.eventStream.listen(_onEvent);
  }

  @override
  void onRemove() {
    _events?.cancel();
    for (final n in <ValueNotifier<Object?>>[
      score,
      wickets,
      ballsLeft,
      runsNeeded,
      target,
      currentOver,
      maximumOvers,
      bowlerName,
      nextBatterLabel,
      combo,
      powerSegments,
      powerArmed,
      freeHit,
      elevation,
      selectedDirection,
      phase,
      preparationSeconds,
      canConfigureShot,
      canSwing,
      successfulContact,
      risk,
      canRun,
      runProgress,
      completedRuns,
      canTurnBack,
      history,
      sting,
    ]) {
      n.dispose();
    }
    super.onRemove();
  }

  // ── Input (imperative, no state of its own) ────────────────────────────────

  /// Leaves the engine's `matchIntro` — until this lands, the fixed tick is a
  /// no-op and no ball is bowled. The intro overlay calls it when its countdown
  /// hits zero.
  void start() => controller.dispatch(const StartCommand());

  void selectElevation(Elevation e) =>
      controller.dispatch(SelectElevationCommand(e));

  void selectDirection(ShotDirection direction) =>
      controller.dispatch(SelectDirectionCommand(direction));

  /// Press: show a brief backlift while the player waits to release.
  void beginSwing() {
    if (_swingHeld) return;
    final s = controller.state;
    if (!_swingWindowOpen(s)) return;
    _swingHeld = true;
    _swingHeldAtMicros = s.simulationMicros;
  }

  /// Release: the swing itself. The engine grades when it is released.
  ///
  /// [direction]/[elevation] let a whole-screen tap/swipe choose the shot's
  /// placement and loft at the instant of the hit (tap = grounded straight,
  /// swipe = aimed, upward flick = loft). When omitted the pre-selected shot
  /// stands, so existing callers keep working.
  void releaseSwing({ShotDirection? direction, Elevation? elevation}) {
    if (!_swingHeld) return;
    _swingHeld = false;
    _swingHeldAtMicros = null;
    final s = controller.state;
    controller.dispatch(
      SwingCommand(direction ?? s.selectedDirection, elevation: elevation),
    );
  }

  /// The finger slid off the plate, or the deck swapped under it. No swing.
  void cancelSwing() {
    _swingHeld = false;
    _swingHeldAtMicros = null;
  }

  /// The CTA only becomes interactive during the engine's legal swing window.
  bool _swingWindowOpen(MatchState s) => s.canSwing;

  void activatePowerShot() =>
      controller.dispatch(const ActivatePowerShotCommand());
  void startRun() => controller.dispatch(const StartRunCommand());
  void holdBall() => controller.dispatch(const HoldBallCommand());
  void turnBack() => controller.dispatch(const TurnBackCommand());
  void pause() {
    cancelSwing();
    controller.dispatch(const PauseCommand());
  }

  void resume() => controller.dispatch(const ResumeCommand());
  void backgrounded() {
    cancelSwing();
    controller.dispatch(const AppBackgroundedCommand());
  }

  // ── Loop ──────────────────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);
    if (!dt.isFinite || dt <= 0) return;
    final bounded = dt.clamp(0.0, 1 / 30);
    _visualSeconds += bounded;

    controller.step(
      Duration(
        microseconds: (bounded * Duration.microsecondsPerSecond).round(),
      ),
    );

    final s = controller.state;
    _captureTrail(s);
    if (s.phase == MatchPhase.bowlerRunUp) {
      _bowlerRunPhase += bounded * kFoRunUpCycle;
    }
    if (_stingClearAt > 0 && _visualSeconds >= _stingClearAt) {
      sting.value = null;
      _stingClearAt = -1;
    }
    if (_nextBatterClearAt > 0 && _visualSeconds >= _nextBatterClearAt) {
      nextBatterLabel.value = null;
      _nextBatterClearAt = -1;
    }
    _syncNotifiers(s);
  }

  void _syncNotifiers(MatchState s) {
    score.value = s.score;
    wickets.value = s.wickets;
    ballsLeft.value = s.ballsRemaining;
    runsNeeded.value = s.runsNeeded;
    target.value = s.target;
    currentOver.value = s.currentOver;
    maximumOvers.value = s.maximumOvers;
    final bowler = s.currentBowler;
    if (bowler != null && bowlerName.value != bowler.name) {
      bowlerName.value = bowler.name;
    }
    combo.value = s.combo;
    powerSegments.value = s.powerSegments;
    powerArmed.value = s.powerShotArmed;
    freeHit.value = s.freeHit || s.currentDeliveryFreeHit;
    elevation.value = s.selectedElevation;
    selectedDirection.value = s.selectedDirection;
    phase.value = s.phase;
    canConfigureShot.value = s.canConfigureShot;
    canSwing.value = s.canSwing;
    preparationSeconds.value = s.phase == MatchPhase.deliveryPreparation
        ? ((tuning.deliveryPreparationMicros - s.phaseElapsedMicros) /
                  Duration.microsecondsPerSecond)
              .ceil()
              .clamp(1, 3)
        : 0;
    risk.value = s.runner.risk;
    canRun.value = s.canRun;
    completedRuns.value = s.runner.completedRuns;
    canTurnBack.value = s.runner.canTurnBack;
    // Quantised so an unchanged bar never notifies.
    _setDouble(runProgress, (s.runner.progress * 100).round() / 100);
    if (!s.canSwing) {
      _swingHeld = false;
      _swingHeldAtMicros = null;
    }
    if (!identical(history.value, s.history)) history.value = s.history;
    _rotateBatsmanOnWicket(s);
  }

  void _rotateBatsmanOnWicket(MatchState s) {
    if (s.wickets <= _syncedWickets) return;
    _syncedWickets = s.wickets;
    if (_nextBatterIndex >= batsmanIds.length) return;
    final incoming = batsmanIds[_nextBatterIndex++];
    _strikerActorId = incoming;
    nextBatterLabel.value = 'NEXT BAT';
    _nextBatterClearAt = _visualSeconds + 2.2;
  }

  void _setDouble(ValueNotifier<double> n, double v) {
    if ((n.value - v).abs() > 0.001) n.value = v;
  }

  void _onEvent(GameplayEvent event) {
    switch (event.type) {
      case GameplayEventType.contactResolved:
        if (controller.state.contactOutcome?.madeContact == true) {
          successfulContact.value = true;
        }
        _effect = event.type;
        _effectStartedAt = _visualSeconds;
        _effectSeed = controller.state.currentDelivery?.seed ?? 0;
        break;
      case GameplayEventType.boundary:
      case GameplayEventType.wicket:
      case GameplayEventType.catchTaken:
      case GameplayEventType.catchDropped:
      case GameplayEventType.runOut:
      case GameplayEventType.runCompleted:
        _effect = event.type;
        _effectStartedAt = _visualSeconds;
        _effectSeed = controller.state.currentDelivery?.seed ?? 0;
      default:
        break;
    }
    _stingFor(event);
    onEvents(event);
  }

  void _stingFor(GameplayEvent event) {
    final s = controller.state;
    FinalOverSting? next;
    switch (event.type) {
      case GameplayEventType.boundary:
        final six = s.lastResult?.boundary == 6 || s.ledger.boundary == 6;
        next = six
            ? const FinalOverSting('SIX', Cyber.gold, major: true)
            : const FinalOverSting('FOUR', Cyber.cyan, major: true);
      case GameplayEventType.wicket:
        next = const FinalOverSting('OUT', Cyber.danger, major: true);
      case GameplayEventType.runOut:
        next = const FinalOverSting('RUN OUT', Cyber.danger, major: true);
      case GameplayEventType.catchDropped:
        next = const FinalOverSting('DROPPED', Cyber.lime);
      case GameplayEventType.powerShotActivated:
        next = const FinalOverSting('POWER SHOT', Cyber.magenta, major: true);
      case GameplayEventType.extraAwarded:
        next = FinalOverSting(
          s.currentDelivery?.isNoBall == true ? 'NO BALL · FREE HIT' : 'WIDE',
          Cyber.amber,
        );
      case GameplayEventType.contactResolved:
        if (s.contactOutcome?.timing == TimingGrade.perfect) {
          next = const FinalOverSting('PERFECT', Cyber.lime);
        }
      case GameplayEventType.fieldLayoutChanged:
        final label = event.payload['label'] as String? ?? 'FIELD SHIFT';
        next = FinalOverSting('FIELD SHIFT · $label', Cyber.cyan);
      default:
        return;
    }
    if (next == null) return;
    sting.value = next;
    _stingClearAt =
        _visualSeconds +
        (next.major ? kFoStingMajorMs : kFoStingMinorMs) / 1000;
  }

  void _captureTrail(MatchState s) {
    final ordinal = s.currentDelivery?.ordinal ?? -1;
    if (ordinal != _trailDeliveryOrdinal) {
      _trailDeliveryOrdinal = ordinal;
      _trail.clear();
    }
    final position = s.ball?.position;
    if (position == null) return;
    if (_trail.isEmpty || _trail.last.distanceTo(position) >= 0.025) {
      _trail.add(position);
      if (_trail.length > 30) _trail.removeAt(0);
    }
  }

  // ── Render ────────────────────────────────────────────────────────────────
  @override
  void render(Canvas canvas) {
    if (!hasLayout) return;
    final viewport = Size(size.x, size.y);
    if (viewport.isEmpty) return;

    final s = controller.state;
    final transition = s.cameraTransition.clamp(0.0, 1.0);
    final age = (_visualSeconds - _effectStartedAt).clamp(0.0, 2.0);
    final shake = reducedMotion ? Offset.zero : _shake(age);
    final zoom = reducedMotion ? 1.0 : _zoom(age);

    canvas.save();
    canvas.translate(shake.dx, shake.dy);
    canvas.translate(viewport.width / 2, viewport.height / 2);
    canvas.scale(zoom);
    canvas.translate(-viewport.width / 2, -viewport.height / 2);

    if (transition < 1) {
      _withOpacity(
        canvas,
        viewport,
        1 - Curves.easeInCubic.transform(transition),
        () => _paintBattingView(canvas, viewport, s),
      );
    }
    if (transition > 0) {
      _withOpacity(
        canvas,
        viewport,
        Curves.easeOutCubic.transform(transition),
        () => _paintFieldView(canvas, viewport, s),
      );
    }
    canvas.restore();

    _paintEffects(canvas, viewport, s, age);
    if (s.ballsRemaining == 1 && !s.isTerminal) {
      _paintFinalBallVignette(canvas, viewport);
    }
    super.render(canvas);
  }

  void _withOpacity(
    Canvas canvas,
    Size size,
    double opacity,
    VoidCallback paint,
  ) {
    if (opacity <= 0) return;
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0)),
    );
    paint();
    canvas.restore();
  }

  /// Where the grass starts — directly under the hoardings, so there is no
  /// no-man's-land between the boards and the rope. The pitch's far edge is
  /// pinned just below it (see [_paintPerspectivePitch]), which is what keeps
  /// the rope, the bowler's feet and the vanishing point agreeing on which way
  /// is *away*.
  static const double horizonFraction = 0.29;

  /// How loud the ground is. Idles low, jumps on a boundary or a wicket, and
  /// settles back over a couple of seconds — the crowd is the scoreboard you
  /// hear.
  double get _crowdHype {
    final loud = switch (_effect) {
      GameplayEventType.boundary => 1.0,
      GameplayEventType.wicket || GameplayEventType.runOut => 0.85,
      GameplayEventType.catchTaken || GameplayEventType.catchDropped => 0.6,
      _ => 0.0,
    };
    if (loud == 0) return kFoCrowdIdleHype;
    final age = ((_visualSeconds - _effectStartedAt) / kFoCrowdHypeSeconds)
        .clamp(0.0, 1.0);
    return kFoCrowdIdleHype +
        loud *
            (1 - Curves.easeOutCubic.transform(age)) *
            (1 - kFoCrowdIdleHype);
  }

  /// The ground, drawn: night sky, floodlights, a bowl of crowd, the hoardings,
  /// the sightscreen behind the bowler's arm, and the outfield running away to
  /// the rope. Back to front, flat fills and lit lines — the lamps are the only
  /// thing allowed to bloom.
  void _paintStadium(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final horizonY = h * horizonFraction;

    // Night sky over the ground.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, horizonY + 1),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, 0),
          Offset(w / 2, horizonY),
          [
            const Color(0xFF0B1C2B),
            const Color(0xFF07131F),
            const Color(0xFF030912),
          ],
          const [0.0, 0.48, 1.0],
        ),
    );
    final halo = Rect.fromCenter(
      center: Offset(w * 0.5, h * 0.14),
      width: w * 1.05,
      height: h * 0.30,
    );
    canvas.drawOval(
      halo,
      Paint()
        ..shader = ui.Gradient.radial(halo.center, halo.width / 2, [
          Cyber.cyan.withValues(alpha: 0.08),
          Colors.transparent,
        ]),
    );

    final standTop = h * 0.115;
    final standBottom = h * 0.245;
    _paintFloodlight(canvas, Offset(w * 0.07, standTop + 8), flip: false);
    _paintFloodlight(canvas, Offset(w * 0.93, standTop + 8), flip: true);
    _paintStands(canvas, size, standTop, standBottom);
    _paintSightscreen(canvas, size, standTop, standBottom);
    _paintHoardings(canvas, size, standBottom + h * 0.012);
    _paintOutfield(canvas, size, horizonY);
    _paintScanlines(canvas, size);
  }

  /// A pylon: two struts, a rack, and six lamps. The blur here is the only one
  /// in the scene — a floodlight is the one thing on a cricket ground that
  /// genuinely glows.
  void _paintFloodlight(Canvas canvas, Offset base, {required bool flip}) {
    final side = flip ? -1.0 : 1.0;
    final strut = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.30)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(base, base.translate(side * 14, -74), strut);
    canvas.drawLine(
      base.translate(side * 7, -2),
      base.translate(side * 21, -74),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.18)
        ..strokeWidth = 1,
    );

    final rack = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: base.translate(side * 18, -84),
        width: 38,
        height: 24,
      ),
      const Radius.circular(3),
    );
    canvas.drawRRect(
      rack,
      Paint()..color = Cyber.panel.withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      rack,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.45),
    );
    for (var row = 0; row < 2; row++) {
      for (var col = 0; col < 3; col++) {
        canvas.drawCircle(
          Offset(rack.left + 8 + col * 11, rack.top + 8 + row * 9),
          2.6,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.62)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
  }

  /// The bowl. A curved back, a roof line, vomitories, tiers, and a few hundred
  /// people doing a Mexican wave in `sin`.
  void _paintStands(Canvas canvas, Size size, double top, double bottom) {
    final w = size.width;
    final h = size.height;
    final height = bottom - top;
    final hype = _crowdHype;

    final back = Path()
      ..moveTo(0, top)
      ..quadraticBezierTo(w * 0.5, top - h * 0.055, w, top)
      ..lineTo(w, bottom)
      ..quadraticBezierTo(w * 0.5, bottom + h * 0.035, 0, bottom)
      ..close();
    canvas.drawPath(
      back,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, top),
          Offset(w / 2, bottom),
          [
            Cyber.panel2.withValues(alpha: 0.88),
            Cyber.bg.withValues(alpha: 0.96),
          ],
        ),
    );
    canvas.drawPath(
      back,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Cyber.cyan.withValues(alpha: 0.20),
    );

    final roof = Path()
      ..moveTo(0, top - h * 0.010)
      ..quadraticBezierTo(w * 0.5, top - h * 0.066, w, top - h * 0.010)
      ..lineTo(w, top + h * 0.009)
      ..quadraticBezierTo(w * 0.5, top - h * 0.044, 0, top + h * 0.009)
      ..close();
    canvas.drawPath(roof, Paint()..color = const Color(0xFF0F2334));
    canvas.drawPath(
      roof,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.cyan.withValues(alpha: 0.22),
    );

    // Vomitories — the aisles that break the crowd into blocks.
    for (var i = 1; i < 8; i++) {
      final x = w * i / 8;
      final inset = (i - 4).abs() * h * 0.004;
      canvas.drawLine(
        Offset(x, top - inset),
        Offset(x, bottom),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.07)
          ..strokeWidth = 1,
      );
    }

    // The crowd. Mostly a dark mass of heads — a stand full of neon would be a
    // rainbow, not a crowd — with the odd shirt catching the light. Positions
    // are hashed off the index, never a per-frame Random.
    final wave = reducedMotion ? 0.0 : 1.0;
    const rows = 5;
    final perRow = kFoCrowdDots ~/ rows;
    for (var i = 0; i < kFoCrowdDots; i++) {
      final row = i ~/ perRow;
      final col = i % perRow;
      // Odd rows sit half a seat over, so the heads stagger like real seating.
      final jitter = _hash(i) - 0.5;
      final x =
          (col + (row.isOdd ? 0.5 : 0.0) + jitter * 0.4) * (w / perRow) - 4;
      final bob =
          math.sin(_visualSeconds * (1.4 + hype * 2.4) + col * 0.55 + row) *
          (0.4 + hype * 1.6) *
          wave;
      final y = top + height * 0.22 + row * height / 6.6 + bob;

      final lit = i % 9 == 0;
      final color = lit
          ? (i % 27 == 0 ? Cyber.cyan : Cyber.amber)
          : const Color(0xFF243449);
      canvas.drawCircle(
        Offset(x, y),
        1.05 + _hash(i * 7) * 0.5,
        Paint()
          ..color = color.withValues(alpha: lit ? 0.40 + hype * 0.35 : 0.72),
      );
      // Camera flashes, but only when there is something worth shooting.
      if (hype > 0.6 && i % 13 == 0) {
        if (math.sin(_visualSeconds * 9 + i * 2.3) > 0.88) {
          canvas.drawCircle(
            Offset(x, y - 1),
            1.7,
            Paint()..color = Colors.white.withValues(alpha: 0.5 * hype),
          );
        }
      }
    }
  }

  /// Cheap deterministic 0..1 from an int — a seedless stand-in for a Random we
  /// must not allocate per frame.
  double _hash(int i) {
    final v = math.sin(i * 12.9898) * 43758.5453;
    return v - v.floorToDouble();
  }

  /// The sightscreen, directly behind the bowler's arm — the one piece of
  /// stadium furniture that exists purely so you can pick the ball up. Pale, so
  /// a red ball reads against it, and panelled so it looks built rather than
  /// pasted on.
  void _paintSightscreen(Canvas canvas, Size size, double top, double bottom) {
    final height = bottom - top;
    final face = Rect.fromLTRB(
      size.width * 0.395,
      top + height * 0.26,
      size.width * 0.555,
      bottom - height * 0.06,
    );

    // Legs first, so the face sits on them.
    for (final x in [
      face.left + face.width * 0.22,
      face.right - face.width * 0.22,
    ]) {
      canvas.drawLine(
        Offset(x, face.bottom),
        Offset(x, bottom + size.height * 0.012),
        Paint()
          ..color = const Color(0xFF0B1420)
          ..strokeWidth = 3,
      );
    }

    canvas.drawRect(face, Paint()..color = const Color(0xFFB9C4CE));
    canvas.drawRect(face.deflate(2), Paint()..color = const Color(0xFFD6DEE6));
    // Panel seams.
    for (var i = 1; i < 4; i++) {
      final x = face.left + face.width * i / 4;
      canvas.drawLine(
        Offset(x, face.top + 2),
        Offset(x, face.bottom - 2),
        Paint()
          ..color = const Color(0xFF9AA6B2)
          ..strokeWidth = 1,
      );
    }
    canvas.drawRect(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.line.withValues(alpha: 0.8),
    );
  }

  /// The hoarding ring. Calm chrome — it is advertising, not a moment.
  void _paintHoardings(Canvas canvas, Size size, double y) {
    const labels = ['STATOZ', 'FINAL OVER', 'SIX TO WIN', 'PITCH DUEL'];
    final boardW = size.width / labels.length;
    final boardH = size.height * 0.026;
    for (var i = 0; i < labels.length; i++) {
      final rect = Rect.fromLTWH(i * boardW, y, boardW - 2, boardH);
      final accent = i.isEven ? Cyber.cyan : Cyber.amber;
      canvas.drawRect(
        rect,
        Paint()..color = Cyber.panel.withValues(alpha: 0.80),
      );
      canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = accent.withValues(alpha: 0.32),
      );
      _paintCanvasLabel(
        canvas,
        labels[i],
        rect,
        Cyber.label(
          7,
          color: accent.withValues(alpha: 0.85),
          letterSpacing: 1.4,
        ),
      );
    }
  }

  void _paintCanvasLabel(
    Canvas canvas,
    String text,
    Rect rect,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '',
    )..layout(maxWidth: rect.width - 8);
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
  }

  /// The outfield: turf from the rope to your feet, mown in bands, with the
  /// thirty-yard ring arcing across it.
  void _paintOutfield(Canvas canvas, Size size, double horizonY) {
    final w = size.width;
    final h = size.height;
    final turf = Rect.fromLTRB(0, horizonY, w, h);

    canvas.drawRect(
      turf,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(w / 2, horizonY),
          Offset(w / 2, h),
          [
            const Color(0xFF174348),
            const Color(0xFF0C3338),
            const Color(0xFF06262D),
          ],
          const [0.0, 0.45, 1.0],
        ),
    );

    // Mown bands, widening as they come at you.
    for (var i = 0; i < 6; i++) {
      final t0 = i / 6;
      final t1 = (i + 1) / 6;
      double band(double t) => horizonY + (h - horizonY) * t * t;
      if (i.isEven) continue;
      canvas.drawRect(
        Rect.fromLTRB(0, band(t0), w, band(t1)),
        Paint()..color = Colors.white.withValues(alpha: 0.013),
      );
    }

    // The rope, and the shadow it casts on the grass.
    canvas.drawLine(
      Offset(0, horizonY),
      Offset(w, horizonY),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.45)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      Offset(0, horizonY + 3),
      Offset(w, horizonY + 3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..strokeWidth = 1,
    );

    // Thirty-yard ring — the far arc of it, seen almost edge-on.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.66),
        width: w * 1.30,
        height: h * 0.46,
      ),
      math.pi,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: 0.055),
    );
  }

  /// The same ground, from the blimp: a disc of turf mown in rings, the rope
  /// around it, the thirty-yard circle inside it, and the dark of the stands
  /// beyond. The fielders, the runners and the ball are painted on top of this
  /// by [_paintFieldView].
  void _paintGroundFromAbove(
    Canvas canvas,
    Size size,
    Offset center,
    double radius,
  ) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060B12),
    );

    final turf = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          const Color(0xFF17454A),
          const Color(0xFF0B3036),
        ]),
    );

    // Mown rings.
    for (var i = 1; i <= 5; i++) {
      if (i.isEven) continue;
      canvas.drawCircle(
        center,
        radius * i / 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius / 5
          ..color = Colors.white.withValues(alpha: 0.012),
      );
    }

    // Thirty-yard circle.
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.07)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // The rope.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawArc(
      turf.deflate(-3),
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    _paintScanlines(canvas, size);
  }

  /// CRT scanlines — the same HUD texture the rest of the app wears.
  void _paintScanlines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  // ── Batting camera ────────────────────────────────────────────────────────
  void _paintBattingView(Canvas canvas, Size size, MatchState s) {
    final projection = FinalOverBattingProjection.forViewport(
      size,
      controlDeckTop: _battingControlDeckTop,
    );
    _paintStadium(canvas, size);
    _paintPerspectivePitch(canvas, projection, s);
    _paintBounceMarker(canvas, projection, s);
    _paintStumps(canvas, projection, s);

    // Depth by size: the bowler stands 20 metres away, so it is drawn small
    // and high; the batter is at your shoulder. Keep the head
    // of the batter (feet 0.88h, ~0.25h tall → crown ~0.63h) clear of the
    // bowler's feet (0.44h) or the two silhouettes collide mid-pitch.
    final bowlerPx = size.height * 0.145 * 0.85 / kFoReferenceHeightM;
    final (bowlerKind, bowlerT) = _bowlerPose(s);
    final bowler = s.currentBowler;
    final bowlerLookKey = bowler?.lookKey ?? 'fo-bowler';
    final bowlerNumber =
        bowler?.jerseyNumber ?? finalOverNumberFor('fo-bowler');
    _paintActor(
      canvas,
      projection.pointAt(depth: 0.15, lateral: -0.065),
      bowlerPx,
      facing: 1,
      draw: (c, f) => drawFoBowler(
        c,
        foBowlerPose(bowlerKind, bowlerT, runPhase: _bowlerRunPhase),
        kit: opponentKit,
        look: finalOverLookFor(bowlerLookKey),
        px: bowlerPx,
        heightM: kFoReferenceHeightM,
        number: bowlerNumber,
        facing: f,
        ballInHand:
            bowlerKind != FoBowlerPose.followThrough &&
            !(bowlerKind == FoBowlerPose.release && bowlerT > 0.72),
      ),
    );

    final strikerId = _strikerActorId;
    final batterPx = size.height * 0.25 * 0.85 / kFoReferenceHeightM;
    final batterKind = _batterPose(s);
    final batterT = _batterProgress(s);
    final frame = foBatterFrame(batterKind, batterT);
    final trailAngles = _batterTrailAngles(batterKind, batterT);
    _paintActor(
      canvas,
      projection.pointAt(depth: 0.84, lateral: 0.115),
      batterPx,
      facing: -1,
      draw: (c, f) => drawFoBatter(
        c,
        frame,
        kit: kit,
        look: finalOverLookFor(strikerId),
        px: batterPx,
        heightM: kFoReferenceHeightM,
        number: finalOverNumberFor(strikerId),
        facing: f,
        trailBatAngles: trailAngles,
      ),
    );

    _paintPerspectiveBall(canvas, projection, s);
  }

  /// Places an actor on the turf: ground shadow, then the rig. Turf is grass,
  /// not hardwood — no reflection.
  void _paintActor(
    Canvas canvas,
    Offset ground,
    double px, {
    required int facing,
    required void Function(Canvas canvas, int facing) draw,
  }) {
    canvas.save();
    canvas.translate(ground.dx, ground.dy);
    canvas.scale(facing.toDouble(), 1.0);

    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: px * 0.85, height: px * 0.16),
      Paint()..color = const Color(0x66000000),
    );

    draw(canvas, facing);
    canvas.restore();
  }

  /// The pitch receding to the bowler's end — a Cyber-toned trapezoid with
  /// creases. Flat fills and lit lines only: nothing here glows.
  void _paintPerspectivePitch(
    Canvas canvas,
    FinalOverBattingProjection projection,
    MatchState s,
  ) {
    final nearY = projection.nearY;
    final farY = projection.farY;
    final nearHalf = projection.nearHalfWidth;
    final farHalf = projection.farHalfWidth;
    final cx = projection.centerX;

    final pitch = Path()
      ..moveTo(cx - nearHalf, nearY)
      ..lineTo(cx + nearHalf, nearY)
      ..lineTo(cx + farHalf, farY)
      ..lineTo(cx - farHalf, farY)
      ..close();

    canvas.drawPath(
      pitch,
      Paint()
        ..shader = ui.Gradient.linear(Offset(cx, farY), Offset(cx, nearY), [
          const Color(0xFF6E5A3C),
          const Color(0xFF9C7F52),
        ]),
    );
    canvas.drawPath(
      pitch,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Creases — the batter's line, and the bowler's at the far end.
    void crease(double t, double alpha) {
      final point = projection.pointAt(depth: t);
      final half = projection.halfWidthAt(t);
      canvas.drawLine(
        Offset(cx - half * 1.08, point.dy),
        Offset(cx + half * 1.08, point.dy),
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..strokeWidth = 1 + t * 2,
      );
    }

    crease(0.14, 0.30);
    crease(0.78, 0.42);

    // The line the ball is on, shown only while it is in the air toward you.
    if (s.phase == MatchPhase.incomingBall && s.currentDelivery != null) {
      final delivery = s.currentDelivery!;
      canvas.drawLine(
        projection.incomingPoint(delivery, 0),
        projection.incomingPoint(delivery, 1),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.22)
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintBounceMarker(
    Canvas canvas,
    FinalOverBattingProjection projection,
    MatchState s,
  ) {
    final delivery = s.currentDelivery;
    if (delivery == null) return;
    final bounceProgress = finalOverBounceProgress(delivery.length);
    if (!finalOverShouldShowBounceMarker(
      phase: s.phase,
      suspendedPhase: s.suspendedPhase,
      length: delivery.length,
      incomingProgress: _incomingProgress(s),
    )) {
      return;
    }

    final point = projection.bouncePoint(delivery);
    final depth = 0.08 + 0.78 * bounceProgress;
    final radius = 7.0 + 6.0 * depth;
    final ring = Rect.fromCenter(
      center: point,
      width: radius * 2,
      height: radius * 0.72,
    );
    final glow = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final edge = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawOval(ring, glow);
    canvas.drawOval(ring, edge);
    canvas.drawCircle(
      point,
      math.max(1.8, radius * 0.18),
      Paint()..color = Cyber.cyan,
    );
  }

  void _paintStumps(
    Canvas canvas,
    FinalOverBattingProjection projection,
    MatchState s,
  ) {
    final broken =
        s.ledger.dismissal == DismissalType.bowled ||
        s.lastResult?.dismissal == DismissalType.bowled;
    final size = projection.size;
    final cx = projection.centerX;
    final baseY = projection.pointAt(depth: 0.875).dy;
    final h = size.height * 0.095 * 0.85;
    final gap = size.width * 0.020 * 0.85;

    for (var i = -1; i <= 1; i++) {
      final lean = broken ? i * 0.28 : 0.0;
      final x = cx + i * gap;
      canvas.drawLine(
        Offset(x, baseY),
        Offset(x + lean * h, baseY - h * (broken ? 0.82 : 1)),
        Paint()
          ..color = const Color(0xFFE8ECF3)
          ..strokeWidth = size.width * 0.011
          ..strokeCap = StrokeCap.round,
      );
    }
    // Bails.
    if (!broken) {
      canvas.drawLine(
        Offset(cx - gap, baseY - h),
        Offset(cx + gap, baseY - h),
        Paint()
          ..color = Cyber.amber
          ..strokeWidth = size.width * 0.008
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _paintPerspectiveBall(
    Canvas canvas,
    FinalOverBattingProjection projection,
    MatchState s,
  ) {
    final delivery = s.currentDelivery;
    if (delivery == null) return;
    final size = projection.size;
    if (s.phase == MatchPhase.cameraTransition ||
        s.suspendedPhase == MatchPhase.cameraTransition) {
      // The presentation ball has already exited the batting viewport. During
      // the blend, only the field camera owns the real physics ball.
      return;
    }

    double x;
    double y;
    double r;
    if (s.ball case final ball?) {
      final distance = ball.position.length.clamp(0.0, 1.0);
      x = size.width * (0.5 + ball.position.x * 0.24);
      y = size.height * (0.77 - distance * 0.34 - ball.height * 0.22);
      r = size.shortestSide * (0.037 - distance * 0.012) * 0.5;
    } else if (s.phase == MatchPhase.contact &&
        s.contactOutcome?.madeContact == true) {
      final outcome = s.contactOutcome!;
      final progress =
          (s.phaseElapsedMicros /
                  math.max(1, controller.tuning.impactHoldMicros))
              .clamp(0.0, 1.0);
      final origin = projection.incomingPoint(delivery, 1);
      final point = contactBallFlightPoint(
        viewport: size,
        origin: origin,
        direction: outcome.direction,
        elevation: outcome.elevation,
        power: outcome.power,
        progress: progress,
      );
      x = point.dx;
      y = point.dy;
      r = size.shortestSide * (0.018 - progress * 0.004);

      if (!reducedMotion && progress > 0.08) {
        for (var trail = 2; trail >= 1; trail--) {
          final trailProgress = (progress - trail * 0.06).clamp(0.0, 1.0);
          final trailPoint = contactBallFlightPoint(
            viewport: size,
            origin: origin,
            direction: outcome.direction,
            elevation: outcome.elevation,
            power: outcome.power,
            progress: trailProgress,
          );
          canvas.drawCircle(
            trailPoint,
            r * (1 - trail * 0.16),
            Paint()..color = Cyber.cyan.withValues(alpha: 0.18 / trail),
          );
        }
      }
    } else {
      final p = _incomingProgress(s);
      // Hold the ball in the hand until the arm has actually come over.
      if ((s.phase == MatchPhase.deliveryPreparation ||
              s.phase == MatchPhase.bowlerRunUp) &&
          s.phaseElapsedMicros < controller.tuning.runUpMicros * 0.78) {
        return;
      }
      final point = projection.incomingPoint(delivery, p);
      x = point.dx;
      y = point.dy;
      r = size.shortestSide * (0.018 + 0.026 * p) * 0.5 * 0.85;
    }

    _paintBall(canvas, Offset(x, y), r);
  }

  void _paintBall(Canvas canvas, Offset at, double r) {
    canvas.drawCircle(at, r, Paint()..color = const Color(0xFFC4342B));
    canvas.drawArc(
      Rect.fromCircle(center: at, radius: r * 0.72),
      -math.pi * 0.85 + _visualSeconds * 11,
      math.pi * 0.8,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, r * 0.16),
    );
    canvas.drawCircle(
      at.translate(-r * 0.3, -r * 0.3),
      r * 0.28,
      Paint()..color = Colors.white.withValues(alpha: 0.22),
    );
  }

  // ── Top-down fielding camera ──────────────────────────────────────────────
  void _paintFieldView(Canvas canvas, Size size, MatchState s) {
    final geometry = (
      center: Offset(size.width / 2, size.height / 2),
      radius: size.shortestSide * 0.445,
    );
    Offset at(FieldVector v) =>
        geometry.center + Offset(v.x, v.y) * geometry.radius;

    _paintGroundFromAbove(canvas, size, geometry.center, geometry.radius);

    // The strip.
    canvas.drawRect(
      Rect.fromCenter(
        center: geometry.center,
        width: geometry.radius * 0.11,
        height: geometry.radius * 0.46,
      ),
      Paint()..color = const Color(0xFF8A6E45).withValues(alpha: 0.85),
    );

    // Ball trail.
    if (_trail.length > 1) {
      final path = Path()..moveTo(at(_trail.first).dx, at(_trail.first).dy);
      for (final p in _trail.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color =
              (s.contactOutcome?.elevation == Elevation.loft
                      ? Cyber.gold
                      : Cyber.cyan)
                  .withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }

    final markerR = math.max(7.0, size.shortestSide * 0.019);
    for (final f in s.fielders) {
      drawFoFielderMark(
        canvas,
        at(f.position),
        markerR,
        kit: opponentKit,
        active: f.motion == FielderMotion.chasing || f.hasBall,
        facing: Offset(f.velocity.x, f.velocity.y),
      );
    }

    _paintRunners(canvas, at, markerR, s);

    if (s.ball case final ball?) {
      final center = at(ball.position);
      final r = math.max(
        4.5,
        size.shortestSide * (0.012 + ball.height.clamp(0.0, 0.3) * 0.04),
      );
      if (ball.aerial) {
        canvas.drawOval(
          Rect.fromCenter(
            center: center.translate(0, r * 1.8),
            width: r * 2.4,
            height: r * 0.8,
          ),
          Paint()..color = Colors.black.withValues(alpha: 0.34),
        );
      }
      _paintBall(canvas, center, r);
    }

    if (s.phase == MatchPhase.throwInProgress) {
      final holder = s.fielders.where((f) => f.hasBall).firstOrNull;
      if (holder != null) {
        final targetEnd = s.runner.runNumber.isOdd
            ? const FieldVector(0, -0.21)
            : const FieldVector(0, 0.21);
        canvas.drawLine(
          at(holder.position),
          at(targetEnd),
          Paint()
            ..color = Cyber.amber.withValues(alpha: 0.55)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintRunners(
    Canvas canvas,
    Offset Function(FieldVector) at,
    double r,
    MatchState s,
  ) {
    final runner = s.runner;
    final direction = runner.runNumber.isOdd ? -1.0 : 1.0;
    final startY = direction > 0 ? -0.21 : 0.21;
    final endY = -startY;
    final strikerY = runner.active
        ? startY + (endY - startY) * runner.progress
        : (runner.completedRuns.isOdd ? -0.21 : 0.21);
    final nonStrikerY = runner.active
        ? -startY - (endY - startY) * runner.progress
        : -strikerY;

    drawFoRunnerMark(
      canvas,
      at(FieldVector(-0.025, strikerY)),
      r,
      kit: kit,
      number: finalOverNumberFor(_strikerActorId),
      striker: true,
      danger: runner.risk == RiskLevel.danger,
    );
    drawFoRunnerMark(
      canvas,
      at(FieldVector(0.025, nonStrikerY)),
      r,
      kit: kit,
      number: finalOverNumberFor(_partnerActorId),
      striker: false,
    );
  }

  // ── Pose selection (a projection of state, nothing more) ───────────────────
  (FoBowlerPose, double) _bowlerPose(MatchState s) {
    final p = s.phaseElapsedMicros / math.max(1, controller.tuning.runUpMicros);
    if (s.phase == MatchPhase.deliveryPreparation) {
      return (FoBowlerPose.ready, _visualSeconds);
    }
    if (s.phase == MatchPhase.bowlerRunUp) {
      if (p < 0.58) return (FoBowlerPose.runUp, p / 0.58);
      if (p < 0.80) return (FoBowlerPose.gather, (p - 0.58) / 0.22);
      return (FoBowlerPose.release, (p - 0.80) / 0.20);
    }
    if (s.phase == MatchPhase.incomingBall ||
        s.phase == MatchPhase.contact ||
        s.phase == MatchPhase.cameraTransition) {
      return (FoBowlerPose.followThrough, _incomingProgress(s));
    }
    return (FoBowlerPose.ready, _visualSeconds);
  }

  FoBatterPose _batterPose(MatchState s) {
    if (s.phase == MatchPhase.won) return FoBatterPose.celebrate;
    if (s.ledger.dismissal == DismissalType.bowled) return FoBatterPose.bowled;
    if (s.runner.active) return FoBatterPose.running;

    final outcome = s.contactOutcome;
    if (outcome != null && !outcome.madeContact) return FoBatterPose.miss;

    final swing = s.swingIntent;
    if (swing == null) {
      // Holding the swing control makes the batter visibly load up, while an
      // untouched bat still lifts slightly as the ball approaches.
      if (_swingHeld) return FoBatterPose.backlift;
      return s.phase == MatchPhase.incomingBall
          ? FoBatterPose.backlift
          : FoBatterPose.stance;
    }
    return switch ((s.selectedElevation, swing.direction)) {
      (Elevation.ground, ShotDirection.offSide) => FoBatterPose.groundOff,
      (Elevation.ground, ShotDirection.straight) => FoBatterPose.groundStraight,
      (Elevation.ground, ShotDirection.legSide) => FoBatterPose.groundLeg,
      (Elevation.ground, ShotDirection.behind) => FoBatterPose.groundBack,
      (Elevation.loft, ShotDirection.offSide) => FoBatterPose.loftOff,
      (Elevation.loft, ShotDirection.straight) => FoBatterPose.loftStraight,
      (Elevation.loft, ShotDirection.legSide) => FoBatterPose.loftLeg,
      (Elevation.loft, ShotDirection.behind) => FoBatterPose.loftBack,
    };
  }

  double _batterProgress(MatchState s) {
    if (s.phase == MatchPhase.won) return _visualSeconds - _effectStartedAt;
    if (s.ledger.dismissal == DismissalType.bowled) {
      return _visualSeconds - _effectStartedAt;
    }
    if (s.runner.active) return _bowlerRunPhase;
    final swing = s.swingIntent;
    if (swing == null) {
      if (_swingHeld) {
        final heldAt = _swingHeldAtMicros;
        // Defensive only — beginSwing() always sets both fields together.
        if (heldAt == null) return 1.0;
        // Deliberately NOT clamped to 1.0: `backlift` clamps the 0→1 windup
        // itself but reads the raw overflow to drive an idle coil for as
        // long as the hold continues past full cock.
        return ((s.simulationMicros - heldAt) / kFoBackliftLoadMicros).clamp(
          0.0,
          double.infinity,
        );
      }
      return s.phase == MatchPhase.incomingBall
          ? _incomingProgress(s)
          : _visualSeconds;
    }
    return ((s.simulationMicros - swing.inputMicros) / 520000).clamp(0.0, 1.0);
  }

  static const _trailPoses = {
    FoBatterPose.groundOff,
    FoBatterPose.groundStraight,
    FoBatterPose.groundLeg,
    FoBatterPose.groundBack,
    FoBatterPose.loftOff,
    FoBatterPose.loftStraight,
    FoBatterPose.loftLeg,
    FoBatterPose.loftBack,
    FoBatterPose.miss, // still a full-speed swing through the zone
  };

  /// Two recent past bat angles for a fading motion trail, oldest first.
  /// Only during the fast-motion middle of a committed swing (not the slow
  /// easeInOutCubic start/end), and never during stance/backlift/running/
  /// celebrate/bowled.
  List<double> _batterTrailAngles(FoBatterPose kind, double t) {
    if (!_trailPoses.contains(kind)) return const [];
    if (t < 0.15 || t > 0.85) return const [];
    return [
      foBatterFrame(kind, (t - 0.16).clamp(0.0, 1.0)).batAngle,
      foBatterFrame(kind, (t - 0.08).clamp(0.0, 1.0)).batAngle,
    ];
  }

  double _incomingProgress(MatchState s) {
    final delivery = s.currentDelivery;
    if (delivery == null) return 0;
    final release =
        delivery.expectedContactMicros -
        controller.tuning.incomingToContactMicros;
    return ((s.simulationMicros - release) /
            controller.tuning.incomingToContactMicros)
        .clamp(0.0, 1.0);
  }

  // ── Camera juice + full-screen effects ────────────────────────────────────
  Offset _shake(double age) {
    if (_effect != GameplayEventType.contactResolved &&
        _effect != GameplayEventType.wicket &&
        _effect != GameplayEventType.boundary) {
      return Offset.zero;
    }
    if (age >= kFoShakeSeconds) return Offset.zero;
    final decay = 1 - age / kFoShakeSeconds;
    final strength = _effect == GameplayEventType.wicket
        ? kFoShakeWicket
        : kFoShakeContact;
    return Offset(
      math.sin(_effectSeed * 0.17 + age * 95) * strength * decay,
      math.cos(_effectSeed * 0.23 + age * 77) * strength * decay,
    );
  }

  double _zoom(double age) {
    if ((_effect != GameplayEventType.runOut &&
            _effect != GameplayEventType.runCompleted) ||
        age >= kFoCineSeconds) {
      return 1;
    }
    return 1 + math.sin(age / kFoCineSeconds * math.pi) * kFoCineZoom;
  }

  void _paintEffects(Canvas canvas, Size size, MatchState s, double age) {
    if (age > kFoEffectSeconds || reducedMotion) return;
    final t = (age / kFoEffectSeconds).clamp(0.0, 1.0);
    final center = Offset(size.width / 2, size.height * 0.6);

    switch (_effect) {
      case GameplayEventType.contactResolved:
        if (s.contactOutcome?.madeContact != true) return;
        final k = (age / 0.42).clamp(0.0, 1.0);
        canvas.drawCircle(
          center,
          size.shortestSide * (0.05 + k * 0.28),
          Paint()
            ..color = Cyber.cyan.withValues(alpha: 0.5 * (1 - k))
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6 * (1 - k),
        );
      case GameplayEventType.boundary:
        final six = s.lastResult?.boundary == 6;
        final color = six ? Cyber.gold : Cyber.cyan;
        for (var i = 0; i < 3; i++) {
          final k = (t - i * 0.12).clamp(0.0, 1.0);
          if (k <= 0) continue;
          canvas.drawCircle(
            center,
            size.shortestSide * (0.1 + k * 0.55),
            Paint()
              ..color = color.withValues(alpha: 0.35 * (1 - k))
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 * (1 - k),
          );
        }
      case GameplayEventType.wicket:
      case GameplayEventType.runOut:
        // Shards out of the stumps.
        final rnd = math.Random(_effectSeed);
        for (var i = 0; i < 14; i++) {
          final a = rnd.nextDouble() * math.pi * 2;
          final d =
              size.shortestSide * (0.05 + t * (0.2 + rnd.nextDouble() * 0.3));
          final p = center + Offset(math.cos(a), math.sin(a)) * d;
          canvas.drawCircle(
            p,
            math.max(1, 4 * (1 - t)),
            Paint()..color = Cyber.danger.withValues(alpha: 0.7 * (1 - t)),
          );
        }
      case GameplayEventType.catchTaken:
      case GameplayEventType.catchDropped:
        final ok = _effect == GameplayEventType.catchTaken;
        canvas.drawCircle(
          center,
          size.shortestSide * (0.08 + t * 0.2),
          Paint()
            ..color = (ok ? Cyber.danger : Cyber.lime).withValues(
              alpha: 0.55 * (1 - t),
            )
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5 * (1 - t),
        );
      default:
        break;
    }
  }

  /// One legal ball left. The world closes in.
  void _paintFinalBallVignette(Canvas canvas, Size size) {
    final pulse = 0.5 + 0.5 * math.sin(_visualSeconds * 3.4);
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.62),
          size.longestSide * 0.62,
          [
            Colors.transparent,
            Cyber.danger.withValues(
              alpha: 0.10 * kFoFinalBallVignette * (0.6 + 0.4 * pulse),
            ),
          ],
          const [0.55, 1.0],
        ),
    );
  }
}
```

### A.3 `lib/games/final_over/final_over_rig.dart`

<sub>949 lines</sub>

```dart
/// Procedural athlete rendering for Final Over.
///
/// Same language as Hoop Duel (see `games/rig/athlete_rig.dart`): no sprites,
/// limbs are thick round-cap strokes with IK-lite elbows and knees, only the
/// hip/shoulder/head are ever stored, and every pose is a *pure function* of
/// the engine's state — so what you see is a projection of `MatchState`, never
/// an animation the renderer invented.
///
/// Cricket adds four things basketball has no word for: a bat, a helmet with a
/// grille, leg pads, and batting gloves. All of them are built from the same
/// primitives so a batter reads as the same species as a Hoop Duel guard.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart' show Anchor, Vector2;
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/material.dart' show Colors;

import '../../config/theme.dart';
import '../../data/final_over_kits.dart';
import '../rig/athlete_rig.dart';

/// The frame of reference every dimension scales against.
const double kFoReferenceHeightM = 1.8;

// ─── Poses ────────────────────────────────────────────────────────────────────

enum FoBatterPose {
  stance,
  backlift,
  groundOff,
  groundStraight,
  groundLeg,
  groundBack,
  loftOff,
  loftStraight,
  loftLeg,
  loftBack,
  miss,
  bowled,
  running,
  slide,
  celebrate,
}

enum FoBowlerPose { ready, runUp, gather, release, followThrough }

enum FoUmpireSignal { idle, four, six, out }

/// A batter is a [RigPose] plus the one thing a basketball player never has:
/// a bat angle, in radians from the +x axis (canvas convention — y grows down,
/// so a negative angle points up-and-forward).
class FoBatterFrame {
  const FoBatterFrame(this.pose, this.batAngle);
  final RigPose pose;
  final double batAngle;
}

double _swing(double a, double b, double t) =>
    a + (b - a) * Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));

/// Batter pose for the given shot. [t] is 0→1 through the stroke (for the
/// swing poses) or free-running seconds (for stance/celebrate); [runPhase]
/// drives the run cycle and advances with *distance travelled*, not time, so
/// the feet never skate.
FoBatterFrame foBatterFrame(
  FoBatterPose kind,
  double t, {
  double runPhase = 0,
}) {
  switch (kind) {
    case FoBatterPose.stance:
      // Front-foot-forward guard: crouched, weight forward, BOTH hands gripping
      // the handle together out in front of the thigh with the bat hanging
      // straight down toward the front pad — a batsman actually holding the bat
      // ready, not arms folded across the chest. This is also the k=0 baseline
      // `backlift` animates FROM, so pressing HIT never jumps silhouettes.
      final breathe = sin(t * 2.4) * 0.015;
      return FoBatterFrame(
        RigPose(
          hip: 0.80 + breathe,
          lean: 0.30,
          footNear: const Offset(0.28, 0),
          footFar: const Offset(-0.20, 0),
          handNear: const Offset(0.20, 0.60), // low grip so the bat toe...
          handFar: const Offset(0.16, 0.64), // ...rests down at the foot line
          headBob: breathe,
        ),
        1.45, // bat stands down in front, toe resting by the front foot
      );

    case FoBatterPose.backlift:
      final k = t.clamp(0.0, 1.0);
      // `t` grows past 1.0 for as long as the hold continues — `overflow` is
      // real elapsed hold-time past full cock, used only for the idle coil
      // below so a long hold reads as tense, not frozen.
      final overflow = (t - 1.0).clamp(0.0, 1000.0);
      final coil = sin(overflow * 5.0) * 0.014;
      return FoBatterFrame(
        RigPose(
          hip: 0.80 + coil, // == stance
          lean: 0.30 - k * 0.10 + coil * 0.6, // == stance @ k=0
          footNear: const Offset(0.28, 0), // == stance
          footFar: const Offset(-0.20, 0), // == stance
          handNear: Offset(0.20 - k * 0.16, 0.60 - k * 1.26),
          handFar: Offset(0.16 - k * 0.16, 0.64 - k * 1.36),
          headBob: coil * 0.7,
        ),
        _swing(1.45, -2.35, k), // starts at stance's angle, cocks up behind
      );

    case FoBatterPose.groundOff:
    case FoBatterPose.groundStraight:
    case FoBatterPose.groundLeg:
    case FoBatterPose.groundBack:
      final k = t.clamp(0.0, 1.0);
      final lateral = switch (kind) {
        FoBatterPose.groundOff => -0.20, // opens the face, across the line
        FoBatterPose.groundLeg => 0.22, // whips it away to leg
        FoBatterPose.groundBack => -0.08, // late hands, behind square
        _ => 0.0,
      };
      final finishAngle = switch (kind) {
        FoBatterPose.groundOff => -0.05,
        FoBatterPose.groundStraight => 0.35,
        FoBatterPose.groundLeg => 0.76,
        FoBatterPose.groundBack => 1.18,
        _ => 0.35,
      };
      final behind = kind == FoBatterPose.groundBack;
      return FoBatterFrame(
        RigPose(
          hip: _swing(0.86, behind ? 0.88 : 0.80, k),
          lean: _swing(0.12, behind ? 0.08 : 0.46, k),
          footNear: Offset(_swing(0.18, behind ? 0.10 : 0.34, k), 0),
          footFar: Offset(behind ? -0.34 : -0.24, 0),
          handNear: Offset(
            _swing(-0.02, (behind ? 0.02 : 0.44) + lateral, k),
            _swing(-0.62, behind ? 0.02 : -0.24, k),
          ),
          handFar: Offset(
            _swing(-0.06, (behind ? -0.04 : 0.36) + lateral, k),
            _swing(-0.68, behind ? -0.04 : -0.32, k),
          ),
        ),
        _swing(-2.35, finishAngle, k),
      );

    case FoBatterPose.loftOff:
    case FoBatterPose.loftStraight:
    case FoBatterPose.loftLeg:
    case FoBatterPose.loftBack:
      final k = t.clamp(0.0, 1.0);
      final lateral = switch (kind) {
        FoBatterPose.loftOff => -0.22,
        FoBatterPose.loftLeg => 0.24,
        FoBatterPose.loftBack => -0.10,
        _ => 0.0,
      };
      final finishAngle = switch (kind) {
        FoBatterPose.loftOff => -1.55,
        FoBatterPose.loftStraight => -1.15,
        FoBatterPose.loftLeg => -0.72,
        FoBatterPose.loftBack => 0.42,
        _ => -1.15,
      };
      final behind = kind == FoBatterPose.loftBack;
      // Front leg braces, torso opens up, hands finish high over the shoulder.
      return FoBatterFrame(
        RigPose(
          hip: _swing(0.86, behind ? 0.90 : 0.94, k),
          lean: _swing(0.14, behind ? -0.04 : -0.30, k),
          footNear: Offset(
            _swing(0.18, behind ? 0.08 : 0.38, k),
            _swing(0, behind ? 0.02 : 0.10, k),
          ),
          footFar: Offset(behind ? -0.34 : -0.26, 0),
          handNear: Offset(
            _swing(-0.02, (behind ? -0.02 : 0.30) + lateral, k),
            _swing(-0.60, behind ? -0.70 : -0.96, k),
          ),
          handFar: Offset(
            _swing(-0.06, (behind ? -0.08 : 0.22) + lateral, k),
            _swing(-0.66, behind ? -0.78 : -1.00, k),
          ),
          headBob: k * 0.02,
        ),
        _swing(-2.35, finishAngle, k),
      );

    case FoBatterPose.miss:
      // Swung through thin air — bat past the body, head chasing it.
      final k = t.clamp(0.0, 1.0);
      return FoBatterFrame(
        RigPose(
          hip: _swing(0.86, 0.84, k),
          lean: _swing(0.10, 0.30, k),
          footNear: const Offset(0.22, 0),
          footFar: const Offset(-0.24, 0),
          handNear: Offset(_swing(-0.02, 0.20, k), _swing(-0.60, -0.50, k)),
          handFar: Offset(_swing(-0.06, 0.12, k), _swing(-0.66, -0.56, k)),
          headBob: -0.02 * k,
        ),
        _swing(-2.35, -0.10, k),
      );

    case FoBatterPose.bowled:
      // The slump. Everything sags toward the stumps behind.
      final sag = min(1.0, t * 2.4);
      return FoBatterFrame(
        RigPose(
          hip: 0.86 - sag * 0.10,
          lean: 0.10 + sag * 0.34,
          footNear: const Offset(0.20, 0),
          footFar: const Offset(-0.20, 0),
          handNear: Offset(0.16, -0.26 + sag * 0.08),
          handFar: Offset(0.10, -0.30 + sag * 0.08),
          headBob: -0.07 * sag,
        ),
        _swing(-0.4, 1.6, sag), // bat drops
      );

    case FoBatterPose.running:
      final s = sin(runPhase);
      return FoBatterFrame(
        RigPose(
          hip: 0.90 + sin(runPhase * 2).abs() * 0.03,
          lean: 0.36,
          footNear: Offset(s * 0.40, max(0.0, sin(runPhase)) * 0.14),
          footFar: Offset(-s * 0.40, max(0.0, -sin(runPhase)) * 0.14),
          handNear: Offset(-s * 0.20 + 0.10, -0.44),
          handFar: Offset(s * 0.24 - 0.08, -0.46),
        ),
        -0.6, // bat carried back, tip trailing
      );

    case FoBatterPose.slide:
      // Bat stretched out for the crease.
      final k = t.clamp(0.0, 1.0);
      return FoBatterFrame(
        RigPose(
          hip: _swing(0.80, 0.44, k),
          lean: _swing(0.5, 0.95, k),
          footNear: Offset(_swing(0.30, -0.28, k), 0),
          footFar: Offset(_swing(-0.20, -0.52, k), 0.04),
          handNear: Offset(_swing(0.34, 0.62, k), _swing(-0.30, 0.02, k)),
          handFar: Offset(0.10, -0.34),
        ),
        0.2, // reaching for the line
      );

    case FoBatterPose.celebrate:
      final pump = sin(t * 9).abs();
      return FoBatterFrame(
        RigPose(
          hip: 0.94 + pump * 0.05,
          lean: -0.14,
          footNear: const Offset(0.18, 0),
          footFar: const Offset(-0.18, 0),
          handNear: Offset(0.12, -1.08 - pump * 0.08),
          handFar: const Offset(-0.18, -0.58),
          headBob: pump * 0.03,
        ),
        -1.7, // bat aloft
      );
  }
}

/// Bowler pose. [t] is 0→1 through the phase.
RigPose foBowlerPose(FoBowlerPose kind, double t, {double runPhase = 0}) {
  switch (kind) {
    case FoBowlerPose.ready:
      final breathe = sin(t * 2.0) * 0.015;
      return RigPose(
        hip: 0.92 + breathe,
        lean: 0.06,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: const Offset(0.14, -0.44),
        handFar: const Offset(-0.02, -0.48), // ball cupped at the chest
        headBob: breathe,
      );

    case FoBowlerPose.runUp:
      final s = sin(runPhase);
      return RigPose(
        hip: 0.90 + sin(runPhase * 2).abs() * 0.03,
        lean: 0.30,
        footNear: Offset(s * 0.44, max(0.0, sin(runPhase)) * 0.16),
        footFar: Offset(-s * 0.44, max(0.0, -sin(runPhase)) * 0.16),
        handNear: Offset(-s * 0.22 + 0.10, -0.46),
        handFar: Offset(s * 0.18 - 0.04, -0.50),
      );

    case FoBowlerPose.gather:
      // Coil: front knee up, bowling arm cocked back and low.
      final k = t.clamp(0.0, 1.0);
      return RigPose(
        hip: _swing(0.90, 0.98, k),
        lean: _swing(0.30, -0.16, k),
        footNear: Offset(_swing(0.30, 0.16, k), _swing(0.02, 0.40, k)),
        footFar: Offset(_swing(-0.30, -0.34, k), 0),
        handNear: Offset(_swing(0.10, 0.26, k), _swing(-0.46, -0.72, k)),
        handFar: Offset(_swing(-0.04, -0.34, k), _swing(-0.50, -0.10, k)),
      );

    case FoBowlerPose.release:
      // The arm comes over the top. `snap` is the whole point of the pose.
      final snap = t.clamp(0.0, 1.0);
      final armAngle = -2.25 + 2.75 * Curves.easeInCubic.transform(snap);
      return RigPose(
        hip: _swing(0.98, 0.88, snap),
        lean: _swing(-0.16, 0.42, snap),
        footNear: Offset(_swing(0.16, 0.40, snap), _swing(0.40, 0, snap)),
        footFar: Offset(_swing(-0.34, -0.30, snap), 0),
        handNear: Offset(cos(armAngle) * 0.52, sin(armAngle) * 0.52 - 0.36),
        handFar: Offset(_swing(-0.34, 0.18, snap), _swing(-0.10, -0.52, snap)),
      );

    case FoBowlerPose.followThrough:
      final k = t.clamp(0.0, 1.0);
      return RigPose(
        hip: _swing(0.88, 0.90, k),
        lean: _swing(0.42, 0.26, k),
        footNear: Offset(_swing(0.40, 0.20, k), 0),
        footFar: Offset(_swing(-0.30, -0.36, k), _swing(0, 0.14, k)),
        handNear: Offset(_swing(0.30, 0.06, k), _swing(0.10, -0.40, k)),
        handFar: Offset(_swing(0.18, -0.16, k), _swing(-0.52, -0.44, k)),
      );
  }
}

/// Umpire pose. The signals are the cheapest, loudest feedback in cricket —
/// the crowd knows it's a six because a man in a hat raised both arms.
RigPose foUmpirePose(FoUmpireSignal signal, double t) {
  switch (signal) {
    case FoUmpireSignal.idle:
      final breathe = sin(t * 1.8) * 0.012;
      return RigPose(
        hip: 0.92 + breathe,
        lean: 0.02,
        footNear: const Offset(0.12, 0),
        footFar: const Offset(-0.12, 0),
        handNear: const Offset(0.10, -0.20),
        handFar: const Offset(-0.10, -0.20),
        headBob: breathe,
      );
    case FoUmpireSignal.four:
      // One arm sweeping across the body.
      final k = min(1.0, t * 3);
      final wave = sin(t * 7) * 0.10 * k;
      return RigPose(
        hip: 0.92,
        lean: 0.04,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: Offset(
          _swing(0.10, -0.44, k) + wave,
          _swing(-0.20, -0.52, k),
        ),
        handFar: const Offset(-0.12, -0.20),
      );
    case FoUmpireSignal.six:
      // Both arms straight up. Unmistakable.
      final k = min(1.0, t * 3.4);
      return RigPose(
        hip: 0.92 + k * 0.03,
        lean: 0,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: Offset(0.12, _swing(-0.20, -1.14, k)),
        handFar: Offset(-0.12, _swing(-0.20, -1.12, k)),
      );
    case FoUmpireSignal.out:
      // The finger.
      final k = min(1.0, t * 3.2);
      return RigPose(
        hip: 0.92,
        lean: 0.02,
        footNear: const Offset(0.12, 0),
        footFar: const Offset(-0.12, 0),
        handNear: Offset(_swing(0.10, 0.16, k), _swing(-0.20, -1.10, k)),
        handFar: const Offset(-0.10, -0.20),
      );
  }
}

// ─── Drawing ──────────────────────────────────────────────────────────────────

/// What sits on the head. A helmet is a batter, a cap is a fielder, a hat is
/// the umpire.
enum FoHeadGear { helmet, cap, hat }

/// Draws a batter: the rig, then the bat over the top of the near arm.
///
/// [trailBatAngles] are recent past bat angles (oldest first) drawn as
/// fading ghosts behind the live bat — a cheap motion trail for the fast
/// part of a committed swing. Empty by default (stance/backlift/preview
/// renders never pass any).
void drawFoBatter(
  Canvas canvas,
  FoBatterFrame frame, {
  required FinalOverKit kit,
  required FinalOverLook look,
  required double px,
  required double heightM,
  required int number,
  int facing = 1,
  List<double> trailBatAngles = const [],
}) {
  drawFoRig(
    canvas,
    frame.pose,
    kit: kit,
    look: look,
    px: px,
    heightM: heightM,
    number: number,
    facing: facing,
    gear: FoHeadGear.helmet,
    pads: true,
    gloves: true,
  );

  // Bat last, so it reads in front of the near arm.
  final scaleM = heightM / kFoReferenceHeightM;
  final shoulderY = frame.pose.hip * scaleM + 0.50 * scaleM;
  final shoulder = Offset(sin(frame.pose.lean) * 0.3 * px, -shoulderY * px);
  final grip = shoulder + frame.pose.handNear * (scaleM * px);
  for (var i = 0; i < trailBatAngles.length; i++) {
    final fade = 0.12 + 0.16 * i; // oldest faintest, newest brightest
    _drawBat(canvas, grip, trailBatAngles[i], px, scaleM, kit, alpha: fade);
  }
  _drawBat(canvas, grip, frame.batAngle, px, scaleM, kit);
}

/// Draws the bowler. [ballInHand] paints the ball at the bowling hand until it
/// leaves it.
void drawFoBowler(
  Canvas canvas,
  RigPose pose, {
  required FinalOverKit kit,
  required FinalOverLook look,
  required double px,
  required double heightM,
  required int number,
  int facing = 1,
  bool ballInHand = false,
}) {
  drawFoRig(
    canvas,
    pose,
    kit: kit,
    look: look,
    px: px,
    heightM: heightM,
    number: number,
    facing: facing,
    gear: FoHeadGear.cap,
    pads: false,
    gloves: false,
  );

  if (!ballInHand) return;
  final scaleM = heightM / kFoReferenceHeightM;
  final shoulderY = pose.hip * scaleM + 0.50 * scaleM;
  final shoulder = Offset(sin(pose.lean) * 0.3 * px, -shoulderY * px);
  final hand = shoulder + pose.handNear * (scaleM * px);
  canvas.drawCircle(hand, px * 0.055, Paint()..color = _ballRed);
  canvas.drawArc(
    Rect.fromCircle(center: hand, radius: px * 0.055),
    -pi * 0.8,
    pi * 0.7,
    false,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = px * 0.012,
  );
}

/// Draws the umpire — white coat, black hat, no number.
void drawFoUmpire(
  Canvas canvas,
  RigPose pose, {
  required double px,
  required double heightM,
  int facing = 1,
}) {
  drawFoRig(
    canvas,
    pose,
    kit: _umpireKit,
    look: const FinalOverLook(skin: Color(0xFFC68642), hair: Color(0xFF1C1310)),
    px: px,
    heightM: heightM,
    number: -1, // suppressed
    facing: facing,
    gear: FoHeadGear.hat,
    pads: false,
    gloves: false,
  );
}

const _umpireKit = FinalOverKit(
  id: '_umpire',
  name: 'UMPIRE',
  primary: Color(0xFFE8ECF3),
  secondary: Color(0xFF9AA8C7),
  accent: Color(0xFF2A3550),
);

const _ballRed = Color(0xFFC4342B);

/// The core rig — everything a Final Over actor has in common. Kept top-level
/// so both the batter and the bowler can build on it.
void drawFoRig(
  Canvas canvas,
  RigPose pose, {
  required FinalOverKit kit,
  required FinalOverLook look,
  required double px,
  required double heightM,
  required int number,
  required FoHeadGear gear,
  required bool pads,
  required bool gloves,
  int facing = 1,
}) {
  final scaleM = heightM / kFoReferenceHeightM;

  // Athlete-local px, y up → canvas y down. Feet anchored at the origin.
  Offset pt(double xM, double yM) => Offset(xM * px, -yM * px);

  final hip = pt(0, pose.hip * scaleM);
  final shoulderY = pose.hip * scaleM + 0.50 * scaleM;
  final shoulder = pt(sin(pose.lean) * 0.3, shoulderY);
  final headCenter = pt(
    sin(pose.lean) * 0.42,
    shoulderY + 0.23 * scaleM + pose.headBob,
  );

  final strokeBody = Paint()
    ..color = kit.primary
    ..strokeWidth = px * 0.19
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final strokeSkin = Paint()
    ..color = look.skin
    ..strokeWidth = px * 0.095
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final strokeSkinFar = Paint()
    ..color = rigDarken(look.skin, 0.25)
    ..strokeWidth = px * 0.095
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  // Cricket whites are trousers, not shorts — the leg stroke runs full length.
  final strokeTrouser = Paint()
    ..color = rigDarken(kit.primary, 0.15)
    ..strokeWidth = px * 0.15
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  // Legs (far first, darker — painter's algorithm gives depth for free).
  rigLimb(
    canvas,
    hip,
    pt(pose.footFar.dx * scaleM, pose.footFar.dy * scaleM),
    bend: -0.22 * px,
    upper: strokeTrouser,
    lower: pads ? _padPaint(rigDarken(kit.secondary, 0.25), px) : strokeTrouser,
    lowerOverlay: pads ? rigDarken(kit.secondary, 0.32) : null,
    shoe: rigDarken(kit.accent, 0.2),
    shoeAccent: rigDarken(kit.secondary, 0.2),
    px: px,
  );
  rigLimb(
    canvas,
    hip,
    pt(pose.footNear.dx * scaleM, pose.footNear.dy * scaleM),
    bend: -0.26 * px,
    upper: strokeTrouser,
    lower: pads ? _padPaint(kit.secondary, px) : strokeTrouser,
    lowerOverlay: pads ? kit.secondary : null,
    shoe: kit.accent,
    shoeAccent: kit.secondary,
    px: px,
  );

  // Far arm, behind the torso.
  rigLimb(
    canvas,
    shoulder,
    shoulder + pose.handFar * (scaleM * px),
    bend: 0.2 * px,
    upper: strokeSkinFar,
    lower: strokeSkinFar,
    lowerOverlay: rigDarken(kit.secondary, 0.25),
    px: px,
  );

  // Torso.
  canvas.drawLine(hip, shoulder, strokeBody);
  canvas.drawLine(
    Offset(hip.dx + px * 0.04, hip.dy),
    Offset(shoulder.dx + px * 0.04, shoulder.dy),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = px * 0.05
      ..strokeCap = StrokeCap.round,
  );

  // Shirt trim.
  canvas.drawLine(
    Offset.lerp(hip, shoulder, 0.1)!,
    Offset.lerp(hip, shoulder, 0.9)!,
    Paint()
      ..color = kit.secondary
      ..strokeWidth = px * 0.04
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset.lerp(hip, shoulder, 0.15)!,
    Offset.lerp(hip, shoulder, 0.4)!,
    Paint()
      ..color = kit.accent
      ..strokeWidth = px * 0.05
      ..strokeCap = StrokeCap.round,
  );

  // Shoulder bar — widens the silhouette into a T.
  canvas.drawLine(
    shoulder + Offset(-0.15 * scaleM * px, 0),
    shoulder + Offset(0.15 * scaleM * px, 0),
    Paint()
      ..color = kit.primary
      ..strokeWidth = px * 0.15
      ..strokeCap = StrokeCap.round,
  );

  // Shirt number. The canvas is X-flipped by facing, so un-flip locally to keep
  // the digits readable in both directions.
  if (number >= 0) {
    final numberPos = Offset.lerp(hip, shoulder, 0.55)!;
    canvas.save();
    canvas.translate(numberPos.dx, numberPos.dy);
    canvas.scale(facing.toDouble(), 1);
    rigNumberPaint(
      kit.accent,
      px * 0.2,
    ).render(canvas, '$number', Vector2.zero(), anchor: Anchor.center);
    canvas.restore();
  }

  _drawHead(canvas, headCenter, scaleM * px, gear, kit, look);

  // Near arm, in front.
  rigLimb(
    canvas,
    shoulder,
    shoulder + pose.handNear * (scaleM * px),
    bend: 0.24 * px,
    upper: strokeSkin,
    lower: strokeSkin,
    lowerOverlay: gloves ? kit.secondary : rigDarken(kit.secondary, 0.1),
    px: px,
  );
}

Paint _padPaint(Color color, double px) => Paint()
  ..color = color
  ..strokeWidth = px * 0.13
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

void _drawHead(
  Canvas canvas,
  Offset center,
  double unit,
  FoHeadGear gear,
  FinalOverKit kit,
  FinalOverLook look,
) {
  final r = 0.150 * unit;

  canvas.drawCircle(center, r, Paint()..color = look.skin);
  // Volume: a dark arc over the crown.
  canvas.drawArc(
    Rect.fromCircle(center: center, radius: r),
    -pi / 2,
    pi,
    false,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.3,
  );

  switch (gear) {
    case FoHeadGear.helmet:
      // Dome in the kit colour…
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 1.08),
        pi,
        pi,
        false,
        Paint()
          ..color = kit.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.70,
      );
      // …a peak over the brow…
      canvas.drawLine(
        center + Offset(r * 0.1, -r * 0.42),
        center + Offset(r * 1.15, -r * 0.30),
        Paint()
          ..color = rigDarken(kit.primary, 0.3)
          ..strokeWidth = r * 0.20
          ..strokeCap = StrokeCap.round,
      );
      // …and the grille. A flat lit line, never a blur — THE GLOW RULE holds
      // even on the one thing the player stares at all match.
      canvas.drawLine(
        center + Offset(r * 0.20, r * 0.05),
        center + Offset(r * 1.02, r * 0.05),
        Paint()
          ..color = kit.secondary
          ..strokeWidth = r * 0.16
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        center + Offset(r * 0.24, r * 0.46),
        center + Offset(r * 0.96, r * 0.46),
        Paint()
          ..color = kit.secondary
          ..strokeWidth = r * 0.16
          ..strokeCap = StrokeCap.round,
      );
    case FoHeadGear.cap:
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 1.06),
        pi,
        pi,
        false,
        Paint()
          ..color = look.hair
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.62,
      );
      canvas.drawLine(
        center + Offset(-r * 0.9, -r * 0.35),
        center + Offset(r * 0.9, -r * 0.35),
        Paint()
          ..color = kit.primary
          ..strokeWidth = r * 0.34
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        center + Offset(r * 0.5, -r * 0.42),
        center + Offset(r * 1.35, -r * 0.42),
        Paint()
          ..color = rigDarken(kit.primary, 0.25)
          ..strokeWidth = r * 0.18
          ..strokeCap = StrokeCap.round,
      );
    case FoHeadGear.hat:
      // Wide-brim umpire hat.
      canvas.drawLine(
        center + Offset(-r * 1.3, -r * 0.30),
        center + Offset(r * 1.3, -r * 0.30),
        Paint()
          ..color = const Color(0xFF141B2B)
          ..strokeWidth = r * 0.18
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        Rect.fromCircle(
          center: center.translate(0, -r * 0.22),
          radius: r * 0.9,
        ),
        pi,
        pi,
        false,
        Paint()
          ..color = const Color(0xFF141B2B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.55,
      );
  }
}

/// The bat: three tones — a dark edge, a grip, and a blade that catches the
/// light. Drawn in its own rotated space so the shot poses only have to think
/// about one angle.
void _drawBat(
  Canvas canvas,
  Offset grip,
  double angle,
  double px,
  double scaleM,
  FinalOverKit kit, {
  double alpha = 1.0,
}) {
  final len = 0.62 * scaleM * px;
  final width = 0.115 * scaleM * px;

  canvas.save();
  canvas.translate(grip.dx, grip.dy);
  canvas.rotate(angle);

  // Handle.
  canvas.drawLine(
    Offset(-len * 0.16, 0),
    Offset(len * 0.30, 0),
    Paint()
      ..color = const Color(0xFF23282F).withValues(alpha: alpha)
      ..strokeWidth = width * 0.38
      ..strokeCap = StrokeCap.round,
  );
  // Grip band, in the kit accent so the bat belongs to the team.
  canvas.drawLine(
    Offset(-len * 0.10, 0),
    Offset(len * 0.14, 0),
    Paint()
      ..color = kit.accent.withValues(alpha: alpha)
      ..strokeWidth = width * 0.46
      ..strokeCap = StrokeCap.round,
  );

  // Blade. Bleached willow, deliberately far lighter than any skin tone in
  // [FinalOverLook] — at this size a mid-tan blade reads as a forearm.
  final blade = RRect.fromRectAndRadius(
    Rect.fromLTWH(len * 0.30, -width / 2, len * 0.70, width),
    Radius.circular(width * 0.22),
  );
  canvas.drawRRect(
    blade.shift(Offset(0, width * 0.18)),
    Paint()
      ..color = const Color(
        0xFF6B4A22,
      ).withValues(alpha: alpha), // dark edge behind, for volume
  );
  canvas.drawRRect(
    blade,
    Paint()..color = const Color(0xFFF3E6C8).withValues(alpha: alpha),
  );
  // Spine + the dark outline that keeps the bat off the batter's arms.
  canvas.drawLine(
    Offset(len * 0.34, -width * 0.06),
    Offset(len * 0.94, -width * 0.06),
    Paint()
      ..color = const Color(0xFFFFF9EA).withValues(alpha: alpha)
      ..strokeWidth = width * 0.18
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawRRect(
    blade,
    Paint()
      ..color = const Color(0xFF5A3E1C).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.10,
  );

  canvas.restore();
}

// ─── Top-down field view ──────────────────────────────────────────────────────

/// A fielder seen from directly above — a rig makes no sense from up here, so
/// they're kit-coloured markers with a facing wedge. Same colour rules.
void drawFoFielderMark(
  Canvas canvas,
  Offset at,
  double radius, {
  required FinalOverKit kit,
  required bool active,
  Offset facing = Offset.zero,
}) {
  canvas.drawOval(
    Rect.fromCenter(
      center: at.translate(0, radius * 0.5),
      width: radius * 2.1,
      height: radius * 0.9,
    ),
    Paint()..color = const Color(0x55000000),
  );

  if (facing.distance > 0.01) {
    final dir = facing / facing.distance;
    final path = Path()
      ..moveTo(at.dx + dir.dx * radius * 2.2, at.dy + dir.dy * radius * 2.2)
      ..lineTo(at.dx - dir.dy * radius * 0.8, at.dy + dir.dx * radius * 0.8)
      ..lineTo(at.dx + dir.dy * radius * 0.8, at.dy - dir.dx * radius * 0.8)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = kit.primary.withValues(alpha: active ? 0.55 : 0.25),
    );
  }

  canvas.drawCircle(at, radius, Paint()..color = kit.primary);
  canvas.drawCircle(
    at,
    radius,
    Paint()
      ..color = active ? kit.accent : rigDarken(kit.primary, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.34,
  );
  canvas.drawCircle(at, radius * 0.42, Paint()..color = kit.secondary);
}

/// A runner seen from above. The active batter is the one thing on the field
/// worth a glow — everything else is flat (THE GLOW RULE).
void drawFoRunnerMark(
  Canvas canvas,
  Offset at,
  double radius, {
  required FinalOverKit kit,
  required int number,
  required bool striker,
  bool danger = false,
}) {
  if (striker) {
    canvas.drawCircle(
      at,
      radius * 2.0,
      Paint()
        ..color = (danger ? Cyber.danger : Cyber.cyan).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }
  canvas.drawCircle(at, radius, Paint()..color = kit.primary);
  canvas.drawCircle(
    at,
    radius,
    Paint()
      ..color = kit.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.3,
  );
  rigNumberPaint(
    kit.secondary,
    radius * 1.1,
  ).render(canvas, '$number', Vector2(at.dx, at.dy), anchor: Anchor.center);
}
```

### A.4 `lib/games/rig/athlete_rig.dart`

<sub>175 lines</sub>

```dart
/// Shared primitives for the app's code-drawn athlete rigs.
///
/// No sprite assets anywhere: an athlete is limbs drawn as thick round-cap
/// strokes with IK-lite elbows/knees, posed parametrically from an engine's
/// body state. Hoop Duel established the language; Final Over speaks it too, so
/// the pose type and the drawing primitives live here rather than in either
/// game.
///
/// Rules of the language (keep them if you add a third rig):
///   • only three joints are ever stored — hip, shoulder, head. Elbows and
///     knees are *solved* by [rigLimb], never authored.
///   • every dimension scales by `heightM / referenceHeight`, every stroke
///     width is a fraction of `px` (pixels per world metre).
///   • two colour sources: a *livery* (primary/secondary/accent) dresses the
///     athlete, a *look* (skin/hair) is the person. Far limbs are the near
///     colour run through [rigDarken].
///   • volume is free: repeat a stroke offset along its normal in black @ 0.15.
///   • THE GLOW RULE — a rig never blurs. Lit lines (a visor, a helmet grille)
///     are flat strokes. The only blurred thing on a playfield is the one
///     "this is live" aura, and that belongs to the game, not the rig.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/text.dart';
import 'package:flutter/material.dart' show Colors;

import '../../config/theme.dart';

/// A pose in athlete-local metres: hip height, torso lean, foot targets
/// (relative to the point under the hip) and hand targets (relative to the
/// shoulder). x is forward (facing direction), y is up.
///
/// Hand offsets already use the canvas convention (negative dy = up) so they
/// add to the shoulder directly; foot offsets do not.
class RigPose {
  const RigPose({
    required this.hip,
    this.lean = 0,
    required this.footNear,
    required this.footFar,
    required this.handNear,
    required this.handFar,
    this.headBob = 0,
  });

  final double hip;
  final double lean;
  final Offset footNear;
  final Offset footFar;
  final Offset handNear;
  final Offset handFar;
  final double headBob;
}

final Map<String, TextPaint> _numberPaints = {};

/// Memoised Orbitron paint for a jersey number. Tabular so digits never jitter.
TextPaint rigNumberPaint(Color color, double fontSize) =>
    _numberPaints.putIfAbsent(
      '${color.toARGB32()}-${fontSize.toStringAsFixed(1)}',
      () => TextPaint(
        style: TextStyle(
          fontFamily: Cyber.displayFont,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

/// Pushes a colour toward the app's near-black background — never toward pure
/// black, which reads as a hole rather than shadow.
Color rigDarken(Color color, double amount) =>
    Color.lerp(color, const Color(0xFF05070B), amount)!;

/// Two-segment limb: the joint is solved as the midpoint pushed along the
/// segment normal. [bend] sign picks which way it buckles — negative for knees
/// (forward), positive for elbows (back).
///
/// Passing [shoe] draws a rotated sneaker/boot at the end instead of the small
/// wrist dot a hand gets. [lowerOverlay] paints a sleeve/pad over the top half
/// of the lower segment.
void rigLimb(
  Canvas canvas,
  Offset from,
  Offset to, {
  required double bend,
  required Paint upper,
  required Paint lower,
  required double px,
  Color? lowerOverlay,
  Color? shoe,
  Color? shoeAccent,
}) {
  final mid = Offset.lerp(from, to, 0.5)!;
  final dir = to - from;
  final len = dir.distance;
  final normal = len > 0.001
      ? Offset(-dir.dy / len, dir.dx / len)
      : const Offset(1, 0);
  final joint = mid + normal * bend;

  canvas.drawLine(from, joint, upper);
  canvas.drawLine(joint, to, lower);

  // Shadow pass for volume.
  final shadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.15)
    ..strokeWidth = upper.strokeWidth * 0.25
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(
    from - normal * (upper.strokeWidth * 0.2),
    joint - normal * (upper.strokeWidth * 0.2),
    shadow,
  );
  canvas.drawLine(
    joint - normal * (lower.strokeWidth * 0.2),
    to - normal * (lower.strokeWidth * 0.2),
    shadow,
  );

  // Overlay (arm sleeve / knee pad).
  if (lowerOverlay != null) {
    canvas.drawLine(
      joint,
      Offset.lerp(joint, to, 0.5)!,
      Paint()
        ..color = lowerOverlay
        ..strokeWidth = lower.strokeWidth * 1.05
        ..strokeCap = StrokeCap.round,
    );
  }

  // Hands — a small dot at the wrist end (legs pass a shoe instead).
  if (shoe == null) {
    canvas.drawCircle(to, px * 0.05, Paint()..color = lower.color);
    return;
  }

  final shoeDir = len > 0.001 ? dir / len : const Offset(0, 1);
  final shoeR = px * 0.085;
  canvas.save();
  canvas.translate(to.dx, to.dy);
  canvas.rotate(atan2(shoeDir.dy, shoeDir.dx));
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(shoeR * 0.3, 0),
      width: shoeR * 2.2,
      height: shoeR * 1.4,
    ),
    Paint()..color = shoe,
  );
  if (shoeAccent != null) {
    // Sole highlight.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(shoeR * 0.3, shoeR * 0.3),
        width: shoeR * 2.0,
        height: shoeR * 0.8,
      ),
      0,
      pi,
      false,
      Paint()
        ..color = shoeAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = px * 0.03,
    );
  }
  canvas.restore();
}
```

### A.5 `lib/models/final_over.dart`

<sub>256 lines</sub>

```dart
/// App-side model for Final Over — the bits the *game* needs that the rules
/// engine (the `final_over` package) deliberately knows nothing about: which
/// kit you picked, how hard a chase you asked for, what you have achieved
/// across sessions, and what a chase is worth in XP.
library;

import 'package:final_over/final_over.dart' show GameplayTuning;

/// How steep a chase to set. The engine picks the actual target from its
/// approved ladder (32–66); a tier just says which rungs are in play.
enum FinalOverTier { rookie, pro, elite }

extension FinalOverTierX on FinalOverTier {
  String get label => switch (this) {
    FinalOverTier.rookie => 'ROOKIE',
    FinalOverTier.pro => 'PRO',
    FinalOverTier.elite => 'ELITE',
  };

  /// The blurb under the tier tile — the whole pitch in six words.
  String get blurb => switch (this) {
    FinalOverTier.rookie => 'GET YOUR EYE IN',
    FinalOverTier.pro => 'THE HONEST CHASE',
    FinalOverTier.elite => 'BOUNDARIES OR BUST',
  };

  /// Targets this tier draws from. Every value is on the engine's ladder — do
  /// not invent one, or [GameplayTuning.targetOptions] and the balance report
  /// stop meaning anything.
  List<int> get targets => switch (this) {
    FinalOverTier.rookie => const [32, 36, 40],
    FinalOverTier.pro => const [44, 48, 52, 56],
    FinalOverTier.elite => const [58, 62, 66],
  };

  String get range => '${targets.first}–${targets.last}';

  /// Elite chases are worth more because they are, in fact, harder.
  double get xpMultiplier => switch (this) {
    FinalOverTier.rookie => 0.8,
    FinalOverTier.pro => 1.0,
    FinalOverTier.elite => 1.35,
  };

  /// What the tier actually *means*, mechanically. A tier that only moved the
  /// target left every chase equally razor-thin: the engine's default windows
  /// are elite windows, and nothing widened them for a beginner. So each tier
  /// now brings its own timing windows, its own wickets in hand, its own
  /// slip-fingered or safe-handed fielders, and its own OVERDRIVE price.
  ///
  /// Engine defaults are left alone and reproduced exactly by [elite] — the
  /// package's own balance suite still measures the game it was tuned against.
  GameplayTuning get tuning => switch (this) {
    FinalOverTier.rookie => GameplayTuning.rookie,
    FinalOverTier.pro => GameplayTuning.pro,
    FinalOverTier.elite => GameplayTuning.elite,
  };
}

/// Everything needed to start one chase.
class FinalOverMatchConfig {
  const FinalOverMatchConfig({
    required this.matchId,
    required this.seed,
    required this.tier,
    required this.target,
    required this.kitId,
    required this.batsmanIds,
    required this.opponentName,
    this.showHints = false,
  });

  final String matchId;
  final int seed;
  final FinalOverTier tier;
  final int target;
  final String kitId;
  final List<String> batsmanIds;

  /// Cosmetic rival identity for the shared matchmaking banner.
  final String opponentName;

  /// First chase only — the control deck explains itself, then never again.
  final bool showHints;
}

/// The result of one chase, as the app cares about it.
class FinalOverMatchSummary {
  const FinalOverMatchSummary({
    required this.matchId,
    required this.won,
    required this.tier,
    required this.runs,
    required this.target,
    required this.wickets,
    required this.legalBalls,
    required this.stars,
    required this.objectiveCompleted,
    required this.sixes,
    required this.fours,
    required this.bestCombo,
    required this.xp,
  });

  final String matchId;
  final bool won;
  final FinalOverTier tier;
  final int runs;
  final int target;
  final int wickets;
  final int legalBalls;
  final int stars;
  final bool objectiveCompleted;
  final int sixes;
  final int fours;
  final int bestCombo;
  final int xp;

  int get ballsToSpare => won ? (18 - legalBalls).clamp(0, 18) : 0;

  String get scoreLine => '$runs/$wickets';

  String get resultLabel => won ? 'CHASE COMPLETE' : 'CHASE FAILED';

  /// A letter grade for the result plate. Stars come from the engine; this is
  /// the same information said louder.
  String get grade {
    if (!won) return stars >= 2 ? 'C' : 'D';
    if (stars >= 3 && ballsToSpare >= 2) return 'S';
    if (stars >= 3) return 'A';
    if (stars >= 2) return 'B';
    return 'C';
  }
}

/// Career totals. Persisted; drives the lobby's record panel.
class FinalOverStats {
  const FinalOverStats({
    this.chases = 0,
    this.wins = 0,
    this.bestScore = 0,
    this.bestStars = 0,
    this.sixes = 0,
    this.fours = 0,
    this.bestCombo = 0,
    this.hintsSeen = false,
    this.kitId = 'voltage',
    this.tier = FinalOverTier.rookie,
  });

  final int chases;
  final int wins;
  final int bestScore;
  final int bestStars;
  final int sixes;
  final int fours;
  final int bestCombo;
  final bool hintsSeen;

  /// Lobby selections ride along with the stats — one blob, one write.
  final String kitId;
  final FinalOverTier tier;

  int get losses => (chases - wins).clamp(0, chases);

  String get winRate =>
      chases == 0 ? '—' : '${((wins / chases) * 100).round()}%';

  FinalOverStats merge(FinalOverMatchSummary s) => copyWith(
    chases: chases + 1,
    wins: wins + (s.won ? 1 : 0),
    bestScore: s.runs > bestScore ? s.runs : bestScore,
    bestStars: s.stars > bestStars ? s.stars : bestStars,
    sixes: sixes + s.sixes,
    fours: fours + s.fours,
    bestCombo: s.bestCombo > bestCombo ? s.bestCombo : bestCombo,
  );

  FinalOverStats copyWith({
    int? chases,
    int? wins,
    int? bestScore,
    int? bestStars,
    int? sixes,
    int? fours,
    int? bestCombo,
    bool? hintsSeen,
    String? kitId,
    FinalOverTier? tier,
  }) => FinalOverStats(
    chases: chases ?? this.chases,
    wins: wins ?? this.wins,
    bestScore: bestScore ?? this.bestScore,
    bestStars: bestStars ?? this.bestStars,
    sixes: sixes ?? this.sixes,
    fours: fours ?? this.fours,
    bestCombo: bestCombo ?? this.bestCombo,
    hintsSeen: hintsSeen ?? this.hintsSeen,
    kitId: kitId ?? this.kitId,
    tier: tier ?? this.tier,
  );

  Map<String, dynamic> toJson() => {
    'chases': chases,
    'wins': wins,
    'bestScore': bestScore,
    'bestStars': bestStars,
    'sixes': sixes,
    'fours': fours,
    'bestCombo': bestCombo,
    'hintsSeen': hintsSeen,
    'kitId': kitId,
    'tier': tier.name,
  };

  factory FinalOverStats.fromJson(Map<String, dynamic> json) => FinalOverStats(
    chases: json['chases'] as int? ?? 0,
    wins: json['wins'] as int? ?? 0,
    bestScore: json['bestScore'] as int? ?? 0,
    bestStars: json['bestStars'] as int? ?? 0,
    sixes: json['sixes'] as int? ?? 0,
    fours: json['fours'] as int? ?? 0,
    bestCombo: json['bestCombo'] as int? ?? 0,
    hintsSeen: json['hintsSeen'] as bool? ?? false,
    kitId: json['kitId'] as String? ?? 'voltage',
    tier: FinalOverTier.values.firstWhere(
      (t) => t.name == json['tier'],
      orElse: () => FinalOverTier.rookie,
    ),
  );
}

/// What a chase pays.
///
/// Deliberately generous on effort and stingy on repetition: you are rewarded
/// for runs you actually scored, for the stars the engine awarded, and for
/// finishing early — not for pressing PLAY. Losing still pays, because a
/// three-over chase you lost by two runs was a better game than one you won by
/// ten, and the player should not resent having played it.
int calculateFinalOverXp({
  required bool won,
  required int runs,
  required int wickets,
  required int stars,
  required bool objectiveCompleted,
  required int ballsToSpare,
  required FinalOverTier tier,
}) {
  var xp = won ? 30 : 10;
  xp += runs; // every run off the bat is worth something
  xp += stars * 8;
  if (objectiveCompleted) xp += 15;
  if (won) xp += ballsToSpare * 4; // finishing with balls in hand
  if (won && wickets == 0) xp += 10; // an unbeaten chase
  return (xp * tier.xpMultiplier).round();
}
```

### A.6 `lib/data/final_over_kits.dart`

<sub>157 lines</sub>

```dart
/// Content colours for Final Over's athletes.
///
/// Two independent sources, exactly as Hoop Duel splits them:
///   • a [FinalOverKit] is *clothing* — the shirt, the pads, the helmet, the
///     number. The player picks one in the lobby; the bowling side gets a
///     contrasting one.
///   • a [FinalOverLook] is *the person* — skin and hair. Never a team colour.
///
/// Everything else on screen (pitch, HUD, stumps) comes from `Cyber` tokens.
library;

import 'dart:ui';

/// A team kit: shirt [primary], trim [secondary], number/boots [accent].
class FinalOverKit {
  const FinalOverKit({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final String id;
  final String name;

  /// Shirt, helmet dome, shoulder bar. Trousers are this, darkened.
  final Color primary;

  /// Shirt trim, pads, gloves, sleeve.
  final Color secondary;

  /// Jersey number, boots, the second shirt stripe.
  final Color accent;
}

const finalOverKits = <FinalOverKit>[
  FinalOverKit(
    id: 'voltage',
    name: 'VOLTAGE',
    primary: Color(0xFF1B48D6),
    secondary: Color(0xFFEFF3FF),
    accent: Color(0xFF35E0FF),
  ),
  FinalOverKit(
    id: 'ember',
    name: 'EMBER',
    primary: Color(0xFFD83A1E),
    secondary: Color(0xFF2A1410),
    accent: Color(0xFFFFB53D),
  ),
  FinalOverKit(
    id: 'meridian',
    name: 'MERIDIAN',
    primary: Color(0xFF0E8A5F),
    secondary: Color(0xFFF2FFF9),
    accent: Color(0xFFB4FF3D),
  ),
  FinalOverKit(
    id: 'sovereign',
    name: 'SOVEREIGN',
    primary: Color(0xFF6A2BD9),
    secondary: Color(0xFFE9DDFF),
    accent: Color(0xFFFFD24A),
  ),
  FinalOverKit(
    id: 'monsoon',
    name: 'MONSOON',
    primary: Color(0xFF1F7FA8),
    secondary: Color(0xFF0B2C3B),
    accent: Color(0xFF7FE9FF),
  ),
  FinalOverKit(
    id: 'saffron',
    name: 'SAFFRON',
    primary: Color(0xFFE87722),
    secondary: Color(0xFF14243D),
    accent: Color(0xFFFFF0C2),
  ),
  FinalOverKit(
    id: 'obsidian',
    name: 'OBSIDIAN',
    primary: Color(0xFF37415C),
    secondary: Color(0xFF9AA8C7),
    accent: Color(0xFFFF3D77),
  ),
  FinalOverKit(
    id: 'coral',
    name: 'CORAL',
    primary: Color(0xFFE0407A),
    secondary: Color(0xFFFFE3EC),
    accent: Color(0xFF20E3B2),
  ),
];

/// The one kit every player starts with — no coin cost.
const finalOverFreeKitId = 'voltage';

/// Coin price for every non-free kit in the Shop.
const finalOverKitCoinPrice = 100;

bool isFinalOverKitFree(FinalOverKit kit) => kit.id == finalOverFreeKitId;

int finalOverKitPrice(FinalOverKit kit) =>
    isFinalOverKitFree(kit) ? 0 : finalOverKitCoinPrice;

/// Default owned kit ids for a fresh wallet.
List<String> defaultOwnedFinalOverKitIds() => [finalOverFreeKitId];

/// Ensures the free kit is always present and dedupes ids.
List<String> normalizeOwnedFinalOverKitIds(Iterable<String> ids) {
  final owned = ids.toSet()..add(finalOverFreeKitId);
  return owned.toList();
}

bool isFinalOverKitOwned(String kitId, Iterable<String> ownedKitIds) =>
    isFinalOverKitFree(finalOverKitById(kitId)) ||
    ownedKitIds.contains(kitId);

FinalOverKit finalOverKitById(String id) =>
    finalOverKits.firstWhere((k) => k.id == id, orElse: () => finalOverKits.first);

/// The bowling side always wears something other than the batter's kit, so the
/// two never read as one team.
FinalOverKit finalOverOpponentKit(String playerKitId) {
  final index = finalOverKits.indexWhere((k) => k.id == playerKitId);
  final safe = index < 0 ? 0 : index;
  return finalOverKits[(safe + 3) % finalOverKits.length];
}

/// Skin + hair. Same 5-tone ladder Hoop Duel's athlete looks are built from.
class FinalOverLook {
  const FinalOverLook({required this.skin, required this.hair});

  final Color skin;
  final Color hair;
}

const _looks = <FinalOverLook>[
  FinalOverLook(skin: Color(0xFF6B4423), hair: Color(0xFF17110D)),
  FinalOverLook(skin: Color(0xFF8D5524), hair: Color(0xFF1C1310)),
  FinalOverLook(skin: Color(0xFFC68642), hair: Color(0xFF2B1D14)),
  FinalOverLook(skin: Color(0xFFE0AC69), hair: Color(0xFF4A2F1B)),
  FinalOverLook(skin: Color(0xFFF1C27D), hair: Color(0xFF6B4A2A)),
];

/// Stable per-actor look. Uses a hand-rolled hash (never `String.hashCode`,
/// which is not stable across Dart versions) so a given actor keeps the same
/// face between sessions and between the lobby preview and the pitch.
FinalOverLook finalOverLookFor(String actorId) =>
    _looks[_stableHash(actorId) % _looks.length];

/// Shirt number for an actor, 0–99.
int finalOverNumberFor(String actorId) => _stableHash(actorId) % 100;

int _stableHash(String id) =>
    id.codeUnits.fold(0, (acc, unit) => (acc * 31 + unit) & 0x7fffffff);
```

### A.7 `lib/data/random_opponent_names.dart`

<sub>62 lines</sub>

```dart
import 'dart:math';

const List<String> _randomOpponentFirstNames = [
  'Aarav',
  'Mateo',
  'Luca',
  'Noah',
  'Elias',
  'Omar',
  'Kenji',
  'Rafael',
  'Dante',
  'Niko',
  'Sofia',
  'Maya',
  'Amara',
  'Leila',
  'Ines',
  'Yara',
  'Mina',
  'Talia',
  'Nora',
  'Elena',
  'Theo',
  'Kai',
  'Arjun',
  'Malik',
  'Diego',
];

const List<String> _randomOpponentLastNames = [
  'Sharma',
  'Rossi',
  'Tan',
  'Silva',
  'Okafor',
  'Haddad',
  'Santos',
  'Kovac',
  'Novak',
  'Mensah',
  'Garcia',
  'Petrov',
  'Kimani',
  'Moreau',
  'Rahman',
  'Bennett',
  'Alvarez',
  'Hassan',
  'Ito',
  'Diallo',
];

final List<String> randomOpponentNames = List.unmodifiable([
  for (final firstName in _randomOpponentFirstNames)
    for (final lastName in _randomOpponentLastNames) '$firstName $lastName',
]);

String randomOpponentName({Random? random}) {
  final rng = random ?? Random();
  return randomOpponentNames[rng.nextInt(randomOpponentNames.length)];
}
```

### A.8 `lib/blocs/final_over/final_over_state.dart`

<sub>55 lines</sub>

```dart
import '../../models/final_over.dart';

/// The coarse flow of a Final Over session. This is the ONLY thing the widget
/// tree rebuilds on — the six-ball chase itself runs at 60fps inside the Flame
/// game and reports through `ValueNotifier`s, never through here.
enum FinalOverPhase {
  /// In the lobby.
  idle,

  /// Match screen up, VS card + countdown running.
  intro,

  /// The chase is live.
  playing,

  /// The engine has called it; the result cinematic has not started yet.
  finished,

  /// The result cinematic is on screen.
  result,
}

class FinalOverState {
  const FinalOverState({
    this.phase = FinalOverPhase.idle,
    this.stats = const FinalOverStats(),
    this.config,
    this.summary,
    this.loaded = false,
  });

  final FinalOverPhase phase;
  final FinalOverStats stats;
  final FinalOverMatchConfig? config;
  final FinalOverMatchSummary? summary;
  final bool loaded;

  FinalOverTier get tier => stats.tier;
  String get kitId => stats.kitId;

  FinalOverState copyWith({
    FinalOverPhase? phase,
    FinalOverStats? stats,
    FinalOverMatchConfig? config,
    FinalOverMatchSummary? summary,
    bool? loaded,
    bool clearSummary = false,
  }) => FinalOverState(
    phase: phase ?? this.phase,
    stats: stats ?? this.stats,
    config: config ?? this.config,
    summary: clearSummary ? null : (summary ?? this.summary),
    loaded: loaded ?? this.loaded,
  );
}
```

### A.9 `lib/blocs/final_over/final_over_cubit.dart`

<sub>110 lines</sub>

```dart
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/final_over_kits.dart';
import '../../data/random_opponent_names.dart';
import '../../models/final_over.dart';
import '../../services/secure_storage_service.dart';
import 'final_over_state.dart';

/// Owns the Final Over *session*: lobby selections, the coarse phase machine,
/// and career stats.
///
/// It deliberately knows nothing about balls, runs or wickets — that is the
/// engine's job, and the renderer's. If this cubit ever grows a `score` field,
/// something has gone wrong.
class FinalOverCubit extends Cubit<FinalOverState> {
  FinalOverCubit(this._storage) : super(const FinalOverState());

  final SecureGameStorage _storage;
  final Random _random = Random();

  Future<void> load() async {
    final stats = await _storage.loadFinalOverStats();
    emit(state.copyWith(stats: stats, loaded: true));
  }

  /// Clamps an equipped kit the player no longer owns back to the free kit.
  void ensureEquippedKitOwned(Iterable<String> ownedKitIds) {
    if (isFinalOverKitOwned(state.stats.kitId, ownedKitIds)) return;
    selectKit(finalOverFreeKitId, ownedKitIds: ownedKitIds);
  }

  void selectTier(FinalOverTier tier) {
    if (tier == state.stats.tier) return;
    final stats = state.stats.copyWith(tier: tier);
    emit(state.copyWith(stats: stats));
    _storage.saveFinalOverStats(stats);
  }

  void selectKit(String kitId, {required Iterable<String> ownedKitIds}) {
    if (!isFinalOverKitOwned(kitId, ownedKitIds)) return;
    if (kitId == state.stats.kitId) return;
    final stats = state.stats.copyWith(kitId: kitId);
    emit(state.copyWith(stats: stats));
    _storage.saveFinalOverStats(stats);
  }

  /// Builds a chase. The seed is what makes a match reproducible — the engine
  /// derives the delivery sequence from it, so the same seed is the same over.
  FinalOverMatchConfig buildMatch({required List<String> batsmanIds}) {
    final tier = state.stats.tier;
    final targets = tier.targets;
    final config = FinalOverMatchConfig(
      matchId: 'finalover-${DateTime.now().microsecondsSinceEpoch}',
      seed: _random.nextInt(1 << 31),
      tier: tier,
      target: targets[_random.nextInt(targets.length)],
      kitId: state.stats.kitId,
      batsmanIds: List<String>.from(batsmanIds),
      opponentName: randomOpponentName(random: _random),
      showHints: !state.stats.hintsSeen,
    );
    emit(state.copyWith(
      config: config,
      phase: FinalOverPhase.intro,
      clearSummary: true,
    ));
    return config;
  }

  void beginPlay() {
    if (state.phase != FinalOverPhase.intro) return;
    emit(state.copyWith(phase: FinalOverPhase.playing));
  }

  void markHintsSeen() {
    if (state.stats.hintsSeen) return;
    final stats = state.stats.copyWith(hintsSeen: true);
    emit(state.copyWith(stats: stats));
    _storage.saveFinalOverStats(stats);
  }

  /// The engine has ended the match. Folds the result into career stats and
  /// parks in [FinalOverPhase.finished] so the screen can land the sound and
  /// the haptic before the cinematic starts.
  Future<void> onMatchEnded(FinalOverMatchSummary summary) async {
    final stats = state.stats.merge(summary);
    emit(state.copyWith(
      phase: FinalOverPhase.finished,
      summary: summary,
      stats: stats,
    ));
    await _storage.saveFinalOverStats(stats);
  }

  void showResult() {
    if (state.phase != FinalOverPhase.finished) return;
    emit(state.copyWith(phase: FinalOverPhase.result));
  }

  /// Walking out mid-chase. No stats, no XP — the match never happened.
  void abandonMatch() {
    if (state.phase == FinalOverPhase.idle) return;
    emit(state.copyWith(phase: FinalOverPhase.idle, clearSummary: true));
  }

  void backToLobby() =>
      emit(state.copyWith(phase: FinalOverPhase.idle, clearSummary: true));
}
```

## Appendix B — Play-layer widgets (verbatim)

Controls and HUD. These compile against Appendix A + D with no edits.

### B.1 `lib/screens/final_over/widgets/final_over_swing_surface.dart`

<sub>307 lines</sub>

```dart
import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/final_over/final_over_game.dart';

/// The whole pitch is the bat.
///
/// There is no HOLD TO SWING button any more: the player taps or swipes
/// *anywhere* over the play area to hit the ball. A tap drives it straight along
/// the ground; dominant swipes place it left/off, front/straight, right/leg or
/// back/behind. An upward front swipe or fast flick lofts the shot. The hit is
/// timed by the release, exactly as the engine already grades.
///
/// The surface is only live during the engine's legal swing window
/// ([FinalOverGame.canSwing]); outside it the layer is inert so the HUD, the
/// bottom deck and the overlays keep their own taps.
class FinalOverSwingSurface extends StatefulWidget {
  const FinalOverSwingSurface({required this.game, super.key});

  final FinalOverGame game;

  @override
  State<FinalOverSwingSurface> createState() => _FinalOverSwingSurfaceState();
}

class _FinalOverSwingSurfaceState extends State<FinalOverSwingSurface> {
  Offset? _origin;
  Offset? _current;
  Duration? _downStamp;
  SwingGesture _preview = SwingGesture.tap;

  FinalOverGame get _game => widget.game;

  void _onDown(PointerDownEvent event) {
    // Starts the render-only backlift coil; the engine no-ops if the window has
    // already shut between the rebuild and this event.
    _game.beginSwing();
    setState(() {
      _origin = event.localPosition;
      _current = event.localPosition;
      _downStamp = event.timeStamp;
      _preview = SwingGesture.tap;
    });
  }

  void _onMove(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null) return;
    setState(() {
      _current = event.localPosition;
      _preview = classifyBattingGesture(delta: event.localPosition - origin);
    });
  }

  void _onUp(PointerUpEvent event) {
    final origin = _origin;
    if (origin == null) {
      _reset();
      return;
    }
    final delta = event.localPosition - origin;
    final gesture = classifyBattingGesture(
      delta: delta,
      velocity: _velocity(delta, event.timeStamp),
    );
    _game.releaseSwing(
      direction: gesture.direction,
      elevation: gesture.elevation,
    );
    HapticFeedback.lightImpact();
    _reset();
  }

  void _onCancel(PointerCancelEvent event) {
    _game.cancelSwing();
    _reset();
  }

  double _velocity(Offset delta, Duration upStamp) {
    final downStamp = _downStamp;
    if (downStamp == null) return 0;
    final micros = (upStamp - downStamp).inMicroseconds;
    if (micros <= 0) return 0;
    return delta.distance / (micros / 1e6);
  }

  void _reset() {
    if (_origin == null && _current == null) return;
    setState(() {
      _origin = null;
      _current = null;
      _downStamp = null;
      _preview = SwingGesture.tap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _game.canSwing,
      builder: (context, live, _) {
        final origin = _origin;
        final current = _current;
        return IgnorePointer(
          ignoring: !live,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onCancel,
            child: CustomPaint(
              size: Size.infinite,
              painter: origin != null && current != null
                  ? _SwingAimPainter(
                      origin: origin,
                      current: current,
                      gesture: _preview,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// The shot a batting gesture resolves to. [direction] feeds `SwingCommand`;
/// [elevation] feeds it too (tap = grounded front drive).
@immutable
class SwingGesture {
  const SwingGesture(this.direction, this.elevation, {required this.isSwipe});

  final ShotDirection direction;
  final Elevation elevation;
  final bool isSwipe;

  /// The neutral resolution for a plain tap: a safe grounded drive.
  static const tap = SwingGesture(
    ShotDirection.straight,
    Elevation.ground,
    isSwipe: false,
  );

  @override
  bool operator ==(Object other) =>
      other is SwingGesture &&
      other.direction == direction &&
      other.elevation == elevation &&
      other.isSwipe == isSwipe;

  @override
  int get hashCode => Object.hash(direction, elevation, isSwipe);
}

/// Classify a batting gesture from its start→end displacement (and optional
/// release speed). Short travel is a tap → grounded straight drive. A longer
/// drag uses its dominant axis: left/right choose the cricket off/leg channels,
/// up drives in front and down plays behind the striker. An upward front swipe
/// lofts; every other direction needs a fast flick to leave the ground.
SwingGesture classifyBattingGesture({
  required Offset delta,
  double velocity = 0,
}) {
  const tapSlop = 24.0;
  const loftRise = 26.0; // upward travel (px) that turns a drive into a loft
  const loftSpeed = 900.0; // flick speed (px/s) that lofts regardless of angle

  final distance = delta.distance;
  if (distance < tapSlop) return SwingGesture.tap;

  final horizontal = delta.dx.abs() >= delta.dy.abs();
  final direction = horizontal
      ? delta.dx < 0
            ? ShotDirection.offSide
            : ShotDirection.legSide
      : delta.dy > 0
      ? ShotDirection.behind
      : ShotDirection.straight;
  final upwardFront =
      direction == ShotDirection.straight && delta.dy < -loftRise;
  final lofted = upwardFront || velocity >= loftSpeed;
  return SwingGesture(
    direction,
    lofted ? Elevation.loft : Elevation.ground,
    isSwipe: true,
  );
}

/// Draws the live aim feedback anchored at the finger: an origin pip, an arrow
/// toward the current point once the gesture qualifies as a swipe, and a
/// direction/elevation read-out. Loft tints violet to echo the LOFT accent.
class _SwingAimPainter extends CustomPainter {
  const _SwingAimPainter({
    required this.origin,
    required this.current,
    required this.gesture,
  });

  final Offset origin;
  final Offset current;
  final SwingGesture gesture;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = gesture.elevation == Elevation.loft
        ? Cyber.violet
        : Cyber.cyan;

    // Origin pip — where the swing was anchored.
    canvas.drawCircle(origin, 4, Paint()..color = Cyber.gold);
    canvas.drawCircle(
      origin,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.gold.withValues(alpha: .45),
    );

    if (gesture.isSwipe) {
      canvas.drawLine(
        origin,
        current,
        Paint()
          ..color = accent.withValues(alpha: .92)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      _drawArrowHead(canvas, origin, current, accent);
      _drawLabel(canvas, size, accent);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Color color) {
    final delta = to - from;
    final length = delta.distance;
    if (length < 1) return;
    final unit = delta / length;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final base = to - unit * 12;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo((base + perpendicular * 6).dx, (base + perpendicular * 6).dy)
      ..moveTo(to.dx, to.dy)
      ..lineTo((base - perpendicular * 6).dx, (base - perpendicular * 6).dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawLabel(Canvas canvas, Size size, Color accent) {
    final text =
        '${_directionLabel(gesture.direction)} · '
        '${gesture.elevation == Elevation.loft ? 'LOFT' : 'GROUND'}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: Cyber.label(9, color: accent, letterSpacing: 1.4),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Sit the read-out just above the finger, clamped on-screen.
    var dx = current.dx - painter.width / 2;
    dx = dx.clamp(8.0, size.width - painter.width - 8);
    var dy = current.dy - 30;
    if (dy < 8) dy = current.dy + 18;

    final bgRect = Rect.fromLTWH(
      dx - 8,
      dy - 4,
      painter.width + 16,
      painter.height + 8,
    );
    canvas.drawRect(bgRect, Paint()..color = Cyber.bg.withValues(alpha: .82));
    canvas.drawRect(
      bgRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: .55),
    );
    painter.paint(canvas, Offset(dx, dy));
  }

  static String _directionLabel(ShotDirection direction) => switch (direction) {
    ShotDirection.offSide => 'LEFT',
    ShotDirection.straight => 'FRONT',
    ShotDirection.legSide => 'RIGHT',
    ShotDirection.behind => 'BACK',
  };

  @override
  bool shouldRepaint(covariant _SwingAimPainter oldDelegate) =>
      oldDelegate.origin != origin ||
      oldDelegate.current != current ||
      oldDelegate.gesture != gesture;
}
```

### B.2 `lib/screens/final_over/widgets/final_over_controls.dart`

<sub>481 lines</sub>

```dart
import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/final_over/final_over_game.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// The deck. It has two faces:
///   • while the ball is coming — a slim status strip. The hit itself is no
///     longer a button here: the player taps or swipes ANYWHERE over the pitch
///     (see `FinalOverSwingSurface`) — a tap drives it, a swipe places it, a
///     flick up lofts it.
///   • once you've hit it — DO you run.
///
/// Plates, not buttons. Pressed is an accent *fill*, never a glow — the only
/// glow down here is the RUN plate when the risk is real, because that is the
/// decision the whole game hangs on.
class FinalOverControls extends StatelessWidget {
  const FinalOverControls({
    required this.game,
    required this.showHints,
    this.rookieAssist = false,
    super.key,
  });

  final FinalOverGame game;
  final bool showHints;
  final bool rookieAssist;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0.96),
            Cyber.bg.withValues(alpha: 0.80),
            Cyber.bg.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([game.phase, game.canRun]),
        builder: (context, _) {
          final running =
              _isRunningPhase(game.phase.value) || game.canRun.value;
          return AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: running
                  ? _RunningDeck(key: const ValueKey('run'), game: game)
                  : _BattingDeck(
                      key: const ValueKey('bat'),
                      game: game,
                      showHints: showHints,
                      rookieAssist: rookieAssist,
                    ),
            ),
          );
        },
      ),
    );
  }

  static bool _isRunningPhase(MatchPhase phase) =>
      phase == MatchPhase.runDecision ||
      phase == MatchPhase.runnersMoving ||
      phase == MatchPhase.throwInProgress;
}

// ── Batting ───────────────────────────────────────────────────────────────────

/// The batting face is now just a read-out. Since the swing moved onto the
/// pitch (`FinalOverSwingSurface`), this strip only coaches: what to do while
/// the ball comes, that the shot is played, and — for rookies — a recommended
/// flick derived from the delivery's line and length.
class _BattingDeck extends StatelessWidget {
  const _BattingDeck({
    required this.game,
    required this.showHints,
    required this.rookieAssist,
    super.key,
  });

  final FinalOverGame game;
  final bool showHints;
  final bool rookieAssist;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game.phase, game.canSwing]),
      builder: (context, _) {
        final live = game.canSwing.value;
        final committed = game.state.swingIntent != null;
        final delivery = game.state.currentDelivery;
        final recommendDirection = rookieAssist && live && delivery != null
            ? _directionForLine(delivery.line)
            : null;
        final recommendElevation = rookieAssist && live && delivery != null
            ? _elevationForLength(delivery.length)
            : null;
        return _BattingStatusStrip(
          phase: game.phase.value,
          live: live,
          committed: committed,
          verbose: showHints,
          recommendDirection: recommendDirection,
          recommendElevation: recommendElevation,
        );
      },
    );
  }

  static ShotDirection _directionForLine(DeliveryLine line) => switch (line) {
    DeliveryLine.wideOff || DeliveryLine.off => ShotDirection.offSide,
    DeliveryLine.middle => ShotDirection.straight,
    DeliveryLine.leg || DeliveryLine.wideLeg => ShotDirection.legSide,
  };

  static Elevation? _elevationForLength(DeliveryLength length) =>
      switch (length) {
        DeliveryLength.yorker || DeliveryLength.full => Elevation.ground,
        DeliveryLength.short => Elevation.loft,
        DeliveryLength.good => null,
      };
}

class _BattingStatusStrip extends StatelessWidget {
  const _BattingStatusStrip({
    required this.phase,
    required this.live,
    required this.committed,
    required this.verbose,
    this.recommendDirection,
    this.recommendElevation,
  });

  final MatchPhase phase;
  final bool live;
  final bool committed;
  final bool verbose;
  final ShotDirection? recommendDirection;
  final Elevation? recommendElevation;

  @override
  Widget build(BuildContext context) {
    final (label, helper, icon, accent) = _content();
    return Semantics(
      liveRegion: true,
      label: '$label. $helper',
      child: SizedBox(
        height: 34,
        child: ChamferedActionSurface(
          clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
          borderColor: live ? accent.withValues(alpha: 0.55) : Cyber.line,
          child: ColoredBox(
            color: Cyber.panel.withValues(alpha: 0.88),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(icon, color: accent, size: 15),
                  const SizedBox(width: 8),
                  Text(label, style: Cyber.display(10, color: Colors.white)),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 12, color: Cyber.line),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      helper,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        7.5,
                        color: live ? accent : Cyber.muted,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, String, IconData, Color) _content() {
    if (committed) {
      return (
        'SHOT PLAYED',
        'TRACK THE BALL',
        Icons.check_rounded,
        Cyber.success,
      );
    }
    if (live) {
      final recommend = recommendDirection != null
          ? 'TRY ${_directionLabel(recommendDirection!)}'
                '${recommendElevation != null ? ' · ${_elevationLabel(recommendElevation!)}' : ''}'
          : verbose
          ? 'SWIPE 4 WAYS · FLICK FAST TO LOFT'
          : 'TAP OR SWIPE THE PITCH';
      return (
        'TAP TO HIT',
        recommend,
        Icons.sports_cricket_rounded,
        Cyber.cyan,
      );
    }
    return switch (phase) {
      MatchPhase.bowlerRunUp => (
        'WATCH THE RELEASE',
        'HIT AS IT REACHES THE BAT',
        Icons.visibility_rounded,
        Cyber.cyan,
      ),
      MatchPhase.incomingBall => (
        'SWING CLOSED',
        'THE BALL HAS PASSED',
        Icons.timer_off_rounded,
        Cyber.muted,
      ),
      MatchPhase.contact ||
      MatchPhase.cameraTransition ||
      MatchPhase.fieldPlay => (
        'TRACK THE BALL',
        'RUN WHEN THE CALL APPEARS',
        Icons.radar_rounded,
        Cyber.cyan,
      ),
      _ => (
        'READ THE BALL',
        'TAP FRONT · SWIPE L/R/BACK',
        Icons.sports_cricket_rounded,
        Cyber.muted,
      ),
    };
  }
}

// ── Running ───────────────────────────────────────────────────────────────────

class _RunningDeck extends StatelessWidget {
  const _RunningDeck({required this.game, super.key});

  final FinalOverGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        game.risk,
        game.runProgress,
        game.completedRuns,
        game.canRun,
        game.canTurnBack,
      ]),
      builder: (context, _) {
        final risk = game.risk.value;
        final (riskLabel, riskColor) = switch (risk) {
          RiskLevel.safe => ('SAFE', Cyber.success),
          RiskLevel.close => ('CLOSE', Cyber.amber),
          RiskLevel.danger => ('DANGER', Cyber.danger),
        };
        final running = game.runProgress.value > 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Risk radar + runs banked.
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: riskColor.withValues(alpha: 0.14),
                    border: Border.all(color: riskColor.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: riskColor,
                          boxShadow: risk == RiskLevel.danger
                              ? Cyber.glow(riskColor, alpha: 0.8, blur: 7)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        riskLabel,
                        style: Cyber.label(
                          9,
                          color: riskColor,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${game.completedRuns.value}/3 RUNS',
                  style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1.4),
                ),
              ],
            ),
            if (running) ...[
              const SizedBox(height: 6),
              CyberProgressBar(
                value: game.runProgress.value,
                accent: riskColor,
                height: 4,
                animate: false,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _Plate(
                    label: game.canTurnBack.value ? 'TURN BACK' : 'HOLD',
                    icon: game.canTurnBack.value
                        ? Icons.u_turn_left_rounded
                        : Icons.pan_tool_rounded,
                    accent: Cyber.muted,
                    height: 58,
                    onTap: () {
                      if (game.canTurnBack.value) {
                        game.turnBack();
                      } else {
                        game.holdBall();
                      }
                      HapticFeedback.selectionClick();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: _Plate(
                    label: running ? 'RUN AGAIN' : 'RUN',
                    icon: Icons.directions_run_rounded,
                    accent: riskColor,
                    height: 58,
                    big: true,
                    // The one glow on the deck: taking a run when it's tight is
                    // the game's real decision, so the game shouts about it.
                    glow: risk != RiskLevel.safe,
                    onTap: () {
                      game.startRun();
                      HapticFeedback.mediumImpact();
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ── The plate ─────────────────────────────────────────────────────────────────

class _Plate extends StatefulWidget {
  const _Plate({
    required this.label,
    required this.accent,
    required this.onTap,
    this.icon,
    this.height = 46,
    this.big = false,
    this.glow = false,
  });

  final String label;
  final IconData? icon;
  final Color accent;

  /// Fires on pointer *down*, always.
  final VoidCallback onTap;
  final double height;
  final bool big;
  final bool glow;

  @override
  State<_Plate> createState() => _PlateState();
}

class _PlateState extends State<_Plate> {
  bool _down = false;

  void _release() {
    if (!_down) return;
    setState(() => _down = false);
  }

  @override
  Widget build(BuildContext context) {
    final on = _down;
    final accent = widget.accent;

    return Listener(
      onPointerDown: (_) {
        setState(() => _down = true);
        widget.onTap();
      },
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _release(),
      child: ChamferedActionSurface(
        clipper: const HudChamferClipper(bigCut: 10, smallCut: 3),
        borderColor: accent.withValues(alpha: on ? 0.9 : 0.4),
        borderWidth: on ? 1.6 : 1,
        glowColor: accent,
        glow: widget.glow ? 1 : 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: widget.height,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on
                ? accent.withValues(alpha: 0.26)
                : Cyber.panel.withValues(alpha: 0.85),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: widget.big ? 17 : 14, color: accent),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.display(
                    widget.big ? 13 : 10.5,
                    color: on ? Colors.white : accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _directionLabel(ShotDirection direction) => switch (direction) {
  ShotDirection.offSide => 'LEFT',
  ShotDirection.straight => 'FRONT',
  ShotDirection.legSide => 'RIGHT',
  ShotDirection.behind => 'BACK',
};

String _elevationLabel(Elevation elevation) => switch (elevation) {
  Elevation.ground => 'GROUND',
  Elevation.loft => 'LOFT',
};
```

### B.3 `lib/screens/final_over/widgets/final_over_hud.dart`

<sub>589 lines</sub>

```dart
import 'dart:math' as math;

import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/final_over/final_over_game.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// The chase, read at a glance. Every widget in here is a
/// [ValueListenableBuilder] over a notifier the Flame game pushes once a frame
/// — no bloc, no rebuild storm.
class FinalOverHudBar extends StatelessWidget {
  const FinalOverHudBar({required this.game, required this.onExit, super.key});

  final FinalOverGame game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 14, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Cyber.bg.withValues(alpha: 0.94),
            Cyber.bg.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onExit,
                icon: const Icon(Icons.close_rounded),
                color: Cyber.muted,
                iconSize: 20,
              ),
              const _ScoreBlock(),
              const SizedBox(width: 10),
              const _OverChip(),
              const Spacer(),
              const _ChaseCluster(),
            ],
          ),
          const SizedBox(height: 8),
          const _BallStrip(),
          const _BowlerLine(),
        ],
      ),
    );
  }
}

class _OverChip extends StatelessWidget {
  const _OverChip();

  @override
  Widget build(BuildContext context) {
    final game = _gameOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([game.currentOver, game.maximumOvers]),
      builder: (context, _) {
        final over = game.currentOver.value + 1;
        final max = game.maximumOvers.value;
        return CyberChip(
          label: 'OVER $over/$max',
          color: Cyber.cyan,
        );
      },
    );
  }
}

class _BowlerLine extends StatelessWidget {
  const _BowlerLine();

  @override
  Widget build(BuildContext context) {
    final game = _gameOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([game.bowlerName, game.nextBatterLabel]),
      builder: (context, _) {
        final next = game.nextBatterLabel.value;
        return Padding(
          padding: const EdgeInsets.only(left: 12, top: 6),
          child: Row(
            children: [
              Text(
                'BOWLING · ${game.bowlerName.value}',
                style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.3),
              ),
              if (next != null) ...[
                const SizedBox(width: 8),
                CyberChip(label: next, color: Cyber.lime),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock();

  @override
  Widget build(BuildContext context) {
    final game = _gameOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([game.score, game.wickets, game.target]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${game.score.value}',
                style: Cyber.display(
                  30,
                  color: Colors.white,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              Text(
                '/${game.wickets.value}',
                style: Cyber.display(
                  17,
                  color: Cyber.muted,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          Text(
            'TARGET ${game.target.value}',
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}

/// The one number that matters. Goes red when the required rate has passed the
/// point where a boundary an over saves you.
class _ChaseCluster extends StatelessWidget {
  const _ChaseCluster();

  @override
  Widget build(BuildContext context) {
    final game = _gameOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([
        game.runsNeeded,
        game.ballsLeft,
        game.freeHit,
        game.combo,
      ]),
      builder: (context, _) {
        final need = game.runsNeeded.value;
        final balls = game.ballsLeft.value;
        final desperate = balls > 0 && need > balls * 6;
        final color = desperate ? Cyber.danger : Colors.white;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              need <= 0 ? 'DONE' : 'NEED $need',
              style: Cyber.display(
                20,
                color: color,
                letterSpacing: 1,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            Text(
              'OFF $balls ${balls == 1 ? 'BALL' : 'BALLS'}',
              style: Cyber.label(
                8,
                color: desperate ? Cyber.danger : Cyber.muted,
                letterSpacing: 1.4,
              ),
            ),
            if (game.freeHit.value || game.combo.value > 1) ...[
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (game.combo.value > 1)
                    CyberChip(
                      label: '×${game.combo.value} COMBO',
                      color: Cyber.magenta,
                    ),
                  if (game.combo.value > 1 && game.freeHit.value)
                    const SizedBox(width: 5),
                  if (game.freeHit.value)
                    const CyberChip(label: 'FREE HIT', color: Cyber.gold),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Six tokens for the *current* over, plus ticks for overs already done.
class _BallStrip extends StatelessWidget {
  const _BallStrip();

  @override
  Widget build(BuildContext context) {
    final game = _gameOf(context);
    return AnimatedBuilder(
      animation: Listenable.merge([game.history, game.currentOver, game.maximumOvers]),
      builder: (context, _) {
        final history = game.history.value;
        final legal = history.where((b) => b.legal).toList();
        final overIndex = game.currentOver.value;
        final ballsPerOver = 6;
        final start = overIndex * ballsPerOver;
        final overBalls = legal.length > start
            ? legal.sublist(start, math.min(legal.length, start + ballsPerOver))
            : const <BallResult>[];
        final extrasThisOver = history
            .where(
              (b) =>
                  !b.legal &&
                  b.legalBallsBefore >= start &&
                  b.legalBallsBefore < start + ballsPerOver,
            )
            .take(3);
        return Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Row(
            children: [
              for (var o = 0; o < game.maximumOvers.value; o++) ...[
                if (o > 0) const SizedBox(width: 4),
                _OverTick(done: o < overIndex, live: o == overIndex),
              ],
              const SizedBox(width: 10),
              for (var i = 0; i < ballsPerOver; i++) ...[
                _BallToken(
                  result: i < overBalls.length ? overBalls[i] : null,
                  next: i == overBalls.length,
                ),
                if (i < ballsPerOver - 1) const SizedBox(width: 5),
              ],
              const Spacer(),
              for (final extra in extrasThisOver) ...[
                _ExtraToken(result: extra),
                const SizedBox(width: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _OverTick extends StatelessWidget {
  const _OverTick({required this.done, required this.live});

  final bool done;
  final bool live;

  @override
  Widget build(BuildContext context) {
    final color = live
        ? Cyber.cyan
        : done
        ? Cyber.success
        : Cyber.border;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: live || done ? color.withValues(alpha: 0.35) : Cyber.panel,
        border: Border.all(color: color.withValues(alpha: live ? 0.95 : 0.45)),
        boxShadow: live ? Cyber.glow(Cyber.cyan, alpha: 0.35, blur: 6) : null,
      ),
    );
  }
}

class _BallToken extends StatelessWidget {
  const _BallToken({required this.result, required this.next});

  final BallResult? result;
  final bool next;

  @override
  Widget build(BuildContext context) {
    final r = result;
    final (label, color) = switch (r) {
      null => ('·', Cyber.border),
      final b when b.isWicket => ('W', Cyber.danger),
      final b when b.boundary == 6 => ('6', Cyber.gold),
      final b when b.boundary == 4 => ('4', Cyber.cyan),
      final b when b.totalRuns == 0 => ('0', Cyber.muted),
      final b => ('${b.totalRuns}', Cyber.success),
    };
    final filled = r != null;

    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 5, smallCut: 2),
      child: Container(
        width: 26,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? color.withValues(alpha: 0.20)
              : Cyber.panel.withValues(alpha: 0.7),
          border: Border.all(
            // The ball about to be bowled is the live one — the only token
            // that gets a bright edge.
            color: next
                ? Cyber.cyan.withValues(alpha: 0.9)
                : color.withValues(alpha: filled ? 0.75 : 0.35),
            width: next ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: Cyber.display(
            11,
            color: filled ? color : Cyber.muted,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
      ),
    );
  }
}

class _ExtraToken extends StatelessWidget {
  const _ExtraToken({required this.result});
  final BallResult result;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: Cyber.amber.withValues(alpha: 0.14),
      border: Border.all(color: Cyber.amber.withValues(alpha: 0.5)),
    ),
    child: Text(
      result.extra == ExtraType.noBall ? 'NB' : 'WD',
      style: Cyber.label(7, color: Cyber.amber, letterSpacing: 0.8),
    ),
  );
}

/// OVERDRIVE charge. Banked by middling the ball; armed, it turns gold and the
/// next shot leaves the bat harder. Distinct from the *shot* power on the
/// meter, which you earn ball by ball with the backlift.
class FinalOverOverdriveRail extends StatelessWidget {
  const FinalOverOverdriveRail({required this.game, super.key});

  final FinalOverGame game;

  @override
  Widget build(BuildContext context) {
    final requirement = game.overdriveRequirement;
    return AnimatedBuilder(
      animation: Listenable.merge([
        game.powerSegments,
        game.powerArmed,
        game.canConfigureShot,
      ]),
      builder: (context, _) {
        final segments = game.powerSegments.value.clamp(0, requirement);
        final armed = game.powerArmed.value;
        final configuring = game.canConfigureShot.value;
        final ready = segments >= requirement && !armed;
        final canArm = configuring && ready;
        final label = armed
            ? 'OVERDRIVE ARMED'
            : ready
            ? 'OVERDRIVE READY • TAP TO ARM'
            : 'OVERDRIVE';
        final semanticsLabel = armed
            ? 'Overdrive armed'
            : ready
            ? 'Overdrive ready. Tap to arm'
            : 'Overdrive $segments of $requirement charged';

        return AnimatedSize(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment: Alignment.bottomCenter,
          child: configuring
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Semantics(
                    button: canArm,
                    enabled: canArm,
                    label: semanticsLabel,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: canArm
                          ? () {
                              game.activatePowerShot();
                              HapticFeedback.mediumImpact();
                            }
                          : null,
                      child: SizedBox(
                        height: 44,
                        child: ChamferedActionSurface(
                          clipper: const HudChamferClipper(
                            bigCut: 9,
                            smallCut: 3,
                          ),
                          borderColor: canArm
                              ? Cyber.gold.withValues(alpha: .9)
                              : armed
                              ? Cyber.gold.withValues(alpha: .7)
                              : Cyber.line,
                          borderWidth: canArm || armed ? 1.5 : 1,
                          glowColor: Cyber.gold,
                          glow: canArm ? 1 : 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            color: canArm || armed
                                ? Cyber.gold.withValues(alpha: .12)
                                : Cyber.panel.withValues(alpha: .84),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  size: 15,
                                  color: canArm || armed
                                      ? Cyber.gold
                                      : Cyber.muted,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Cyber.label(
                                          7.5,
                                          color: canArm || armed
                                              ? Cyber.gold
                                              : Cyber.muted,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      CyberProgressBar(
                                        value: requirement == 0
                                            ? 0
                                            : segments / requirement,
                                        accent: canArm || armed
                                            ? Cyber.gold
                                            : Cyber.cyan,
                                        height: 4,
                                        animate: false,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$segments/$requirement',
                                  style: Cyber.label(
                                    8,
                                    color: canArm || armed
                                        ? Cyber.gold
                                        : Cyber.muted,
                                    letterSpacing: 1,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

/// SIX / FOUR / OUT / PERFECT. Majors land with an elastic pop and a glow —
/// this is a moment, and moments are allowed to glow.
class FinalOverStingLayer extends StatelessWidget {
  const FinalOverStingLayer({required this.game, super.key});

  final FinalOverGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FinalOverSting?>(
      valueListenable: game.sting,
      builder: (context, sting, _) {
        if (sting == null) return const SizedBox.shrink();
        return Align(
          alignment: const Alignment(0, -0.32),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(sting.label),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: sting.major ? 520 : 320),
            curve: sting.major ? Curves.easeOutBack : Curves.easeOut,
            builder: (context, t, child) => Transform.scale(
              scale: sting.major ? 1.6 - 0.6 * t : 1.0,
              child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
            ),
            child: ClipPath(
              clipper: const HudChamferClipper(bigCut: 13, smallCut: 4),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: sting.major ? 24 : 17,
                  vertical: sting.major ? 11 : 8,
                ),
                decoration: BoxDecoration(
                  color: Cyber.bg.withValues(alpha: 0.92),
                  border: Border.all(
                    color: sting.color.withValues(alpha: 0.85),
                    width: 1.4,
                  ),
                  boxShadow: sting.major
                      ? Cyber.glow(sting.color, alpha: 0.4, blur: 22)
                      : null,
                ),
                child: Text(
                  sting.label,
                  style: Cyber.display(
                    sting.major ? 22 : 14,
                    color: sting.color,
                    letterSpacing: 3,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The HUD widgets are all built under the match screen, which puts the game
/// in scope via an [InheritedWidget]. Keeps the constructors from having to
/// thread `game` through six layers.
class FinalOverGameScope extends InheritedWidget {
  const FinalOverGameScope({
    required this.game,
    required super.child,
    super.key,
  });

  final FinalOverGame game;

  @override
  bool updateShouldNotify(FinalOverGameScope old) => old.game != game;
}

FinalOverGame _gameOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<FinalOverGameScope>()!.game;
```

### B.4 `lib/screens/final_over/widgets/final_over_overlays.dart`

<sub>142 lines</sub>

```dart
import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Between-over beat: new bowler walks in. Auto-dismisses.
class FinalOverBowlerRevealOverlay extends StatelessWidget {
  const FinalOverBowlerRevealOverlay({
    required this.overNumber,
    required this.bowlerName,
    required this.onDone,
    super.key,
  });

  final int overNumber;
  final String bowlerName;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDone,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.88),
        child: Center(
          child: CyberPanel(
            accent: Cyber.magenta,
            glow: true,
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OVER $overNumber',
                  style: Cyber.label(11, color: Cyber.muted, letterSpacing: 2.4),
                ),
                const SizedBox(height: 10),
                Text(
                  bowlerName,
                  style: Cyber.display(
                    34,
                    color: Colors.white,
                    letterSpacing: 2,
                  ).copyWith(
                    shadows: Cyber.glow(Cyber.magenta, alpha: 0.45, blur: 18)
                        .map(
                          (s) => Shadow(
                            color: s.color,
                            blurRadius: s.blurRadius,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TAKES THE BALL',
                  style: Cyber.label(10, color: Cyber.magenta, letterSpacing: 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pause. The chase is frozen exactly where it stood — the engine's clock does
/// not advance, so nothing is lost.
class FinalOverPauseOverlay extends StatelessWidget {
  const FinalOverPauseOverlay({
    required this.onResume,
    required this.onQuit,
    super.key,
  });

  final VoidCallback onResume;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: CyberPanel(
                accent: Cyber.cyan,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'CHASE PAUSED',
                      textAlign: TextAlign.center,
                      style: Cyber.display(
                        26,
                        color: Colors.white,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The over is held exactly where you left it.',
                      textAlign: TextAlign.center,
                      style: Cyber.body(12, color: Cyber.muted),
                    ),
                    const SizedBox(height: 20),
                    HudCtaButton(
                      label: 'RESUME',
                      icon: Icons.play_arrow_rounded,
                      accent: Cyber.cyan,
                      onTap: onResume,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: onQuit,
                      child: Text(
                        'QUIT WITHOUT REWARD',
                        style: Cyber.label(
                          10,
                          color: Cyber.danger,
                          letterSpacing: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

## Appendix C — Host screens (verbatim, reference only)

Shown so the wiring in §7 can be read in full. **Not compile-checked**: these import source-app systems listed in §9 (global `GameBloc`, audio scenes, matchmaking gate, level-up celebration, confirm dialog). Port them by applying §9.

### C.1 `lib/screens/final_over/final_over_match_screen.dart`

<sub>592 lines</sub>

```dart
import 'dart:async';

import 'package:final_over/final_over.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/final_over/final_over_cubit.dart';
import '../../blocs/final_over/final_over_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../config/theme.dart';
import '../../data/final_over_kits.dart';
import '../../games/final_over/final_over_game.dart';
import '../../models/avatar_frame_option.dart';
import '../../models/avatar_option.dart';
import '../../models/final_over.dart';
import '../../models/progression.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/game_audio_mappings.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/matchmaking/game_match_gate.dart';
import '../../widgets/matchmaking/game_matchmaking_config.dart';
import 'widgets/final_over_controls.dart';
import 'widgets/final_over_hud.dart';
import 'widgets/final_over_overlays.dart';
import 'widgets/final_over_result.dart';
import 'widgets/final_over_swing_surface.dart';

/// The chase: a full-bleed Flame pitch under the score HUD, sting banners, the
/// two-faced control deck, and the intro / pause / result
/// overlays.
///
/// Three owners, cleanly separated — the `final_over` package's
/// [MatchController] owns the rules, [FinalOverGame] owns the 60fps projection
/// of them, and [FinalOverCubit] owns the coarse session phase. This screen is
/// the wiring between them: it maps engine events to sound and haptics, and it
/// pays the player exactly once.
class FinalOverMatchScreen extends StatefulWidget {
  const FinalOverMatchScreen({
    required this.config,
    required this.onExit,
    super.key,
  });

  final FinalOverMatchConfig config;
  final VoidCallback onExit;

  @override
  State<FinalOverMatchScreen> createState() => _FinalOverMatchScreenState();
}

class _FinalOverMatchScreenState extends State<FinalOverMatchScreen>
    with WidgetsBindingObserver {
  late final FinalOverCubit _cubit;
  late final MatchController _controller;
  late final FinalOverGame _game;

  bool _rewardsDispatched = false;
  bool _paused = false;
  double _controlStackHeight = 116;
  int? _bowlerRevealOver;
  String? _bowlerRevealName;

  // Tallied from the engine's own ball ledger, never counted here.
  int _sixes = 0;
  int _fours = 0;
  int _bestCombo = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = context.read<FinalOverCubit>();

    final reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    // The tier is the difficulty: it sets the timing windows, the wickets in
    // hand and what OVERDRIVE costs. See [FinalOverTierX.tuning].
    _controller = MatchController(tuning: widget.config.tier.tuning);
    _game = FinalOverGame(
      controller: _controller,
      kit: finalOverKitById(widget.config.kitId),
      opponentKit: finalOverOpponentKit(widget.config.kitId),
      batsmanIds: widget.config.batsmanIds,
      onEvents: _onEvent,
      reducedMotion: reducedMotion,
    );
    _controller.startMatch(
      seed: widget.config.seed,
      target: widget.config.target,
    );

    AudioController.instance.enterScene(AudioScene.finalOver);
  }

  /// CHASE AGAIN builds the next match on the shared cubit and *then* replaces
  /// this route, so the new screen is already up — and already owns the cubit —
  /// by the time this one is torn down. Anything global we clean up on the way
  /// out (the session, the music) would land on the new chase instead of ours.
  bool get _replacedByNextChase =>
      _cubit.state.config?.matchId != widget.config.matchId;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_replacedByNextChase) {
      AudioController.instance.leaveScene(AudioScene.finalOver);
      // Walking out mid-chase discards it — no stats, no XP.
      final phase = _cubit.state.phase;
      if (phase == FinalOverPhase.intro || phase == FinalOverPhase.playing) {
        _cubit.abandonMatch();
      }
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !_paused) {
      _game.backgrounded();
      if (mounted) setState(() => _paused = true);
    }
  }

  // ── engine events → sound / haptics / cubit beats ─────────────────────────
  void _onEvent(GameplayEvent event) {
    final s = _controller.state;
    switch (event.type) {
      case GameplayEventType.deliveryPrepared:
        playSound(finalOverSoundForEvent(event.type)!);
      case GameplayEventType.ballReleased:
        playSound(finalOverSoundForEvent(event.type)!);
      case GameplayEventType.contactResolved:
        final outcome = s.contactOutcome;
        if (outcome == null) break;
        switch (outcome.timing) {
          case TimingGrade.perfect:
            playSound(
              finalOverSoundForEvent(event.type, timing: outcome.timing)!,
            );
            HapticFeedback.mediumImpact();
          case TimingGrade.good:
            playSound(
              finalOverSoundForEvent(event.type, timing: outcome.timing)!,
            );
            HapticFeedback.selectionClick();
          case TimingGrade.early:
          case TimingGrade.late:
            playSound(
              finalOverSoundForEvent(event.type, timing: outcome.timing)!,
            );
          case TimingGrade.poor:
            playSound(
              finalOverSoundForEvent(event.type, timing: outcome.timing)!,
            );
          case TimingGrade.miss:
            playSound(
              finalOverSoundForEvent(event.type, timing: outcome.timing)!,
            );
        }
      case GameplayEventType.boundary:
        final six = s.lastResult?.boundary == 6 || s.ledger.boundary == 6;
        playSound(finalOverSoundForEvent(event.type, six: six)!);
        HapticFeedback.heavyImpact();
      case GameplayEventType.wicket:
        playSound(finalOverSoundForEvent(event.type)!);
        HapticFeedback.heavyImpact();
      case GameplayEventType.runOut:
        playSound(finalOverSoundForEvent(event.type)!);
        HapticFeedback.heavyImpact();
      case GameplayEventType.catchTaken:
        playSound(finalOverSoundForEvent(event.type)!);
        HapticFeedback.heavyImpact();
      case GameplayEventType.catchDropped:
        playSound(finalOverSoundForEvent(event.type)!);
      case GameplayEventType.powerShotActivated:
        playSound(finalOverSoundForEvent(event.type)!);
        HapticFeedback.mediumImpact();
      case GameplayEventType.runStarted:
      case GameplayEventType.runnerTurnedBack:
        playSound(finalOverSoundForEvent(event.type)!);
      case GameplayEventType.runCompleted:
        playSound(finalOverSoundForEvent(event.type)!);
        HapticFeedback.selectionClick();
      case GameplayEventType.ballPickedUp:
        playSound(finalOverSoundForEvent(event.type)!);
      case GameplayEventType.throwStarted:
        playSound(finalOverSoundForEvent(event.type)!);
      case GameplayEventType.cameraTransitionStarted:
        playSound(finalOverSoundForEvent(event.type)!);
      case GameplayEventType.extraAwarded:
        playSound(finalOverSoundForEvent(event.type)!);
      case GameplayEventType.deliveryCompleted:
        _tallyBall(s.lastResult);
        // Last ball of the innings still coming: let the crowd tell them.
        if (s.ballsRemaining == 1 && !s.isTerminal) {
          playSound(
            finalOverSoundForEvent(event.type, finalBallPressure: true)!,
          );
        }
      case GameplayEventType.overComplete:
        final nextOver = event.payload['nextOver'] as int? ?? (s.currentOver + 1);
        final name = event.payload['bowler'] as String? ?? s.currentBowler?.name;
        if (name != null) {
          playSound(SoundEffect.bannerSlam);
          HapticFeedback.mediumImpact();
          setState(() {
            _bowlerRevealOver = nextOver;
            _bowlerRevealName = name;
          });
          Future.delayed(const Duration(milliseconds: 1600), () {
            if (!mounted) return;
            setState(() {
              _bowlerRevealOver = null;
              _bowlerRevealName = null;
            });
          });
        }
      case GameplayEventType.matchEnded:
        _onMatchEnded();
      case GameplayEventType.paused:
        AudioController.instance.setSceneMusicEnabled(false);
      case GameplayEventType.resumed:
        AudioController.instance.setSceneMusicEnabled(true);
      default:
        break;
    }
  }

  void _tallyBall(BallResult? ball) {
    if (ball == null) return;
    if (ball.boundary == 6) _sixes += 1;
    if (ball.boundary == 4) _fours += 1;
    final combo = _controller.state.combo;
    if (combo > _bestCombo) _bestCombo = combo;
  }

  void _onMatchEnded() {
    if (_rewardsDispatched) return;
    _rewardsDispatched = true;

    final s = _controller.state;
    final won = s.phase == MatchPhase.won;
    final xp = calculateFinalOverXp(
      won: won,
      runs: s.score,
      wickets: s.wickets,
      stars: s.stars,
      objectiveCompleted: s.objectiveCompleted,
      ballsToSpare: won
          ? (s.maximumLegalBalls - s.legalBalls).clamp(0, s.maximumLegalBalls)
          : 0,
      tier: widget.config.tier,
    );
    final summary = FinalOverMatchSummary(
      matchId: widget.config.matchId,
      won: won,
      tier: widget.config.tier,
      runs: s.score,
      target: s.target,
      wickets: s.wickets,
      legalBalls: s.legalBalls,
      stars: s.stars,
      objectiveCompleted: s.objectiveCompleted,
      sixes: _sixes,
      fours: _fours,
      bestCombo: _bestCombo,
      xp: xp,
    );

    unawaited(_cubit.onMatchEnded(summary));
    context.read<GameBloc>().add(
      FinalOverFinished(
        matchId: summary.matchId,
        runs: summary.runs,
        target: summary.target,
        wickets: summary.wickets,
        resultLabel: summary.resultLabel,
        tierLabel: summary.tier.label,
        grade: summary.grade,
        stars: summary.stars,
        xp: xp,
      ),
    );

    playSound(won ? SoundEffect.cricketVictory : SoundEffect.cricketDefeat);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _cubit.showResult();
    });
  }

  // ── flow ──────────────────────────────────────────────────────────────────
  void _beginPlay() {
    _cubit.beginPlay();
    _cubit.markHintsSeen();
    // The engine parks in matchIntro and bowls nothing until this lands.
    _game.start();
  }

  void _pause() {
    if (_paused) return;
    _game.pause();
    AudioController.instance.setSceneMusicEnabled(false);
    setState(() => _paused = true);
  }

  void _resume() {
    if (!_paused) return;
    _game.resume();
    AudioController.instance.setSceneMusicEnabled(true);
    setState(() => _paused = false);
  }

  Future<void> _confirmExit() async {
    final phase = _cubit.state.phase;
    if (phase == FinalOverPhase.result || phase == FinalOverPhase.finished) {
      widget.onExit();
      return;
    }
    _pause();
    final leave = await showCyberConfirmDialog(
      context,
      title: 'LEAVE THE CHASE?',
      message: 'Walking out abandons the chase — no XP, no record.',
      confirmLabel: 'Leave',
      cancelLabel: 'Keep batting',
      destructive: true,
    );
    if (!mounted) return;
    if (leave) {
      widget.onExit();
    } else {
      _resume();
    }
  }

  void _rematch() {
    final config = _cubit.buildMatch(batsmanIds: widget.config.batsmanIds);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: _cubit,
          child: FinalOverMatchScreen(config: config, onExit: widget.onExit),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: FinalOverGameScope(
        game: _game,
        child: Scaffold(
          backgroundColor: Cyber.bg,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Positioned.fill(child: GameWidget(game: _game)),
                  // The whole pitch is the bat: tap/swipe anywhere to hit. Sits
                  // above the pitch but below the HUD, deck and overlays so
                  // those keep their own taps.
                  Positioned.fill(child: FinalOverSwingSurface(game: _game)),
                  Align(
                    alignment: Alignment.topCenter,
                    child: FinalOverHudBar(game: _game, onExit: _confirmExit),
                  ),
                  FinalOverStingLayer(game: _game),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: _MeasureSize(
                      onChanged: (deckSize) {
                        if (!mounted) return;
                        _game.setBattingControlDeckTop(
                          constraints.maxHeight - deckSize.height,
                        );
                        if ((_controlStackHeight - deckSize.height).abs() >
                            .5) {
                          setState(() => _controlStackHeight = deckSize.height);
                        }
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FinalOverOverdriveRail(game: _game),
                          const SizedBox(height: 6),
                          FinalOverControls(
                            game: _game,
                            showHints: widget.config.showHints,
                            rookieAssist:
                                widget.config.tier == FinalOverTier.rookie,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_paused)
                    Positioned.fill(
                      child: FinalOverPauseOverlay(
                        onResume: _resume,
                        onQuit: widget.onExit,
                      ),
                    ),
                  if (_bowlerRevealOver != null && _bowlerRevealName != null)
                    Positioned.fill(
                      child: FinalOverBowlerRevealOverlay(
                        overNumber: _bowlerRevealOver!,
                        bowlerName: _bowlerRevealName!,
                        onDone: () => setState(() {
                          _bowlerRevealOver = null;
                          _bowlerRevealName = null;
                        }),
                      ),
                    ),
                  _PhaseOverlays(
                    game: _game,
                    onBeginPlay: _beginPlay,
                    onRematch: _rematch,
                    onExit: widget.onExit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChanged, required super.child});

  final ValueChanged<Size> onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChanged);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChanged = onChanged;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChanged);

  ValueChanged<Size> onChanged;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    if (_lastSize == size) return;
    _lastSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(size));
  }
}

/// Intro and result, driven straight off the cubit's phase. Builders see the
/// mount phase, so no initial-listener kick is needed.
class _PhaseOverlays extends StatelessWidget {
  const _PhaseOverlays({
    required this.game,
    required this.onBeginPlay,
    required this.onRematch,
    required this.onExit,
  });

  final FinalOverGame game;
  final VoidCallback onBeginPlay;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FinalOverCubit, FinalOverState>(
      buildWhen: (p, c) => p.phase != c.phase,
      builder: (context, state) {
        switch (state.phase) {
          case FinalOverPhase.intro:
            final config = state.config;
            if (config == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: _FinalOverMatchGate(
                config: config,
                onReady: onBeginPlay,
                onCancel: onExit,
              ),
            );
          case FinalOverPhase.result:
            final summary = state.summary;
            if (summary == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: FinalOverResultOverlay(
                summary: summary,
                stats: state.stats,
                history: game.history.value,
                onRematch: onRematch,
                onExit: onExit,
              ),
            );
          case FinalOverPhase.idle:
          case FinalOverPhase.playing:
          case FinalOverPhase.finished:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _FinalOverMatchGate extends StatefulWidget {
  const _FinalOverMatchGate({
    required this.config,
    required this.onReady,
    required this.onCancel,
  });

  final FinalOverMatchConfig config;
  final VoidCallback onReady;
  final VoidCallback onCancel;

  @override
  State<_FinalOverMatchGate> createState() => _FinalOverMatchGateState();
}

class _FinalOverMatchGateState extends State<_FinalOverMatchGate> {
  final SecureGameStorage _storage = SecureGameStorage();
  String? _selectedAvatarId;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final avatarId = await _storage.loadSelectedAvatarId();
    if (!mounted) return;
    setState(() => _selectedAvatarId = avatarId);
  }

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GameBloc>().state;
    final level = game.progression.levelFor(ProgressTrack.finalOver);
    final playerAvatar = avatarOptionById(_selectedAvatarId);
    final frame = avatarFrameOptionById(game.equippedAvatarFrameId);
    final rival = widget.config.opponentName;

    return GameMatchGate(
      goLabel: 'PLAY!',
      config: GameMatchmakingConfig(
        title: 'FINAL OVER',
        queueLabel: 'SCANNING GLOBAL CRICKET QUEUE',
        player: MatchmakingFighter(
          name: 'PLAYER ONE',
          avatarAsset: playerAvatar.assetPath,
          frame: frame,
          badge: 'LV $level',
        ),
        opponent: MatchmakingFighter(
          name: rival,
          avatarAsset: avatarForName(rival).assetPath,
          badge: 'LV $level',
        ),
      ),
      onReady: widget.onReady,
      onCancel: widget.onCancel,
    );
  }
}
```

### C.2 `lib/screens/final_over/widgets/final_over_result.dart`

<sub>441 lines</sub>

```dart
import 'dart:async';

import 'package:final_over/final_over.dart' show BallResult, ExtraType;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/final_over.dart';
import '../../../models/progression.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/level_up_celebration.dart';

/// The pay-off. Four beats, 750ms apart, tap to skip:
///   1. the verdict,
///   2. the score, the grade plate and the stars,
///   3. the over you actually bowled — ball by ball — and the box score,
///   4. the XP, the record, and the way back in.
///
/// XP was credited before this overlay mounted, so skipping costs nothing.
class FinalOverResultOverlay extends StatefulWidget {
  const FinalOverResultOverlay({
    required this.summary,
    required this.stats,
    required this.history,
    required this.onRematch,
    required this.onExit,
    super.key,
  });

  final FinalOverMatchSummary summary;
  final FinalOverStats stats;
  final List<BallResult> history;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  @override
  State<FinalOverResultOverlay> createState() => _FinalOverResultOverlayState();
}

class _FinalOverResultOverlayState extends State<FinalOverResultOverlay> {
  static const _maxStage = 3;
  int _stage = 0;
  Timer? _timer;
  bool _showLevelUp = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 750), (timer) {
      if (!mounted) return;
      if (_stage >= _maxStage) {
        timer.cancel();
        return;
      }
      setState(() => _stage += 1);
      playSound(SoundEffect.cardSlam);
      if (_stage >= _maxStage) _maybeLevelUp();
    });
  }

  void _skip() {
    if (_stage >= _maxStage) return;
    _timer?.cancel();
    setState(() => _stage = _maxStage);
    _maybeLevelUp();
  }

  void _maybeLevelUp() {
    if (!mounted) return;
    if (context.read<GameBloc>().state.pendingLevelUps.isNotEmpty) {
      setState(() => _showLevelUp = true);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.summary;
    final accent = s.won ? Cyber.success : Cyber.danger;

    return GestureDetector(
      onTap: _skip,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.97),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 26,
                    vertical: 18,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1 — verdict
                        _RevealIn(
                          visible: _stage >= 0,
                          child: Column(
                            children: [
                              Text(
                                s.resultLabel,
                                textAlign: TextAlign.center,
                                style: Cyber.display(
                                  30,
                                  color: accent,
                                  letterSpacing: 3,
                                ).copyWith(
                                  shadows: [
                                    Shadow(
                                      color: accent.withValues(alpha: 0.55),
                                      blurRadius: 22,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _reason(s),
                                textAlign: TextAlign.center,
                                style: Cyber.body(12, color: Cyber.muted),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 2 — score + grade + stars
                        _RevealIn(
                          visible: _stage >= 1,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.scoreLine,
                                      style: Cyber.display(
                                        38,
                                        color: Colors.white,
                                      ).copyWith(
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'CHASING ${s.target}',
                                      style: Cyber.label(
                                        9,
                                        color: Cyber.muted,
                                        letterSpacing: 1.6,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _Stars(stars: s.stars),
                                  ],
                                ),
                              ),
                              _GradePlate(grade: s.grade, accent: accent),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 3 — the over, ball by ball + the box score
                        _RevealIn(
                          visible: _stage >= 2,
                          child: CyberPanel(
                            accent: Cyber.cyan,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SectionLabel(label: 'THE CHASE'),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final b in widget.history)
                                      _HistoryToken(result: b),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                const HudLine(),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    _Stat('SIXES', '${s.sixes}'),
                                    _Stat('FOURS', '${s.fours}'),
                                    _Stat('BEST COMBO', '×${s.bestCombo}'),
                                    _Stat(
                                      'OBJECTIVE',
                                      s.objectiveCompleted ? '✓' : '—',
                                      color: s.objectiveCompleted
                                          ? Cyber.success
                                          : Cyber.muted,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 4 — the money
                        _RevealIn(
                          visible: _stage >= 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _XpLine(xp: s.xp),
                              const SizedBox(height: 8),
                              Text(
                                'BEST ${widget.stats.bestScore}  ·  '
                                '${widget.stats.wins}/${widget.stats.chases} CHASES WON',
                                textAlign: TextAlign.center,
                                style: Cyber.label(
                                  9,
                                  color: Cyber.muted,
                                  letterSpacing: 1.4,
                                ),
                              ),
                              const SizedBox(height: 18),
                              HudCtaButton(
                                label: 'CHASE AGAIN',
                                icon: Icons.replay_rounded,
                                accent: Cyber.gold,
                                onTap: widget.onRematch,
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: widget.onExit,
                                child: Text(
                                  'BACK TO FINAL OVER',
                                  style: Cyber.label(
                                    10,
                                    color: Cyber.muted,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showLevelUp)
              LevelUpCelebration(
                levels: context.read<GameBloc>().state.pendingLevelUps,
                progression: context.read<GameBloc>().state.progression,
                xpEarned: context.read<GameBloc>().state.lastMatchXP ?? 0,
                trackLabel: context
                    .read<GameBloc>()
                    .state
                    .pendingLevelUpTrack
                    ?.displayLabel,
                onDismissed: () => setState(() => _showLevelUp = false),
              ),
          ],
        ),
      ),
    );
  }

  String _reason(FinalOverMatchSummary s) {
    if (s.won) {
      final spare = s.ballsToSpare;
      if (spare == 0) return 'Off the last ball.';
      return 'With $spare ${spare == 1 ? 'ball' : 'balls'} to spare.';
    }
    if (s.wickets > 0) return 'Wickets gone with the chase alive.';
    final short = s.target - s.runs;
    return '$short ${short == 1 ? 'run' : 'runs'} short.';
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.stars});
  final int stars;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < 3; i++)
        Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(
            i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
            size: 20,
            color: i < stars ? Cyber.gold : Cyber.border,
          ),
        ),
    ],
  );
}

class _GradePlate extends StatelessWidget {
  const _GradePlate({required this.grade, required this.accent});
  final String grade;
  final Color accent;

  @override
  Widget build(BuildContext context) => ClipPath(
    clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
    child: Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        border: Border.all(color: accent.withValues(alpha: 0.7), width: 1.4),
      ),
      child: Text(
        grade,
        style: Cyber.display(34, color: accent, letterSpacing: 1),
      ),
    ),
  );
}

/// One ball of the over. Extras are amber and off to the side, because they
/// didn't count against you.
class _HistoryToken extends StatelessWidget {
  const _HistoryToken({required this.result});
  final BallResult result;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (result) {
      final b when !b.legal =>
        (b.extra == ExtraType.noBall ? 'NB' : 'WD', Cyber.amber),
      final b when b.isWicket => ('W', Cyber.danger),
      final b when b.boundary == 6 => ('6', Cyber.gold),
      final b when b.boundary == 4 => ('4', Cyber.cyan),
      final b when b.totalRuns == 0 => ('•', Cyber.muted),
      final b => ('${b.totalRuns}', Cyber.success),
    };
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: Cyber.display(13, color: color),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Cyber.display(
            16,
            color: color ?? Colors.white,
          ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 1),
        ),
      ],
    ),
  );
}

/// Cosmetic count-up. The XP is already in the ledger.
class _XpLine extends StatelessWidget {
  const _XpLine({required this.xp});
  final int xp;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 900),
    curve: Curves.easeOutCubic,
    builder: (context, t, _) => Text(
      '+${(xp * t).round()} XP',
      textAlign: TextAlign.center,
      style: Cyber.display(26, color: Cyber.violet, letterSpacing: 2).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        shadows: [
          Shadow(color: Cyber.violet.withValues(alpha: 0.5), blurRadius: 18),
        ],
      ),
    ),
  );
}

class _RevealIn extends StatelessWidget {
  const _RevealIn({required this.visible, required this.child});
  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: visible ? Offset.zero : const Offset(0, 0.18),
    duration: const Duration(milliseconds: 340),
    curve: Curves.easeOutCubic,
    child: AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 340),
      child: child,
    ),
  );
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

### D.2 `lib/services/secure_storage_service.dart`

<sub>31 lines</sub>

```dart
// STAND-IN for the host app's lib/services/secure_storage_service.dart.
// The real class also holds secure-storage data for other modes; the game
// records below live in plain SharedPreferences (verbatim methods + keys).
// Add `shared_preferences` to pubspec.yaml.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/final_over.dart';

class SecureGameStorage {
  static const _finalOverStatsKey = 'pd_final_over_stats_v1';

  Future<FinalOverStats> loadFinalOverStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_finalOverStatsKey);
      if (raw == null || raw.isEmpty) return const FinalOverStats();
      return FinalOverStats.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const FinalOverStats();
    }
  }

  Future<void> saveFinalOverStats(FinalOverStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_finalOverStatsKey, jsonEncode(stats.toJson()));
  }
}
```

### D.3 `lib/utils/sound_effects.dart`

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

### D.4 `lib/widgets/cyber/cyber_widgets.dart`

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

### D.5 `lib/widgets/cyber/cyber_cta_button.dart`

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

### E.1 `test/final_over_balance_test.dart`

<sub>67 lines</sub>

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:card_game/models/final_over.dart';

void main() {
  group('Final Over difficulty balance', () {
    test('new and invalid profiles default to Rookie', () {
      expect(const FinalOverStats().tier, FinalOverTier.rookie);
      expect(FinalOverStats.fromJson(const {}).tier, FinalOverTier.rookie);
      expect(
        FinalOverStats.fromJson(const {'tier': 'future'}).tier,
        FinalOverTier.rookie,
      );
    });

    test('target pools keep the full ladder with easier progression', () {
      expect(FinalOverTier.rookie.targets, [32, 36, 40]);
      expect(FinalOverTier.pro.targets, [44, 48, 52, 56]);
      expect(FinalOverTier.elite.targets, [58, 62, 66]);
    });

    test('Rookie applies the forgiving gameplay profile', () {
      final tuning = FinalOverTier.rookie.tuning;
      expect(tuning.perfectWindowMs, 80);
      expect(tuning.goodWindowMs, 180);
      expect(tuning.earlyLateWindowMs, 300);
      expect(tuning.poorWindowMs, 400);
      expect(tuning.maximumWickets, 4);
      expect(tuning.baseCatchChance, 0.58);
      expect(tuning.keeperCatchChance, 0.68);
      expect(tuning.fielderSpeed, 0.24);
      expect(tuning.throwSpeed, 0.56);
      expect(tuning.batterReach, 0.100);
      expect(tuning.powerShotSegments, 4);
      expect(tuning.backliftPowerFloor, 0.75);
      expect(tuning.overswingFrom, 0.98);
      expect(tuning.overswingControlPenalty, 0.10);
      expect(tuning.overswingEdgeBonus, 0.04);
      expect(tuning.groundPowerSpeed, closeTo(0.704, 0.0001));
      expect(tuning.loftPowerSpeed, closeTo(0.649, 0.0001));
    });

    test(
      'Pro and Elite keep their challenge while preserving a running window',
      () {
        final pro = FinalOverTier.pro.tuning;
        expect(pro.perfectWindowMs, 65);
        expect(pro.goodWindowMs, 150);
        expect(pro.poorWindowMs, 330);
        expect(pro.maximumWickets, 3);
        expect(pro.baseCatchChance, 0.68);
        expect(pro.fielderSpeed, 0.27);
        expect(pro.powerShotSegments, 5);

        final elite = FinalOverTier.elite.tuning;
        expect(elite.perfectWindowMs, 50);
        expect(elite.goodWindowMs, 115);
        expect(elite.poorWindowMs, 275);
        expect(elite.baseCatchChance, 0.82);
        expect(elite.keeperCatchChance, 0.88);
        expect(elite.fielderSpeed, 0.29);
        expect(elite.throwSpeed, 0.62);
        expect(elite.powerShotSegments, 8);
      },
    );
  });
}
```

### E.2 `final_over/test/domain/delivery_generator_test.dart`

<sub>162 lines</sub>

```dart
import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

BallResult resultFor(ExtraType extra) => BallResult(
  deliveryOrdinal: 1,
  legalBallsBefore: 0,
  legal: extra == ExtraType.none,
  extra: extra,
  extraRuns: extra == ExtraType.none ? 0 : 1,
  runsOffBat: 0,
  completedRunningRuns: 0,
  boundary: 0,
  dismissal: DismissalType.none,
  contactType: ContactType.none,
  timing: TimingGrade.miss,
  freeHitDelivery: false,
  historyToken: '0',
);

void main() {
  const generator = DeliveryGenerator();

  test('same match seed and physical ordinal repeat exactly', () {
    DeliverySpec make() => generator.generate(
      matchSeed: 99,
      physicalOrdinal: 3,
      legalBalls: 1,
      score: 2,
      target: 48,
      history: const [],
      previousDeliveries: const [],
    );

    final first = make();
    final second = make();
    expect(second.seed, first.seed);
    expect(second.line, first.line);
    expect(second.length, first.length);
    expect(second.speed, first.speed);
    expect(second.movement, first.movement);
    expect(second.extra, first.extra);
  });

  test('first physical ball is legal, reachable, and slowed', () {
    for (var seed = 0; seed < 200; seed++) {
      final ball = generator.generate(
        matchSeed: seed,
        physicalOrdinal: 1,
        legalBalls: 0,
        score: 0,
        target: 48,
        history: const [],
        previousDeliveries: const [],
      );
      expect(ball.extra, ExtraType.none);
      expect(
        ball.line,
        isNot(anyOf(DeliveryLine.wideOff, DeliveryLine.wideLeg)),
      );
      expect(ball.speed, lessThanOrEqualTo(1.08 * 0.95));
    }
  });

  test('extra caps are enforced', () {
    final history = [
      resultFor(ExtraType.noBall),
      resultFor(ExtraType.noBall),
      resultFor(ExtraType.noBall),
      resultFor(ExtraType.wide),
      resultFor(ExtraType.wide),
      resultFor(ExtraType.wide),
      resultFor(ExtraType.wide),
      resultFor(ExtraType.wide),
    ];
    for (var seed = 0; seed < 2000; seed++) {
      final ball = generator.generate(
        matchSeed: seed,
        physicalOrdinal: 12,
        legalBalls: 4,
        score: 8,
        target: 48,
        history: history,
        previousDeliveries: const [],
      );
      expect(ball.extra, ExtraType.none);
    }
  });

  test('a third consecutive yorker or short ball is prevented', () {
    DeliverySpec previous(DeliveryLength length, int ordinal) => DeliverySpec(
      ordinal: ordinal,
      seed: ordinal,
      line: DeliveryLine.middle,
      length: length,
      speed: 0.9,
      movement: 0,
      extra: ExtraType.none,
      lineX: 0,
      expectedContactMicros: 0,
    );

    for (final length in [DeliveryLength.yorker, DeliveryLength.short]) {
      final prior = [previous(length, 1), previous(length, 2)];
      for (var seed = 0; seed < 500; seed++) {
        final ball = generator.generate(
          matchSeed: seed,
          physicalOrdinal: 3,
          legalBalls: 2,
          score: 0,
          target: 48,
          history: const [],
          previousDeliveries: prior,
        );
        expect(ball.length, isNot(length));
      }
    }
  });

  test('final legal delivery is fair when six or fewer are needed', () {
    for (var seed = 0; seed < 500; seed++) {
      final ball = generator.generate(
        matchSeed: seed,
        physicalOrdinal: 20,
        legalBalls: 17,
        score: 44,
        target: 48,
        history: const [],
        previousDeliveries: const [],
      );
      expect(ball.isFairFinalBall, isTrue);
      expect(ball.extra, ExtraType.none);
      expect(ball.length, anyOf(DeliveryLength.full, DeliveryLength.good));
      expect(
        ball.line,
        anyOf(DeliveryLine.off, DeliveryLine.middle, DeliveryLine.leg),
      );
      expect(ball.movement.abs(), lessThanOrEqualTo(0.006));
      expect(ball.speed, lessThanOrEqualTo(0.92));
    }
  });

  test('uncapped generation stays near intended extra rates', () {
    var wides = 0;
    var noBalls = 0;
    const count = 10000;
    for (var seed = 0; seed < count; seed++) {
      final ball = generator.generate(
        matchSeed: seed,
        physicalOrdinal: 2,
        legalBalls: 1,
        score: 0,
        target: 48,
        history: const [],
        previousDeliveries: const [],
      );
      if (ball.extra == ExtraType.wide) wides++;
      if (ball.extra == ExtraType.noBall) noBalls++;
    }
    expect(wides / count, inInclusiveRange(0.035, 0.065));
    expect(noBalls / count, inInclusiveRange(0.012, 0.030));
  });
}
```

### E.3 `final_over/test/domain/deterministic_random_test.dart`

<sub>65 lines</sub>

```dart
import 'package:final_over/domain/deterministic_random.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeterministicRandom', () {
    test('seed zero matches the fixed SplitMix64 golden sequence', () {
      final random = DeterministicRandom(0);
      expect(List.generate(5, (_) => random.nextUint64()), const [
        -0x1ddf57c684e23251,
        0x6e789e6aa1b965f4,
        0x06c45d188009454f,
        -0x077447578db37e14,
        0x1b39896a51a8749b,
      ]);
    });

    test('same seed has the same sequence', () {
      final first = DeterministicRandom(42);
      final second = DeterministicRandom(42);

      final a = List.generate(32, (_) => first.nextUint64());
      final b = List.generate(32, (_) => second.nextUint64());

      expect(a, b);
      expect(a.toSet(), hasLength(32));
    });

    test('different named streams do not overlap', () {
      final values = {
        for (final stream in RandomStream.values)
          SeedStreams.seedFor(987654321, 4, stream),
      };
      expect(values, hasLength(RandomStream.values.length));
    });

    test('physical delivery ordinal changes every derived stream', () {
      for (final stream in RandomStream.values) {
        expect(
          SeedStreams.seedFor(77, 1, stream),
          isNot(SeedStreams.seedFor(77, 2, stream)),
        );
      }
    });

    test('bounded methods respect their ranges', () {
      final random = DeterministicRandom(11);
      for (var i = 0; i < 1000; i++) {
        expect(random.nextInt(7), inInclusiveRange(0, 6));
        expect(random.range(-0.2, 0.3), inInclusiveRange(-0.2, 0.3));
      }
    });

    test('derived delivery stream remains statistically uniform', () {
      var firstBelowTwo = 0;
      var secondBelowFive = 0;
      for (var seed = 0; seed < 10000; seed++) {
        final random = SeedStreams.forStream(seed, 2, RandomStream.delivery);
        if (random.nextDouble() < 0.02) firstBelowTwo++;
        if (random.nextDouble() < 0.05) secondBelowFive++;
      }
      expect(firstBelowTwo / 10000, inInclusiveRange(0.015, 0.025));
      expect(secondBelowFive / 10000, inInclusiveRange(0.04, 0.06));
    });
  });
}
```

### E.4 `final_over/test/domain/field_layout_test.dart`

<sub>58 lines</sub>

```dart
import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('field layouts are complete, unique, and inside the rope', () {
    expect(GameplayTuning.fieldLayouts, hasLength(5));

    for (final layout in GameplayTuning.fieldLayouts) {
      expect(layout.id, isNotEmpty);
      expect(layout.label, isNotEmpty);
      expect(layout.fielders, hasLength(10));
      expect(
        layout.fielders.map((fielder) => fielder.id).toSet(),
        hasLength(10),
      );
      expect(
        layout.fielders.where(
          (fielder) => fielder.role == FielderRole.outfielder,
        ),
        hasLength(8),
      );
      expect(
        layout.fielders.where(
          (fielder) => fielder.role == FielderRole.wicketkeeper,
        ),
        hasLength(1),
      );
      expect(
        layout.fielders.where((fielder) => fielder.role == FielderRole.bowler),
        hasLength(1),
      );
      for (final fielder in layout.fielders) {
        expect(fielder.position.length, lessThan(1));
        expect(fielder.homePosition, fielder.position);
      }
    }
  });

  test('seeded layout rotation changes on every physical delivery', () {
    for (final seed in [-7, 0, 19]) {
      final sequence = [
        for (var ordinal = 1; ordinal <= 12; ordinal++)
          GameplayTuning.fieldLayoutFor(
            matchSeed: seed,
            physicalOrdinal: ordinal,
          ).id,
      ];

      for (var index = 1; index < sequence.length; index++) {
        expect(sequence[index], isNot(sequence[index - 1]));
      }
      expect(
        GameplayTuning.fieldLayoutFor(matchSeed: seed, physicalOrdinal: 1).id,
        sequence.first,
      );
    }
  });
}
```

### E.5 `final_over/test/domain/models_test.dart`

<sub>61 lines</sub>

```dart
import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FieldVector math is deterministic and immutable', () {
    const first = FieldVector(3, 4);
    const second = FieldVector(1, -2);
    expect(first.length, 5);
    expect(first + second, const FieldVector(4, 2));
    expect(first - second, const FieldVector(2, 6));
    expect(first.normalized.length, closeTo(1, 0.0000001));
    expect(FieldVector.lerp(first, second, 0.5), const FieldVector(2, 1));
  });

  test('MatchState exposes provisional score without committing it twice', () {
    final state = MatchState.initial().copyWith(
      committedScore: 5,
      pendingExtras: 1,
      pendingRuns: 2,
      pendingBatRuns: 4,
    );
    expect(state.score, 12);
    expect(state.committedScore, 5);
  });

  test('nullable copyWith fields can be deliberately cleared', () {
    final paused = MatchState.initial().copyWith(
      phase: MatchPhase.paused,
      suspendedPhase: MatchPhase.fieldPlay,
    );
    final resumed = paused.copyWith(
      phase: MatchPhase.fieldPlay,
      suspendedPhase: null,
    );
    expect(resumed.suspendedPhase, isNull);
  });

  test('history and fielder collections cannot be mutated', () {
    final history = <BallResult>[];
    final state = MatchState.initial().copyWith(history: history);
    history.clear();
    expect(state.history, isEmpty);
    expect(() => state.history.add(_dot), throwsUnsupportedError);
  });
}

const _dot = BallResult(
  deliveryOrdinal: 1,
  legalBallsBefore: 0,
  legal: true,
  extra: ExtraType.none,
  extraRuns: 0,
  runsOffBat: 0,
  completedRunningRuns: 0,
  boundary: 0,
  dismissal: DismissalType.none,
  contactType: ContactType.miss,
  timing: TimingGrade.miss,
  freeHitDelivery: false,
  historyToken: '0',
);
```

### E.6 `final_over/test/domain/resolvers_test.dart`

<sub>298 lines</sub>

```dart
import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

DeliverySpec delivery({
  DeliveryLine line = DeliveryLine.middle,
  DeliveryLength length = DeliveryLength.good,
  ExtraType extra = ExtraType.none,
  double movement = 0,
}) => DeliverySpec(
  ordinal: 1,
  seed: 1,
  line: line,
  length: length,
  speed: 0.9,
  movement: movement,
  extra: extra,
  lineX: GameplayTuning.lineX[line]!,
  expectedContactMicros: 1000000,
);

BallResult result({
  bool legal = true,
  ExtraType extra = ExtraType.none,
  int extraRuns = 0,
  int batRuns = 0,
  int runningRuns = 0,
  int boundary = 0,
  DismissalType dismissal = DismissalType.none,
  ContactType contact = ContactType.clean,
  int legalBallsBefore = 0,
}) => BallResult(
  deliveryOrdinal: 1,
  legalBallsBefore: legalBallsBefore,
  legal: legal,
  extra: extra,
  extraRuns: extraRuns,
  runsOffBat: batRuns,
  completedRunningRuns: runningRuns,
  boundary: boundary,
  dismissal: dismissal,
  contactType: contact,
  timing: TimingGrade.good,
  freeHitDelivery: false,
  historyToken: 'test',
);

void main() {
  group('timing', () {
    test('continuous boundaries are inclusive', () {
      expect(TimingResolver.resolve(-50), TimingGrade.perfect);
      expect(TimingResolver.resolve(50), TimingGrade.perfect);
      expect(TimingResolver.resolve(-51), TimingGrade.good);
      expect(TimingResolver.resolve(115), TimingGrade.good);
      expect(TimingResolver.resolve(-116), TimingGrade.early);
      expect(TimingResolver.resolve(190), TimingGrade.late);
      expect(TimingResolver.resolve(-191), TimingGrade.poor);
      expect(TimingResolver.resolve(275), TimingGrade.poor);
      expect(TimingResolver.resolve(276), TimingGrade.miss);
      expect(TimingResolver.resolve(0, hasInput: false), TimingGrade.miss);
    });
  });

  group('contact', () {
    const resolver = ContactResolver();

    test(
      'compatibility rewards matching line and applies mismatch penalty',
      () {
        final ball = delivery(
          line: DeliveryLine.off,
          length: DeliveryLength.good,
        );
        final matching = resolver.compatibility(
          ball,
          ShotDirection.offSide,
          Elevation.ground,
        );
        final mismatch = resolver.compatibility(
          ball,
          ShotDirection.legSide,
          Elevation.ground,
        );
        expect(matching - mismatch, closeTo(0.26, 0.000001));
      },
    );

    test('unreachable ball misses even with perfect input', () {
      final outcome = resolver.resolve(
        delivery: delivery(line: DeliveryLine.wideOff),
        elevation: Elevation.loft,
        direction: ShotDirection.offSide,
        timingErrorMs: 0,
        hasInput: true,
        powerShot: false,
        random: DeterministicRandom(4),
      );
      expect(outcome.type, ContactType.miss);
      expect(outcome.acceptedSwing, isTrue);
    });

    test('power shot changes output but never cricket runs directly', () {
      final normal = resolver.resolve(
        delivery: delivery(),
        elevation: Elevation.loft,
        direction: ShotDirection.straight,
        timingErrorMs: 0,
        hasInput: true,
        powerShot: false,
        random: DeterministicRandom(10),
      );
      final powered = resolver.resolve(
        delivery: delivery(),
        elevation: Elevation.loft,
        direction: ShotDirection.straight,
        timingErrorMs: 0,
        hasInput: true,
        powerShot: true,
        random: DeterministicRandom(10),
      );
      expect(powered.power, greaterThan(normal.power));
      expect(powered.control, greaterThanOrEqualTo(normal.control));
      expect(powered.powerShotUsed, isTrue);
    });

    test('no input identifies a bowled threat in the stump channel', () {
      final outcome = resolver.resolve(
        delivery: delivery(length: DeliveryLength.full),
        elevation: Elevation.ground,
        direction: ShotDirection.straight,
        timingErrorMs: 276,
        hasInput: false,
        powerShot: false,
        random: DeterministicRandom(1),
      );
      expect(outcome.type, ContactType.miss);
      expect(outcome.bowledThreat, isTrue);
    });

    test('a behind shot travels toward the wicketkeeper end', () {
      final outcome = resolver.resolve(
        delivery: delivery(line: DeliveryLine.leg),
        elevation: Elevation.ground,
        direction: ShotDirection.behind,
        timingErrorMs: 0,
        hasInput: true,
        powerShot: false,
        random: DeterministicRandom(12),
      );

      expect(outcome.madeContact, isTrue);
      expect(outcome.direction, ShotDirection.behind);
      expect(outcome.velocity.y, greaterThan(0));
      expect(outcome.velocity.x.abs(), lessThan(outcome.velocity.y));
    });
  });

  group('physics and exact ties', () {
    const physics = PhysicsResolver();
    const fielding = FieldingResolver();

    test('ground shots and bounced lofts cannot become a six', () {
      const crossing = BallKinematics(
        position: FieldVector(1, 0),
        velocity: FieldVector(1, 0),
        height: 0.2,
        verticalVelocity: 0.1,
        aerial: true,
      );
      expect(physics.boundaryValue(crossing, Elevation.ground), 4);
      expect(physics.boundaryValue(crossing, Elevation.loft), 6);
      expect(
        physics.boundaryValue(
          crossing.copyWith(firstBounceOccurred: true),
          Elevation.loft,
        ),
        4,
      );
    });

    test('catch must be strictly before bounce', () {
      expect(physics.catchPrecedesBounce(0.9, 1.0), isTrue);
      expect(physics.catchPrecedesBounce(1.0, 1.0), isFalse);
    });

    test('pickup must be strictly before boundary', () {
      expect(physics.pickupPrecedesBoundary(0.9, 1.0), isTrue);
      expect(physics.pickupPrecedesBoundary(1.0, 1.0), isFalse);
    });

    test('crease tie is safe', () {
      expect(
        fielding.isRunOut(stumpBreakMicros: 999, creaseMicros: 1000),
        isTrue,
      );
      expect(
        fielding.isRunOut(stumpBreakMicros: 1000, creaseMicros: 1000),
        isFalse,
      );
    });

    test('risk labels use the documented margins', () {
      expect(fielding.riskForMargin(0.221), RiskLevel.safe);
      expect(fielding.riskForMargin(0.22), RiskLevel.close);
      expect(fielding.riskForMargin(-0.15), RiskLevel.close);
      expect(fielding.riskForMargin(-0.151), RiskLevel.danger);
    });
  });

  group('scoring', () {
    test('first-three objective includes intervening illegal runs', () {
      var update = ScoringResolver.updateObjective(
        ObjectiveType.sixRunsFirstThreeLegalBalls,
        0,
        result(
          legal: false,
          extra: ExtraType.noBall,
          extraRuns: 1,
          batRuns: 4,
          boundary: 4,
          legalBallsBefore: 2,
        ),
      );
      expect(update.progress, 5);
      expect(update.completed, isFalse);
      update = ScoringResolver.updateObjective(
        ObjectiveType.sixRunsFirstThreeLegalBalls,
        update.progress,
        result(runningRuns: 1, legalBallsBefore: 2),
      );
      expect(update.completed, isTrue);
    });

    test('double completes only after second running run', () {
      expect(
        ScoringResolver.updateObjective(
          ObjectiveType.completeDouble,
          0,
          result(runningRuns: 1),
        ).completed,
        isFalse,
      );
      expect(
        ScoringResolver.updateObjective(
          ObjectiveType.completeDouble,
          0,
          result(runningRuns: 2),
        ).completed,
        isTrue,
      );
    });

    test('no-contact extra leaves combo and power unchanged', () {
      final wide = result(
        legal: false,
        extra: ExtraType.wide,
        extraRuns: 1,
        contact: ContactType.none,
      );
      expect(ScoringResolver.nextCombo(2, wide), 2);
      expect(ScoringResolver.chargeFor(wide, 2), 0);
    });

    test('productive contacted no-ball advances combo', () {
      final noBallFour = result(
        legal: false,
        extra: ExtraType.noBall,
        extraRuns: 1,
        batRuns: 4,
        boundary: 4,
      );
      expect(ScoringResolver.nextCombo(1, noBallFour), 2);
      expect(ScoringResolver.chargeFor(noBallFour, 2), 3);
    });

    test('history tokens combine extras, runs, and wickets', () {
      expect(
        ScoringResolver.historyToken(
          extra: ExtraType.noBall,
          totalRuns: 5,
          batAndRunningRuns: 4,
          boundary: 4,
          dismissal: DismissalType.none,
        ),
        'NB+4',
      );
      expect(
        ScoringResolver.historyToken(
          extra: ExtraType.none,
          totalRuns: 1,
          batAndRunningRuns: 1,
          boundary: 0,
          dismissal: DismissalType.runOut,
        ),
        '1+RUN OUT',
      );
    });
  });
}
```

### E.7 `final_over/test/application/test_support.dart`

<sub>72 lines</sub>

```dart
import 'package:final_over/application/match_controller.dart';
import 'package:final_over/domain/domain.dart';

final class ScriptedDeliveryGenerator extends DeliveryGenerator {
  ScriptedDeliveryGenerator(this.script);

  final List<DeliverySpec> script;
  int _index = 0;

  @override
  DeliverySpec generate({
    required int matchSeed,
    required int physicalOrdinal,
    required int legalBalls,
    required int score,
    required int target,
    required List<BallResult> history,
    required List<DeliverySpec> previousDeliveries,
    int expectedContactMicros = 0,
    BowlerProfile? bowler,
  }) {
    final source = script[_index.clamp(0, script.length - 1)];
    _index++;
    return DeliverySpec(
      ordinal: physicalOrdinal,
      seed: SeedStreams.seedFor(
        matchSeed,
        physicalOrdinal,
        RandomStream.delivery,
      ),
      line: source.line,
      length: source.length,
      speed: source.speed,
      movement: source.movement,
      extra: source.extra,
      lineX: GameplayTuning.lineX[source.line]!,
      expectedContactMicros: expectedContactMicros,
      isFairFinalBall: source.isFairFinalBall,
    );
  }
}

DeliverySpec scripted({
  DeliveryLine line = DeliveryLine.middle,
  DeliveryLength length = DeliveryLength.full,
  ExtraType extra = ExtraType.none,
  double speed = 0.9,
  double movement = 0,
}) => DeliverySpec(
  ordinal: 0,
  seed: 0,
  line: line,
  length: length,
  speed: speed,
  movement: movement,
  extra: extra,
  lineX: GameplayTuning.lineX[line]!,
  expectedContactMicros: 0,
);

void advanceUntil(
  MatchController controller,
  bool Function() predicate, {
  int maximumTicks = 20000,
}) {
  for (var tick = 0; tick < maximumTicks && !predicate(); tick++) {
    controller.step(const Duration(microseconds: 16667));
  }
  if (!predicate()) {
    throw StateError('Condition was not reached within $maximumTicks ticks');
  }
}
```

### E.8 `final_over/test/application/match_controller_test.dart`

<sub>516 lines</sub>

```dart
import 'package:final_over/application/application.dart';
import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('match setup and authority', () {
    test(
      'three-second preparation reveals delivery and locks shot choices',
      () {
        final controller = MatchController();
        controller.startMatch(seed: 41, target: 40);
        controller.dispatch(const GameCommand.start());

        final preparedAt = controller.state.simulationMicros;
        final delivery = controller.state.currentDelivery!;
        expect(controller.state.phase, MatchPhase.deliveryPreparation);
        expect(controller.state.canConfigureShot, isTrue);
        expect(controller.state.selectedElevation, Elevation.ground);
        expect(controller.state.selectedDirection, ShotDirection.straight);
        expect(
          delivery.expectedContactMicros - preparedAt,
          3000000 + 900000 + 650000,
        );

        controller.dispatch(const GameCommand.selectElevation(Elevation.loft));
        controller.dispatch(
          const GameCommand.selectDirection(ShotDirection.legSide),
        );
        expect(controller.state.selectedElevation, Elevation.loft);
        expect(controller.state.selectedDirection, ShotDirection.legSide);

        for (var tick = 0; tick < 179; tick++) {
          controller.step(const Duration(microseconds: 16667));
        }
        expect(controller.state.phase, MatchPhase.deliveryPreparation);
        controller.step(const Duration(microseconds: 16667));
        expect(controller.state.phase, MatchPhase.bowlerRunUp);
        expect(controller.state.canConfigureShot, isFalse);

        controller.dispatch(
          const GameCommand.selectElevation(Elevation.ground),
        );
        controller.dispatch(
          const GameCommand.selectDirection(ShotDirection.offSide),
        );
        expect(controller.state.selectedElevation, Elevation.loft);
        expect(controller.state.selectedDirection, ShotDirection.legSide);
      },
    );

    test('pause freezes preparation and swing only opens at ball release', () {
      final controller = MatchController();
      controller.startMatch(seed: 42, target: 40);
      controller.dispatch(const GameCommand.start());
      for (var tick = 0; tick < 60; tick++) {
        controller.step(const Duration(microseconds: 16667));
      }
      final beforePause = controller.state.simulationMicros;
      controller.dispatch(const GameCommand.pause());
      for (var tick = 0; tick < 60; tick++) {
        controller.step(const Duration(microseconds: 16667));
      }
      expect(controller.state.simulationMicros, beforePause);

      controller.dispatch(const GameCommand.resume());
      controller.dispatch(
        const GameCommand.swing(ShotDirection.straight, charge: 0.8),
      );
      expect(controller.state.swingIntent, isNull);
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );
      expect(controller.state.canSwing, isTrue);
      controller.dispatch(
        const GameCommand.swing(ShotDirection.straight, charge: 0.8),
      );
      expect(controller.state.swingIntent, isNotNull);
      expect(controller.state.swingIntent!.charge, closeTo(0.8, 0.0001));
      expect(controller.state.canSwing, isFalse);
    });

    test('release-to-contact hold duration reaches ideal charge', () {
      const tuning = GameplayTuning();
      final heldSeconds =
          tuning.incomingToContactMicros / Duration.microsecondsPerSecond;
      expect(heldSeconds / tuning.chargeSeconds, closeTo(0.8, 0.0001));
    });

    test(
      'seeded start selects only approved targets and an eligible objective',
      () {
        final controller = MatchController();
        for (var seed = 0; seed < 100; seed++) {
          controller.startMatch(seed: seed);
          expect(
            GameplayTuning.targetOptions,
            contains(controller.state.target),
          );
          expect(controller.state.phase, MatchPhase.matchIntro);
          if (controller.state.objective == ObjectiveType.twoBoundaries) {
            expect(
              controller.state.target,
              greaterThanOrEqualTo(GameplayTuning.targetMinimum),
            );
          }
        }
      },
    );

    test('same seed and commands produce identical delivery state', () {
      final first = MatchController();
      final second = MatchController();
      first.startMatch(seed: 124, target: 48);
      second.startMatch(seed: 124, target: 48);
      first.dispatch(const GameCommand.start());
      second.dispatch(const GameCommand.start());

      for (var i = 0; i < 130; i++) {
        first.step(const Duration(microseconds: 16667));
        second.step(const Duration(microseconds: 16667));
      }

      expect(second.state.phase, first.state.phase);
      expect(second.state.simulationMicros, first.state.simulationMicros);
      expect(
        second.state.currentDelivery?.seed,
        first.state.currentDelivery?.seed,
      );
      expect(
        second.state.currentDelivery?.line,
        first.state.currentDelivery?.line,
      );
      expect(
        second.state.currentDelivery?.length,
        first.state.currentDelivery?.length,
      );
      expect(second.state.history.length, first.state.history.length);
    });

    test('duplicate swing is ignored', () {
      final generator = ScriptedDeliveryGenerator([scripted()]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 4, target: 48);
      controller.dispatch(const GameCommand.start());
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );

      controller.dispatch(const GameCommand.swing(ShotDirection.offSide));
      controller.dispatch(const GameCommand.swing(ShotDirection.legSide));

      expect(controller.state.swingIntent?.direction, ShotDirection.offSide);
    });

    test('state and gameplay streams expose authoritative updates', () {
      final controller = MatchController();
      final states = <MatchState>[];
      final events = <GameplayEvent>[];
      controller.stateStream.listen(states.add);
      controller.eventStream.listen(events.add);

      controller.startMatch(seed: 9, target: 48);
      controller.dispatch(const GameCommand.start());

      expect(states, isNotEmpty);
      expect(events.first.type, GameplayEventType.matchStarted);
      expect(
        events.any((event) => event.type == GameplayEventType.deliveryPrepared),
        isTrue,
      );
    });
  });

  group('pause and lifecycle', () {
    test('pause and background freeze simulation and restore exact phase', () {
      final controller = MatchController();
      controller.startMatch(seed: 3, target: 48);
      controller.dispatch(const GameCommand.start());
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );
      final phase = controller.state.phase;
      final elapsed = controller.state.phaseElapsedMicros;
      final simulation = controller.state.simulationMicros;

      controller.dispatch(const GameCommand.appBackgrounded());
      expect(controller.state.phase, MatchPhase.paused);
      expect(controller.state.suspendedPhase, phase);
      controller.step(const Duration(seconds: 5));
      expect(controller.state.simulationMicros, simulation);
      expect(controller.state.phaseElapsedMicros, elapsed);

      controller.dispatch(const GameCommand.resume());
      expect(controller.state.phase, phase);
      expect(controller.state.suspendedPhase, isNull);
      controller.step(const Duration(microseconds: 16667));
      expect(controller.state.simulationMicros, simulation + 16667);
    });
  });

  group('extras and Free Hit', () {
    test(
      'no-ball establishes Free Hit, wide preserves it, legal ball consumes it',
      () {
        final generator = ScriptedDeliveryGenerator([
          scripted(extra: ExtraType.noBall),
          scripted(line: DeliveryLine.wideOff, extra: ExtraType.wide),
          scripted(),
        ]);
        final controller = MatchController(deliveryGenerator: generator);
        controller.startMatch(seed: 1, target: 48);
        controller.dispatch(const GameCommand.start());

        advanceUntil(controller, () => controller.state.history.length == 1);
        expect(controller.state.freeHit, isTrue);
        expect(controller.state.legalBalls, 0);
        expect(controller.state.score, 1);

        advanceUntil(controller, () => controller.state.history.length == 2);
        expect(controller.state.freeHit, isTrue);
        expect(controller.state.legalBalls, 0);
        expect(controller.state.score, 2);

        advanceUntil(controller, () => controller.state.history.length == 3);
        expect(controller.state.freeHit, isFalse);
        expect(controller.state.legalBalls, 1);
        expect(controller.state.wickets, 0);
        expect(controller.state.history.last.freeHitDelivery, isTrue);
      },
    );

    test('target-winning no-ball extra finalizes before contact', () {
      final generator = ScriptedDeliveryGenerator([
        for (var i = 0; i < 31; i++)
          scripted(line: DeliveryLine.wideOff, extra: ExtraType.wide),
        scripted(extra: ExtraType.noBall),
      ]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 2, target: 32);
      controller.dispatch(const GameCommand.start());

      advanceUntil(controller, () => controller.state.isTerminal);

      expect(controller.state.phase, MatchPhase.won);
      expect(controller.state.score, 32);
      expect(controller.state.legalBalls, 0);
      expect(controller.state.physicalDeliveries, 32);
      expect(controller.state.history, hasLength(32));
      expect(controller.state.history.last.extra, ExtraType.noBall);
      expect(controller.state.history.last.contactType, ContactType.none);
      expect(controller.state.contactOutcome, isNull);
    });
  });

  group('terminal ordering and exact-once ledger', () {
    test('eighteen legal dots are recorded before balls-exhausted loss', () {
      final generator = ScriptedDeliveryGenerator([
        for (var i = 0; i < 18; i++)
          scripted(line: DeliveryLine.wideOff, length: DeliveryLength.short),
      ]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 5, target: 48);
      controller.dispatch(const GameCommand.start());

      advanceUntil(controller, () => controller.state.isTerminal);

      expect(controller.state.phase, MatchPhase.lost);
      expect(controller.state.endReason, MatchEndReason.ballsExhausted);
      expect(controller.state.legalBalls, 18);
      expect(controller.state.history, hasLength(18));
      expect(controller.state.history.last.legalBallsBefore, 17);
    });

    test('two valid bowled wickets end the match', () {
      final generator = ScriptedDeliveryGenerator([scripted(), scripted()]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 7, target: 48);
      controller.dispatch(const GameCommand.start());

      advanceUntil(controller, () => controller.state.isTerminal);

      expect(controller.state.phase, MatchPhase.lost);
      expect(controller.state.endReason, MatchEndReason.wicketsLost);
      expect(controller.state.wickets, 2);
      expect(controller.state.legalBalls, 2);
      expect(
        controller.state.history.map((result) => result.dismissal),
        everyElement(DismissalType.bowled),
      );

      controller.step(const Duration(seconds: 10));
      expect(controller.state.history, hasLength(2));
      expect(controller.state.wickets, 2);
    });

    test('completing an over rotates the bowler and emits overComplete', () {
      final generator = ScriptedDeliveryGenerator([
        for (var i = 0; i < 6; i++)
          scripted(line: DeliveryLine.wideOff, length: DeliveryLength.short),
      ]);
      final controller = MatchController(deliveryGenerator: generator);
      final events = <GameplayEventType>[];
      final sub = controller.eventStream.listen((e) => events.add(e.type));
      controller.startMatch(seed: 11, target: 48);
      final firstBowler = controller.state.currentBowler!.id;
      controller.dispatch(const GameCommand.start());

      advanceUntil(
        controller,
        () => controller.state.legalBalls >= 6 || controller.state.isTerminal,
      );
      sub.cancel();

      expect(controller.state.legalBalls, 6);
      expect(controller.state.currentOver, 1);
      expect(controller.state.bowlerIndex, 1);
      expect(controller.state.currentBowler!.id, isNot(firstBowler));
      expect(events, contains(GameplayEventType.overComplete));
    });
  });

  group('running commands', () {
    test(
      'a controlled ground shot gives a rookie enough time for one safe run',
      () {
        final generator = ScriptedDeliveryGenerator([
          scripted(line: DeliveryLine.off, length: DeliveryLength.full),
        ]);
        final controller = MatchController(
          tuning: GameplayTuning.rookie,
          deliveryGenerator: generator,
        );
        final events = <GameplayEventType>[];
        final subscription = controller.eventStream.listen(
          (event) => events.add(event.type),
        );
        addTearDown(subscription.cancel);
        controller.startMatch(seed: 17, target: 48);
        controller.dispatch(const GameCommand.start());
        controller.dispatch(
          const GameCommand.selectElevation(Elevation.ground),
        );
        advanceUntil(
          controller,
          () => controller.state.phase == MatchPhase.incomingBall,
        );
        final contactAt =
            controller.state.currentDelivery!.expectedContactMicros;
        advanceUntil(
          controller,
          () => controller.state.simulationMicros >= contactAt - 240000,
        );
        controller.dispatch(const GameCommand.swing(ShotDirection.offSide));
        advanceUntil(controller, () => controller.state.canRun);

        expect(controller.state.runner.risk, isNot(RiskLevel.danger));
        controller.dispatch(const GameCommand.startRun());
        advanceUntil(
          controller,
          () =>
              events.contains(GameplayEventType.runCompleted) ||
              events.contains(GameplayEventType.runOut) ||
              events.contains(GameplayEventType.boundary),
        );

        expect(events, contains(GameplayEventType.runCompleted));
        expect(events, isNot(contains(GameplayEventType.runOut)));
      },
    );

    test('Turn Back is accepted through 45 percent and scores no run', () {
      final generator = ScriptedDeliveryGenerator([
        scripted(line: DeliveryLine.off, length: DeliveryLength.full),
      ]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 17, target: 48);
      controller.dispatch(const GameCommand.start());
      controller.dispatch(const GameCommand.selectElevation(Elevation.ground));
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );
      final contactAt = controller.state.currentDelivery!.expectedContactMicros;
      advanceUntil(
        controller,
        () => controller.state.simulationMicros >= contactAt - 30000,
      );
      controller.dispatch(const GameCommand.swing(ShotDirection.offSide));
      advanceUntil(controller, () => controller.state.canRun);
      controller.dispatch(const GameCommand.startRun());
      for (var i = 0; i < 15; i++) {
        controller.step(const Duration(microseconds: 16667));
      }
      expect(controller.state.runner.progress, lessThanOrEqualTo(0.45));
      controller.dispatch(const GameCommand.turnBack());
      expect(controller.state.runner.returning, isTrue);

      advanceUntil(controller, () => !controller.state.runner.active);
      expect(controller.state.pendingRuns, 0);
      expect(controller.state.runner.completedRuns, 0);
    });
  });

  group('dynamic field layouts', () {
    for (final extra in [ExtraType.wide, ExtraType.noBall]) {
      test('the field shifts after a ${extra.name} delivery', () {
        final generator = ScriptedDeliveryGenerator([
          scripted(extra: extra),
          scripted(),
        ]);
        final controller = MatchController(deliveryGenerator: generator);
        addTearDown(controller.dispose);
        final events = <GameplayEvent>[];
        final subscription = controller.eventStream.listen(events.add);
        addTearDown(subscription.cancel);

        controller.startMatch(seed: 23, target: 48);
        controller.dispatch(const GameCommand.start());
        final firstPositions = controller.state.fielders
            .map((fielder) => fielder.homePosition)
            .toList();

        advanceUntil(
          controller,
          () => controller.state.physicalDeliveries == 2,
        );

        final secondPositions = controller.state.fielders
            .map((fielder) => fielder.homePosition)
            .toList();
        expect(secondPositions, isNot(orderedEquals(firstPositions)));
        final shift = events.lastWhere(
          (event) => event.type == GameplayEventType.fieldLayoutChanged,
        );
        expect(shift.payload['deliveryOrdinal'], 2);
        expect(shift.payload['id'], isNotEmpty);
        expect(shift.payload['label'], isNotEmpty);
      });
    }

    test('contact launch preserves the prepared formation', () {
      final generator = ScriptedDeliveryGenerator([
        scripted(line: DeliveryLine.middle, length: DeliveryLength.full),
      ]);
      final controller = MatchController(deliveryGenerator: generator);
      addTearDown(controller.dispose);
      controller.startMatch(seed: 31, target: 48);
      controller.dispatch(const GameCommand.start());
      final preparedPositions = controller.state.fielders
          .map((fielder) => fielder.homePosition)
          .toList();

      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );
      final contactAt = controller.state.currentDelivery!.expectedContactMicros;
      advanceUntil(
        controller,
        () => controller.state.simulationMicros >= contactAt - 20000,
      );
      controller.dispatch(const GameCommand.swing(ShotDirection.straight));
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.cameraTransition,
      );

      expect(
        controller.state.fielders.map((fielder) => fielder.homePosition),
        orderedEquals(preparedPositions),
      );
      expect(
        controller.state.fielders.map((fielder) => fielder.position),
        orderedEquals(preparedPositions),
      );
    });

    test('contact holds the batting camera for 450 milliseconds', () {
      final generator = ScriptedDeliveryGenerator([
        scripted(line: DeliveryLine.middle, length: DeliveryLength.full),
      ]);
      final controller = MatchController(deliveryGenerator: generator);
      addTearDown(controller.dispose);
      controller.startMatch(seed: 41, target: 48);
      controller.dispatch(const GameCommand.start());

      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );
      final contactAt = controller.state.currentDelivery!.expectedContactMicros;
      advanceUntil(
        controller,
        () => controller.state.simulationMicros >= contactAt - 20000,
      );
      controller.dispatch(const GameCommand.swing(ShotDirection.straight));
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.contact,
      );

      for (var frame = 0; frame < 26; frame++) {
        controller.step(const Duration(microseconds: 16667));
      }
      expect(controller.state.phase, MatchPhase.contact);

      controller.step(const Duration(microseconds: 16667));
      expect(controller.state.phase, MatchPhase.cameraTransition);
    });
  });
}
```

### E.9 `final_over/test/game/contact_ball_flight_test.dart`

<sub>94 lines</sub>

```dart
import 'package:final_over/domain/domain.dart';
import 'package:final_over/game/contact_ball_flight.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(393, 852);
  const origin = Offset(196.5, 650);

  test('every shot clears its edge before the camera handoff', () {
    const lastVisibleContactProgress = 0.95;
    final ballRadius = viewport.shortestSide * 0.014;

    for (final direction in ShotDirection.values) {
      final endpoint = contactBallFlightPoint(
        viewport: viewport,
        origin: origin,
        direction: direction,
        elevation: Elevation.ground,
        power: 0.65,
        progress: lastVisibleContactProgress,
      );

      switch (direction) {
        case ShotDirection.offSide:
          expect(endpoint.dx, lessThan(-ballRadius));
        case ShotDirection.straight:
          expect(endpoint.dy, lessThan(-ballRadius));
        case ShotDirection.legSide:
          expect(endpoint.dx, greaterThan(viewport.width + ballRadius));
        case ShotDirection.behind:
          expect(endpoint.dy, greaterThan(viewport.height + ballRadius));
      }
    }
  });

  test('flight advances continuously toward the chosen edge', () {
    for (final direction in ShotDirection.values) {
      final midpoint = contactBallFlightPoint(
        viewport: viewport,
        origin: origin,
        direction: direction,
        elevation: Elevation.ground,
        power: 0.65,
        progress: 0.5,
      );
      final endpoint = contactBallFlightPoint(
        viewport: viewport,
        origin: origin,
        direction: direction,
        elevation: Elevation.ground,
        power: 0.65,
        progress: 1,
      );

      expect(midpoint, isNot(origin));
      expect(
        (midpoint - origin).distance,
        lessThan((endpoint - origin).distance),
      );
    }
  });

  test('loft adds an arc but still exits through the selected edge', () {
    final groundMidpoint = contactBallFlightPoint(
      viewport: viewport,
      origin: origin,
      direction: ShotDirection.behind,
      elevation: Elevation.ground,
      power: 0.8,
      progress: 0.5,
    );
    final midpoint = contactBallFlightPoint(
      viewport: viewport,
      origin: origin,
      direction: ShotDirection.behind,
      elevation: Elevation.loft,
      power: 0.8,
      progress: 0.5,
    );
    final endpoint = contactBallFlightPoint(
      viewport: viewport,
      origin: origin,
      direction: ShotDirection.behind,
      elevation: Elevation.loft,
      power: 0.8,
      progress: 1,
    );

    expect(midpoint.dy, lessThan(groundMidpoint.dy));
    expect(midpoint.dy, greaterThan(origin.dy));
    expect(endpoint.dy, greaterThan(viewport.height));
  });
}
```
