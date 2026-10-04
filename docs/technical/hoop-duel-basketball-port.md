# Hoop Duel (Basketball) — Implementation & Porting Reference

> **Status:** BUILT · **Written:** 2026-09-16 · **Audience:** Flutter engineers rebuilding this game in another project
>
> **Source of truth:** `lib/games/basketball/` plus the files listed in §3.
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

Hoop Duel is a **real-time 1v1 half-court basketball duel**, drawn from the
side. It is a 2D arcade game, not a card game. You control one athlete against
a CPU athlete. The hoop is on the right.

| Rule | Value |
|---|---|
| Format | 2 halves × **45 s** game clock, then sudden-death overtime (next basket wins) |
| Shot clock | **12 s**, reset on every change of possession or rebound |
| Scoring | 2 points, or 3 from on/behind the arc (arc line at `x = 11.6 − 6.75`) |
| Rosters | 3 athletes per side. One is active; the player can substitute at halftime |
| Possession | Random tip for H1, flipped for H2, random for OT |
| Made basket | The other side takes the ball from the check spot (`x = 3.2`) |
| Buzzer | If the ball is in the air (or loose off a live shot) when the clock hits 0, the play finishes first (buzzer-beater rule) |
| Win | Higher score after H2; a tie goes to OT, where the first basket wins |
| Difficulty | Rookie / Pro / All-Star (affects only AI latency, jitter, mistakes and fake discipline) |

The feel comes from a **timed shot meter**: releasing near the jump apex
grades as PERFECT, GOOD, EARLY or LATE, and the grade multiplies make
probability. Around that sit steals, blocks, pump fakes, crossovers, a spin
move, step-backs, dunks, rebounds with a landing marker, stamina and a
"heat" (on-fire) state.

## 2. Architecture

```
Flutter screen (Appendix C)            ← phases, overlays, sound, haptics, XP dispatch
 ├─ BasketballCubit (A)                ← lobby selections + coarse phase machine + stats persistence
 ├─ GameWidget(BasketballGame) (A)     ← Flame: 60 fps loop, camera, juice, rendering
 │    ├─ BasketballEngine (A)          ← PURE Dart simulation. Deterministic for (seed, intents)
 │    ├─ BasketballAI (A)              ← produces the same intents a thumb would
 │    └─ rig / court / ball components ← procedural Canvas drawing (no sprites)
 └─ Controls / HUD / Overlays (B)      ← Listener pads → game input API; ValueNotifier HUD
```

Hard rules that the port must keep:

1. **The engine is the only rules authority.** No Flutter or Flame imports.
   Every gate (dunk rating ≥ 72, stamina costs, lockouts) is enforced inside
   `BasketballEngine`, so the AI cannot cheat structurally. It sends the same
   `BasketballIntent` a player does.
2. **Fixed substeps.** `BasketballGame.update` clamps wall `dt` to 1/30 s,
   accumulates it, and steps the engine in fixed **1/120 s** substeps.
   Edge-triggered inputs (press, release, burst, swipe) are consumed only on
   the first substep of a frame.
3. **No bloc emission per frame.** High-frequency HUD values (score, clocks,
   stamina, heat, shot meter, action cue, stings) are `ValueNotifier`s on the
   game. The cubit only hears coarse beats: half ended, match ended.
4. **Two RNGs.** Simulation randomness uses `Random(config.seed)` (and the AI
   uses `seed ^ 0xa11ce`). Cosmetic randomness (sting label variety, shake,
   sparks) uses a separate unseeded `_fxRng`, so visuals never change outcomes.
5. **Reduced motion** disables slow-mo, shake and the impact zoom (`reducedMotion` flag).

## 3. File map

| Target path (keep the same relative layout) | Role | Where |
|---|---|---|
| `lib/games/basketball/basketball_tuning.dart` | Every tunable constant (court, clocks, movement, shot model, defense, stamina, heat, AI) | A.1 |
| `lib/games/basketball/basketball_engine.dart` | Intents, body/ball state, events, the full rules engine | A.2 |
| `lib/games/basketball/basketball_ai.dart` | CPU controller with perception delay, jitter and plans | A.3 |
| `lib/games/basketball/basketball_game.dart` | `FlameGame`: loop, input API, notifiers, camera, juice, court/ball/marker components | A.4 |
| `lib/games/basketball/basketball_rig.dart` | Pose-per-`BodyState` and the athlete draw pass (`AthleteComponent`) | A.5 |
| `lib/games/rig/athlete_rig.dart` | Shared stroke-rig primitives (`RigPose`, IK limbs, jersey number paint) | A.6 |
| `lib/models/basketball.dart` | Enums, `BasketballAthlete`, match config/summary/box score, persisted `BasketballStats` | A.7 |
| `lib/data/basketball_athletes.dart` | The 180-athlete roster (30 teams × 6): seeds → generated ratings/traits/taglines, plus per-team on-court looks | A.8 |
| `lib/data/basketball_teams.dart` | Team liveries (jersey colours) and ownership helpers | A.9 |
| `lib/blocs/basketball/basketball_state.dart` | `BasketballPhase` + state | A.10 |
| `lib/blocs/basketball/basketball_cubit.dart` | Lobby + phase machine + persistence | A.11 |
| `lib/screens/basketball/widgets/basketball_controls.dart` | MOVE pad and contextual ACTION pad | B.1 |
| `lib/screens/basketball/widgets/basketball_hud.dart` | Score/clock bar, stamina rail, shot meter, sting layer | B.2 |
| `lib/screens/basketball/widgets/basketball_overlays.dart` | Halftime overlay (bench/substitution picker) and OVERTIME stinger | B.3 |
| `lib/screens/basketball/basketball_match_screen.dart` | Host screen that wires everything (**reference**) | C.1 |
| `lib/screens/basketball/widgets/basketball_result.dart` | Result overlay (**reference**) | C.2 |
| `lib/config/theme.dart` | **Stand-in**: `Cyber` / `AppTheme` tokens | D.1 |
| `lib/models/progression.dart` | **Stand-in**: `cpuSmartness`, `calculateBasketballXP` (verbatim) | D.2 |
| `lib/services/secure_storage_service.dart` | **Stand-in**: stats load/save (verbatim methods) | D.3 |
| `lib/utils/sound_effects.dart` | **Stand-in**: `SoundEffect` + `playSound` | D.4 |
| `lib/widgets/cyber/cyber_widgets.dart` | **Subset** of shared HUD widgets (verbatim classes) | D.5 |
| `lib/widgets/cyber/cyber_cta_button.dart` | `HudCtaButton` (verbatim) | D.6 |
| `test/basketball_engine_test.dart`, `test/basketball_action_cue_test.dart` | Acceptance suites | E |

Not ported, because they belong to the source app's meta layer: the lobby
screen (roster/difficulty picker), the jersey shop and deck builder, the
card-collection and starter-pack economy, matchmaking, avatars, the global
`GameBloc` XP ledger, and the audio scene controller. §9 lists exactly where
the reference screen touches them.

## 4. Dependencies

```yaml
environment:
  sdk: ^3.12.2          # Dart 3 patterns / switch expressions are used throughout
dependencies:
  flutter: { sdk: flutter }
  flame: ^1.18.0        # verified against 1.38.0
  flutter_bloc: ^9.1.1
  shared_preferences: ^2.5.3   # only for the storage stand-in
dev_dependencies:
  flutter_test: { sdk: flutter }
flutter:
  fonts:               # add `fonts: - asset:` entries pointing at your font files
    - family: Orbitron   # Cyber.displayFont — HUD labels, jersey numbers
    - family: Onest      # Cyber.bodyFont
```

No image, sprite or audio assets are needed to run the game. Athletes, court,
arena and ball are drawn procedurally. Sound is wired through `playSound`
(§8). **Rename `package:card_game/` in the tests to your package name.**

## 5. Rules reference (engine)

Constants live in `basketball_tuning.dart` (A.1). The formulas below are the
ones most likely to be retuned, quoted from A.2.

### 5.1 World

The court is a single axis `x ∈ [0, 12.6]` m. The rim is at `x = 11.6`,
height 3.05, and the backboard at `x = 11.95`. The ball is 2D `(x, h)`. The
distance to the rim is `d = 11.6 − x`. Zones by `d`:

- dunk ≤ 1.5 (2.2 with the RIM PRESSURE trait)
- layup ≤ 2.4
- close ≤ 4.5
- mid < 6.75
- otherwise three

### 5.2 Intents

`BasketballIntent` carries one continuous field and six edge/hold flags:

- `moveAxis` (−1 = away from the hoop, +1 = toward it)
- `burst`
- `actionDown`
- `actionPressed`
- `actionReleased`
- `heldSeconds`
- `swipeBack`

The tap/hold threshold is `kBbTapThreshold = 0.12 s`.

### 5.3 Offense priority table (`_resolveOffense`, evaluated top-down)

| # | Condition | Result |
|---|---|---|
| O1.5 | burst while driving, stamina ≥ 10 | **Spin move** (0.38 s, ball exposed 0.10 s). A set defender within `0.45 × 1.4` m at the end absorbs it (0.30 s lockout). Otherwise it continues as a 0.30 s drive, and SPIN CYCLE fires if the defender was beaten |
| — | burst, not locked, stamina ≥ 12 | **Drive** 0.9 s at ×1.5 speed (drains 12 × 0.4 up front, then 12/s) |
| O1 | swipe back | **Step-back** 0.9 m over 0.3 s, which flows straight into a shot gather |
| O3 | action held while driving inside the dunk gate | **Dunk** if dunk ≥ 72, stamina ≥ 35 and the lane is clear; otherwise a layup |
| O2 | held ≥ 0.12 s, not driving | **Gather** (0.12 s, or 0.08 s with QUICK RELEASE), then a 0.75 s jump shot |
| O7 | release during gather or shot jump | **Release** (graded) |
| O6 | tap with an active put-back window (0.9 s after an offensive board) and `d ≤ 2.4` | **Put-back** (+0.10 make bonus) |
| O4 | tap while moving and `d ≤ 2.4` | **Layup** |
| O5 | tap while set | **Pump fake** (0.35 s). A defender who jumps at it staggers on landing |

A crossover happens when the direction flips within 0.22 s while running or
driving with the ball. It exposes the ball for 0.12 s. If the defender is
within 1.3 m and overcommitted (lunging, or in stance moving the other way),
they stagger: **ANKLE BREAKER**.

### 5.4 Shot meter and grade

Jump apex fraction is 0.42 (0.36 with QUICK RELEASE). The perfect half-window
in seconds is:

```
0.06 × (0.7 + 0.5·clamp((rating−50)/50)) × lerp(0.7, 1, clamp(stamina01/0.6))
     × (1 − 0.25·contest) × (heat ? 1.25) × (quickRelease ? 1.15)
```

GOOD extends 0.14 s beyond that on each side; anything further is EARLY or
LATE. Releasing during the gather is EARLY. Never releasing auto-releases as
LATE on landing. Layups, dunks and put-backs auto-release at the apex as GOOD.

### 5.5 Make probability (`makeProbability`)

```
base    = zoneBase + (rating−70)·0.004 − max(0, d − zoneRef)·0.03  (+0.10 put-back)
          zoneBase: layup/dunk .58, close .50, mid .46, three .40
          DEEP RANGE: no overshoot penalty on threes
timing  = perfect 1.30 · good 1.00 · early/late 0.55
contest = 1 − 0.55·contestOn(shooter)       (RIM PRESSURE halves it on layups)
          contestOn = clamp(1 − gap/2.2) × arms(stance/contest 1.0, block-jump 1.3, else 0.5)
                      × (1 + (defHeight−1.95)·0.3), clamped 0..1.3
balance = 0.85 if moving on a jump shot; ≤0.92 on a step-back; ×0.95 in the first 0.05 s of a jump
stamina = lerp(0.85, 1, clamp(stamina01/0.6))
heat    = 1.12 when on fire
repeat  = 0.9^stacks  (same zone made again: +1 stack, max 2)
p = clamp(product, 0.02, perfect ? 0.93 : 0.88)
```

A dunk that isn't blocked always scores. A **block connects** when the
defender is in a block jump that started within `2 × 0.14 s` of the release
and the gap is within `1.2 + (block−70)·0.004 + (height−1.95)·0.5`. Against a
dunk it is instead a roll of `clamp(0.35 + (block−dunk)·0.004, .05, .75)`.
Beating a mistimed block jump with a dunk triggers **POSTER**.

### 5.6 Defense

The defender's action input resolves as follows:

- **Hold within 1.8 m:** stance (×0.62 speed, drains 1.5/s).
- **Release after holding ≥ 0.16 s against a shooter threat:** block jump.
- **Taps, resolved top-down:**
  1. **Rebound jump** — if the ball is loose or descending (past 55 % of its flight).
  2. **Contest** — if the shooter is up and within 2.2 m.
  3. **Steal lunge** — if within reach + 0.4 m.
  4. **Whiff** — otherwise, with a 0.55 s recovery.

The steal roll happens once, in the lunge's 0.08–0.20 s active frames:

```
p = 0.35 + (steal−70)·0.005 + (exposed ? .25) − (protected ? .65) − (handling−70)·0.003
p = clamp(p, 0.03, 0.85)
```

The handler is **protected** when guarded (within 1.4 m), not driving and not
exposed. Protection also slows the handler to ×0.7.

### 5.7 Rebounds and loose balls

A miss bounces off the rim with a seeded trajectory. The **landing
prediction** is published only after rim contact; the landing marker renders
it. The ball is grabbable below 2.6 m within 0.95 m. When both players jump,
the contest is scored on:

- distance
- rebound rating
- height
- an apex bonus
- GLASS CLEANER
- box-out

A ground pickup happens within 0.7 m once the ball is below 1.2 m. A ball
nobody recovers for **3.5 s** is scooped by the nearest player, so there is
never dead time.

### 5.8 Stamina (0–100) and heat

| Stamina cost | Amount |
|---|---|
| Drive | 12/s |
| Crossover | 3 |
| Jump shot | 6 |
| Dunk | 18 |
| Block jump | 8 |
| Lunge | 5 |
| Contest | 2 |
| Rebound jump | 6 |
| Stance | 1.5/s |

| Stamina regen | Amount |
|---|---|
| Calm | 8/s × (0.8 + stamina/250) |
| During dead-ball resets | 15/s |
| Halftime | bench → 100, active +40 |

A fully tired athlete floors at ×0.85 speed, ×0.9 jump height and ×0.7
perfect window.

**Heat meter (0–1):**

- **Gains:** +0.34 per basket, +0.12 per stop, +0.08 per offensive board. It
  fills to 1 after a 6-0 run.
- **Effects at 1:** ON FIRE for 15 s — ×1.25 perfect window, ×1.08 speed,
  ×0.6 stamina drain, ×1.12 make chance.
- **Reset:** conceding a basket wipes the scorer's opponent's heat.

### 5.9 Match flow inside the engine

- **Phases:** `playPhase` is `awaiting → live → deadReset → live …`.
- **Half end:** a half ends by emitting `halfEnded` and parking in `awaiting`;
  the host must call `startHalf(next)`.
- **Resets:** made baskets and shot-clock violations run a 0.9 s `deadReset`
  in which players lerp to their spots. On a basket, the scorer plays
  `celebrate` and the victim `dejected` (0.8 s).
- **Match end:** an OT basket or a decided H2 emits `matchEnded`, and the
  phase becomes `finished`.

### 5.10 AI (`BasketballAI`)

The AI reads the opponent and the ball through a **perception buffer delayed
by latency**, but reads its own body directly. Timing is blurred by
approximately Gaussian jitter.

| Difficulty | Latency | Jitter | ε (random plan) | Bites on fakes |
|---|---|---|---|---|
| Rookie | 0.40 s | 0.12 | 0.35 | 55 % |
| Pro | 0.25 s | 0.07 | 0.18 | 30 % |
| All-Star | 0.16 s | 0.04 | 0.08 | 15 % |

Offense replans every 0.35–0.75 s between `bringUp`, `probe`, `createSpace`,
`attack` and `pullUp`. At halftime `BasketballGame.cpuAutoSubstitute()` brings
in the freshest bench athlete when the active one is below 55 stamina.

### 5.11 Grade and XP

`BasketballMatchSummary.grade` builds a score from these components:

- **Result:** a win is +3.
- **Field-goal %:** ≥ 60 is +2; ≥ 45 is +1.
- **Perfect releases:** ≥ 3 is +1.
- **Blocks + steals:** ≥ 3 is +2; ≥ 1 is +1.
- **Turnovers:** ≥ 4 is −1.
- **Winning margin:** a win by ≥ 8 is +1.

The total maps to **S ≥ 8 · A ≥ 6 · B ≥ 4 · C ≥ 2 · D**.

`calculateBasketballXP` (D.2) pays as follows:

- **Win:** `min(26, 16 + 2·margin)`, then +2 if it went to OT (capped at 26).
- **Loss:** 4, or 6 if it went to OT.
- **Coins:** never.

## 6. Controls → intents (B.1)

Both pads are raw `Listener`s, not `GestureDetector`s, so a move-hold and an
action-hold register **simultaneously** (multi-touch).

| Gesture | Game API | Engine meaning |
|---|---|---|
| Hold ◀ or ▶ | `setMoveAxis(−1/+1)` | Run. Both held = 0 |
| Double-tap the same arrow within **260 ms** | `tapBurst()` + light haptic | Burst drive. Mid-drive, this becomes a spin |
| ACTION down | `actionPressed()` | Starts the hold timer (the game accumulates `heldT` per substep) |
| ACTION up / cancel | `actionReleased()` | Tap (< 0.12 s) or release (by context, §5.3/5.6) |
| ACTION drag left > 34 px (horizontal-dominant) | `swipeBack()` + selection haptic | Step-back. Cancels the pending hold |

The ACTION pad's label comes from `game.actionCue`
(`BasketballEngine.actionCueFor`):

- SHOOT
- FINISH
- RELEASE
- DEFEND
- BLOCK
- REBOUND

This is presentation only: it explains the input without changing resolution.
`showHints` (first match only) adds MOVE and ACTION hint labels.

## 7. Session phase machine (cubit) and the host contract

`BasketballPhase`: `idle → intro → playing → halftime → playing →
(overtimeBreak → playing) → finished → result`.

The host screen (C.1) must drive the game in this order:

1. **Lobby:** `cubit.load()`, then `toggleRoster(id)` ×3, `setStarter(id)`,
   `setDifficulty(d)`, and finally `buildMatch()`. That creates a seeded
   `BasketballMatchConfig` (CPU roster = 3 random athletes, CPU livery ≠
   player livery) and enters `intro`.
2. Create `BasketballGame(config:, onEvents:, reducedMotion:)` **once** in
   `initState`, and mount `GameWidget(game:)`.
3. When the intro/VS countdown finishes, call `cubit.beginPlay()` and then
   `game.startHalf(0)`.
4. On the `halfEnded` event, call `cubit.onHalfEnded(halfIndex:,
   needsOvertime:)`. On H1, also call `cubit.markHintsSeen()`.
5. **Halftime overlay confirm:**
   - `game.halftimeRest()`
   - if the pick changed, `game.substitutePlayer(i)` (and play the sub cue)
   - `game.cpuAutoSubstitute()`
   - `cubit.resumeSecondHalf()`
   - `game.startHalf(1)`
6. After the OT stinger, call `cubit.beginOvertime()` and then
   `game.startHalf(2)`.
7. **On `matchEnded`** (guard it to run once):
   - `summary = game.summary()`
   - `cubit.onMatchEnded(summary)` — computes XP, updates `BasketballStats`, persists
   - dispatch the XP to your progression system
   - play the victory/defeat cue and a heavy haptic
   - after **900 ms**, `cubit.showResult()`
8. **Exit confirmation:** `game.setPaused(true)`, confirm, then either leave or
   `setPaused(false)`. Leaving mid-match (intro, playing, halftime or
   overtimeBreak) calls `cubit.abandonMatch()`, which records no stats and no
   XP. Guard it with `identical(cubit.state.config, configAtInit)` so a REMATCH
   that already replaced the config isn't reset.

Screen layout (C.1), a `Stack` over `Scaffold(backgroundColor: Cyber.bg)`:

- `GameWidget` fills the screen.
- `BasketballHudBar` sits on top.
- `BasketballStingLayer` sits above the court.
- `BasketballShotMeter` hovers over the player.
- `BasketballStaminaRail` and `BasketballControls` sit at the bottom.
- Phase overlays are on top: the intro/tip-off countdown (built inside C.1),
  halftime and OT (B.3), and the result (C.2).

## 8. Feedback map (gratification)

`BasketballGame._handleEvents` (A.4) supplies the visual juice. The screen
(C.1) supplies sound and haptics.

| Event | Visual | Sting (player / CPU) | Sound (`basketballSoundForEvent`) | Haptic |
|---|---|---|---|---|
| basketMade | net sway, swish burst, crowd surge, backboard flash in the scorer's colour; slow-mo 0.4 s on a PERFECT three by the player | `+2`/`+3` lime, gold on a three (major) / `CONCEDED +n` danger | bbSwish | medium (player) |
| dunk | shake 0.28 s ×9, impact zoom 0.30 s | THROWN DOWN! / HAMMER TIME! / WITH AUTHORITY! gold / DUNKED ON YOUR RIM | bbDunkSlam | heavy |
| poster | slow-mo 0.4, impact zoom | POSTERIZED! / PUT ON A POSTER! gold major | bbPoster | — |
| block | shake 0.22 ×7, 14 cyan sparks, zoom if it was a dunk | BLOCKED! / NOT TODAY! / SENT BACK! cyan / REJECTED! / SWATTED AWAY! | bbBlock | heavy |
| steal | — | STOLEN! / PICKED HIS POCKET! cyan / TURNOVER! | bbSteal | medium |
| ankleBreaker | slow-mo 0.25 | ANKLE BREAKER! / SHIFTED! / CROSSED UP! violet major | bbSneakerSqueak | medium |
| spinMove | — | SPIN CYCLE! / REVERSED! violet / SPUN PAST YOU | bbSneakerSqueak | selection (player) |
| crossover | — | — | bbSneakerSqueak (player) | — |
| perfectRelease | — | PERFECT / SPLASH INCOMING lime (player) | bbPerfectRelease (player) | selection |
| shotReleased | — | — | bbRelease (player) | — |
| heatStarted / heatEnded | crowd "hyped" state | YOU'RE ON FIRE! gold major / OPPONENT HEATING UP | bbCrowdRoar / bbHeatEnd | medium (player) |
| shotClockViolation | — | SHOT CLOCK! danger / FORCED THE STOP! cyan | bbShotClock | — |
| shotMissed | 8 amber rim sparks, light net sway | — | bbRimRattle | — |
| rebound | — | OFF. BOARD — PUT IT BACK! (player offensive) | bbRebound | — |
| buzzerBeater | slow-mo 0.5 | BUZZER BEATER! gold major | bbBuzzer | heavy |
| halfEnded | — | (halftime overlay) | bbBuzzer | heavy |
| stagger | — | — | bbBackboard | — |
| match end | — | (result overlay) | bbVictory / bbDefeat | heavy |

Sting variety uses `_fxRng`. The sting layer (`BasketballStingLayer`, B.2) slams major stings bigger
and holds them longer. Map the cue names to your own audio files. The source
app's `SoundEffect` enum is not portable, so D.4 declares only the cues the B
widgets reference directly.

## 9. Host touch-points in the reference screen (Appendix C)

C.1 and C.2 are shown verbatim, but they import source-app systems. Replace
these:

| Source symbol | What it does | Replace with |
|---|---|---|
| `GameBloc` / `BasketballFinished(...)` | Banks XP and match history globally | Your progression / history service |
| `AudioController.instance.enterScene/leaveScene/setSceneMusicEnabled` | Scene music bed | Your music player (or delete) |
| `basketballSoundForEvent` / `SoundEffect.bb*` | Cue lookup (table in §8) | Your audio mapping |
| `showCyberConfirmDialog` | Leave-match confirm | Any confirm dialog |
| `GameMatchGate` / `GameMatchmakingConfig`, avatar models | Pre-match "finding opponent" gate | Remove, or your own intro |
| `LevelUpCelebration`, level/XP read-outs in C.2 | Level-up moment on the result | Your level-up UI |
| `SecureGameStorage` | Persistence | D.3 or your storage |

## 10. Design rules carried by this code

1. The **glow rule** applies: only the live ball-handler glows on court. Pads
   are calm plates, and the pressed state is an accent fill, never a glow.
2. Every colour comes from `Cyber.*` tokens, except content colours (team
   liveries and athlete skin/hair looks).
3. Shapes use chamfered corners (`HudChamferClipper`,
   `ChamferedActionSurface`).
4. Every meaningful beat has a moment: sting + sound + haptic + camera.

## 11. Port checklist

1. Create the files in §3 at the same paths (A, B, D). Add the §4 dependencies
   and fonts.
2. Replace `D.1` token values with your design system if you have one; keep
   the names.
3. Port C.1 as your match screen, applying §9. Build a lobby that calls the
   cubit methods in §7 step 1.
4. Provide `BasketballCubit(SecureGameStorage())` above the screen with
   `BlocProvider`, and call `load()`.
5. Wire the §8 sound cues.
6. Copy Appendix E into `test/`, rename `package:card_game` to your package,
   and run `flutter test`.
7. Run `flutter analyze` (expect zero issues) and play a match on device:
   check simultaneous move + action, double-tap burst, the shot meter, the
   halftime sub, OT and the result.

## 12. Verification performed for this document

A script read **only this markdown file**, wrote every Appendix A, B, D and E
code block to its heading's path in an empty Flutter package, and added the §4
dependencies (Flutter 3.44.4, flame 1.38.0, flutter_bloc 9.1.1).

- **Verbatim check:** every Appendix A and B block is byte-identical to the
  source repo file.
- **Analyze:** `flutter analyze` → **No issues found!**
- **Tests:** `flutter test` on Appendix E → **35 tests, all passed**. E.1 omits two card-collection tests; see its note.
- **Not checked:** Appendix C was not compiled; it depends on the host
  systems in §9.

---

## Appendix A — Game code (verbatim)

Copy each file to the path in its heading. These are byte-for-byte copies of the source repo.

### A.1 `lib/games/basketball/basketball_tuning.dart`

<sub>243 lines</sub>

```dart
/// Every tunable constant for Hoop Duel in one place (mirrors the Grand Prix
/// engine's tuning discipline). Pure Dart — no Flutter imports.
///
/// World units are metres along a single axis x (the side-view court), plus a
/// height axis h for the ball and jumps. The hoop is on the RIGHT.
/// Distances to the rim are `d = kBbRimX - x`.
library;

// ---------------------------------------------------------------------------
// Court geometry
// ---------------------------------------------------------------------------
const double kBbCourtMinX = 0.0;
const double kBbCourtMaxX = 12.6;
const double kBbRimX = 11.6;
const double kBbBackboardX = 11.95;
const double kBbRimHeight = 3.05;

/// Three-point distance from the rim; the arc line sits at x = kBbRimX - this.
const double kBbArcDist = 6.75;

/// Offense/defense reset spots after a made basket / turnover.
const double kBbCheckSpotX = 3.2;
const double kBbDefResetX = 5.6;

/// Shot-zone boundaries by distance to the rim.
const double kBbDunkGate = 1.5;
const double kBbDunkGateRimPressure = 2.2;
const double kBbLayupRange = 2.4;
const double kBbCloseRange = 4.5;

// ---------------------------------------------------------------------------
// Clocks & flow
// ---------------------------------------------------------------------------
const double kBbHalfSeconds = 45;
const double kBbShotClockSeconds = 12;

/// Dead-ball reset (post-basket / violation) — players lerp to reset spots.
const double kBbResetSeconds = 0.9;

// ---------------------------------------------------------------------------
// Movement
// ---------------------------------------------------------------------------
/// Base run speed (m/s) at 70 SPD; scales ±20% across the rating range.
const double kBbBaseSpeed = 3.4;
const double kBbDriveMult = 1.5;
const double kBbStanceMult = 0.62;
const double kBbProtectMult = 0.7;
const double kBbDriveDuration = 0.9;
const double kBbBurstStaminaCost = 12;

/// A direction flip within this window of the previous one = crossover.
const double kBbCrossoverWindow = 0.22;
const double kBbCrossoverDuration = 0.25;
const double kBbStepbackDistance = 0.9;
const double kBbStepbackDuration = 0.3;

/// Guarded auto ball-protection kicks in inside this gap.
const double kBbGuardedGap = 1.4;

/// Soft body separation — bodies can't overlap closer than this.
const double kBbBodyGap = 0.45;

// ---------------------------------------------------------------------------
// Jumps & shot meter
// ---------------------------------------------------------------------------
const double kBbGatherSeconds = 0.12;
const double kBbGatherQuickRelease = 0.08;
const double kBbJumpShotDuration = 0.75;
const double kBbLayupDuration = 0.6;
const double kBbDunkDuration = 0.65;
const double kBbBlockJumpDuration = 0.6;
const double kBbReboundJumpDuration = 0.55;

/// Meter apex (perfect point) as a fraction of the shot jump.
const double kBbShotApexFrac = 0.42;
const double kBbShotApexQuickRelease = 0.36;
const double kBbMaxJumpHeight = 0.75;

/// Perfect half-window (seconds) at rating 50 before modifiers.
const double kBbPerfectHalfWindow = 0.06;

/// Good grade extends this far beyond the perfect window on both sides.
const double kBbGoodHalfWindow = 0.14;

// ---------------------------------------------------------------------------
// Shot model (probabilities multiply, then clamp)
// ---------------------------------------------------------------------------
const double kBbBaseLayup = 0.58;
const double kBbBaseClose = 0.50;
const double kBbBaseMid = 0.46;
const double kBbBaseThree = 0.40;

/// Make-chance change per rating point away from 70.
const double kBbRatingSlope = 0.004;

/// Make-chance loss per metre beyond the zone's reference distance.
const double kBbDistanceSlope = 0.03;

const double kBbTimingPerfect = 1.30;
const double kBbTimingGood = 1.00;
const double kBbTimingEarlyLate = 0.55;

/// Max contest suppression (at gap 0 with a synced jump contest).
const double kBbContestMax = 0.55;
const double kBbContestRange = 2.2;

const double kBbBalanceMoving = 0.85;
const double kBbBalanceStepback = 0.92;

const double kBbHeatShotBonus = 1.12;
const double kBbRepeatPenalty = 0.9;
const int kBbRepeatMaxStacks = 2;

const double kBbShotFloor = 0.02;
const double kBbShotCap = 0.88;
const double kBbShotCapPerfect = 0.93;

/// Put-back bonus on top of the layup base.
const double kBbPutbackBonus = 0.10;
const double kBbPutbackWindow = 0.9;

// ---------------------------------------------------------------------------
// Defense
// ---------------------------------------------------------------------------
const double kBbStealReach = 1.1;
const double kBbStealActiveFrom = 0.08;
const double kBbStealActiveTo = 0.20;
const double kBbStealBase = 0.35;
const double kBbStealRatingSlope = 0.005;
const double kBbStealExposedBonus = 0.25;
const double kBbStealProtectedPenalty = 0.65;
const double kBbWhiffRecover = 0.55;

/// Grounded contest arm-up bonus and its trigger gap.
const double kBbContestGap = 2.2;

/// Block: jump must start within this window of the release to connect.
const double kBbBlockSyncWindow = 0.14;
const double kBbBlockReachBase = 1.2;
const double kBbBlockReachSlope = 0.004;
const double kBbBlockDunkBase = 0.35;
const double kBbStaggerSeconds = 0.6;
const double kBbFakeSeconds = 0.35;

// ---------------------------------------------------------------------------
// Rebounds
// ---------------------------------------------------------------------------
/// Ball becomes grabbable below this height while loose.
const double kBbCatchHeight = 2.6;
const double kBbReboundReach = 0.95;
const double kBbBoxOutBonus = 0.4;
const double kBbGlassCleanerBonus = 0.15;
const double kBbGroundPickupRange = 0.7;
const double kBbGravity = 9.8;

/// A loose ball nobody recovers this long is scooped by the nearest player, so
/// there's never dead time (and the half can always end).
const double kBbLooseTimeout = 3.5;

// ---------------------------------------------------------------------------
// Stamina (0–100)
// ---------------------------------------------------------------------------
const double kBbDrainDrivePerSec = 12;
const double kBbDrainCrossover = 3;
const double kBbDrainJumpShot = 6;
const double kBbDrainDunk = 18;
const double kBbDrainBlockJump = 8;
const double kBbDrainLunge = 5;
const double kBbDrainContest = 2;
const double kBbDrainReboundJump = 6;
const double kBbDrainStancePerSec = 1.5;
const double kBbRegenCalmPerSec = 8;
const double kBbRegenResetPerSec = 15;
const double kBbHalftimeActiveRegen = 40;
const double kBbDunkStaminaGate = 35;

/// Low-stamina floors (fully tired ⇒ these multipliers).
const double kBbTiredSpeedFloor = 0.85;
const double kBbTiredJumpFloor = 0.9;
const double kBbTiredWindowFloor = 0.7;

// ---------------------------------------------------------------------------
// Heat
// ---------------------------------------------------------------------------
const double kBbHeatPerBasket = 0.34;
const double kBbHeatPerStop = 0.12;
const double kBbHeatPerBoard = 0.08;
const double kBbHeatDuration = 15;
const double kBbHeatWindowMult = 1.25;
const double kBbHeatSpeedMult = 1.08;
const double kBbHeatDrainMult = 0.6;

// ---------------------------------------------------------------------------
// Spin move (second double-tap mid-drive)
// ---------------------------------------------------------------------------
const double kBbSpinDuration = 0.38;
const double kBbSpinSpeedMult = 1.35;
const double kBbSpinStaminaCost = 10;

/// Ball-exposed window at spin start — the steal counterplay.
const double kBbSpinExposed = 0.10;

/// Fresh drive time granted when a spin beats the defender.
const double kBbSpinCarryDrive = 0.30;

/// Lockout when a set defender absorbs the spin (they held their ground).
const double kBbSpinAbsorbRecover = 0.30;

// ---------------------------------------------------------------------------
// Presentation beats (render-facing, still engine-timed for determinism)
// ---------------------------------------------------------------------------

/// Post-basket reaction beat (scorer celebrates, victim slumps). Must stay
/// inside [kBbResetSeconds] so both athletes are idle when play resumes.
const double kBbReactSeconds = 0.8;

/// Impact cinematic: focal zoom-punch duration + strength (dunk/poster/big
/// block), applied to the whole canvas in [BasketballGame.render].
const double kBbCineSeconds = 0.30;
const double kBbCineZoom = 0.03;

/// Backboard score-flash decay.
const double kBbScoreFlashSeconds = 0.5;

/// Hardwood reflection ghosts (rig/ball/hoop): opacity + vertical squash.
const double kBbReflectAlpha = 0.09;
const double kBbReflectSquash = 0.38;

// ---------------------------------------------------------------------------
// AI
// ---------------------------------------------------------------------------
const double kBbAiLatencyRookie = 0.40;
const double kBbAiLatencyPro = 0.25;
const double kBbAiLatencyAllStar = 0.16;
const double kBbAiJitterRookie = 0.12;
const double kBbAiJitterPro = 0.07;
const double kBbAiJitterAllStar = 0.04;
const double kBbAiEpsilonRookie = 0.35;
const double kBbAiEpsilonPro = 0.18;
const double kBbAiEpsilonAllStar = 0.08;
const double kBbAiBiteRookie = 0.55;
const double kBbAiBitePro = 0.30;
const double kBbAiBiteAllStar = 0.15;
```

### A.2 `lib/games/basketball/basketball_engine.dart`

<sub>1820 lines</sub>

```dart
/// Hoop Duel engine — the pure 1v1 half-court basketball simulation.
///
/// Deterministic given a seed + intent streams (mirrors the Grand Prix
/// engine): players move on a 1D court axis, the ball is 2D (x, height).
/// The Flame layer only renders this state and translates pointers into
/// [BasketballIntent]s; the AI produces the same intents. Every rule gate
/// (dunk rating, lockouts) lives HERE, so the AI cannot cheat
/// structurally. No Flutter/Flame imports.
library;

import 'dart:math';

import '../../models/basketball.dart';
import 'basketball_tuning.dart';

// ---------------------------------------------------------------------------
// Intents (identical API for thumbs and AI)
// ---------------------------------------------------------------------------

class BasketballIntent {
  const BasketballIntent({
    this.moveAxis = 0,
    this.burst = false,
    this.actionDown = false,
    this.actionPressed = false,
    this.actionReleased = false,
    this.heldSeconds = 0,
    this.swipeBack = false,
  });

  static const idle = BasketballIntent();

  /// -1 = away from the hoop, +1 = toward it.
  final double moveAxis;

  /// Edge: double-tap burst on the move pad.
  final bool burst;

  /// Action zone currently held.
  final bool actionDown;

  /// Edge: action press started this tick.
  final bool actionPressed;

  /// Edge: action released this tick.
  final bool actionReleased;

  /// How long the action was held at release (or so far).
  final double heldSeconds;

  /// Edge: swipe away from the hoop inside the action zone.
  final bool swipeBack;
}

// ---------------------------------------------------------------------------
// Simulation state
// ---------------------------------------------------------------------------

enum BodyState {
  idle,
  run,
  drive,
  crossover,
  stepback,
  gather,
  jump,
  land,
  stance,
  lunge,
  contest,
  fake,
  stagger,
  celebrate,
  dejected,
  spin,
}

enum JumpPurpose { shot, layup, dunk, putback, block, rebound }

enum BallPhase { held, shot, loose, dead }

enum PlayPhase { awaiting, live, deadReset, finished }

/// Presentation-only meaning of the player's contextual ACTION pad.
///
/// This is derived entirely from simulation state. It does not alter intent
/// resolution; it only explains what the existing tap/hold/release will do.
enum BasketballActionCue { shoot, finish, release, defend, block, rebound }

/// The tap-hold intent 'hold' threshold that separates tap from shot gather.
const double kBbTapThreshold = 0.12;

class BasketballAthleteBody {
  BasketballAthleteBody(this.spec, this.team);

  BasketballAthlete spec;
  final int team;

  double x = 0;
  int facing = 1;
  BodyState body = BodyState.idle;
  double stateT = 0;

  JumpPurpose? jumpPurpose;
  double jumpT = 0;
  double jumpDur = 0;

  double stamina = 100;
  double recoverT = 0;
  double driveT = 0;
  double fakeT = 0;

  /// Ball-exposed window (crossover / drive start) — boosts steals.
  double exposedT = 0;

  /// Put-back quick-shot window after an offensive board.
  double putbackT = 0;

  /// The defender jumped at a pump fake; staggers on landing.
  bool baited = false;

  /// A defender was in the lane when the spin started (the spin had someone
  /// to beat — gates the SPIN CYCLE payoff event).
  bool spinTargeted = false;

  /// Steal lunge has rolled already (one roll per lunge).
  bool lungeRolled = false;

  double lastMoveDir = 0;
  double sinceDirChange = 99;

  bool get airborne => body == BodyState.jump;
  bool get locked =>
      body == BodyState.gather ||
      body == BodyState.jump ||
      body == BodyState.stagger ||
      body == BodyState.stepback ||
      body == BodyState.spin ||
      recoverT > 0;

  double get stamina01 => stamina / 100;

  /// 0..1 vertical jump progress mapped to a sine arc.
  double get jumpHeight => body == BodyState.jump && jumpDur > 0
      ? sin(pi * (jumpT / jumpDur).clamp(0.0, 1.0)) *
            kBbMaxJumpHeight *
            _tiredJump
      : 0;

  double get _tiredJump =>
      kBbTiredJumpFloor + (1 - kBbTiredJumpFloor) * stamina01;

  /// Distance to the rim.
  double get d => kBbRimX - x;

  double get reach =>
      spec.heightM * 1.31 + jumpHeight + (spec.heightM - 1.95) * 0.2;

  void enter(BodyState next) {
    body = next;
    stateT = 0;
  }

  void startJump(JumpPurpose purpose, double duration) {
    jumpPurpose = purpose;
    jumpT = 0;
    jumpDur = duration;
    enter(BodyState.jump);
  }

  void drain(double amount) => stamina = (stamina - amount).clamp(0, 100);
}

class BasketballTeamSim {
  BasketballTeamSim(this.roster, int starterIndex)
    : activeIndex = starterIndex,
      staminas = List<double>.filled(roster.length, 100);

  final List<BasketballAthlete> roster;
  int activeIndex;
  final List<double> staminas;

  int score = 0;
  int unanswered = 0;
  double heatMeter = 0;
  bool heatActive = false;
  double heatT = 0;
}

class ShotFlight {
  ShotFlight({
    required this.make,
    required this.points,
    required this.zone,
    required this.grade,
    required this.shooterTeam,
    required this.duration,
    required this.startX,
    required this.startH,
    required this.releasedBeforeBuzzer,
    this.dunk = false,
  });

  final bool make;
  final int points;
  final ShotZone zone;
  final ReleaseGrade grade;
  final int shooterTeam;
  final double duration;
  final double startX;
  final double startH;
  final bool releasedBeforeBuzzer;
  final bool dunk;
  double t = 0;
}

/// Public rebound prediction — exposed only after rim contact.
class ReboundPrediction {
  const ReboundPrediction(this.landX, this.tLand);

  final double landX;
  final double tLand;
}

class BasketballBall {
  BallPhase phase = BallPhase.dead;

  /// Team index holding the ball, or -1 while loose/in flight.
  int holder = -1;
  double x = kBbCheckSpotX;
  double h = 1.1;
  double vx = 0;
  double vh = 0;
  ShotFlight? flight;
  ReboundPrediction? prediction;
}

/// Shot-meter view for the HUD (null when no meter is running).
class ShotMeterView {
  const ShotMeterView({
    required this.progress,
    required this.perfectCenter,
    required this.perfectHalf,
    required this.goodHalf,
  });

  final double progress;
  final double perfectCenter;
  final double perfectHalf;
  final double goodHalf;
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

enum BasketballEventType {
  basketMade,
  shotMissed,
  steal,
  block,
  rebound,
  shotClockViolation,
  heatStarted,
  heatEnded,
  ankleBreaker,
  poster,
  stagger,
  perfectRelease,
  halfEnded,
  overtimeStarted,
  matchEnded,
  substitution,
  dunk,
  shotReleased,
  buzzerBeater,
  spinMove,
  crossover,
}

class BasketballEvent {
  const BasketballEvent(
    this.type, {
    this.team = -1,
    this.points = 0,
    this.zone,
    this.grade,
    this.offensive = false,
    this.halfIndex = 0,
    this.needsOvertime = false,
    this.onDunk = false,
  });

  final BasketballEventType type;
  final int team;
  final int points;
  final ShotZone? zone;
  final ReleaseGrade? grade;
  final bool offensive;
  final int halfIndex;
  final bool needsOvertime;
  final bool onDunk;
}

// ---------------------------------------------------------------------------
// Engine
// ---------------------------------------------------------------------------

class BasketballEngine {
  BasketballEngine(this.config)
    : _rng = Random(config.seed),
      teams = [
        BasketballTeamSim(config.playerRoster, config.playerStarterIndex),
        BasketballTeamSim(config.cpuRoster, config.cpuStarterIndex),
      ] {
    bodies = [
      BasketballAthleteBody(config.playerRoster[config.playerStarterIndex], 0),
      BasketballAthleteBody(config.cpuRoster[config.cpuStarterIndex], 1),
    ];
    _firstPossession = _rng.nextBool() ? 0 : 1;
  }

  final BasketballMatchConfig config;
  final Random _rng;
  final List<BasketballTeamSim> teams;
  late final List<BasketballAthleteBody> bodies;
  final BasketballBall ball = BasketballBall();

  PlayPhase playPhase = PlayPhase.awaiting;
  int halfIndex = 0;
  double halfClock = kBbHalfSeconds;
  double shotClock = kBbShotClockSeconds;
  int possession = 0;
  double resetT = 0;
  bool overtime = false;

  late int _firstPossession;
  bool _buzzerPending = false;
  bool _matchOver = false;
  double _looseSeconds = 0;

  // Player-team box score accumulation.
  int _attempts = 0;
  int _makes = 0;
  int _threes = 0;
  int _perfects = 0;
  int _dunks = 0;
  int _blocks = 0;
  int _steals = 0;
  int _rebounds = 0;
  int _turnovers = 0;
  int _bestRun = 0;

  /// Repeat-shot penalty stacks per team, keyed by coarse zone bucket.
  final List<ShotZone?> _lastMakeZone = [null, null];
  final List<int> _repeatStacks = [0, 0];

  List<BasketballEvent> _events = [];

  bool get matchOver => _matchOver;

  BasketballAthleteBody get playerBody => bodies[0];
  BasketballAthleteBody get cpuBody => bodies[1];

  /// Current presentation cue for the human-controlled athlete.
  BasketballActionCue get playerActionCue => actionCueFor(0);

  /// Explains the contextual ACTION input for [team] without mutating state.
  ///
  /// The ordering mirrors the live resolution tables below: a rebound
  /// opportunity supersedes offense/defense, an active shot asks for release,
  /// and a valid shooter threat asks a defender to time a block.
  BasketballActionCue actionCueFor(int team) {
    assert(team == 0 || team == 1, 'Basketball teams are indexed 0 or 1.');
    final body = bodies[team];
    final opponent = bodies[1 - team];
    final flight = ball.flight;

    // The cue promises a visible landing marker, so it starts only once a
    // loose-ball prediction is available—not while a made/missed shot is
    // still hidden in flight.
    final reboundAvailable =
        ball.phase == BallPhase.loose && ball.prediction != null;
    if (reboundAvailable && !body.locked && !body.airborne) {
      return BasketballActionCue.rebound;
    }

    final onOffense = possession == team;
    final holdingBall = ball.phase == BallPhase.held && ball.holder == team;
    if (onOffense && holdingBall) {
      final shotRunning =
          body.body == BodyState.gather ||
          (body.airborne && body.jumpPurpose == JumpPurpose.shot);
      if (shotRunning) return BasketballActionCue.release;

      final moving = body.body == BodyState.run || body.body == BodyState.drive;
      final finishAvailable =
          !body.airborne &&
          body.d <= kBbLayupRange &&
          (moving || body.putbackT > 0);
      if (finishAvailable) return BasketballActionCue.finish;

      return BasketballActionCue.shoot;
    }

    final shooterThreat =
        opponent.body == BodyState.gather ||
        opponent.body == BodyState.fake ||
        (opponent.airborne &&
            (opponent.jumpPurpose == JumpPurpose.shot ||
                opponent.jumpPurpose == JumpPurpose.layup ||
                opponent.jumpPurpose == JumpPurpose.dunk ||
                opponent.jumpPurpose == JumpPurpose.putback)) ||
        (ball.phase == BallPhase.shot &&
            flight != null &&
            flight.shooterTeam != team &&
            flight.t <= kBbBlockSyncWindow);
    if (shooterThreat &&
        !body.locked &&
        !body.airborne &&
        body.stamina >= kBbDrainBlockJump) {
      return BasketballActionCue.block;
    }

    return BasketballActionCue.defend;
  }

  /// Court x of the three-point arc line (feet on/behind = a 3). Used to draw
  /// the arc and to decide 2 vs 3 at release.
  static const double arcLineX = kBbRimX - kBbArcDist;

  // -------------------------------------------------------------------------
  // Match flow API (cubit-driven)
  // -------------------------------------------------------------------------

  void startHalf(int index) {
    halfIndex = index;
    overtime = index >= 2;
    halfClock = overtime ? 0 : kBbHalfSeconds;
    possession = switch (index) {
      0 => _firstPossession,
      1 => 1 - _firstPossession,
      _ => _rng.nextBool() ? 0 : 1,
    };
    _buzzerPending = false;
    _placeForPossession();
    shotClock = kBbShotClockSeconds;
    playPhase = PlayPhase.live;
  }

  void substitute(int team, int rosterIndex) {
    final sim = teams[team];
    if (rosterIndex < 0 ||
        rosterIndex >= sim.roster.length ||
        rosterIndex == sim.activeIndex) {
      return;
    }
    // Store the outgoing athlete's stamina, bring the sub in fresh-legged.
    sim.staminas[sim.activeIndex] = bodies[team].stamina;
    sim.activeIndex = rosterIndex;
    final body = BasketballAthleteBody(sim.roster[rosterIndex], team);
    body.stamina = sim.staminas[rosterIndex];
    body.x = bodies[team].x;
    bodies[team] = body;
  }

  /// Bench regeneration + active top-up at halftime.
  void halftimeRest() {
    for (var t = 0; t < 2; t++) {
      final sim = teams[t];
      for (var i = 0; i < sim.staminas.length; i++) {
        sim.staminas[i] = 100;
      }
      bodies[t].stamina = (bodies[t].stamina + kBbHalftimeActiveRegen).clamp(
        0,
        100,
      );
    }
  }

  BasketballMatchSummary summary({bool abandoned = false}) =>
      BasketballMatchSummary(
        playerScore: teams[0].score,
        cpuScore: teams[1].score,
        overtime: overtime,
        difficulty: config.difficulty,
        buzzerBeater: _endedOnBuzzer,
        abandoned: abandoned,
        box: BasketballBoxScore(
          attempts: _attempts,
          makes: _makes,
          threesMade: _threes,
          perfectReleases: _perfects,
          dunks: _dunks,
          blocks: _blocks,
          steals: _steals,
          rebounds: _rebounds,
          turnovers: _turnovers,
          bestRun: _bestRun,
        ),
      );

  bool _endedOnBuzzer = false;

  ShotMeterView? meterView(int team) {
    final body = bodies[team];
    if (body.body == BodyState.gather && body.jumpPurpose == JumpPurpose.shot) {
      return ShotMeterView(
        progress: 0,
        perfectCenter: _apexFrac(body),
        perfectHalf: perfectHalfWindow(body) / kBbJumpShotDuration,
        goodHalf: kBbGoodHalfWindow / kBbJumpShotDuration,
      );
    }
    if (body.body == BodyState.jump &&
        body.jumpPurpose == JumpPurpose.shot &&
        ball.holder == team) {
      return ShotMeterView(
        progress: (body.jumpT / body.jumpDur).clamp(0.0, 1.0),
        perfectCenter: _apexFrac(body),
        perfectHalf: perfectHalfWindow(body) / body.jumpDur,
        goodHalf: kBbGoodHalfWindow / body.jumpDur,
      );
    }
    return null;
  }

  double _apexFrac(BasketballAthleteBody body) =>
      body.spec.trait == BasketballTrait.quickRelease
      ? kBbShotApexQuickRelease
      : kBbShotApexFrac;

  /// Perfect half-window in seconds for this body right now.
  double perfectHalfWindow(BasketballAthleteBody body) {
    final rating = body.spec.ratingFor(zoneFor(body.d));
    final contest = _contestOn(body);
    var half =
        kBbPerfectHalfWindow *
        (0.7 + 0.5 * ((rating - 50) / 50).clamp(0.0, 1.0)) *
        _lerp(
          kBbTiredWindowFloor,
          1.0,
          (body.stamina01 / 0.6).clamp(0.0, 1.0),
        ) *
        (1 - 0.25 * contest);
    if (teams[body.team].heatActive) half *= kBbHeatWindowMult;
    if (body.spec.trait == BasketballTrait.quickRelease) half *= 1.15;
    return half;
  }

  // -------------------------------------------------------------------------
  // step
  // -------------------------------------------------------------------------

  List<BasketballEvent> step(
    BasketballIntent player,
    BasketballIntent cpu,
    double dt,
  ) {
    _events = [];
    if (playPhase == PlayPhase.awaiting || playPhase == PlayPhase.finished) {
      return _events;
    }

    _advanceTimers(dt);

    if (playPhase == PlayPhase.deadReset) {
      _stepDeadReset(dt);
      return _events;
    }

    final intents = [player, cpu];
    for (var t = 0; t < 2; t++) {
      final onOffense = ball.holder == t;
      if (onOffense) {
        _resolveOffense(bodies[t], intents[t]);
      } else {
        _resolveDefense(bodies[t], intents[t]);
      }
      _integrateMovement(bodies[t], intents[t], dt);
    }
    _separateBodies();
    _stepBall(dt);
    _stepClocks(dt);
    return _events;
  }

  // -------------------------------------------------------------------------
  // Timers & states
  // -------------------------------------------------------------------------

  void _advanceTimers(double dt) {
    for (final body in bodies) {
      body.stateT += dt;
      body.sinceDirChange += dt;
      if (body.recoverT > 0) body.recoverT = max(0, body.recoverT - dt);
      if (body.exposedT > 0) body.exposedT = max(0, body.exposedT - dt);
      if (body.putbackT > 0) body.putbackT = max(0, body.putbackT - dt);

      switch (body.body) {
        case BodyState.fake:
          if (body.stateT >= kBbFakeSeconds) body.enter(BodyState.idle);
        case BodyState.crossover:
          if (body.stateT >= kBbCrossoverDuration) body.enter(BodyState.run);
        case BodyState.stepback:
          if (body.stateT >= kBbStepbackDuration) {
            // Step-back flows straight into a gather (shooting space).
            _beginGather(body);
          }
        case BodyState.stagger:
          if (body.stateT >= kBbStaggerSeconds) body.enter(BodyState.idle);
        case BodyState.celebrate:
        case BodyState.dejected:
          if (body.stateT >= kBbReactSeconds) body.enter(BodyState.idle);
        case BodyState.spin:
          if (body.stateT >= kBbSpinDuration) {
            final defender = bodies[1 - body.team];
            final setDefender =
                defender.body == BodyState.stance ||
                defender.body == BodyState.contest;
            // Ending the turn on top of a planted body = the defender held
            // their ground. To beat a set stance the spin must be launched
            // close enough to carry fully PAST it — a timing skill.
            if (setDefender &&
                (defender.x - body.x).abs() <= kBbBodyGap * 1.4) {
              body.enter(BodyState.idle);
              body.recoverT = kBbSpinAbsorbRecover;
            } else {
              body.driveT = kBbSpinCarryDrive;
              body.enter(BodyState.drive);
              if (body.spinTargeted &&
                  (defender.x - body.x) * body.facing < 0) {
                _emit(
                  BasketballEvent(
                    BasketballEventType.spinMove,
                    team: body.team,
                  ),
                );
              }
            }
            body.spinTargeted = false;
          }
        case BodyState.lunge:
          if (body.stateT >= 0.35) {
            body.enter(BodyState.idle);
            if (!body.lungeRolled) body.recoverT = kBbWhiffRecover;
          }
        case BodyState.land:
          if (body.stateT >= 0.18) body.enter(BodyState.idle);
        case BodyState.gather:
          final gatherDur = body.spec.trait == BasketballTrait.quickRelease
              ? kBbGatherQuickRelease
              : kBbGatherSeconds;
          if (body.stateT >= gatherDur) {
            body.startJump(
              body.jumpPurpose ?? JumpPurpose.shot,
              _jumpDurFor(body.jumpPurpose ?? JumpPurpose.shot),
            );
          }
        case BodyState.jump:
          body.jumpT += dt;
          _stepJump(body);
        case BodyState.drive:
          body.driveT -= dt;
          body.drain(kBbDrainDrivePerSec * dt * _heatDrain(body.team));
          if (body.driveT <= 0) body.enter(BodyState.run);
        case BodyState.stance:
          body.drain(kBbDrainStancePerSec * dt * _heatDrain(body.team));
        default:
          break;
      }

      // Calm regeneration. Reaction beats count as calm so the reset-walk
      // regen is unchanged from before reactions existed.
      final calm =
          body.body == BodyState.idle ||
          body.body == BodyState.celebrate ||
          body.body == BodyState.dejected ||
          (body.body == BodyState.run && body.lastMoveDir == 0);
      if (calm) {
        final rate = playPhase == PlayPhase.deadReset
            ? kBbRegenResetPerSec
            : kBbRegenCalmPerSec;
        body.stamina =
            (body.stamina + rate * dt * (0.8 + body.spec.stamina / 250)).clamp(
              0,
              100,
            );
      }
    }

    for (var t = 0; t < 2; t++) {
      final team = teams[t];
      if (team.heatActive) {
        team.heatT -= dt;
        if (team.heatT <= 0) {
          team.heatActive = false;
          team.heatMeter = 0;
          _emit(BasketballEvent(BasketballEventType.heatEnded, team: t));
        }
      }
    }
  }

  double _heatDrain(int team) =>
      teams[team].heatActive ? kBbHeatDrainMult : 1.0;

  double _jumpDurFor(JumpPurpose purpose) => switch (purpose) {
    JumpPurpose.shot => kBbJumpShotDuration,
    JumpPurpose.layup || JumpPurpose.putback => kBbLayupDuration,
    JumpPurpose.dunk => kBbDunkDuration,
    JumpPurpose.block => kBbBlockJumpDuration,
    JumpPurpose.rebound => kBbReboundJumpDuration,
  };

  void _stepJump(BasketballAthleteBody body) {
    final purpose = body.jumpPurpose;
    final apex = body.jumpDur * 0.5;

    // Layups/dunks/put-backs auto-release at their apex.
    if (ball.holder == body.team &&
        body.jumpT >= apex &&
        (purpose == JumpPurpose.layup ||
            purpose == JumpPurpose.dunk ||
            purpose == JumpPurpose.putback)) {
      _releaseShot(body, auto: true);
    }

    // Rebound grab attempt through the jump.
    if (purpose == JumpPurpose.rebound && ball.phase == BallPhase.loose) {
      _tryGrab(body);
    }

    if (body.jumpT >= body.jumpDur) {
      // Shot jump that never released: auto Late release at landing.
      if (ball.holder == body.team && purpose == JumpPurpose.shot) {
        _releaseShot(body, forcedLate: true);
      }
      final wasBaited = body.baited;
      body.baited = false;
      body.jumpPurpose = null;
      if (wasBaited) {
        body.enter(BodyState.stagger);
        _emit(BasketballEvent(BasketballEventType.stagger, team: body.team));
      } else {
        body.enter(BodyState.land);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Offense resolution (deterministic priority table)
  // -------------------------------------------------------------------------

  void _resolveOffense(BasketballAthleteBody body, BasketballIntent intent) {
    if (playPhase != PlayPhase.live) return;

    // O1.5 — spin move: a second double-tap mid-drive whips past the defender.
    // Deterministic counterplay: a defender holding a set stance in the lane
    // absorbs the spin (resolved in _advanceTimers) — no RNG rolls.
    if (intent.burst &&
        body.body == BodyState.drive &&
        !body.airborne &&
        body.stamina >= kBbSpinStaminaCost) {
      final defender = bodies[1 - body.team];
      body.drain(kBbSpinStaminaCost);
      body.exposedT = kBbSpinExposed;
      body.spinTargeted =
          (defender.x - body.x) * body.facing > 0 &&
          (defender.x - body.x).abs() <= 1.6;
      body.enter(BodyState.spin);
      return;
    }

    // Burst drive.
    if (intent.burst &&
        !body.locked &&
        body.stamina >= kBbBurstStaminaCost &&
        body.body != BodyState.drive) {
      body.driveT = kBbDriveDuration;
      body.exposedT = 0.15;
      body.drain(kBbBurstStaminaCost * 0.4);
      body.enter(BodyState.drive);
    }

    // O1 — step-back.
    if (intent.swipeBack && !body.locked && !body.airborne) {
      body.drain(kBbDrainCrossover);
      body.jumpPurpose = JumpPurpose.shot;
      body.enter(BodyState.stepback);
      return;
    }

    // O3 — dunk: hold while driving inside the gate.
    if (intent.actionDown &&
        body.body == BodyState.drive &&
        body.d <= _dunkGate(body) &&
        !body.airborne) {
      if (body.spec.dunk >= 72 &&
          body.stamina >= kBbDunkStaminaGate &&
          _laneClear(body)) {
        body.drain(kBbDrainDunk);
        body.startJump(JumpPurpose.dunk, kBbDunkDuration);
      } else {
        body.drain(kBbDrainJumpShot);
        body.startJump(JumpPurpose.layup, kBbLayupDuration);
      }
      return;
    }

    // O2 — held past the tap threshold: begin the shot gather. Holding
    // through a drive is reserved for the dunk gate (O3) until the drive ends.
    if (intent.actionDown &&
        intent.heldSeconds >= kBbTapThreshold &&
        !body.locked &&
        !body.airborne &&
        body.body != BodyState.drive &&
        body.body != BodyState.gather) {
      body.jumpPurpose = JumpPurpose.shot;
      _beginGather(body);
      return;
    }

    // O7 — release the shot.
    if (intent.actionReleased &&
        (body.body == BodyState.gather ||
            (body.airborne && body.jumpPurpose == JumpPurpose.shot))) {
      _releaseShot(body);
      return;
    }

    if (intent.actionReleased && intent.heldSeconds < kBbTapThreshold) {
      // O6 — put-back.
      if (body.putbackT > 0 && body.d <= kBbLayupRange && !body.airborne) {
        body.drain(kBbDrainJumpShot);
        body.startJump(JumpPurpose.putback, kBbLayupDuration);
        return;
      }
      // O4 — layup on the move near the rim.
      final moving = body.body == BodyState.run || body.body == BodyState.drive;
      if (moving && body.d <= kBbLayupRange && !body.airborne) {
        body.drain(kBbDrainJumpShot);
        body.startJump(JumpPurpose.layup, kBbLayupDuration);
        return;
      }
      // O5 — pump fake while set.
      if (!body.locked && !body.airborne) {
        body.enter(BodyState.fake);
        return;
      }
    }
  }

  double _dunkGate(BasketballAthleteBody body) =>
      body.spec.trait == BasketballTrait.rimPressure
      ? kBbDunkGateRimPressure
      : kBbDunkGate;

  bool _laneClear(BasketballAthleteBody body) {
    final defender = bodies[1 - body.team];
    if (defender.body != BodyState.stance &&
        defender.body != BodyState.contest &&
        !defender.airborne) {
      return true;
    }
    // A set defender between the driver and the rim blocks the lane.
    final between = defender.x > body.x && defender.x < kBbRimX;
    return !(between && (defender.x - body.x).abs() < 0.9);
  }

  void _beginGather(BasketballAthleteBody body) {
    body.drain(kBbDrainJumpShot);
    body.jumpPurpose = JumpPurpose.shot;
    body.enter(BodyState.gather);
  }

  // -------------------------------------------------------------------------
  // Defense resolution
  // -------------------------------------------------------------------------

  void _resolveDefense(BasketballAthleteBody body, BasketballIntent intent) {
    if (playPhase != PlayPhase.live) return;
    final attacker = bodies[1 - body.team];
    final gap = (attacker.x - body.x).abs();

    // Sustained hold near the handler = stance; hold + release = block jump.
    if (intent.actionDown && !body.locked && !body.airborne) {
      if (body.body != BodyState.stance && gap <= 1.8) {
        body.enter(BodyState.stance);
      }
    } else if (body.body == BodyState.stance &&
        !intent.actionDown &&
        !intent.actionReleased) {
      body.enter(BodyState.idle);
    }

    if (intent.actionReleased && intent.heldSeconds >= 0.16 && !body.locked) {
      // D3 — block jump, but only against a rising/faking shooter or a ball
      // that just left the hand. Releasing a plain stance hold stays grounded.
      final shooterThreat =
          attacker.body == BodyState.gather ||
          attacker.body == BodyState.fake ||
          (attacker.airborne &&
              (attacker.jumpPurpose == JumpPurpose.shot ||
                  attacker.jumpPurpose == JumpPurpose.layup ||
                  attacker.jumpPurpose == JumpPurpose.dunk ||
                  attacker.jumpPurpose == JumpPurpose.putback)) ||
          (ball.phase == BallPhase.shot &&
              (ball.flight?.t ?? 99) <= kBbBlockSyncWindow);
      if (shooterThreat && body.stamina >= kBbDrainBlockJump) {
        body.drain(kBbDrainBlockJump);
        if (attacker.body == BodyState.fake) body.baited = true;
        body.startJump(JumpPurpose.block, kBbBlockJumpDuration);
        _tryBlockInFlight(body);
      } else if (body.body == BodyState.stance) {
        body.enter(BodyState.idle);
      }
      return;
    }

    if (intent.actionReleased && intent.heldSeconds < kBbTapThreshold) {
      // Taps resolve top-down: rebound → contest → steal → whiff.
      if (body.locked || body.airborne) return;

      // D1 — rebound jump at a loose or descending ball.
      final ballComing =
          ball.phase == BallPhase.loose ||
          (ball.phase == BallPhase.shot &&
              ball.flight != null &&
              ball.flight!.t / ball.flight!.duration > 0.55);
      if (ballComing) {
        body.drain(kBbDrainReboundJump);
        body.startJump(JumpPurpose.rebound, kBbReboundJumpDuration);
        return;
      }

      // D2 — grounded contest while the shooter gathers/rises.
      final shooterUp =
          attacker.body == BodyState.gather ||
          (attacker.airborne && attacker.jumpPurpose == JumpPurpose.shot);
      if (shooterUp && gap <= kBbContestGap) {
        body.drain(kBbDrainContest);
        body.enter(BodyState.contest);
        return;
      }

      // D4 — steal lunge.
      if (ball.holder == attacker.team && gap <= kBbStealReach + 0.4) {
        body.drain(kBbDrainLunge);
        body.lungeRolled = false;
        body.enter(BodyState.lunge);
        return;
      }

      // D5 — whiff.
      body.drain(kBbDrainLunge);
      body.lungeRolled = false;
      body.enter(BodyState.lunge);
    }

    // Steal roll during the lunge's active frames.
    if (body.body == BodyState.lunge &&
        !body.lungeRolled &&
        body.stateT >= kBbStealActiveFrom &&
        body.stateT <= kBbStealActiveTo &&
        ball.holder == attacker.team) {
      final reach = (attacker.x - body.x).abs() <= kBbStealReach;
      if (reach) {
        body.lungeRolled = true;
        _rollSteal(body, attacker);
      }
    }

    // Contest state relaxes once the shot resolves.
    if (body.body == BodyState.contest && body.stateT > 0.5) {
      body.enter(BodyState.idle);
    }
  }

  void _rollSteal(
    BasketballAthleteBody defender,
    BasketballAthleteBody handler,
  ) {
    final exposed = handler.exposedT > 0 || handler.body == BodyState.crossover;
    final guarded = (handler.x - defender.x).abs() <= kBbGuardedGap;
    final protected = guarded && handler.body != BodyState.drive && !exposed;
    var p =
        kBbStealBase +
        (defender.spec.steal - 70) * kBbStealRatingSlope +
        (exposed ? kBbStealExposedBonus : 0) -
        (protected ? kBbStealProtectedPenalty : 0) -
        (handler.spec.handling - 70) * 0.003;
    p = p.clamp(0.03, 0.85);
    if (_rng.nextDouble() < p) {
      _turnover(to: defender.team, steal: true);
      defender.enter(BodyState.idle);
      if (defender.team == 0) _steals++;
      if (handler.team == 0) _turnovers++;
      teams[defender.team].heatMeter =
          (teams[defender.team].heatMeter + kBbHeatPerStop).clamp(0.0, 1.0);
      _maybeIgniteHeat(defender.team);
      _emit(BasketballEvent(BasketballEventType.steal, team: defender.team));
    }
  }

  // -------------------------------------------------------------------------
  // Movement
  // -------------------------------------------------------------------------

  void _integrateMovement(
    BasketballAthleteBody body,
    BasketballIntent intent,
    double dt,
  ) {
    // Scripted step-back slide.
    if (body.body == BodyState.stepback) {
      body.x -= kBbStepbackDistance * (dt / kBbStepbackDuration);
      body.x = body.x.clamp(kBbCourtMinX, kBbCourtMaxX);
      return;
    }
    // Scripted spin slide — the turn carries the handler forward.
    if (body.body == BodyState.spin) {
      body.x = (body.x + body.facing * kBbBaseSpeed * kBbSpinSpeedMult * dt)
          .clamp(kBbCourtMinX, kBbCourtMaxX);
      return;
    }
    if (body.locked || body.airborne || playPhase != PlayPhase.live) {
      return;
    }
    // Lunge carries a small forward step toward the attacker.
    if (body.body == BodyState.lunge) {
      final attacker = bodies[1 - body.team];
      final dir = (attacker.x - body.x).sign;
      body.x += dir * 1.6 * dt;
      return;
    }

    final axis = intent.moveAxis.clamp(-1.0, 1.0);

    // Crossover: quick direction flip while moving with the ball.
    if (axis != 0 &&
        body.lastMoveDir != 0 &&
        axis.sign != body.lastMoveDir.sign &&
        body.sinceDirChange <= kBbCrossoverWindow &&
        ball.holder == body.team &&
        (body.body == BodyState.run || body.body == BodyState.drive)) {
      body.drain(kBbDrainCrossover);
      body.exposedT = 0.12;
      body.enter(BodyState.crossover);
      _emit(BasketballEvent(BasketballEventType.crossover, team: body.team));
      _checkAnkleBreaker(body);
    }
    if (axis != 0 && axis.sign != body.lastMoveDir.sign) {
      body.sinceDirChange = 0;
    }
    body.lastMoveDir = axis;
    if (axis != 0) body.facing = axis > 0 ? 1 : -1;

    var speed =
        kBbBaseSpeed *
        (0.8 + 0.4 * ((body.spec.speed - 30) / 69).clamp(0.0, 1.0)) *
        _lerp(kBbTiredSpeedFloor, 1.0, body.stamina01);
    if (teams[body.team].heatActive) speed *= kBbHeatSpeedMult;
    switch (body.body) {
      case BodyState.drive:
        speed *= kBbDriveMult;
      case BodyState.stance:
        speed *= kBbStanceMult;
      case BodyState.crossover:
        speed *= 1.15;
      default:
        break;
    }
    // Guarded auto ball-protection: slower but steal-resistant.
    if (ball.holder == body.team &&
        body.body != BodyState.drive &&
        (bodies[1 - body.team].x - body.x).abs() <= kBbGuardedGap) {
      speed *= kBbProtectMult;
    }

    if (axis != 0 &&
        (body.body == BodyState.idle || body.body == BodyState.land)) {
      body.enter(BodyState.run);
    } else if (axis == 0 && body.body == BodyState.run) {
      body.enter(BodyState.idle);
    }

    body.x = (body.x + axis * speed * dt).clamp(kBbCourtMinX, kBbCourtMaxX);
  }

  void _checkAnkleBreaker(BasketballAthleteBody handler) {
    final defender = bodies[1 - handler.team];
    final gap = (handler.x - defender.x).abs();
    if (gap > 1.3) return;
    final overcommitted =
        defender.body == BodyState.lunge ||
        (defender.body == BodyState.stance &&
            defender.lastMoveDir != 0 &&
            defender.lastMoveDir.sign != handler.lastMoveDir.sign);
    if (overcommitted) {
      defender.enter(BodyState.stagger);
      _emit(
        BasketballEvent(BasketballEventType.ankleBreaker, team: handler.team),
      );
    }
  }

  void _separateBodies() {
    final a = bodies[0];
    final b = bodies[1];
    // A spinning handler rotates around the defender's body rather than
    // bulldozing them — separation is suspended for the spin's duration.
    if (a.body == BodyState.spin || b.body == BodyState.spin) return;
    final dx = b.x - a.x;
    if (dx.abs() >= kBbBodyGap || dx == 0) return;
    final overlap = kBbBodyGap - dx.abs();
    final dir = dx.sign;
    // Heavier bodies hold their ground.
    double wa = b.spec.heightM / (a.spec.heightM + b.spec.heightM);
    double wb = 1 - wa;

    // Fix: When fighting for a loose ball, the player closer to the ball establishes
    // position and cannot be bulldozed from behind by the opponent.
    if (ball.phase == BallPhase.loose || ball.phase == BallPhase.shot) {
      final aDist = (a.x - ball.x).abs();
      final bDist = (b.x - ball.x).abs();
      if (aDist < bDist - 0.1 && (b.x - a.x).sign == b.lastMoveDir.sign) {
        wa = 0.05;
        wb = 0.95;
      } else if (bDist < aDist - 0.1 &&
          (a.x - b.x).sign == a.lastMoveDir.sign) {
        wa = 0.95;
        wb = 0.05;
      }
    }

    a.x = (a.x - dir * overlap * wa).clamp(kBbCourtMinX, kBbCourtMaxX);
    b.x = (b.x + dir * overlap * wb).clamp(kBbCourtMinX, kBbCourtMaxX);
  }

  // -------------------------------------------------------------------------
  // Shooting
  // -------------------------------------------------------------------------

  ShotZone zoneFor(double d) {
    if (d <= kBbDunkGate) return ShotZone.dunk;
    if (d <= kBbLayupRange) return ShotZone.layup;
    if (d <= kBbCloseRange) return ShotZone.close;
    if (d < kBbArcDist) return ShotZone.mid;
    return ShotZone.three;
  }

  /// Contest factor 0..1 on a shooter from the opposing defender.
  double _contestOn(BasketballAthleteBody shooter) {
    final defender = bodies[1 - shooter.team];
    final gap = (defender.x - shooter.x).abs();
    final proximity = (1 - gap / kBbContestRange).clamp(0.0, 1.0);
    final arms = switch (defender.body) {
      BodyState.stance || BodyState.contest => 1.0,
      BodyState.jump when defender.jumpPurpose == JumpPurpose.block => 1.3,
      _ => 0.5,
    };
    final height = 1 + (defender.spec.heightM - 1.95) * 0.3;
    return (proximity * arms * height).clamp(0.0, 1.3);
  }

  void _releaseShot(
    BasketballAthleteBody body, {
    bool auto = false,
    bool forcedLate = false,
  }) {
    if (ball.holder != body.team) return;
    final purpose = body.jumpPurpose ?? JumpPurpose.shot;

    // Grade the release.
    ReleaseGrade grade;
    if (forcedLate) {
      grade = ReleaseGrade.late;
    } else if (auto) {
      grade = ReleaseGrade.good;
    } else if (body.body == BodyState.gather) {
      // Released before the jump even started.
      body.startJump(JumpPurpose.shot, kBbJumpShotDuration);
      grade = ReleaseGrade.early;
    } else {
      final apexT = body.jumpDur * _apexFrac(body);
      final offset = body.jumpT - apexT;
      final half = perfectHalfWindow(body);
      if (offset.abs() <= half) {
        grade = ReleaseGrade.perfect;
      } else if (offset.abs() <= half + kBbGoodHalfWindow) {
        grade = ReleaseGrade.good;
      } else {
        grade = offset < 0 ? ReleaseGrade.early : ReleaseGrade.late;
      }
    }

    final releaseX = body.x;
    final d = kBbRimX - releaseX;
    var zone = purpose == JumpPurpose.dunk
        ? ShotZone.dunk
        : purpose == JumpPurpose.layup || purpose == JumpPurpose.putback
        ? ShotZone.layup
        : zoneFor(d);
    // A jump shot from point blank still counts as a layup-range attempt.
    if (zone == ShotZone.dunk && purpose == JumpPurpose.shot) {
      zone = ShotZone.layup;
    }
    final points = zone == ShotZone.three ? 3 : 2;

    // Block check at release.
    final defender = bodies[1 - body.team];
    final blocked = _blockConnects(defender, body);

    // Make roll.
    final isDunk = purpose == JumpPurpose.dunk;
    bool make;
    if (blocked) {
      make = false;
    } else if (isDunk) {
      make = true;
    } else {
      make = _rng.nextDouble() < makeProbability(body, zone, grade, purpose);
    }

    if (body.team == 0) {
      _attempts++;
      if (grade == ReleaseGrade.perfect) _perfects++;
    }
    if (grade == ReleaseGrade.perfect) {
      _emit(
        BasketballEvent(BasketballEventType.perfectRelease, team: body.team),
      );
    }

    final releasedBeforeBuzzer = overtime || halfClock > 0;
    final startH = body.spec.heightM + body.jumpHeight + 0.3;
    final duration = isDunk ? 0.22 : (0.42 + d.abs() * 0.055).clamp(0.3, 0.95);

    ball.phase = BallPhase.shot;
    ball.holder = -1;
    ball.x = releaseX;
    ball.h = startH;
    ball.prediction = null;
    ball.flight = ShotFlight(
      make: make,
      points: points,
      zone: zone,
      grade: grade,
      shooterTeam: body.team,
      duration: duration,
      startX: releaseX,
      startH: startH,
      releasedBeforeBuzzer: releasedBeforeBuzzer,
      dunk: isDunk,
    );
    _emit(
      BasketballEvent(
        BasketballEventType.shotReleased,
        team: body.team,
        zone: zone,
        grade: grade,
      ),
    );

    if (blocked) {
      _resolveBlock(defender, body, onDunk: isDunk);
    } else if (isDunk &&
        defender.airborne &&
        defender.jumpPurpose == JumpPurpose.block) {
      // Beat a mistimed block jump at the rim: poster.
      _emit(BasketballEvent(BasketballEventType.poster, team: body.team));
    }
  }

  double makeProbability(
    BasketballAthleteBody body,
    ShotZone zone,
    ReleaseGrade grade,
    JumpPurpose purpose,
  ) {
    final spec = body.spec;
    final d = body.d;
    final rating = spec.ratingFor(zone);
    final zoneBase = switch (zone) {
      ShotZone.dunk || ShotZone.layup => kBbBaseLayup,
      ShotZone.close => kBbBaseClose,
      ShotZone.mid => kBbBaseMid,
      ShotZone.three => kBbBaseThree,
    };
    final zoneRef = switch (zone) {
      ShotZone.dunk || ShotZone.layup => kBbLayupRange,
      ShotZone.close => kBbCloseRange,
      ShotZone.mid => kBbArcDist,
      ShotZone.three => kBbArcDist,
    };
    var overshoot = max(0.0, d - zoneRef);
    if (zone == ShotZone.three && spec.trait == BasketballTrait.deepRange) {
      overshoot = 0;
    }
    var base =
        zoneBase +
        (rating - 70) * kBbRatingSlope -
        overshoot * kBbDistanceSlope;
    if (purpose == JumpPurpose.putback) base += kBbPutbackBonus;

    final timing = switch (grade) {
      ReleaseGrade.perfect => kBbTimingPerfect,
      ReleaseGrade.good => kBbTimingGood,
      _ => kBbTimingEarlyLate,
    };

    var contest = 1 - kBbContestMax * _contestOn(body).clamp(0.0, 1.0);
    if (purpose == JumpPurpose.layup &&
        spec.trait == BasketballTrait.rimPressure) {
      contest = 1 - (1 - contest) * 0.5;
    }

    final moving = body.lastMoveDir != 0 && purpose == JumpPurpose.shot;
    var balance = moving ? kBbBalanceMoving : 1.0;
    if (body.body == BodyState.jump && body.stateT < 0.05) balance *= 0.95;
    // Step-back shots carry a slight balance penalty.
    if (body.exposedT > 0 && purpose == JumpPurpose.shot) {
      balance = min(balance, kBbBalanceStepback);
    }

    final stamina = _lerp(0.85, 1.0, (body.stamina01 / 0.6).clamp(0.0, 1.0));
    final heat = teams[body.team].heatActive ? kBbHeatShotBonus : 1.0;
    final repeat = pow(kBbRepeatPenalty, _repeatStacks[body.team]).toDouble();

    final cap = grade == ReleaseGrade.perfect ? kBbShotCapPerfect : kBbShotCap;
    return (base * timing * contest * balance * stamina * heat * repeat).clamp(
      kBbShotFloor,
      cap,
    );
  }

  bool _blockConnects(
    BasketballAthleteBody defender,
    BasketballAthleteBody shooter,
  ) {
    if (!defender.airborne || defender.jumpPurpose != JumpPurpose.block) {
      return false;
    }
    if (defender.jumpT > kBbBlockSyncWindow * 2) return false;
    final gap = (defender.x - shooter.x).abs();
    final reach =
        kBbBlockReachBase +
        (defender.spec.block - 70) * kBbBlockReachSlope +
        (defender.spec.heightM - 1.95) * 0.5;
    if (gap > reach) return false;
    if (shooter.jumpPurpose == JumpPurpose.dunk) {
      final p =
          (kBbBlockDunkBase + (defender.spec.block - shooter.spec.dunk) * 0.004)
              .clamp(0.05, 0.75);
      return _rng.nextDouble() < p;
    }
    return true;
  }

  void _resolveBlock(
    BasketballAthleteBody defender,
    BasketballAthleteBody shooter, {
    required bool onDunk,
  }) {
    // Deflection: down / behind the shooter / toward the sideline, in play.
    final mode = _rng.nextInt(3);
    ball.phase = BallPhase.loose;
    ball.flight = null;
    ball.h = shooter.spec.heightM + shooter.jumpHeight;
    ball.x = shooter.x;
    switch (mode) {
      case 0: // straight down
        ball.vx = -0.4;
        ball.vh = -2.0;
      case 1: // behind the shooter
        ball.vx = -(1.8 + _rng.nextDouble() * 1.6);
        ball.vh = 1.2;
      default: // toward the sideline but kept in play
        ball.vx = -(0.8 + _rng.nextDouble() * 0.8);
        ball.vh = 2.2;
    }
    ball.prediction = _predictLanding();
    if (defender.team == 0) _blocks++;
    teams[defender.team].heatMeter =
        (teams[defender.team].heatMeter + kBbHeatPerStop).clamp(0.0, 1.0);
    _maybeIgniteHeat(defender.team);
    _emit(
      BasketballEvent(
        BasketballEventType.block,
        team: defender.team,
        onDunk: onDunk,
      ),
    );
  }

  void _tryBlockInFlight(BasketballAthleteBody defender) {
    final flight = ball.flight;
    if (ball.phase != BallPhase.shot || flight == null) return;
    if (flight.t > kBbBlockSyncWindow) return;
    if (flight.shooterTeam == defender.team) return;
    final shooter = bodies[flight.shooterTeam];
    if (_blockConnects(defender, shooter)) {
      _resolveBlock(defender, shooter, onDunk: flight.dunk);
    }
  }

  // -------------------------------------------------------------------------
  // Ball
  // -------------------------------------------------------------------------

  void _stepBall(double dt) {
    if (ball.phase != BallPhase.loose) _looseSeconds = 0;
    switch (ball.phase) {
      case BallPhase.held:
        final holder = bodies[ball.holder];
        ball.x = holder.x + holder.facing * 0.35;
        ball.h = 1.1;
      case BallPhase.shot:
        final flight = ball.flight!;
        flight.t += dt;
        final s = (flight.t / flight.duration).clamp(0.0, 1.0);
        // Quadratic arc from release to the rim with lift above both ends.
        final lift = flight.dunk
            ? 0.25
            : max(1.0, (kBbRimX - flight.startX).abs() * 0.22);
        final peak = max(flight.startH, kBbRimHeight) + lift;
        ball.x = _lerp(flight.startX, kBbRimX, s);
        ball.h = _arcHeight(flight.startH, peak, kBbRimHeight, s);
        if (s >= 1) _resolveShotArrival(flight);
      case BallPhase.loose:
        ball.vh -= kBbGravity * dt;
        ball.x += ball.vx * dt;
        ball.h += ball.vh * dt;
        if (ball.x < kBbCourtMinX + 0.15 || ball.x > kBbCourtMaxX - 0.15) {
          ball.vx = -ball.vx * 0.7;
          ball.x = ball.x.clamp(kBbCourtMinX + 0.15, kBbCourtMaxX - 0.15);
        }
        if (ball.h <= 0.12 && ball.vh < 0) {
          ball.h = 0.12;
          ball.vh = -ball.vh * 0.55;
          ball.vx *= 0.8;
          if (ball.vh.abs() < 0.8) ball.vh = 0;
        }
        _tryGroundPickup();
        // Safety net: a ball nobody chases down is scooped by the nearest
        // player, so there's never dead time and a pending buzzer can resolve.
        if (ball.phase == BallPhase.loose) {
          _looseSeconds += dt;
          if (_looseSeconds >= kBbLooseTimeout) _forceLooseRecovery();
        }
      case BallPhase.dead:
        break;
    }
  }

  void _forceLooseRecovery() {
    final a = bodies[0];
    final b = bodies[1];
    final nearest = (ball.x - a.x).abs() <= (ball.x - b.x).abs() ? a : b;
    _grabBall(nearest);
  }

  double _arcHeight(double from, double peak, double to, double s) {
    // Piecewise parabola through (0,from) (0.55,peak) (1,to).
    if (s < 0.55) {
      final u = s / 0.55;
      return from + (peak - from) * (1 - (1 - u) * (1 - u));
    }
    final u = (s - 0.55) / 0.45;
    return peak - (peak - to) * u * u;
  }

  void _resolveShotArrival(ShotFlight flight) {
    if (flight.make) {
      _scoreBasket(flight);
      return;
    }
    // Miss: rim bounce → loose ball with a seeded, varied trajectory.
    final missAngle = _rng.nextDouble();
    final long = _rng.nextBool();
    final spread = 0.8 + (kBbRimX - flight.startX).abs() * 0.35 * missAngle;
    ball.phase = BallPhase.loose;
    ball.flight = null;
    ball.x = kBbRimX;
    ball.h = kBbRimHeight;
    ball.vx = (long ? -1 : -0.45) * spread;
    ball.vh = 1.6 + missAngle * 1.8;
    // Publish the landing prediction now that the rim has been hit.
    ball.prediction = _predictLanding();
    _emit(
      BasketballEvent(
        BasketballEventType.shotMissed,
        team: flight.shooterTeam,
        zone: flight.zone,
        grade: flight.grade,
      ),
    );
    if (_buzzerPending) _finishHalfNow();
  }

  ReboundPrediction _predictLanding() {
    // Closed-form projectile: where the ball first falls to catch height.
    const target = 1.2;
    final vh = ball.vh;
    final disc = vh * vh + 2 * kBbGravity * (ball.h - target);
    final t = (vh + sqrt(max(0, disc))) / kBbGravity;
    final landX = (ball.x + ball.vx * t).clamp(
      kBbCourtMinX + 0.15,
      kBbCourtMaxX - 0.15,
    );
    return ReboundPrediction(landX, t);
  }

  void _scoreBasket(ShotFlight flight) {
    final scorer = flight.shooterTeam;
    final team = teams[scorer];
    final other = teams[1 - scorer];
    team.score += flight.points;
    team.unanswered += flight.points;
    other.unanswered = 0;
    if (other.heatActive) {
      other.heatActive = false;
      other.heatMeter = 0;
      _emit(BasketballEvent(BasketballEventType.heatEnded, team: 1 - scorer));
    } else {
      other.heatMeter = 0;
    }
    if (scorer == 0) {
      _makes++;
      if (flight.points == 3) _threes++;
      if (flight.dunk) _dunks++;
      _bestRun = max(_bestRun, teams[0].unanswered);
    }
    // Repeat-shot penalty bookkeeping.
    if (_lastMakeZone[scorer] == flight.zone) {
      _repeatStacks[scorer] = min(
        kBbRepeatMaxStacks,
        _repeatStacks[scorer] + 1,
      );
    } else {
      _repeatStacks[scorer] = 0;
    }
    _lastMakeZone[scorer] = flight.zone;

    team.heatMeter = (team.heatMeter + kBbHeatPerBasket).clamp(0.0, 1.0);
    if (team.unanswered >= 6) team.heatMeter = 1;
    _maybeIgniteHeat(scorer);

    final buzzer = _buzzerPending;
    _emit(
      BasketballEvent(
        BasketballEventType.basketMade,
        team: scorer,
        points: flight.points,
        zone: flight.zone,
        grade: flight.grade,
      ),
    );
    if (flight.dunk) {
      _emit(BasketballEvent(BasketballEventType.dunk, team: scorer));
    }
    if (buzzer) {
      _emit(BasketballEvent(BasketballEventType.buzzerBeater, team: scorer));
    }

    ball.phase = BallPhase.dead;
    ball.flight = null;
    ball.prediction = null;

    if (overtime) {
      _endMatch(buzzer: false);
      return;
    }
    if (buzzer) {
      _finishHalfNow(buzzerBeater: true);
      return;
    }
    _beginReset(newPossession: 1 - scorer, scoredBy: scorer);
  }

  void _maybeIgniteHeat(int teamIndex) {
    final team = teams[teamIndex];
    if (!team.heatActive && team.heatMeter >= 1) {
      team.heatActive = true;
      team.heatT = kBbHeatDuration;
      _emit(BasketballEvent(BasketballEventType.heatStarted, team: teamIndex));
    }
  }

  // -------------------------------------------------------------------------
  // Rebounds & pickups
  // -------------------------------------------------------------------------

  void _tryGrab(BasketballAthleteBody body) {
    if (ball.phase != BallPhase.loose) return;
    if (ball.h > body.reach || ball.h < 0.5) return;
    if ((ball.x - body.x).abs() > kBbReboundReach) return;

    // Contested when the opponent is also mid rebound-jump in range.
    final other = bodies[1 - body.team];
    final contested =
        other.airborne &&
        other.jumpPurpose == JumpPurpose.rebound &&
        (ball.x - other.x).abs() <= kBbReboundReach &&
        ball.h <= other.reach;
    var winner = body;
    if (contested) {
      final sa = _reboundScore(body);
      final sb = _reboundScore(other);
      winner = sa == sb
          ? (_rng.nextBool() ? body : other)
          : (sa > sb ? body : other);
    }
    _grabBall(winner);
  }

  double _reboundScore(BasketballAthleteBody body) {
    var score =
        -2.0 * (ball.x - body.x).abs() +
        (body.spec.rebound - 70) * 0.01 +
        (body.spec.heightM - 1.95) * 0.6;
    // Apex bonus: grabbing near the top of the jump.
    final frac = body.jumpDur > 0 ? body.jumpT / body.jumpDur : 0.0;
    if ((frac - 0.5).abs() < 0.2) score += 0.3;
    if (body.spec.trait == BasketballTrait.glassCleaner) {
      score += kBbGlassCleanerBonus;
    }
    // Box-out assist: was holding stance in contact just before the jump.
    final other = bodies[1 - body.team];
    if ((other.x - body.x).abs() < kBbBodyGap + 0.15 && body.d < other.d) {
      score += kBbBoxOutBonus * 0.5;
    }
    score += (_rng.nextDouble() - 0.5) * 0.05;
    return score;
  }

  void _tryGroundPickup() {
    if (ball.phase != BallPhase.loose || ball.h > 1.2) return;
    BasketballAthleteBody? nearest;
    for (final body in bodies) {
      if (body.airborne || body.locked) continue;
      final gap = (ball.x - body.x).abs();
      if (gap <= kBbGroundPickupRange &&
          (nearest == null || gap < (ball.x - nearest.x).abs())) {
        nearest = body;
      }
    }
    if (nearest != null) _grabBall(nearest);
  }

  void _grabBall(BasketballAthleteBody body) {
    final wasShotBy = possession;
    ball.phase = BallPhase.held;
    ball.holder = body.team;
    ball.vx = 0;
    ball.vh = 0;
    ball.prediction = null;

    final offensive = body.team == wasShotBy;
    possession = body.team;
    shotClock = kBbShotClockSeconds;
    if (offensive) {
      body.putbackT = kBbPutbackWindow;
      teams[body.team].heatMeter =
          (teams[body.team].heatMeter + kBbHeatPerBoard).clamp(0.0, 1.0);
      _maybeIgniteHeat(body.team);
    }
    if (body.team == 0) _rebounds++;
    _emit(
      BasketballEvent(
        BasketballEventType.rebound,
        team: body.team,
        offensive: offensive,
      ),
    );
    // The buzzer already sounded — any recovered ball ends the half.
    if (_buzzerPending) _finishHalfNow();
  }

  // -------------------------------------------------------------------------
  // Clocks, possession, match flow
  // -------------------------------------------------------------------------

  void _stepClocks(double dt) {
    if (playPhase != PlayPhase.live) return;

    if (!overtime && !_buzzerPending) {
      halfClock -= dt;
      if (halfClock <= 0) {
        halfClock = 0;
        // Ball in the air (or loose off a live shot): buzzer-beater rule.
        if (ball.phase == BallPhase.shot || ball.phase == BallPhase.loose) {
          _buzzerPending = true;
        } else {
          _finishHalfNow();
          return;
        }
      }
    }

    if (ball.phase == BallPhase.held && !_buzzerPending) {
      shotClock -= dt;
      if (shotClock <= 0) {
        if (ball.holder == 0) _turnovers++;
        _emit(
          BasketballEvent(
            BasketballEventType.shotClockViolation,
            team: ball.holder,
          ),
        );
        _turnover(to: 1 - ball.holder, steal: false);
        _beginReset(newPossession: possession);
      }
    }
  }

  void _turnover({required int to, required bool steal}) {
    possession = to;
    shotClock = kBbShotClockSeconds;
    if (steal) {
      ball.phase = BallPhase.held;
      ball.holder = to;
    }
  }

  void _beginReset({required int newPossession, int? scoredBy}) {
    possession = newPossession;
    playPhase = PlayPhase.deadReset;
    resetT = kBbResetSeconds;
    ball.phase = BallPhase.dead;
    ball.flight = null;
    ball.prediction = null;
    for (final body in bodies) {
      body.jumpPurpose = null;
      body.putbackT = 0;
      // A scored-on reset plays a reaction beat (scorer celebrates, victim
      // slumps); both time out to idle well inside the reset walk-back.
      final react = scoredBy == null
          ? BodyState.idle
          : (body.team == scoredBy ? BodyState.celebrate : BodyState.dejected);
      if (body.body != react) body.enter(react);
    }
  }

  void _stepDeadReset(double dt) {
    resetT -= dt;
    final offense = bodies[possession];
    final defense = bodies[1 - possession];
    final k = (dt / max(0.01, resetT + dt)).clamp(0.0, 1.0);
    offense.x = _lerp(offense.x, kBbCheckSpotX, k);
    defense.x = _lerp(defense.x, kBbDefResetX, k);
    ball.x = offense.x + 0.35;
    ball.h = 1.1;
    if (resetT <= 0) {
      offense.x = kBbCheckSpotX;
      defense.x = kBbDefResetX;
      offense.facing = 1;
      defense.facing = -1;
      ball.phase = BallPhase.held;
      ball.holder = possession;
      shotClock = kBbShotClockSeconds;
      playPhase = PlayPhase.live;
    }
  }

  void _placeForPossession() {
    final offense = bodies[possession];
    final defense = bodies[1 - possession];
    offense.x = kBbCheckSpotX;
    defense.x = kBbDefResetX;
    offense.facing = 1;
    defense.facing = -1;
    offense.enter(BodyState.idle);
    defense.enter(BodyState.idle);
    ball.phase = BallPhase.held;
    ball.holder = possession;
    ball.prediction = null;
    ball.flight = null;
  }

  void _finishHalfNow({bool buzzerBeater = false}) {
    _buzzerPending = false;
    if (halfIndex == 0) {
      playPhase = PlayPhase.awaiting;
      _emit(const BasketballEvent(BasketballEventType.halfEnded, halfIndex: 0));
      return;
    }
    // End of H2: decide or go to overtime.
    if (teams[0].score != teams[1].score) {
      _endMatch(buzzer: buzzerBeater);
    } else {
      playPhase = PlayPhase.awaiting;
      _emit(
        const BasketballEvent(
          BasketballEventType.halfEnded,
          halfIndex: 1,
          needsOvertime: true,
        ),
      );
    }
  }

  void _endMatch({required bool buzzer}) {
    _matchOver = true;
    _endedOnBuzzer = buzzer;
    playPhase = PlayPhase.finished;
    ball.phase = BallPhase.dead;
    _emit(
      BasketballEvent(
        BasketballEventType.matchEnded,
        team: teams[0].score > teams[1].score ? 0 : 1,
      ),
    );
  }

  void _emit(BasketballEvent event) => _events.add(event);

  static double _lerp(double a, double b, double t) => a + (b - a) * t;
}
```

### A.3 `lib/games/basketball/basketball_ai.dart`

<sub>531 lines</sub>

```dart
/// Hoop Duel CPU controller.
///
/// The AI produces the same [BasketballIntent]s a thumb would — every rule
/// gate stays in the engine, so the AI cannot cheat structurally. It reads
/// the opponent and ball through a perception buffer delayed by a
/// difficulty-dependent latency (it never sees inputs, only observable
/// state), reads its OWN body directly (proprioception), and its timing is
/// blurred by gaussian jitter. Difficulty touches only latency, jitter,
/// decision quality and fake discipline. Pure Dart.
library;

import 'dart:collection';
import 'dart:math';

import '../../models/basketball.dart';
import 'basketball_engine.dart';
import 'basketball_tuning.dart';

class _Observation {
  _Observation({
    required this.t,
    required this.oppX,
    required this.oppBody,
    required this.oppJump,
    required this.oppJumpT,
    required this.ballPhase,
    required this.holder,
    required this.ballX,
    required this.flightT,
    required this.predictionX,
    required this.predictionT,
  });

  final double t;
  final double oppX;
  final BodyState oppBody;
  final JumpPurpose? oppJump;
  final double oppJumpT;
  final BallPhase ballPhase;
  final int holder;
  final double ballX;
  final double flightT;
  final double? predictionX;
  final double? predictionT;
}

enum _OffensePlan { bringUp, probe, createSpace, attack, pullUp }

class BasketballAI {
  BasketballAI({required this.difficulty, required int seed, this.team = 1})
    : _rng = Random(seed);

  final BasketballDifficulty difficulty;
  final Random _rng;

  /// Which side this AI drives (1 = CPU in normal play).
  final int team;

  final Queue<_Observation> _buffer = Queue();
  double _now = 0;

  _OffensePlan _plan = _OffensePlan.bringUp;
  double _replanT = 0;

  /// Non-null while the action zone is held (accumulated hold seconds).
  double? _holdT;

  /// Scheduled hold-release time for a timed shot/block release.
  double? _releaseAt;
  bool _releaseIsBlock = false;

  double _stealCooldown = 0;
  double _spinCooldown = 0;
  double _fakeBiteChance = 0;
  bool _fakeBiteInit = false;
  double _wiggleT = 0;
  int _wiggleDir = 1;

  double get _latency => switch (difficulty) {
    BasketballDifficulty.rookie => kBbAiLatencyRookie,
    BasketballDifficulty.pro => kBbAiLatencyPro,
    BasketballDifficulty.allStar => kBbAiLatencyAllStar,
  };

  double get _jitter => switch (difficulty) {
    BasketballDifficulty.rookie => kBbAiJitterRookie,
    BasketballDifficulty.pro => kBbAiJitterPro,
    BasketballDifficulty.allStar => kBbAiJitterAllStar,
  };

  double get _epsilon => switch (difficulty) {
    BasketballDifficulty.rookie => kBbAiEpsilonRookie,
    BasketballDifficulty.pro => kBbAiEpsilonPro,
    BasketballDifficulty.allStar => kBbAiEpsilonAllStar,
  };

  /// Gaussian-ish jitter (sum of two uniforms) around zero.
  double _noise() => (_rng.nextDouble() + _rng.nextDouble() - 1) * _jitter * 2;

  BasketballIntent think(BasketballEngine engine, double dt) {
    _now += dt;
    if (!_fakeBiteInit) {
      _fakeBiteInit = true;
      _fakeBiteChance = switch (difficulty) {
        BasketballDifficulty.rookie => kBbAiBiteRookie,
        BasketballDifficulty.pro => kBbAiBitePro,
        BasketballDifficulty.allStar => kBbAiBiteAllStar,
      };
    }
    _stealCooldown = max(0, _stealCooldown - dt);
    _spinCooldown = max(0, _spinCooldown - dt);
    _replanT -= dt;
    _wiggleT -= dt;

    _push(engine);
    final obs = _delayed();
    if (obs == null || engine.playPhase != PlayPhase.live) {
      return _emit(moveAxis: 0);
    }

    final me = engine.bodies[team];
    final onBall = engine.ball.holder == team;

    if (onBall) return _offense(engine, me, obs, dt);
    return _defense(engine, me, obs, dt);
  }

  void _push(BasketballEngine engine) {
    final opp = engine.bodies[1 - team];
    final ball = engine.ball;
    _buffer.addLast(
      _Observation(
        t: _now,
        oppX: opp.x,
        oppBody: opp.body,
        oppJump: opp.jumpPurpose,
        oppJumpT: opp.jumpT,
        ballPhase: ball.phase,
        holder: ball.holder,
        ballX: ball.x,
        flightT: ball.flight?.t ?? -1,
        predictionX: ball.prediction?.landX,
        predictionT: ball.prediction?.tLand,
      ),
    );
    while (_buffer.length > 2 && _buffer.first.t < _now - _latency - 0.05) {
      _buffer.removeFirst();
    }
  }

  _Observation? _delayed() {
    final cutoff = _now - _latency;
    _Observation? result;
    for (final obs in _buffer) {
      if (obs.t <= cutoff) {
        result = obs;
      } else {
        break;
      }
    }
    return result ?? (_buffer.isNotEmpty ? _buffer.first : null);
  }

  // ---------------------------------------------------------------------
  // Offense
  // ---------------------------------------------------------------------

  BasketballIntent _offense(
    BasketballEngine engine,
    BasketballAthleteBody me,
    _Observation obs,
    double dt,
  ) {
    final spec = me.spec;

    // Mid-shot: manage the timed release.
    if (me.body == BodyState.gather ||
        (me.airborne && me.jumpPurpose == JumpPurpose.shot)) {
      return _manageShotRelease(engine, me);
    }
    if (me.airborne) return _emit(moveAxis: 0);

    final gap = (obs.oppX - me.x).abs();
    final open = gap > 1.7;
    final oppStaggered = obs.oppBody == BodyState.stagger;
    final oppAirborne =
        obs.oppBody == BodyState.jump && obs.oppJump == JumpPurpose.block;
    final shotClock = engine.shotClock;
    final leading = engine.teams[team].score > engine.teams[1 - team].score;

    // Replan.
    if (_replanT <= 0) {
      _replanT = 0.35 + _rng.nextDouble() * 0.4;
      _plan = _pickPlan(
        engine,
        me,
        open: open,
        oppStaggered: oppStaggered || oppAirborne,
        shotClock: shotClock,
        leading: leading,
      );
      if (_rng.nextDouble() < _epsilon) {
        _plan = _OffensePlan
            .values[_rng.nextInt(_OffensePlan.values.length)];
      }
    }

    switch (_plan) {
      case _OffensePlan.bringUp:
        // Walk it toward the preferred range.
        final targetX = _preferredX(spec);
        if ((me.x - targetX).abs() < 0.2) {
          _plan = _OffensePlan.probe;
          return _emit(moveAxis: 0);
        }
        return _emit(moveAxis: me.x < targetX ? 0.8 : -0.8);

      case _OffensePlan.probe:
        // Leading late: burn clock before making a move (never full stall).
        if (leading && shotClock > 7 && !oppStaggered) {
          return _wiggle();
        }
        return _wiggle();

      case _OffensePlan.createSpace:
        // Step-back for a jumper (guarded), or crossover shake.
        if (gap < 1.4 && _rng.nextDouble() < 0.6) {
          _plan = _OffensePlan.pullUp;
          return _emit(swipeBack: true);
        }
        return _wiggle(fast: true);

      case _OffensePlan.attack:
        // Drive the lane; finish at the rim.
        final d = me.d;
        final wantsDunk = spec.dunk >= 72 && me.stamina >= kBbDunkStaminaGate;
        if (d <= (wantsDunk ? _dunkGateFor(spec) : kBbLayupRange)) {
          if (wantsDunk && me.body == BodyState.drive) {
            // Hold through the gate for the slam.
            return _hold(dt, moveAxis: 1);
          }
          return _tap(moveAxis: 1); // layup
        }
        // Spin past a defender planted in the driving lane (a second burst
        // mid-drive is the spin input — same thumb edge a player uses).
        final laneBlocked = obs.oppX > me.x && (obs.oppX - me.x) <= 1.2;
        if (me.body == BodyState.drive &&
            laneBlocked &&
            _spinCooldown <= 0 &&
            me.stamina >= kBbSpinStaminaCost + 10 &&
            _rng.nextDouble() > _epsilon) {
          _spinCooldown = 2.5;
          return _emit(moveAxis: 1, burst: true);
        }
        return _emit(
          moveAxis: 1,
          burst: me.body != BodyState.drive && me.stamina > 25,
        );

      case _OffensePlan.pullUp:
        // Rise for the jumper — the engine's meter does the rest.
        _scheduleShotRelease(me);
        return _hold(dt, moveAxis: 0);
    }
  }

  double _dunkGateFor(BasketballAthlete spec) =>
      spec.trait == BasketballTrait.rimPressure
      ? kBbDunkGateRimPressure
      : kBbDunkGate;

  _OffensePlan _pickPlan(
    BasketballEngine engine,
    BasketballAthleteBody me, {
    required bool open,
    required bool oppStaggered,
    required double shotClock,
    required bool leading,
  }) {
    final spec = me.spec;
    if (shotClock < 3) {
      return me.d < kBbCloseRange ? _OffensePlan.attack : _OffensePlan.pullUp;
    }
    if (oppStaggered) {
      return spec.dunk >= spec.three ? _OffensePlan.attack : _OffensePlan.pullUp;
    }
    // Archetype tendencies.
    final roll = _rng.nextDouble();
    switch (spec.archetype) {
      case BasketballArchetype.sharpshooter:
        if (open && me.d >= kBbCloseRange) return _OffensePlan.pullUp;
        return roll < 0.6 ? _OffensePlan.createSpace : _OffensePlan.probe;
      case BasketballArchetype.slasher:
        if (roll < 0.65) return _OffensePlan.attack;
        return open ? _OffensePlan.pullUp : _OffensePlan.probe;
      case BasketballArchetype.interiorPower:
        if (me.d > kBbCloseRange) return _OffensePlan.attack;
        return roll < 0.55 ? _OffensePlan.attack : _OffensePlan.pullUp;
      case BasketballArchetype.balancedGuard:
        if (open) {
          return me.d < kBbLayupRange + 1
              ? _OffensePlan.attack
              : _OffensePlan.pullUp;
        }
        return roll < 0.4
            ? _OffensePlan.attack
            : roll < 0.7
            ? _OffensePlan.createSpace
            : _OffensePlan.probe;
    }
  }

  /// Preferred shooting distance from the rim, as a court x.
  double _preferredX(BasketballAthlete spec) => switch (spec.archetype) {
    BasketballArchetype.sharpshooter => kBbRimX - kBbArcDist - 0.3,
    BasketballArchetype.slasher => kBbRimX - kBbCloseRange,
    BasketballArchetype.interiorPower => kBbRimX - kBbLayupRange - 0.8,
    BasketballArchetype.balancedGuard => kBbRimX - kBbCloseRange - 0.6,
  };

  void _scheduleShotRelease(BasketballAthleteBody me) {
    if (_releaseAt != null) return;
    final gatherDur = me.spec.trait == BasketballTrait.quickRelease
        ? kBbGatherQuickRelease
        : kBbGatherSeconds;
    final apexFrac = me.spec.trait == BasketballTrait.quickRelease
        ? kBbShotApexQuickRelease
        : kBbShotApexFrac;
    _releaseAt =
        _now + gatherDur + kBbJumpShotDuration * apexFrac + _noise();
    _releaseIsBlock = false;
  }

  BasketballIntent _manageShotRelease(
    BasketballEngine engine,
    BasketballAthleteBody me,
  ) {
    _scheduleShotRelease(me);
    if (_now >= (_releaseAt ?? _now)) {
      return _release();
    }
    return _hold(0.0001, moveAxis: 0);
  }

  // ---------------------------------------------------------------------
  // Defense
  // ---------------------------------------------------------------------

  BasketballIntent _defense(
    BasketballEngine engine,
    BasketballAthleteBody me,
    _Observation obs,
    double dt,
  ) {
    // Pending timed block release.
    if (_holdT != null && _releaseIsBlock) {
      if (_now >= (_releaseAt ?? _now)) return _release();
      return _hold(dt, moveAxis: 0);
    }

    // Loose ball / live shot → crash the boards.
    if (obs.ballPhase == BallPhase.loose || obs.ballPhase == BallPhase.shot) {
      return _crashBoards(engine, me, obs);
    }

    final oppHasBall = obs.holder == 1 - team;
    if (!oppHasBall) {
      // Transition — retreat between the (delayed) opponent and the rim.
      final target = obs.oppX + 1.1;
      return _moveToward(me, target.clamp(kBbCourtMinX, kBbRimX - 0.5));
    }

    final oppSpec = engine.bodies[1 - team].spec;
    final gap = (obs.oppX - me.x).abs();

    // Shooter rising (delayed observation): contest or block.
    final shooterUp =
        obs.oppBody == BodyState.gather ||
        (obs.oppBody == BodyState.jump && obs.oppJump == JumpPurpose.shot);
    if (shooterUp && gap <= kBbContestGap) {
      final canBlock =
          me.spec.block >= 60 && gap <= 1.4 && me.stamina > 20;
      if (canBlock && _rng.nextDouble() > _epsilon) {
        // Time the block to the shooter's apex.
        final apexIn =
            kBbJumpShotDuration * kBbShotApexFrac - obs.oppJumpT;
        _releaseAt = _now + max(0.05, apexIn) + _noise();
        _releaseIsBlock = true;
        return _hold(dt, moveAxis: 0);
      }
      return _tap(moveAxis: 0); // grounded contest
    }

    // Pump fake shown: disciplined defenders hold ground, biters jump.
    if (obs.oppBody == BodyState.fake && gap <= 1.6) {
      if (_rng.nextDouble() < _fakeBiteChance * dt * 8) {
        _fakeBiteChance *= 0.6; // it learns within the match
        _releaseAt = _now + 0.1;
        _releaseIsBlock = true;
        return _hold(dt, moveAxis: 0);
      }
    }

    // A spinning handler beats a lunge — disciplined defenders plant a set
    // stance instead (the engine absorbs a spin into a set body). Rookies
    // don't read it and keep chasing/lunging, so spins beat them clean.
    if (obs.oppBody == BodyState.spin &&
        difficulty != BasketballDifficulty.rookie) {
      final holdX = (obs.oppX + 0.5).clamp(kBbCourtMinX, kBbRimX - 0.4);
      return _moveToward(me, holdX, stance: true, dt: dt);
    }

    // Steal only when the ball is exposed (and not too often).
    final exposed =
        obs.oppBody == BodyState.crossover || obs.oppBody == BodyState.drive;
    if (exposed &&
        gap <= kBbStealReach + 0.3 &&
        _stealCooldown <= 0 &&
        me.spec.steal >= 45 &&
        _rng.nextDouble() > _epsilon) {
      _stealCooldown = switch (difficulty) {
        BasketballDifficulty.rookie => 2.2,
        BasketballDifficulty.pro => 1.6,
        BasketballDifficulty.allStar => 1.1,
      };
      return _tap(moveAxis: 0);
    }

    // Shadow: sit between the attacker and the rim; respect shooters by
    // pressing up, sag off weak shooters.
    final respect = oppSpec.three >= 75
        ? 0.9
        : oppSpec.three >= 55
        ? 1.2
        : 1.6;
    final targetX = (obs.oppX + respect).clamp(kBbCourtMinX, kBbRimX - 0.4);
    final wantStance = gap < 1.9;
    return _moveToward(me, targetX, stance: wantStance, dt: dt);
  }

  BasketballIntent _crashBoards(
    BasketballEngine engine,
    BasketballAthleteBody me,
    _Observation obs,
  ) {
    final landX = obs.predictionX;
    if (landX == null) {
      // No prediction public yet — drift toward the rim.
      return _moveToward(me, kBbRimX - 1.2);
    }
    final gap = (landX - me.x).abs();
    if (gap > 0.35) return _moveToward(me, landX);
    // Time the jump so the apex meets the drop.
    final tLand = engine.ball.prediction?.tLand ?? obs.predictionT ?? 1;
    if (!me.airborne && tLand <= kBbReboundJumpDuration * 0.5 + _noise().abs()) {
      return _tap(moveAxis: 0);
    }
    return _emit(moveAxis: 0);
  }

  // ---------------------------------------------------------------------
  // Intent plumbing (thumb-shaped edges)
  // ---------------------------------------------------------------------

  BasketballIntent _moveToward(
    BasketballAthleteBody me,
    double targetX, {
    bool stance = false,
    double dt = 0,
  }) {
    final delta = targetX - me.x;
    final axis = delta.abs() < 0.12 ? 0.0 : delta.sign;
    if (stance) return _hold(dt, moveAxis: axis * 0.8);
    return _emit(moveAxis: axis);
  }

  BasketballIntent _wiggle({bool fast = false}) {
    if (_wiggleT <= 0) {
      _wiggleT = fast ? 0.16 : 0.5 + _rng.nextDouble() * 0.5;
      _wiggleDir = -_wiggleDir;
    }
    return _emit(moveAxis: _wiggleDir * (fast ? 1.0 : 0.5));
  }

  BasketballIntent _emit({
    double moveAxis = 0,
    bool burst = false,
    bool swipeBack = false,
  }) {
    // Emitting a plain intent releases any stray hold as a no-op tap-safe
    // release only when a release was scheduled; otherwise just drop it.
    _holdT = null;
    _releaseAt = null;
    _releaseIsBlock = false;
    return BasketballIntent(
      moveAxis: moveAxis,
      burst: burst,
      swipeBack: swipeBack,
    );
  }

  BasketballIntent _tap({required double moveAxis}) {
    _holdT = null;
    _releaseAt = null;
    return BasketballIntent(
      moveAxis: moveAxis,
      actionPressed: true,
      actionReleased: true,
      heldSeconds: 0.05,
    );
  }

  BasketballIntent _hold(double dt, {required double moveAxis}) {
    final started = _holdT == null;
    _holdT = (_holdT ?? 0) + dt;
    return BasketballIntent(
      moveAxis: moveAxis,
      actionDown: true,
      actionPressed: started,
      heldSeconds: _holdT!,
    );
  }

  BasketballIntent _release() {
    final held = _holdT ?? 0.2;
    _holdT = null;
    _releaseAt = null;
    _releaseIsBlock = false;
    return BasketballIntent(actionReleased: true, heldSeconds: held);
  }
}
```

### A.4 `lib/games/basketball/basketball_game.dart`

<sub>1929 lines</sub>

```dart
/// Flame renderer + real-time loop for Hoop Duel.
///
/// Mirrors Grand Prix Dash: the 60fps simulation lives HERE — `update(dt)`
/// advances the pure [BasketballEngine] in fixed substeps, the CPU thumb is a
/// seeded [BasketballAI], and only coarse events flow up to the screen/cubit.
/// High-frequency HUD values (clocks, stamina, heat, the shot meter) are
/// [ValueNotifier]s so nothing emits bloc state per frame. All drawing is
/// procedural Canvas on `Cyber` tokens; athlete looks are the content-color
/// exception.
library;

import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart' show TextPainter;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

import '../../config/theme.dart';
import '../../data/basketball_teams.dart';
import '../../models/basketball.dart';
import 'basketball_ai.dart';
import 'basketball_engine.dart';
import 'basketball_rig.dart';
import 'basketball_tuning.dart';

/// One transient HUD banner ("PERFECT RELEASE", "ANKLE BREAKER", …).
class BasketballSting {
  const BasketballSting(this.id, this.label, this.color, {this.major = false});

  final int id;
  final String label;
  final Color color;

  /// Major stings slam bigger and hold longer.
  final bool major;
}

class BasketballGame extends FlameGame {
  BasketballGame({
    required this.config,
    required this.onEvents,
    this.reducedMotion = false,
  }) : engine = BasketballEngine(config),
       _ai = BasketballAI(
         difficulty: config.difficulty,
         seed: config.seed ^ 0xa11ce,
       );

  final BasketballMatchConfig config;

  /// Coarse per-frame event batch — the screen maps these to sounds, haptics
  /// and cubit phase changes.
  final void Function(List<BasketballEvent> events) onEvents;
  final bool reducedMotion;

  final BasketballEngine engine;
  final BasketballAI _ai;
  final Random _fxRng = Random();

  // HUD bindings — cheap 60fps reads, never bloc emissions.
  final ValueNotifier<int> scorePlayer = ValueNotifier(0);
  final ValueNotifier<int> scoreCpu = ValueNotifier(0);
  final ValueNotifier<int> halfClockTenths = ValueNotifier(
    (kBbHalfSeconds * 10).round(),
  );
  final ValueNotifier<int> shotClockSeconds = ValueNotifier(
    kBbShotClockSeconds.round(),
  );
  final ValueNotifier<double> stamina01 = ValueNotifier(1);
  final ValueNotifier<double> heatPlayer = ValueNotifier(0);
  final ValueNotifier<double> heatCpu = ValueNotifier(0);
  final ValueNotifier<bool> heatActivePlayer = ValueNotifier(false);
  final ValueNotifier<bool> heatActiveCpu = ValueNotifier(false);
  final ValueNotifier<ShotMeterView?> meter = ValueNotifier(null);
  final ValueNotifier<int> possession = ValueNotifier(0);
  final ValueNotifier<BasketballActionCue> actionCue = ValueNotifier(
    BasketballActionCue.defend,
  );
  final ValueNotifier<BasketballSting?> sting = ValueNotifier(null);

  // Input state fed by the Flutter control pads.
  double _moveAxis = 0;
  bool _actionDown = false;
  double _heldT = 0;
  bool _burstQueued = false;
  bool _pressQueued = false;
  bool _releaseQueued = false;
  double _releaseHeld = 0;
  bool _swipeQueued = false;

  bool _paused = false;
  double _accumulator = 0;
  double _slowMoT = 0;
  double _shakeT = 0;
  double _shakeMag = 0;
  double _cineT = 0;
  double _camX = kBbCheckSpotX + 2;
  Offset _shake = Offset.zero;
  int _stingId = 0;

  /// Net sway impulse, consumed by the court renderer.
  double netSway = 0;

  /// Crowd surge impulse (0..1) on big plays — lifts the bob amplitude and
  /// camera flashes beyond the sustained heat "hyped" state.
  double crowdHype = 0;

  /// Backboard score-flash: decaying timer + the scorer's livery color.
  double scoreFlashT = 0;
  Color scoreFlashColor = Cyber.cyan;

  /// Global dribble phase so both ball and player rig can sync.
  double dribblePhase = 0;

  static const double _subDt = 1 / 120;

  // -- world → screen mapping -------------------------------------------------

  double get pxPerUnit => size.x / 8.2;

  double get floorY => size.y * 0.62;

  Offset worldToScreen(double x, double h) => Offset(
    (x - _camX) * pxPerUnit + size.x / 2 + _shake.dx,
    floorY - h * pxPerUnit + _shake.dy,
  );

  @override
  Color backgroundColor() => Cyber.bg;

  /// Impact cinematic (Super Over technique): a decaying focal zoom-punch +
  /// jitter about the rim, applied to the whole canvas for the first ~0.3s
  /// after a dunk/poster/big block. Replaces the old global zoom pulse.
  @override
  void render(Canvas canvas) {
    if (_cineT > 0 && !reducedMotion) {
      final impact = _cineT / kBbCineSeconds;
      final focal = worldToScreen(kBbRimX, kBbRimHeight);
      canvas.save();
      canvas.translate(
        sin(_cineT * 47) * impact * 3,
        cos(_cineT * 53) * impact * 3,
      );
      final zoom = 1 + impact * kBbCineZoom;
      canvas.translate(focal.dx, focal.dy);
      canvas.scale(zoom, zoom);
      canvas.translate(-focal.dx, -focal.dy);
      super.render(canvas);
      canvas.restore();
      return;
    }
    super.render(canvas);
  }

  @override
  Future<void> onLoad() async {
    add(_CourtComponent()..priority = -10);
    add(_LandingMarkerComponent()..priority = -5);
    add(AthleteComponent(team: 1)..priority = 10);
    add(AthleteComponent(team: 0)..priority = 12);
    add(_BallComponent()..priority = 15);
  }

  // -- input API (called by the Flutter control pads) -------------------------

  void setMoveAxis(double axis) => _moveAxis = axis.clamp(-1, 1);

  void tapBurst() => _burstQueued = true;

  void actionPressed() {
    _actionDown = true;
    _heldT = 0;
    _pressQueued = true;
  }

  void actionReleased() {
    if (!_actionDown && !_pressQueued) return;
    _releaseQueued = true;
    _releaseHeld = _heldT;
    _actionDown = false;
  }

  void swipeBack() {
    _swipeQueued = true;
    // A step-back swipe supersedes the hold that started it.
    _actionDown = false;
    _pressQueued = false;
    _releaseQueued = false;
  }

  void cancelTouches() {
    _moveAxis = 0;
    _actionDown = false;
    _pressQueued = false;
    _releaseQueued = false;
    _swipeQueued = false;
    _burstQueued = false;
  }

  // -- match flow API (cubit-driven via the screen) ---------------------------

  void setPaused(bool paused) => _paused = paused;

  void startHalf(int index) {
    engine.startHalf(index);
    cancelTouches();
  }

  void substitutePlayer(int rosterIndex) => engine.substitute(0, rosterIndex);

  /// CPU halftime brain: bring in the freshest bench athlete when gassed.
  void cpuAutoSubstitute() {
    final sim = engine.teams[1];
    if (engine.cpuBody.stamina >= 55) return;
    var best = sim.activeIndex;
    var bestStamina = engine.cpuBody.stamina;
    for (var i = 0; i < sim.staminas.length; i++) {
      if (i == sim.activeIndex) continue;
      if (sim.staminas[i] > bestStamina + 10) {
        best = i;
        bestStamina = sim.staminas[i];
      }
    }
    if (best != sim.activeIndex) engine.substitute(1, best);
  }

  void halftimeRest() => engine.halftimeRest();

  BasketballMatchSummary summary({bool abandoned = false}) =>
      engine.summary(abandoned: abandoned);

  // -- loop --------------------------------------------------------------------

  @override
  void update(double dt) {
    super.update(dt);
    final wallDt = min(dt, 1 / 30);

    if (!_paused) {
      var simDt = wallDt;
      if (_slowMoT > 0) {
        _slowMoT = max(0, _slowMoT - wallDt);
        simDt = wallDt * 0.25;
      }
      _accumulator += simDt;
      final frameEvents = <BasketballEvent>[];
      var first = true;
      while (_accumulator >= _subDt) {
        _accumulator -= _subDt;
        frameEvents.addAll(_stepOnce(consumeEdges: first));
        first = false;
      }
      if (frameEvents.isNotEmpty) {
        _handleEvents(frameEvents);
        onEvents(frameEvents);
      }
    }

    _decayFx(wallDt);
    _syncCamera(wallDt);
    _syncNotifiers();
    dribblePhase += wallDt * 7;
  }

  List<BasketballEvent> _stepOnce({required bool consumeEdges}) {
    if (_actionDown) _heldT += _subDt;
    final intent = BasketballIntent(
      moveAxis: _moveAxis,
      burst: consumeEdges && _burstQueued,
      actionDown: _actionDown,
      actionPressed: consumeEdges && _pressQueued,
      actionReleased: consumeEdges && _releaseQueued,
      heldSeconds: consumeEdges && _releaseQueued ? _releaseHeld : _heldT,
      swipeBack: consumeEdges && _swipeQueued,
    );
    if (consumeEdges) {
      _burstQueued = false;
      _pressQueued = false;
      if (_releaseQueued) {
        _releaseQueued = false;
        _heldT = 0;
      }
      _swipeQueued = false;
    }
    final cpuIntent = _ai.think(engine, _subDt);
    return engine.step(intent, cpuIntent, _subDt);
  }

  void _decayFx(double wallDt) {
    if (_shakeT > 0) {
      _shakeT = max(0, _shakeT - wallDt);
      final k = _shakeT * _shakeMag;
      _shake = Offset(
        (_fxRng.nextDouble() - 0.5) * 2 * k,
        (_fxRng.nextDouble() - 0.5) * 2 * k,
      );
    } else {
      _shake = Offset.zero;
    }
    _cineT = max(0, _cineT - wallDt);
    crowdHype = max(0, crowdHype - wallDt * 0.8);
    scoreFlashT = max(0, scoreFlashT - wallDt);
    netSway = max(0, netSway - wallDt * 2.4);
  }

  void _syncCamera(double wallDt) {
    final ball = engine.ball;
    final mid = (engine.playerBody.x + engine.cpuBody.x) / 2;
    final target = ball.x * 0.55 + mid * 0.45;
    final halfView = size.x / 2 / pxPerUnit;
    final minCam = kBbCourtMinX - 0.4 + halfView;
    final maxCam = kBbCourtMaxX + 0.6 - halfView;
    final clamped = maxCam > minCam
        ? target.clamp(minCam, maxCam)
        : (minCam + maxCam) / 2;
    final k = 1 - exp(-6 * wallDt);
    _camX += (clamped - _camX) * k;
  }

  void _syncNotifiers() {
    scorePlayer.value = engine.teams[0].score;
    scoreCpu.value = engine.teams[1].score;
    halfClockTenths.value = (engine.halfClock * 10).ceil();
    shotClockSeconds.value = engine.shotClock.clamp(0, 99).ceil();
    stamina01.value = (engine.playerBody.stamina / 100 * 100).round() / 100;
    heatPlayer.value = (engine.teams[0].heatMeter * 100).round() / 100;
    heatCpu.value = (engine.teams[1].heatMeter * 100).round() / 100;
    heatActivePlayer.value = engine.teams[0].heatActive;
    heatActiveCpu.value = engine.teams[1].heatActive;
    meter.value = engine.meterView(0);
    possession.value = engine.ball.holder;
    actionCue.value = engine.playerActionCue;
  }

  // -- event → juice mapping ---------------------------------------------------

  void _handleEvents(List<BasketballEvent> events) {
    for (final event in events) {
      switch (event.type) {
        case BasketballEventType.basketMade:
          netSway = 1;
          _swishBurst();
          crowdHype = 1;
          scoreFlashT = kBbScoreFlashSeconds;
          scoreFlashColor = basketballTeamById(
            event.team == 0 ? config.teamId : config.cpuTeamId,
          ).primary;
          final mine = event.team == 0;
          final three = event.points == 3;
          if (event.grade == ReleaseGrade.perfect && three && mine) {
            _slowMo(0.4);
          }
          _sting(
            mine ? '+${event.points}' : 'CONCEDED +${event.points}',
            mine ? (three ? Cyber.gold : Cyber.lime) : Cyber.danger,
            major: three && mine,
          );
        case BasketballEventType.buzzerBeater:
          _slowMo(0.5);
          crowdHype = 1;
          _sting('BUZZER BEATER!', Cyber.gold, major: true);
        case BasketballEventType.dunk:
          _shakeNow(0.28, 9);
          _cineT = kBbCineSeconds;
          crowdHype = 1;
          _sting(
            event.team == 0
                ? _pick(const [
                    'THROWN DOWN!',
                    'HAMMER TIME!',
                    'WITH AUTHORITY!',
                  ])
                : 'DUNKED ON YOUR RIM',
            event.team == 0 ? Cyber.gold : Cyber.danger,
            major: event.team == 0,
          );
        case BasketballEventType.poster:
          _slowMo(0.4);
          _cineT = kBbCineSeconds;
          _sting(
            _pick(const ['POSTERIZED!', 'PUT ON A POSTER!']),
            Cyber.gold,
            major: true,
          );
        case BasketballEventType.block:
          _shakeNow(0.22, 7);
          crowdHype = 1;
          if (event.onDunk) _cineT = kBbCineSeconds;
          _sparkBurst(
            worldToScreen(engine.ball.x, engine.ball.h),
            Cyber.cyan,
            14,
          );
          _sting(
            event.team == 0
                ? _pick(const ['BLOCKED!', 'NOT TODAY!', 'SENT BACK!'])
                : _pick(const ['REJECTED!', 'SWATTED AWAY!']),
            event.team == 0 ? Cyber.cyan : Cyber.danger,
            major: event.onDunk,
          );
        case BasketballEventType.steal:
          _sting(
            event.team == 0
                ? _pick(const ['STOLEN!', 'PICKED HIS POCKET!'])
                : 'TURNOVER!',
            event.team == 0 ? Cyber.cyan : Cyber.danger,
          );
        case BasketballEventType.ankleBreaker:
          _slowMo(0.25);
          _sting(
            _pick(const ['ANKLE BREAKER!', 'SHIFTED!', 'CROSSED UP!']),
            Cyber.violet,
            major: true,
          );
        case BasketballEventType.spinMove:
          _sting(
            event.team == 0
                ? _pick(const ['SPIN CYCLE!', 'REVERSED!'])
                : 'SPUN PAST YOU',
            event.team == 0 ? Cyber.violet : Cyber.danger,
          );
        case BasketballEventType.perfectRelease:
          if (event.team == 0) {
            _sting(_pick(const ['PERFECT', 'SPLASH INCOMING']), Cyber.lime);
          }
        case BasketballEventType.heatStarted:
          _sting(
            event.team == 0 ? 'YOU\'RE ON FIRE!' : 'OPPONENT HEATING UP',
            event.team == 0 ? Cyber.gold : Cyber.danger,
            major: event.team == 0,
          );
        case BasketballEventType.shotClockViolation:
          _sting(
            event.team == 0 ? 'SHOT CLOCK!' : 'FORCED THE STOP!',
            event.team == 0 ? Cyber.danger : Cyber.cyan,
          );
        case BasketballEventType.shotMissed:
          _sparkBurst(worldToScreen(kBbRimX, kBbRimHeight), Cyber.amber, 8);
          netSway = max(netSway, 0.35);
        case BasketballEventType.rebound:
          if (event.offensive && event.team == 0) {
            _sting('OFF. BOARD — PUT IT BACK!', Cyber.cyan);
          }
        default:
          break;
      }
    }
  }

  void _slowMo(double seconds) {
    if (reducedMotion) return;
    _slowMoT = max(_slowMoT, seconds);
  }

  void _shakeNow(double seconds, double magnitude) {
    if (reducedMotion) return;
    _shakeT = seconds;
    _shakeMag = magnitude;
  }

  void _sting(String label, Color color, {bool major = false}) {
    sting.value = BasketballSting(++_stingId, label, color, major: major);
  }

  /// Render-side label variety — uses the fx RNG, never the sim RNG.
  String _pick(List<String> options) => options[_fxRng.nextInt(options.length)];

  void _swishBurst() {
    if (reducedMotion || !isLoaded) return;
    final at = worldToScreen(kBbRimX, kBbRimHeight - 0.2);
    add(
      ParticleSystemComponent(
        position: Vector2(at.dx, at.dy),
        priority: 30,
        particle: Particle.generate(
          count: 12,
          lifespan: 0.5,
          generator: (_) {
            final angle = pi / 2 + (_fxRng.nextDouble() - 0.5) * 0.9;
            final speed = 60 + _fxRng.nextDouble() * 120;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              acceleration: Vector2(0, 220),
              child: CircleParticle(
                radius: 1.2 + _fxRng.nextDouble() * 1.6,
                paint: Paint()
                  ..color = (_fxRng.nextBool() ? Cyber.gold : Cyber.cyan)
                      .withValues(alpha: 0.9),
              ),
            );
          },
        ),
      ),
    );
  }

  void _sparkBurst(Offset at, Color color, int count) {
    if (reducedMotion || !isLoaded) return;
    add(
      ParticleSystemComponent(
        position: Vector2(at.dx, at.dy),
        priority: 30,
        particle: Particle.generate(
          count: count,
          lifespan: 0.4,
          generator: (_) {
            final angle = _fxRng.nextDouble() * pi * 2;
            final speed = 50 + _fxRng.nextDouble() * 150;
            return AcceleratedParticle(
              speed: Vector2(cos(angle), sin(angle)) * speed,
              acceleration: Vector2(0, 260),
              child: CircleParticle(
                radius: 1.2 + _fxRng.nextDouble() * 1.6,
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
    scorePlayer.dispose();
    scoreCpu.dispose();
    halfClockTenths.dispose();
    shotClockSeconds.dispose();
    stamina01.dispose();
    heatPlayer.dispose();
    heatCpu.dispose();
    heatActivePlayer.dispose();
    heatActiveCpu.dispose();
    meter.dispose();
    possession.dispose();
    actionCue.dispose();
    sting.dispose();
    super.onRemove();
  }
}

// -----------------------------------------------------------------------------
// Court
// -----------------------------------------------------------------------------

/// Rooftop neon court: skyline greebles, bobbing crowd silhouettes, hardwood
/// band with cyber markings, hoop assembly with a swaying net and a diegetic
/// shot-clock box. Court markings stay high-contrast; atmosphere stays dark.
class _StarSpec {
  const _StarSpec(this.x01, this.y01, this.radius, this.alpha);

  final double x01;
  final double y01;
  final double radius;
  final double alpha;
}

class _TowerWindowSpec {
  const _TowerWindowSpec(this.x01, this.y01, this.cyan);

  final double x01;
  final double y01;
  final bool cyan;
}

class _TowerSpec {
  const _TowerSpec({
    required this.worldX,
    required this.width,
    required this.height,
    required this.near,
    required this.billboard,
    required this.billboardY01,
    required this.billboardCyan,
    required this.windows,
  });

  final double worldX;
  final double width;
  final double height;
  final bool near;
  final bool billboard;
  final double billboardY01;
  final bool billboardCyan;
  final List<_TowerWindowSpec> windows;
}

enum _RoofPropKind { acUnit, antenna, railing }

class _RoofPropSpec {
  const _RoofPropSpec({
    required this.worldX,
    required this.kind,
    required this.width,
    required this.height,
  });

  final double worldX;
  final _RoofPropKind kind;
  final double width;
  final double height;
}

class _ArenaFixtureSpec {
  const _ArenaFixtureSpec(this.x01, this.homeSide, this.drop);

  final double x01;
  final bool homeSide;
  final double drop;
}

class _CameraFlashSpec {
  const _CameraFlashSpec(this.x01, this.height, this.phase);

  final double x01;
  final double height;
  final int phase;
}

class _CourtComponent extends PositionComponent
    with HasGameReference<BasketballGame> {
  _CourtComponent()
    : _stars = _buildStars(),
      _towers = _buildTowers(),
      _roofPropSpecs = _buildRoofProps();

  double _time = 0;

  final List<_StarSpec> _stars;
  final List<_TowerSpec> _towers;
  final List<_RoofPropSpec> _roofPropSpecs;

  static const List<_ArenaFixtureSpec> _arenaFixtures = [
    _ArenaFixtureSpec(0.10, true, 0.18),
    _ArenaFixtureSpec(0.25, true, 0.10),
    _ArenaFixtureSpec(0.39, true, 0.16),
    _ArenaFixtureSpec(0.61, false, 0.16),
    _ArenaFixtureSpec(0.75, false, 0.10),
    _ArenaFixtureSpec(0.90, false, 0.18),
  ];
  static const List<_CameraFlashSpec> _cameraFlashes = [
    _CameraFlashSpec(0.12, 1.08, 0),
    _CameraFlashSpec(0.32, 0.92, 4),
    _CameraFlashSpec(0.56, 1.18, 7),
    _CameraFlashSpec(0.78, 1.02, 10),
    _CameraFlashSpec(0.92, 0.88, 13),
  ];

  final Paint _fillPaint = Paint();
  final Paint _strokePaint = Paint()..style = PaintingStyle.stroke;
  final Paint _linePaint = Paint();
  final Paint _shaderPaint = Paint();

  double _shaderWidth = -1;
  double _shaderHeight = -1;
  double _shaderFloorY = -1;
  Shader? _skyShader;
  Shader? _hazeShader;
  Shader? _floorShader;

  static List<_StarSpec> _buildStars() {
    final rng = Random(11);
    return List<_StarSpec>.unmodifiable(
      List.generate(
        24,
        (_) => _StarSpec(
          rng.nextDouble(),
          rng.nextDouble() * 0.72,
          0.4 + rng.nextDouble() * 1.1,
          0.08 + rng.nextDouble() * 0.16,
        ),
      ),
    );
  }

  static List<_TowerSpec> _buildTowers() {
    final rng = Random(7);
    return List<_TowerSpec>.unmodifiable(
      List.generate(12, (index) {
        final windows = <_TowerWindowSpec>[];
        for (var window = 0; window < 7; window++) {
          if (rng.nextDouble() < 0.44) continue;
          windows.add(
            _TowerWindowSpec(
              0.12 + rng.nextDouble() * 0.76,
              0.10 + rng.nextDouble() * 0.78,
              window.isEven,
            ),
          );
        }
        return _TowerSpec(
          worldX: index * 1.55 - 2.6,
          width: 0.78 + rng.nextDouble() * 0.85,
          height: 2.0 + rng.nextDouble() * 2.5,
          near: index.isOdd,
          billboard: rng.nextDouble() < 0.36,
          billboardY01: 0.18 + rng.nextDouble() * 0.32,
          billboardCyan: rng.nextBool(),
          windows: List.unmodifiable(windows),
        );
      }),
    );
  }

  static List<_RoofPropSpec> _buildRoofProps() {
    final rng = Random(23);
    return List<_RoofPropSpec>.unmodifiable(
      List.generate(
        13,
        (index) => _RoofPropSpec(
          worldX: index * 1.35 - 2.0,
          kind: _RoofPropKind.values[rng.nextInt(_RoofPropKind.values.length)],
          width: 0.55 + rng.nextDouble() * 0.55,
          height: 0.28 + rng.nextDouble() * 0.75,
        ),
      ),
    );
  }

  static final TextPaint _clockText = TextPaint(
    style: Cyber.label(
      13,
      color: Cyber.gold,
      weight: FontWeight.w800,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
  static final TextPaint _clockTextDanger = TextPaint(
    style: Cyber.label(
      13,
      color: Cyber.danger,
      weight: FontWeight.w800,
      letterSpacing: 0,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
  static final TextPaint _tickerStyle = TextPaint(
    style: Cyber.label(
      10,
      color: Cyber.cyan.withValues(alpha: 0.5),
      weight: FontWeight.w700,
      letterSpacing: 2,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );

  // Cached ticker layout — rebuilt only when the score/half changes.
  static final TextPaint _bannerStyle = TextPaint(
    style: Cyber.label(
      8,
      color: AppTheme.textContrast.withValues(alpha: 0.84),
      weight: FontWeight.w800,
      letterSpacing: 1.3,
    ),
  );
  static final TextPaint _goldCourtLabel = TextPaint(
    style: Cyber.label(
      8,
      color: Cyber.gold.withValues(alpha: 0.52),
      weight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
  static final TextPaint _cyanCourtLabel = TextPaint(
    style: Cyber.label(
      8,
      color: Cyber.cyan.withValues(alpha: 0.46),
      weight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
  static final TextPaint _emblemStyle = TextPaint(
    style: Cyber.label(
      8,
      color: Cyber.cyan.withValues(alpha: 0.38),
      weight: FontWeight.w900,
      letterSpacing: 1.8,
    ),
  );

  int _tickerKey = -1;
  TextPainter? _tickerPainter;
  String? _homeBannerId;
  String? _cpuBannerId;
  TextPainter? _homeBannerPainter;
  TextPainter? _cpuBannerPainter;

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    if (!gameRef.isLoaded) return;
    final size = gameRef.size;
    final floorY = gameRef.floorY;
    final px = gameRef.pxPerUnit;

    _skyline(canvas, gameRef, size, floorY, px);
    _roofProps(canvas, gameRef, size, floorY, px);
    _eventRig(canvas, gameRef, size, floorY, px);
    _crowd(canvas, gameRef, size, floorY, px);
    _floor(canvas, gameRef, size, floorY, px);
    _hoop(canvas, gameRef, px);
  }

  /// Near-rooftop props (AC units, antennas, railing) at parallax 0.3 —
  /// the depth layer between the far towers (0.15) and the crowd (1.0).
  double _decorativeTime(BasketballGame gameRef) =>
      gameRef.reducedMotion ? 0 : _time;

  Paint _solid(Color color) => _fillPaint
    ..shader = null
    ..style = PaintingStyle.fill
    ..color = color;

  Paint _outline(Color color, double width) => _strokePaint
    ..shader = null
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.butt
    ..strokeWidth = width
    ..color = color;

  Paint _line(Color color, double width, {StrokeCap cap = StrokeCap.butt}) =>
      _linePaint
        ..shader = null
        ..style = PaintingStyle.fill
        ..strokeCap = cap
        ..strokeWidth = width
        ..color = color;

  void _ensureShaders(Vector2 size, double floorY, double px) {
    if (_shaderWidth == size.x &&
        _shaderHeight == size.y &&
        _shaderFloorY == floorY) {
      return;
    }
    _shaderWidth = size.x;
    _shaderHeight = size.y;
    _shaderFloorY = floorY;
    final skyBottom = max(1.0, floorY - 2.0 * px);
    _skyShader = Gradient.linear(
      Offset.zero,
      Offset(0, skyBottom),
      [Cyber.arenaSky, Cyber.arenaVioletHorizon, Cyber.bg],
      const [0, 0.62, 1],
    );
    _hazeShader = Gradient.linear(
      Offset(0, skyBottom - px * 0.9),
      Offset(0, skyBottom + px * 0.5),
      [
        Cyber.arenaHorizon.withValues(alpha: 0),
        Cyber.cyan.withValues(alpha: 0.055),
        Cyber.arenaHorizon.withValues(alpha: 0.28),
      ],
      const [0, 0.56, 1],
    );
    _floorShader = Gradient.linear(Offset(0, floorY), Offset(0, size.y), [
      Cyber.arenaVioletHorizon,
      Cyber.arenaFloor,
    ]);
  }

  void _roofProps(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double floorY,
    double px,
  ) {
    final baseY = floorY - 1.62 * px;
    for (final spec in _roofPropSpecs) {
      final at = gameRef.worldToScreen(
        spec.worldX * 0.7 + gameRef._camX * 0.3,
        0,
      );
      final width = spec.width * px;
      final height = spec.height * px;
      switch (spec.kind) {
        case _RoofPropKind.acUnit:
          final unit = Rect.fromLTWH(
            at.dx - width / 2,
            baseY - min(height, 0.42 * px),
            width,
            min(height, 0.42 * px),
          );
          canvas.drawRect(unit, _solid(Cyber.bg));
          canvas.drawRect(
            unit.deflate(2),
            _outline(Cyber.line.withValues(alpha: 0.28), 1),
          );
          canvas.drawCircle(
            unit.center,
            unit.height * 0.24,
            _outline(Cyber.line.withValues(alpha: 0.34), 1),
          );
        case _RoofPropKind.antenna:
          canvas.drawLine(
            Offset(at.dx, baseY),
            Offset(at.dx, baseY - height),
            _line(Cyber.borderMuted, 2),
          );
          canvas.drawLine(
            Offset(at.dx - 0.1 * px, baseY - height * 0.62),
            Offset(at.dx + 0.1 * px, baseY - height * 0.62),
            _line(Cyber.borderMuted, 2),
          );
          canvas.drawCircle(
            Offset(at.dx, baseY - height),
            2,
            _solid(Cyber.magenta.withValues(alpha: 0.32)),
          );
        case _RoofPropKind.railing:
          canvas.drawLine(
            Offset(at.dx - width / 2, baseY - 0.16 * px),
            Offset(at.dx + width / 2, baseY - 0.16 * px),
            _line(Cyber.borderMuted, 2),
          );
          for (var p = 0; p <= 3; p++) {
            final postX = at.dx - width / 2 + width * p / 3;
            canvas.drawLine(
              Offset(postX, baseY),
              Offset(postX, baseY - 0.16 * px),
              _line(Cyber.borderMuted, 2),
            );
          }
      }
    }
  }

  void _skyline(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double floorY,
    double px,
  ) {
    _ensureShaders(size, floorY, px);
    final skyBottom = floorY - 2.0 * px;
    _shaderPaint
      ..style = PaintingStyle.fill
      ..shader = _skyShader;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, floorY), _shaderPaint);

    final decorativeT = _decorativeTime(gameRef);
    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      final twinkle = gameRef.reducedMotion
          ? 1.0
          : 0.82 + sin(decorativeT * 1.7 + i * 1.9) * 0.18;
      canvas.drawCircle(
        Offset(star.x01 * size.x, star.y01 * max(0, skyBottom)),
        star.radius,
        _solid(AppTheme.textContrast.withValues(alpha: star.alpha * twinkle)),
      );
    }

    final moonC = Offset(
      size.x * 0.78 - gameRef._camX * px * 0.05,
      size.y * 0.14,
    );
    canvas.drawCircle(
      moonC,
      px * 0.30,
      _solid(AppTheme.textContrast.withValues(alpha: 0.42)),
    );
    canvas.drawCircle(
      moonC + Offset(-px * 0.11, -px * 0.05),
      px * 0.27,
      _solid(Cyber.arenaSky),
    );

    final blimpW = px * 1.4;
    final blimpTravel = size.x + blimpW * 2;
    final blimpX = gameRef.reducedMotion
        ? size.x * 0.24
        : (decorativeT * 8) % blimpTravel - blimpW;
    final blimpY = size.y * 0.09;
    final hull = Rect.fromCenter(
      center: Offset(blimpX, blimpY),
      width: blimpW,
      height: px * 0.4,
    );
    canvas.drawOval(hull, _solid(Cyber.card));
    final fin = Path()
      ..moveTo(blimpX - blimpW * 0.42, blimpY)
      ..lineTo(blimpX - blimpW * 0.62, blimpY - px * 0.22)
      ..lineTo(blimpX - blimpW * 0.62, blimpY + px * 0.22)
      ..close();
    canvas.drawPath(fin, _solid(Cyber.card));
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(blimpX, blimpY),
        width: blimpW * 0.6,
        height: px * 0.16,
      ),
      _outline(
        basketballTeamById(
          gameRef.config.teamId,
        ).primary.withValues(alpha: 0.28),
        1.4,
      ),
    );

    for (var i = 0; i < 12; i++) {
      final gridY = floorY - px * 2.3 - i * px * 0.45;
      canvas.drawLine(
        Offset(0, gridY),
        Offset(size.x, gridY),
        _line(Cyber.magenta.withValues(alpha: 0.035), 1),
      );
    }

    _drawTowerLayer(canvas, gameRef, floorY, px, near: false);

    _shaderPaint
      ..style = PaintingStyle.fill
      ..shader = _hazeShader;
    canvas.drawRect(
      Rect.fromLTWH(0, max(0, skyBottom - px * 0.9), size.x, px * 1.45),
      _shaderPaint,
    );

    _drawTowerLayer(canvas, gameRef, floorY, px, near: true);
  }

  void _drawTowerLayer(
    Canvas canvas,
    BasketballGame gameRef,
    double floorY,
    double px, {
    required bool near,
  }) {
    final baseY = floorY - (near ? 1.78 : 1.95) * px;
    for (final tower in _towers) {
      if (tower.near != near) continue;
      final parallax = near ? 0.86 : 0.68;
      final centerX =
          gameRef.size.x / 2 + (tower.worldX - gameRef._camX) * px * parallax;
      final width = tower.width * px * (near ? 1 : 0.82);
      final height = tower.height * px * (near ? 1 : 0.78);
      final rect = Rect.fromLTWH(
        centerX - width / 2,
        baseY - height,
        width,
        height,
      );
      canvas.drawRect(rect, _solid(near ? Cyber.bg2 : Cyber.arenaHorizon));

      if (tower.billboard) {
        final board = Rect.fromLTWH(
          rect.left - 2,
          rect.top + rect.height * tower.billboardY01,
          rect.width + 4,
          min(px * 0.5, rect.height * 0.24),
        );
        final color = tower.billboardCyan ? Cyber.cyan : Cyber.magenta;
        canvas.drawRect(
          board,
          _outline(color.withValues(alpha: near ? 0.19 : 0.10), 1.4),
        );
      }

      for (final window in tower.windows) {
        canvas.drawRect(
          Rect.fromLTWH(
            rect.left + rect.width * window.x01,
            rect.top + rect.height * window.y01,
            near ? 3 : 2,
            near ? 5 : 4,
          ),
          _solid(
            (window.cyan ? Cyber.cyan : Cyber.magenta).withValues(
              alpha: near ? 0.23 : 0.12,
            ),
          ),
        );
      }
    }
  }

  void _eventRig(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double floorY,
    double px,
  ) {
    final home = basketballTeamById(gameRef.config.teamId);
    final cpu = basketballTeamById(gameRef.config.cpuTeamId);

    // Stepped grandstand slabs create a readable event bowl behind the player
    // silhouettes without competing with the live court markings.
    for (var tier = 0; tier < 3; tier++) {
      final inset = size.x * (0.015 + tier * 0.025);
      final top = floorY - (1.72 - tier * 0.32) * px;
      final bottom = top + px * 0.38;
      final step = Path()
        ..moveTo(inset + px * 0.18, top)
        ..lineTo(size.x - inset, top)
        ..lineTo(size.x - inset - px * 0.18, bottom)
        ..lineTo(inset, bottom)
        ..close();
      canvas.drawPath(
        step,
        _solid(
          (tier.isEven ? Cyber.bg2 : Cyber.panel).withValues(
            alpha: tier == 2 ? 0.72 : 0.55,
          ),
        ),
      );
      canvas.drawLine(
        Offset(inset + px * 0.18, top),
        Offset(size.x - inset, top),
        _line(Cyber.line.withValues(alpha: 0.22), 1),
      );
    }

    final trussTop = floorY - 3.05 * px;
    final trussBase = floorY - 0.72 * px;
    final left = size.x * 0.045;
    final right = size.x * 0.955;
    canvas.drawLine(
      Offset(left, trussTop),
      Offset(right, trussTop),
      _line(Cyber.borderMuted.withValues(alpha: 0.72), 2),
    );
    for (final x in [left, right]) {
      canvas.drawLine(
        Offset(x, trussTop),
        Offset(x, trussBase),
        _line(Cyber.borderMuted.withValues(alpha: 0.72), 2),
      );
      for (var segment = 0; segment < 4; segment++) {
        final y0 = trussTop + (trussBase - trussTop) * segment / 4;
        final y1 = trussTop + (trussBase - trussTop) * (segment + 1) / 4;
        final inward = x == left ? px * 0.17 : -px * 0.17;
        canvas.drawLine(
          Offset(x, y0),
          Offset(x + inward, y1),
          _line(Cyber.line.withValues(alpha: 0.34), 1),
        );
        canvas.drawLine(
          Offset(x + inward, y0),
          Offset(x, y1),
          _line(Cyber.line.withValues(alpha: 0.34), 1),
        );
      }
    }

    for (final fixture in _arenaFixtures) {
      final x = size.x * fixture.x01;
      final team = fixture.homeSide ? home : cpu;
      final fixtureRect = Rect.fromCenter(
        center: Offset(x, trussTop + fixture.drop * px),
        width: px * 0.22,
        height: px * 0.16,
      );
      canvas.drawRect(fixtureRect, _solid(Cyber.panel));
      canvas.drawLine(
        Offset(x, trussTop),
        Offset(x, fixtureRect.top),
        _line(Cyber.line.withValues(alpha: 0.38), 1),
      );
      canvas.drawLine(
        Offset(fixtureRect.left + 2, fixtureRect.bottom),
        Offset(fixtureRect.right - 2, fixtureRect.bottom),
        _line(team.primary.withValues(alpha: 0.42), 2),
      );
    }

    _ensureBannerPainters(home.id, cpu.id);
    final bannerY = floorY - 2.35 * px;
    _drawTeamBanner(
      canvas,
      center: Offset(size.x * 0.21, bannerY),
      width: px * 1.55,
      height: px * 0.48,
      color: home.primary,
      painter: _homeBannerPainter!,
      mirrored: false,
    );
    _drawTeamBanner(
      canvas,
      center: Offset(size.x * 0.79, bannerY),
      width: px * 1.55,
      height: px * 0.48,
      color: cpu.primary,
      painter: _cpuBannerPainter!,
      mirrored: true,
    );
  }

  void _ensureBannerPainters(String homeId, String cpuId) {
    if (_homeBannerId != homeId) {
      _homeBannerId = homeId;
      _homeBannerPainter = _bannerStyle.toTextPainter(
        'YOU·${_arenaTeamCode(homeId)}',
      );
    }
    if (_cpuBannerId != cpuId) {
      _cpuBannerId = cpuId;
      _cpuBannerPainter = _bannerStyle.toTextPainter(
        '${_arenaTeamCode(cpuId)}·CPU',
      );
    }
  }

  String _arenaTeamCode(String id) =>
      id.substring(0, min(3, id.length)).toUpperCase();

  void _drawTeamBanner(
    Canvas canvas, {
    required Offset center,
    required double width,
    required double height,
    required Color color,
    required TextPainter painter,
    required bool mirrored,
  }) {
    final rect = Rect.fromCenter(center: center, width: width, height: height);
    final cut = min(8.0, height * 0.28);
    final banner = Path()
      ..moveTo(rect.left + (mirrored ? 0 : cut), rect.top)
      ..lineTo(rect.right - (mirrored ? cut : 0), rect.top)
      ..lineTo(rect.right, rect.top + (mirrored ? cut : 0))
      ..lineTo(rect.right - (mirrored ? 0 : cut), rect.bottom)
      ..lineTo(rect.left + (mirrored ? cut : 0), rect.bottom)
      ..lineTo(rect.left, rect.bottom - (mirrored ? 0 : cut))
      ..close();
    canvas.drawPath(banner, _solid(Color.lerp(Cyber.panel, color, 0.22)!));
    canvas.drawPath(
      banner,
      _outline(Color.lerp(Cyber.line, color, 0.58)!, 1.2),
    );
    canvas
      ..save()
      ..clipPath(banner);
    painter.paint(
      canvas,
      Offset(
        rect.center.dx - painter.width / 2,
        rect.center.dy - painter.height / 2,
      ),
    );
    canvas.restore();
  }

  void _crowd(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double floorY,
    double px,
  ) {
    final engine = gameRef.engine;
    final hyped = engine.teams[0].heatActive || engine.teams[1].heatActive;
    // Sustained heat sets the floor; big-play hype surges on top (the crowd
    // "stands up" for a beat, then settles).
    final amp = gameRef.reducedMotion
        ? 0.0
        : (hyped ? 0.08 : 0.03) + gameRef.crowdHype * 0.06;
    final freq = hyped ? 7.0 : 2.4 + gameRef.crowdHype * 3;
    final decorativeT = _decorativeTime(gameRef);
    final userLivery = basketballTeamById(gameRef.config.teamId);
    final cpuLivery = basketballTeamById(gameRef.config.cpuTeamId);
    for (final layer in const [0, 1]) {
      final baseY = floorY - (1.35 - layer * 0.55) * px;
      final base = layer == 0 ? Cyber.bg : Cyber.card;
      final path = Path()..moveTo(0, baseY + px);
      final pockets = <Rect>[];
      final pocketColors = <Color>[];
      var col = 0;
      for (var sx = -20.0; sx <= size.x + 20; sx += px * 0.5) {
        // Stable per-column head-height variance (seedless hash — no
        // per-frame Random allocations).
        final hash = sin(sx * 12.9898 + layer * 78.233) * 43758.5453;
        final variance = (hash - hash.floorToDouble()) * 0.16;
        final head = 0.16 + variance + layer * 0.1;
        final bob = sin(decorativeT * freq + sx * 0.11 + layer * 2) * amp * px;
        path.lineTo(sx, baseY - head * px + bob);
        path.lineTo(sx + px * 0.25, baseY - (0.05 + layer * 0.1) * px + bob);
        // Team-color fan pockets, alternating supporters.
        if (col % 6 == 0 && layer == 1) {
          pockets.add(
            Rect.fromLTWH(sx, baseY - head * px + bob, px * 0.4, px * 0.16),
          );
          pocketColors.add(
            Color.lerp(
              base,
              (col ~/ 6).isEven ? userLivery.primary : cpuLivery.primary,
              0.3,
            )!,
          );
        }
        col++;
      }
      path
        ..lineTo(size.x + 20, baseY + px)
        ..close();
      canvas.drawPath(path, _solid(base));
      for (var i = 0; i < pockets.length; i++) {
        canvas.drawRect(pockets[i], _solid(pocketColors[i]));
      }
    }
    // Camera flashes when hyped or surging on a big play.
    if (!gameRef.reducedMotion && (hyped || gameRef.crowdHype > 0.3)) {
      final beat = (decorativeT * 12).floor();
      for (final flash in _cameraFlashes) {
        if ((beat + flash.phase) % 17 != 0) continue;
        canvas.drawCircle(
          Offset(flash.x01 * size.x, floorY - px * flash.height),
          px * 0.055,
          _solid(
            AppTheme.textContrast.withValues(
              alpha: 0.28 + gameRef.crowdHype * 0.42,
            ),
          ),
        );
      }
    }

    // Hoarding rail between crowd and court, with a scrolling LED ticker.
    final railY = floorY - 0.78 * px;
    final railH = 0.78 * px;
    canvas.drawRect(
      Rect.fromLTWH(0, railY, size.x, railH),
      _solid(Cyber.arenaFloor),
    );
    _ticker(canvas, gameRef, size, railY, railH);
    // The rail edge lifts briefly when a basket flashes the boards.
    final edgeLift = gameRef.scoreFlashT > 0
        ? gameRef.scoreFlashT / kBbScoreFlashSeconds
        : 0.0;
    canvas.drawLine(
      Offset(0, railY),
      Offset(size.x, railY),
      _line(
        edgeLift > 0
            ? gameRef.scoreFlashColor.withValues(alpha: 0.25 + edgeLift * 0.5)
            : Cyber.cyan.withValues(alpha: 0.25),
        2,
      ),
    );

    // Calm team-color LED segments brand the venue; only the scoring response
    // brightens them, keeping persistent chrome free of glow.
    final ledY = railY + railH - 3;
    const ledCount = 12;
    final gap = 3.0;
    final ledW = (size.x - gap * (ledCount + 1)) / ledCount;
    for (var index = 0; index < ledCount; index++) {
      final teamColor = index < ledCount ~/ 2
          ? userLivery.primary
          : cpuLivery.primary;
      final activeColor = edgeLift > 0 ? gameRef.scoreFlashColor : teamColor;
      canvas.drawRect(
        Rect.fromLTWH(gap + index * (ledW + gap), ledY, ledW, 1.5),
        _solid(activeColor.withValues(alpha: 0.22 + edgeLift * 0.42)),
      );
    }
  }

  /// Scrolling LED score/flavor line on the hoarding rail. The laid-out text
  /// is cached and only rebuilt when the score changes.
  void _ticker(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double railY,
    double railH,
  ) {
    final engine = gameRef.engine;
    final key =
        engine.teams[0].score * 1000 +
        engine.teams[1].score +
        engine.halfIndex * 1000000;
    if (key != _tickerKey || _tickerPainter == null) {
      _tickerKey = key;
      const flavors = [
        'HOOP DUEL LIVE',
        'ROOFTOP CIRCUIT',
        'NEON COURT NIGHTS',
        'HEAT CHECK SEASON',
      ];
      final text =
          'YOU ${engine.teams[0].score} — ${engine.teams[1].score} CPU'
          '  •  ${flavors[key % flavors.length]}  •  ';
      _tickerPainter = _tickerStyle.toTextPainter(text);
    }
    final tp = _tickerPainter!;
    if (tp.width <= 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, railY, size.x, railH));
    final textY = railY + (railH - tp.height) / 2;
    var dx = gameRef.reducedMotion
        ? 8.0
        : ((_decorativeTime(gameRef) * -40) % tp.width) - tp.width;
    while (dx < size.x) {
      tp.paint(canvas, Offset(dx, textY));
      dx += tp.width;
    }
    canvas.restore();
  }

  void _floor(
    Canvas canvas,
    BasketballGame gameRef,
    Vector2 size,
    double floorY,
    double px,
  ) {
    _ensureShaders(size, floorY, px);
    final floorDepth = size.y - floorY;
    final floorRect = Rect.fromLTWH(0, floorY, size.x, floorDepth);
    _shaderPaint
      ..style = PaintingStyle.fill
      ..shader = _floorShader;
    canvas.drawRect(floorRect, _shaderPaint);

    // Perspective depth bands stay flat and quiet; the live court lines keep
    // the visual hierarchy.
    for (var band = 1; band <= 5; band++) {
      final depth = pow(band / 5, 1.55).toDouble();
      final y = floorY + floorDepth * depth;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.x, y),
        _line(
          (band.isEven ? Cyber.cyan : Cyber.line).withValues(
            alpha: band.isEven ? 0.035 : 0.12,
          ),
          band == 5 ? 1.5 : 1,
        ),
      );
    }

    final camLeft = gameRef._camX - size.x / 2 / px - 1;
    final camRight = gameRef._camX + size.x / 2 / px + 1;
    final vanishX = size.x * 0.52;
    for (var wx = camLeft.floorToDouble(); wx <= camRight; wx += 0.62) {
      final top = gameRef.worldToScreen(wx, 0);
      final bottomX = vanishX + (top.dx - vanishX) * 1.22;
      canvas.drawLine(
        top,
        Offset(bottomX, size.y),
        _line(Cyber.line.withValues(alpha: 0.30), 1.2),
      );
    }

    final arcAt = gameRef.worldToScreen(BasketballEngine.arcLineX, 0);
    canvas.drawRect(
      Rect.fromLTWH(0, floorY, max(0, arcAt.dx), floorDepth),
      _solid(Cyber.gold.withValues(alpha: 0.045)),
    );
    canvas.drawLine(
      arcAt,
      Offset(arcAt.dx - px * 0.4, size.y),
      _line(Cyber.gold.withValues(alpha: 0.62), 2.4),
    );

    final paintFrom = gameRef.worldToScreen(kBbRimX - 2.6, 0);
    final paintTo = gameRef.worldToScreen(kBbBackboardX + 0.4, 0);
    canvas.drawRect(
      Rect.fromLTRB(paintFrom.dx, floorY, paintTo.dx, size.y),
      _solid(Cyber.cyan.withValues(alpha: 0.075)),
    );
    canvas.drawLine(
      paintFrom,
      Offset(paintFrom.dx - px * 0.3, size.y),
      _line(Cyber.cyan.withValues(alpha: 0.48), 2),
    );

    final restrictedAt = gameRef.worldToScreen(kBbRimX - 1.0, 0);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(restrictedAt.dx, size.y),
        width: px * 2,
        height: px * 1.2,
      ),
      pi,
      pi,
      false,
      _outline(Cyber.cyan.withValues(alpha: 0.36), 1.5),
    );

    final labelY = floorY + min(floorDepth * 0.24, px * 0.58);
    _goldCourtLabel.render(
      canvas,
      '3PT',
      Vector2(arcAt.dx - px * 0.58, labelY),
      anchor: Anchor.center,
    );
    _cyanCourtLabel.render(
      canvas,
      'PAINT',
      Vector2((paintFrom.dx + paintTo.dx) / 2, labelY),
      anchor: Anchor.center,
    );

    final emblemAt = gameRef.worldToScreen(
      (kBbCourtMinX + kBbCourtMaxX) / 2,
      0,
    );
    final emblemCenter = Offset(emblemAt.dx, floorY + floorDepth * 0.38);
    final emblemRect = Rect.fromCenter(
      center: emblemCenter,
      width: px * 2.8,
      height: px * 0.82,
    );
    canvas.drawOval(
      emblemRect,
      _outline(Cyber.cyan.withValues(alpha: 0.24), 1.5),
    );
    canvas.drawArc(
      emblemRect.deflate(4),
      pi * 0.1,
      pi * 0.72,
      false,
      _outline(Cyber.gold.withValues(alpha: 0.34), 1.5),
    );
    _emblemStyle.render(
      canvas,
      'HOOP // DUEL',
      Vector2(emblemCenter.dx, emblemCenter.dy),
      anchor: Anchor.center,
    );

    final flash = gameRef.scoreFlashT > 0
        ? gameRef.scoreFlashT / kBbScoreFlashSeconds
        : 0.0;
    if (flash > 0) {
      final responseY = floorY + floorDepth * 0.72;
      canvas.drawRect(
        Rect.fromLTWH(0, responseY, size.x, max(2, floorDepth * 0.06)),
        _solid(gameRef.scoreFlashColor.withValues(alpha: 0.08 * flash)),
      );
      canvas.drawLine(
        Offset(0, responseY),
        Offset(size.x, responseY),
        _line(gameRef.scoreFlashColor.withValues(alpha: 0.42 * flash), 2),
      );
    }

    // A calm near-edge bevel gives the roof deck physical thickness.
    final bevelH = min(px * 0.24, floorDepth * 0.14);
    final bevelTop = size.y - bevelH;
    final bevel = Path()
      ..moveTo(0, bevelTop + 4)
      ..lineTo(px * 0.24, bevelTop)
      ..lineTo(size.x, bevelTop)
      ..lineTo(size.x, size.y)
      ..lineTo(0, size.y)
      ..close();
    canvas.drawPath(bevel, _solid(Cyber.bg2.withValues(alpha: 0.92)));
    canvas.drawLine(
      Offset(px * 0.24, bevelTop),
      Offset(size.x, bevelTop),
      _line(Cyber.line.withValues(alpha: 0.42), 1.5),
    );

    canvas.drawLine(
      Offset(0, floorY),
      Offset(size.x, floorY),
      _line(Cyber.cyan.withValues(alpha: 0.28), 2),
    );
  }

  void _hoop(Canvas canvas, BasketballGame gameRef, double px) {
    final rim = gameRef.worldToScreen(kBbRimX, kBbRimHeight);
    final boardBase = gameRef.worldToScreen(kBbBackboardX, kBbRimHeight - 0.2);
    final boardTop = gameRef.worldToScreen(kBbBackboardX, kBbRimHeight + 0.8);
    final poleBase = gameRef.worldToScreen(kBbBackboardX + 0.35, 0);

    // Reflection ghost on the polished hardwood (pole + board), drawn
    // before the assembly so it always sits underneath.
    if (!gameRef.reducedMotion) {
      final floorLine = poleBase.dy;
      final poleTopY = boardTop.dy - px * 0.2;
      canvas.drawLine(
        Offset(poleBase.dx, floorLine),
        Offset(
          poleBase.dx,
          floorLine + (floorLine - poleTopY) * kBbReflectSquash,
        ),
        Paint()
          ..color = const Color(0xff232b3d).withValues(alpha: 0.35)
          ..strokeWidth = px * 0.14
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawRect(
        Rect.fromLTRB(
          boardBase.dx - px * 0.06,
          floorLine + (floorLine - boardBase.dy) * kBbReflectSquash,
          boardBase.dx + px * 0.06,
          floorLine + (floorLine - boardTop.dy) * kBbReflectSquash,
        ),
        Paint()..color = Cyber.cyan.withValues(alpha: 0.06),
      );
    }

    // Pole + arm.
    final polePaint = Paint()
      ..color = const Color(0xff232b3d)
      ..strokeWidth = px * 0.14
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      poleBase,
      Offset(poleBase.dx, boardTop.dy - px * 0.2),
      polePaint,
    );
    canvas.drawLine(
      Offset(poleBase.dx, boardTop.dy - px * 0.1),
      Offset(boardBase.dx, boardBase.dy - px * 0.2),
      polePaint,
    );

    // Backboard glass.
    final board = Rect.fromLTRB(
      boardBase.dx - px * 0.06,
      boardTop.dy,
      boardBase.dx + px * 0.06,
      boardBase.dy,
    );
    canvas.drawRect(board, Paint()..color = const Color(0x14e8ecf2));
    canvas.drawRect(
      board,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Cyber.cyan.withValues(alpha: 0.5),
    );
    // Score flash: the board's LED frame pulses in the scorer's livery —
    // event-driven and decaying, not an always-on glow.
    if (gameRef.scoreFlashT > 0) {
      final flash = gameRef.scoreFlashT / kBbScoreFlashSeconds;
      canvas.drawRect(
        board.inflate(2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..color = gameRef.scoreFlashColor.withValues(alpha: 0.7 * flash),
      );
    }

    // Rim (side view) + hook to the board.
    final rimPaint = Paint()
      ..color = Cyber.amber
      ..strokeWidth = px * 0.07
      ..strokeCap = StrokeCap.round;
    final rimFront = Offset(rim.dx - 0.23 * px, rim.dy);
    final rimBack = Offset(rim.dx + 0.23 * px, rim.dy);
    canvas.drawLine(rimFront, rimBack, rimPaint);
    canvas.drawLine(
      rimBack,
      Offset(boardBase.dx, rim.dy - px * 0.05),
      rimPaint,
    );

    // Net: swaying segments.
    final sway = sin(_time * 13) * gameRef.netSway * px * 0.12;
    final netPaint = Paint()
      ..color = const Color(0x8fe8ecf2)
      ..strokeWidth = 1.4;
    for (var i = 0; i <= 4; i++) {
      final k = i / 4;
      final top = Offset.lerp(rimFront, rimBack, k)!;
      final bottom = Offset(
        rim.dx + (k - 0.5) * 0.18 * px + sway,
        rim.dy + 0.42 * px,
      );
      canvas.drawLine(top, bottom, netPaint);
    }
    canvas.drawLine(
      Offset(rim.dx - 0.11 * px + sway, rim.dy + 0.28 * px),
      Offset(rim.dx + 0.11 * px + sway, rim.dy + 0.28 * px),
      netPaint,
    );

    // Diegetic shot clock above the board.
    final clock = gameRef.engine.shotClock.clamp(0, 99).ceil();
    final boxCenter = Offset(boardBase.dx, boardTop.dy - px * 0.42);
    final boxRect = Rect.fromCenter(
      center: boxCenter,
      width: px * 0.62,
      height: px * 0.5,
    );
    canvas.drawRect(boxRect, Paint()..color = const Color(0xff070b14));
    canvas.drawRect(
      boxRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = (clock <= 3 ? Cyber.danger : Cyber.gold).withValues(
          alpha: 0.6,
        ),
    );
    (clock <= 3 ? _clockTextDanger : _clockText).render(
      canvas,
      '$clock',
      Vector2(boxCenter.dx, boxCenter.dy),
      anchor: Anchor.center,
    );
  }
}

// -----------------------------------------------------------------------------
// Ball
// -----------------------------------------------------------------------------

class _BallComponent extends PositionComponent
    with HasGameReference<BasketballGame> {
  final Queue<Offset> _trail = Queue();

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    final engine = gameRef.engine;
    final ball = engine.ball;
    final px = gameRef.pxPerUnit;

    final world = _visualPosition(engine, ball);
    final at = gameRef.worldToScreen(world.dx, world.dy);
    final r = 0.14 * px;

    // Heat trail while flying.
    final shooterHeat =
        (ball.phase == BallPhase.shot || ball.phase == BallPhase.loose) &&
        (engine.teams[0].heatActive || engine.teams[1].heatActive);
    if (shooterHeat) {
      _trail.addLast(at);
      while (_trail.length > 7) {
        _trail.removeFirst();
      }
      var i = 0;
      for (final p in _trail) {
        final k = i / _trail.length;
        canvas.drawCircle(
          p,
          r * (0.4 + k * 0.5),
          Paint()..color = Cyber.gold.withValues(alpha: 0.10 + k * 0.12),
        );
        i++;
      }
    } else {
      _trail.clear();
    }

    // Ball shadow.
    final ground = gameRef.worldToScreen(world.dx, 0);
    canvas.drawOval(
      Rect.fromCenter(
        center: ground,
        width: r * 1.6 * (1 - (world.dy / 6).clamp(0.0, 0.7)),
        height: r * 0.5,
      ),
      Paint()..color = const Color(0x4d000000),
    );

    // Reflection ghost in the hardwood polish.
    if (!gameRef.reducedMotion && world.dy < 4) {
      canvas.drawCircle(
        Offset(at.dx, ground.dy + world.dy * px * kBbReflectSquash),
        r * 0.9,
        Paint()..color = Cyber.amber.withValues(alpha: kBbReflectAlpha),
      );
    }

    canvas.drawCircle(at, r, Paint()..color = Cyber.amber);
    final seam = Paint()
      ..color = const Color(0xff5b2c07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, r * 0.14);
    final spin = ball.phase == BallPhase.held
        ? gameRef.dribblePhase * 0.4
        : world.dx * 0.8;
    canvas.drawArc(
      Rect.fromCircle(center: at, radius: r * 0.92),
      spin,
      pi,
      false,
      seam,
    );
    canvas.drawLine(
      Offset(at.dx - r * 0.9, at.dy),
      Offset(at.dx + r * 0.9, at.dy),
      seam..strokeWidth = max(0.8, r * 0.1),
    );
  }

  /// Where to draw the ball: engine position in flight/loose, stylized
  /// dribble/hands while held (the engine's held position is coarse).
  Offset _visualPosition(BasketballEngine engine, BasketballBall ball) {
    if (ball.phase != BallPhase.held || ball.holder < 0) {
      return Offset(ball.x, ball.h);
    }
    final holder = engine.bodies[ball.holder];
    final fx = holder.x + holder.facing * 0.32;
    switch (holder.body) {
      case BodyState.gather:
        return Offset(fx, holder.spec.heightM * 0.62);
      case BodyState.jump:
        final frac = holder.jumpDur > 0
            ? (holder.jumpT / holder.jumpDur).clamp(0.0, 1.0)
            : 0.0;
        final overhead =
            holder.spec.heightM * (0.62 + frac * 0.5) + holder.jumpHeight;
        return Offset(fx + holder.facing * 0.1, overhead);
      case BodyState.fake:
        final k = (holder.stateT / kBbFakeSeconds).clamp(0.0, 1.0);
        final up = sin(min(1.0, k * 2) * pi) * 0.5;
        return Offset(fx, holder.spec.heightM * 0.62 + up);
      default:
        // Dribble bounce; tighter + lower when protecting the ball.
        final guarded =
            (engine.bodies[1 - ball.holder].x - holder.x).abs() <=
            kBbGuardedGap;
        final height = guarded ? 0.5 : 0.75;
        final bounce =
            sin(game.dribblePhase * (guarded ? 1.6 : 1.0)).abs() * height;
        return Offset(fx, 0.14 + bounce);
    }
  }
}

// -----------------------------------------------------------------------------
// Rebound landing marker
// -----------------------------------------------------------------------------

class _LandingMarkerComponent extends PositionComponent
    with HasGameReference<BasketballGame> {
  double _time = 0;
  final Paint _markerPaint = Paint()..style = PaintingStyle.stroke;
  final Paint _fillPaint = Paint();

  static final TextPaint _labelStyle = TextPaint(
    style: Cyber.label(
      7,
      color: Cyber.gold.withValues(alpha: 0.82),
      weight: FontWeight.w900,
      letterSpacing: 1.2,
    ),
  );

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    final prediction = gameRef.engine.ball.prediction;
    if (prediction == null) return;
    final px = gameRef.pxPerUnit;
    final at = gameRef.worldToScreen(prediction.landX, 0);
    final pulse = gameRef.reducedMotion ? 1.0 : 0.88 + sin(_time * 9) * 0.12;
    final outer = Rect.fromCenter(
      center: at,
      width: px * 1.02 * pulse,
      height: px * 0.34 * pulse,
    );
    canvas.drawOval(
      outer,
      _markerPaint
        ..strokeWidth = 2
        ..color = Cyber.gold.withValues(alpha: 0.78),
    );
    canvas.drawOval(
      outer.deflate(px * 0.10),
      _markerPaint
        ..strokeWidth = 1
        ..color = Cyber.gold.withValues(alpha: 0.34),
    );

    final tick = px * 0.15;
    final tickPaint = _markerPaint
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square
      ..color = Cyber.cyan.withValues(alpha: 0.66);
    canvas.drawLine(
      Offset(at.dx - outer.width * 0.62, at.dy),
      Offset(at.dx - outer.width * 0.62 + tick, at.dy),
      tickPaint,
    );
    canvas.drawLine(
      Offset(at.dx + outer.width * 0.62 - tick, at.dy),
      Offset(at.dx + outer.width * 0.62, at.dy),
      tickPaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: at,
        width: max(3, px * 0.07),
        height: max(2, px * 0.025),
      ),
      _fillPaint..color = Cyber.gold.withValues(alpha: 0.86),
    );

    final chevronY = at.dy - px * 0.38;
    final chevron = Path()
      ..moveTo(at.dx - px * 0.12, chevronY)
      ..lineTo(at.dx, chevronY + px * 0.09)
      ..lineTo(at.dx + px * 0.12, chevronY);
    canvas.drawPath(
      chevron,
      _markerPaint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Cyber.gold.withValues(alpha: 0.72),
    );
    _labelStyle.render(
      canvas,
      'REBOUND',
      Vector2(at.dx, chevronY - px * 0.10),
      anchor: Anchor.bottomCenter,
    );
  }
}
```

### A.5 `lib/games/basketball/basketball_rig.dart`

<sub>918 lines</sub>

```dart
/// Procedural athlete rendering for Hoop Duel.
///
/// No sprite assets: each athlete is a code-drawn rig (limbs as thick
/// round-cap strokes, IK-lite elbows/knees) posed parametrically from the
/// engine's body state, in the app's stylized-silhouette tradition
/// (Football Chess tokens / Grand Prix cars). Team + look colors are content
/// colors; everything else pulls from `Cyber` tokens.
///
/// The pose type and the drawing primitives are shared with the other rigs —
/// see `games/rig/athlete_rig.dart`. This file only holds what is basketball:
/// the pose-per-[BodyState] switch and the jersey/hardwood draw pass.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

import '../../config/theme.dart';
import '../../data/basketball_athletes.dart';
import '../../data/basketball_teams.dart';
import '../rig/athlete_rig.dart';
import 'basketball_engine.dart';
import 'basketball_game.dart';
import 'basketball_tuning.dart';

/// Hoop Duel's pose is the shared [RigPose] — hip height, torso lean, foot
/// targets (relative to the point under the hip) and hand targets (relative to
/// the shoulder).
typedef BasketballPose = RigPose;

/// Computes the pose for the current engine body state. All motion in here is
/// a pure function of state + timers, so rendering stays deterministic.
BasketballPose poseFor(
  BasketballAthleteBody body,
  double runPhase, {
  double? dribbleBallY,
}) {
  final pose = _basePoseFor(body, runPhase);
  if (dribbleBallY != null && _isDribblingState(body.body)) {
    final scaleM = body.spec.heightM / 1.95;
    final shoulderY = pose.hip * scaleM + 0.52 * scaleM;
    final dy = (shoulderY - dribbleBallY) / scaleM;
    final dx = (0.32 - sin(pose.lean) * 0.3) / scaleM;
    return BasketballPose(
      hip: pose.hip,
      lean: pose.lean,
      footNear: pose.footNear,
      footFar: pose.footFar,
      handNear: Offset(dx, dy),
      handFar: pose.handFar,
      headBob: pose.headBob,
    );
  }
  return pose;
}

bool _isDribblingState(BodyState state) {
  switch (state) {
    case BodyState.idle:
    case BodyState.run:
    case BodyState.drive:
    case BodyState.crossover:
    case BodyState.stepback:
    case BodyState.stance:
    case BodyState.stagger:
      return true;
    default:
      return false;
  }
}

BasketballPose _basePoseFor(BasketballAthleteBody body, double runPhase) {
  final t = body.stateT;
  final jumpFrac = body.jumpDur > 0
      ? (body.jumpT / body.jumpDur).clamp(0.0, 1.0)
      : 0.0;
  final tired = body.stamina01 < 0.25;

  switch (body.body) {
    case BodyState.idle:
      final bob = sin(t * (tired ? 4.5 : 2.2)) * 0.02;
      return BasketballPose(
        hip: (tired ? 0.86 : 0.94) + bob,
        lean: tired ? 0.38 : 0.06,
        footNear: const Offset(0.16, 0),
        footFar: const Offset(-0.16, 0),
        handNear: tired ? const Offset(0.18, -0.62) : const Offset(0.1, -0.52),
        handFar: tired ? const Offset(-0.1, -0.62) : const Offset(-0.12, -0.5),
        headBob: bob,
      );
    case BodyState.run:
    case BodyState.drive:
      final speedy = body.body == BodyState.drive;
      final swing = sin(runPhase);
      final amp = speedy ? 0.42 : 0.3;
      return BasketballPose(
        hip: 0.9 + sin(runPhase * 2).abs() * 0.03,
        lean: speedy ? 0.34 : 0.18,
        footNear: Offset(swing * amp, max(0.0, sin(runPhase)) * 0.14),
        footFar: Offset(-swing * amp, max(0.0, -sin(runPhase)) * 0.14),
        handNear: Offset(-swing * 0.24 + 0.08, -0.42),
        handFar: Offset(swing * 0.24 - 0.08, -0.44),
      );
    case BodyState.crossover:
      final k = (t / 0.25).clamp(0.0, 1.0);
      return BasketballPose(
        hip: 0.78 - sin(k * pi) * 0.08,
        lean: 0.3,
        footNear: Offset(0.34 - k * 0.5, 0),
        footFar: const Offset(-0.3, 0),
        handNear: Offset(0.22 - k * 0.44, -0.16),
        handFar: const Offset(-0.2, -0.4),
      );
    case BodyState.stepback:
      return BasketballPose(
        hip: 0.86,
        lean: -0.22,
        footNear: const Offset(0.28, 0.06),
        footFar: const Offset(-0.24, 0),
        handNear: const Offset(0.1, -0.3),
        handFar: const Offset(-0.14, -0.34),
      );
    case BodyState.gather:
      return BasketballPose(
        hip: 0.78,
        lean: 0.12,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: const Offset(0.24, -0.28),
        handFar: const Offset(0.18, -0.32),
      );
    case BodyState.jump:
      return _jumpPose(body, jumpFrac);
    case BodyState.land:
      final k = (t / 0.18).clamp(0.0, 1.0);
      return BasketballPose(
        hip: 0.74 + k * 0.2,
        lean: 0.18 - k * 0.12,
        footNear: const Offset(0.2, 0),
        footFar: const Offset(-0.2, 0),
        handNear: const Offset(0.16, -0.2),
        handFar: const Offset(-0.16, -0.2),
      );
    case BodyState.stance:
      final sway = sin(t * 3) * 0.02;
      return BasketballPose(
        hip: 0.76 + sway,
        lean: 0.14,
        footNear: const Offset(0.34, 0),
        footFar: const Offset(-0.34, 0),
        handNear: const Offset(0.42, -0.18),
        handFar: const Offset(-0.4, -0.16),
      );
    case BodyState.lunge:
      final k = (t / 0.35).clamp(0.0, 1.0);
      return BasketballPose(
        hip: 0.7 - sin(k * pi) * 0.06,
        lean: 0.5,
        footNear: Offset(0.4 + k * 0.2, 0),
        footFar: const Offset(-0.34, 0),
        handNear: Offset(0.5 + sin(k * pi) * 0.16, -0.06),
        handFar: const Offset(-0.2, -0.3),
      );
    case BodyState.contest:
      return BasketballPose(
        hip: 0.92,
        lean: 0.04,
        footNear: const Offset(0.2, 0),
        footFar: const Offset(-0.2, 0),
        handNear: const Offset(0.1, -1.06),
        handFar: const Offset(-0.06, -1.02),
      );
    case BodyState.fake:
      final k = (t / 0.35).clamp(0.0, 1.0);
      final up = sin(min(1.0, k * 2) * pi) * 0.5;
      return BasketballPose(
        hip: 0.84 + up * 0.06,
        lean: 0.08,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: Offset(0.2, -0.3 - up),
        handFar: Offset(0.14, -0.34 - up),
      );
    case BodyState.stagger:
      final wob = sin(t * 16) * (1 - (t / 0.6).clamp(0.0, 1.0)) * 0.2;
      return BasketballPose(
        hip: 0.8,
        lean: -0.4 + wob,
        footNear: const Offset(0.36, 0),
        footFar: const Offset(-0.1, 0),
        handNear: Offset(0.3 + wob, -0.7),
        handFar: Offset(-0.34 - wob, -0.6),
        headBob: wob * 0.4,
      );
    case BodyState.celebrate:
      // Fist pump: arm punches the sky on a springy hop.
      final pump = sin(t * 10).abs();
      return BasketballPose(
        hip: 0.94 + pump * 0.05,
        lean: -0.12,
        footNear: const Offset(0.18, 0),
        footFar: const Offset(-0.18, 0),
        handNear: Offset(0.1, -1.08 - pump * 0.08),
        handFar: const Offset(-0.2, -0.55),
        headBob: pump * 0.03,
      );
    case BodyState.dejected:
      // Head down, shoulders slumped, hands hanging low.
      final sag = min(1.0, t * 3);
      return BasketballPose(
        hip: 0.9 - sag * 0.04,
        lean: 0.3 * sag,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: Offset(0.08, -0.22 - sag * 0.02),
        handFar: const Offset(-0.1, -0.22),
        headBob: -0.05 * sag,
      );
    case BodyState.spin:
      // Sweeping low turn: the lean whips front-to-back through the spin
      // (reads as a body rotation side-on), ball arm wrapped in tight.
      final k = (t / kBbSpinDuration).clamp(0.0, 1.0);
      final whirl = sin(k * pi);
      return BasketballPose(
        hip: 0.72 + whirl * 0.06,
        lean: 0.45 - k * 0.9,
        footNear: Offset(0.3 - k * 0.5, 0.06 * whirl),
        footFar: Offset(-0.2 + k * 0.42, 0),
        handNear: Offset(-0.28 * whirl + 0.06, -0.5),
        handFar: Offset(0.34 * whirl, -0.66),
        headBob: whirl * 0.02,
      );
  }
}

BasketballPose _jumpPose(BasketballAthleteBody body, double frac) {
  final tuck = sin(frac * pi);
  switch (body.jumpPurpose) {
    case JumpPurpose.shot:
      // Ball overhead, wrist follow-through past the apex.
      final release = (frac - 0.4).clamp(0.0, 1.0) * 1.6;
      return BasketballPose(
        hip: 0.98,
        lean: 0.02,
        footNear: Offset(0.08, 0.2 * tuck),
        footFar: Offset(-0.1, 0.26 * tuck),
        handNear: Offset(0.18 + release * 0.12, -1.0 - release * 0.06),
        handFar: const Offset(0.06, -0.9),
      );
    case JumpPurpose.layup:
    case JumpPurpose.putback:
      return BasketballPose(
        hip: 0.98,
        lean: 0.12,
        footNear: Offset(0.16, 0.42 * tuck), // knee drive
        footFar: Offset(-0.12, 0.1 * tuck),
        handNear: Offset(0.3, -1.02 - tuck * 0.1),
        handFar: const Offset(-0.08, -0.5),
      );
    case JumpPurpose.dunk:
      // Windup behind the head → two-hand slam in front.
      final slam = (frac - 0.35).clamp(0.0, 1.0) / 0.65;
      final reach = -0.6 + slam * 1.1;
      return BasketballPose(
        hip: 0.98,
        lean: 0.2 + slam * 0.18,
        footNear: Offset(0.2, 0.4 * tuck),
        footFar: Offset(-0.16, 0.34 * tuck),
        handNear: Offset(reach * 0.5 + 0.3, -1.04 + slam * 0.2),
        handFar: Offset(reach * 0.5 + 0.14, -1.0 + slam * 0.2),
      );
    case JumpPurpose.block:
      return BasketballPose(
        hip: 0.98,
        lean: 0.04,
        footNear: Offset(0.1, 0.28 * tuck),
        footFar: Offset(-0.12, 0.2 * tuck),
        handNear: const Offset(0.16, -1.14),
        handFar: const Offset(-0.14, -0.4),
      );
    case JumpPurpose.rebound:
      return BasketballPose(
        hip: 0.98,
        lean: 0,
        footNear: Offset(0.1, 0.3 * tuck),
        footFar: Offset(-0.1, 0.3 * tuck),
        handNear: const Offset(0.14, -1.1),
        handFar: const Offset(-0.12, -1.08),
      );
    case null:
      return BasketballPose(
        hip: 0.96,
        footNear: const Offset(0.14, 0.1),
        footFar: const Offset(-0.14, 0.1),
        handNear: const Offset(0.12, -0.5),
        handFar: const Offset(-0.12, -0.5),
      );
  }
}

/// Renders one athlete from the live engine body. The ball-handler's heat
/// aura is the only glow on the court (THE GLOW RULE).
class AthleteComponent extends PositionComponent
    with HasGameReference<BasketballGame> {
  AthleteComponent({required this.team});

  final int team;
  double _runPhase = 0;
  double _lastX = 0;

  BasketballAthleteBody get body => game.engine.bodies[team];

  @override
  void update(double dt) {
    super.update(dt);
    final x = body.x;
    _runPhase += (x - _lastX).abs() * 6.5 + dt * 0.8;
    _lastX = x;
  }

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    final engine = gameRef.engine;
    final b = body;
    final look = basketballLookFor(b.spec.id);
    final px = gameRef.pxPerUnit;
    final heightPx = b.spec.heightM * px;
    final ground = gameRef.worldToScreen(b.x, 0);
    final lift = b.jumpHeight * px;

    canvas.save();
    canvas.translate(ground.dx, ground.dy - lift);
    // Squash & stretch around the feet anchor.
    final squash = _squash(b);
    canvas.scale(squash.dx * b.facing.toDouble(), squash.dy);

    // Ground shadow (before body, unscaled-ish).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, lift),
        width: heightPx * 0.42 * (1 - b.jumpHeight * 0.4),
        height: heightPx * 0.07,
      ),
      Paint()..color = Cyber.bg.withValues(alpha: 0.75),
    );
    _drawMovementTicks(
      canvas,
      b,
      heightPx,
      lift,
      reducedMotion: gameRef.reducedMotion,
    );

    // Heat aura — the one glow on court.
    if (engine.teams[team].heatActive &&
        engine.ball.phase == BallPhase.held &&
        engine.ball.holder == team) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -heightPx * 0.45),
          width: heightPx * 0.8,
          height: heightPx * 1.1,
        ),
        Paint()
          ..color = look.accent.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    double? dribbleBallY;
    if (engine.ball.holder == team && engine.ball.phase == BallPhase.held) {
      final guarded = (engine.bodies[1 - team].x - b.x).abs() <= kBbGuardedGap;
      final height = guarded ? 0.5 : 0.75;
      final bounce =
          sin(gameRef.dribblePhase * (guarded ? 1.6 : 1.0)).abs() * height;
      dribbleBallY = 0.14 + bounce + 0.12; // target near the top of the ball
    }

    final pose = poseFor(b, _runPhase, dribbleBallY: dribbleBallY);
    final livery = basketballTeamById(
      team == 0 ? gameRef.config.teamId : gameRef.config.cpuTeamId,
    );

    // Hardwood reflection: the same rig mirrored about the ground line,
    // squashed and faded. Skipped under reduced motion (also the perf guard).
    if (!gameRef.reducedMotion) {
      canvas.save();
      canvas.translate(0, lift * 2);
      canvas.scale(1, -kBbReflectSquash);
      final bounds = Rect.fromLTWH(
        -heightPx,
        -heightPx * 1.3,
        heightPx * 2,
        heightPx * 1.6,
      );
      canvas.saveLayer(
        bounds,
        Paint()..color = Cyber.textPrimary.withValues(alpha: kBbReflectAlpha),
      );
      drawBasketballRig(
        canvas,
        b,
        pose,
        look,
        px,
        primary: livery.primary,
        secondary: livery.secondary,
        accent: livery.accent,
        reflectionPass: true,
      );
      canvas.restore();
      canvas.restore();
    }

    drawBasketballRig(
      canvas,
      b,
      pose,
      look,
      px,
      primary: livery.primary,
      secondary: livery.secondary,
      accent: livery.accent,
    );
    if (team == 0) {
      _drawYouMarker(canvas, b, heightPx);
    }
    canvas.restore();
  }

  Offset _squash(BasketballAthleteBody b) {
    if (b.body == BodyState.jump && b.jumpT < 0.08) {
      return const Offset(0.94, 1.08);
    }
    if (b.body == BodyState.land && b.stateT < 0.1) {
      return const Offset(1.07, 0.92);
    }
    return const Offset(1, 1);
  }

  void _drawMovementTicks(
    Canvas canvas,
    BasketballAthleteBody body,
    double heightPx,
    double floorOffset, {
    required bool reducedMotion,
  }) {
    final y = floorOffset - heightPx * 0.015;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square
      ..strokeWidth = max(1.0, heightPx * 0.012);

    switch (body.body) {
      case BodyState.drive:
        final pulse = reducedMotion
            ? 0.24
            : 0.18 + sin(_runPhase * 2).abs() * 0.12;
        paint.color = Cyber.cyan.withValues(alpha: pulse);
        for (var i = 0; i < 2; i++) {
          final x = -heightPx * (0.18 + i * 0.11);
          canvas.drawLine(
            Offset(x, y - heightPx * (0.015 + i * 0.018)),
            Offset(x - heightPx * 0.09, y),
            paint,
          );
        }
        break;
      case BodyState.stepback:
        final fade = (1 - body.stateT / 0.42).clamp(0.0, 1.0);
        paint.color = Cyber.cyan.withValues(alpha: 0.42 * fade);
        for (var i = 0; i < 3; i++) {
          final x = heightPx * (0.12 + i * 0.1);
          canvas.drawLine(Offset(x, y), Offset(x + heightPx * 0.065, y), paint);
        }
        break;
      case BodyState.land:
        final fade = (1 - body.stateT / 0.18).clamp(0.0, 1.0);
        paint.color = Cyber.cyan.withValues(alpha: 0.48 * fade);
        canvas.drawLine(
          Offset(-heightPx * 0.28, y),
          Offset(-heightPx * 0.16, y - heightPx * 0.055),
          paint,
        );
        canvas.drawLine(
          Offset(heightPx * 0.28, y),
          Offset(heightPx * 0.16, y - heightPx * 0.055),
          paint,
        );
        break;
      default:
        break;
    }
  }

  void _drawYouMarker(
    Canvas canvas,
    BasketballAthleteBody body,
    double heightPx,
  ) {
    final width = heightPx * 0.34;
    final height = heightPx * 0.14;
    final top = -heightPx * 1.18;
    final path = Path()
      ..moveTo(-width * 0.5, top)
      ..lineTo(width * 0.38, top)
      ..lineTo(width * 0.5, top + height * 0.28)
      ..lineTo(width * 0.5, top + height)
      ..lineTo(-width * 0.38, top + height)
      ..lineTo(-width * 0.5, top + height * 0.72)
      ..close();
    canvas.drawPath(path, Paint()..color = Cyber.cyan);

    canvas.save();
    canvas.translate(0, top + height * 0.5);
    canvas.scale(body.facing.toDouble(), 1);
    rigNumberPaint(
      Cyber.bg,
      heightPx * 0.075,
    ).render(canvas, 'YOU', Vector2.zero(), anchor: Anchor.center);
    canvas.restore();

    canvas.drawPath(
      Path()
        ..moveTo(-height * 0.12, top + height)
        ..lineTo(height * 0.12, top + height)
        ..lineTo(0, top + height * 1.3)
        ..close(),
      Paint()..color = Cyber.cyan,
    );
  }
}

// -----------------------------------------------------------------------------
// Rig drawing — top-level so extra passes (floor reflections) can reuse it.
// -----------------------------------------------------------------------------

/// Draws one athlete rig in the given jersey livery colors. Called by
/// [AthleteComponent] for the main pass and again (flipped + faded) for the
/// hardwood reflection.
void drawBasketballRig(
  Canvas canvas,
  BasketballAthleteBody b,
  BasketballPose pose,
  BasketballAthleteLook look,
  double px, {
  required Color primary,
  required Color secondary,
  required Color accent,
  bool reflectionPass = false,
}) {
  final primaryColor = primary;
  final secondaryColor = secondary;
  final accentColor = accent;

  final h = b.spec.heightM;
  final scaleM = h / 1.95; // proportions relative to a 1.95m frame
  final frame = look.buildScale;

  // Anchor points (athlete-local px, y up → canvas y down).
  Offset pt(double xM, double yM) => Offset(xM * px, -yM * px);

  final hip = pt(0, pose.hip * scaleM);
  final shoulderY = pose.hip * scaleM + 0.52 * scaleM;
  final shoulder = pt(sin(pose.lean) * 0.3, shoulderY);
  final headCenter = pt(
    sin(pose.lean) * 0.42,
    shoulderY + 0.24 * scaleM + pose.headBob,
  );
  final footFar = pt(pose.footFar.dx * scaleM, pose.footFar.dy * scaleM);
  final footNear = pt(pose.footNear.dx * scaleM, pose.footNear.dy * scaleM);
  final handFar = shoulder + pose.handFar * (scaleM * px);
  final handNear = shoulder + pose.handNear * (scaleM * px);

  final strokeBody = Paint()
    ..color = primaryColor
    ..strokeWidth = px * 0.19 * frame
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final strokeSkin = Paint()
    ..color = look.skin
    ..strokeWidth = px * 0.095 * frame
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final strokeSkinFar = Paint()
    ..color = rigDarken(look.skin, 0.25)
    ..strokeWidth = px * 0.095 * frame
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final strokeShorts = Paint()
    ..color = rigDarken(primaryColor, 0.15)
    ..strokeWidth = px * 0.15 * frame
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  final headR = 0.155 * scaleM * px;
  if (!reflectionPass) {
    _drawRigUnderStroke(
      canvas,
      hip: hip,
      shoulder: shoulder,
      headCenter: headCenter,
      headRadius: headR,
      footFar: footFar,
      footNear: footNear,
      handFar: handFar,
      handNear: handNear,
      frame: frame,
      px: px,
    );
  }

  // Legs (far first, darker).
  rigLimb(
    canvas,
    hip,
    footFar,
    bend: -0.22 * px,
    upper: strokeShorts,
    lower: strokeSkinFar,
    shoe: rigDarken(accentColor, 0.2),
    shoeAccent: rigDarken(secondaryColor, 0.2),
    px: px,
  );
  rigLimb(
    canvas,
    hip,
    footNear,
    bend: -0.26 * px,
    upper: strokeShorts,
    lower: strokeSkin,
    lowerOverlay:
        !reflectionPass && look.gear == BasketballAthleteGear.kneeSleeve
        ? secondaryColor
        : null,
    shoe: accentColor,
    shoeAccent: secondaryColor,
    px: px,
  );

  // Far arm behind the torso. Hand offsets use canvas convention already
  // (negative dy = up), so they add to the shoulder directly.
  rigLimb(
    canvas,
    shoulder,
    handFar,
    bend: 0.2 * px,
    upper: strokeSkinFar,
    lower: strokeSkinFar,
    px: px,
  );

  // Torso (jersey) + trim + volume shading.
  canvas.drawLine(hip, shoulder, strokeBody);

  if (!reflectionPass) {
    // Torso shading.
    canvas.drawLine(
      Offset(hip.dx + px * 0.04, hip.dy),
      Offset(shoulder.dx + px * 0.04, shoulder.dy),
      Paint()
        ..color = Cyber.bg.withValues(alpha: 0.3)
        ..strokeWidth = px * 0.05
        ..strokeCap = StrokeCap.round,
    );

    // Jersey stripes.
    canvas.drawLine(
      Offset.lerp(hip, shoulder, 0.1)!,
      Offset.lerp(hip, shoulder, 0.9)!,
      Paint()
        ..color = secondaryColor
        ..strokeWidth = px * 0.04
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset.lerp(hip, shoulder, 0.15)!,
      Offset.lerp(hip, shoulder, 0.4)!,
      Paint()
        ..color = accentColor
        ..strokeWidth = px * 0.05
        ..strokeCap = StrokeCap.round,
    );
  }

  // Shoulder bar — widens the silhouette into a T at the top of the jersey.
  canvas.drawLine(
    shoulder + Offset(-0.15 * scaleM * px * frame, 0),
    shoulder + Offset(0.15 * scaleM * px * frame, 0),
    Paint()
      ..color = primaryColor
      ..strokeWidth = px * 0.15 * frame
      ..strokeCap = StrokeCap.round,
  );

  // Jersey number — the surrounding canvas is X-flipped by facing, so
  // un-flip locally to keep the digits readable in both directions.
  if (!reflectionPass) {
    final numberPos = Offset.lerp(hip, shoulder, 0.55)!;
    canvas.save();
    canvas.translate(numberPos.dx, numberPos.dy);
    canvas.scale(b.facing.toDouble(), 1);
    rigNumberPaint(accentColor, px * 0.2).render(
      canvas,
      '${jerseyNumberFor(b.spec.id)}',
      Vector2.zero(),
      anchor: Anchor.center,
    );
    canvas.restore();
  }

  // Head + hair + headband.
  canvas.drawCircle(headCenter, headR, Paint()..color = look.skin);

  if (reflectionPass) {
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headR * look.hairScale),
      pi,
      pi,
      false,
      Paint()
        ..color = look.hair
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.48,
    );
  } else {
    // Head shading.
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headR),
      -pi / 2,
      pi,
      false,
      Paint()
        ..color = Cyber.bg.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.3,
    );

    _drawBasketballHair(canvas, headCenter, headR, look);
    if (look.gear == BasketballAthleteGear.headband) {
      canvas.drawLine(
        headCenter + Offset(-headR, headR * 0.08),
        headCenter + Offset(headR, headR * 0.08),
        Paint()
          ..color = secondaryColor
          ..strokeWidth = headR * 0.25
          ..strokeCap = StrokeCap.square,
      );
    }

    // Visor face hint — a lit line across the front of the face. Flat color,
    // no blur: a lit line is not a glow (THE GLOW RULE stays intact).
    canvas.drawLine(
      headCenter + Offset(headR * 0.15, headR * 0.42),
      headCenter + Offset(headR * 0.95, headR * 0.42),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.85)
        ..strokeWidth = headR * 0.2
        ..strokeCap = StrokeCap.round,
    );
  }

  // Near arm in front.
  rigLimb(
    canvas,
    shoulder,
    handNear,
    bend: 0.24 * px,
    upper: strokeSkin,
    lower: strokeSkin,
    lowerOverlay:
        !reflectionPass && look.gear == BasketballAthleteGear.shootingSleeve
        ? secondaryColor
        : null,
    px: px,
  );
}

void _drawRigUnderStroke(
  Canvas canvas, {
  required Offset hip,
  required Offset shoulder,
  required Offset headCenter,
  required double headRadius,
  required Offset footFar,
  required Offset footNear,
  required Offset handFar,
  required Offset handNear,
  required double frame,
  required double px,
}) {
  final outline = Paint()
    ..color = Cyber.bg.withValues(alpha: 0.96)
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  void limb(Offset from, Offset to, double bend, double width) {
    final mid = Offset.lerp(from, to, 0.5)!;
    final direction = to - from;
    final length = direction.distance;
    final normal = length > 0.001
        ? Offset(-direction.dy / length, direction.dx / length)
        : const Offset(1, 0);
    final joint = mid + normal * bend;
    outline.strokeWidth = width + px * 0.055;
    canvas.drawLine(from, joint, outline);
    canvas.drawLine(joint, to, outline);
    canvas.drawCircle(
      to,
      outline.strokeWidth * 0.5,
      Paint()..color = outline.color,
    );
  }

  limb(hip, footFar, -0.22 * px, px * 0.15 * frame);
  limb(hip, footNear, -0.26 * px, px * 0.15 * frame);
  limb(shoulder, handFar, 0.2 * px, px * 0.095 * frame);
  limb(shoulder, handNear, 0.24 * px, px * 0.095 * frame);

  outline.strokeWidth = px * (0.19 * frame + 0.055);
  canvas.drawLine(hip, shoulder, outline);
  canvas.drawCircle(
    headCenter,
    headRadius + px * 0.028,
    Paint()..color = outline.color,
  );
}

void _drawBasketballHair(
  Canvas canvas,
  Offset center,
  double headRadius,
  BasketballAthleteLook look,
) {
  final radius = headRadius * look.hairScale;
  final hairPaint = Paint()
    ..color = look.hair
    ..strokeCap = StrokeCap.round;

  switch (look.hairStyle) {
    case BasketballHairStyle.closeCrop:
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        pi,
        pi,
        false,
        hairPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.38,
      );
      break;
    case BasketballHairStyle.fade:
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 1.02),
        pi * 1.08,
        pi * 0.84,
        false,
        hairPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.5,
      );
      canvas.drawLine(
        center + Offset(-radius * 0.92, -radius * 0.12),
        center + Offset(-radius * 0.82, radius * 0.28),
        hairPaint..strokeWidth = radius * 0.18,
      );
      break;
    case BasketballHairStyle.curls:
      hairPaint.style = PaintingStyle.fill;
      for (var i = 0; i < 5; i++) {
        final angle = pi + i * pi / 4;
        canvas.drawCircle(
          center +
              Offset(cos(angle), sin(angle)) * (radius * 0.86) +
              Offset(0, -radius * 0.08),
          radius * 0.31,
          hairPaint,
        );
      }
      break;
    case BasketballHairStyle.highTop:
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - radius * 0.82, center.dy - radius * 0.55)
          ..lineTo(center.dx - radius * 0.62, center.dy - radius * 1.28)
          ..lineTo(center.dx + radius * 0.58, center.dy - radius * 1.28)
          ..lineTo(center.dx + radius * 0.82, center.dy - radius * 0.55)
          ..close(),
        hairPaint..style = PaintingStyle.fill,
      );
      break;
    case BasketballHairStyle.twists:
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        pi,
        pi,
        false,
        hairPaint
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.34,
      );
      for (final x in const [-0.55, 0.0, 0.55]) {
        canvas.drawLine(
          center + Offset(radius * x, -radius * 0.72),
          center + Offset(radius * x, -radius * 1.18),
          hairPaint..strokeWidth = radius * 0.18,
        );
        canvas.drawCircle(
          center + Offset(radius * x, -radius * 1.22),
          radius * 0.12,
          hairPaint..style = PaintingStyle.fill,
        );
      }
      break;
  }
}
```

### A.6 `lib/games/rig/athlete_rig.dart`

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

### A.7 `lib/models/basketball.dart`

<sub>387 lines</sub>

```dart
/// Domain model for Hoop Duel — the 2D side-view 1v1 arcade basketball duel.
///
/// Pure data: enums, athlete specs, match config/summary, and the persisted
/// lifetime record. No Flutter/Flame imports so the engine and tests stay pure.
library;

enum BasketballArchetype { balancedGuard, sharpshooter, slasher, interiorPower }

enum BasketballCardRole { guard, wing, big }

/// One signature trait per athlete — small, readable effects.
enum BasketballTrait {
  /// Faster gather + earlier release apex, slightly wider perfect window.
  quickRelease,

  /// No distance falloff beyond the three-point arc.
  deepRange,

  /// Wider dunk gate and halved layup contest.
  rimPressure,

  /// Rebound contest bonus and stronger box-out.
  glassCleaner,
}

enum BasketballDifficulty { rookie, pro, allStar }

/// Where a shot resolves from, by distance to the rim at release.
enum ShotZone { dunk, layup, close, mid, three }

/// Release timing grade against the shot meter.
enum ReleaseGrade { perfect, good, early, late }

String basketballArchetypeLabel(BasketballArchetype archetype) =>
    switch (archetype) {
      BasketballArchetype.balancedGuard => 'BALANCED GUARD',
      BasketballArchetype.sharpshooter => 'SHARPSHOOTER',
      BasketballArchetype.slasher => 'SLASHER',
      BasketballArchetype.interiorPower => 'INTERIOR POWER',
    };

String basketballTraitLabel(BasketballTrait trait) => switch (trait) {
  BasketballTrait.quickRelease => 'QUICK RELEASE',
  BasketballTrait.deepRange => 'DEEP RANGE',
  BasketballTrait.rimPressure => 'RIM PRESSURE',
  BasketballTrait.glassCleaner => 'GLASS CLEANER',
};

String basketballTraitBlurb(BasketballTrait trait) => switch (trait) {
  BasketballTrait.quickRelease => 'Faster gather, harder to block',
  BasketballTrait.deepRange => 'No penalty on deep threes',
  BasketballTrait.rimPressure => 'Dunks from further out',
  BasketballTrait.glassCleaner => 'Owns the rebound battle',
};

String basketballDifficultyLabel(BasketballDifficulty difficulty) =>
    switch (difficulty) {
      BasketballDifficulty.rookie => 'ROOKIE',
      BasketballDifficulty.pro => 'PRO',
      BasketballDifficulty.allStar => 'ALL-STAR',
    };

BasketballDifficulty basketballDifficultyFromName(String? name) =>
    BasketballDifficulty.values.firstWhere(
      (d) => d.name == name,
      orElse: () => BasketballDifficulty.pro,
    );

/// A Hoop Duel athlete. Ratings are 0-99.
class BasketballAthlete {
  const BasketballAthlete({
    required this.id,
    required this.name,
    required this.ovr,
    required this.teamName,
    required this.teamCode,
    required this.position,
    required this.cardRole,
    required this.archetype,
    required this.trait,
    required this.tagline,
    required this.heightM,
    required this.speed,
    required this.handling,
    required this.inside,
    required this.mid,
    required this.three,
    required this.dunk,
    required this.defense,
    required this.steal,
    required this.block,
    required this.rebound,
    required this.stamina,
  });

  final String id;
  final String name;
  final int ovr;
  final String teamName;
  final String teamCode;
  final String position;
  final BasketballCardRole cardRole;
  final BasketballArchetype archetype;
  final BasketballTrait trait;

  /// One-line lobby flavor, e.g. 'Never rushed. Never late.'
  final String tagline;

  /// Body height in metres — feeds reach for blocks/rebounds.
  final double heightM;

  final int speed;
  final int handling;
  final int inside;
  final int mid;
  final int three;
  final int dunk;
  final int defense;
  final int steal;
  final int block;
  final int rebound;
  final int stamina;

  /// Shooting rating for a zone (dunk uses [dunk], put-backs use [inside]).
  int ratingFor(ShotZone zone) => switch (zone) {
    ShotZone.dunk => dunk,
    ShotZone.layup || ShotZone.close => inside,
    ShotZone.mid => mid,
    ShotZone.three => three,
  };

  int get overall => ovr;
}

/// Everything a match needs to run deterministically.
class BasketballMatchConfig {
  const BasketballMatchConfig({
    required this.playerRoster,
    required this.playerStarterIndex,
    required this.cpuRoster,
    required this.cpuStarterIndex,
    required this.difficulty,
    required this.seed,
    this.showHints = false,
    this.teamId = 'statoz',
    this.cpuTeamId = 'bulls',
  });

  /// Three athletes picked in the lobby; one is active at a time.
  final List<BasketballAthlete> playerRoster;
  final int playerStarterIndex;
  final List<BasketballAthlete> cpuRoster;
  final int cpuStarterIndex;
  final BasketballDifficulty difficulty;
  final int seed;

  /// First-match contextual control hints.
  final bool showHints;

  /// The user's selected team livery ID.
  final String teamId;

  /// The CPU's team livery ID — always different from [teamId].
  final String cpuTeamId;
}

/// Player-side box score, accumulated by the engine for the result screen.
class BasketballBoxScore {
  const BasketballBoxScore({
    this.attempts = 0,
    this.makes = 0,
    this.threesMade = 0,
    this.perfectReleases = 0,
    this.dunks = 0,
    this.blocks = 0,
    this.steals = 0,
    this.rebounds = 0,
    this.turnovers = 0,
    this.bestRun = 0,
  });

  final int attempts;
  final int makes;
  final int threesMade;
  final int perfectReleases;
  final int dunks;
  final int blocks;
  final int steals;
  final int rebounds;
  final int turnovers;

  /// Longest unanswered scoring run (points).
  final int bestRun;

  int get fgPercent => attempts == 0 ? 0 : (makes * 100 ~/ attempts);
}

/// Final match outcome handed from the engine to the cubit/result screen.
class BasketballMatchSummary {
  const BasketballMatchSummary({
    required this.playerScore,
    required this.cpuScore,
    required this.overtime,
    required this.box,
    required this.difficulty,
    this.buzzerBeater = false,
    this.abandoned = false,
  });

  final int playerScore;
  final int cpuScore;
  final bool overtime;
  final BasketballBoxScore box;
  final BasketballDifficulty difficulty;

  /// The winning basket beat the final buzzer.
  final bool buzzerBeater;
  final bool abandoned;

  bool get won => playerScore > cpuScore;
  int get margin => (playerScore - cpuScore).abs();

  /// Performance grade D→S: result + shot quality + defense, not just score.
  String get grade {
    var score = 0;
    if (won) score += 3;
    if (box.fgPercent >= 60) {
      score += 2;
    } else if (box.fgPercent >= 45) {
      score += 1;
    }
    if (box.perfectReleases >= 3) score += 1;
    if (box.blocks + box.steals >= 3) {
      score += 2;
    } else if (box.blocks + box.steals >= 1) {
      score += 1;
    }
    if (box.turnovers >= 4) score -= 1;
    if (won && margin >= 8) score += 1;
    return switch (score) {
      >= 8 => 'S',
      >= 6 => 'A',
      >= 4 => 'B',
      >= 2 => 'C',
      _ => 'D',
    };
  }
}

/// Persisted lifetime Hoop Duel record (on-device only — mirrors
/// [GrandPrixStats]). Also remembers the last roster/starter/difficulty so a
/// returning player can hit PLAY immediately, and whether the first-match
/// control hints have been shown.
class BasketballStats {
  const BasketballStats({
    this.games = 0,
    this.wins = 0,
    this.losses = 0,
    this.otGames = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.mostPoints = 0,
    this.bestMargin = 0,
    this.totalDunks = 0,
    this.totalBlocks = 0,
    this.totalPerfects = 0,
    this.lastRosterIds = const [],
    this.lastStarterId,
    this.lastDifficulty = BasketballDifficulty.pro,
    this.hintsSeen = false,
    this.lastTeamId = 'statoz',
  });

  factory BasketballStats.fromJson(Map<String, dynamic> json) {
    final rawRoster = json['lastRosterIds'];
    return BasketballStats(
      games: json['games'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      otGames: json['otGames'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      bestStreak: json['bestStreak'] as int? ?? 0,
      mostPoints: json['mostPoints'] as int? ?? 0,
      bestMargin: json['bestMargin'] as int? ?? 0,
      totalDunks: json['totalDunks'] as int? ?? 0,
      totalBlocks: json['totalBlocks'] as int? ?? 0,
      totalPerfects: json['totalPerfects'] as int? ?? 0,
      lastRosterIds: rawRoster is List
          ? [for (final id in rawRoster) '$id']
          : const [],
      lastStarterId: json['lastStarterId'] as String?,
      lastDifficulty: basketballDifficultyFromName(
        json['lastDifficulty'] as String?,
      ),
      hintsSeen: json['hintsSeen'] as bool? ?? false,
      lastTeamId: json['lastTeamId'] as String? ?? 'statoz',
    );
  }

  final int games;
  final int wins;
  final int losses;
  final int otGames;
  final int currentStreak;
  final int bestStreak;
  final int mostPoints;
  final int bestMargin;
  final int totalDunks;
  final int totalBlocks;
  final int totalPerfects;
  final List<String> lastRosterIds;
  final String? lastStarterId;
  final BasketballDifficulty lastDifficulty;
  final bool hintsSeen;
  final String lastTeamId;

  BasketballStats copyWith({
    List<String>? lastRosterIds,
    String? lastStarterId,
    BasketballDifficulty? lastDifficulty,
    bool? hintsSeen,
    String? lastTeamId,
  }) => BasketballStats(
    games: games,
    wins: wins,
    losses: losses,
    otGames: otGames,
    currentStreak: currentStreak,
    bestStreak: bestStreak,
    mostPoints: mostPoints,
    bestMargin: bestMargin,
    totalDunks: totalDunks,
    totalBlocks: totalBlocks,
    totalPerfects: totalPerfects,
    lastRosterIds: lastRosterIds ?? this.lastRosterIds,
    lastStarterId: lastStarterId ?? this.lastStarterId,
    lastDifficulty: lastDifficulty ?? this.lastDifficulty,
    hintsSeen: hintsSeen ?? this.hintsSeen,
    lastTeamId: lastTeamId ?? this.lastTeamId,
  );

  BasketballStats recordResult(BasketballMatchSummary summary) {
    final won = summary.won;
    final nextStreak = won ? currentStreak + 1 : 0;
    return BasketballStats(
      games: games + 1,
      wins: won ? wins + 1 : wins,
      losses: won ? losses : losses + 1,
      otGames: summary.overtime ? otGames + 1 : otGames,
      currentStreak: nextStreak,
      bestStreak: nextStreak > bestStreak ? nextStreak : bestStreak,
      mostPoints: summary.playerScore > mostPoints
          ? summary.playerScore
          : mostPoints,
      bestMargin: won && summary.margin > bestMargin
          ? summary.margin
          : bestMargin,
      totalDunks: totalDunks + summary.box.dunks,
      totalBlocks: totalBlocks + summary.box.blocks,
      totalPerfects: totalPerfects + summary.box.perfectReleases,
      lastRosterIds: lastRosterIds,
      lastStarterId: lastStarterId,
      lastDifficulty: summary.difficulty,
      hintsSeen: hintsSeen,
      lastTeamId: lastTeamId,
    );
  }

  Map<String, dynamic> toJson() => {
    'games': games,
    'wins': wins,
    'losses': losses,
    'otGames': otGames,
    'currentStreak': currentStreak,
    'bestStreak': bestStreak,
    'mostPoints': mostPoints,
    'bestMargin': bestMargin,
    'totalDunks': totalDunks,
    'totalBlocks': totalBlocks,
    'totalPerfects': totalPerfects,
    'lastRosterIds': lastRosterIds,
    'lastStarterId': lastStarterId,
    'lastDifficulty': lastDifficulty.name,
    'hintsSeen': hintsSeen,
    'lastTeamId': lastTeamId,
  };
}
```

### A.8 `lib/data/basketball_athletes.dart`

<sub>636 lines</sub>

```dart
import 'dart:ui';

import '../models/basketball.dart';

/// 180-player 2026 NBA Hoop Duel roster: six players per team.
///
/// Each seed locks the card/game identity: team, player, position, basketball
/// deck role, and OVR. Granular gameplay ratings are generated from those
/// values so the roster stays maintainable while preserving distinct play
/// styles for guards, wings, and bigs.
final List<BasketballAthlete> basketballAthletes = [
  for (final seed in _basketballSeeds) _buildAthlete(seed),
];

final Map<String, BasketballAthlete> _basketballAthletesById = {
  for (final athlete in basketballAthletes) athlete.id: athlete,
};

BasketballAthlete basketballAthleteById(String id) =>
    _basketballAthletesById[id] ?? basketballAthletes.first;

class _Seed {
  const _Seed(this.teamCode, this.name, this.position, this.role, this.ovr);

  final String teamCode;
  final String name;
  final String position;
  final BasketballCardRole role;
  final int ovr;
}

const List<_Seed> _basketballSeeds = [
  _Seed('ATL', 'Trae Young', 'PG', BasketballCardRole.guard, 91),
  _Seed('ATL', 'Jalen Johnson', 'PF', BasketballCardRole.wing, 88),
  _Seed('ATL', 'Kristaps Porzingis', 'C', BasketballCardRole.big, 84),
  _Seed('ATL', 'Nickeil Alexander-Walker', 'SG', BasketballCardRole.guard, 79),
  _Seed('ATL', 'Onyeka Okongwu', 'C', BasketballCardRole.big, 79),
  _Seed('ATL', 'Zaccharie Risacher', 'SF', BasketballCardRole.wing, 78),
  _Seed('BOS', 'Jayson Tatum', 'SF/PF', BasketballCardRole.wing, 94),
  _Seed('BOS', 'Jaylen Brown', 'SG/SF', BasketballCardRole.wing, 90),
  _Seed('BOS', 'Derrick White', 'G', BasketballCardRole.guard, 86),
  _Seed('BOS', 'Payton Pritchard', 'PG', BasketballCardRole.guard, 82),
  _Seed('BOS', 'Neemias Queta', 'C', BasketballCardRole.big, 77),
  _Seed('BOS', 'Baylor Scheierman', 'G/F', BasketballCardRole.wing, 75),
  _Seed('BKN', 'Michael Porter Jr.', 'SF', BasketballCardRole.wing, 86),
  _Seed('BKN', 'Cam Thomas', 'SG', BasketballCardRole.guard, 84),
  _Seed('BKN', 'Nic Claxton', 'C', BasketballCardRole.big, 82),
  _Seed('BKN', 'Terance Mann', 'G', BasketballCardRole.guard, 79),
  _Seed('BKN', 'Noah Clowney', 'F', BasketballCardRole.wing, 77),
  _Seed('BKN', 'Tyler Bilodeau', 'F/C', BasketballCardRole.big, 72),
  _Seed('CHA', 'LaMelo Ball', 'PG', BasketballCardRole.guard, 88),
  _Seed('CHA', 'Brandon Miller', 'SF', BasketballCardRole.wing, 86),
  _Seed('CHA', 'Miles Bridges', 'SF/PF', BasketballCardRole.wing, 82),
  _Seed('CHA', 'Kon Knueppel', 'G/F', BasketballCardRole.guard, 78),
  _Seed('CHA', 'Moussa Diabate', 'C', BasketballCardRole.big, 74),
  _Seed('CHA', 'Kylan Boswell', 'G', BasketballCardRole.guard, 72),
  _Seed('CHI', 'Coby White', 'PG', BasketballCardRole.guard, 84),
  _Seed('CHI', 'Josh Giddey', 'G/F', BasketballCardRole.guard, 84),
  _Seed('CHI', 'Nikola Vucevic', 'C', BasketballCardRole.big, 82),
  _Seed('CHI', 'Matas Buzelis', 'F', BasketballCardRole.wing, 79),
  _Seed('CHI', 'Ayo Dosunmu', 'G', BasketballCardRole.guard, 78),
  _Seed('CHI', 'Tobe Awaka', 'F/C', BasketballCardRole.wing, 72),
  _Seed('CLE', 'Donovan Mitchell', 'SG', BasketballCardRole.guard, 92),
  _Seed('CLE', 'Evan Mobley', 'PF/C', BasketballCardRole.big, 91),
  _Seed('CLE', 'Darius Garland', 'PG', BasketballCardRole.guard, 87),
  _Seed('CLE', 'Jarrett Allen', 'C', BasketballCardRole.big, 86),
  _Seed('CLE', 'DeAndre Hunter', 'SF', BasketballCardRole.wing, 79),
  _Seed('CLE', 'Max Strus', 'G/F', BasketballCardRole.wing, 78),
  _Seed('DAL', 'Kyrie Irving', 'PG', BasketballCardRole.guard, 90),
  _Seed('DAL', 'Cooper Flagg', 'F', BasketballCardRole.wing, 84),
  _Seed('DAL', 'Klay Thompson', 'SG', BasketballCardRole.guard, 82),
  _Seed('DAL', 'PJ Washington', 'PF', BasketballCardRole.wing, 79),
  _Seed('DAL', 'Daniel Gafford', 'C', BasketballCardRole.big, 79),
  _Seed('DAL', 'Dereck Lively II', 'C', BasketballCardRole.big, 78),
  _Seed('DEN', 'Nikola Jokic', 'C', BasketballCardRole.big, 97),
  _Seed('DEN', 'Jamal Murray', 'PG', BasketballCardRole.guard, 88),
  _Seed('DEN', 'Aaron Gordon', 'PF', BasketballCardRole.wing, 84),
  _Seed('DEN', 'Cam Johnson', 'SF', BasketballCardRole.wing, 81),
  _Seed('DEN', 'Christian Braun', 'G/F', BasketballCardRole.guard, 79),
  _Seed('DEN', 'Julian Strawther', 'G/F', BasketballCardRole.guard, 76),
  _Seed('DET', 'Cade Cunningham', 'PG', BasketballCardRole.guard, 91),
  _Seed('DET', 'Jaden Ivey', 'SG', BasketballCardRole.guard, 84),
  _Seed('DET', 'Ausar Thompson', 'SF', BasketballCardRole.wing, 81),
  _Seed('DET', 'Tobias Harris', 'PF', BasketballCardRole.wing, 81),
  _Seed('DET', 'Jalen Duren', 'C', BasketballCardRole.big, 79),
  _Seed('DET', 'Ron Holland', 'F', BasketballCardRole.wing, 77),
  _Seed('GSW', 'Stephen Curry', 'PG', BasketballCardRole.guard, 93),
  _Seed('GSW', 'Jimmy Butler', 'SF', BasketballCardRole.wing, 89),
  _Seed('GSW', 'Draymond Green', 'PF/C', BasketballCardRole.big, 83),
  _Seed('GSW', 'Jonathan Kuminga', 'F', BasketballCardRole.wing, 82),
  _Seed('GSW', 'Brandin Podziemski', 'G', BasketballCardRole.guard, 78),
  _Seed('GSW', 'Moses Moody', 'G/F', BasketballCardRole.wing, 77),
  _Seed('HOU', 'Kevin Durant', 'PF', BasketballCardRole.wing, 93),
  _Seed('HOU', 'Alperen Sengun', 'C', BasketballCardRole.big, 90),
  _Seed('HOU', 'Amen Thompson', 'G/F', BasketballCardRole.guard, 86),
  _Seed('HOU', 'Jabari Smith Jr.', 'PF', BasketballCardRole.wing, 79),
  _Seed('HOU', 'Reed Sheppard', 'G', BasketballCardRole.guard, 76),
  _Seed('HOU', 'Steven Adams', 'C', BasketballCardRole.big, 75),
  _Seed('IND', 'Tyrese Haliburton', 'PG', BasketballCardRole.guard, 90),
  _Seed('IND', 'Pascal Siakam', 'PF', BasketballCardRole.wing, 88),
  _Seed('IND', 'Andrew Nembhard', 'G', BasketballCardRole.guard, 81),
  _Seed('IND', 'Bennedict Mathurin', 'G/F', BasketballCardRole.guard, 79),
  _Seed('IND', 'Aaron Nesmith', 'SF', BasketballCardRole.wing, 79),
  _Seed('IND', 'Obi Toppin', 'PF', BasketballCardRole.big, 78),
  _Seed('LAC', 'Kawhi Leonard', 'SF', BasketballCardRole.wing, 89),
  _Seed('LAC', 'James Harden', 'PG', BasketballCardRole.guard, 87),
  _Seed('LAC', 'Bradley Beal', 'SG', BasketballCardRole.guard, 84),
  _Seed('LAC', 'Ivica Zubac', 'C', BasketballCardRole.big, 82),
  _Seed('LAC', 'Bogdan Bogdanovic', 'G', BasketballCardRole.guard, 79),
  _Seed('LAC', 'Nicolas Batum', 'G/F', BasketballCardRole.wing, 75),
  _Seed('LAL', 'Luka Doncic', 'PG', BasketballCardRole.guard, 96),
  _Seed('LAL', 'LeBron James', 'SF/PF', BasketballCardRole.wing, 91),
  _Seed('LAL', 'Austin Reaves', 'G', BasketballCardRole.guard, 83),
  _Seed('LAL', 'Rui Hachimura', 'F', BasketballCardRole.wing, 79),
  _Seed('LAL', 'Marcus Smart', 'G', BasketballCardRole.guard, 78),
  _Seed('LAL', 'Jaxson Hayes', 'C', BasketballCardRole.big, 74),
  _Seed('MEM', 'Ja Morant', 'PG', BasketballCardRole.guard, 89),
  _Seed('MEM', 'Jaren Jackson Jr.', 'PF/C', BasketballCardRole.big, 88),
  _Seed('MEM', 'Cameron Boozer', 'F', BasketballCardRole.wing, 82),
  _Seed('MEM', 'Zach Edey', 'C', BasketballCardRole.big, 80),
  _Seed('MEM', 'Santi Aldama', 'F/C', BasketballCardRole.wing, 79),
  _Seed('MEM', 'Scotty Pippen Jr.', 'G', BasketballCardRole.guard, 75),
  _Seed('MIA', 'Giannis Antetokounmpo', 'PF', BasketballCardRole.wing, 95),
  _Seed('MIA', 'Bam Adebayo', 'C', BasketballCardRole.big, 90),
  _Seed('MIA', 'Tyler Herro', 'SG', BasketballCardRole.guard, 87),
  _Seed('MIA', 'Kelel Ware', 'C', BasketballCardRole.big, 79),
  _Seed('MIA', 'Jaime Jaquez Jr.', 'F', BasketballCardRole.wing, 78),
  _Seed('MIA', 'Davion Mitchell', 'G', BasketballCardRole.guard, 76),
  _Seed('MIL', 'Nate Ament', 'F', BasketballCardRole.wing, 82),
  _Seed('MIL', 'Kyle Kuzma', 'F', BasketballCardRole.wing, 81),
  _Seed('MIL', 'Bobby Portis', 'PF/C', BasketballCardRole.big, 79),
  _Seed('MIL', 'Kevin Porter Jr.', 'G', BasketballCardRole.guard, 78),
  _Seed('MIL', 'Cole Anthony', 'G', BasketballCardRole.guard, 76),
  _Seed('MIL', 'Alex Antetokounmpo', 'F', BasketballCardRole.big, 70),
  _Seed('MIN', 'Anthony Edwards', 'SG', BasketballCardRole.guard, 93),
  _Seed('MIN', 'Julius Randle', 'PF', BasketballCardRole.wing, 87),
  _Seed('MIN', 'Rudy Gobert', 'C', BasketballCardRole.big, 86),
  _Seed('MIN', 'Naz Reid', 'C/F', BasketballCardRole.big, 82),
  _Seed('MIN', 'Jaden McDaniels', 'SF', BasketballCardRole.wing, 81),
  _Seed('MIN', 'Rob Dillingham', 'G', BasketballCardRole.guard, 72),
  _Seed('NOP', 'Zion Williamson', 'PF', BasketballCardRole.big, 87),
  _Seed('NOP', 'Dejounte Murray', 'PG', BasketballCardRole.guard, 86),
  _Seed('NOP', 'Trey Murphy III', 'SF', BasketballCardRole.wing, 84),
  _Seed('NOP', 'Herb Jones', 'SF', BasketballCardRole.wing, 79),
  _Seed('NOP', 'Yves Missi', 'C', BasketballCardRole.big, 78),
  _Seed('NOP', 'Jordan Hawkins', 'G', BasketballCardRole.guard, 76),
  _Seed('NYK', 'Jalen Brunson', 'PG', BasketballCardRole.guard, 92),
  _Seed('NYK', 'Karl-Anthony Towns', 'C', BasketballCardRole.big, 90),
  _Seed('NYK', 'Mikal Bridges', 'SF', BasketballCardRole.wing, 86),
  _Seed('NYK', 'OG Anunoby', 'F', BasketballCardRole.wing, 85),
  _Seed('NYK', 'Josh Hart', 'G/F', BasketballCardRole.wing, 82),
  _Seed('NYK', 'Jose Alvarado', 'G', BasketballCardRole.guard, 77),
  _Seed('OKC', 'Shai Gilgeous-Alexander', 'PG', BasketballCardRole.guard, 97),
  _Seed('OKC', 'Chet Holmgren', 'C', BasketballCardRole.big, 90),
  _Seed('OKC', 'Jalen Williams', 'G/F', BasketballCardRole.wing, 90),
  _Seed('OKC', 'Alex Caruso', 'G', BasketballCardRole.guard, 82),
  _Seed('OKC', 'Lu Dort', 'G/F', BasketballCardRole.wing, 79),
  _Seed('OKC', 'Brooks Barnhizer', 'G', BasketballCardRole.guard, 72),
  _Seed('ORL', 'Paolo Banchero', 'PF', BasketballCardRole.wing, 91),
  _Seed('ORL', 'Franz Wagner', 'SF', BasketballCardRole.wing, 88),
  _Seed('ORL', 'Desmond Bane', 'SG', BasketballCardRole.guard, 87),
  _Seed('ORL', 'Jalen Suggs', 'G', BasketballCardRole.guard, 82),
  _Seed('ORL', 'Anthony Black', 'G', BasketballCardRole.guard, 79),
  _Seed('ORL', 'Goga Bitadze', 'C', BasketballCardRole.big, 78),
  _Seed('PHI', 'Joel Embiid', 'C', BasketballCardRole.big, 92),
  _Seed('PHI', 'Tyrese Maxey', 'PG', BasketballCardRole.guard, 90),
  _Seed('PHI', 'Paul George', 'SF', BasketballCardRole.wing, 86),
  _Seed('PHI', 'Jared McCain', 'G', BasketballCardRole.guard, 80),
  _Seed('PHI', 'Adem Bona', 'F/C', BasketballCardRole.big, 76),
  _Seed('PHI', 'Dominick Barlow', 'F', BasketballCardRole.wing, 74),
  _Seed('PHX', 'Devin Booker', 'SG', BasketballCardRole.guard, 91),
  _Seed('PHX', 'Jalen Green', 'G', BasketballCardRole.guard, 84),
  _Seed('PHX', 'Dillon Brooks', 'SF', BasketballCardRole.wing, 80),
  _Seed('PHX', 'Grayson Allen', 'G', BasketballCardRole.guard, 79),
  _Seed('PHX', 'Ryan Dunn', 'F', BasketballCardRole.wing, 77),
  _Seed('PHX', 'Oso Ighodaro', 'F/C', BasketballCardRole.big, 74),
  _Seed('POR', 'Deni Avdija', 'F', BasketballCardRole.wing, 84),
  _Seed('POR', 'Scoot Henderson', 'PG', BasketballCardRole.guard, 82),
  _Seed('POR', 'Shaedon Sharpe', 'G', BasketballCardRole.guard, 81),
  _Seed('POR', 'Jerami Grant', 'F', BasketballCardRole.wing, 80),
  _Seed('POR', 'Donovan Clingan', 'C', BasketballCardRole.big, 78),
  _Seed('POR', 'Robert Williams III', 'C', BasketballCardRole.big, 76),
  _Seed('SAC', 'Domantas Sabonis', 'C', BasketballCardRole.big, 89),
  _Seed('SAC', 'Zach LaVine', 'SG', BasketballCardRole.guard, 86),
  _Seed('SAC', 'DeMar DeRozan', 'SF', BasketballCardRole.wing, 85),
  _Seed('SAC', 'Keegan Murray', 'F', BasketballCardRole.wing, 81),
  _Seed('SAC', 'Precious Achiuwa', 'F/C', BasketballCardRole.big, 78),
  _Seed('SAC', 'Darius Acuff Jr.', 'G', BasketballCardRole.guard, 73),
  _Seed('SAS', 'Victor Wembanyama', 'C', BasketballCardRole.big, 96),
  _Seed('SAS', 'DeAaron Fox', 'PG', BasketballCardRole.guard, 89),
  _Seed('SAS', 'Stephon Castle', 'G', BasketballCardRole.guard, 83),
  _Seed('SAS', 'Devin Vassell', 'G/F', BasketballCardRole.wing, 82),
  _Seed('SAS', 'Harrison Barnes', 'F', BasketballCardRole.wing, 78),
  _Seed('SAS', 'Bismack Biyombo', 'C', BasketballCardRole.big, 72),
  _Seed('TOR', 'Scottie Barnes', 'F', BasketballCardRole.wing, 91),
  _Seed('TOR', 'Brandon Ingram', 'SF', BasketballCardRole.wing, 87),
  _Seed('TOR', 'RJ Barrett', 'G/F', BasketballCardRole.wing, 84),
  _Seed('TOR', 'Immanuel Quickley', 'PG', BasketballCardRole.guard, 82),
  _Seed('TOR', 'Jakob Poeltl', 'C', BasketballCardRole.big, 80),
  _Seed('TOR', 'Gradey Dick', 'G/F', BasketballCardRole.guard, 74),
  _Seed('UTA', 'Lauri Markkanen', 'F', BasketballCardRole.wing, 87),
  _Seed('UTA', 'Ace Bailey', 'F', BasketballCardRole.wing, 82),
  _Seed('UTA', 'Keyonte George', 'G', BasketballCardRole.guard, 80),
  _Seed('UTA', 'Walker Kessler', 'C', BasketballCardRole.big, 79),
  _Seed('UTA', 'Trey Alexander', 'G', BasketballCardRole.guard, 73),
  _Seed('UTA', 'Tamar Bates', 'G', BasketballCardRole.guard, 70),
  _Seed('WAS', 'Anthony Davis', 'C/PF', BasketballCardRole.big, 91),
  _Seed('WAS', 'Deandre Ayton', 'C', BasketballCardRole.big, 84),
  _Seed('WAS', 'Bilal Coulibaly', 'F', BasketballCardRole.wing, 80),
  _Seed('WAS', 'Alex Sarr', 'F/C', BasketballCardRole.wing, 79),
  _Seed('WAS', 'Tre Johnson', 'G', BasketballCardRole.guard, 78),
  _Seed('WAS', 'Bub Carrington', 'G', BasketballCardRole.guard, 76),
];

BasketballAthlete _buildAthlete(_Seed seed) {
  final shootingNames = {
    'Stephen Curry',
    'Kevin Durant',
    'Tyrese Haliburton',
    'Devin Booker',
    'Klay Thompson',
    'Michael Porter Jr.',
    'Jamal Murray',
    'Trae Young',
    'Jalen Brunson',
  };
  final isShooter = shootingNames.contains(seed.name);
  final archetype = switch (seed.role) {
    BasketballCardRole.guard =>
      isShooter
          ? BasketballArchetype.sharpshooter
          : BasketballArchetype.balancedGuard,
    BasketballCardRole.wing =>
      isShooter
          ? BasketballArchetype.sharpshooter
          : BasketballArchetype.slasher,
    BasketballCardRole.big => BasketballArchetype.interiorPower,
  };
  final trait = switch (archetype) {
    BasketballArchetype.sharpshooter => BasketballTrait.deepRange,
    BasketballArchetype.balancedGuard => BasketballTrait.quickRelease,
    BasketballArchetype.slasher => BasketballTrait.rimPressure,
    BasketballArchetype.interiorPower => BasketballTrait.glassCleaner,
  };
  final heightM = switch (seed.role) {
    BasketballCardRole.guard => seed.position.contains('F') ? 1.96 : 1.91,
    BasketballCardRole.wing => seed.position.contains('PF') ? 2.06 : 2.03,
    BasketballCardRole.big =>
      seed.name == 'Victor Wembanyama'
          ? 2.24
          : seed.name == 'Kristaps Porzingis'
          ? 2.21
          : 2.11,
  };

  return BasketballAthlete(
    id: '${seed.teamCode.toLowerCase()}-${_slug(seed.name)}',
    name: seed.name,
    ovr: seed.ovr,
    teamName: _teamNames[seed.teamCode]!,
    teamCode: seed.teamCode,
    position: seed.position,
    cardRole: seed.role,
    archetype: archetype,
    trait: trait,
    tagline: _tagline(seed, trait),
    heightM: heightM,
    speed: _rating(seed.ovr, _speedDelta(seed.role)),
    handling: _rating(seed.ovr, _handlingDelta(seed.role, isShooter)),
    inside: _rating(seed.ovr, _insideDelta(seed.role)),
    mid: _rating(seed.ovr, isShooter ? 5 : _midDelta(seed.role)),
    three: _rating(seed.ovr, isShooter ? 8 : _threeDelta(seed.role)),
    dunk: _rating(seed.ovr, _dunkDelta(seed.role)),
    defense: _rating(seed.ovr, _defenseDelta(seed.role)),
    steal: _rating(seed.ovr, _stealDelta(seed.role)),
    block: _rating(seed.ovr, _blockDelta(seed.role)),
    rebound: _rating(seed.ovr, _reboundDelta(seed.role)),
    stamina: _rating(seed.ovr, seed.ovr >= 90 ? 3 : 0),
  );
}

String _tagline(_Seed seed, BasketballTrait trait) {
  final roleText = switch (seed.role) {
    BasketballCardRole.guard => 'Backcourt value',
    BasketballCardRole.wing => 'Two-way wing value',
    BasketballCardRole.big => 'Paint value',
  };
  final traitText = switch (trait) {
    BasketballTrait.quickRelease => 'quick-trigger reads',
    BasketballTrait.deepRange => 'deep-range pressure',
    BasketballTrait.rimPressure => 'rim pressure',
    BasketballTrait.glassCleaner => 'glass control',
  };
  return '$roleText with $traitText.';
}

int _rating(int ovr, int delta) => (ovr + delta).clamp(25, 99);

int _speedDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => 5,
  BasketballCardRole.wing => 2,
  BasketballCardRole.big => -12,
};

int _handlingDelta(BasketballCardRole role, bool shooter) => switch (role) {
  BasketballCardRole.guard => shooter ? 8 : 7,
  BasketballCardRole.wing => 2,
  BasketballCardRole.big => -10,
};

int _insideDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -5,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => 8,
};

int _midDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => 2,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => -2,
};

int _threeDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => 3,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => -10,
};

int _dunkDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -12,
  BasketballCardRole.wing => 3,
  BasketballCardRole.big => 7,
};

int _defenseDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -4,
  BasketballCardRole.wing => 2,
  BasketballCardRole.big => 5,
};

int _stealDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => 2,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => -6,
};

int _blockDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -25,
  BasketballCardRole.wing => -6,
  BasketballCardRole.big => 10,
};

int _reboundDelta(BasketballCardRole role) => switch (role) {
  BasketballCardRole.guard => -15,
  BasketballCardRole.wing => 1,
  BasketballCardRole.big => 10,
};

String _slug(String value) => value
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
    .replaceAll(RegExp(r'^-+|-+$'), '');

const Map<String, String> _teamNames = {
  'ATL': 'Atlanta Hawks',
  'BOS': 'Boston Celtics',
  'BKN': 'Brooklyn Nets',
  'CHA': 'Charlotte Hornets',
  'CHI': 'Chicago Bulls',
  'CLE': 'Cleveland Cavaliers',
  'DAL': 'Dallas Mavericks',
  'DEN': 'Denver Nuggets',
  'DET': 'Detroit Pistons',
  'GSW': 'Golden State Warriors',
  'HOU': 'Houston Rockets',
  'IND': 'Indiana Pacers',
  'LAC': 'LA Clippers',
  'LAL': 'Los Angeles Lakers',
  'MEM': 'Memphis Grizzlies',
  'MIA': 'Miami Heat',
  'MIL': 'Milwaukee Bucks',
  'MIN': 'Minnesota Timberwolves',
  'NOP': 'New Orleans Pelicans',
  'NYK': 'New York Knicks',
  'OKC': 'Oklahoma City Thunder',
  'ORL': 'Orlando Magic',
  'PHI': 'Philadelphia 76ers',
  'PHX': 'Phoenix Suns',
  'POR': 'Portland Trail Blazers',
  'SAC': 'Sacramento Kings',
  'SAS': 'San Antonio Spurs',
  'TOR': 'Toronto Raptors',
  'UTA': 'Utah Jazz',
  'WAS': 'Washington Wizards',
};

/// Procedural hair silhouettes used by the on-court rig.
enum BasketballHairStyle { closeCrop, fade, curls, highTop, twists }

/// Render-only frame categories. These never affect reach or collisions.
enum BasketballAthleteBuild { lean, athletic, power }

/// One restrained, trait-linked accessory per athlete.
enum BasketballAthleteGear { none, shootingSleeve, headband, kneeSleeve }

/// On-court + card look for one athlete (content colors and render-only shape).
class BasketballAthleteLook {
  const BasketballAthleteLook({
    required this.accent,
    required this.skin,
    required this.hair,
    this.hairStyle = BasketballHairStyle.closeCrop,
    this.hairScale = 1,
    this.build = BasketballAthleteBuild.athletic,
    this.buildScale = 1,
    this.gear = BasketballAthleteGear.none,
  });

  /// Signature color used for the card trim and heat aura tint.
  final Color accent;
  final Color skin;
  final Color hair;

  /// Stable silhouette choices derived from the athlete id.
  final BasketballHairStyle hairStyle;
  final double hairScale;

  /// Width-only rendering variation. Height and gameplay geometry are intact.
  final BasketballAthleteBuild build;
  final double buildScale;

  /// A single visual accessory selected from the athlete's gameplay trait.
  final BasketballAthleteGear gear;
}

const Map<String, BasketballAthleteLook> _teamLooks = {
  'ATL': BasketballAthleteLook(
    accent: Color(0xFFE03A3E),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF17110D),
  ),
  'BOS': BasketballAthleteLook(
    accent: Color(0xFF007A33),
    skin: Color(0xFFC68642),
    hair: Color(0xFF191919),
  ),
  'BKN': BasketballAthleteLook(
    accent: Color(0xFFF5F5F5),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF1B1B22),
  ),
  'CHA': BasketballAthleteLook(
    accent: Color(0xFF1D8CAB),
    skin: Color(0xFFC68642),
    hair: Color(0xFF2B221B),
  ),
  'CHI': BasketballAthleteLook(
    accent: Color(0xFFCE1141),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF4B2E1F),
  ),
  'CLE': BasketballAthleteLook(
    accent: Color(0xFFFFB81C),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF151515),
  ),
  'DAL': BasketballAthleteLook(
    accent: Color(0xFF00538C),
    skin: Color(0xFFC68642),
    hair: Color(0xFF1D1714),
  ),
  'DEN': BasketballAthleteLook(
    accent: Color(0xFFFFC72C),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF5A3B26),
  ),
  'DET': BasketballAthleteLook(
    accent: Color(0xFFC8102E),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'GSW': BasketballAthleteLook(
    accent: Color(0xFFFFC72C),
    skin: Color(0xFFC68642),
    hair: Color(0xFF231A14),
  ),
  'HOU': BasketballAthleteLook(
    accent: Color(0xFFCE1141),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF141414),
  ),
  'IND': BasketballAthleteLook(
    accent: Color(0xFFFFC633),
    skin: Color(0xFFC68642),
    hair: Color(0xFF151515),
  ),
  'LAC': BasketballAthleteLook(
    accent: Color(0xFFC8102E),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'LAL': BasketballAthleteLook(
    accent: Color(0xFFFDB927),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF141414),
  ),
  'MEM': BasketballAthleteLook(
    accent: Color(0xFF5D76A9),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'MIA': BasketballAthleteLook(
    accent: Color(0xFF98002E),
    skin: Color(0xFF6B4423),
    hair: Color(0xFF181818),
  ),
  'MIL': BasketballAthleteLook(
    accent: Color(0xFF00471B),
    skin: Color(0xFFC68642),
    hair: Color(0xFF201914),
  ),
  'MIN': BasketballAthleteLook(
    accent: Color(0xFF78BE20),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'NOP': BasketballAthleteLook(
    accent: Color(0xFFC8102E),
    skin: Color(0xFF6B4423),
    hair: Color(0xFF111111),
  ),
  'NYK': BasketballAthleteLook(
    accent: Color(0xFFF58426),
    skin: Color(0xFFC68642),
    hair: Color(0xFF17120F),
  ),
  'OKC': BasketballAthleteLook(
    accent: Color(0xFFEF3B24),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'ORL': BasketballAthleteLook(
    accent: Color(0xFF0077C0),
    skin: Color(0xFFC68642),
    hair: Color(0xFF17120F),
  ),
  'PHI': BasketballAthleteLook(
    accent: Color(0xFF006BB6),
    skin: Color(0xFF6B4423),
    hair: Color(0xFF111111),
  ),
  'PHX': BasketballAthleteLook(
    accent: Color(0xFFE56020),
    skin: Color(0xFFC68642),
    hair: Color(0xFF17120F),
  ),
  'POR': BasketballAthleteLook(
    accent: Color(0xFFE03A3E),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'SAC': BasketballAthleteLook(
    accent: Color(0xFF5A2D81),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF5A3B26),
  ),
  'SAS': BasketballAthleteLook(
    accent: Color(0xFFC4CED4),
    skin: Color(0xFFE0AC69),
    hair: Color(0xFF2C221B),
  ),
  'TOR': BasketballAthleteLook(
    accent: Color(0xFFCE1141),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF151515),
  ),
  'UTA': BasketballAthleteLook(
    accent: Color(0xFFFFC72C),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
  'WAS': BasketballAthleteLook(
    accent: Color(0xFF002B5C),
    skin: Color(0xFF8D5524),
    hair: Color(0xFF111111),
  ),
};

final Map<String, BasketballAthleteLook> _athleteLooksById = {
  for (final athlete in basketballAthletes)
    athlete.id: _buildAthleteLook(athlete),
};

BasketballAthleteLook basketballLookFor(String id) =>
    _athleteLooksById[id] ?? _athleteLooksById[basketballAthletes.first.id]!;

BasketballAthleteLook _buildAthleteLook(BasketballAthlete athlete) {
  final base = _teamLooks[athlete.teamCode] ?? _teamLooks.values.first;
  final hash = _stableAthleteHash(athlete.id);
  final build = switch (athlete.cardRole) {
    BasketballCardRole.guard => BasketballAthleteBuild.lean,
    BasketballCardRole.wing => BasketballAthleteBuild.athletic,
    BasketballCardRole.big => BasketballAthleteBuild.power,
  };
  final buildScale = switch (athlete.cardRole) {
    BasketballCardRole.guard => 0.88 + ((hash >> 3) % 4) * 0.012,
    BasketballCardRole.wing => 0.97 + ((hash >> 3) % 4) * 0.012,
    BasketballCardRole.big => 1.08 + ((hash >> 3) % 4) * 0.015,
  };
  final gear = switch (athlete.trait) {
    BasketballTrait.quickRelease ||
    BasketballTrait.deepRange => BasketballAthleteGear.shootingSleeve,
    BasketballTrait.rimPressure => BasketballAthleteGear.headband,
    BasketballTrait.glassCleaner => BasketballAthleteGear.kneeSleeve,
  };

  return BasketballAthleteLook(
    accent: base.accent,
    skin: base.skin,
    hair: base.hair,
    hairStyle: BasketballHairStyle
        .values[(hash >> 7) % BasketballHairStyle.values.length],
    hairScale: 0.9 + ((hash >> 11) % 5) * 0.04,
    build: build,
    buildScale: buildScale,
    gear: gear,
  );
}

int _stableAthleteHash(String id) =>
    id.codeUnits.fold(0, (acc, unit) => (acc * 31 + unit) & 0x7fffffff);

/// Stable jersey number derived from the athlete id (0–99). Uses an explicit
/// fold hash, not [String.hashCode], so numbers never change across Dart
/// versions or runs.
int jerseyNumberFor(String id) => _stableAthleteHash(id) % 100;
```

### A.9 `lib/data/basketball_teams.dart`

<sub>143 lines</sub>

```dart
import 'package:flutter/material.dart';

class BasketballTeamLivery {
  const BasketballTeamLivery({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final String id;
  final String name;
  final Color primary;
  final Color secondary;
  final Color accent;
}

const List<BasketballTeamLivery> basketballTeams = [
  BasketballTeamLivery(
    id: 'statoz',
    name: 'STATOZ',
    primary: Color(0xFF0B4F5C), // Deep teal body
    secondary: Color(0xFF061018), // Near-black trim
    accent: Color(0xFF35E0FF), // Cyan number/stripe
  ),
  BasketballTeamLivery(
    id: 'lakers',
    name: 'Los Angeles',
    primary: Color(0xFFFDB927), // Gold
    secondary: Color(0xFF552583), // Purple
    accent: Color(0xFF000000), // Black
  ),
  BasketballTeamLivery(
    id: 'bulls',
    name: 'Chicago',
    primary: Color(0xFFCE1141), // Red
    secondary: Color(0xFF000000), // Black
    accent: Color(0xFFFFFFFF), // White
  ),
  BasketballTeamLivery(
    id: 'celtics',
    name: 'Boston',
    primary: Color(0xFF007A33), // Green
    secondary: Color(0xFFFFFFFF), // White
    accent: Color(0xFF000000), // Black
  ),
  BasketballTeamLivery(
    id: 'warriors',
    name: 'Golden State',
    primary: Color(0xFF1D428A), // Royal Blue
    secondary: Color(0xFFFFC72C), // Golden Yellow
    accent: Color(0xFFFFFFFF), // White
  ),
  BasketballTeamLivery(
    id: 'heat',
    name: 'Miami',
    primary: Color(0xFF98002E), // Red
    secondary: Color(0xFFF9A01B), // Yellow
    accent: Color(0xFF000000), // Black
  ),
  BasketballTeamLivery(
    id: 'knicks',
    name: 'New York',
    primary: Color(0xFFF58426), // Orange
    secondary: Color(0xFF006BB6), // Blue
    accent: Color(0xFFFFFFFF), // White
  ),
  BasketballTeamLivery(
    id: 'nets',
    name: 'Brooklyn',
    primary: Color(0xFF000000), // Black
    secondary: Color(0xFFFFFFFF), // White
    accent: Color(0xFF707271), // Grey
  ),
  BasketballTeamLivery(
    id: 'spurs',
    name: 'San Antonio',
    primary: Color(0xFFC4CED4), // Silver
    secondary: Color(0xFF000000), // Black
    accent: Color(0xFFEF426F), // Pink
  ),
  BasketballTeamLivery(
    id: 'suns',
    name: 'Phoenix',
    primary: Color(0xFF1D1160), // Dark Purple
    secondary: Color(0xFFE56020), // Orange
    accent: Color(0xFFF9AD1B), // Yellow
  ),
  BasketballTeamLivery(
    id: 'bucks',
    name: 'Milwaukee',
    primary: Color(0xFF00471B), // Hunter Green
    secondary: Color(0xFFEEE1C6), // Cream
    accent: Color(0xFFFFFFFF), // White
  ),
  BasketballTeamLivery(
    id: 'mavs',
    name: 'Dallas',
    primary: Color(0xFF00538C), // Royal Blue
    secondary: Color(0xFFB8C4CA), // Silver
    accent: Color(0xFFFFFFFF), // White
  ),
  BasketballTeamLivery(
    id: 'nuggets',
    name: 'Denver',
    primary: Color(0xFF0E2240), // Midnight Blue
    secondary: Color(0xFFFEC524), // Sunshine Yellow
    accent: Color(0xFF8B2131), // Maroon
  ),
];

/// The one jersey every player starts with — no coin cost.
const basketballFreeTeamId = 'statoz';

/// Coin price for every non-free jersey in the Shop.
const basketballTeamCoinPrice = 100;

bool isBasketballTeamFree(BasketballTeamLivery team) =>
    team.id == basketballFreeTeamId;

int basketballTeamPrice(BasketballTeamLivery team) =>
    isBasketballTeamFree(team) ? 0 : basketballTeamCoinPrice;

/// Default owned jersey ids for a fresh wallet.
List<String> defaultOwnedBasketballTeamIds() => [basketballFreeTeamId];

/// Ensures the free jersey is always present and dedupes ids.
List<String> normalizeOwnedBasketballTeamIds(Iterable<String> ids) {
  final owned = ids.toSet()..add(basketballFreeTeamId);
  return owned.toList();
}

bool isBasketballTeamOwned(String teamId, Iterable<String> ownedTeamIds) =>
    isBasketballTeamFree(basketballTeamById(teamId)) ||
    ownedTeamIds.contains(teamId);

BasketballTeamLivery basketballTeamById(String id) {
  return basketballTeams.firstWhere(
    (team) => team.id == id,
    orElse: () => basketballTeams.first,
  );
}
```

### A.10 `lib/blocs/basketball/basketball_state.dart`

<sub>92 lines</sub>

```dart
import '../../models/basketball.dart';

/// Coarse Hoop Duel session phases. The 60fps match itself lives in the Flame
/// game; this machine only drives screens/overlays.
enum BasketballPhase {
  /// Hub/lobby — no match built.
  idle,

  /// Matchmaking VS card + tip-off countdown.
  intro,

  /// A half (or overtime) is live.
  playing,

  /// Between halves — substitution overlay.
  halftime,

  /// Scores level after H2 — the OVERTIME stinger beat.
  overtimeBreak,

  /// Match decided; the screen plays its final beat before the overlay.
  finished,

  /// Result overlay is up.
  result,
}

class BasketballState {
  const BasketballState({
    this.loading = true,
    this.stats = const BasketballStats(),
    this.rosterIds = const [],
    this.starterId,
    this.difficulty = BasketballDifficulty.pro,
    this.phase = BasketballPhase.idle,
    this.halfIndex = 0,
    this.config,
    this.summary,
    this.xp = 0,
    this.teamId = 'statoz',
  });

  final bool loading;
  final BasketballStats stats;

  /// Lobby roster selection (exactly 3 to play).
  final List<String> rosterIds;
  final String? starterId;
  final BasketballDifficulty difficulty;

  final BasketballPhase phase;

  /// 0/1 = halves, 2 = overtime.
  final int halfIndex;
  final BasketballMatchConfig? config;
  final BasketballMatchSummary? summary;
  final int xp;
  final String teamId;

  bool get rosterReady =>
      rosterIds.length == 3 &&
      starterId != null &&
      rosterIds.contains(starterId);

  BasketballState copyWith({
    bool? loading,
    BasketballStats? stats,
    List<String>? rosterIds,
    String? starterId,
    BasketballDifficulty? difficulty,
    BasketballPhase? phase,
    int? halfIndex,
    BasketballMatchConfig? config,
    BasketballMatchSummary? summary,
    int? xp,
    String? teamId,
    bool clearMatch = false,
    bool clearStarter = false,
  }) => BasketballState(
    loading: loading ?? this.loading,
    stats: stats ?? this.stats,
    rosterIds: rosterIds ?? this.rosterIds,
    starterId: clearStarter ? null : (starterId ?? this.starterId),
    difficulty: difficulty ?? this.difficulty,
    phase: phase ?? this.phase,
    halfIndex: halfIndex ?? this.halfIndex,
    config: clearMatch ? null : (config ?? this.config),
    summary: clearMatch ? null : (summary ?? this.summary),
    xp: clearMatch ? 0 : (xp ?? this.xp),
    teamId: teamId ?? this.teamId,
  );
}
```

### A.11 `lib/blocs/basketball/basketball_cubit.dart`

<sub>241 lines</sub>

```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/basketball_athletes.dart';
import '../../data/basketball_teams.dart';
import '../../models/basketball.dart';
import '../../models/progression.dart';
import '../../services/secure_storage_service.dart';
import 'basketball_state.dart';

/// Drives a Hoop Duel session: lobby roster/difficulty selections, the
/// intro → halves → halftime → overtime → result phase machine, and stats
/// persistence.
///
/// The 60fps simulation never touches this cubit — the Flame game owns the
/// engine and the match screen forwards only coarse beats (half ended, match
/// ended). Rewards are dispatched by the match screen (GameBloc lives in the
/// widget tree), mirroring the Grand Prix / Football Chess pattern.
class BasketballCubit extends Cubit<BasketballState> {
  BasketballCubit(this._storage, {Random? random})
    : _random = random ?? Random(),
      super(const BasketballState());

  final SecureGameStorage _storage;
  final Random _random;

  static const _defaultRoster = [
    'okc-shai-gilgeous-alexander',
    'den-nikola-jokic',
    'sas-victor-wembanyama',
  ];

  Future<void> load() async {
    final stats = await _storage.loadBasketballStats();
    final validIds = {for (final athlete in basketballAthletes) athlete.id};
    var roster = [
      for (final id in stats.lastRosterIds)
        if (validIds.contains(id)) id,
    ];
    if (roster.toSet().length != 3) roster = List.of(_defaultRoster);
    final starter = roster.contains(stats.lastStarterId)
        ? stats.lastStarterId!
        : roster.first;
    emit(
      state.copyWith(
        loading: false,
        stats: stats,
        rosterIds: roster,
        starterId: starter,
        difficulty: stats.lastDifficulty,
        teamId: stats.lastTeamId,
      ),
    );
  }

  // -- lobby ------------------------------------------------------------------

  void toggleRoster(String id) {
    if (state.phase != BasketballPhase.idle) return;
    final roster = List.of(state.rosterIds);
    if (roster.contains(id)) {
      roster.remove(id);
    } else if (roster.length < 3) {
      roster.add(id);
    } else {
      return; // roster full — deselect someone first
    }
    var starter = state.starterId;
    if (starter != null && !roster.contains(starter)) {
      starter = roster.isEmpty ? null : roster.first;
    }
    starter ??= roster.isEmpty ? null : roster.first;
    emit(
      state.copyWith(
        rosterIds: roster,
        starterId: starter,
        clearStarter: starter == null,
      ),
    );
    _persistSelections();
  }

  void setStarter(String id) {
    if (!state.rosterIds.contains(id)) return;
    emit(state.copyWith(starterId: id));
    _persistSelections();
  }

  void setDifficulty(BasketballDifficulty difficulty) {
    emit(state.copyWith(difficulty: difficulty));
    _persistSelections();
  }

  /// Clamps an equipped jersey the player no longer owns back to the free one.
  void ensureEquippedTeamOwned(Iterable<String> ownedTeamIds) {
    if (isBasketballTeamOwned(state.teamId, ownedTeamIds)) return;
    setTeamId(basketballFreeTeamId, ownedTeamIds: ownedTeamIds);
  }

  void setTeamId(String teamId, {required Iterable<String> ownedTeamIds}) {
    if (!isBasketballTeamOwned(teamId, ownedTeamIds)) return;
    if (teamId == state.teamId) return;
    emit(state.copyWith(teamId: teamId));
    _persistSelections();
  }

  void _persistSelections() {
    final stats = state.stats.copyWith(
      lastRosterIds: state.rosterIds,
      lastStarterId: state.starterId,
      lastDifficulty: state.difficulty,
      lastTeamId: state.teamId,
    );
    emit(state.copyWith(stats: stats));
    unawaited(_storage.saveBasketballStats(stats));
  }

  // -- match lifecycle ----------------------------------------------------------

  /// Builds a fresh seeded match from the lobby selections and enters the
  /// intro (VS + countdown). The Flame game is constructed from this config.
  void buildMatch() {
    if (!state.rosterReady) return;
    buildMatchFromRoster(
      rosterIds: state.rosterIds,
      starterId: state.starterId!,
    );
  }

  void buildMatchFromRoster({
    required List<String> rosterIds,
    required String starterId,
  }) {
    if (rosterIds.length != 3 || !rosterIds.contains(starterId)) return;
    final validIds = {for (final athlete in basketballAthletes) athlete.id};
    if (!rosterIds.every(validIds.contains)) return;
    final playerRoster = [
      for (final id in rosterIds) basketballAthleteById(id),
    ];
    final cpuPool = List.of(basketballAthletes)..shuffle(_random);
    final cpuRoster = cpuPool.take(3).toList();
    final rivalLiveries = [
      for (final team in basketballTeams)
        if (team.id != state.teamId) team.id,
    ]..shuffle(_random);
    final config = BasketballMatchConfig(
      playerRoster: playerRoster,
      playerStarterIndex: rosterIds.indexOf(starterId),
      cpuRoster: cpuRoster,
      cpuStarterIndex: _random.nextInt(cpuRoster.length),
      difficulty: state.difficulty,
      seed: _random.nextInt(1 << 31),
      showHints: !state.stats.hintsSeen,
      teamId: state.teamId,
      cpuTeamId: rivalLiveries.first,
    );
    emit(
      state.copyWith(
        phase: BasketballPhase.intro,
        halfIndex: 0,
        config: config,
        rosterIds: rosterIds,
        starterId: starterId,
        xp: 0,
      ),
    );
  }

  /// Tip-off countdown finished — the screen starts half 1 on the game.
  void beginPlay() {
    if (state.phase != BasketballPhase.intro) return;
    emit(state.copyWith(phase: BasketballPhase.playing, halfIndex: 0));
  }

  void onHalfEnded({required int halfIndex, required bool needsOvertime}) {
    if (state.phase != BasketballPhase.playing) return;
    if (halfIndex == 0) {
      emit(state.copyWith(phase: BasketballPhase.halftime));
    } else if (needsOvertime) {
      emit(state.copyWith(phase: BasketballPhase.overtimeBreak));
    }
  }

  /// Halftime overlay confirmed — the screen applies rest/subs + starts H2.
  void resumeSecondHalf() {
    if (state.phase != BasketballPhase.halftime) return;
    emit(state.copyWith(phase: BasketballPhase.playing, halfIndex: 1));
  }

  /// OVERTIME stinger finished — sudden death.
  void beginOvertime() {
    if (state.phase != BasketballPhase.overtimeBreak) return;
    emit(state.copyWith(phase: BasketballPhase.playing, halfIndex: 2));
  }

  Future<void> onMatchEnded(BasketballMatchSummary summary) async {
    if (state.phase != BasketballPhase.playing) return;
    final xp = calculateBasketballXP(
      won: summary.won,
      margin: summary.margin,
      overtime: summary.overtime,
    );
    final stats = state.stats.recordResult(summary);
    emit(
      state.copyWith(
        phase: BasketballPhase.finished,
        summary: summary,
        xp: xp,
        stats: stats,
      ),
    );
    await _storage.saveBasketballStats(stats);
  }

  /// The match screen calls this after its final beat to raise the overlay.
  void showResult() {
    if (state.phase != BasketballPhase.finished) return;
    emit(state.copyWith(phase: BasketballPhase.result));
  }

  /// The first-match control hints have served their purpose.
  void markHintsSeen() {
    if (state.stats.hintsSeen) return;
    final stats = state.stats.copyWith(hintsSeen: true);
    emit(state.copyWith(stats: stats));
    unawaited(_storage.saveBasketballStats(stats));
  }

  /// Leaving mid-match discards the attempt — no stats, no reward (spec).
  void abandonMatch() {
    emit(
      state.copyWith(
        phase: BasketballPhase.idle,
        halfIndex: 0,
        clearMatch: true,
      ),
    );
  }
}
```

## Appendix B — Play-layer widgets (verbatim)

Controls and HUD. These compile against Appendix A + D with no edits.

### B.1 `lib/screens/basketball/widgets/basketball_controls.dart`

<sub>391 lines</sub>

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/basketball/basketball_engine.dart';
import '../../../games/basketball/basketball_game.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// The Hoop Duel control deck: a MOVE pad (◀ away / ▶ to rim) on the left and
/// a contextual ACTION pad on the right. Both are raw [Listener]s (not
/// GestureDetectors) so move-hold and action-hold register simultaneously —
/// the same multi-touch reason Grand Prix uses hold pads. Double-tap a move
/// arrow to burst-drive; hold ACTION and release for a jump shot; tap it for a
/// layup / pump-fake / steal by context; swipe it away from the rim to
/// step-back. Pads are calm plates; pressed state is an accent fill, never a
/// glow (only the on-court ball-handler glows).
class BasketballControls extends StatelessWidget {
  const BasketballControls({
    required this.game,
    this.showHints = false,
    super.key,
  });

  final BasketballGame game;
  final bool showHints;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _MovePad(game: game, showHint: showHints),
          const Spacer(),
          _ActionPad(game: game, showHint: showHints),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Move pad
// ---------------------------------------------------------------------------

class _MovePad extends StatefulWidget {
  const _MovePad({required this.game, required this.showHint});

  final BasketballGame game;
  final bool showHint;

  @override
  State<_MovePad> createState() => _MovePadState();
}

class _MovePadState extends State<_MovePad> {
  bool _left = false;
  bool _right = false;
  DateTime? _lastTapAway;
  DateTime? _lastTapRim;

  void _apply() {
    final axis = (_right ? 1.0 : 0.0) - (_left ? 1.0 : 0.0);
    widget.game.setMoveAxis(axis);
  }

  void _set({bool? left, bool? right}) {
    if (left != null) _left = left;
    if (right != null) _right = right;
    _apply();
    if (mounted) setState(() {});
  }

  void _maybeBurst(bool toRim) {
    final now = DateTime.now();
    final last = toRim ? _lastTapRim : _lastTapAway;
    if (last != null && now.difference(last).inMilliseconds < 260) {
      widget.game.tapBurst();
      HapticFeedback.lightImpact();
    }
    if (toRim) {
      _lastTapRim = now;
    } else {
      _lastTapAway = now;
    }
  }

  @override
  void dispose() {
    widget.game.setMoveAxis(0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHint) const _HintLabel('MOVE'),
        Row(
          children: [
            _DirButton(
              icon: Icons.chevron_left,
              down: _left,
              onDown: () {
                _maybeBurst(false);
                _set(left: true);
              },
              onUp: () => _set(left: false),
            ),
            const SizedBox(width: 10),
            _DirButton(
              icon: Icons.chevron_right,
              down: _right,
              onDown: () {
                _maybeBurst(true);
                _set(right: true);
              },
              onUp: () => _set(right: false),
            ),
          ],
        ),
      ],
    );
  }
}

class _DirButton extends StatelessWidget {
  const _DirButton({
    required this.icon,
    required this.down,
    required this.onDown,
    required this.onUp,
  });

  final IconData icon;
  final bool down;
  final VoidCallback onDown;
  final VoidCallback onUp;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => onDown(),
      onPointerUp: (_) => onUp(),
      onPointerCancel: (_) => onUp(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 90),
        width: 64,
        height: 68,
        decoration: BoxDecoration(
          color: down
              ? Cyber.cyan.withValues(alpha: 0.26)
              : Cyber.panel.withValues(alpha: 0.85),
          border: Border.all(
            color: Cyber.cyan.withValues(alpha: down ? 0.9 : 0.4),
            width: down ? 1.6 : 1,
          ),
        ),
        child: Icon(
          icon,
          color: down ? Cyber.cyan : Cyber.cyan.withValues(alpha: 0.75),
          size: 32,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action pad
// ---------------------------------------------------------------------------

class _ActionPad extends StatefulWidget {
  const _ActionPad({required this.game, required this.showHint});

  final BasketballGame game;
  final bool showHint;

  @override
  State<_ActionPad> createState() => _ActionPadState();
}

class _ActionPadState extends State<_ActionPad> {
  bool _down = false;
  Offset _start = Offset.zero;
  bool _swiped = false;

  void _onDown(PointerDownEvent event) {
    _down = true;
    _swiped = false;
    _start = event.position;
    widget.game.actionPressed();
    if (mounted) setState(() {});
  }

  void _onMove(PointerMoveEvent event) {
    if (!_down || _swiped) return;
    final delta = event.position - _start;
    // Swipe away from the rim (leftward) with intent → step-back.
    if (delta.dx < -34 && delta.dx.abs() > delta.dy.abs()) {
      _swiped = true;
      widget.game.swipeBack();
      HapticFeedback.selectionClick();
      _down = false;
      if (mounted) setState(() {});
    }
  }

  void _onUp(PointerUpEvent event) {
    if (!_down) return;
    _down = false;
    widget.game.actionReleased();
    if (mounted) setState(() {});
  }

  void _onCancel(PointerCancelEvent event) {
    if (!_down) return;
    _down = false;
    widget.game.actionReleased();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const clipper = HudChamferClipper(bigCut: 12, smallCut: 4);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.showHint) const _HintLabel('ACTION'),
        Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onDown,
          onPointerMove: _onMove,
          onPointerUp: _onUp,
          onPointerCancel: _onCancel,
          child: ValueListenableBuilder<BasketballActionCue>(
            valueListenable: widget.game.actionCue,
            builder: (context, cue, _) => ChamferedActionSurface(
              clipper: clipper,
              borderColor: Cyber.gold.withValues(alpha: _down ? 0.9 : 0.45),
              borderWidth: _down ? 1.7 : 1,
              child: AnimatedContainer(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 90),
                width: 150,
                height: 68,
                color: _down
                    ? Cyber.gold.withValues(alpha: 0.26)
                    : Cyber.panel.withValues(alpha: 0.9),
                alignment: Alignment.center,
                child: AnimatedSwitcher(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 140),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: _ActionCueCopy(
                    key: ValueKey(cue),
                    cue: cue,
                    down: _down,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCueCopy extends StatelessWidget {
  const _ActionCueCopy({required this.cue, required this.down, super.key});

  final BasketballActionCue cue;
  final bool down;

  @override
  Widget build(BuildContext context) {
    final (label, instruction, icon) = switch (cue) {
      BasketballActionCue.shoot => (
        'SHOOT',
        'HOLD · RELEASE IN LIME',
        Icons.sports_basketball,
      ),
      BasketballActionCue.finish => (
        'FINISH',
        'TAP LAYUP · HOLD DUNK',
        Icons.sports_handball,
      ),
      BasketballActionCue.release => (
        'RELEASE',
        'HIT THE LIME',
        Icons.vertical_align_top,
      ),
      BasketballActionCue.defend => (
        'DEFEND',
        'TAP STEAL · HOLD GUARD',
        Icons.shield_outlined,
      ),
      BasketballActionCue.block => (
        'BLOCK',
        'RELEASE WITH SHOOTER',
        Icons.pan_tool_alt_outlined,
      ),
      BasketballActionCue.rebound => (
        'REBOUND',
        'TAP AT MARKER',
        Icons.keyboard_double_arrow_up,
      ),
    };
    final accent = down ? Cyber.gold : Cyber.gold.withValues(alpha: 0.86);

    return Semantics(
      label: '$label. $instruction',
      child: ExcludeSemantics(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accent, size: 17),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: Cyber.display(11, color: accent, letterSpacing: 1.4),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              instruction,
              maxLines: 1,
              style: Cyber.label(
                6.5,
                color: down ? Cyber.gold : Cyber.muted,
                letterSpacing: 0.65,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintLabel extends StatelessWidget {
  const _HintLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, child) =>
            Opacity(opacity: (0.5 + 0.5 * t).clamp(0.0, 1.0), child: child),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Cyber.bg.withValues(alpha: 0.7),
            border: Border.all(color: Cyber.gold.withValues(alpha: 0.5)),
          ),
          child: Text(
            text,
            style: Cyber.label(8, color: Cyber.gold, letterSpacing: 1.4),
          ),
        ),
      ),
    );
  }
}
```

### B.2 `lib/screens/basketball/widgets/basketball_hud.dart`

<sub>455 lines</sub>

```dart
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/basketball/basketball_cubit.dart';
import '../../../blocs/basketball/basketball_state.dart';
import '../../../config/theme.dart';
import '../../../games/basketball/basketball_engine.dart';
import '../../../games/basketball/basketball_game.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Top HUD bar: exit · MY score — half clock / shot clock — CPU score, with
/// heat meters under each score. Clocks/meters ride the game's
/// [ValueNotifier]s (never bloc state @60fps); the half label is the one
/// coarse read from the cubit.
class BasketballHudBar extends StatelessWidget {
  const BasketballHudBar({required this.game, required this.onExit, super.key});

  final BasketballGame game;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 10),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconButton(
            onPressed: onExit,
            icon: const Icon(Icons.close, color: Cyber.muted, size: 20),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gap = constraints.maxWidth < 260 ? 6.0 : 14.0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ScoreBlock(
                      label: 'YOU',
                      accent: Cyber.cyan,
                      score: game.scorePlayer,
                      heat: game.heatPlayer,
                      heatActive: game.heatActivePlayer,
                      possession: game.possession,
                      team: 0,
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.topCenter,
                        child: _ClockCluster(game: game),
                      ),
                    ),
                    SizedBox(width: gap),
                    _ScoreBlock(
                      label: 'CPU',
                      accent: Cyber.magenta,
                      score: game.scoreCpu,
                      heat: game.heatCpu,
                      heatActive: game.heatActiveCpu,
                      possession: game.possession,
                      team: 1,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({
    required this.label,
    required this.accent,
    required this.score,
    required this.heat,
    required this.heatActive,
    required this.possession,
    required this.team,
  });

  final String label;
  final Color accent;
  final ValueListenable<int> score;
  final ValueListenable<double> heat;
  final ValueListenable<bool> heatActive;
  final ValueListenable<int> possession;
  final int team;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<int>(
              valueListenable: possession,
              builder: (context, holder, _) => AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: holder == team ? 1 : 0,
                child: Icon(
                  Icons.sports_basketball,
                  size: 10,
                  color: Cyber.amber,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.6),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ValueListenableBuilder<int>(
          valueListenable: score,
          builder: (context, value, _) => Text(
            '$value',
            style: Cyber.display(
              26,
              color: accent,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 58,
          child: ValueListenableBuilder<bool>(
            valueListenable: heatActive,
            builder: (context, active, _) => ValueListenableBuilder<double>(
              valueListenable: heat,
              builder: (context, value, _) => Column(
                children: [
                  AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 140),
                    child: Text(
                      active ? 'ON FIRE' : 'HEAT',
                      key: ValueKey(active),
                      style: Cyber.label(
                        5.5,
                        color: active ? Cyber.gold : Cyber.muted,
                        letterSpacing: active ? 0.8 : 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  CyberProgressBar(
                    value: active ? 1 : value,
                    accent: active ? Cyber.gold : accent,
                    height: 4,
                    radius: 2,
                    animate: false,
                    trackColor: accent.withValues(alpha: 0.14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClockCluster extends StatelessWidget {
  const _ClockCluster({required this.game});

  final BasketballGame game;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        BlocBuilder<BasketballCubit, BasketballState>(
          buildWhen: (p, c) => p.halfIndex != c.halfIndex,
          builder: (context, state) => Text(
            switch (state.halfIndex) {
              0 => '1ST HALF',
              1 => '2ND HALF',
              _ => 'OVERTIME',
            },
            style: Cyber.label(
              8,
              color: state.halfIndex >= 2 ? Cyber.gold : Cyber.muted,
              letterSpacing: 1.8,
            ),
          ),
        ),
        const SizedBox(height: 2),
        BlocBuilder<BasketballCubit, BasketballState>(
          buildWhen: (p, c) => p.halfIndex != c.halfIndex,
          builder: (context, state) => state.halfIndex >= 2
              ? Text(
                  'SUDDEN DEATH',
                  style: Cyber.display(
                    14,
                    color: Cyber.gold,
                    letterSpacing: 1.5,
                  ),
                )
              : ValueListenableBuilder<int>(
                  valueListenable: game.halfClockTenths,
                  builder: (context, tenths, _) {
                    final seconds = tenths / 10;
                    final danger = seconds <= 10;
                    return Text(
                      seconds >= 10
                          ? '0:${seconds.floor().toString().padLeft(2, '0')}'
                          : seconds.toStringAsFixed(1),
                      style:
                          Cyber.display(
                            20,
                            color: danger ? Cyber.danger : Colors.white,
                          ).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 3),
        ValueListenableBuilder<int>(
          valueListenable: game.shotClockSeconds,
          builder: (context, clock, _) {
            final danger = clock <= 3;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.6),
                border: Border.all(
                  color: (danger ? Cyber.danger : Cyber.gold).withValues(
                    alpha: 0.55,
                  ),
                ),
              ),
              child: Text(
                'SHOT $clock',
                style: Cyber.label(
                  8.5,
                  color: danger ? Cyber.danger : Cyber.gold,
                  letterSpacing: 1.2,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stamina rail (sits just above the control deck)
// ---------------------------------------------------------------------------

class BasketballStaminaRail extends StatelessWidget {
  const BasketballStaminaRail({required this.game, super.key});

  final BasketballGame game;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'STAMINA',
            style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 1.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ValueListenableBuilder<double>(
              valueListenable: game.stamina01,
              builder: (context, value, _) => Row(
                children: [
                  Expanded(
                    child: CyberProgressBar(
                      value: value,
                      accent: value < 0.3 ? Cyber.danger : Cyber.success,
                      height: 5,
                      radius: 2,
                      animate: false,
                      trackColor: Cyber.success.withValues(alpha: 0.12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${(value * 100).round()}%',
                      textAlign: TextAlign.right,
                      style:
                          Cyber.label(
                            7.5,
                            color: value < 0.3 ? Cyber.danger : Cyber.muted,
                            letterSpacing: 0.5,
                          ).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shot meter — anchored above the action pad while a shot is gathering
// ---------------------------------------------------------------------------

class BasketballShotMeter extends StatefulWidget {
  const BasketballShotMeter({required this.game, super.key});

  final BasketballGame game;

  @override
  State<BasketballShotMeter> createState() => _BasketballShotMeterState();
}

class _BasketballShotMeterState extends State<BasketballShotMeter> {
  bool _wasHot = false;

  void _syncHot(bool hot) {
    if (hot == _wasHot) return;
    _wasHot = hot;
    if (hot) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) HapticFeedback.lightImpact();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShotMeterView?>(
      valueListenable: widget.game.meter,
      builder: (context, view, _) {
        if (view == null) {
          _syncHot(false);
          return const SizedBox.shrink();
        }
        final hot =
            (view.progress - view.perfectCenter).abs() <= view.perfectHalf;
        _syncHot(hot);
        return CyberChargeMeter(
          view: ChargeMeterView(
            progress: view.progress,
            perfectCenter: view.perfectCenter,
            perfectHalf: view.perfectHalf,
            goodHalf: view.goodHalf,
            hot: hot,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sting banners (PERFECT RELEASE / ANKLE BREAKER / …)
// ---------------------------------------------------------------------------

class BasketballStingLayer extends StatelessWidget {
  const BasketballStingLayer({required this.game, super.key});

  final BasketballGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BasketballSting?>(
      valueListenable: game.sting,
      builder: (context, sting, _) {
        if (sting == null) return const SizedBox.shrink();
        final major = sting.major;
        return Align(
          alignment: Alignment(0, major ? -0.34 : -0.5),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(sting.id),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: major ? 1600 : 1100),
            builder: (context, t, child) {
              final appear = (t * 5).clamp(0.0, 1.0);
              final fade = t > 0.72 ? (1 - (t - 0.72) / 0.28) : 1.0;
              return Opacity(
                // Clamped: binary-float fade math can dip below 0 at t == 1.
                opacity: (appear * fade).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: major
                      ? 1.6 - 0.6 * Curves.easeOutBack.transform(appear)
                      : 1.0,
                  child: Transform.translate(
                    offset: Offset(0, (1 - appear) * 8),
                    child: child,
                  ),
                ),
              );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: major ? 18 : 10,
                vertical: major ? 8 : 4,
              ),
              decoration: BoxDecoration(
                color: Cyber.bg.withValues(alpha: 0.82),
                border: Border.all(
                  color: sting.color.withValues(alpha: 0.8),
                  width: major ? 1.6 : 1,
                ),
                boxShadow: major ? Cyber.glow(sting.color, alpha: 0.4) : null,
              ),
              child: Text(
                sting.label,
                style: Cyber.display(
                  major ? 18 : 11,
                  color: sting.color,
                  letterSpacing: major ? 2.4 : 1.4,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
```

### B.3 `lib/screens/basketball/widgets/basketball_overlays.dart`

<sub>283 lines</sub>

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/basketball_athletes.dart';
import '../../../games/basketball/basketball_game.dart';
import '../../../models/basketball.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

/// Halftime: score check + pick who plays the second half (fresh legs beat).
class BasketballHalftimeOverlay extends StatefulWidget {
  const BasketballHalftimeOverlay({
    required this.game,
    required this.rosterIds,
    required this.onResume,
    super.key,
  });

  final BasketballGame game;
  final List<String> rosterIds;

  /// Called with the roster index to field for H2 (may equal the active one).
  final ValueChanged<int> onResume;

  @override
  State<BasketballHalftimeOverlay> createState() =>
      _BasketballHalftimeOverlayState();
}

class _BasketballHalftimeOverlayState extends State<BasketballHalftimeOverlay> {
  late int _selected = widget.game.engine.teams[0].activeIndex;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final team = game.engine.teams[0];
    final activeIndex = team.activeIndex;
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.95),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    'HALFTIME',
                    style: Cyber.display(24, letterSpacing: 3).copyWith(
                      shadows: [
                        Shadow(
                          color: Cyber.gold.withValues(alpha: 0.5),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${game.scorePlayer.value}',
                        style: Cyber.display(30, color: Cyber.cyan),
                      ),
                      Text(
                        '  —  ',
                        style: Cyber.display(16, color: Cyber.muted),
                      ),
                      Text(
                        '${game.scoreCpu.value}',
                        style: Cyber.display(30, color: Cyber.magenta),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const SectionLabel(label: 'WHO TAKES THE SECOND HALF?'),
                const SizedBox(height: 4),
                const Text(
                  'The bench rested to full stamina.',
                  style: TextStyle(color: Cyber.muted, fontSize: 11),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < widget.rosterIds.length; i++) ...[
                  _SubCard(
                    athlete: basketballAthleteById(widget.rosterIds[i]),
                    stamina: i == activeIndex
                        ? game.engine.playerBody.stamina
                        : team.staminas[i],
                    wasOn: i == activeIndex,
                    selected: i == _selected,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      playSound(SoundEffect.cardSelect);
                      setState(() => _selected = i);
                    },
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 10),
                HudCtaButton(
                  label: 'START 2ND HALF',
                  icon: Icons.sports_basketball,
                  accent: Cyber.gold,
                  tapSound: SoundEffect.playMatch,
                  helper: _selected == activeIndex
                      ? 'STAY WITH ${basketballAthleteById(widget.rosterIds[_selected]).name}'
                      : 'SUB IN ${basketballAthleteById(widget.rosterIds[_selected]).name} — FRESH LEGS',
                  onTap: () => widget.onResume(_selected),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubCard extends StatelessWidget {
  const _SubCard({
    required this.athlete,
    required this.stamina,
    required this.wasOn,
    required this.selected,
    required this.onTap,
  });

  final BasketballAthlete athlete;
  final double stamina;
  final bool wasOn;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = basketballLookFor(athlete.id);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(look.accent.withValues(alpha: 0.12), Cyber.panel)
              : Cyber.panel,
          border: Border.all(
            color: selected ? look.accent : Cyber.border.withValues(alpha: 0.6),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: look.accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        athlete.name,
                        style: Cyber.display(13, letterSpacing: 1),
                      ),
                      const SizedBox(width: 8),
                      if (wasOn)
                        const CyberChip(label: 'ON COURT', color: Cyber.cyan)
                      else if (stamina >= 99)
                        const CyberChip(label: 'FRESH', color: Cyber.success),
                    ],
                  ),
                  const SizedBox(height: 6),
                  CyberProgressBar(
                    value: stamina / 100,
                    accent: stamina < 35 ? Cyber.danger : Cyber.success,
                    height: 5,
                    radius: 2,
                    animate: false,
                    trackColor: Cyber.success.withValues(alpha: 0.12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? look.accent : Cyber.muted,
            ),
          ],
        ),
      ),
    );
  }
}

/// OVERTIME stinger — sudden death, auto-advances (tap to skip).
class BasketballOvertimeOverlay extends StatefulWidget {
  const BasketballOvertimeOverlay({required this.onBegin, super.key});

  final VoidCallback onBegin;

  @override
  State<BasketballOvertimeOverlay> createState() =>
      _BasketballOvertimeOverlayState();
}

class _BasketballOvertimeOverlayState extends State<BasketballOvertimeOverlay> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    playSound(SoundEffect.riser);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 2200), _finish);
  }

  void _finish() {
    if (_done || !mounted) return;
    _done = true;
    widget.onBegin();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _finish,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.94),
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 600),
            builder: (context, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1.4 - 0.4 * Curves.easeOutBack.transform(t),
                child: child,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OVERTIME',
                  style: Cyber.display(34, color: Cyber.gold, letterSpacing: 4)
                      .copyWith(
                    shadows: [
                      Shadow(
                        color: Cyber.gold.withValues(alpha: 0.6),
                        blurRadius: 22,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'SUDDEN DEATH — FIRST BASKET WINS',
                  style: Cyber.label(10, color: Colors.white, letterSpacing: 2.4),
                ),
              ],
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

### C.1 `lib/screens/basketball/basketball_match_screen.dart`

<sub>409 lines</sub>

```dart
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/basketball/basketball_cubit.dart';
import '../../blocs/basketball/basketball_state.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../config/theme.dart';
import '../../games/basketball/basketball_engine.dart';
import '../../games/basketball/basketball_game.dart';
import '../../models/avatar_frame_option.dart';
import '../../models/avatar_option.dart';
import '../../models/basketball.dart';
import '../../models/progression.dart';
import '../../services/secure_storage_service.dart';
import '../../utils/game_audio_mappings.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/matchmaking/game_match_gate.dart';
import '../../widgets/matchmaking/game_matchmaking_config.dart';
import 'widgets/basketball_controls.dart';
import 'widgets/basketball_hud.dart';
import 'widgets/basketball_overlays.dart';
import 'widgets/basketball_result.dart';

/// The live duel: full-bleed Flame court under the score/clock HUD, the shot
/// meter, sting banners, the two-zone control deck, and the intro / halftime /
/// overtime / result overlays. The cubit owns the phase machine; the Flame
/// game owns the 60fps simulation; this screen bridges the two, maps engine
/// events to sound/haptics, and dispatches the reward exactly once.
class BasketballMatchScreen extends StatefulWidget {
  const BasketballMatchScreen({
    required this.onExit,
    required this.onRematch,
    super.key,
  });

  final VoidCallback onExit;
  final VoidCallback onRematch;

  @override
  State<BasketballMatchScreen> createState() => _BasketballMatchScreenState();
}

class _BasketballMatchScreenState extends State<BasketballMatchScreen> {
  late final BasketballCubit _cubit;
  late final BasketballGame _game;
  BasketballMatchConfig? _config;
  bool _rewardsDispatched = false;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<BasketballCubit>();
    _config = _cubit.state.config;
    final reducedMotion = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    _game = BasketballGame(
      config: _config!,
      onEvents: _onGameEvents,
      reducedMotion: reducedMotion,
    );
    AudioController.instance.enterScene(AudioScene.basketball);
  }

  @override
  void dispose() {
    AudioController.instance.leaveScene(AudioScene.basketball);
    // Leaving mid-match discards the attempt (no stats, no reward). A REMATCH
    // relaunch has already replaced the config by the time this route is
    // disposed — the identity check keeps us from resetting the new match.
    final phase = _cubit.state.phase;
    final midMatch =
        phase == BasketballPhase.intro ||
        phase == BasketballPhase.playing ||
        phase == BasketballPhase.halftime ||
        phase == BasketballPhase.overtimeBreak;
    if (midMatch && identical(_cubit.state.config, _config)) {
      _cubit.abandonMatch();
    }
    super.dispose();
  }

  // -- engine events → sound / haptics / cubit beats --------------------------

  void _onGameEvents(List<BasketballEvent> events) {
    for (final event in events) {
      switch (event.type) {
        case BasketballEventType.basketMade:
          playSound(basketballSoundForEvent(event.type)!);
          if (event.team == 0) HapticFeedback.mediumImpact();
        case BasketballEventType.shotMissed:
          playSound(basketballSoundForEvent(event.type)!);
        case BasketballEventType.dunk:
          playSound(basketballSoundForEvent(event.type)!);
          HapticFeedback.heavyImpact();
        case BasketballEventType.poster:
          playSound(basketballSoundForEvent(event.type)!);
        case BasketballEventType.block:
          playSound(basketballSoundForEvent(event.type)!);
          HapticFeedback.heavyImpact();
        case BasketballEventType.steal:
          playSound(basketballSoundForEvent(event.type)!);
          HapticFeedback.mediumImpact();
        case BasketballEventType.rebound:
          playSound(basketballSoundForEvent(event.type)!);
        case BasketballEventType.ankleBreaker:
          playSound(basketballSoundForEvent(event.type)!);
          HapticFeedback.mediumImpact();
        case BasketballEventType.spinMove:
          playSound(basketballSoundForEvent(event.type)!);
          if (event.team == 0) HapticFeedback.selectionClick();
        case BasketballEventType.crossover:
          if (event.team == 0) {
            playSound(basketballSoundForEvent(event.type)!);
          }
        case BasketballEventType.perfectRelease:
          if (event.team == 0) {
            playSound(basketballSoundForEvent(event.type)!);
            HapticFeedback.selectionClick();
          }
        case BasketballEventType.shotReleased:
          if (event.team == 0) {
            playSound(basketballSoundForEvent(event.type)!);
          }
        case BasketballEventType.heatStarted:
          playSound(basketballSoundForEvent(event.type)!);
          if (event.team == 0) HapticFeedback.mediumImpact();
        case BasketballEventType.heatEnded:
          playSound(basketballSoundForEvent(event.type)!);
        case BasketballEventType.shotClockViolation:
          playSound(basketballSoundForEvent(event.type)!);
        case BasketballEventType.buzzerBeater:
          playSound(basketballSoundForEvent(event.type)!);
          HapticFeedback.heavyImpact();
        case BasketballEventType.halfEnded:
          playSound(basketballSoundForEvent(event.type)!);
          HapticFeedback.heavyImpact();
          if (event.halfIndex == 0) _cubit.markHintsSeen();
          _cubit.onHalfEnded(
            halfIndex: event.halfIndex,
            needsOvertime: event.needsOvertime,
          );
        case BasketballEventType.overtimeStarted:
          playSound(basketballSoundForEvent(event.type)!);
        case BasketballEventType.substitution:
          playSound(basketballSoundForEvent(event.type)!);
        case BasketballEventType.stagger:
          playSound(basketballSoundForEvent(event.type)!);
        case BasketballEventType.matchEnded:
          _onMatchEnded();
      }
    }
  }

  void _onMatchEnded() {
    if (_rewardsDispatched) return;
    _rewardsDispatched = true;
    final summary = _game.summary();
    unawaited(_cubit.onMatchEnded(summary));
    final xp = _cubit.state.xp;
    context.read<GameBloc>().add(
      BasketballFinished(
        playerScore: summary.playerScore,
        cpuScore: summary.cpuScore,
        resultLabel: summary.won ? 'Victory' : 'Defeat',
        difficultyLabel: basketballDifficultyLabel(summary.difficulty),
        grade: summary.grade,
        overtime: summary.overtime,
        xp: xp,
      ),
    );
    playSound(summary.won ? SoundEffect.bbVictory : SoundEffect.bbDefeat);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _cubit.showResult();
    });
  }

  // -- phase transitions (driven by overlay callbacks, not listeners) ---------

  void _beginPlay() {
    _cubit.beginPlay();
    _game.startHalf(0);
  }

  void _resumeSecondHalf(int rosterIndex) {
    _game.halftimeRest();
    if (rosterIndex != _game.engine.teams[0].activeIndex) {
      _game.substitutePlayer(rosterIndex);
      playSound(SoundEffect.bbSubstitution);
    }
    _game.cpuAutoSubstitute();
    _cubit.resumeSecondHalf();
    _game.startHalf(1);
  }

  void _beginOvertime() {
    _cubit.beginOvertime();
    _game.startHalf(2);
  }

  Future<void> _confirmExit() async {
    final phase = _cubit.state.phase;
    if (phase == BasketballPhase.result || phase == BasketballPhase.finished) {
      widget.onExit();
      return;
    }
    _game.setPaused(true);
    AudioController.instance.setSceneMusicEnabled(false);
    final leave = await showCyberConfirmDialog(
      context,
      title: 'LEAVE THE COURT?',
      message: 'Walking out abandons the match — no XP, no record.',
      confirmLabel: 'Leave',
      cancelLabel: 'Keep playing',
      destructive: true,
    );
    if (leave) {
      widget.onExit();
    } else {
      _game.setPaused(false);
      AudioController.instance.setSceneMusicEnabled(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showHints = _config?.showHints ?? false;
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: _game)),
            Align(
              alignment: Alignment.topCenter,
              child: BasketballHudBar(game: _game, onExit: _confirmExit),
            ),
            BasketballStingLayer(game: _game),
            Positioned(
              right: 22,
              bottom: 168,
              child: BasketballShotMeter(game: _game),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BasketballStaminaRail(game: _game),
                  const SizedBox(height: 6),
                  BasketballControls(game: _game, showHints: showHints),
                ],
              ),
            ),
            _PhaseOverlays(
              game: _game,
              onBeginPlay: _beginPlay,
              onResumeSecondHalf: _resumeSecondHalf,
              onBeginOvertime: _beginOvertime,
              onRematch: widget.onRematch,
              onExit: widget.onExit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders the phase-scoped full-screen overlays (intro / halftime / overtime
/// break / result) from cubit state — builders see the mount phase, so no
/// initial-listener kick is needed.
class _PhaseOverlays extends StatelessWidget {
  const _PhaseOverlays({
    required this.game,
    required this.onBeginPlay,
    required this.onResumeSecondHalf,
    required this.onBeginOvertime,
    required this.onRematch,
    required this.onExit,
  });

  final BasketballGame game;
  final VoidCallback onBeginPlay;
  final ValueChanged<int> onResumeSecondHalf;
  final VoidCallback onBeginOvertime;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BasketballCubit, BasketballState>(
      buildWhen: (p, c) => p.phase != c.phase,
      builder: (context, state) {
        final config = state.config;
        switch (state.phase) {
          case BasketballPhase.intro:
            if (config == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: _HoopDuelMatchGate(
                config: config,
                onReady: onBeginPlay,
                onCancel: onExit,
              ),
            );
          case BasketballPhase.halftime:
            return Positioned.fill(
              child: BasketballHalftimeOverlay(
                game: game,
                rosterIds: state.rosterIds,
                onResume: onResumeSecondHalf,
              ),
            );
          case BasketballPhase.overtimeBreak:
            return Positioned.fill(
              child: BasketballOvertimeOverlay(onBegin: onBeginOvertime),
            );
          case BasketballPhase.result:
            final summary = state.summary;
            if (summary == null) return const SizedBox.shrink();
            return Positioned.fill(
              child: BasketballResultOverlay(
                summary: summary,
                xp: state.xp,
                stats: state.stats,
                onRematch: onRematch,
                onExit: onExit,
              ),
            );
          case BasketballPhase.idle:
          case BasketballPhase.playing:
          case BasketballPhase.finished:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _HoopDuelMatchGate extends StatefulWidget {
  const _HoopDuelMatchGate({
    required this.config,
    required this.onReady,
    required this.onCancel,
  });

  final BasketballMatchConfig config;
  final VoidCallback onReady;
  final VoidCallback onCancel;

  @override
  State<_HoopDuelMatchGate> createState() => _HoopDuelMatchGateState();
}

class _HoopDuelMatchGateState extends State<_HoopDuelMatchGate> {
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
    final level = game.progression.levelFor(ProgressTrack.hoopDuel);
    final playerAvatar = avatarOptionById(_selectedAvatarId);
    final frame = avatarFrameOptionById(game.equippedAvatarFrameId);
    final rival = widget.config.cpuRoster[widget.config.cpuStarterIndex];

    return GameMatchGate(
      goLabel: 'TIP OFF!',
      config: GameMatchmakingConfig(
        title: 'HOOP DUEL',
        queueLabel: 'SCANNING GLOBAL HOOP QUEUE',
        player: MatchmakingFighter(
          name: 'PLAYER ONE',
          avatarAsset: playerAvatar.assetPath,
          frame: frame,
          badge: 'LV $level',
        ),
        opponent: MatchmakingFighter(
          name: rival.name,
          avatarAsset: avatarForName(rival.name).assetPath,
          badge: 'LV $level',
        ),
      ),
      onReady: widget.onReady,
      onCancel: widget.onCancel,
    );
  }
}
```

### C.2 `lib/screens/basketball/widgets/basketball_result.dart`

<sub>394 lines</sub>

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/game/game_bloc.dart';
import '../../../config/theme.dart';
import '../../../models/basketball.dart';
import '../../../models/progression.dart';
import '../../../utils/sound_effects.dart';
import '../../../widgets/cyber/cyber_cta_button.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/level_up_celebration.dart';

/// Full-time result reveal: verdict banner → score + grade plate → box-score
/// grid → XP count-up + record → CTAs. Staged like the quiz/settlement
/// reveals (timer-driven beats, tap skips to the end); XP was credited before
/// this overlay is shown, so skipping changes nothing.
class BasketballResultOverlay extends StatefulWidget {
  const BasketballResultOverlay({
    required this.summary,
    required this.xp,
    required this.stats,
    required this.onRematch,
    required this.onExit,
    super.key,
  });

  final BasketballMatchSummary summary;
  final int xp;
  final BasketballStats stats;
  final VoidCallback onRematch;
  final VoidCallback onExit;

  @override
  State<BasketballResultOverlay> createState() =>
      _BasketballResultOverlayState();
}

class _BasketballResultOverlayState extends State<BasketballResultOverlay> {
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

  /// After the reveal lands, celebrate any levels this match's XP crossed —
  /// same beat as the Grand Prix result.
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
    final summary = widget.summary;
    final won = summary.won;
    final accent = won ? Cyber.success : Cyber.danger;
    return GestureDetector(
      onTap: _skip,
      child: ColoredBox(
        color: Cyber.bg.withValues(alpha: 0.97),
        child: Stack(
          children: [
            SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RevealIn(
                      visible: _stage >= 0,
                      child: Column(
                        children: [
                          Text(
                            won ? 'VICTORY' : 'DEFEAT',
                            textAlign: TextAlign.center,
                            style: Cyber.display(
                              32,
                              color: accent,
                              letterSpacing: 4,
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
                          if (summary.buzzerBeater || summary.overtime)
                            CyberChip(
                              label: summary.buzzerBeater
                                  ? 'BUZZER BEATER'
                                  : 'OVERTIME',
                              color: Cyber.gold,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RevealIn(
                      visible: _stage >= 1,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '${summary.playerScore}',
                            style: Cyber.display(40, color: Cyber.cyan)
                                .copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '—',
                              style: Cyber.display(20, color: Cyber.muted),
                            ),
                          ),
                          Text(
                            '${summary.cpuScore}',
                            style: Cyber.display(40, color: Cyber.magenta)
                                .copyWith(
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 22),
                          _GradePlate(grade: summary.grade),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _RevealIn(
                      visible: _stage >= 2,
                      child: _BoxScoreGrid(box: summary.box),
                    ),
                    const SizedBox(height: 18),
                    _RevealIn(
                      visible: _stage >= 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _XpLine(xp: widget.xp),
                          const SizedBox(height: 8),
                          Center(
                            child: Text(
                              'RECORD ${widget.stats.wins}W — ${widget.stats.losses}L'
                              '${widget.stats.currentStreak > 1 ? ' · ${widget.stats.currentStreak} STRAIGHT' : ''}',
                              style: Cyber.label(
                                9,
                                color: Cyber.muted,
                                letterSpacing: 1.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          HudCtaButton(
                            label: 'REMATCH',
                            icon: Icons.replay,
                            accent: Cyber.gold,
                            tapSound: SoundEffect.playMatch,
                            onTap: widget.onRematch,
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              widget.onExit();
                            },
                            child: Text(
                              'BACK TO COURT LOBBY',
                              style: Cyber.label(
                                10,
                                color: Cyber.muted,
                                letterSpacing: 2,
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
}

class _RevealIn extends StatelessWidget {
  const _RevealIn({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 340),
      opacity: visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 340),
        curve: Curves.easeOutCubic,
        offset: visible ? Offset.zero : const Offset(0, 0.08),
        child: child,
      ),
    );
  }
}

class _GradePlate extends StatelessWidget {
  const _GradePlate({required this.grade});

  final String grade;

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      'S' => Cyber.gold,
      'A' => Cyber.lime,
      'B' => Cyber.cyan,
      'C' => Cyber.amber,
      _ => Cyber.muted,
    };
    final elite = grade == 'S';
    return Container(
      width: 52,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Cyber.bg.withValues(alpha: 0.6),
        border: Border.all(color: color, width: 1.6),
        boxShadow: elite ? Cyber.glow(color, alpha: 0.5) : null,
      ),
      child: Text(
        grade,
        style: Cyber.display(26, color: color),
      ),
    );
  }
}

class _BoxScoreGrid extends StatelessWidget {
  const _BoxScoreGrid({required this.box});

  final BasketballBoxScore box;

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String)>[
      ('FG', box.attempts == 0 ? '—' : '${box.fgPercent}%'),
      ('PERFECT', '${box.perfectReleases}'),
      ('3PT MADE', '${box.threesMade}'),
      ('DUNKS', '${box.dunks}'),
      ('BLOCKS', '${box.blocks}'),
      ('STEALS', '${box.steals}'),
      ('BOARDS', '${box.rebounds}'),
      ('BEST RUN', '${box.bestRun}'),
    ];
    return CyberPanel(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) ...[
              const SizedBox(height: 10),
              const HudLine(),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                for (final entry in entries.sublist(row * 4, row * 4 + 4))
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          entry.$2,
                          style: Cyber.display(15).copyWith(
                            fontFeatures: const [
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          entry.$1,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Cyber.muted,
                            fontFamily: Cyber.displayFont,
                            fontSize: 6.8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _XpLine extends StatelessWidget {
  const _XpLine({required this.xp});

  final int xp;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => Text(
          '+${(xp * t).round()} XP',
          style: Cyber.display(22, color: Cyber.gold).copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            shadows: [
              Shadow(
                color: Cyber.gold.withValues(alpha: 0.5),
                blurRadius: 14,
              ),
            ],
          ),
        ),
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

<sub>22 lines</sub>

```dart
// STAND-IN for the host app's lib/models/progression.dart — only the
// functions these games call, copied verbatim. In the source app XP is
// banked by a global GameBloc; wire the returned value to your own
// progression system.
import 'dart:math';

double cpuSmartness(int level) => min(1.0, level / 12);

// XP for Hoop Duel — a two-half basketball duel on the same scale as the other
// arcade modes: a win scales with the margin (+16 base, +2 per point of
// margin, capped at Football Chess's +26 ceiling; +2 more for surviving
// overtime), a loss still earns a little (+6 if it forced overtime). XP only —
// the court never pays coins.
int calculateBasketballXP({
  required bool won,
  required int margin,
  required bool overtime,
}) {
  if (!won) return overtime ? 6 : 4;
  final base = min(26, 16 + margin * 2);
  return overtime ? min(26, base + 2) : base;
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

import '../models/basketball.dart';

class SecureGameStorage {
  static const _basketballStatsKey = 'pd_basketball_stats_v1';

  Future<BasketballStats> loadBasketballStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_basketballStatsKey);
      if (raw == null || raw.isEmpty) return const BasketballStats();
      return BasketballStats.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const BasketballStats();
    }
  }

  Future<void> saveBasketballStats(BasketballStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_basketballStatsKey, jsonEncode(stats.toJson()));
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

### E.1 `test/basketball_engine_test.dart`

_Verbatim except two tests removed because they cover the source app's card-collection system, which is out of scope: `basketball card rarities match the 12/36/60/72 distribution` and `every NBA team has enough basketball roles for deck building` (plus their two imports, `config/enums.dart` and `models/cards.dart`)._

<sub>832 lines</sub>

```dart
import 'dart:convert';

import 'package:card_game/blocs/basketball/basketball_cubit.dart';
import 'package:card_game/data/basketball_athletes.dart';
import 'package:card_game/games/basketball/basketball_ai.dart';
import 'package:card_game/games/basketball/basketball_engine.dart';
import 'package:card_game/games/basketball/basketball_tuning.dart';
import 'package:card_game/models/basketball.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _dt = 1 / 120;

BasketballMatchConfig _config({
  int seed = 7,
  BasketballDifficulty difficulty = BasketballDifficulty.pro,
  String starter = 'okc-shai-gilgeous-alexander',
}) {
  final starterAthlete = basketballAthleteById(starter);
  final rest = basketballAthletes
      .where((a) => a.id != starter)
      .take(2)
      .toList();
  return BasketballMatchConfig(
    playerRoster: [starterAthlete, ...rest],
    playerStarterIndex: 0,
    cpuRoster: [
      basketballAthleteById('sas-victor-wembanyama'),
      basketballAthleteById('phi-joel-embiid'),
      basketballAthleteById('was-anthony-davis'),
    ],
    cpuStarterIndex: 0,
    difficulty: difficulty,
    seed: seed,
  );
}

/// Engine already in half 1 with the PLAYER holding the ball.
BasketballEngine _playerBallEngine({
  int seed = 7,
  String starter = 'okc-shai-gilgeous-alexander',
}) {
  var s = seed;
  while (true) {
    final engine = BasketballEngine(_config(seed: s, starter: starter))
      ..startHalf(0);
    if (engine.possession == 0) return engine;
    s++;
  }
}

List<BasketballEvent> _run(
  BasketballEngine engine,
  double seconds, {
  BasketballIntent Function(int tick)? player,
  BasketballIntent Function(int tick)? cpu,
}) {
  final events = <BasketballEvent>[];
  final ticks = (seconds * 120).round();
  for (var i = 0; i < ticks; i++) {
    events.addAll(
      engine.step(
        player?.call(i) ?? BasketballIntent.idle,
        cpu?.call(i) ?? BasketballIntent.idle,
        _dt,
      ),
    );
  }
  return events;
}

/// Holds the action zone into a jump shot, releasing at [releaseFrac] of the
/// jump. Returns all events produced until just after the release.
List<BasketballEvent> _shoot(
  BasketballEngine engine, {
  required double releaseFrac,
}) {
  final events = <BasketballEvent>[];
  var held = 0.0;
  for (var i = 0; i < 600; i++) {
    final body = engine.playerBody;
    final releasing =
        body.body == BodyState.jump &&
        body.jumpPurpose == JumpPurpose.shot &&
        body.jumpT >= body.jumpDur * releaseFrac;
    if (releasing) {
      events.addAll(
        engine.step(
          BasketballIntent(actionReleased: true, heldSeconds: held),
          BasketballIntent.idle,
          _dt,
        ),
      );
      return events;
    }
    held += _dt;
    events.addAll(
      engine.step(
        BasketballIntent(
          actionDown: true,
          actionPressed: i == 0,
          heldSeconds: held,
        ),
        BasketballIntent.idle,
        _dt,
      ),
    );
  }
  return events;
}

/// Drives Giannis to the rim and dunks (dunks always score unless blocked).
List<BasketballEvent> _dunk(BasketballEngine engine) {
  final events = <BasketballEvent>[];
  var held = 0.0;
  for (var i = 0; i < 2400; i++) {
    final body = engine.playerBody;
    BasketballIntent intent;
    if (engine.ball.holder == 0 && !body.airborne) {
      if (body.body == BodyState.drive && body.d <= kBbDunkGateRimPressure) {
        held += _dt;
        intent = BasketballIntent(
          moveAxis: 1,
          actionDown: true,
          heldSeconds: held,
        );
      } else {
        held = 0;
        intent = BasketballIntent(
          moveAxis: 1,
          burst: body.body != BodyState.drive && body.stamina > 25,
        );
      }
    } else {
      // Airborne dunk or ball in flight — let it play out.
      intent = const BasketballIntent();
    }
    events.addAll(engine.step(intent, BasketballIntent.idle, _dt));
    if (events.any(
      (e) =>
          e.type == BasketballEventType.basketMade ||
          e.type == BasketballEventType.matchEnded,
    )) {
      break;
    }
  }
  return events;
}

bool _has(List<BasketballEvent> events, BasketballEventType type) =>
    events.any((e) => e.type == type);

void main() {
  group('match setup & flow', () {
    test('startHalf places offense at the check spot, ball live', () {
      final engine = _playerBallEngine();
      expect(engine.playPhase, PlayPhase.live);
      expect(engine.ball.phase, BallPhase.held);
      expect(engine.playerBody.x, closeTo(kBbCheckSpotX, 0.01));
      expect(engine.cpuBody.x, closeTo(kBbDefResetX, 0.01));
      expect(engine.shotClock, kBbShotClockSeconds);
    });

    test('half 2 possession flips relative to half 1', () {
      final engine = BasketballEngine(_config())..startHalf(0);
      final first = engine.possession;
      engine.startHalf(1);
      expect(engine.possession, 1 - first);
    });

    test('movement respects bounds and moves toward the rim', () {
      final engine = _playerBallEngine();
      final startX = engine.playerBody.x;
      _run(engine, 1, player: (_) => const BasketballIntent(moveAxis: 1));
      expect(engine.playerBody.x, greaterThan(startX));
      _run(engine, 30, player: (_) => const BasketballIntent(moveAxis: 1));
      expect(engine.playerBody.x, lessThanOrEqualTo(kBbCourtMaxX));
    });

    test('shot clock violation turns the ball over and resets', () {
      final engine = _playerBallEngine();
      final events = _run(engine, kBbShotClockSeconds + 2);
      expect(_has(events, BasketballEventType.shotClockViolation), isTrue);
      expect(engine.possession, 1);
      expect(engine.playPhase, PlayPhase.live);
      expect(engine.cpuBody.x, closeTo(kBbCheckSpotX, 0.05));
    });

    test('half ends at zero with a dead ball', () {
      final engine = _playerBallEngine();
      engine.halfClock = 0.3;
      final events = _run(engine, 1);
      expect(_has(events, BasketballEventType.halfEnded), isTrue);
      expect(engine.playPhase, PlayPhase.awaiting);
    });

    test('buzzer beater: half only ends after a live shot resolves', () {
      final engine = _playerBallEngine();
      // Long enough for the release to beat the buzzer, short enough that the
      // ball is still in the air when the clock hits zero.
      engine.halfClock = 0.6;
      final events = _shoot(engine, releaseFrac: 0.4);
      events.addAll(_run(engine, 3));
      final endIndex = events.indexWhere(
        (e) => e.type == BasketballEventType.halfEnded,
      );
      final resolveIndex = events.indexWhere(
        (e) =>
            e.type == BasketballEventType.basketMade ||
            e.type == BasketballEventType.shotMissed,
      );
      expect(endIndex, greaterThanOrEqualTo(0));
      expect(resolveIndex, greaterThanOrEqualTo(0));
      expect(endIndex, greaterThan(resolveIndex));
    });
  });

  group('shooting', () {
    test('release at apex grades perfect; extremes grade early/late', () {
      final apexFrac = kBbShotApexQuickRelease; // SGA has Quick Release
      final perfect = _shoot(_playerBallEngine(), releaseFrac: apexFrac);
      final released = perfect.firstWhere(
        (e) => e.type == BasketballEventType.shotReleased,
      );
      expect(released.grade, ReleaseGrade.perfect);
      expect(_has(perfect, BasketballEventType.perfectRelease), isTrue);

      final late_ = _shoot(_playerBallEngine(), releaseFrac: 0.95);
      expect(
        late_
            .firstWhere((e) => e.type == BasketballEventType.shotReleased)
            .grade,
        ReleaseGrade.late,
      );
    });

    test('zone and points come from the release position', () {
      final fromDeep = _playerBallEngine();
      final deepEvents = _shoot(fromDeep, releaseFrac: 0.36);
      expect(
        deepEvents
            .firstWhere((e) => e.type == BasketballEventType.shotReleased)
            .zone,
        ShotZone.three,
      );

      final fromMid = _playerBallEngine();
      fromMid.playerBody.x = kBbRimX - kBbCloseRange - 0.5;
      final midEvents = _shoot(fromMid, releaseFrac: 0.36);
      expect(
        midEvents
            .firstWhere((e) => e.type == BasketballEventType.shotReleased)
            .zone,
        ShotZone.mid,
      );
    });

    test('make probability is monotonic in grade, contest and distance', () {
      final engine = _playerBallEngine();
      final body = engine.playerBody;
      body.x = kBbRimX - kBbCloseRange - 0.4; // mid range
      engine.cpuBody.x = kBbCourtMinX; // no contest

      final perfect = engine.makeProbability(
        body,
        ShotZone.mid,
        ReleaseGrade.perfect,
        JumpPurpose.shot,
      );
      final good = engine.makeProbability(
        body,
        ShotZone.mid,
        ReleaseGrade.good,
        JumpPurpose.shot,
      );
      final early = engine.makeProbability(
        body,
        ShotZone.mid,
        ReleaseGrade.early,
        JumpPurpose.shot,
      );
      expect(perfect, greaterThan(good));
      expect(good, greaterThan(early));

      // Contest suppresses.
      engine.cpuBody
        ..x = body.x + 0.5
        ..enter(BodyState.stance);
      final contested = engine.makeProbability(
        body,
        ShotZone.mid,
        ReleaseGrade.good,
        JumpPurpose.shot,
      );
      expect(contested, lessThan(good));

      // Deeper threes are harder (no Deep Range on SGA).
      engine.cpuBody.x = kBbCourtMinX;
      body.x = kBbRimX - kBbArcDist - 0.1;
      final atLine = engine.makeProbability(
        body,
        ShotZone.three,
        ReleaseGrade.good,
        JumpPurpose.shot,
      );
      body.x = kBbRimX - kBbArcDist - 2.5;
      final deep = engine.makeProbability(
        body,
        ShotZone.three,
        ReleaseGrade.good,
        JumpPurpose.shot,
      );
      expect(deep, lessThan(atLine));

      // Probabilities stay inside the clamp.
      expect(perfect, lessThanOrEqualTo(kBbShotCapPerfect));
      expect(deep, greaterThanOrEqualTo(kBbShotFloor));
    });

    test('perfect window shrinks when tired and grows on heat', () {
      final engine = _playerBallEngine();
      final body = engine.playerBody;
      final fresh = engine.perfectHalfWindow(body);
      body.stamina = 15;
      final tired = engine.perfectHalfWindow(body);
      expect(tired, lessThan(fresh));
      body.stamina = 100;
      engine.teams[0].heatActive = true;
      final hot = engine.perfectHalfWindow(body);
      expect(hot, greaterThan(fresh));
    });
  });

  group('possession', () {
    test('a shot from inside resolves immediately — no clear required', () {
      final engine = _playerBallEngine();
      engine.playerBody.x = kBbRimX - kBbLayupRange; // inside the arc
      final shot = _shoot(engine, releaseFrac: 0.4);
      expect(_has(shot, BasketballEventType.shotReleased), isTrue);
    });
  });

  group('defense', () {
    test('a whiffed lunge locks the defender out', () {
      final engine = _playerBallEngine();
      engine.cpuBody.x = engine.playerBody.x + 3; // far away — pure whiff
      _run(
        engine,
        0.1,
        cpu: (i) => BasketballIntent(
          actionPressed: i == 0,
          actionReleased: i == 0,
          heldSeconds: 0.05,
        ),
      );
      expect(engine.cpuBody.body, BodyState.lunge);
      _run(engine, 0.4);
      expect(engine.cpuBody.recoverT, greaterThan(0));
    });

    test('exposed dribbles are stolen more often than protected ones', () {
      var protectedSteals = 0;
      var exposedSteals = 0;
      for (var seed = 0; seed < 150; seed++) {
        // Protected: stationary, guarded handler.
        final a = _playerBallEngine(seed: seed * 3 + 1);
        a.cpuBody.x = a.playerBody.x + 0.9;
        final eventsA = _run(
          a,
          0.4,
          cpu: (i) => i == 2
              ? const BasketballIntent(
                  actionPressed: true,
                  actionReleased: true,
                  heldSeconds: 0.05,
                )
              : BasketballIntent.idle,
        );
        if (_has(eventsA, BasketballEventType.steal)) protectedSteals++;

        // Exposed: handler bursts into a drive as the defender lunges.
        final b = _playerBallEngine(seed: seed * 3 + 1);
        b.cpuBody.x = b.playerBody.x + 0.9;
        final eventsB = _run(
          b,
          0.4,
          player: (i) => BasketballIntent(moveAxis: 1, burst: i == 0),
          cpu: (i) => i == 2
              ? const BasketballIntent(
                  actionPressed: true,
                  actionReleased: true,
                  heldSeconds: 0.05,
                )
              : BasketballIntent.idle,
        );
        if (_has(eventsB, BasketballEventType.steal)) exposedSteals++;
      }
      expect(exposedSteals, greaterThan(protectedSteals));
      expect(exposedSteals, lessThan(150)); // never a guarantee
    });

    test('a synced block jump rejects the shot into a live ball', () {
      final engine = _playerBallEngine();
      engine.cpuBody.x = engine.playerBody.x + 0.7;
      var held = 0.0;
      final events = <BasketballEvent>[];
      for (var i = 0; i < 400; i++) {
        final shooter = engine.playerBody;
        var playerHeld = (i + 1) * _dt;
        BasketballIntent playerIntent;
        BasketballIntent cpuIntent;
        final apex = shooter.jumpDur * kBbShotApexQuickRelease;
        if (shooter.airborne &&
            shooter.jumpPurpose == JumpPurpose.shot &&
            shooter.jumpT >= apex) {
          playerIntent = BasketballIntent(
            actionReleased: true,
            heldSeconds: playerHeld,
          );
        } else {
          playerIntent = BasketballIntent(
            actionDown: true,
            actionPressed: i == 0,
            heldSeconds: playerHeld,
          );
        }
        // Defender releases its held block the moment the shooter rises.
        if (shooter.airborne && shooter.jumpPurpose == JumpPurpose.shot) {
          cpuIntent = BasketballIntent(actionReleased: true, heldSeconds: held);
          held = 0;
        } else {
          held += _dt;
          cpuIntent = BasketballIntent(actionDown: true, heldSeconds: held);
        }
        events.addAll(engine.step(playerIntent, cpuIntent, _dt));
        if (_has(events, BasketballEventType.block)) break;
      }
      expect(_has(events, BasketballEventType.block), isTrue);
      expect(engine.ball.phase, BallPhase.loose);
    });

    test('a pump fake baits the leaping defender into a stagger', () {
      final engine = _playerBallEngine();
      engine.cpuBody.x = engine.playerBody.x + 0.8;
      final events = <BasketballEvent>[];
      var held = 0.0;
      for (var i = 0; i < 240; i++) {
        // Player taps a pump fake at tick 0.
        final playerIntent = i == 0
            ? const BasketballIntent(
                actionPressed: true,
                actionReleased: true,
                heldSeconds: 0.05,
              )
            : BasketballIntent.idle;
        // Defender holds, then bites mid-fake.
        BasketballIntent cpuIntent;
        if (engine.playerBody.body == BodyState.fake && held >= 0.16) {
          cpuIntent = BasketballIntent(actionReleased: true, heldSeconds: held);
          held = 0;
        } else {
          held += _dt;
          cpuIntent = BasketballIntent(actionDown: true, heldSeconds: held);
        }
        events.addAll(engine.step(playerIntent, cpuIntent, _dt));
        if (_has(events, BasketballEventType.stagger)) break;
      }
      expect(_has(events, BasketballEventType.stagger), isTrue);
      expect(engine.cpuBody.body, BodyState.stagger);
    });
  });

  group('spin move', () {
    test('a second burst mid-drive enters the spin and carries into a drive',
        () {
      final engine = _playerBallEngine();
      // First burst → drive.
      engine.step(
        const BasketballIntent(moveAxis: 1, burst: true),
        BasketballIntent.idle,
        _dt,
      );
      expect(engine.playerBody.body, BodyState.drive);
      // Second burst mid-drive → spin (the double-tap is reused; no new input).
      engine.step(
        const BasketballIntent(moveAxis: 1, burst: true),
        BasketballIntent.idle,
        _dt,
      );
      expect(engine.playerBody.body, BodyState.spin);
      // Nobody set in the lane — the spin flows into a fresh drive.
      _run(
        engine,
        kBbSpinDuration + 0.05,
        player: (_) => const BasketballIntent(moveAxis: 1),
      );
      expect(engine.playerBody.body, BodyState.drive);
    });

    test('a set defender in the lane absorbs the spin into recovery', () {
      final engine = _playerBallEngine();
      // Plant the defender in the driving lane so the spin ends on their body.
      engine.cpuBody.x = engine.playerBody.x + 1.3;
      engine.step(
        const BasketballIntent(moveAxis: 1, burst: true),
        BasketballIntent.idle,
        _dt,
      );
      engine.step(
        const BasketballIntent(moveAxis: 1, burst: true),
        BasketballIntent.idle,
        _dt,
      );
      expect(engine.playerBody.body, BodyState.spin);
      // Defender holds a set stance throughout the spin.
      _run(
        engine,
        kBbSpinDuration + 0.05,
        player: (_) => const BasketballIntent(moveAxis: 1),
        cpu: (_) => const BasketballIntent(actionDown: true, heldSeconds: 0.3),
      );
      // Absorbed: the handler is locked out, not driving.
      expect(engine.playerBody.body, BodyState.idle);
      expect(engine.playerBody.recoverT, greaterThan(0));
    });
  });

  group('dunks, heat, overtime', () {
    test('a clean dunk always scores and pays into heat', () {
      final engine = _playerBallEngine(starter: 'mia-giannis-antetokounmpo');
      engine.cpuBody.x = kBbCourtMinX; // open lane
      final events = _dunk(engine);
      expect(_has(events, BasketballEventType.basketMade), isTrue);
      expect(_has(events, BasketballEventType.dunk), isTrue);
      expect(engine.teams[0].score, 2);
      expect(engine.teams[0].heatMeter, greaterThan(0));
    });

    test('three unanswered baskets ignite heat; it expires on its own', () {
      final engine = _playerBallEngine(starter: 'mia-giannis-antetokounmpo');
      engine.halfClock = 500; // keep the half alive for the whole script
      final events = <BasketballEvent>[];
      for (var basket = 0; basket < 3; basket++) {
        engine.cpuBody.x = kBbCourtMinX;
        events.addAll(_dunk(engine));
        engine.playerBody.stamina = 100;
        // Ride out the reset + CPU shot-clock violation + second reset.
        events.addAll(_run(engine, kBbShotClockSeconds + 3));
      }
      expect(_has(events, BasketballEventType.heatStarted), isTrue);
      // Heat expires after its duration.
      events.addAll(_run(engine, kBbHeatDuration + 1));
      expect(_has(events, BasketballEventType.heatEnded), isTrue);
      expect(engine.teams[0].heatActive, isFalse);
    });

    test('overtime is sudden death — first basket ends the match', () {
      for (var seed = 1; seed < 60; seed++) {
        final engine = _playerBallEngine(
          starter: 'mia-giannis-antetokounmpo',
          seed: seed,
        );
        engine.teams[0].score = 10;
        engine.teams[1].score = 10;
        engine.startHalf(2);
        if (engine.possession != 0) continue;
        expect(engine.overtime, isTrue);
        engine.cpuBody.x = kBbCourtMinX;
        final events = _dunk(engine);
        expect(_has(events, BasketballEventType.matchEnded), isTrue);
        expect(engine.matchOver, isTrue);
        return;
      }
      fail('no seed put the player on ball in overtime');
    });
  });

  group('stamina & substitutions', () {
    test('stamina stays bounded and tired athletes are slower', () {
      final engine = _playerBallEngine();
      for (var i = 0; i < 1200; i++) {
        engine.step(
          BasketballIntent(moveAxis: i.isEven ? 1 : -1, burst: i % 40 == 0),
          BasketballIntent.idle,
          _dt,
        );
        expect(engine.playerBody.stamina, inInclusiveRange(0, 100));
      }

      // Fresh vs gassed straight-line speed.
      final fresh = _playerBallEngine();
      fresh.playerBody.x = 2;
      _run(fresh, 1, player: (_) => const BasketballIntent(moveAxis: 1));
      final freshDistance = fresh.playerBody.x - 2;

      final tired = _playerBallEngine();
      tired.playerBody.x = 2;
      tired.playerBody.stamina = 5;
      _run(tired, 1, player: (_) => const BasketballIntent(moveAxis: 1));
      final tiredDistance = tired.playerBody.x - 2;
      expect(tiredDistance, lessThan(freshDistance));
    });

    test('substitution stores stamina and fields the bench athlete', () {
      final engine = _playerBallEngine();
      final starter = engine.playerBody.spec;
      engine.playerBody.stamina = 37;
      engine.substitute(0, 1);
      expect(engine.playerBody.spec, isNot(starter));
      expect(engine.playerBody.stamina, 100);
      expect(engine.teams[0].staminas[0], 37);
      engine.substitute(0, 0);
      expect(engine.playerBody.spec, starter);
      expect(engine.playerBody.stamina, 37);
    });

    test('halftime rest refills the bench and tops up the active athlete', () {
      final engine = _playerBallEngine();
      engine.playerBody.stamina = 30;
      engine.teams[0].staminas[1] = 20;
      engine.halftimeRest();
      expect(engine.playerBody.stamina, 70);
      expect(engine.teams[0].staminas[1], 100);
    });
  });

  group('AI', () {
    BasketballMatchSummary playFullMatch(
      BasketballDifficulty difficulty,
      int seed, {
      List<BasketballEventType>? eventLog,
    }) {
      final engine = BasketballEngine(
        _config(seed: seed, difficulty: difficulty),
      )..startHalf(0);
      final home = BasketballAI(
        difficulty: difficulty,
        seed: seed + 1,
        team: 0,
      );
      final away = BasketballAI(difficulty: difficulty, seed: seed + 2);
      var simSeconds = 0.0;
      while (!engine.matchOver && simSeconds < 400) {
        simSeconds += _dt;
        final events = engine.step(
          home.think(engine, _dt),
          away.think(engine, _dt),
          _dt,
        );
        eventLog?.addAll(events.map((e) => e.type));
        for (final event in events) {
          if (event.type == BasketballEventType.halfEnded) {
            if (event.halfIndex == 0) {
              engine.halftimeRest();
              engine.startHalf(1);
            } else if (event.needsOvertime) {
              engine.startHalf(2);
            }
          }
        }
      }
      expect(
        engine.matchOver,
        isTrue,
        reason: 'AI vs AI match must finish ($difficulty, seed $seed)',
      );
      return engine.summary();
    }

    test('AI vs AI completes at every difficulty with sane scores', () {
      for (final difficulty in BasketballDifficulty.values) {
        for (var seed = 0; seed < 3; seed++) {
          final summary = playFullMatch(difficulty, seed * 11 + 1);
          final total = summary.playerScore + summary.cpuScore;
          expect(
            total,
            greaterThan(0),
            reason: 'someone must score ($difficulty seed $seed)',
          );
          expect(
            total,
            lessThan(90),
            reason: 'scores stay sane ($difficulty seed $seed)',
          );
        }
      }
    });

    test('identical seeds replay identically (full-match golden)', () {
      final logA = <BasketballEventType>[];
      final logB = <BasketballEventType>[];
      final a = playFullMatch(BasketballDifficulty.pro, 42, eventLog: logA);
      final b = playFullMatch(BasketballDifficulty.pro, 42, eventLog: logB);
      expect(logA, logB);
      expect(a.playerScore, b.playerScore);
      expect(a.cpuScore, b.cpuScore);
    });
  });

  group('model', () {
    test('NBA catalog has 180 rated athletes across 30 six-player teams', () {
      expect(basketballAthletes, hasLength(180));
      expect(
        basketballAthletes.map((athlete) => athlete.teamCode).toSet(),
        hasLength(30),
      );
      expect(
        basketballAthletes.map((athlete) => athlete.id).toSet(),
        hasLength(180),
      );

      final teamCounts = <String, int>{};
      for (final athlete in basketballAthletes) {
        teamCounts.update(
          athlete.teamCode,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      for (final count in teamCounts.values) {
        expect(count, 6);
      }

      for (final athlete in basketballAthletes) {
        expect(athlete.ovr, inInclusiveRange(0, 99));
        expect(athlete.overall, athlete.ovr);
        expect(athlete.teamName, isNotEmpty);
        expect(athlete.teamCode, isNotEmpty);
        expect(athlete.position, isNotEmpty);

        final ratings = [
          athlete.speed,
          athlete.handling,
          athlete.inside,
          athlete.mid,
          athlete.three,
          athlete.dunk,
          athlete.defense,
          athlete.steal,
          athlete.block,
          athlete.rebound,
          athlete.stamina,
        ];
        for (final rating in ratings) {
          expect(rating, inInclusiveRange(0, 99));
        }
      }
    });

    test(
      'old fictional Hoop Duel roster ids fall back to NBA defaults',
      () async {
        SharedPreferences.setMockInitialValues({
          'pd_basketball_stats_v1': jsonEncode(
            const BasketballStats(
              lastRosterIds: ['volt', 'blitz', 'titan'],
              lastStarterId: 'volt',
            ).toJson(),
          ),
        });

        final cubit = BasketballCubit(SecureGameStorage());
        await cubit.load();
        addTearDown(cubit.close);

        expect(cubit.state.rosterIds, [
          'okc-shai-gilgeous-alexander',
          'den-nikola-jokic',
          'sas-victor-wembanyama',
        ]);
        expect(cubit.state.starterId, 'okc-shai-gilgeous-alexander');
        expect(cubit.state.rosterReady, isTrue);
      },
    );

    test('stats json roundtrip and recordResult', () {
      const summary = BasketballMatchSummary(
        playerScore: 21,
        cpuScore: 14,
        overtime: false,
        difficulty: BasketballDifficulty.pro,
        box: BasketballBoxScore(
          attempts: 12,
          makes: 8,
          threesMade: 1,
          perfectReleases: 4,
          dunks: 2,
          blocks: 2,
          steals: 1,
          rebounds: 3,
          turnovers: 1,
          bestRun: 8,
        ),
      );
      final stats = const BasketballStats()
          .recordResult(summary)
          .copyWith(
            lastRosterIds: [
              'okc-shai-gilgeous-alexander',
              'den-nikola-jokic',
              'sas-victor-wembanyama',
            ],
            lastStarterId: 'okc-shai-gilgeous-alexander',
          );
      final revived = BasketballStats.fromJson(stats.toJson());
      expect(revived.wins, 1);
      expect(revived.games, 1);
      expect(revived.mostPoints, 21);
      expect(revived.bestMargin, 7);
      expect(revived.totalDunks, 2);
      expect(revived.lastRosterIds, [
        'okc-shai-gilgeous-alexander',
        'den-nikola-jokic',
        'sas-victor-wembanyama',
      ]);
      expect(revived.lastDifficulty, BasketballDifficulty.pro);
      expect(summary.grade, anyOf('A', 'S'));
    });

    test('grades reward all-round play, not just points', () {
      const grinder = BasketballMatchSummary(
        playerScore: 8,
        cpuScore: 12,
        overtime: false,
        difficulty: BasketballDifficulty.pro,
        box: BasketballBoxScore(attempts: 10, makes: 3, turnovers: 5),
      );
      expect(grinder.grade, anyOf('C', 'D'));
    });
  });
}
```

### E.2 `test/basketball_action_cue_test.dart`

<sub>89 lines</sub>

```dart
import 'package:card_game/data/basketball_athletes.dart';
import 'package:card_game/games/basketball/basketball_engine.dart';
import 'package:card_game/games/basketball/basketball_tuning.dart';
import 'package:card_game/models/basketball.dart';
import 'package:flutter_test/flutter_test.dart';

BasketballEngine _engine() {
  final roster = basketballAthletes.take(6).toList();
  final engine = BasketballEngine(
    BasketballMatchConfig(
      playerRoster: roster.take(3).toList(),
      playerStarterIndex: 0,
      cpuRoster: roster.skip(3).take(3).toList(),
      cpuStarterIndex: 0,
      difficulty: BasketballDifficulty.pro,
      seed: 7,
    ),
  )..startHalf(0);

  engine
    ..possession = 0
    ..ball.phase = BallPhase.held
    ..ball.holder = 0;
  return engine;
}

void main() {
  group('BasketballActionCue', () {
    test('shoot is the default cue while holding the ball', () {
      final engine = _engine();

      expect(engine.playerActionCue, BasketballActionCue.shoot);
    });

    test('finish appears inside the layup window while moving', () {
      final engine = _engine();
      engine.playerBody
        ..x = kBbRimX - 1
        ..enter(BodyState.run);

      expect(engine.playerActionCue, BasketballActionCue.finish);
    });

    test('release appears while a jump shot is gathering', () {
      final engine = _engine();
      engine.playerBody
        ..jumpPurpose = JumpPurpose.shot
        ..enter(BodyState.gather);

      expect(engine.playerActionCue, BasketballActionCue.release);
    });

    test('defend appears while the opponent controls the ball', () {
      final engine = _engine();
      engine
        ..possession = 1
        ..ball.holder = 1;

      expect(engine.playerActionCue, BasketballActionCue.defend);
    });

    test('block appears for a shooter threat when stamina allows it', () {
      final engine = _engine();
      engine
        ..possession = 1
        ..ball.holder = 1;
      engine.cpuBody
        ..jumpPurpose = JumpPurpose.shot
        ..enter(BodyState.gather);

      expect(engine.playerActionCue, BasketballActionCue.block);

      engine.playerBody.stamina = kBbDrainBlockJump - 0.1;
      expect(engine.playerActionCue, BasketballActionCue.defend);
    });

    test('rebound appears when a tap can launch a rebound jump', () {
      final engine = _engine();
      engine.ball
        ..phase = BallPhase.loose
        ..holder = -1;
      expect(engine.playerActionCue, isNot(BasketballActionCue.rebound));

      engine.ball.prediction = const ReboundPrediction(8, 0.5);

      expect(engine.playerActionCue, BasketballActionCue.rebound);
    });
  });
}
```
