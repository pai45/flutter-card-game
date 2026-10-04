# Tennis Rally — Implementation & Porting Reference

> **Status:** BUILT · **Written:** 2026-09-16 · **Audience:** Flutter engineers rebuilding this game in another project
>
> **Source of truth:** `lib/games/tennis/` plus the files listed in §3.
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

Tennis Rally is a **real-time, top-down/perspective one-set tennis game**
against a CPU opponent. You move with a virtual stick. You serve and hit with
a second pad whose **release timing** grades the contact and whose **drag
direction** aims the ball and picks the shot type.

| Mode (`TennisMode`) | Rules |
|---|---|
| `quickMatch` | One set: first to 6 games, win by 2; tiebreak to 7 (win by 2) at 6–6. Real scoring: 15/30/40, deuce/advantage, alternating serve. Ends change after every second game (the engine's `totalGames.isEven` rule) and every 6 tiebreak points |
| `tournament` | Three rounds (`currentRound` 0 → 1 → 2) against three random rivals. Each round is a quickMatch; lose once and the run ends; win round 2 to be champion |
| `endlessRally` | The CPU feeds balls. Every clean return scores; ball speed rises 2 % every 5 returns. Ends on your first miss |
| `targetPractice` | 20 fed balls and a 90 s cap. Land in the target on the far court for 500/250/100/25 points; the target shrinks as you go |
| `training` | Lessons 1–8 with completion goals (§5.7) |

The player is always team 0 on the near side (`y > 0`). The opponent is team
1 (`y < 0`). Difficulty (Rookie / Pro / All-Star) changes AI reaction, aim
error and tactics, and scales the opponent's return-miss chance.

## 2. Architecture

```
TennisMatchScreen (Appendix C)          ← settle, pause/resume, lifecycle, sound, haptics, XP dispatch
 ├─ TennisCubit (A)                     ← profile, mode/opponent/difficulty, tournament, resume snapshot, rewards
 ├─ GameWidget(TennisGame) (A)          ← Flame: fixed-step loop, notifiers, juice, all Canvas drawing
 │    ├─ TennisEngine (A)               ← PURE Dart: bodies, ball physics, serve, contact, scoring, modes
 │    ├─ TennisScoring (A)              ← pure scorekeeper (games/points/deuce/tiebreak/ends)
 │    └─ TennisAI (A)                   ← emits TennisIntent like a thumb would
 └─ TennisControls / TennisHud (B)      ← Listener stick + shot pad; ValueNotifier HUD
```

Hard rules that the port must keep:

1. **The engine is pure Dart and seeded.** `TennisRandom` is a tiny LCG
   (`state = (1103515245·state + 12345) & 0x7fffffff`) so its state can be
   **snapshotted and restored**. Do not swap it for `dart:math Random`, or
   resume breaks.
2. **Fixed 1/120 s substeps** with wall `dt` clamped to 1/30. Edge inputs
   (`shotPressed`, `shotReleased`) are consumed on the first substep only.
   `engine.step` also clamps `dt` to 1/30.
3. **Resume support.** `TennisGame.snapshot()` serialises the engine, the AI
   and the accumulator into `TennisMatchSnapshot`. The screen saves it on
   pause, on backgrounding and on dispose (unless the match was settled or
   deliberately exited), and passes it back as `resume:`.
4. **HUD values are `ValueNotifier`s:**
   - score, stamina, focus, serve meter, rally count
   - practice score, balls remaining, lesson progress
   - elapsed time, phase, last timing, sting

   Only the `setEnded` event matters to the cubit.

## 3. File map

| Target path | Role | Where |
|---|---|---|
| `lib/games/tennis/tennis_engine.dart` | Court constants, `TennisIntent`, events, `TennisScoring`, bodies/ball, `TennisRandom`, `TennisEngine`, `TennisAI` | A.1 |
| `lib/games/tennis/tennis_game.dart` | `FlameGame`: loop, input API, notifiers, stings, court/net/players/ball/trail/landing-marker drawing | A.2 |
| `lib/models/tennis.dart` | Modes, ratings, `TennisPlayer`, settings, config, score state, stats, summary + grade, reward calc, tournament, profile, snapshot | A.3 |
| `lib/data/tennis_athletes.dart` | The 100-player roster (`tennisTop100`) with archetypes and 9 ratings | A.4 |
| `lib/blocs/tennis/tennis_state.dart` | `TennisFlowPhase` + state | A.5 |
| `lib/blocs/tennis/tennis_cubit.dart` | Selection, match build, tournament, resume, settle | A.6 |
| `lib/screens/tennis/widgets/tennis_controls.dart` | Movement stick + shot/aim pad (left-handed swap, scale, opacity) | B.1 |
| `lib/screens/tennis/widgets/tennis_hud.dart` | Mode tag, match/practice scoreboard, serve meter, stamina/focus rails, sting layer | B.2 |
| `lib/screens/tennis/tennis_match_screen.dart` | Host screen (**reference**, includes pause/settings/result panels) | C.1 |
| `lib/config/theme.dart` | **Stand-in** tokens | D.1 |
| `lib/config/enums.dart` | **Stand-in**: `CardTier` | D.2 |
| `lib/models/starter_pack.dart` | **Stand-in**: `packRarityForRating` (used by `TennisPlayer.tier`) | D.3 |
| `lib/services/secure_storage_service.dart` | **Stand-in**: profile, snapshot and settlement persistence (verbatim methods) | D.4 |
| `lib/utils/sound_effects.dart` | **Stand-in**: `SoundEffect` + `playSound` | D.5 |
| `lib/widgets/cyber/cyber_widgets.dart` | **Subset** of shared HUD widgets (verbatim classes) | D.6 |
| `lib/widgets/cyber/cyber_cta_button.dart` | `HudCtaButton` (verbatim; used by the C.1 panels) | D.7 |
| `test/tennis_engine_test.dart` | Acceptance suite | E |

Not ported, because they belong to the source app's meta layer: `tennis_hub.dart`
(mode picker, player select, opponent preview, tournament bracket, profile
and achievements UI), the tennis deck builder, the starter-pack/card economy,
matchmaking, the global `GameBloc`, and the audio scene controller.

The hub now has its own port doc,
[tennis-rally-hub-port.md](tennis-rally-hub-port.md), built on top of this
one. It covers the shipped Quick Match lobby and the unrouted five-mode
prototype.

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
    - family: Orbitron        # Cyber.displayFont
    - family: Onest           # Cyber.bodyFont
```

No image or audio assets are required; everything is drawn on Canvas.
**Rename `package:card_game/` in the test to your package name.**

## 5. Rules reference (engine)

### 5.1 Court (metres, singles)

| Measurement | Value |
|---|---|
| Half-width | 4.115 |
| Half-length | 11.885 |
| Service line | 6.40 |
| Net height | 0.914 |
| Gravity | −9.8 |

The player is clamped to `y ∈ [0.75, 12.985]` and the opponent to the mirror
range. Both are clamped to `x ∈ ±(4.115 + 1.1)`.

### 5.2 Intent (`TennisIntent`)

| Field | Meaning |
|---|---|
| `moveX`, `moveY` | Stick, −1..1 |
| `sprint` | Sprint flag |
| `shotDown` | Shot pad held |
| `shotPressed` | Edge: press started |
| `shotReleased` | Edge: released |
| `holdSeconds` | Hold length |
| `aimX`, `aimY` | Aim, −1..1 |
| `serveAim` | −1 wide / 0 body / 1 T |

### 5.3 Movement and stamina

```
speed = (3.5 + speed/100·2.4) × (0.70 + stamina01·0.30) × (sprint && stamina>8 ? 1.35 : 1)
drain = (sprint ? 7.2 : 0.65) × |stick| per second;  regen 3/s when idle, 9/s between points
```

**Movement assist** (a setting, on by default) nudges an idle player toward a
ball on their side.

### 5.4 Serve

1. **Arm:** pressing in `preServe` enters `serving`.
2. **Meter:** the serve meter ping-pongs 0→1→0 with a half-period of 1.05 s
   (first serve) or 1.25 s (second serve).
3. **Release:** releasing launches the serve.

The serve maths:

```
accuracy = 1 − |meter − 0.82| / 0.82
quality  = clamp(accuracy·0.72 + serveRating·0.28 + (2nd serve ? 0.14 : 0))
targetX  = side·(1.05 + serveAim·1.25) ± (1−quality)·(2.7 first | 1.6 second)
long     = quality < 0.45 ? (0.45−quality)·7 m past the box
duration = 0.58 + (1−quality)·0.20
```

The first bounce is checked against the correct service box (the side
alternates by points in the game: even = right court):

- **Net cord + in:** LET, replay the serve.
- **Out:** FAULT, and a second serve follows.
- **Second fault:** DOUBLE FAULT, point to the receiver.
- **Serve bounces twice untouched:** ACE.

### 5.5 Contact and shot selection

`canHit(team)` requires all of the following:

- the ball is live
- the phase is rally
- the ball did not come from this team
- the ball is on this team's side
- distance ≤ `0.75 + reach/100·0.65`
- ball height between 0.18 and 2.8

A release is queued, and it fires on the first substep where `canHit` is true.

**Timing grade:**

- **PERFECT** — distance ≤ 0.34 and the queue age ≤
  `(0.075 + control/2200) × (0.72 + stamina01·0.28) × (focus point ? 1.10)`.
- **LATE / EARLY** — distance > 1.05, split by the ball's travel direction
  (`ball.vy` relative to the hitter).
- **EARLY** — queue age > 0.45.
- **GOOD** — otherwise.

**Shot type** (`_resolveShot`, first match wins):

| Condition | Shot |
|---|---|
| High ball (z > 2.05) and near the net (\|y\| < 4.4) | SMASH |
| Near the net, no bounce yet | VOLLEY |
| Stretched (distance > 0.95) or LATE | DEFENSIVE |
| aimY < −0.55 | DROP SHOT |
| aimY < −0.16 | SLICE |
| aimY > 0.55 | LOB |
| aimY > 0.16 | TOPSPIN |
| held ≥ 0.28 s | POWER |
| otherwise | NORMAL |

Each shot has a flight time, a target depth and a stamina cost, for example:

| Shot | Flight | Target depth | Stamina |
|---|---|---|---|
| Power | 0.68 − power/2500 s | — | 6.5 |
| Lob | 1.36 s | — | 3.2 |
| Smash | 0.54 s | — | 9 |
| Drop | 0.92 s | 2.8 m | 3.5 |

**Scatter:**

```
spread = max(0.04, timingErr(perfect .10 / good .35 / early-late .95) + (1−stamina01)·0.8
                   + (power|drop ? .25) − control·0.38)
```

The flight is solved ballistically (`_setFlight`) so the ball lands on the
target at the given time. Bounce factors: slice/drop 0.48, topspin 0.72,
lob/defensive 0.76.

**Opponent return miss** (`_opponentMissesReturn`) — the CPU can whiff a
return with a chance built from these terms:

- a base term from its return rating
- stretch
- fatigue
- timing
- pressure from the incoming shot type
- a difficulty scale (Rookie ×1.25, Pro ×1, All-Star ×0.78)

The chance is clamped to 1.5–42 %.

### 5.6 Rally, focus, points

- **Rally milestones** at 5, 10 and 20 shots emit `rallyMilestone` (+5 focus
  for the player).
- **Focus** is gained from PERFECT (+12) and winners (+8). At 100 the next
  point becomes a **focus point** (×1.10 perfect window).
- **Point awards:**
  - The first bounce outside the singles court, or on the hitter's own side,
    is OUT (point to the other side).
  - A second bounce is a WINNER for the hitter.
  - A net ball that crosses at `z < 0.914` may dribble over (45 % if high
    enough); otherwise it dies.
- **Point reset:** 0.78 s (1.0 s after a game).
- **Scoring:** `TennisScoring.awardPoint` returns game/set/tiebreak/end-change
  flags and break-point converted/saved. Tiebreak serve rotation is 1, 2, 2 …

### 5.7 Practice modes and training lessons

| Lesson | Goal |
|---|---|
| 1 | 3 NORMAL returns |
| 2 | 1 PERFECT |
| 3 | Aim left and right |
| 4 | 1 POWER |
| 5 | 1 LOB (feed from the net) |
| 6 | 2 good serves (serve-only lesson) |
| 7 | 2 contacts after sprinting |
| 8 | Play one real game to completion (scoring lesson) |

**Target practice:** targets cycle through set positions, and the scoring
rings shrink by 1.8 % per ball (floor 62 %).

**Endless rally:** `practiceScore` counts returns. The summary reports it ×100.

### 5.8 AI (`TennisAI`)

| Difficulty | Reaction sample | Serve release (hold s) | Aim error | Tactic chance |
|---|---|---|---|---|
| Rookie | 0.30 s | 0.68 | 0.42 | 10 % |
| Pro | 0.18 s | 0.78 | 0.24 | 26 % |
| All-Star | 0.11 s | 0.84 | 0.12 | 42 % |

The AI re-samples ball and player positions every reaction period and chases
the observed ball. It aims away from the player's side. Tactics: it lobs a
player at the net, drop-shots a deep player, and holds for power when it has
stamina.

### 5.9 Summary, grade, reward

`TennisMatchSummary.performanceScore` (0–100) is the sum of these components:

| Component | Range |
|---|---|
| Result | 20 / 10 / 4 |
| Difficulty | 2 / 6 / 10 |
| First-serve % | 0–15 |
| Winners vs. unforced errors | 0–15 |
| Break play | 0–10 |
| Perfect contacts | 0–10 |
| Rally length | 0–10 |
| Stamina economy | 0–5 |
| Shot variety | 0–5 |

Grade: **S ≥ 90 · A ≥ 78 · B ≥ 64 · C ≥ 48 · D**.

`calculateTennisReward` (A.3) pays XP, coins and per-player mastery XP by
mode:

- **Training:** 5 XP on the first completion of a lesson.
- **Practice modes:** `min(12, score ÷ 100)` XP.
- **Sets:**
  - **Base:** 12 XP, +10 on a win.
  - **Bonuses:** the difficulty XP bonus (0/4/8), a grade bonus and a
    performance bonus (capped at 8).
  - **Coins on a win:** 20/30/40 by difficulty.
  - **Tournament:** coins ×1.25, and the champion gets +30 XP and +75 coins.
  - **Repeat-farming guard:** a Rookie quick match replayed with the same
    player/opponent/difficulty 3+ times pays 10 coins and no bonuses.

Settlement is idempotent per `matchId` (`settledMatchIds`, capped at 256).

## 6. Controls → intents (B.1)

| Pad | Gesture | Game API |
|---|---|---|
| Movement (left; right when left-handed) | Drag the thumb inside a 46 px radius | `setMove(dx/46, dy/46, sprint:)`. **Sprint** = travelled > 42 px within the first 210 ms of the touch |
| | Lift / cancel | `setMove(0, 0)` |
| Shot (right; left when left-handed) | Down | `shotStarted()` (starts the hold; also arms the serve) |
| | Drag (clamped to 74 px) | Live aim preview |
| | Up | `shotReleased(aimX: dx/58, aimY: −dy/58, holdSeconds:)` + selection haptic. `serveAim` is derived from aimX (< −0.3 wide, > 0.3 T) |

- **Aim direction:** drag up = deeper and loopier (topspin/lob); drag down =
  shorter and softer (slice/drop).
- **Settings:** `controlScale` (0.8–1.25) and `controlOpacity` (0.45–1) come
  from `TennisSettings`.
- **Multi-touch:** each pad tracks its own pointer id.

## 7. Session flow and the host contract

`TennisFlowPhase`: `hub → selection → preview → match → result`.

1. **Setup:**
   - `cubit.load()` restores the profile and any saved snapshot.
   - Then choose via `selectMode`, `selectPlayer`, `selectOpponent`,
     `selectDifficulty` and `selectTrainingLesson`.
   - For tournaments, `prepareTournament()`.
2. **Start:** `config = cubit.buildMatch()`, or `cubit.resumeMatch()` when
   `state.canResume`. Then push the match screen with that config.
3. **Screen `initState`:**
   - Build `TennisGame(config:, settings: settings.copyWith(reducedMotion: OS
     flag || setting), resume: snapshot-if-same-matchId, onEvents:)`.
   - Lock portrait orientation.
   - Observe the app lifecycle, and auto-pause on
     inactive/paused/hidden/detached.
4. **Per event:**
   - Play `tennisSoundForEvent` (if sound is on).
   - Haptics (player only): selection on PERFECT, medium on WINNER/ACE.
   - On `setEnded`, run `_finish()`.
5. **`_finish()`** (once):
   1. `game.setPaused(true)`.
   2. `summary = game.summary(tournamentChampion: mode==tournament &&
      round==2 && setWinner==0)`.
   3. `reward = await cubit.settle(summary)`.
   4. Dispatch the XP/coins to your economy.
   5. Play the victory/defeat cue and a heavy haptic.
   6. Show the result panel.
6. **Pause:** `game.setPaused(true)` + `cubit.saveSnapshot(game.snapshot())`.
   Resume with `setPaused(false)`. Settings changes go through
   `game.applySettings()` and `cubit.updateSettings()`.
7. **Exit:**
   - **Deliberate exit:** `cubit.abandonMatch()` (clears the snapshot).
   - **Non-deliberate dispose:** save the snapshot.
   - **Result panel buttons:** rematch → `onRestart`; next round →
     `onContinueTournament`; exit → `cubit.returnToHub()`.

## 8. Feedback map

| Event | Visual (A.2) | Sound (`tennisSoundForEvent`) | Haptic |
|---|---|---|---|
| contact | timing chip; SMASH → sting amber major + camera push 1.0 | tennisContact | — |
| perfectContact | PERFECT sting cyan, camera push 0.55 | tennisPerfect | selection |
| winner | WINNER sting lime major, camera push 0.8 | tennisWinner | medium |
| ace | ACE gold major | tennisAce | medium |
| fault / doubleFault / let | FAULT amber / DOUBLE FAULT danger major / LET - REPLAY cyan | tennisFault / tennisDoubleFault / tennisLet | — |
| net | net pulse | tennisNet | — |
| out | line pulse | tennisOut | — |
| rallyMilestone | `N SHOTS` cyan | cheering | — |
| tieBreakStarted / endChange | TIEBREAK gold major / CHANGE ENDS cyan | tennisTiebreak / tennisEndChange | — |
| lessonComplete | LESSON COMPLETE lime major | tennisLesson | — |
| serveStarted, bounce, pointEnded, gameEnded, setEnded, practiceScore | — | tennisServe, tennisBounce, tennisPoint, tennisGame, tennisSet, tennisPoint | — |
| match end | result panel | tennisVictory / tennisDefeat | heavy |

- **Sting timing:** major stings hold 1.35 s and minor 0.85 s.
- **Reduced motion:** disables the camera push.
- **Rendering:** the renderer draws a ball trail and a landing-prediction
  marker per flight.

## 9. Host touch-points in the reference screen (Appendix C)

| Source symbol | Replace with |
|---|---|
| `GameBloc` / `TennisFinished(...)` | Your XP, coin and history service |
| `AudioController` scenes | Your music player |
| `tennisSoundForEvent`, `SoundEffect.tennis*` | Your audio mapping (§8) |
| `HudCtaButton`, `CyberPanel` in the pause/result panels | Provided by D.7 and D.6 |
| `SystemChrome.setPreferredOrientations` | Keep (portrait lock) |

## 10. Design rules carried by this code

- Colours come only from `Cyber` tokens, except per-player content palettes
  (`_AthletePalette`).
- Pads are calm; the active pad gets an accent fill, not a glow.
- Every point outcome gets a sting, and big shots add a camera push.

## 11. Port checklist

1. Copy A, B and D to the same paths. Add the §4 dependencies.
2. Build your own hub for mode/player/opponent/difficulty selection, calling
   the cubit methods in §7. See
   [tennis-rally-hub-port.md](tennis-rally-hub-port.md) for the source hubs.
3. Port C.1, applying §9. Keep the lifecycle observer and the snapshot saves.
4. Wire the §8 sounds.
5. Copy Appendix E, rename the package import, and run `flutter test`.
6. On device, verify:
   - serve meter → fault → second serve
   - left-handed swap
   - a pause/kill/resume restores the exact rally state
   - a tiebreak at 6–6

## 12. Verification performed for this document

A script read **only this markdown file**, wrote every Appendix A, B, D and E
code block to its heading's path in an empty Flutter package, and added the §4
dependencies (Flutter 3.44.4, flame 1.38.0, flutter_bloc 9.1.1).

- **Verbatim check:** every Appendix A and B block is byte-identical to the
  source repo file.
- **Analyze:** `flutter analyze` → **No issues found!**
- **Tests:** `flutter test` on Appendix E → **20 tests, all passed**.
- **Not checked:** Appendix C was not compiled; it depends on the host
  systems in §9.

---

## Appendix A — Game code (verbatim)

Copy each file to the path in its heading. These are byte-for-byte copies of the source repo.

### A.1 `lib/games/tennis/tennis_engine.dart`

<sub>1712 lines</sub>

```dart
import 'dart:math';

import '../../models/tennis.dart';

const double tennisCourtHalfWidth = 4.115;
const double tennisCourtHalfLength = 11.885;
const double tennisServiceLine = 6.40;
const double tennisNetHeight = 0.914;
const double tennisGravity = -9.8;

bool tennisBallInsideSingles(double x, double y) =>
    x.abs() <= tennisCourtHalfWidth + 0.001 &&
    y.abs() <= tennisCourtHalfLength + 0.001;

bool tennisServeInsideBox({
  required double x,
  required double y,
  required int server,
  required bool rightServiceCourt,
}) {
  final expectedSide = rightServiceCourt ? 1.0 : -1.0;
  final boxSide = server == 0 ? expectedSide : -expectedSide;
  final correctHalf = x.abs() <= 0.001 || x.sign == boxSide.sign;
  final correctDepth = server == 0
      ? y <= 0.001 && y >= -tennisServiceLine - 0.001
      : y >= -0.001 && y <= tennisServiceLine + 0.001;
  return x.abs() <= tennisCourtHalfWidth + 0.001 && correctHalf && correctDepth;
}

class TennisIntent {
  const TennisIntent({
    this.moveX = 0,
    this.moveY = 0,
    this.sprint = false,
    this.shotDown = false,
    this.shotPressed = false,
    this.shotReleased = false,
    this.holdSeconds = 0,
    this.aimX = 0,
    this.aimY = 0,
    this.serveAim = 0,
  });

  static const idle = TennisIntent();

  final double moveX;
  final double moveY;
  final bool sprint;
  final bool shotDown;
  final bool shotPressed;
  final bool shotReleased;
  final double holdSeconds;
  final double aimX;
  final double aimY;

  /// -1 = wide, 0 = body, 1 = centre/T.
  final int serveAim;
}

enum TennisEventType {
  serveStarted,
  contact,
  perfectContact,
  bounce,
  net,
  let,
  fault,
  doubleFault,
  ace,
  out,
  winner,
  pointEnded,
  gameEnded,
  endChange,
  tieBreakStarted,
  setEnded,
  rallyMilestone,
  practiceScore,
  lessonComplete,
}

class TennisEvent {
  const TennisEvent(
    this.type, {
    this.team,
    this.label,
    this.value,
    this.shot,
    this.timing,
  });

  final TennisEventType type;
  final int? team;
  final String? label;
  final int? value;
  final TennisShotType? shot;
  final TennisTimingGrade? timing;
}

class TennisPointResult {
  const TennisPointResult({
    required this.winner,
    required this.gameWon,
    required this.setWon,
    required this.tieBreakStarted,
    required this.endChange,
    required this.breakPointConverted,
    required this.breakPointSaved,
  });

  final int winner;
  final bool gameWon;
  final bool setWon;
  final bool tieBreakStarted;
  final bool endChange;
  final bool breakPointConverted;
  final bool breakPointSaved;
}

/// Pure tennis scorekeeper. It has no Flutter or Flame dependency and can be
/// driven directly by unit tests.
class TennisScoring {
  TennisScoring({required int firstServer})
    : _state = TennisScoreState(
        firstServer: firstServer,
        currentServer: firstServer,
        tieBreakFirstServer: firstServer,
      );

  TennisScoring.fromState(TennisScoreState state) : _state = state;

  TennisScoreState _state;
  TennisScoreState get state => _state;

  bool isBreakPointFor(int player) {
    if (_state.tieBreak || player == _state.currentServer) return false;
    return _wouldWinGame(player);
  }

  bool isSetPointFor(int player) {
    if (_state.complete) return false;
    final clone = TennisScoring.fromState(
      TennisScoreState.fromJson(_state.toJson()),
    );
    return clone.awardPoint(player).setWon;
  }

  bool _wouldWinGame(int player) {
    final mine = player == 0 ? _state.playerPoints : _state.opponentPoints;
    final theirs = player == 0 ? _state.opponentPoints : _state.playerPoints;
    if (_state.advantage == player) return true;
    return mine >= 3 && theirs <= 2;
  }

  TennisPointResult awardPoint(int winner) {
    if (_state.complete) {
      return TennisPointResult(
        winner: winner,
        gameWon: false,
        setWon: true,
        tieBreakStarted: false,
        endChange: false,
        breakPointConverted: false,
        breakPointSaved: false,
      );
    }

    final serverBefore = _state.currentServer;
    final receiverBefore = 1 - serverBefore;
    final wasBreakPoint = isBreakPointFor(receiverBefore);
    var playerGames = _state.playerGames;
    var opponentGames = _state.opponentGames;
    var playerPoints = _state.playerPoints;
    var opponentPoints = _state.opponentPoints;
    var advantage = _state.advantage;
    var playerTieBreak = _state.playerTieBreak;
    var opponentTieBreak = _state.opponentTieBreak;
    var tieBreak = _state.tieBreak;
    var tieBreakFirstServer = _state.tieBreakFirstServer;
    var currentServer = _state.currentServer;
    var pointsInGame = _state.pointsInGame + 1;
    var totalGames = _state.totalGames;
    var setWinner = -1;
    var gameWon = false;
    var tieBreakStarted = false;
    var endChange = false;

    if (tieBreak) {
      if (winner == 0) {
        playerTieBreak++;
      } else {
        opponentTieBreak++;
      }
      final mine = winner == 0 ? playerTieBreak : opponentTieBreak;
      final theirs = winner == 0 ? opponentTieBreak : playerTieBreak;
      if (mine >= 7 && mine - theirs >= 2) {
        setWinner = winner;
        playerGames = winner == 0 ? 7 : 6;
        opponentGames = winner == 1 ? 7 : 6;
      } else {
        final nextPoint = playerTieBreak + opponentTieBreak;
        if (nextPoint > 0 && nextPoint % 6 == 0) endChange = true;
        currentServer = _tieBreakServer(tieBreakFirstServer, nextPoint);
      }
    } else {
      if (playerPoints >= 3 && opponentPoints >= 3) {
        if (advantage == winner) {
          gameWon = true;
        } else if (advantage == 1 - winner) {
          advantage = -1;
        } else {
          advantage = winner;
        }
      } else {
        if (winner == 0) {
          playerPoints++;
        } else {
          opponentPoints++;
        }
        final mine = winner == 0 ? playerPoints : opponentPoints;
        final theirs = winner == 0 ? opponentPoints : playerPoints;
        if (mine >= 4 && mine - theirs >= 2) gameWon = true;
      }

      if (gameWon) {
        if (winner == 0) {
          playerGames++;
        } else {
          opponentGames++;
        }
        totalGames++;
        playerPoints = 0;
        opponentPoints = 0;
        advantage = -1;
        pointsInGame = 0;
        currentServer = 1 - currentServer;
        final mine = winner == 0 ? playerGames : opponentGames;
        final theirs = winner == 0 ? opponentGames : playerGames;
        if (mine >= 6 && mine - theirs >= 2) {
          setWinner = winner;
        } else if (playerGames == 6 && opponentGames == 6) {
          tieBreak = true;
          tieBreakStarted = true;
          tieBreakFirstServer = currentServer;
          currentServer = tieBreakFirstServer;
        }
        if (setWinner < 0 && totalGames.isEven) endChange = true;
      }
    }

    _state = TennisScoreState(
      playerGames: playerGames,
      opponentGames: opponentGames,
      playerPoints: playerPoints,
      opponentPoints: opponentPoints,
      advantage: advantage,
      tieBreak: tieBreak,
      playerTieBreak: playerTieBreak,
      opponentTieBreak: opponentTieBreak,
      firstServer: _state.firstServer,
      currentServer: currentServer,
      pointsInGame: pointsInGame,
      totalGames: totalGames,
      setWinner: setWinner,
      tieBreakFirstServer: tieBreakFirstServer,
    );
    return TennisPointResult(
      winner: winner,
      gameWon: gameWon,
      setWon: setWinner >= 0,
      tieBreakStarted: tieBreakStarted,
      endChange: endChange,
      breakPointConverted: wasBreakPoint && winner == receiverBefore && gameWon,
      breakPointSaved: wasBreakPoint && winner == serverBefore,
    );
  }

  static int _tieBreakServer(int first, int pointIndex) {
    if (pointIndex == 0) return first;
    final block = (pointIndex - 1) ~/ 2;
    return block.isEven ? 1 - first : first;
  }
}

class TennisBody {
  TennisBody({required this.team, required this.spec});

  final int team;
  final TennisPlayer spec;
  double x = 0;
  double y = 0;
  double stamina = 100;
  double focus = 0;
  double swingT = 0;
  TennisShotType? swingShot;
  TennisTimingGrade? lastTiming;

  double get stamina01 => stamina / 100;
  double get focus01 => focus / 100;

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'stamina': stamina,
    'focus': focus,
    'swingT': swingT,
    'swingShot': swingShot?.name,
    'lastTiming': lastTiming?.name,
  };

  void restore(Map<String, dynamic> json) {
    x = _num(json['x'], 0);
    y = _num(json['y'], team == 0 ? 9 : -9);
    stamina = _num(json['stamina'], 100).clamp(0, 100).toDouble();
    focus = _num(json['focus'], 0).clamp(0, 100).toDouble();
    swingT = _num(json['swingT'], 0);
    swingShot = _nullableEnum(TennisShotType.values, json['swingShot']);
    lastTiming = _nullableEnum(TennisTimingGrade.values, json['lastTiming']);
  }
}

class TennisBall {
  double x = 0;
  double y = 0;
  double z = 0;
  double vx = 0;
  double vy = 0;
  double vz = 0;
  int bounces = 0;
  int lastHitter = 1;
  bool live = false;
  bool serve = false;
  bool netTouched = false;
  TennisShotType shot = TennisShotType.normal;

  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'z': z,
    'vx': vx,
    'vy': vy,
    'vz': vz,
    'bounces': bounces,
    'lastHitter': lastHitter,
    'live': live,
    'serve': serve,
    'netTouched': netTouched,
    'shot': shot.name,
  };

  void restore(Map<String, dynamic> json) {
    x = _num(json['x'], 0);
    y = _num(json['y'], 0);
    z = _num(json['z'], 0);
    vx = _num(json['vx'], 0);
    vy = _num(json['vy'], 0);
    vz = _num(json['vz'], 0);
    bounces = _integer(json['bounces'], 0);
    lastHitter = _integer(json['lastHitter'], 1);
    live = json['live'] as bool? ?? false;
    serve = json['serve'] as bool? ?? false;
    netTouched = json['netTouched'] as bool? ?? false;
    shot = _enum(TennisShotType.values, json['shot'], TennisShotType.normal);
  }
}

class _QueuedShot {
  _QueuedShot({
    required this.at,
    required this.holdSeconds,
    required this.aimX,
    required this.aimY,
    required this.serveAim,
  });

  final double at;
  final double holdSeconds;
  final double aimX;
  final double aimY;
  final int serveAim;
}

class _MutableStats {
  int aces = 0;
  int doubleFaults = 0;
  int winners = 0;
  int unforcedErrors = 0;
  int breakPointsWon = 0;
  int breakPointsSaved = 0;
  int breakPointsSavedCurrentGame = 0;
  int maxBreakPointsSavedInGame = 0;
  int firstServesIn = 0;
  int firstServesAttempted = 0;
  int perfectContacts = 0;
  int longestRally = 0;
  int netPointsWon = 0;
  int totalPointsWon = 0;
  int totalPointsLost = 0;
  double staminaSpent = 0;
  int cleanHolds = 0;
  bool comeback = false;
  bool tiebreakNerve = false;
  bool wonTwentyShotRally = false;
  final Set<TennisShotType> shots = <TennisShotType>{};
  int maxDeficit = 0;
  int pointsLostCurrentServiceGame = 0;

  TennisMatchStats freeze(int durationSeconds) => TennisMatchStats(
    durationSeconds: durationSeconds,
    aces: aces,
    doubleFaults: doubleFaults,
    winners: winners,
    unforcedErrors: unforcedErrors,
    breakPointsWon: breakPointsWon,
    breakPointsSaved: breakPointsSaved,
    maxBreakPointsSavedInGame: maxBreakPointsSavedInGame,
    firstServesIn: firstServesIn,
    firstServesAttempted: firstServesAttempted,
    perfectContacts: perfectContacts,
    longestRally: longestRally,
    netPointsWon: netPointsWon,
    totalPointsWon: totalPointsWon,
    totalPointsLost: totalPointsLost,
    staminaSpent: staminaSpent,
    cleanHolds: cleanHolds,
    comebackFromThreeGames: comeback,
    tiebreakNerve: tiebreakNerve,
    wonTwentyShotRally: wonTwentyShotRally,
    shotTypesUsed: Set<TennisShotType>.unmodifiable(shots),
  );

  Map<String, dynamic> toJson() => freeze(0).toJson()
    ..['maxDeficit'] = maxDeficit
    ..['pointsLostCurrentServiceGame'] = pointsLostCurrentServiceGame
    ..['breakPointsSavedCurrentGame'] = breakPointsSavedCurrentGame;

  void restore(Map<String, dynamic> json) {
    final frozen = TennisMatchStats.fromJson(json);
    aces = frozen.aces;
    doubleFaults = frozen.doubleFaults;
    winners = frozen.winners;
    unforcedErrors = frozen.unforcedErrors;
    breakPointsWon = frozen.breakPointsWon;
    breakPointsSaved = frozen.breakPointsSaved;
    maxBreakPointsSavedInGame = frozen.maxBreakPointsSavedInGame;
    firstServesIn = frozen.firstServesIn;
    firstServesAttempted = frozen.firstServesAttempted;
    perfectContacts = frozen.perfectContacts;
    longestRally = frozen.longestRally;
    netPointsWon = frozen.netPointsWon;
    totalPointsWon = frozen.totalPointsWon;
    totalPointsLost = frozen.totalPointsLost;
    staminaSpent = frozen.staminaSpent;
    cleanHolds = frozen.cleanHolds;
    comeback = frozen.comebackFromThreeGames;
    tiebreakNerve = frozen.tiebreakNerve;
    wonTwentyShotRally = frozen.wonTwentyShotRally;
    shots
      ..clear()
      ..addAll(frozen.shotTypesUsed);
    maxDeficit = _integer(json['maxDeficit'], 0);
    pointsLostCurrentServiceGame = _integer(
      json['pointsLostCurrentServiceGame'],
      0,
    );
    breakPointsSavedCurrentGame = _integer(
      json['breakPointsSavedCurrentGame'],
      0,
    );
  }
}

class TennisRandom {
  TennisRandom(int seed) : state = seed & 0x7fffffff;

  int state;

  double nextDouble() {
    state = (1103515245 * state + 12345) & 0x7fffffff;
    return state / 0x80000000;
  }

  int nextInt(int max) =>
      (nextDouble() * max).floor().clamp(0, max - 1).toInt();
}

class TennisEngine {
  TennisEngine(
    this.config, {
    this.movementAssist = true,
    Map<String, dynamic>? snapshot,
  }) : random = TennisRandom(config.seed),
       player = TennisBody(team: 0, spec: tennisPlayerById(config.playerId)),
       opponent = TennisBody(
         team: 1,
         spec: tennisPlayerById(config.opponentId),
       ),
       scoring = TennisScoring(
         firstServer: config.mode == TennisMode.training
             ? 0
             : (config.seed.isEven ? 0 : 1),
       ) {
    if (snapshot == null) {
      _resetBodies();
      _startPoint(initial: true);
    } else {
      _restore(snapshot);
    }
  }

  final TennisMatchConfig config;
  bool movementAssist;
  final TennisRandom random;
  final TennisBody player;
  final TennisBody opponent;
  final TennisBall ball = TennisBall();
  late TennisScoring scoring;
  final _MutableStats _stats = _MutableStats();

  TennisMatchPhase phase = TennisMatchPhase.preServe;
  int serveNumber = 1;
  double serveMeter = 0;
  bool serveMeterRising = true;
  int rallyCount = 0;
  int practiceScore = 0;
  int ballsRemaining = 20;
  int lessonProgress = 0;
  int targetIndex = 0;
  int flightId = 0;
  double targetX = 0;
  double targetY = -8;
  double elapsed = 0;
  double pointResetT = 0;
  bool paused = false;
  bool focusPointActive = false;
  bool endSwapped = false;

  _QueuedShot? _playerShot;
  _QueuedShot? _opponentShot;
  double _playerHold = 0;
  double _opponentHold = 0;
  bool _trainingAimLeft = false;
  bool _trainingAimRight = false;
  bool _trainingSprintUsed = false;
  bool _serveContinuation = false;
  bool _playerSavedTieBreakSetPoint = false;
  int _opponentMissLockedFlightId = -1;
  final List<TennisEvent> _events = <TennisEvent>[];

  TennisScoreState get score => scoring.state;
  bool get complete =>
      phase == TennisMatchPhase.setComplete ||
      phase == TennisMatchPhase.practiceComplete;
  TennisBody bodyFor(int team) => team == 0 ? player : opponent;

  bool canHit(int team) {
    if (!ball.live || phase != TennisMatchPhase.rally) return false;
    if (config.mode == TennisMode.targetPractice && team == 1) return false;
    // A player cannot strike their own live shot again. Without this guard the
    // AI can generate a contact on consecutive fixed steps while the ball is
    // still inside its reach, repeatedly relaunching the same trajectory.
    if (ball.lastHitter == team) return false;
    if (team == 0 && ball.y < 0) return false;
    if (team == 1 && ball.y > 0) return false;
    final body = bodyFor(team);
    final reach = 0.75 + body.spec.ratings.reach / 100 * 0.65;
    final distance = sqrt(pow(ball.x - body.x, 2) + pow(ball.y - body.y, 2));
    return distance <= reach && ball.z >= 0.18 && ball.z <= 2.8;
  }

  List<TennisEvent> step(
    TennisIntent playerIntent,
    TennisIntent opponentIntent,
    double dt,
  ) {
    _events.clear();
    if (paused || complete) return const <TennisEvent>[];
    final safeDt = dt.clamp(0, 1 / 30).toDouble();
    elapsed += safeDt;
    if (config.mode == TennisMode.targetPractice && elapsed >= 90) {
      _finishPractice();
      return List<TennisEvent>.unmodifiable(_events);
    }

    _updateBody(player, playerIntent, safeDt);
    _updateBody(opponent, opponentIntent, safeDt);
    _captureIntent(0, playerIntent, safeDt);
    _captureIntent(1, opponentIntent, safeDt);

    if (phase == TennisMatchPhase.pointComplete) {
      pointResetT -= safeDt;
      if (pointResetT <= 0) _startPoint();
    } else if (phase == TennisMatchPhase.preServe ||
        phase == TennisMatchPhase.serving) {
      _updateServe(playerIntent, opponentIntent, safeDt);
    } else if (phase == TennisMatchPhase.rally) {
      _tryContact(0);
      _tryContact(1);
      _updateBall(safeDt);
    }

    player.swingT = max(0, player.swingT - safeDt);
    opponent.swingT = max(0, opponent.swingT - safeDt);
    return List<TennisEvent>.unmodifiable(_events);
  }

  void _updateBody(TennisBody body, TennisIntent intent, double dt) {
    if (phase == TennisMatchPhase.pointComplete) {
      _recover(body, dt * 0.8);
      return;
    }
    var mx = intent.moveX.clamp(-1, 1).toDouble();
    var my = intent.moveY.clamp(-1, 1).toDouble();
    if (body.team == 0 &&
        movementAssist &&
        mx.abs() + my.abs() < 0.08 &&
        ball.live &&
        ball.y > 0) {
      mx = ((ball.x - body.x) * 0.22).clamp(-0.36, 0.36).toDouble();
      my = ((ball.y - body.y) * 0.12).clamp(-0.24, 0.24).toDouble();
    }
    final length = sqrt(mx * mx + my * my);
    if (length > 1) {
      mx /= length;
      my /= length;
    }
    final rating = body.spec.ratings;
    final tired = 0.70 + body.stamina01 * 0.30;
    final sprinting = intent.sprint && body.stamina > 8;
    final speed =
        (3.5 + rating.speed / 100 * 2.4) * tired * (sprinting ? 1.35 : 1);
    body.x += mx * speed * dt;
    body.y += my * speed * dt;
    body.x = body.x
        .clamp(-tennisCourtHalfWidth - 1.1, tennisCourtHalfWidth + 1.1)
        .toDouble();
    if (body.team == 0) {
      body.y = body.y.clamp(0.75, tennisCourtHalfLength + 1.1).toDouble();
    } else {
      body.y = body.y.clamp(-tennisCourtHalfLength - 1.1, -0.75).toDouble();
    }
    if (length > 0.05) {
      final drain = (sprinting ? 7.2 : 0.65) * length * dt;
      body.stamina = max(0, body.stamina - drain);
      if (body.team == 0) _stats.staminaSpent += drain;
    } else {
      body.stamina = min(100, body.stamina + 3.0 * dt);
    }
    if (body.team == 0 && intent.sprint) _trainingSprintUsed = true;
  }

  void _recover(TennisBody body, double dt) {
    final targetY = body.team == 0 ? 8.8 : -8.8;
    body.x += (0 - body.x) * min(1, dt * 2.2);
    body.y += (targetY - body.y) * min(1, dt * 2.2);
    body.stamina = min(100, body.stamina + dt * 9);
  }

  void _captureIntent(int team, TennisIntent intent, double dt) {
    if (team == 0) {
      if (intent.shotDown) _playerHold += dt;
      if (intent.shotReleased) {
        _playerShot = _QueuedShot(
          at: elapsed,
          holdSeconds: max(intent.holdSeconds, _playerHold),
          aimX: intent.aimX,
          aimY: intent.aimY,
          serveAim: intent.serveAim,
        );
        _playerHold = 0;
      }
    } else {
      if (intent.shotDown) _opponentHold += dt;
      if (intent.shotReleased) {
        _opponentShot = _QueuedShot(
          at: elapsed,
          holdSeconds: max(intent.holdSeconds, _opponentHold),
          aimX: intent.aimX,
          aimY: intent.aimY,
          serveAim: intent.serveAim,
        );
        _opponentHold = 0;
      }
    }
  }

  void _updateServe(
    TennisIntent playerIntent,
    TennisIntent opponentIntent,
    double dt,
  ) {
    final server = score.currentServer;
    final intent = server == 0 ? playerIntent : opponentIntent;
    final queued = server == 0 ? _playerShot : _opponentShot;
    if (intent.shotPressed || intent.shotDown) {
      if (phase == TennisMatchPhase.preServe) {
        phase = TennisMatchPhase.serving;
        serveMeter = 0;
        serveMeterRising = true;
        _events.add(TennisEvent(TennisEventType.serveStarted, team: server));
      }
    }
    if (phase == TennisMatchPhase.serving) {
      final delta = dt / (serveNumber == 1 ? 1.05 : 1.25);
      serveMeter += serveMeterRising ? delta : -delta;
      if (serveMeter >= 1) {
        serveMeter = 1;
        serveMeterRising = false;
      } else if (serveMeter <= 0) {
        serveMeter = 0;
        serveMeterRising = true;
      }
    }
    if (phase == TennisMatchPhase.serving && queued != null) {
      if (server == 0) {
        _playerShot = null;
      } else {
        _opponentShot = null;
      }
      _launchServe(server, queued);
    }
  }

  void _launchServe(int server, _QueuedShot queued) {
    final body = bodyFor(server);
    final accuracy = 1 - (serveMeter - 0.82).abs() / 0.82;
    final rating = body.spec.ratings.serve / 100;
    final secondSafety = serveNumber == 2 ? 0.14 : 0;
    final quality = (accuracy * 0.72 + rating * 0.28 + secondSafety).clamp(
      0,
      1,
    );
    final side = score.rightServiceCourt ? 1.0 : -1.0;
    final direction = queued.serveAim.clamp(-1, 1);
    var targetX = side * (1.05 + direction * 1.25);
    if (server == 1) targetX *= -1;
    final targetY = server == 0 ? -4.4 : 4.4;
    final error = (1 - quality) * (serveNumber == 1 ? 2.7 : 1.6);
    targetX += (random.nextDouble() * 2 - 1) * error;
    final longError = quality < 0.45 ? (0.45 - quality) * 7 : 0;
    final actualTargetY = targetY + (server == 0 ? -longError : longError);
    final duration = 0.58 + (1 - quality) * 0.20;
    ball
      ..x = body.x
      ..y = body.y
      ..z = 2.35
      ..bounces = 0
      ..lastHitter = server
      ..live = true
      ..serve = true
      ..netTouched = false
      ..shot = TennisShotType.serve;
    _setFlight(targetX, actualTargetY, duration);
    phase = TennisMatchPhase.rally;
    _stats.firstServesAttempted += server == 0 && serveNumber == 1 ? 1 : 0;
    body
      ..swingT = 0.55
      ..swingShot = TennisShotType.serve;
  }

  void _tryContact(int team) {
    if (!canHit(team)) return;
    if (team == 1 && _opponentMissLockedFlightId == flightId) return;
    final queued = team == 0 ? _playerShot : _opponentShot;
    if (queued == null) return;
    if (team == 0) {
      _playerShot = null;
    } else {
      _opponentShot = null;
    }
    final body = bodyFor(team);
    final distance = sqrt(pow(ball.x - body.x, 2) + pow(ball.y - body.y, 2));
    final queueAge = elapsed - queued.at;
    var grade = TennisTimingGrade.good;
    final perfectWindow =
        (0.075 + body.spec.ratings.control / 2200) *
        (0.72 + body.stamina01 * 0.28) *
        (team == 0 && focusPointActive ? 1.10 : 1);
    if (distance <= 0.34 && queueAge <= perfectWindow) {
      grade = TennisTimingGrade.perfect;
    } else if (distance > 1.05) {
      grade = ball.vy * (team == 0 ? 1 : -1) > 0
          ? TennisTimingGrade.late
          : TennisTimingGrade.early;
    } else if (queueAge > 0.45) {
      grade = TennisTimingGrade.early;
    }
    final shot = _resolveShot(team, queued, grade);
    if (grade == TennisTimingGrade.missed) return;
    if (team == 1 && _opponentMissesReturn(body, distance, grade)) {
      _opponentMissLockedFlightId = flightId;
      body
        ..swingT = 0.28
        ..swingShot = shot
        ..lastTiming = TennisTimingGrade.missed;
      return;
    }
    _launchRallyShot(team, queued, shot, grade);
    body
      ..swingT = shot == TennisShotType.smash ? 0.62 : 0.36
      ..swingShot = shot
      ..lastTiming = grade;
    _events.add(
      TennisEvent(
        TennisEventType.contact,
        team: team,
        shot: shot,
        timing: grade,
        label: grade.name.toUpperCase(),
      ),
    );
    if (team == 0) {
      _stats.shots.add(shot);
      if (config.mode == TennisMode.endlessRally) {
        practiceScore++;
        _events.add(
          TennisEvent(
            TennisEventType.practiceScore,
            team: 0,
            value: practiceScore,
            label: '$practiceScore RETURNS',
          ),
        );
      }
      if (queued.aimX < -0.25) _trainingAimLeft = true;
      if (queued.aimX > 0.25) _trainingAimRight = true;
      if (grade == TennisTimingGrade.perfect) {
        _stats.perfectContacts++;
        player.focus = min(100, player.focus + 12);
        _events.add(
          const TennisEvent(
            TennisEventType.perfectContact,
            team: 0,
            label: 'PERFECT',
          ),
        );
      }
      _updateTrainingOnContact(shot, grade);
    }
  }

  bool _opponentMissesReturn(
    TennisBody body,
    double distance,
    TennisTimingGrade grade,
  ) {
    final rating = body.spec.ratings;
    final returnRating =
        (rating.control * 0.42 +
            rating.reach * 0.23 +
            rating.speed * 0.20 +
            rating.stamina * 0.15) /
        100;
    final base = 0.24 - returnRating * 0.17;
    final stretch = ((distance - 0.42) / 0.92).clamp(0, 1) * 0.17;
    final tired = (1 - body.stamina01) * 0.16;
    final timing = switch (grade) {
      TennisTimingGrade.perfect => -0.025,
      TennisTimingGrade.good => 0.0,
      TennisTimingGrade.early || TennisTimingGrade.late => 0.12,
      TennisTimingGrade.missed => 0.22,
    };
    final shotPressure = switch (ball.shot) {
      TennisShotType.serve => 0.06,
      TennisShotType.power || TennisShotType.smash => 0.05,
      TennisShotType.dropShot || TennisShotType.slice => 0.035,
      TennisShotType.topspin || TennisShotType.lob => 0.025,
      TennisShotType.volley => 0.04,
      TennisShotType.defensive || TennisShotType.normal => 0.0,
    };
    final difficultyScale = switch (config.difficulty) {
      TennisDifficulty.rookie => 1.25,
      TennisDifficulty.pro => 1.0,
      TennisDifficulty.allStar => 0.78,
    };
    final chance =
        (base + stretch + tired + timing + shotPressure) * difficultyScale;
    return random.nextDouble() < chance.clamp(0.015, 0.42);
  }

  TennisShotType _resolveShot(
    int team,
    _QueuedShot queued,
    TennisTimingGrade grade,
  ) {
    final body = bodyFor(team);
    final nearNet = body.y.abs() < 4.4;
    final highBall = ball.z > 2.05;
    final stretched =
        sqrt(pow(ball.x - body.x, 2) + pow(ball.y - body.y, 2)) > 0.95;
    if (highBall && nearNet) return TennisShotType.smash;
    if (nearNet && ball.bounces == 0) return TennisShotType.volley;
    if (stretched || grade == TennisTimingGrade.late) {
      return TennisShotType.defensive;
    }
    if (queued.aimY < -0.55) return TennisShotType.dropShot;
    if (queued.aimY < -0.16) return TennisShotType.slice;
    if (queued.aimY > 0.55) return TennisShotType.lob;
    if (queued.aimY > 0.16) return TennisShotType.topspin;
    if (queued.holdSeconds >= 0.28) return TennisShotType.power;
    return TennisShotType.normal;
  }

  void _launchRallyShot(
    int team,
    _QueuedShot queued,
    TennisShotType shot,
    TennisTimingGrade grade,
  ) {
    final body = bodyFor(team);
    final rating = body.spec.ratings;
    final side = team == 0 ? -1.0 : 1.0;
    var targetY = side * 8.8;
    var duration = 0.92;
    var staminaCost = 1.1;
    switch (shot) {
      case TennisShotType.power:
        duration = 0.68 - rating.power / 2500;
        staminaCost = 6.5;
        break;
      case TennisShotType.topspin:
        duration = 0.92;
        staminaCost = 2.2;
        break;
      case TennisShotType.slice:
        duration = 1.08;
        staminaCost = 1.8;
        break;
      case TennisShotType.lob:
        duration = 1.36;
        staminaCost = 3.2;
        break;
      case TennisShotType.volley:
        duration = 0.63;
        targetY = side * 7.2;
        staminaCost = 2.4;
        break;
      case TennisShotType.smash:
        duration = 0.54;
        staminaCost = 9.0;
        break;
      case TennisShotType.dropShot:
        duration = 0.92;
        targetY = side * 2.8;
        staminaCost = 3.5;
        break;
      case TennisShotType.defensive:
        duration = 1.28;
        targetY = side * 8.1;
        staminaCost = 1.2;
        break;
      case TennisShotType.normal:
      case TennisShotType.serve:
        duration = 0.92;
        staminaCost = 1.1;
        break;
    }
    var targetX = queued.aimX.clamp(-1, 1) * tennisCourtHalfWidth * 0.88;
    final control =
        (rating.control +
            (shot == TennisShotType.topspin || shot == TennisShotType.slice
                ? rating.spin
                : rating.power)) /
        200;
    final timingError = switch (grade) {
      TennisTimingGrade.perfect => 0.10,
      TennisTimingGrade.good => 0.35,
      TennisTimingGrade.early || TennisTimingGrade.late => 0.95,
      TennisTimingGrade.missed => 2.0,
    };
    final tiredError = (1 - body.stamina01) * 0.8;
    final difficultyError =
        shot == TennisShotType.power || shot == TennisShotType.dropShot
        ? 0.25
        : 0;
    final spread = max(
      0.04,
      timingError + tiredError + difficultyError - control * 0.38,
    );
    targetX += (random.nextDouble() * 2 - 1) * spread;
    targetY += (random.nextDouble() * 2 - 1) * spread * 0.9;
    body.stamina = max(0, body.stamina - staminaCost);
    if (team == 0) _stats.staminaSpent += staminaCost;
    ball
      ..x = body.x
      ..y = body.y
      ..z = max(0.55, ball.z)
      ..bounces = 0
      ..lastHitter = team
      ..live = true
      ..serve = false
      ..netTouched = false
      ..shot = shot;
    _setFlight(targetX, targetY, duration);
    rallyCount++;
    _stats.longestRally = max(_stats.longestRally, rallyCount);
    if (rallyCount == 5 || rallyCount == 10 || rallyCount == 20) {
      if (team == 0) player.focus = min(100, player.focus + 5);
      _events.add(
        TennisEvent(
          TennisEventType.rallyMilestone,
          team: team,
          value: rallyCount,
          label: '$rallyCount SHOTS',
        ),
      );
    }
  }

  void _setFlight(double targetX, double targetY, double duration) {
    flightId++;
    final speedScale = config.mode == TennisMode.endlessRally
        ? 1 + 0.02 * (practiceScore ~/ 5)
        : 1.0;
    final t = max(0.42, duration / speedScale);
    ball.vx = (targetX - ball.x) / t;
    ball.vy = (targetY - ball.y) / t;
    ball.vz = (0 - ball.z - 0.5 * tennisGravity * t * t) / t;
  }

  void _updateBall(double dt) {
    if (!ball.live) return;
    final previousY = ball.y;
    ball
      ..x += ball.vx * dt
      ..y += ball.vy * dt
      ..z += ball.vz * dt
      ..vz += tennisGravity * dt;

    final crossedNet =
        (previousY < 0 && ball.y >= 0) || (previousY > 0 && ball.y <= 0);
    if (crossedNet && !ball.netTouched && ball.z < tennisNetHeight) {
      ball.netTouched = true;
      flightId++;
      _events.add(
        TennisEvent(TennisEventType.net, team: ball.lastHitter, label: 'NET'),
      );
      if (ball.z >= tennisNetHeight * 0.72 && random.nextDouble() < 0.45) {
        ball.z = tennisNetHeight + 0.04;
        ball.vy *= 0.58;
        ball.vz = max(0.25, ball.vz.abs() * 0.25);
      } else {
        ball.vx *= 0.2;
        ball.vy *= -0.08;
        ball.vz = 0;
      }
    }

    if (ball.z <= 0 && ball.vz < 0) {
      ball.z = 0;
      ball.bounces++;
      ball.vz = -ball.vz * _bounceFactor(ball.shot);
      ball.vx *= 0.88;
      ball.vy *= 0.88;
      _events.add(
        TennisEvent(
          TennisEventType.bounce,
          team: ball.lastHitter,
          value: ball.bounces,
        ),
      );
      if (ball.bounces == 1) {
        if (ball.serve) {
          _resolveServeBounce();
          if (!ball.live) return;
        } else if (!tennisBallInsideSingles(ball.x, ball.y)) {
          _events.add(
            TennisEvent(
              TennisEventType.out,
              team: ball.lastHitter,
              label: 'OUT',
            ),
          );
          _awardPoint(1 - ball.lastHitter, 'OUT');
          return;
        } else if (!_onReceiverSide(ball.lastHitter, ball.y)) {
          _awardPoint(1 - ball.lastHitter, ball.netTouched ? 'NET' : 'OUT');
          return;
        } else if (config.mode == TennisMode.targetPractice &&
            ball.lastHitter == 0 &&
            ball.y < 0) {
          _scoreTarget();
          return;
        }
      }
      if (ball.bounces >= 2) {
        if (ball.serve && ball.lastHitter == score.currentServer) {
          if (ball.lastHitter == 0) _stats.aces++;
          _events.add(
            TennisEvent(
              TennisEventType.ace,
              team: ball.lastHitter,
              label: 'ACE',
            ),
          );
        }
        _awardPoint(ball.lastHitter, 'WINNER');
      }
    }

    if (ball.y.abs() > tennisCourtHalfLength + 5 ||
        ball.x.abs() > tennisCourtHalfWidth + 6) {
      _awardPoint(1 - ball.lastHitter, 'OUT');
    }
  }

  double _bounceFactor(TennisShotType shot) => switch (shot) {
    TennisShotType.slice || TennisShotType.dropShot => 0.48,
    TennisShotType.topspin => 0.72,
    TennisShotType.lob || TennisShotType.defensive => 0.76,
    _ => 0.62,
  };

  bool _onReceiverSide(int hitter, double y) => hitter == 0 ? y <= 0 : y >= 0;

  void _resolveServeBounce() {
    final server = ball.lastHitter;
    final inside = tennisServeInsideBox(
      x: ball.x,
      y: ball.y,
      server: server,
      rightServiceCourt: score.rightServiceCourt,
    );
    if (ball.netTouched && inside) {
      ball.live = false;
      _events.add(TennisEvent(TennisEventType.let, team: server, label: 'LET'));
      phase = TennisMatchPhase.pointComplete;
      pointResetT = 0.45;
      _serveContinuation = true;
      return;
    }
    if (!inside) {
      ball.live = false;
      _handleFault(server);
      return;
    }
    if (server == 0 && serveNumber == 1) _stats.firstServesIn++;
    if (server == 0 &&
        config.mode == TennisMode.training &&
        config.trainingLesson == 6) {
      _updateTrainingOnContact(TennisShotType.serve, TennisTimingGrade.good);
      if (lessonProgress == 1 && phase != TennisMatchPhase.practiceComplete) {
        ball.live = false;
        serveNumber = 2;
        _serveContinuation = true;
        phase = TennisMatchPhase.pointComplete;
        pointResetT = 0.5;
      }
    }
  }

  void _handleFault(int server) {
    _events.add(
      TennisEvent(TennisEventType.fault, team: server, label: 'FAULT'),
    );
    if (serveNumber == 1) {
      serveNumber = 2;
      _serveContinuation = true;
      phase = TennisMatchPhase.pointComplete;
      pointResetT = 0.42;
    } else {
      if (server == 0) _stats.doubleFaults++;
      _events.add(
        TennisEvent(
          TennisEventType.doubleFault,
          team: server,
          label: 'DOUBLE FAULT',
        ),
      );
      _awardPoint(1 - server, 'DOUBLE FAULT');
    }
  }

  void _awardPoint(int winner, String label) {
    if (phase == TennisMatchPhase.pointComplete || complete) return;
    ball.live = false;
    if (winner == 0 && rallyCount >= 20) _stats.wonTwentyShotRally = true;
    if (winner == 0) {
      _stats.totalPointsWon++;
    } else {
      _stats.totalPointsLost++;
      if (score.currentServer == 0) _stats.pointsLostCurrentServiceGame++;
    }
    if (winner == ball.lastHitter && label == 'WINNER') {
      if (winner == 0) {
        _stats.winners++;
        player.focus = min(100, player.focus + 8);
        if (player.y.abs() < 4.4) _stats.netPointsWon++;
      }
      _events.add(
        TennisEvent(TennisEventType.winner, team: winner, label: 'WINNER'),
      );
    } else if (winner != ball.lastHitter && ball.lastHitter == 0) {
      _stats.unforcedErrors++;
    }

    if (config.mode == TennisMode.endlessRally) {
      if (winner == 1) {
        _finishPractice();
      } else {
        phase = TennisMatchPhase.pointComplete;
        pointResetT = 0.55;
      }
      return;
    }
    if (config.mode == TennisMode.training && config.trainingLesson != 8) {
      phase = TennisMatchPhase.pointComplete;
      pointResetT = 0.55;
      return;
    }
    if (config.mode == TennisMode.targetPractice) {
      _nextTargetBall();
      return;
    }

    final savedTieBreakSetPoint =
        score.tieBreak && winner == 0 && scoring.isSetPointFor(1);
    if (savedTieBreakSetPoint) _playerSavedTieBreakSetPoint = true;
    final result = scoring.awardPoint(winner);
    serveNumber = 1;
    final deficit = score.opponentGames - score.playerGames;
    _stats.maxDeficit = max(_stats.maxDeficit, deficit);
    if (result.breakPointConverted && winner == 0) _stats.breakPointsWon++;
    if (result.breakPointSaved && winner == 0) {
      _stats.breakPointsSaved++;
      _stats.breakPointsSavedCurrentGame++;
      _stats.maxBreakPointsSavedInGame = max(
        _stats.maxBreakPointsSavedInGame,
        _stats.breakPointsSavedCurrentGame,
      );
    }
    if (result.gameWon) {
      if (winner == 0 &&
          score.currentServer == 1 &&
          _stats.pointsLostCurrentServiceGame == 0) {
        _stats.cleanHolds++;
      }
      _stats.pointsLostCurrentServiceGame = 0;
      _stats.breakPointsSavedCurrentGame = 0;
      _events.add(
        TennisEvent(
          TennisEventType.gameEnded,
          team: winner,
          label: winner == 0 ? 'GAME PLAYER' : 'GAME OPPONENT',
        ),
      );
    }
    if (result.tieBreakStarted) {
      _events.add(
        const TennisEvent(TennisEventType.tieBreakStarted, label: 'TIEBREAK'),
      );
    }
    if (result.endChange) {
      endSwapped = !endSwapped;
      _events.add(
        const TennisEvent(TennisEventType.endChange, label: 'CHANGE ENDS'),
      );
    }
    _events.add(
      TennisEvent(TennisEventType.pointEnded, team: winner, label: label),
    );
    if (result.setWon) {
      _stats.comeback = winner == 0 && _stats.maxDeficit >= 3;
      _stats.tiebreakNerve = winner == 0 && _playerSavedTieBreakSetPoint;
      phase = TennisMatchPhase.setComplete;
      if (focusPointActive) focusPointActive = false;
      _events.add(
        TennisEvent(
          TennisEventType.setEnded,
          team: winner,
          label: winner == 0 ? 'VICTORY' : 'DEFEAT',
        ),
      );
    } else if (config.mode == TennisMode.training &&
        config.trainingLesson == 8 &&
        result.gameWon) {
      lessonProgress++;
      _events.add(
        const TennisEvent(
          TennisEventType.lessonComplete,
          team: 0,
          value: 8,
          label: 'SCORING COMPLETE',
        ),
      );
      _finishPractice();
    } else {
      phase = TennisMatchPhase.pointComplete;
      pointResetT = result.gameWon ? 1.0 : 0.78;
    }
  }

  void _startPoint({bool initial = false}) {
    if (complete) return;
    final continuingPoint = !initial && _serveContinuation;
    _serveContinuation = false;
    rallyCount = 0;
    ball.live = false;
    _playerShot = null;
    _opponentShot = null;
    _opponentMissLockedFlightId = -1;
    serveMeter = 0;
    if (initial) serveNumber = 1;
    _resetBodies();
    if (!continuingPoint) {
      if (player.focus >= 100) {
        focusPointActive = true;
        player.focus = 0;
      } else {
        focusPointActive = false;
      }
    }
    if (config.mode == TennisMode.endlessRally ||
        config.mode == TennisMode.targetPractice ||
        (config.mode == TennisMode.training && config.trainingLesson != 6)) {
      _startFeed();
    } else {
      phase = TennisMatchPhase.preServe;
    }
  }

  void _resetBodies() {
    player
      ..x = score.rightServiceCourt ? -1.25 : 1.25
      ..y = 9.1;
    opponent
      ..x = score.rightServiceCourt ? 1.25 : -1.25
      ..y = -9.1;
  }

  void _startFeed() {
    opponent
      ..x = (random.nextDouble() * 2 - 1) * 1.3
      ..y = config.mode == TennisMode.training && config.trainingLesson == 5
          ? -3.2
          : -8.6;
    ball
      ..x = opponent.x
      ..y = opponent.y
      ..z = 1.1
      ..bounces = 0
      ..lastHitter = 1
      ..live = true
      ..serve = false
      ..netTouched = false
      ..shot = TennisShotType.normal;
    final target = (random.nextDouble() * 2 - 1) * 2.5;
    _setFlight(target, 7.8, 1.0);
    phase = TennisMatchPhase.rally;
  }

  void _scoreTarget() {
    final distance = sqrt(pow(ball.x - targetX, 2) + pow(ball.y - targetY, 2));
    final shrink = max(0.62, 1 - targetIndex * 0.018);
    final points = distance <= 0.65 * shrink
        ? 500
        : distance <= 1.25 * shrink
        ? 250
        : distance <= 2.1 * shrink
        ? 100
        : 25;
    practiceScore += points;
    _events.add(
      TennisEvent(
        TennisEventType.practiceScore,
        team: 0,
        value: points,
        label: '+$points',
      ),
    );
    _nextTargetBall();
  }

  void _nextTargetBall() {
    ballsRemaining--;
    if (ballsRemaining <= 0) {
      _finishPractice();
      return;
    }
    targetIndex++;
    targetX = (targetIndex.isEven ? -1 : 1) * (1.1 + (targetIndex % 3) * 0.75);
    targetY = -5.2 - (targetIndex % 4) * 1.25;
    phase = TennisMatchPhase.pointComplete;
    pointResetT = 0.55;
  }

  void _updateTrainingOnContact(TennisShotType shot, TennisTimingGrade grade) {
    if (config.mode != TennisMode.training || config.trainingLesson == null) {
      return;
    }
    final lesson = config.trainingLesson!;
    switch (lesson) {
      case 1:
        if (shot == TennisShotType.normal) lessonProgress++;
        break;
      case 2:
        if (grade == TennisTimingGrade.perfect) lessonProgress = 1;
        break;
      case 3:
        lessonProgress =
            (_trainingAimLeft ? 1 : 0) + (_trainingAimRight ? 1 : 0);
        break;
      case 4:
        if (shot == TennisShotType.power) lessonProgress = 1;
        break;
      case 5:
        if (shot == TennisShotType.lob) lessonProgress = 1;
        break;
      case 6:
        if (shot == TennisShotType.serve) lessonProgress++;
        break;
      case 7:
        if (_trainingSprintUsed) lessonProgress++;
        break;
      case 8:
        break;
    }
    final target = switch (lesson) {
      1 => 3,
      3 => 2,
      6 => 2,
      7 => 2,
      8 => 999,
      _ => 1,
    };
    if (lessonProgress >= target) {
      _events.add(
        TennisEvent(
          TennisEventType.lessonComplete,
          team: 0,
          value: lesson,
          label: 'LESSON COMPLETE',
        ),
      );
      _finishPractice();
    }
  }

  void _finishPractice() {
    ball.live = false;
    phase = TennisMatchPhase.practiceComplete;
    _events.add(
      TennisEvent(
        TennisEventType.setEnded,
        team: 0,
        value: practiceScore,
        label: config.mode == TennisMode.training
            ? 'LESSON COMPLETE'
            : 'SESSION COMPLETE',
      ),
    );
  }

  TennisMatchSummary summary({bool tournamentChampion = false}) {
    final won =
        config.mode == TennisMode.quickMatch ||
            config.mode == TennisMode.tournament
        ? score.setWinner == 0
        : true;
    return TennisMatchSummary(
      matchId: config.matchId,
      mode: config.mode,
      playerId: config.playerId,
      opponentId: config.opponentId,
      difficulty: config.difficulty,
      playerGames: score.playerGames,
      opponentGames: score.opponentGames,
      won: won,
      stats: _stats.freeze(elapsed.round()),
      practiceScore: config.mode == TennisMode.endlessRally
          ? practiceScore * 100
          : practiceScore,
      tournamentChampion: tournamentChampion,
      trainingLesson: config.trainingLesson,
    );
  }

  Map<String, dynamic> snapshot() => {
    'rng': random.state,
    'score': score.toJson(),
    'player': player.toJson(),
    'opponent': opponent.toJson(),
    'ball': ball.toJson(),
    'phase': phase.name,
    'serveNumber': serveNumber,
    'serveMeter': serveMeter,
    'serveMeterRising': serveMeterRising,
    'rallyCount': rallyCount,
    'practiceScore': practiceScore,
    'ballsRemaining': ballsRemaining,
    'lessonProgress': lessonProgress,
    'targetIndex': targetIndex,
    'flightId': flightId,
    'targetX': targetX,
    'targetY': targetY,
    'elapsed': elapsed,
    'pointResetT': pointResetT,
    'focusPointActive': focusPointActive,
    'endSwapped': endSwapped,
    'serveContinuation': _serveContinuation,
    'playerSavedTieBreakSetPoint': _playerSavedTieBreakSetPoint,
    'opponentMissLockedFlightId': _opponentMissLockedFlightId,
    'stats': _stats.toJson(),
  };

  void _restore(Map<String, dynamic> json) {
    random.state = _integer(json['rng'], config.seed) & 0x7fffffff;
    scoring = TennisScoring.fromState(
      TennisScoreState.fromJson(_map(json['score'])),
    );
    player.restore(_map(json['player']));
    opponent.restore(_map(json['opponent']));
    ball.restore(_map(json['ball']));
    phase = _enum(
      TennisMatchPhase.values,
      json['phase'],
      TennisMatchPhase.preServe,
    );
    serveNumber = _integer(json['serveNumber'], 1);
    serveMeter = _num(json['serveMeter'], 0);
    serveMeterRising = json['serveMeterRising'] as bool? ?? true;
    rallyCount = _integer(json['rallyCount'], 0);
    practiceScore = _integer(json['practiceScore'], 0);
    ballsRemaining = _integer(json['ballsRemaining'], 20);
    lessonProgress = _integer(json['lessonProgress'], 0);
    targetIndex = _integer(json['targetIndex'], 0);
    flightId = _integer(json['flightId'], 0);
    targetX = _num(json['targetX'], 0);
    targetY = _num(json['targetY'], -8);
    elapsed = _num(json['elapsed'], 0);
    pointResetT = _num(json['pointResetT'], 0);
    focusPointActive = json['focusPointActive'] as bool? ?? false;
    endSwapped = json['endSwapped'] as bool? ?? false;
    _serveContinuation = json['serveContinuation'] as bool? ?? false;
    _playerSavedTieBreakSetPoint =
        json['playerSavedTieBreakSetPoint'] as bool? ?? false;
    _opponentMissLockedFlightId = _integer(
      json['opponentMissLockedFlightId'],
      -1,
    );
    _stats.restore(_map(json['stats']));
  }
}

/// AI consumes only public engine state and emits the same intent shape as a
/// human control pad. Reaction delays are explicit and difficulty never alters
/// the body's legal movement, stamina, or reach.
class TennisAI {
  TennisAI({required this.difficulty, required int seed, this.team = 1})
    : _random = TennisRandom(seed);

  final TennisDifficulty difficulty;
  final int team;
  final TennisRandom _random;
  double _reactionT = 0;
  double _serveHold = 0;
  bool _serveDown = false;
  double _observedBallX = 0;
  double _observedBallY = 0;
  double _observedPlayerX = 0;
  double _observedPlayerY = 0;

  double get reactionDelay => switch (difficulty) {
    TennisDifficulty.rookie => 0.30,
    TennisDifficulty.pro => 0.18,
    TennisDifficulty.allStar => 0.11,
  };

  Map<String, dynamic> snapshot() => {
    'rng': _random.state,
    'reactionT': _reactionT,
    'serveHold': _serveHold,
    'serveDown': _serveDown,
    'observedBallX': _observedBallX,
    'observedBallY': _observedBallY,
    'observedPlayerX': _observedPlayerX,
    'observedPlayerY': _observedPlayerY,
  };

  void restore(Map<String, dynamic> json) {
    _random.state = _integer(json['rng'], 1) & 0x7fffffff;
    _reactionT = _num(json['reactionT'], 0);
    _serveHold = _num(json['serveHold'], 0);
    _serveDown = json['serveDown'] as bool? ?? false;
    _observedBallX = _num(json['observedBallX'], 0);
    _observedBallY = _num(json['observedBallY'], 0);
    _observedPlayerX = _num(json['observedPlayerX'], 0);
    _observedPlayerY = _num(json['observedPlayerY'], 0);
  }

  TennisIntent think(TennisEngine engine, double dt) {
    _reactionT -= dt;
    if (_reactionT <= 0) {
      _reactionT = reactionDelay;
      _observedBallX = engine.ball.x;
      _observedBallY = engine.ball.y;
      final other = engine.bodyFor(1 - team);
      _observedPlayerX = other.x;
      _observedPlayerY = other.y;
    }
    final body = engine.bodyFor(team);
    final serving =
        engine.score.currentServer == team &&
        (engine.phase == TennisMatchPhase.preServe ||
            engine.phase == TennisMatchPhase.serving);
    if (serving) {
      _serveHold += dt;
      if (!_serveDown) {
        _serveDown = true;
        return const TennisIntent(shotDown: true, shotPressed: true);
      }
      final releaseAt = switch (difficulty) {
        TennisDifficulty.rookie => 0.68,
        TennisDifficulty.pro => 0.78,
        TennisDifficulty.allStar => 0.84,
      };
      if (_serveHold >= releaseAt) {
        final held = _serveHold;
        _serveHold = 0;
        _serveDown = false;
        return TennisIntent(
          shotReleased: true,
          holdSeconds: held,
          serveAim: _random.nextInt(3) - 1,
        );
      }
      return const TennisIntent(shotDown: true);
    }
    _serveHold = 0;
    _serveDown = false;

    var targetX = 0.0;
    var targetY = team == 0 ? 8.6 : -8.6;
    final ballApproaching =
        engine.ball.live && (team == 0 ? engine.ball.y > 0 : engine.ball.y < 0);
    if (ballApproaching) {
      targetX = _observedBallX
          .clamp(-tennisCourtHalfWidth, tennisCourtHalfWidth)
          .toDouble();
      targetY = _observedBallY
          .clamp(
            team == 0 ? 1.2 : -tennisCourtHalfLength,
            team == 0 ? tennisCourtHalfLength : -1.2,
          )
          .toDouble();
    }
    final dx = (targetX - body.x).clamp(-1, 1).toDouble();
    final dy = (targetY - body.y).clamp(-1, 1).toDouble();
    final sprint =
        ballApproaching && (targetX - body.x).abs() > 1.9 && body.stamina > 24;
    if (engine.canHit(team)) {
      final aimError = switch (difficulty) {
        TennisDifficulty.rookie => 0.42,
        TennisDifficulty.pro => 0.24,
        TennisDifficulty.allStar => 0.12,
      };
      var aimX = _observedPlayerX > 0 ? -0.78 : 0.78;
      aimX += (_random.nextDouble() * 2 - 1) * aimError;
      var aimY = 0.0;
      final otherDeep = _observedPlayerY.abs() > 8.5;
      final otherAtNet = _observedPlayerY.abs() < 4.4;
      final tacticChance = switch (difficulty) {
        TennisDifficulty.rookie => 0.10,
        TennisDifficulty.pro => 0.26,
        TennisDifficulty.allStar => 0.42,
      };
      if (otherAtNet && _random.nextDouble() < tacticChance) {
        aimY = 0.8;
      } else if (otherDeep && _random.nextDouble() < tacticChance) {
        aimY = -0.72;
      }
      final hold = body.stamina > 35 && _random.nextDouble() < tacticChance
          ? 0.34
          : 0.08;
      return TennisIntent(
        moveX: dx,
        moveY: dy,
        sprint: sprint,
        shotReleased: true,
        holdSeconds: hold,
        aimX: aimX.clamp(-1, 1).toDouble(),
        aimY: aimY,
      );
    }
    return TennisIntent(moveX: dx, moveY: dy, sprint: sprint);
  }
}

T _enum<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

T? _nullableEnum<T extends Enum>(Iterable<T> values, Object? raw) {
  if (raw == null) return null;
  for (final value in values) {
    if (value.name == raw.toString()) return value;
  }
  return null;
}

double _num(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

int _integer(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
```

### A.2 `lib/games/tennis/tennis_game.dart`

<sub>836 lines</sub>

```dart
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as material;

import '../../config/theme.dart';
import '../../models/tennis.dart';
import 'tennis_engine.dart';

class TennisSting {
  const TennisSting(this.id, this.label, this.color, {this.major = false});

  final int id;
  final String label;
  final ui.Color color;
  final bool major;
}

class TennisGame extends FlameGame {
  TennisGame({
    required this.config,
    required this.settings,
    required this.onEvents,
    TennisMatchSnapshot? resume,
  }) : engine = TennisEngine(
         config,
         movementAssist: settings.movementAssist,
         snapshot: resume == null
             ? null
             : _map(
                 resume.engine.containsKey('simulation')
                     ? resume.engine['simulation']
                     : resume.engine,
               ),
       ),
       _ai = TennisAI(
         difficulty: config.difficulty,
         seed: config.seed ^ 0x71e115,
       ) {
    if (resume != null && resume.engine['ai'] is Map) {
      _ai.restore(_map(resume.engine['ai']));
    }
    final savedAccumulator = resume?.engine['accumulator'];
    if (savedAccumulator is num) {
      _accumulator = savedAccumulator.toDouble().clamp(0, _subDt);
    }
  }

  static const double _subDt = 1 / 120;

  final TennisMatchConfig config;
  TennisSettings settings;
  final void Function(List<TennisEvent> events) onEvents;
  final TennisEngine engine;
  final TennisAI _ai;

  final ValueNotifier<TennisScoreState> score = ValueNotifier(
    const TennisScoreState(),
  );
  final ValueNotifier<double> stamina01 = ValueNotifier(1);
  final ValueNotifier<double> focus01 = ValueNotifier(0);
  final ValueNotifier<double> serveMeter = ValueNotifier(0);
  final ValueNotifier<int> rally = ValueNotifier(0);
  final ValueNotifier<int> practiceScore = ValueNotifier(0);
  final ValueNotifier<int> ballsRemaining = ValueNotifier(20);
  final ValueNotifier<int> lessonProgress = ValueNotifier(0);
  final ValueNotifier<int> elapsedTenths = ValueNotifier(0);
  final ValueNotifier<TennisMatchPhase> phase = ValueNotifier(
    TennisMatchPhase.preServe,
  );
  final ValueNotifier<TennisTimingGrade?> timing = ValueNotifier(null);
  final ValueNotifier<TennisSting?> sting = ValueNotifier(null);

  double _moveX = 0;
  double _moveY = 0;
  bool _sprint = false;
  bool _shotDown = false;
  bool _shotPressed = false;
  bool _shotReleased = false;
  double _shotHold = 0;
  double _releaseHold = 0;
  double _aimX = 0;
  double _aimY = 0;
  int _serveAim = 0;
  double _accumulator = 0;
  bool _paused = false;
  double _stingT = 0;
  int _stingId = 0;
  double _cameraPush = 0;
  double _netPulse = 0;
  double _linePulse = 0;
  double _clock = 0;
  int _landingFlightId = -1;
  ui.Offset? _landingMarker;
  final List<_TrailPoint> _trail = <_TrailPoint>[];

  @override
  material.Color backgroundColor() => Cyber.bg;

  void setMove(double x, double y, {bool sprint = false}) {
    _moveX = x.clamp(-1, 1).toDouble();
    _moveY = y.clamp(-1, 1).toDouble();
    _sprint = sprint;
  }

  void shotStarted() {
    _shotDown = true;
    _shotPressed = true;
    _shotHold = 0;
  }

  void shotReleased({
    required double aimX,
    required double aimY,
    required double holdSeconds,
  }) {
    _aimX = aimX.clamp(-1, 1).toDouble();
    _aimY = aimY.clamp(-1, 1).toDouble();
    _serveAim = _aimX < -0.3 ? -1 : (_aimX > 0.3 ? 1 : 0);
    _releaseHold = max(_shotHold, holdSeconds);
    _shotReleased = true;
    _shotDown = false;
  }

  void cancelTouches() {
    _moveX = 0;
    _moveY = 0;
    _sprint = false;
    _shotDown = false;
    _shotPressed = false;
    _shotReleased = false;
    _shotHold = 0;
  }

  void setPaused(bool value) {
    _paused = value;
    engine.paused = value;
    if (value) cancelTouches();
  }

  void applySettings(TennisSettings value) {
    settings = value;
    engine.movementAssist = value.movementAssist;
  }

  TennisMatchSnapshot snapshot() => TennisMatchSnapshot(
    config: config,
    engine: <String, dynamic>{
      'simulation': engine.snapshot(),
      'ai': _ai.snapshot(),
      'accumulator': _accumulator,
    },
    savedAtMillis: DateTime.now().millisecondsSinceEpoch,
  );

  TennisMatchSummary summary({bool tournamentChampion = false}) =>
      engine.summary(tournamentChampion: tournamentChampion);

  @override
  void update(double dt) {
    super.update(dt);
    final wallDt = min(dt, 1 / 30);
    _clock += wallDt;
    if (!_paused) {
      _accumulator += wallDt;
      final events = <TennisEvent>[];
      var first = true;
      while (_accumulator >= _subDt) {
        _accumulator -= _subDt;
        events.addAll(_step(consumeEdges: first));
        first = false;
      }
      if (events.isNotEmpty) {
        _handleEvents(events);
        onEvents(events);
      }
    }
    _decayFx(wallDt);
    _syncNotifiers();
    _recordTrail();
  }

  List<TennisEvent> _step({required bool consumeEdges}) {
    if (_shotDown) _shotHold += _subDt;
    final intent = TennisIntent(
      moveX: _moveX,
      moveY: _moveY,
      sprint: _sprint,
      shotDown: _shotDown,
      shotPressed: consumeEdges && _shotPressed,
      shotReleased: consumeEdges && _shotReleased,
      holdSeconds: consumeEdges && _shotReleased ? _releaseHold : _shotHold,
      aimX: _aimX,
      aimY: _aimY,
      serveAim: _serveAim,
    );
    if (consumeEdges) {
      _shotPressed = false;
      if (_shotReleased) {
        _shotReleased = false;
        _shotHold = 0;
      }
    }
    return engine.step(intent, _ai.think(engine, _subDt), _subDt);
  }

  void _handleEvents(List<TennisEvent> events) {
    for (final event in events) {
      switch (event.type) {
        case TennisEventType.contact:
          if (event.team == 0) timing.value = event.timing;
          if (event.shot == TennisShotType.smash) {
            _showSting('SMASH', Cyber.amber, major: true);
            if (!settings.reducedMotion) _cameraPush = 1;
          }
          break;
        case TennisEventType.perfectContact:
          _showSting('PERFECT', Cyber.cyan);
          if (!settings.reducedMotion) _cameraPush = 0.55;
          break;
        case TennisEventType.winner:
          _showSting('WINNER', Cyber.lime, major: true);
          if (!settings.reducedMotion) _cameraPush = 0.8;
          break;
        case TennisEventType.ace:
          _showSting('ACE', Cyber.gold, major: true);
          break;
        case TennisEventType.fault:
          _showSting('FAULT', Cyber.amber);
          break;
        case TennisEventType.doubleFault:
          _showSting('DOUBLE FAULT', Cyber.danger, major: true);
          break;
        case TennisEventType.let:
          _showSting('LET - REPLAY', Cyber.cyan);
          break;
        case TennisEventType.net:
          _netPulse = 1;
          break;
        case TennisEventType.out:
          _linePulse = 1;
          break;
        case TennisEventType.rallyMilestone:
          _showSting(event.label ?? '${event.value} SHOTS', Cyber.cyan);
          break;
        case TennisEventType.tieBreakStarted:
          _showSting('TIEBREAK', Cyber.gold, major: true);
          break;
        case TennisEventType.endChange:
          _showSting('CHANGE ENDS', Cyber.cyan);
          break;
        case TennisEventType.lessonComplete:
          _showSting('LESSON COMPLETE', Cyber.lime, major: true);
          break;
        default:
          break;
      }
    }
  }

  void _showSting(String label, ui.Color color, {bool major = false}) {
    sting.value = TennisSting(++_stingId, label, color, major: major);
    _stingT = major ? 1.35 : 0.85;
  }

  void _decayFx(double dt) {
    if (_stingT > 0) {
      _stingT = max(0, _stingT - dt);
      if (_stingT == 0) sting.value = null;
    }
    _cameraPush = max(0, _cameraPush - dt * 2.5);
    _netPulse = max(0, _netPulse - dt * 3.2);
    _linePulse = max(0, _linePulse - dt * 2.6);
  }

  void _syncNotifiers() {
    if (!identical(score.value, engine.score)) score.value = engine.score;
    _setDouble(stamina01, engine.player.stamina01);
    _setDouble(focus01, engine.player.focus01);
    _setDouble(serveMeter, engine.serveMeter);
    if (rally.value != engine.rallyCount) rally.value = engine.rallyCount;
    if (practiceScore.value != engine.practiceScore) {
      practiceScore.value = engine.practiceScore;
    }
    if (ballsRemaining.value != engine.ballsRemaining) {
      ballsRemaining.value = engine.ballsRemaining;
    }
    if (lessonProgress.value != engine.lessonProgress) {
      lessonProgress.value = engine.lessonProgress;
    }
    final nextElapsed = (engine.elapsed * 10).floor();
    if (elapsedTenths.value != nextElapsed) elapsedTenths.value = nextElapsed;
    if (phase.value != engine.phase) phase.value = engine.phase;
  }

  void _setDouble(ValueNotifier<double> notifier, double value) {
    if ((notifier.value - value).abs() > 0.002) notifier.value = value;
  }

  void _recordTrail() {
    if (!engine.ball.live) {
      _trail.clear();
      return;
    }
    final point = _TrailPoint(engine.ball.x, engine.ball.y, engine.ball.z);
    if (_trail.isEmpty || _trail.last.distanceTo(point) > 0.34) {
      _trail.add(point);
      final limit = settings.reducedMotion ? 2 : 7;
      if (_trail.length > limit) _trail.removeAt(0);
    }
  }

  @override
  void render(ui.Canvas canvas) {
    _drawAtmosphere(canvas);
    _drawCourt(canvas);
    _drawPrediction(canvas);
    _drawPlayer(canvas, engine.opponent);
    _drawPlayer(canvas, engine.player);
    _drawBall(canvas);
    super.render(canvas);
  }

  void _drawAtmosphere(ui.Canvas canvas) {
    final rect = ui.Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(
      rect,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          ui.Offset(size.x * 0.5, 0),
          ui.Offset(size.x * 0.5, size.y),
          const <ui.Color>[
            ui.Color(0xff101f2b),
            Cyber.bg,
            ui.Color(0xff040814),
          ],
          const <double>[0, 0.55, 1],
        ),
    );
    final crowdPaint = ui.Paint()..color = Cyber.cyan.withValues(alpha: 0.08);
    for (var row = 0; row < 4; row++) {
      final y = size.y * (0.07 + row * 0.027);
      for (var i = 0; i < 22; i++) {
        final x = (i + (row.isOdd ? 0.5 : 0)) * size.x / 21;
        canvas.drawCircle(ui.Offset(x, y), 1.2 + row * 0.25, crowdPaint);
      }
    }
    canvas.drawRect(
      ui.Rect.fromLTWH(0, size.y * 0.125, size.x, 2),
      ui.Paint()..color = Cyber.lime.withValues(alpha: 0.18),
    );
  }

  void _drawCourt(ui.Canvas canvas) {
    final corners = <ui.Offset>[
      _courtPoint(-tennisCourtHalfWidth, -tennisCourtHalfLength),
      _courtPoint(tennisCourtHalfWidth, -tennisCourtHalfLength),
      _courtPoint(tennisCourtHalfWidth, tennisCourtHalfLength),
      _courtPoint(-tennisCourtHalfWidth, tennisCourtHalfLength),
    ];
    final shadow = ui.Path()..moveTo(corners.first.dx, corners.first.dy + 9);
    for (final point in corners.skip(1)) {
      shadow.lineTo(point.dx, point.dy + 14);
    }
    shadow.close();
    canvas.drawPath(
      shadow,
      ui.Paint()..color = const ui.Color(0xff02050b).withValues(alpha: 0.82),
    );
    final court = ui.Path()..moveTo(corners.first.dx, corners.first.dy);
    for (final point in corners.skip(1)) {
      court.lineTo(point.dx, point.dy);
    }
    court.close();
    canvas.drawPath(
      court,
      ui.Paint()
        ..shader = ui.Gradient.linear(
          corners.first,
          corners[2],
          const <ui.Color>[ui.Color(0xff164b50), ui.Color(0xff0b303b)],
        ),
    );
    canvas.drawPath(
      court,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..color = Cyber.cyan.withValues(alpha: 0.52 + _linePulse * 0.32),
    );

    final line = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeCap = ui.StrokeCap.square
      ..strokeWidth = 1.45
      ..color = material.Colors.white.withValues(alpha: 0.84);
    _drawWorldLine(
      canvas,
      -tennisCourtHalfWidth,
      -tennisCourtHalfLength,
      -tennisCourtHalfWidth,
      tennisCourtHalfLength,
      line,
    );
    _drawWorldLine(
      canvas,
      tennisCourtHalfWidth,
      -tennisCourtHalfLength,
      tennisCourtHalfWidth,
      tennisCourtHalfLength,
      line,
    );
    for (final y in <double>[
      -tennisCourtHalfLength,
      -tennisServiceLine,
      tennisServiceLine,
      tennisCourtHalfLength,
    ]) {
      _drawWorldLine(
        canvas,
        -tennisCourtHalfWidth,
        y,
        tennisCourtHalfWidth,
        y,
        line,
      );
    }
    _drawWorldLine(canvas, 0, -tennisServiceLine, 0, tennisServiceLine, line);
    _drawNet(canvas);

    if (config.mode == TennisMode.targetPractice) {
      _drawTarget(canvas, engine.targetX, engine.targetY);
    }
  }

  void _drawNet(ui.Canvas canvas) {
    final left = _courtPoint(-tennisCourtHalfWidth - 0.25, 0);
    final right = _courtPoint(tennisCourtHalfWidth + 0.25, 0);
    final height = 18.0;
    final pulse = _netPulse * 3;
    final netPaint = ui.Paint()
      ..color = material.Colors.white.withValues(alpha: 0.56 + _netPulse * 0.3)
      ..strokeWidth = 0.8;
    for (var i = 0; i <= 10; i++) {
      final t = i / 10;
      final x = ui.lerpDouble(left.dx, right.dx, t)!;
      canvas.drawLine(
        ui.Offset(x, left.dy - height + sin(_clock * 18 + i) * pulse),
        ui.Offset(x, left.dy),
        netPaint,
      );
    }
    for (var i = 0; i <= 4; i++) {
      final y = left.dy - height + i * height / 4;
      canvas.drawLine(ui.Offset(left.dx, y), ui.Offset(right.dx, y), netPaint);
    }
    canvas.drawLine(
      ui.Offset(left.dx, left.dy - height),
      ui.Offset(right.dx, right.dy - height),
      ui.Paint()
        ..color = material.Colors.white.withValues(alpha: 0.92)
        ..strokeWidth = 2.1,
    );
    for (final post in <ui.Offset>[left, right]) {
      canvas.drawLine(
        post,
        post.translate(0, -height - 4),
        ui.Paint()
          ..color = Cyber.cyan
          ..strokeWidth = 2.5,
      );
    }
  }

  void _drawPrediction(ui.Canvas canvas) {
    final ball = engine.ball;
    if (!ball.live || ball.bounces > 0) {
      _landingMarker = null;
      _landingFlightId = -1;
      return;
    }
    if (_landingFlightId != engine.flightId) {
      _landingFlightId = engine.flightId;
      _landingMarker = _calculateLanding();
    }
    final landing = _landingMarker;
    if (landing == null || landing.dy.abs() > tennisCourtHalfLength + 2) return;
    final center = _courtPoint(landing.dx, landing.dy);
    final active = engine.focusPointActive;
    final color = active ? Cyber.lime : Cyber.cyan;
    final alpha = active ? 0.74 : 0.32;
    canvas.drawOval(
      ui.Rect.fromCenter(center: center, width: active ? 34 : 26, height: 12),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = active ? 2.4 : 1.3
        ..color = color.withValues(alpha: alpha),
    );
    canvas.drawCircle(
      center,
      active ? 3.5 : 2.5,
      ui.Paint()..color = color.withValues(alpha: alpha),
    );
  }

  ui.Offset? _calculateLanding() {
    final ball = engine.ball;
    if (!ball.live) return null;
    final a = tennisGravity * 0.5;
    final discriminant = ball.vz * ball.vz - 4 * a * ball.z;
    if (discriminant < 0) return null;
    final root = sqrt(discriminant);
    final roots = <double>[
      (-ball.vz + root) / (2 * a),
      (-ball.vz - root) / (2 * a),
    ].where((value) => value > 0.01).toList()..sort();
    if (roots.isEmpty) return null;
    final t = roots.first;
    return ui.Offset(ball.x + ball.vx * t, ball.y + ball.vy * t);
  }

  void _drawTarget(ui.Canvas canvas, double x, double y) {
    final center = _courtPoint(x, y);
    final shrink = max(0.62, 1 - engine.targetIndex * 0.018);
    final colors = <ui.Color>[Cyber.cyan, Cyber.lime, Cyber.gold];
    final widths = <double>[54, 34, 16];
    for (var i = 0; i < widths.length; i++) {
      canvas.drawOval(
        ui.Rect.fromCenter(
          center: center,
          width: widths[i] * shrink,
          height: widths[i] * 0.38 * shrink,
        ),
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors[i].withValues(alpha: 0.72),
      );
    }
  }

  void _drawPlayer(ui.Canvas canvas, TennisBody body) {
    final feet = _courtPoint(body.x, body.y);
    final depth = _depth(body.y);
    final scale = 0.58 + depth * 0.48;
    final palette = _palette(body.spec.id);
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: feet.translate(0, 3),
        width: 28 * scale,
        height: 7 * scale,
      ),
      ui.Paint()..color = material.Colors.black.withValues(alpha: 0.38),
    );
    final swing = body.swingT > 0 ? min(1.0, body.swingT * 3.2) : 0.0;
    final isBackhand = engine.ball.x < body.x;
    final lean = body.swingShot == TennisShotType.smash ? -5.0 : 0.0;
    final hip = feet.translate(0, -19 * scale + lean * scale);
    final shoulder = hip.translate(0, -22 * scale);
    final head = shoulder.translate(0, -11 * scale);
    final limb = ui.Paint()
      ..color = palette.skin
      ..strokeWidth = 6 * scale
      ..strokeCap = ui.StrokeCap.round;
    final uniform = ui.Paint()
      ..color = palette.shirt
      ..strokeWidth = 12 * scale
      ..strokeCap = ui.StrokeCap.round;
    final leg = ui.Paint()
      ..color = palette.shorts
      ..strokeWidth = 7 * scale
      ..strokeCap = ui.StrokeCap.round;
    final stride = sin(_clock * 9 + body.team) * 4 * scale;
    canvas.drawLine(
      hip.translate(-3 * scale, 0),
      feet.translate(-6 * scale + stride, -1),
      leg,
    );
    canvas.drawLine(
      hip.translate(3 * scale, 0),
      feet.translate(6 * scale - stride, -1),
      leg,
    );
    canvas.drawLine(hip, shoulder, uniform);
    final nonRacketHand = shoulder.translate(
      (isBackhand ? 7 : -7) * scale,
      12 * scale,
    );
    canvas.drawLine(shoulder, nonRacketHand, limb);

    var racketHand = shoulder.translate(10 * scale, 10 * scale);
    if (swing > 0) {
      final shot = body.swingShot;
      if (shot == TennisShotType.smash || shot == TennisShotType.serve) {
        racketHand = shoulder.translate(
          (isBackhand ? -8 : 8) * scale,
          (-24 + 16 * swing) * scale,
        );
      } else if (shot == TennisShotType.slice ||
          shot == TennisShotType.dropShot) {
        racketHand = shoulder.translate(
          (isBackhand ? -22 : 22) * scale,
          (4 + 13 * swing) * scale,
        );
      } else {
        racketHand = shoulder.translate(
          (isBackhand ? -26 : 26) * scale * (0.35 + swing),
          (8 - 15 * swing) * scale,
        );
      }
    }
    canvas.drawLine(shoulder, racketHand, limb);
    final racketEnd = racketHand.translate(
      (isBackhand ? -1 : 1) * 14 * scale,
      -5 * scale,
    );
    canvas.drawLine(
      racketHand,
      racketEnd,
      ui.Paint()
        ..color = Cyber.border
        ..strokeWidth = 2.2 * scale,
    );
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: racketEnd.translate((isBackhand ? -1 : 1) * 6 * scale, -2),
        width: 12 * scale,
        height: 18 * scale,
      ),
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2 * scale
        ..color = palette.racket,
    );
    canvas.drawCircle(head, 7.5 * scale, ui.Paint()..color = palette.skin);
    canvas.drawArc(
      ui.Rect.fromCircle(center: head.translate(0, -1), radius: 7.8 * scale),
      pi,
      pi,
      false,
      ui.Paint()
        ..color = palette.hair
        ..strokeWidth = 4 * scale
        ..style = ui.PaintingStyle.stroke,
    );
    if (body.team == 0 && engine.focusPointActive) {
      canvas.drawCircle(
        hip,
        28 * scale,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Cyber.lime.withValues(alpha: 0.5),
      );
    }
  }

  void _drawBall(ui.Canvas canvas) {
    final ball = engine.ball;
    if (!ball.live) return;
    for (var i = 0; i < _trail.length; i++) {
      final point = _trail[i];
      final alpha = (i + 1) / _trail.length * 0.16;
      canvas.drawCircle(
        _ballPoint(point.x, point.y, point.z),
        2.1,
        ui.Paint()..color = Cyber.lime.withValues(alpha: alpha),
      );
    }
    final floor = _courtPoint(ball.x, ball.y);
    final center = _ballPoint(ball.x, ball.y, ball.z);
    final depth = _depth(ball.y);
    final radius = 3.4 + depth * 1.25;
    canvas.drawOval(
      ui.Rect.fromCenter(
        center: floor.translate(0, 2),
        width: radius * 3.2,
        height: radius * 1.1,
      ),
      ui.Paint()
        ..color = material.Colors.black.withValues(
          alpha: (0.32 - min(0.22, ball.z * 0.055)),
        ),
    );
    canvas.drawCircle(
      center,
      radius + 2.2,
      ui.Paint()..color = Cyber.lime.withValues(alpha: 0.12),
    );
    canvas.drawCircle(
      center,
      radius,
      ui.Paint()
        ..shader = ui.Gradient.radial(
          center.translate(-1.2, -1.2),
          radius * 1.5,
          const <ui.Color>[ui.Color(0xfff5ff8b), ui.Color(0xffa8d520)],
        ),
    );
    canvas.drawArc(
      ui.Rect.fromCircle(center: center, radius: radius * 0.72),
      -1.1,
      1.7,
      false,
      ui.Paint()
        ..color = material.Colors.white.withValues(alpha: 0.72)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _drawWorldLine(
    ui.Canvas canvas,
    double x1,
    double y1,
    double x2,
    double y2,
    ui.Paint paint,
  ) {
    canvas.drawLine(_courtPoint(x1, y1), _courtPoint(x2, y2), paint);
  }

  ui.Offset _courtPoint(double x, double y) {
    final depth = _depth(y);
    final zoom = 1 + _cameraPush * 0.025;
    final courtY = ui.lerpDouble(size.y * 0.17, size.y * 0.80, depth)!;
    final halfWidth = ui.lerpDouble(size.x * 0.245, size.x * 0.475, depth)!;
    final centerX = size.x * 0.5;
    return ui.Offset(
      centerX + x / tennisCourtHalfWidth * halfWidth * zoom,
      size.y * 0.5 + (courtY - size.y * 0.5) * zoom,
    );
  }

  ui.Offset _ballPoint(double x, double y, double z) {
    final floor = _courtPoint(x, y);
    final lift = z * (14 + _depth(y) * 10);
    return floor.translate(0, -lift);
  }

  double _depth(double y) =>
      ((y + tennisCourtHalfLength) / (tennisCourtHalfLength * 2))
          .clamp(0, 1)
          .toDouble();
}

class _TrailPoint {
  const _TrailPoint(this.x, this.y, this.z);

  final double x;
  final double y;
  final double z;

  double distanceTo(_TrailPoint other) =>
      sqrt(pow(x - other.x, 2) + pow(y - other.y, 2) + pow(z - other.z, 2));
}

class _AthletePalette {
  const _AthletePalette({
    required this.skin,
    required this.hair,
    required this.shirt,
    required this.shorts,
    required this.racket,
  });

  final ui.Color skin;
  final ui.Color hair;
  final ui.Color shirt;
  final ui.Color shorts;
  final ui.Color racket;
}

_AthletePalette _palette(String id) => switch (id) {
  'jett-okafor' => const _AthletePalette(
    skin: ui.Color(0xff8f5738),
    hair: ui.Color(0xff121011),
    shirt: ui.Color(0xffff8e4f),
    shorts: ui.Color(0xff26314d),
    racket: Cyber.amber,
  ),
  'mira-chen' => const _AthletePalette(
    skin: ui.Color(0xffe1a37e),
    hair: ui.Color(0xff17131c),
    shirt: ui.Color(0xff55e7c4),
    shorts: ui.Color(0xff18304a),
    racket: Cyber.cyan,
  ),
  'luca-vale' => const _AthletePalette(
    skin: ui.Color(0xffd3a078),
    hair: ui.Color(0xff5b3625),
    shirt: ui.Color(0xffffd55d),
    shorts: ui.Color(0xff323241),
    racket: Cyber.gold,
  ),
  'sora-malik' => const _AthletePalette(
    skin: ui.Color(0xffad704d),
    hair: ui.Color(0xff221922),
    shirt: ui.Color(0xff9ee568),
    shorts: ui.Color(0xff1c3a35),
    racket: Cyber.lime,
  ),
  'kaia-brooks' => const _AthletePalette(
    skin: ui.Color(0xff70432f),
    hair: ui.Color(0xff161015),
    shirt: ui.Color(0xffff6f91),
    shorts: ui.Color(0xff3a233d),
    racket: Cyber.pink,
  ),
  'theo-laurent' => const _AthletePalette(
    skin: ui.Color(0xffc88f67),
    hair: ui.Color(0xff352a20),
    shirt: ui.Color(0xff6bbdff),
    shorts: ui.Color(0xff1e304d),
    racket: Cyber.cyan,
  ),
  'riven-cole' => const _AthletePalette(
    skin: ui.Color(0xff9c6447),
    hair: ui.Color(0xff151517),
    shirt: ui.Color(0xffef6dff),
    shorts: ui.Color(0xff2d2546),
    racket: Cyber.violet,
  ),
  _ => const _AthletePalette(
    skin: ui.Color(0xffca8464),
    hair: ui.Color(0xff30201e),
    shirt: ui.Color(0xff67dcff),
    shorts: ui.Color(0xff20314a),
    racket: Cyber.cyan,
  ),
};

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
```

### A.3 `lib/models/tennis.dart`

<sub>1104 lines</sub>

```dart
import 'dart:math';

import '../config/enums.dart';
import '../data/tennis_athletes.dart';
import 'starter_pack.dart';

enum TennisMode {
  quickMatch,
  tournament,
  endlessRally,
  targetPractice,
  training,
}

enum TennisDifficulty { rookie, pro, allStar }

enum TennisArchetype {
  allRounder,
  powerBaseliner,
  speedDefender,
  serveAndVolley,
  spinSpecialist,
  allCourtRival,
}

enum TennisShotType {
  normal,
  power,
  topspin,
  slice,
  lob,
  volley,
  smash,
  dropShot,
  defensive,
  serve,
}

enum TennisTimingGrade { perfect, good, early, late, missed }

enum TennisMatchPhase {
  preServe,
  serving,
  rally,
  pointComplete,
  setComplete,
  practiceComplete,
}

extension TennisModeLabel on TennisMode {
  String get label => switch (this) {
    TennisMode.quickMatch => 'QUICK MATCH',
    TennisMode.tournament => 'TOURNAMENT',
    TennisMode.endlessRally => 'ENDLESS RALLY',
    TennisMode.targetPractice => 'TARGET PRACTICE',
    TennisMode.training => 'TRAINING',
  };
}

extension TennisDifficultyLabel on TennisDifficulty {
  String get label => switch (this) {
    TennisDifficulty.rookie => 'ROOKIE',
    TennisDifficulty.pro => 'PRO',
    TennisDifficulty.allStar => 'ALL-STAR',
  };

  int get winCoins => switch (this) {
    TennisDifficulty.rookie => 20,
    TennisDifficulty.pro => 30,
    TennisDifficulty.allStar => 40,
  };

  int get xpBonus => switch (this) {
    TennisDifficulty.rookie => 0,
    TennisDifficulty.pro => 4,
    TennisDifficulty.allStar => 8,
  };
}

extension TennisArchetypeLabel on TennisArchetype {
  String get label => switch (this) {
    TennisArchetype.allRounder => 'ALL-ROUNDER',
    TennisArchetype.powerBaseliner => 'POWER BASELINER',
    TennisArchetype.speedDefender => 'SPEED DEFENDER',
    TennisArchetype.serveAndVolley => 'SERVE & VOLLEY',
    TennisArchetype.spinSpecialist => 'SPIN SPECIALIST',
    TennisArchetype.allCourtRival => 'ALL-COURT RIVAL',
  };
}

extension TennisShotLabel on TennisShotType {
  String get label => switch (this) {
    TennisShotType.normal => 'GOOD',
    TennisShotType.power => 'POWER',
    TennisShotType.topspin => 'TOPSPIN',
    TennisShotType.slice => 'SLICE',
    TennisShotType.lob => 'LOB',
    TennisShotType.volley => 'VOLLEY',
    TennisShotType.smash => 'SMASH',
    TennisShotType.dropShot => 'DROP SHOT',
    TennisShotType.defensive => 'DEFENSIVE',
    TennisShotType.serve => 'SERVE',
  };
}

class TennisRatings {
  const TennisRatings({
    required this.speed,
    required this.acceleration,
    required this.power,
    required this.control,
    required this.serve,
    required this.stamina,
    required this.volley,
    required this.spin,
    required this.reach,
  });

  factory TennisRatings.fromJson(Map<String, dynamic> json) => TennisRatings(
    speed: _int(json['speed'], 75),
    acceleration: _int(json['acceleration'], 75),
    power: _int(json['power'], 75),
    control: _int(json['control'], 75),
    serve: _int(json['serve'], 75),
    stamina: _int(json['stamina'], 75),
    volley: _int(json['volley'], 75),
    spin: _int(json['spin'], 75),
    reach: _int(json['reach'], 75),
  );

  final int speed;
  final int acceleration;
  final int power;
  final int control;
  final int serve;
  final int stamina;
  final int volley;
  final int spin;
  final int reach;

  int get overall =>
      (speed +
          acceleration +
          power +
          control +
          serve +
          stamina +
          volley +
          spin +
          reach) ~/
      9;

  Map<String, dynamic> toJson() => {
    'speed': speed,
    'acceleration': acceleration,
    'power': power,
    'control': control,
    'serve': serve,
    'stamina': stamina,
    'volley': volley,
    'spin': spin,
    'reach': reach,
  };
}

class TennisPlayer {
  const TennisPlayer({
    required this.id,
    required this.name,
    required this.archetype,
    required this.ratings,
    required this.signature,
    required this.overallRating,
  });

  final String id;
  final String name;
  final TennisArchetype archetype;
  final TennisRatings ratings;
  final String signature;
  final int overallRating;

  CardTier get tier => packRarityForRating(overallRating);
}

/// The playable tennis roster. Backed by the real Top 100 (2026) list so that
/// starter-pack pulls, CPU opponents and the Flame engine all resolve against
/// the same athletes.
const tennisPlayers = tennisTop100;

TennisPlayer tennisPlayerById(String id) => tennisPlayers.firstWhere(
  (player) => player.id == id,
  orElse: () => tennisPlayers.first,
);

class TennisSettings {
  const TennisSettings({
    this.leftHanded = false,
    this.controlScale = 1,
    this.controlOpacity = 0.82,
    this.movementAssist = true,
    this.reducedMotion = false,
    this.strongFlashes = true,
    this.haptics = true,
    this.music = true,
    this.sound = true,
  });

  factory TennisSettings.fromJson(Map<String, dynamic> json) => TennisSettings(
    leftHanded: json['leftHanded'] as bool? ?? false,
    controlScale: _double(json['controlScale'], 1).clamp(0.8, 1.25).toDouble(),
    controlOpacity: _double(
      json['controlOpacity'],
      0.82,
    ).clamp(0.45, 1).toDouble(),
    movementAssist: json['movementAssist'] as bool? ?? true,
    reducedMotion: json['reducedMotion'] as bool? ?? false,
    strongFlashes: json['strongFlashes'] as bool? ?? true,
    haptics: json['haptics'] as bool? ?? true,
    music: json['music'] as bool? ?? true,
    sound: json['sound'] as bool? ?? true,
  );

  final bool leftHanded;
  final double controlScale;
  final double controlOpacity;
  final bool movementAssist;
  final bool reducedMotion;
  final bool strongFlashes;
  final bool haptics;
  final bool music;
  final bool sound;

  TennisSettings copyWith({
    bool? leftHanded,
    double? controlScale,
    double? controlOpacity,
    bool? movementAssist,
    bool? reducedMotion,
    bool? strongFlashes,
    bool? haptics,
    bool? music,
    bool? sound,
  }) => TennisSettings(
    leftHanded: leftHanded ?? this.leftHanded,
    controlScale: controlScale ?? this.controlScale,
    controlOpacity: controlOpacity ?? this.controlOpacity,
    movementAssist: movementAssist ?? this.movementAssist,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    strongFlashes: strongFlashes ?? this.strongFlashes,
    haptics: haptics ?? this.haptics,
    music: music ?? this.music,
    sound: sound ?? this.sound,
  );

  Map<String, dynamic> toJson() => {
    'leftHanded': leftHanded,
    'controlScale': controlScale,
    'controlOpacity': controlOpacity,
    'movementAssist': movementAssist,
    'reducedMotion': reducedMotion,
    'strongFlashes': strongFlashes,
    'haptics': haptics,
    'music': music,
    'sound': sound,
  };
}

class TennisMatchConfig {
  const TennisMatchConfig({
    required this.matchId,
    required this.mode,
    required this.playerId,
    required this.opponentId,
    required this.difficulty,
    required this.seed,
    this.trainingLesson,
    this.tournamentId,
    this.tournamentRound,
  });

  factory TennisMatchConfig.fromJson(Map<String, dynamic> json) =>
      TennisMatchConfig(
        matchId: json['matchId'] as String? ?? 'restored-match',
        mode: _enumByName(
          TennisMode.values,
          json['mode'],
          TennisMode.quickMatch,
        ),
        playerId: json['playerId'] as String? ?? tennisPlayers.first.id,
        opponentId: json['opponentId'] as String? ?? tennisPlayers[1].id,
        difficulty: _enumByName(
          TennisDifficulty.values,
          json['difficulty'],
          TennisDifficulty.pro,
        ),
        seed: _int(json['seed'], 1),
        trainingLesson: json['trainingLesson'] as int?,
        tournamentId: json['tournamentId'] as String?,
        tournamentRound: json['tournamentRound'] as int?,
      );

  final String matchId;
  final TennisMode mode;
  final String playerId;
  final String opponentId;
  final TennisDifficulty difficulty;
  final int seed;
  final int? trainingLesson;
  final String? tournamentId;
  final int? tournamentRound;

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'mode': mode.name,
    'playerId': playerId,
    'opponentId': opponentId,
    'difficulty': difficulty.name,
    'seed': seed,
    'trainingLesson': trainingLesson,
    'tournamentId': tournamentId,
    'tournamentRound': tournamentRound,
  };
}

class TennisScoreState {
  const TennisScoreState({
    this.playerGames = 0,
    this.opponentGames = 0,
    this.playerPoints = 0,
    this.opponentPoints = 0,
    this.advantage = -1,
    this.tieBreak = false,
    this.playerTieBreak = 0,
    this.opponentTieBreak = 0,
    this.firstServer = 0,
    this.currentServer = 0,
    this.pointsInGame = 0,
    this.totalGames = 0,
    this.setWinner = -1,
    this.tieBreakFirstServer = 0,
  });

  factory TennisScoreState.fromJson(Map<String, dynamic> json) =>
      TennisScoreState(
        playerGames: _int(json['playerGames'], 0),
        opponentGames: _int(json['opponentGames'], 0),
        playerPoints: _int(json['playerPoints'], 0),
        opponentPoints: _int(json['opponentPoints'], 0),
        advantage: _int(json['advantage'], -1),
        tieBreak: json['tieBreak'] as bool? ?? false,
        playerTieBreak: _int(json['playerTieBreak'], 0),
        opponentTieBreak: _int(json['opponentTieBreak'], 0),
        firstServer: _int(json['firstServer'], 0),
        currentServer: _int(json['currentServer'], 0),
        pointsInGame: _int(json['pointsInGame'], 0),
        totalGames: _int(json['totalGames'], 0),
        setWinner: _int(json['setWinner'], -1),
        tieBreakFirstServer: _int(json['tieBreakFirstServer'], 0),
      );

  final int playerGames;
  final int opponentGames;
  final int playerPoints;
  final int opponentPoints;
  final int advantage;
  final bool tieBreak;
  final int playerTieBreak;
  final int opponentTieBreak;
  final int firstServer;
  final int currentServer;
  final int pointsInGame;
  final int totalGames;
  final int setWinner;
  final int tieBreakFirstServer;

  bool get isDeuce => !tieBreak && playerPoints >= 3 && opponentPoints >= 3;
  bool get complete => setWinner >= 0;
  bool get rightServiceCourt => pointsInGame.isEven;

  String pointLabel(int player) {
    if (tieBreak) {
      return '${player == 0 ? playerTieBreak : opponentTieBreak}';
    }
    if (advantage == player) return 'AD';
    if (isDeuce) return '40';
    final points = player == 0 ? playerPoints : opponentPoints;
    return switch (points.clamp(0, 3).toInt()) {
      0 => 'LOVE',
      1 => '15',
      2 => '30',
      _ => '40',
    };
  }

  Map<String, dynamic> toJson() => {
    'playerGames': playerGames,
    'opponentGames': opponentGames,
    'playerPoints': playerPoints,
    'opponentPoints': opponentPoints,
    'advantage': advantage,
    'tieBreak': tieBreak,
    'playerTieBreak': playerTieBreak,
    'opponentTieBreak': opponentTieBreak,
    'firstServer': firstServer,
    'currentServer': currentServer,
    'pointsInGame': pointsInGame,
    'totalGames': totalGames,
    'setWinner': setWinner,
    'tieBreakFirstServer': tieBreakFirstServer,
  };
}

class TennisMatchStats {
  const TennisMatchStats({
    this.durationSeconds = 0,
    this.aces = 0,
    this.doubleFaults = 0,
    this.winners = 0,
    this.unforcedErrors = 0,
    this.breakPointsWon = 0,
    this.breakPointsSaved = 0,
    this.maxBreakPointsSavedInGame = 0,
    this.firstServesIn = 0,
    this.firstServesAttempted = 0,
    this.perfectContacts = 0,
    this.longestRally = 0,
    this.netPointsWon = 0,
    this.totalPointsWon = 0,
    this.totalPointsLost = 0,
    this.staminaSpent = 0,
    this.cleanHolds = 0,
    this.comebackFromThreeGames = false,
    this.tiebreakNerve = false,
    this.wonTwentyShotRally = false,
    this.shotTypesUsed = const <TennisShotType>{},
  });

  factory TennisMatchStats.fromJson(
    Map<String, dynamic> json,
  ) => TennisMatchStats(
    durationSeconds: _int(json['durationSeconds'], 0),
    aces: _int(json['aces'], 0),
    doubleFaults: _int(json['doubleFaults'], 0),
    winners: _int(json['winners'], 0),
    unforcedErrors: _int(json['unforcedErrors'], 0),
    breakPointsWon: _int(json['breakPointsWon'], 0),
    breakPointsSaved: _int(json['breakPointsSaved'], 0),
    maxBreakPointsSavedInGame: _int(json['maxBreakPointsSavedInGame'], 0),
    firstServesIn: _int(json['firstServesIn'], 0),
    firstServesAttempted: _int(json['firstServesAttempted'], 0),
    perfectContacts: _int(json['perfectContacts'], 0),
    longestRally: _int(json['longestRally'], 0),
    netPointsWon: _int(json['netPointsWon'], 0),
    totalPointsWon: _int(json['totalPointsWon'], 0),
    totalPointsLost: _int(json['totalPointsLost'], 0),
    staminaSpent: _double(json['staminaSpent'], 0),
    cleanHolds: _int(json['cleanHolds'], 0),
    comebackFromThreeGames: json['comebackFromThreeGames'] as bool? ?? false,
    tiebreakNerve: json['tiebreakNerve'] as bool? ?? false,
    wonTwentyShotRally: json['wonTwentyShotRally'] as bool? ?? false,
    shotTypesUsed: _stringList(json['shotTypesUsed'])
        .map(
          (name) =>
              _enumByName(TennisShotType.values, name, TennisShotType.normal),
        )
        .toSet(),
  );

  final int durationSeconds;
  final int aces;
  final int doubleFaults;
  final int winners;
  final int unforcedErrors;
  final int breakPointsWon;
  final int breakPointsSaved;
  final int maxBreakPointsSavedInGame;
  final int firstServesIn;
  final int firstServesAttempted;
  final int perfectContacts;
  final int longestRally;
  final int netPointsWon;
  final int totalPointsWon;
  final int totalPointsLost;
  final double staminaSpent;
  final int cleanHolds;
  final bool comebackFromThreeGames;
  final bool tiebreakNerve;
  final bool wonTwentyShotRally;
  final Set<TennisShotType> shotTypesUsed;

  double get firstServePercentage =>
      firstServesAttempted == 0 ? 0 : firstServesIn / firstServesAttempted;

  int get totalPoints => totalPointsWon + totalPointsLost;

  Map<String, dynamic> toJson() => {
    'durationSeconds': durationSeconds,
    'aces': aces,
    'doubleFaults': doubleFaults,
    'winners': winners,
    'unforcedErrors': unforcedErrors,
    'breakPointsWon': breakPointsWon,
    'breakPointsSaved': breakPointsSaved,
    'maxBreakPointsSavedInGame': maxBreakPointsSavedInGame,
    'firstServesIn': firstServesIn,
    'firstServesAttempted': firstServesAttempted,
    'perfectContacts': perfectContacts,
    'longestRally': longestRally,
    'netPointsWon': netPointsWon,
    'totalPointsWon': totalPointsWon,
    'totalPointsLost': totalPointsLost,
    'staminaSpent': staminaSpent,
    'cleanHolds': cleanHolds,
    'comebackFromThreeGames': comebackFromThreeGames,
    'tiebreakNerve': tiebreakNerve,
    'wonTwentyShotRally': wonTwentyShotRally,
    'shotTypesUsed': shotTypesUsed.map((shot) => shot.name).toList(),
  };
}

class TennisMatchSummary {
  const TennisMatchSummary({
    required this.matchId,
    required this.mode,
    required this.playerId,
    required this.opponentId,
    required this.difficulty,
    required this.playerGames,
    required this.opponentGames,
    required this.won,
    required this.stats,
    this.practiceScore = 0,
    this.tournamentChampion = false,
    this.trainingLesson,
  });

  final String matchId;
  final TennisMode mode;
  final String playerId;
  final String opponentId;
  final TennisDifficulty difficulty;
  final int playerGames;
  final int opponentGames;
  final bool won;
  final TennisMatchStats stats;
  final int practiceScore;
  final bool tournamentChampion;
  final int? trainingLesson;

  int get performanceScore {
    final result = won ? 20 : (playerGames + 2 >= opponentGames ? 10 : 4);
    final difficultyScore = switch (difficulty) {
      TennisDifficulty.rookie => 2,
      TennisDifficulty.pro => 6,
      TennisDifficulty.allStar => 10,
    };
    final serve = (stats.firstServePercentage * 15).round().clamp(0, 15);
    final shotBalance = (8 + stats.winners - stats.unforcedErrors * 2).clamp(
      0,
      15,
    );
    final breakPlay = (stats.breakPointsWon * 3 + stats.breakPointsSaved * 2)
        .clamp(0, 10);
    final perfect = (stats.perfectContacts * 2).clamp(0, 10);
    final rally = (stats.longestRally / 2).round().clamp(0, 10);
    final stamina = (5 - stats.staminaSpent / 80).round().clamp(0, 5);
    final variety = stats.shotTypesUsed.length.clamp(0, 5);
    return (result +
            difficultyScore +
            serve +
            shotBalance +
            breakPlay +
            perfect +
            rally +
            stamina +
            variety)
        .clamp(0, 100)
        .toInt();
  }

  String get grade => switch (performanceScore) {
    >= 90 => 'S',
    >= 78 => 'A',
    >= 64 => 'B',
    >= 48 => 'C',
    _ => 'D',
  };

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'mode': mode.name,
    'playerId': playerId,
    'opponentId': opponentId,
    'difficulty': difficulty.name,
    'playerGames': playerGames,
    'opponentGames': opponentGames,
    'won': won,
    'stats': stats.toJson(),
    'practiceScore': practiceScore,
    'tournamentChampion': tournamentChampion,
    'trainingLesson': trainingLesson,
  };
}

class TennisReward {
  const TennisReward({
    required this.xp,
    required this.coins,
    required this.masteryXp,
    required this.farmed,
  });

  static const zero = TennisReward(
    xp: 0,
    coins: 0,
    masteryXp: 0,
    farmed: false,
  );

  final int xp;
  final int coins;
  final int masteryXp;
  final bool farmed;
}

class TennisTournament {
  const TennisTournament({
    required this.id,
    required this.playerId,
    required this.difficulty,
    required this.entrants,
    required this.opponents,
    this.currentRound = 0,
    this.results = const <String>[],
    this.active = true,
    this.champion = false,
  });

  factory TennisTournament.fromJson(Map<String, dynamic> json) =>
      TennisTournament(
        id: json['id'] as String? ?? 'tournament',
        playerId: json['playerId'] as String? ?? tennisPlayers.first.id,
        difficulty: _enumByName(
          TennisDifficulty.values,
          json['difficulty'],
          TennisDifficulty.pro,
        ),
        entrants: _stringList(json['entrants']),
        opponents: _stringList(json['opponents']),
        currentRound: _int(json['currentRound'], 0),
        results: _stringList(json['results']),
        active: json['active'] as bool? ?? true,
        champion: json['champion'] as bool? ?? false,
      );

  final String id;
  final String playerId;
  final TennisDifficulty difficulty;
  final List<String> entrants;
  final List<String> opponents;
  final int currentRound;
  final List<String> results;
  final bool active;
  final bool champion;

  String? get currentOpponentId => active && currentRound < opponents.length
      ? opponents[currentRound]
      : null;

  TennisTournament copyWith({
    int? currentRound,
    List<String>? results,
    bool? active,
    bool? champion,
  }) => TennisTournament(
    id: id,
    playerId: playerId,
    difficulty: difficulty,
    entrants: entrants,
    opponents: opponents,
    currentRound: currentRound ?? this.currentRound,
    results: results ?? this.results,
    active: active ?? this.active,
    champion: champion ?? this.champion,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'playerId': playerId,
    'difficulty': difficulty.name,
    'entrants': entrants,
    'opponents': opponents,
    'currentRound': currentRound,
    'results': results,
    'active': active,
    'champion': champion,
  };
}

class TennisProfile {
  const TennisProfile({
    this.schemaVersion = 1,
    this.starterPackClaimed = false,
    this.ownedPlayerIds = const <String>[],
    this.selectedPlayerId = 'arthur-fery',
    this.lastOpponentId = 'alexander-blockx',
    this.difficulty = TennisDifficulty.pro,
    this.settings = const TennisSettings(),
    this.setsPlayed = 0,
    this.setsWon = 0,
    this.currentWinStreak = 0,
    this.bestWinStreak = 0,
    this.totalAces = 0,
    this.longestRally = 0,
    this.cleanHolds = 0,
    this.breaksConverted = 0,
    this.breakPointsSaved = 0,
    this.netPointsWon = 0,
    this.serveVolleyNetPoints = 0,
    this.comebackSets = 0,
    this.tiebreakNerveWins = 0,
    this.stylesWon = const <TennisArchetype>{},
    this.achievements = const <String>{},
    this.masteryXp = const <String, int>{},
    this.completedLessons = const <int>{},
    this.trophies = const <String, int>{},
    this.bestEndless = 0,
    this.bestTarget = 0,
    this.lastQuickSignature,
    this.quickRepeatCount = 0,
    this.settledMatchIds = const <String>[],
    this.tournament,
  });

  factory TennisProfile.fromJson(Map<String, dynamic> json) {
    final selectedPlayerId =
        json['selectedPlayerId'] as String? ?? tennisPlayers.first.id;
    final hasStarterFields =
        json.containsKey('starterPackClaimed') ||
        json.containsKey('ownedPlayerIds');
    final claimed = json['starterPackClaimed'] as bool? ?? !hasStarterFields;
    final owned = _stringList(json['ownedPlayerIds']);
    final ownedPlayerIds = owned.isNotEmpty || !claimed
        ? owned
        : <String>[selectedPlayerId];
    return TennisProfile(
      schemaVersion: _int(json['schemaVersion'], 1),
      starterPackClaimed: claimed,
      ownedPlayerIds: ownedPlayerIds,
      selectedPlayerId: selectedPlayerId,
      lastOpponentId: json['lastOpponentId'] as String? ?? tennisPlayers[1].id,
      difficulty: _enumByName(
        TennisDifficulty.values,
        json['difficulty'],
        TennisDifficulty.pro,
      ),
      settings: TennisSettings.fromJson(_map(json['settings'])),
      setsPlayed: _int(json['setsPlayed'], 0),
      setsWon: _int(json['setsWon'], 0),
      currentWinStreak: _int(json['currentWinStreak'], 0),
      bestWinStreak: _int(json['bestWinStreak'], 0),
      totalAces: _int(json['totalAces'], 0),
      longestRally: _int(json['longestRally'], 0),
      cleanHolds: _int(json['cleanHolds'], 0),
      breaksConverted: _int(json['breaksConverted'], 0),
      breakPointsSaved: _int(json['breakPointsSaved'], 0),
      netPointsWon: _int(json['netPointsWon'], 0),
      serveVolleyNetPoints: _int(json['serveVolleyNetPoints'], 0),
      comebackSets: _int(json['comebackSets'], 0),
      tiebreakNerveWins: _int(json['tiebreakNerveWins'], 0),
      stylesWon: _stringList(json['stylesWon'])
          .map(
            (name) => _enumByName(
              TennisArchetype.values,
              name,
              TennisArchetype.allRounder,
            ),
          )
          .toSet(),
      achievements: _stringList(json['achievements']).toSet(),
      masteryXp: _intMap(json['masteryXp']),
      completedLessons: _intSet(json['completedLessons']),
      trophies: _intMap(json['trophies']),
      bestEndless: _int(json['bestEndless'], 0),
      bestTarget: _int(json['bestTarget'], 0),
      lastQuickSignature: json['lastQuickSignature'] as String?,
      quickRepeatCount: _int(json['quickRepeatCount'], 0),
      settledMatchIds: _stringList(json['settledMatchIds']),
      tournament: json['tournament'] is Map
          ? TennisTournament.fromJson(_map(json['tournament']))
          : null,
    );
  }

  final int schemaVersion;
  final bool starterPackClaimed;
  final List<String> ownedPlayerIds;
  final String selectedPlayerId;
  final String lastOpponentId;
  final TennisDifficulty difficulty;
  final TennisSettings settings;
  final int setsPlayed;
  final int setsWon;
  final int currentWinStreak;
  final int bestWinStreak;
  final int totalAces;
  final int longestRally;
  final int cleanHolds;
  final int breaksConverted;
  final int breakPointsSaved;
  final int netPointsWon;
  final int serveVolleyNetPoints;
  final int comebackSets;
  final int tiebreakNerveWins;
  final Set<TennisArchetype> stylesWon;
  final Set<String> achievements;
  final Map<String, int> masteryXp;
  final Set<int> completedLessons;
  final Map<String, int> trophies;
  final int bestEndless;
  final int bestTarget;
  final String? lastQuickSignature;
  final int quickRepeatCount;
  final List<String> settledMatchIds;
  final TennisTournament? tournament;

  int masteryFor(String playerId) => masteryXp[playerId] ?? 0;

  int masteryLevel(String playerId) {
    var remaining = masteryFor(playerId);
    var level = 1;
    while (level < 10 && remaining >= level * 100) {
      remaining -= level * 100;
      level++;
    }
    return level;
  }

  double masteryProgress(String playerId) {
    var remaining = masteryFor(playerId);
    var level = 1;
    while (level < 10 && remaining >= level * 100) {
      remaining -= level * 100;
      level++;
    }
    if (level >= 10) return 1;
    return (remaining / (level * 100)).clamp(0, 1).toDouble();
  }

  bool ownsPlayer(String playerId) => ownedPlayerIds.contains(playerId);

  /// Playable athletes are exactly the ones the player has collected. Tennis
  /// shares the card economy with the other sports now, so cards beyond the
  /// starter are earned through packs rather than hardcoded unlock rules.
  bool isPlayerUnlocked(String playerId) => ownsPlayer(playerId);

  TennisProfile copyWith({
    bool? starterPackClaimed,
    List<String>? ownedPlayerIds,
    String? selectedPlayerId,
    String? lastOpponentId,
    TennisDifficulty? difficulty,
    TennisSettings? settings,
    int? setsPlayed,
    int? setsWon,
    int? currentWinStreak,
    int? bestWinStreak,
    int? totalAces,
    int? longestRally,
    int? cleanHolds,
    int? breaksConverted,
    int? breakPointsSaved,
    int? netPointsWon,
    int? serveVolleyNetPoints,
    int? comebackSets,
    int? tiebreakNerveWins,
    Set<TennisArchetype>? stylesWon,
    Set<String>? achievements,
    Map<String, int>? masteryXp,
    Set<int>? completedLessons,
    Map<String, int>? trophies,
    int? bestEndless,
    int? bestTarget,
    String? lastQuickSignature,
    int? quickRepeatCount,
    List<String>? settledMatchIds,
    TennisTournament? tournament,
    bool clearTournament = false,
  }) => TennisProfile(
    schemaVersion: schemaVersion,
    starterPackClaimed: starterPackClaimed ?? this.starterPackClaimed,
    ownedPlayerIds: ownedPlayerIds ?? this.ownedPlayerIds,
    selectedPlayerId: selectedPlayerId ?? this.selectedPlayerId,
    lastOpponentId: lastOpponentId ?? this.lastOpponentId,
    difficulty: difficulty ?? this.difficulty,
    settings: settings ?? this.settings,
    setsPlayed: setsPlayed ?? this.setsPlayed,
    setsWon: setsWon ?? this.setsWon,
    currentWinStreak: currentWinStreak ?? this.currentWinStreak,
    bestWinStreak: bestWinStreak ?? this.bestWinStreak,
    totalAces: totalAces ?? this.totalAces,
    longestRally: longestRally ?? this.longestRally,
    cleanHolds: cleanHolds ?? this.cleanHolds,
    breaksConverted: breaksConverted ?? this.breaksConverted,
    breakPointsSaved: breakPointsSaved ?? this.breakPointsSaved,
    netPointsWon: netPointsWon ?? this.netPointsWon,
    serveVolleyNetPoints: serveVolleyNetPoints ?? this.serveVolleyNetPoints,
    comebackSets: comebackSets ?? this.comebackSets,
    tiebreakNerveWins: tiebreakNerveWins ?? this.tiebreakNerveWins,
    stylesWon: stylesWon ?? this.stylesWon,
    achievements: achievements ?? this.achievements,
    masteryXp: masteryXp ?? this.masteryXp,
    completedLessons: completedLessons ?? this.completedLessons,
    trophies: trophies ?? this.trophies,
    bestEndless: bestEndless ?? this.bestEndless,
    bestTarget: bestTarget ?? this.bestTarget,
    lastQuickSignature: lastQuickSignature ?? this.lastQuickSignature,
    quickRepeatCount: quickRepeatCount ?? this.quickRepeatCount,
    settledMatchIds: settledMatchIds ?? this.settledMatchIds,
    tournament: clearTournament ? null : (tournament ?? this.tournament),
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'starterPackClaimed': starterPackClaimed,
    'ownedPlayerIds': ownedPlayerIds,
    'selectedPlayerId': selectedPlayerId,
    'lastOpponentId': lastOpponentId,
    'difficulty': difficulty.name,
    'settings': settings.toJson(),
    'setsPlayed': setsPlayed,
    'setsWon': setsWon,
    'currentWinStreak': currentWinStreak,
    'bestWinStreak': bestWinStreak,
    'totalAces': totalAces,
    'longestRally': longestRally,
    'cleanHolds': cleanHolds,
    'breaksConverted': breaksConverted,
    'breakPointsSaved': breakPointsSaved,
    'netPointsWon': netPointsWon,
    'serveVolleyNetPoints': serveVolleyNetPoints,
    'comebackSets': comebackSets,
    'tiebreakNerveWins': tiebreakNerveWins,
    'stylesWon': stylesWon.map((style) => style.name).toList(),
    'achievements': achievements.toList(),
    'masteryXp': masteryXp,
    'completedLessons': completedLessons.toList(),
    'trophies': trophies,
    'bestEndless': bestEndless,
    'bestTarget': bestTarget,
    'lastQuickSignature': lastQuickSignature,
    'quickRepeatCount': quickRepeatCount,
    'settledMatchIds': settledMatchIds,
    'tournament': tournament?.toJson(),
  };
}

class TennisMatchSnapshot {
  const TennisMatchSnapshot({
    this.schemaVersion = 1,
    required this.config,
    required this.engine,
    required this.savedAtMillis,
  });

  factory TennisMatchSnapshot.fromJson(Map<String, dynamic> json) =>
      TennisMatchSnapshot(
        schemaVersion: _int(json['schemaVersion'], 1),
        config: TennisMatchConfig.fromJson(_map(json['config'])),
        engine: _map(json['engine']),
        savedAtMillis: _int(json['savedAtMillis'], 0),
      );

  final int schemaVersion;
  final TennisMatchConfig config;
  final Map<String, dynamic> engine;
  final int savedAtMillis;

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'config': config.toJson(),
    'engine': engine,
    'savedAtMillis': savedAtMillis,
  };
}

TennisReward calculateTennisReward(
  TennisMatchSummary summary,
  TennisProfile profile,
) {
  if (summary.mode == TennisMode.training) {
    final first =
        summary.trainingLesson != null &&
        !profile.completedLessons.contains(summary.trainingLesson);
    return TennisReward(
      xp: first ? 5 : 0,
      coins: 0,
      masteryXp: first ? 8 : 2,
      farmed: false,
    );
  }
  if (summary.mode == TennisMode.endlessRally ||
      summary.mode == TennisMode.targetPractice) {
    return TennisReward(
      xp: min(12, summary.practiceScore ~/ 100),
      coins: 0,
      masteryXp: min(12, summary.practiceScore ~/ 80),
      farmed: false,
    );
  }

  final signature =
      '${summary.playerId}:${summary.opponentId}:'
      '${summary.difficulty.name}';
  final repeatedRookie =
      summary.mode == TennisMode.quickMatch &&
      summary.difficulty == TennisDifficulty.rookie &&
      profile.lastQuickSignature == signature &&
      profile.quickRepeatCount >= 3;
  final gradeBonus = switch (summary.grade) {
    'S' => 10,
    'A' => 7,
    'B' => 4,
    'C' => 2,
    _ => 0,
  };
  final performanceBonus = min(
    8,
    min(3, summary.stats.aces) +
        (summary.stats.longestRally >= 20 ? 2 : 0) +
        (summary.stats.comebackFromThreeGames ? 2 : 0) +
        (summary.stats.breakPointsSaved >= 3 ? 2 : 0),
  );
  var xp = 12;
  var coins = 0;
  if (summary.won) {
    xp += 10;
    coins = repeatedRookie ? 10 : summary.difficulty.winCoins;
  }
  if (!repeatedRookie) {
    xp += summary.difficulty.xpBonus + gradeBonus + performanceBonus;
  }
  if (summary.mode == TennisMode.tournament && summary.won) {
    coins = (coins * 1.25).round();
    if (summary.tournamentChampion) {
      xp += 30;
      coins += 75;
    }
  }
  final masteryGrade = switch (summary.grade) {
    'S' => 20,
    'A' => 15,
    'B' => 10,
    'C' => 5,
    _ => 0,
  };
  final mastery =
      20 +
      (summary.won ? 20 : 0) +
      masteryGrade +
      min(10, summary.stats.shotTypesUsed.length * 2).toInt();
  return TennisReward(
    xp: xp,
    coins: coins,
    masteryXp: mastery,
    farmed: repeatedRookie,
  );
}

T _enumByName<T extends Enum>(Iterable<T> values, Object? raw, T fallback) {
  final name = raw?.toString();
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

int _int(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

double _double(Object? value, double fallback) =>
    value is num ? value.toDouble() : fallback;

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<String> _stringList(Object? value) => value is List
    ? value.whereType<Object>().map((item) => item.toString()).toList()
    : <String>[];

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return <String, int>{};
  return {
    for (final entry in value.entries)
      entry.key.toString(): entry.value is num
          ? (entry.value as num).toInt()
          : 0,
  };
}

Set<int> _intSet(Object? value) => value is List
    ? value.whereType<num>().map((item) => item.toInt()).toSet()
    : <int>{};
```

### A.4 `lib/data/tennis_athletes.dart`

<sub>1809 lines</sub>

```dart
import '../models/tennis.dart';

/// Top 100 current tennis players (2026), ATP and WTA combined.
///
/// Sub-ratings are shaped by each athlete's [TennisArchetype] and average
/// out to [TennisPlayer.overallRating], which is what drives both the card
/// tier ([packRarityForRating]) and the rally physics in the Flame engine.
const tennisTop100 = <TennisPlayer>[
  TennisPlayer(
    id: 'jannik-sinner',
    name: 'Jannik Sinner',
    archetype: TennisArchetype.allCourtRival,
    signature: 'Complete all-court pressure without a weak zone',
    ratings: TennisRatings(
      speed: 99,
      acceleration: 99,
      power: 97,
      control: 93,
      serve: 97,
      stamina: 96,
      volley: 93,
      spin: 94,
      reach: 96,
    ),
    overallRating: 96,
  ),
  TennisPlayer(
    id: 'alexander-zverev',
    name: 'Alexander Zverev',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Big serve into an immediate forehand',
    ratings: TennisRatings(
      speed: 91,
      acceleration: 93,
      power: 96,
      control: 91,
      serve: 95,
      stamina: 94,
      volley: 93,
      spin: 97,
      reach: 96,
    ),
    overallRating: 94,
  ),
  TennisPlayer(
    id: 'carlos-alcaraz',
    name: 'Carlos Alcaraz',
    archetype: TennisArchetype.allCourtRival,
    signature: 'Raises another level in the big moments',
    ratings: TennisRatings(
      speed: 91,
      acceleration: 94,
      power: 92,
      control: 99,
      serve: 96,
      stamina: 98,
      volley: 89,
      spin: 96,
      reach: 91,
    ),
    overallRating: 94,
  ),
  TennisPlayer(
    id: 'felix-auger-aliassime',
    name: 'Félix Auger-Aliassime',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Fast serve followed by decisive net pressure',
    ratings: TennisRatings(
      speed: 93,
      acceleration: 94,
      power: 94,
      control: 91,
      serve: 94,
      stamina: 90,
      volley: 95,
      spin: 87,
      reach: 90,
    ),
    overallRating: 92,
  ),
  TennisPlayer(
    id: 'alex-de-minaur',
    name: 'Alex de Minaur',
    archetype: TennisArchetype.speedDefender,
    signature: 'Relentless legs deep behind the baseline',
    ratings: TennisRatings(
      speed: 95,
      acceleration: 98,
      power: 90,
      control: 93,
      serve: 89,
      stamina: 93,
      volley: 91,
      spin: 93,
      reach: 86,
    ),
    overallRating: 92,
  ),
  TennisPlayer(
    id: 'ben-shelton',
    name: 'Ben Shelton',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Ends points early with raw power',
    ratings: TennisRatings(
      speed: 84,
      acceleration: 84,
      power: 96,
      control: 86,
      serve: 96,
      stamina: 89,
      volley: 88,
      spin: 85,
      reach: 93,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'novak-djokovic',
    name: 'Novak Djokovic',
    archetype: TennisArchetype.allCourtRival,
    signature: 'Complete all-court pressure without a weak zone',
    ratings: TennisRatings(
      speed: 90,
      acceleration: 90,
      power: 87,
      control: 89,
      serve: 92,
      stamina: 91,
      volley: 88,
      spin: 91,
      reach: 83,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'daniil-medvedev',
    name: 'Daniil Medvedev',
    archetype: TennisArchetype.speedDefender,
    signature: 'Absorbs pace and resets the point',
    ratings: TennisRatings(
      speed: 98,
      acceleration: 98,
      power: 82,
      control: 94,
      serve: 81,
      stamina: 91,
      volley: 87,
      spin: 86,
      reach: 84,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'flavio-cobolli',
    name: 'Flavio Cobolli',
    archetype: TennisArchetype.allRounder,
    signature: 'Solid from everywhere with no clear hole',
    ratings: TennisRatings(
      speed: 93,
      acceleration: 93,
      power: 88,
      control: 90,
      serve: 88,
      stamina: 92,
      volley: 84,
      spin: 87,
      reach: 86,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'taylor-fritz',
    name: 'Taylor Fritz',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Flattens the ball and takes time away',
    ratings: TennisRatings(
      speed: 87,
      acceleration: 89,
      power: 98,
      control: 89,
      serve: 92,
      stamina: 86,
      volley: 83,
      spin: 87,
      reach: 90,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'alexander-bublik',
    name: 'Alexander Bublik',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Chips and charges at every opening',
    ratings: TennisRatings(
      speed: 84,
      acceleration: 84,
      power: 89,
      control: 80,
      serve: 93,
      stamina: 81,
      volley: 99,
      spin: 73,
      reach: 82,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'jiri-lehecka',
    name: 'Jiří Lehečka',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Big serve into an immediate forehand',
    ratings: TennisRatings(
      speed: 84,
      acceleration: 80,
      power: 99,
      control: 83,
      serve: 92,
      stamina: 82,
      volley: 77,
      spin: 82,
      reach: 86,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'casper-ruud',
    name: 'Casper Ruud',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Heavy topspin that climbs off the bounce',
    ratings: TennisRatings(
      speed: 86,
      acceleration: 89,
      power: 76,
      control: 90,
      serve: 80,
      stamina: 93,
      volley: 83,
      spin: 93,
      reach: 75,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'lorenzo-musetti',
    name: 'Lorenzo Musetti',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Heavy topspin that climbs off the bounce',
    ratings: TennisRatings(
      speed: 83,
      acceleration: 88,
      power: 78,
      control: 92,
      serve: 81,
      stamina: 93,
      volley: 80,
      spin: 94,
      reach: 76,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'learner-tien',
    name: 'Learner Tien',
    archetype: TennisArchetype.speedDefender,
    signature: 'Covers the court and outlasts the rally',
    ratings: TennisRatings(
      speed: 97,
      acceleration: 93,
      power: 74,
      control: 89,
      serve: 77,
      stamina: 91,
      volley: 80,
      spin: 84,
      reach: 80,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'andrey-rublev',
    name: 'Andrey Rublev',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Ends points early with raw power',
    ratings: TennisRatings(
      speed: 80,
      acceleration: 84,
      power: 98,
      control: 85,
      serve: 90,
      stamina: 80,
      volley: 78,
      spin: 84,
      reach: 86,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'frances-tiafoe',
    name: 'Frances Tiafoe',
    archetype: TennisArchetype.allRounder,
    signature: 'Balanced timing and reliable recovery',
    ratings: TennisRatings(
      speed: 87,
      acceleration: 87,
      power: 83,
      control: 90,
      serve: 80,
      stamina: 87,
      volley: 82,
      spin: 88,
      reach: 81,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'luciano-darderi',
    name: 'Luciano Darderi',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Never gives the same ball twice',
    ratings: TennisRatings(
      speed: 85,
      acceleration: 85,
      power: 83,
      control: 91,
      serve: 80,
      stamina: 89,
      volley: 83,
      spin: 95,
      reach: 74,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'jakub-mensik',
    name: 'Jakub Menšík',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Big serve into an immediate forehand',
    ratings: TennisRatings(
      speed: 81,
      acceleration: 79,
      power: 96,
      control: 82,
      serve: 95,
      stamina: 86,
      volley: 77,
      spin: 82,
      reach: 87,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'alejandro-davidovich-fokina',
    name: 'Alejandro Davidovich Fokina',
    archetype: TennisArchetype.speedDefender,
    signature: 'Absorbs pace and resets the point',
    ratings: TennisRatings(
      speed: 98,
      acceleration: 94,
      power: 77,
      control: 88,
      serve: 72,
      stamina: 94,
      volley: 79,
      spin: 89,
      reach: 74,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'valentin-vacherot',
    name: 'Valentin Vacherot',
    archetype: TennisArchetype.allRounder,
    signature: 'Balanced timing and reliable recovery',
    ratings: TennisRatings(
      speed: 82,
      acceleration: 86,
      power: 78,
      control: 85,
      serve: 76,
      stamina: 85,
      volley: 80,
      spin: 79,
      reach: 78,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'francisco-cerundolo',
    name: 'Francisco Cerundolo',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Never gives the same ball twice',
    ratings: TennisRatings(
      speed: 77,
      acceleration: 81,
      power: 72,
      control: 91,
      serve: 79,
      stamina: 89,
      volley: 81,
      spin: 91,
      reach: 68,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'arthur-fils',
    name: 'Arthur Fils',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Big serve into an immediate forehand',
    ratings: TennisRatings(
      speed: 78,
      acceleration: 78,
      power: 94,
      control: 79,
      serve: 89,
      stamina: 78,
      volley: 72,
      spin: 77,
      reach: 84,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'tommy-paul',
    name: 'Tommy Paul',
    archetype: TennisArchetype.speedDefender,
    signature: 'Elite retrieval and counterattack speed',
    ratings: TennisRatings(
      speed: 92,
      acceleration: 92,
      power: 72,
      control: 85,
      serve: 68,
      stamina: 92,
      volley: 74,
      spin: 83,
      reach: 71,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'rafael-jodar',
    name: 'Rafael Jodar',
    archetype: TennisArchetype.allRounder,
    signature: 'Adapts the plan as the match turns',
    ratings: TennisRatings(
      speed: 85,
      acceleration: 85,
      power: 77,
      control: 83,
      serve: 77,
      stamina: 82,
      volley: 79,
      spin: 81,
      reach: 80,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'karen-khachanov',
    name: 'Karen Khachanov',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Flattens the ball and takes time away',
    ratings: TennisRatings(
      speed: 78,
      acceleration: 76,
      power: 94,
      control: 82,
      serve: 90,
      stamina: 78,
      volley: 74,
      spin: 77,
      reach: 80,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'joao-fonseca',
    name: 'Joao Fonseca',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Heavy first strike from the baseline',
    ratings: TennisRatings(
      speed: 77,
      acceleration: 79,
      power: 91,
      control: 81,
      serve: 91,
      stamina: 80,
      volley: 71,
      spin: 78,
      reach: 81,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'arthur-rinderknech',
    name: 'Arthur Rinderknech',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Wins the short points with clean hands',
    ratings: TennisRatings(
      speed: 79,
      acceleration: 82,
      power: 82,
      control: 73,
      serve: 95,
      stamina: 74,
      volley: 97,
      spin: 67,
      reach: 80,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'ugo-humbert',
    name: 'Ugo Humbert',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Fast serve followed by decisive net pressure',
    ratings: TennisRatings(
      speed: 81,
      acceleration: 86,
      power: 84,
      control: 73,
      serve: 92,
      stamina: 73,
      volley: 94,
      spin: 67,
      reach: 79,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'tomas-martin-etcheverry',
    name: 'Tomas Martin Etcheverry',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Never gives the same ball twice',
    ratings: TennisRatings(
      speed: 75,
      acceleration: 83,
      power: 75,
      control: 91,
      serve: 78,
      stamina: 84,
      volley: 81,
      spin: 92,
      reach: 70,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'alejandro-tabilo',
    name: 'Alejandro Tabilo',
    archetype: TennisArchetype.allRounder,
    signature: 'Steady rhythm that wears opponents down',
    ratings: TennisRatings(
      speed: 87,
      acceleration: 82,
      power: 80,
      control: 84,
      serve: 79,
      stamina: 81,
      volley: 78,
      spin: 80,
      reach: 78,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'brandon-nakashima',
    name: 'Brandon Nakashima',
    archetype: TennisArchetype.allRounder,
    signature: 'Solid from everywhere with no clear hole',
    ratings: TennisRatings(
      speed: 86,
      acceleration: 84,
      power: 79,
      control: 86,
      serve: 79,
      stamina: 80,
      volley: 80,
      spin: 79,
      reach: 76,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'ignacio-buse',
    name: 'Ignacio Buse',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Heavy topspin that climbs off the bounce',
    ratings: TennisRatings(
      speed: 82,
      acceleration: 83,
      power: 75,
      control: 91,
      serve: 75,
      stamina: 88,
      volley: 74,
      spin: 94,
      reach: 67,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'matteo-arnaldi',
    name: 'Matteo Arnaldi',
    archetype: TennisArchetype.allRounder,
    signature: 'Solid from everywhere with no clear hole',
    ratings: TennisRatings(
      speed: 82,
      acceleration: 85,
      power: 80,
      control: 85,
      serve: 79,
      stamina: 83,
      volley: 79,
      spin: 80,
      reach: 76,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'zizou-bergs',
    name: 'Zizou Bergs',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Overwhelming pace off both wings',
    ratings: TennisRatings(
      speed: 77,
      acceleration: 80,
      power: 93,
      control: 82,
      serve: 91,
      stamina: 76,
      volley: 72,
      spin: 78,
      reach: 80,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'arthur-fery',
    name: 'Arthur Fery',
    archetype: TennisArchetype.allRounder,
    signature: 'Balanced timing and reliable recovery',
    ratings: TennisRatings(
      speed: 77,
      acceleration: 83,
      power: 75,
      control: 79,
      serve: 77,
      stamina: 82,
      volley: 76,
      spin: 77,
      reach: 76,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'alexander-blockx',
    name: 'Alexander Blockx',
    archetype: TennisArchetype.allRounder,
    signature: 'Solid from everywhere with no clear hole',
    ratings: TennisRatings(
      speed: 80,
      acceleration: 82,
      power: 74,
      control: 79,
      serve: 77,
      stamina: 79,
      volley: 78,
      spin: 81,
      reach: 72,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'cameron-norrie',
    name: 'Cameron Norrie',
    archetype: TennisArchetype.speedDefender,
    signature: 'Turns defence into offence in one step',
    ratings: TennisRatings(
      speed: 92,
      acceleration: 88,
      power: 63,
      control: 82,
      serve: 66,
      stamina: 89,
      volley: 72,
      spin: 82,
      reach: 68,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'denis-shapovalov',
    name: 'Denis Shapovalov',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Big serve into an immediate forehand',
    ratings: TennisRatings(
      speed: 74,
      acceleration: 70,
      power: 92,
      control: 79,
      serve: 88,
      stamina: 75,
      volley: 73,
      spin: 73,
      reach: 78,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'corentin-moutet',
    name: 'Corentin Moutet',
    archetype: TennisArchetype.speedDefender,
    signature: 'Turns defence into offence in one step',
    ratings: TennisRatings(
      speed: 90,
      acceleration: 87,
      power: 70,
      control: 83,
      serve: 66,
      stamina: 87,
      volley: 71,
      spin: 77,
      reach: 71,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'jan-lennard-struff',
    name: 'Jan-Lennard Struff',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Cuts the rally short with soft touch',
    ratings: TennisRatings(
      speed: 76,
      acceleration: 80,
      power: 82,
      control: 70,
      serve: 89,
      stamina: 70,
      volley: 93,
      spin: 63,
      reach: 79,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'raphael-collignon',
    name: 'Raphael Collignon',
    archetype: TennisArchetype.allRounder,
    signature: 'Clean fundamentals under pressure',
    ratings: TennisRatings(
      speed: 79,
      acceleration: 80,
      power: 75,
      control: 79,
      serve: 74,
      stamina: 85,
      volley: 74,
      spin: 80,
      reach: 76,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'matteo-berrettini',
    name: 'Matteo Berrettini',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Heavy first strike from the baseline',
    ratings: TennisRatings(
      speed: 73,
      acceleration: 71,
      power: 92,
      control: 79,
      serve: 87,
      stamina: 76,
      volley: 70,
      spin: 75,
      reach: 79,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'jaume-munar',
    name: 'Jaume Munar',
    archetype: TennisArchetype.speedDefender,
    signature: 'Covers the court and outlasts the rally',
    ratings: TennisRatings(
      speed: 93,
      acceleration: 90,
      power: 63,
      control: 81,
      serve: 70,
      stamina: 88,
      volley: 72,
      spin: 78,
      reach: 67,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'juan-manuel-cerundolo',
    name: 'Juan Manuel Cerundolo',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Never gives the same ball twice',
    ratings: TennisRatings(
      speed: 78,
      acceleration: 81,
      power: 69,
      control: 88,
      serve: 75,
      stamina: 83,
      volley: 72,
      spin: 91,
      reach: 65,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'alex-michelsen',
    name: 'Alex Michelsen',
    archetype: TennisArchetype.allRounder,
    signature: 'Clean fundamentals under pressure',
    ratings: TennisRatings(
      speed: 81,
      acceleration: 76,
      power: 77,
      control: 82,
      serve: 75,
      stamina: 82,
      volley: 73,
      spin: 81,
      reach: 75,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'ethan-quinn',
    name: 'Ethan Quinn',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Overwhelming pace off both wings',
    ratings: TennisRatings(
      speed: 72,
      acceleration: 74,
      power: 90,
      control: 79,
      serve: 89,
      stamina: 74,
      volley: 72,
      spin: 74,
      reach: 78,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'mariano-navone',
    name: 'Mariano Navone',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Sharp angles and disruptive changes of pace',
    ratings: TennisRatings(
      speed: 74,
      acceleration: 81,
      power: 69,
      control: 87,
      serve: 74,
      stamina: 83,
      volley: 75,
      spin: 93,
      reach: 66,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'adrian-mannarino',
    name: 'Adrian Mannarino',
    archetype: TennisArchetype.speedDefender,
    signature: 'Turns defence into offence in one step',
    ratings: TennisRatings(
      speed: 91,
      acceleration: 90,
      power: 67,
      control: 77,
      serve: 69,
      stamina: 88,
      volley: 73,
      spin: 78,
      reach: 69,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'terence-atmane',
    name: 'Terence Atmane',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Wins the short points with clean hands',
    ratings: TennisRatings(
      speed: 77,
      acceleration: 80,
      power: 83,
      control: 74,
      serve: 89,
      stamina: 69,
      volley: 91,
      spin: 62,
      reach: 77,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'aryna-sabalenka',
    name: 'Aryna Sabalenka',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Ends points early with raw power',
    ratings: TennisRatings(
      speed: 97,
      acceleration: 96,
      power: 95,
      control: 99,
      serve: 95,
      stamina: 93,
      volley: 99,
      spin: 95,
      reach: 95,
    ),
    overallRating: 96,
  ),
  TennisPlayer(
    id: 'elena-rybakina',
    name: 'Elena Rybakina',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Flattens the ball and takes time away',
    ratings: TennisRatings(
      speed: 94,
      acceleration: 93,
      power: 97,
      control: 91,
      serve: 95,
      stamina: 92,
      volley: 92,
      spin: 96,
      reach: 96,
    ),
    overallRating: 94,
  ),
  TennisPlayer(
    id: 'jessica-pegula',
    name: 'Jessica Pegula',
    archetype: TennisArchetype.allRounder,
    signature: 'Solid from everywhere with no clear hole',
    ratings: TennisRatings(
      speed: 95,
      acceleration: 95,
      power: 92,
      control: 97,
      serve: 95,
      stamina: 97,
      volley: 93,
      spin: 93,
      reach: 89,
    ),
    overallRating: 94,
  ),
  TennisPlayer(
    id: 'coco-gauff',
    name: 'Coco Gauff',
    archetype: TennisArchetype.speedDefender,
    signature: 'Turns defence into offence in one step',
    ratings: TennisRatings(
      speed: 96,
      acceleration: 99,
      power: 85,
      control: 93,
      serve: 88,
      stamina: 94,
      volley: 89,
      spin: 93,
      reach: 91,
    ),
    overallRating: 92,
  ),
  TennisPlayer(
    id: 'mirra-andreeva',
    name: 'Mirra Andreeva',
    archetype: TennisArchetype.allCourtRival,
    signature: 'Elite in every phase of the point',
    ratings: TennisRatings(
      speed: 93,
      acceleration: 91,
      power: 95,
      control: 96,
      serve: 94,
      stamina: 96,
      volley: 87,
      spin: 90,
      reach: 86,
    ),
    overallRating: 92,
  ),
  TennisPlayer(
    id: 'karolina-muchova',
    name: 'Karolina Muchova',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Cuts the rally short with soft touch',
    ratings: TennisRatings(
      speed: 89,
      acceleration: 89,
      power: 93,
      control: 84,
      serve: 93,
      stamina: 83,
      volley: 99,
      spin: 82,
      reach: 89,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'linda-noskova',
    name: 'Linda Noskova',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Ends points early with raw power',
    ratings: TennisRatings(
      speed: 86,
      acceleration: 87,
      power: 95,
      control: 92,
      serve: 92,
      stamina: 87,
      volley: 84,
      spin: 86,
      reach: 92,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'iga-swiatek',
    name: 'Iga Swiatek',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Sharp angles and disruptive changes of pace',
    ratings: TennisRatings(
      speed: 89,
      acceleration: 91,
      power: 83,
      control: 94,
      serve: 89,
      stamina: 89,
      volley: 85,
      spin: 97,
      reach: 84,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'amanda-anisimova',
    name: 'Amanda Anisimova',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Big serve into an immediate forehand',
    ratings: TennisRatings(
      speed: 88,
      acceleration: 85,
      power: 97,
      control: 89,
      serve: 92,
      stamina: 87,
      volley: 87,
      spin: 88,
      reach: 88,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'elina-svitolina',
    name: 'Elina Svitolina',
    archetype: TennisArchetype.speedDefender,
    signature: 'Turns defence into offence in one step',
    ratings: TennisRatings(
      speed: 95,
      acceleration: 94,
      power: 79,
      control: 94,
      serve: 86,
      stamina: 93,
      volley: 88,
      spin: 87,
      reach: 85,
    ),
    overallRating: 89,
  ),
  TennisPlayer(
    id: 'marta-kostyuk',
    name: 'Marta Kostyuk',
    archetype: TennisArchetype.allRounder,
    signature: 'Adapts the plan as the match turns',
    ratings: TennisRatings(
      speed: 87,
      acceleration: 89,
      power: 84,
      control: 91,
      serve: 80,
      stamina: 90,
      volley: 79,
      spin: 83,
      reach: 82,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'victoria-mboko',
    name: 'Victoria Mboko',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Flattens the ball and takes time away',
    ratings: TennisRatings(
      speed: 84,
      acceleration: 80,
      power: 95,
      control: 85,
      serve: 92,
      stamina: 83,
      volley: 77,
      spin: 82,
      reach: 87,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'naomi-osaka',
    name: 'Naomi Osaka',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Ends points early with raw power',
    ratings: TennisRatings(
      speed: 78,
      acceleration: 82,
      power: 98,
      control: 82,
      serve: 90,
      stamina: 84,
      volley: 76,
      spin: 86,
      reach: 89,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'belinda-bencic',
    name: 'Belinda Bencic',
    archetype: TennisArchetype.allRounder,
    signature: 'Solid from everywhere with no clear hole',
    ratings: TennisRatings(
      speed: 84,
      acceleration: 87,
      power: 82,
      control: 90,
      serve: 83,
      stamina: 91,
      volley: 83,
      spin: 85,
      reach: 80,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'jasmine-paolini',
    name: 'Jasmine Paolini',
    archetype: TennisArchetype.speedDefender,
    signature: 'Turns defence into offence in one step',
    ratings: TennisRatings(
      speed: 97,
      acceleration: 96,
      power: 73,
      control: 89,
      serve: 77,
      stamina: 92,
      volley: 81,
      spin: 85,
      reach: 75,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'iva-jovic',
    name: 'Iva Jovic',
    archetype: TennisArchetype.allRounder,
    signature: 'Steady rhythm that wears opponents down',
    ratings: TennisRatings(
      speed: 84,
      acceleration: 84,
      power: 86,
      control: 91,
      serve: 83,
      stamina: 89,
      volley: 79,
      spin: 88,
      reach: 81,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'sorana-cirstea',
    name: 'Sorana Cirstea',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Flattens the ball and takes time away',
    ratings: TennisRatings(
      speed: 79,
      acceleration: 83,
      power: 94,
      control: 86,
      serve: 95,
      stamina: 81,
      volley: 79,
      spin: 84,
      reach: 84,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'diana-shnaider',
    name: 'Diana Shnaider',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Heavy first strike from the baseline',
    ratings: TennisRatings(
      speed: 80,
      acceleration: 83,
      power: 95,
      control: 87,
      serve: 94,
      stamina: 84,
      volley: 78,
      spin: 81,
      reach: 83,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'ekaterina-alexandrova',
    name: 'Ekaterina Alexandrova',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Flattens the ball and takes time away',
    ratings: TennisRatings(
      speed: 77,
      acceleration: 84,
      power: 94,
      control: 81,
      serve: 93,
      stamina: 85,
      volley: 78,
      spin: 86,
      reach: 87,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'anna-kalinskaya',
    name: 'Anna Kalinskaya',
    archetype: TennisArchetype.allRounder,
    signature: 'Clean fundamentals under pressure',
    ratings: TennisRatings(
      speed: 90,
      acceleration: 86,
      power: 81,
      control: 91,
      serve: 81,
      stamina: 85,
      volley: 83,
      spin: 87,
      reach: 81,
    ),
    overallRating: 85,
  ),
  TennisPlayer(
    id: 'marie-bouzkova',
    name: 'Marie Bouzkova',
    archetype: TennisArchetype.speedDefender,
    signature: 'Covers the court and outlasts the rally',
    ratings: TennisRatings(
      speed: 93,
      acceleration: 92,
      power: 66,
      control: 85,
      serve: 73,
      stamina: 92,
      volley: 74,
      spin: 82,
      reach: 72,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'maja-chwalinska',
    name: 'Maja Chwalinska',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Sharp angles and disruptive changes of pace',
    ratings: TennisRatings(
      speed: 79,
      acceleration: 83,
      power: 73,
      control: 87,
      serve: 76,
      stamina: 85,
      volley: 80,
      spin: 93,
      reach: 73,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'jelena-ostapenko',
    name: 'Jelena Ostapenko',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Overwhelming pace off both wings',
    ratings: TennisRatings(
      speed: 78,
      acceleration: 77,
      power: 91,
      control: 83,
      serve: 90,
      stamina: 79,
      volley: 70,
      spin: 79,
      reach: 82,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'clara-tauson',
    name: 'Clara Tauson',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Flattens the ball and takes time away',
    ratings: TennisRatings(
      speed: 74,
      acceleration: 81,
      power: 93,
      control: 78,
      serve: 93,
      stamina: 78,
      volley: 74,
      spin: 77,
      reach: 81,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'ann-li',
    name: 'Ann Li',
    archetype: TennisArchetype.allRounder,
    signature: 'Balanced timing and reliable recovery',
    ratings: TennisRatings(
      speed: 82,
      acceleration: 82,
      power: 75,
      control: 86,
      serve: 82,
      stamina: 83,
      volley: 80,
      spin: 84,
      reach: 75,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'barbora-krejcikova',
    name: 'Barbora Krejcikova',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Cuts the rally short with soft touch',
    ratings: TennisRatings(
      speed: 81,
      acceleration: 83,
      power: 85,
      control: 76,
      serve: 94,
      stamina: 72,
      volley: 93,
      spin: 65,
      reach: 80,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'hailey-baptiste',
    name: 'Hailey Baptiste',
    archetype: TennisArchetype.allRounder,
    signature: 'Solid from everywhere with no clear hole',
    ratings: TennisRatings(
      speed: 82,
      acceleration: 86,
      power: 76,
      control: 85,
      serve: 77,
      stamina: 84,
      volley: 76,
      spin: 82,
      reach: 81,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'katerina-siniakova',
    name: 'Katerina Siniakova',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Wins the short points with clean hands',
    ratings: TennisRatings(
      speed: 81,
      acceleration: 83,
      power: 85,
      control: 75,
      serve: 95,
      stamina: 73,
      volley: 94,
      spin: 67,
      reach: 76,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'donna-vekic',
    name: 'Donna Vekic',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Overwhelming pace off both wings',
    ratings: TennisRatings(
      speed: 78,
      acceleration: 77,
      power: 94,
      control: 79,
      serve: 88,
      stamina: 80,
      volley: 71,
      spin: 77,
      reach: 85,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'jaqueline-cristian',
    name: 'Jaqueline Cristian',
    archetype: TennisArchetype.speedDefender,
    signature: 'Relentless legs deep behind the baseline',
    ratings: TennisRatings(
      speed: 90,
      acceleration: 92,
      power: 69,
      control: 87,
      serve: 72,
      stamina: 91,
      volley: 77,
      spin: 79,
      reach: 72,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'maria-sakkari',
    name: 'Maria Sakkari',
    archetype: TennisArchetype.speedDefender,
    signature: 'Relentless legs deep behind the baseline',
    ratings: TennisRatings(
      speed: 93,
      acceleration: 89,
      power: 67,
      control: 85,
      serve: 74,
      stamina: 88,
      volley: 73,
      spin: 85,
      reach: 75,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'emma-raducanu',
    name: 'Emma Raducanu',
    archetype: TennisArchetype.allRounder,
    signature: 'Adapts the plan as the match turns',
    ratings: TennisRatings(
      speed: 84,
      acceleration: 84,
      power: 82,
      control: 87,
      serve: 78,
      stamina: 81,
      volley: 75,
      spin: 83,
      reach: 75,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'janice-tjen',
    name: 'Janice Tjen',
    archetype: TennisArchetype.allRounder,
    signature: 'Solid from everywhere with no clear hole',
    ratings: TennisRatings(
      speed: 81,
      acceleration: 83,
      power: 81,
      control: 86,
      serve: 81,
      stamina: 82,
      volley: 77,
      spin: 82,
      reach: 76,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'wang-xinyu',
    name: 'Wang Xinyu',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Big serve into an immediate forehand',
    ratings: TennisRatings(
      speed: 77,
      acceleration: 78,
      power: 97,
      control: 78,
      serve: 91,
      stamina: 77,
      volley: 71,
      spin: 79,
      reach: 81,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'cristina-bucsa',
    name: 'Cristina Bucsa',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Carves the court open with shape and slice',
    ratings: TennisRatings(
      speed: 77,
      acceleration: 84,
      power: 75,
      control: 91,
      serve: 75,
      stamina: 84,
      volley: 79,
      spin: 92,
      reach: 72,
    ),
    overallRating: 81,
  ),
  TennisPlayer(
    id: 'sara-bejlek',
    name: 'Sara Bejlek',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Ends points early with raw power',
    ratings: TennisRatings(
      speed: 72,
      acceleration: 74,
      power: 89,
      control: 79,
      serve: 85,
      stamina: 78,
      volley: 70,
      spin: 74,
      reach: 81,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'nikola-bartunkova',
    name: 'Nikola Bartunkova',
    archetype: TennisArchetype.allRounder,
    signature: 'Clean fundamentals under pressure',
    ratings: TennisRatings(
      speed: 83,
      acceleration: 82,
      power: 73,
      control: 82,
      serve: 78,
      stamina: 78,
      volley: 76,
      spin: 77,
      reach: 73,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'magdalena-frech',
    name: 'Magdalena Frech',
    archetype: TennisArchetype.speedDefender,
    signature: 'Covers the court and outlasts the rally',
    ratings: TennisRatings(
      speed: 87,
      acceleration: 89,
      power: 67,
      control: 82,
      serve: 68,
      stamina: 87,
      volley: 75,
      spin: 78,
      reach: 69,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'petra-marcinko',
    name: 'Petra Marcinko',
    archetype: TennisArchetype.allRounder,
    signature: 'Adapts the plan as the match turns',
    ratings: TennisRatings(
      speed: 79,
      acceleration: 79,
      power: 73,
      control: 81,
      serve: 77,
      stamina: 81,
      volley: 73,
      spin: 82,
      reach: 77,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'mccartney-kessler',
    name: 'McCartney Kessler',
    archetype: TennisArchetype.allRounder,
    signature: 'Adapts the plan as the match turns',
    ratings: TennisRatings(
      speed: 81,
      acceleration: 78,
      power: 78,
      control: 82,
      serve: 76,
      stamina: 80,
      volley: 75,
      spin: 76,
      reach: 76,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'viktorija-golubic',
    name: 'Viktorija Golubic',
    archetype: TennisArchetype.speedDefender,
    signature: 'Elite retrieval and counterattack speed',
    ratings: TennisRatings(
      speed: 88,
      acceleration: 85,
      power: 64,
      control: 81,
      serve: 71,
      stamina: 87,
      volley: 74,
      spin: 82,
      reach: 70,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'zeynep-sonmez',
    name: 'Zeynep Sonmez',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Sharp angles and disruptive changes of pace',
    ratings: TennisRatings(
      speed: 76,
      acceleration: 82,
      power: 69,
      control: 84,
      serve: 77,
      stamina: 82,
      volley: 77,
      spin: 91,
      reach: 64,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'tereza-valentova',
    name: 'Tereza Valentova',
    archetype: TennisArchetype.allRounder,
    signature: 'Adapts the plan as the match turns',
    ratings: TennisRatings(
      speed: 81,
      acceleration: 78,
      power: 76,
      control: 81,
      serve: 73,
      stamina: 82,
      volley: 77,
      spin: 79,
      reach: 75,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'antonia-ruzic',
    name: 'Antonia Ruzic',
    archetype: TennisArchetype.spinSpecialist,
    signature: 'Never gives the same ball twice',
    ratings: TennisRatings(
      speed: 79,
      acceleration: 81,
      power: 71,
      control: 87,
      serve: 74,
      stamina: 81,
      volley: 77,
      spin: 88,
      reach: 64,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'caty-mcnally',
    name: 'Caty McNally',
    archetype: TennisArchetype.serveAndVolley,
    signature: 'Fast serve followed by decisive net pressure',
    ratings: TennisRatings(
      speed: 74,
      acceleration: 83,
      power: 80,
      control: 71,
      serve: 90,
      stamina: 75,
      volley: 90,
      spin: 64,
      reach: 75,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'talia-gibson',
    name: 'Talia Gibson',
    archetype: TennisArchetype.allRounder,
    signature: 'Balanced timing and reliable recovery',
    ratings: TennisRatings(
      speed: 80,
      acceleration: 80,
      power: 77,
      control: 80,
      serve: 78,
      stamina: 81,
      volley: 75,
      spin: 78,
      reach: 73,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'anhelina-kalinina',
    name: 'Anhelina Kalinina',
    archetype: TennisArchetype.speedDefender,
    signature: 'Turns defence into offence in one step',
    ratings: TennisRatings(
      speed: 89,
      acceleration: 89,
      power: 67,
      control: 78,
      serve: 66,
      stamina: 88,
      volley: 75,
      spin: 78,
      reach: 72,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'peyton-stearns',
    name: 'Peyton Stearns',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Ends points early with raw power',
    ratings: TennisRatings(
      speed: 73,
      acceleration: 77,
      power: 92,
      control: 76,
      serve: 90,
      stamina: 73,
      volley: 67,
      spin: 74,
      reach: 80,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'leylah-fernandez',
    name: 'Leylah Fernandez',
    archetype: TennisArchetype.speedDefender,
    signature: 'Turns defence into offence in one step',
    ratings: TennisRatings(
      speed: 90,
      acceleration: 85,
      power: 64,
      control: 83,
      serve: 71,
      stamina: 90,
      volley: 73,
      spin: 78,
      reach: 68,
    ),
    overallRating: 78,
  ),
  TennisPlayer(
    id: 'paula-badosa',
    name: 'Paula Badosa',
    archetype: TennisArchetype.powerBaseliner,
    signature: 'Ends points early with raw power',
    ratings: TennisRatings(
      speed: 70,
      acceleration: 72,
      power: 91,
      control: 79,
      serve: 89,
      stamina: 74,
      volley: 68,
      spin: 75,
      reach: 84,
    ),
    overallRating: 78,
  ),
];
```

### A.5 `lib/blocs/tennis/tennis_state.dart`

<sub>58 lines</sub>

```dart
import '../../models/tennis.dart';

enum TennisFlowPhase { hub, selection, preview, match, result }

class TennisState {
  const TennisState({
    this.loading = true,
    this.profile = const TennisProfile(),
    this.phase = TennisFlowPhase.hub,
    this.selectedMode = TennisMode.quickMatch,
    this.trainingLesson = 1,
    this.config,
    this.resumeSnapshot,
    this.summary,
    this.reward = TennisReward.zero,
  });

  final bool loading;
  final TennisProfile profile;
  final TennisFlowPhase phase;
  final TennisMode selectedMode;
  final int trainingLesson;
  final TennisMatchConfig? config;
  final TennisMatchSnapshot? resumeSnapshot;
  final TennisMatchSummary? summary;
  final TennisReward reward;

  bool get canResume => resumeSnapshot != null;
  TennisPlayer get selectedPlayer => tennisPlayerById(profile.selectedPlayerId);
  TennisPlayer get selectedOpponent => tennisPlayerById(profile.lastOpponentId);

  TennisState copyWith({
    bool? loading,
    TennisProfile? profile,
    TennisFlowPhase? phase,
    TennisMode? selectedMode,
    int? trainingLesson,
    TennisMatchConfig? config,
    TennisMatchSnapshot? resumeSnapshot,
    TennisMatchSummary? summary,
    TennisReward? reward,
    bool clearConfig = false,
    bool clearResume = false,
    bool clearResult = false,
  }) => TennisState(
    loading: loading ?? this.loading,
    profile: profile ?? this.profile,
    phase: phase ?? this.phase,
    selectedMode: selectedMode ?? this.selectedMode,
    trainingLesson: trainingLesson ?? this.trainingLesson,
    config: clearConfig ? null : (config ?? this.config),
    resumeSnapshot: clearResume
        ? null
        : (resumeSnapshot ?? this.resumeSnapshot),
    summary: clearResult ? null : (summary ?? this.summary),
    reward: clearResult ? TennisReward.zero : (reward ?? this.reward),
  );
}
```

### A.6 `lib/blocs/tennis/tennis_cubit.dart`

<sub>439 lines</sub>

```dart
import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/tennis.dart';
import '../../services/secure_storage_service.dart';
import 'tennis_state.dart';

class TennisCubit extends Cubit<TennisState> {
  TennisCubit(this._storage, {Random? random})
    : _random = random ?? Random(),
      super(const TennisState());

  final SecureGameStorage _storage;
  final Random _random;

  Future<void> load() async {
    final results = await Future.wait<Object?>([
      _storage.loadTennisProfile(),
      _storage.loadTennisMatchSnapshot(),
    ]);
    var profile = results[0]! as TennisProfile;
    final validIds = tennisPlayers.map((player) => player.id).toSet();
    if (!validIds.contains(profile.selectedPlayerId)) {
      profile = profile.copyWith(selectedPlayerId: tennisPlayers.first.id);
    }
    final validOwned = profile.ownedPlayerIds
        .where(validIds.contains)
        .toSet()
        .toList(growable: false);
    if (validOwned.length != profile.ownedPlayerIds.length) {
      profile = profile.copyWith(ownedPlayerIds: validOwned);
    }
    if (profile.starterPackClaimed && profile.ownedPlayerIds.isEmpty) {
      profile = profile.copyWith(ownedPlayerIds: [profile.selectedPlayerId]);
    }
    if (profile.starterPackClaimed &&
        !profile.ownedPlayerIds.contains(profile.selectedPlayerId)) {
      profile = profile.copyWith(
        selectedPlayerId: profile.ownedPlayerIds.first,
      );
    }
    if (!validIds.contains(profile.lastOpponentId) ||
        profile.lastOpponentId == profile.selectedPlayerId) {
      profile = profile.copyWith(
        lastOpponentId: _randomOpponentIdFor(profile.selectedPlayerId),
      );
    }
    emit(
      state.copyWith(
        loading: false,
        profile: profile,
        resumeSnapshot: results[1] as TennisMatchSnapshot?,
      ),
    );
  }

  void selectMode(TennisMode mode) {
    emit(state.copyWith(selectedMode: mode, phase: TennisFlowPhase.selection));
  }

  void selectPlayer(String playerId) {
    if (!state.profile.isPlayerUnlocked(playerId)) return;
    var opponentId = state.profile.lastOpponentId;
    if (opponentId == playerId) {
      opponentId = tennisPlayers
          .firstWhere((player) => player.id != playerId)
          .id;
    }
    _updateProfile(
      state.profile.copyWith(
        selectedPlayerId: playerId,
        lastOpponentId: opponentId,
      ),
    );
  }

  /// Mirrors the tennis cards held in the active [GameBloc] deck slot into the
  /// tennis profile.
  ///
  /// The starter pack itself is granted by `GameBloc` (see
  /// `TennisStarterPackOpened`) so tennis shares one card economy with every
  /// other sport; this profile is a cache of that, not a second source of truth.
  Future<void> syncFromDeck(List<String> ownedIds, String? starterId) async {
    final validIds = tennisPlayers.map((player) => player.id).toSet();
    final owned = ownedIds.where(validIds.contains).toSet().toList();
    if (owned.isEmpty) return;

    final selectedId = owned.contains(starterId) ? starterId! : owned.first;
    final unchanged =
        state.profile.starterPackClaimed &&
        state.profile.selectedPlayerId == selectedId &&
        state.profile.ownedPlayerIds.toSet().containsAll(owned) &&
        owned.length == state.profile.ownedPlayerIds.length;
    if (unchanged) return;

    final profile = state.profile.copyWith(
      starterPackClaimed: true,
      ownedPlayerIds: owned,
      selectedPlayerId: selectedId,
      lastOpponentId: _randomOpponentIdFor(selectedId),
    );
    emit(state.copyWith(profile: profile));
    await _storage.saveTennisProfile(profile);
  }

  void prepareQuickMatchPreview() {
    if (!state.profile.starterPackClaimed ||
        state.profile.ownedPlayerIds.isEmpty) {
      emit(
        state.copyWith(
          selectedMode: TennisMode.quickMatch,
          phase: TennisFlowPhase.hub,
          clearConfig: true,
          clearResult: true,
        ),
      );
      return;
    }
    final playerId =
        state.profile.ownedPlayerIds.contains(state.profile.selectedPlayerId)
        ? state.profile.selectedPlayerId
        : state.profile.ownedPlayerIds.first;
    final profile = state.profile.copyWith(
      selectedPlayerId: playerId,
      lastOpponentId: _randomOpponentIdFor(playerId),
    );
    _updateProfile(profile);
    emit(
      state.copyWith(
        selectedMode: TennisMode.quickMatch,
        phase: TennisFlowPhase.preview,
        clearConfig: true,
        clearResult: true,
      ),
    );
  }

  void selectOpponent(String opponentId) {
    if (opponentId == state.profile.selectedPlayerId) return;
    if (!tennisPlayers.any((player) => player.id == opponentId)) return;
    _updateProfile(state.profile.copyWith(lastOpponentId: opponentId));
  }

  void selectDifficulty(TennisDifficulty difficulty) {
    _updateProfile(state.profile.copyWith(difficulty: difficulty));
  }

  void selectTrainingLesson(int lesson) {
    emit(state.copyWith(trainingLesson: lesson.clamp(1, 8)));
  }

  void updateSettings(TennisSettings settings) {
    _updateProfile(state.profile.copyWith(settings: settings));
  }

  void showPreview() {
    emit(state.copyWith(phase: TennisFlowPhase.preview));
  }

  void prepareTournament() {
    final tournament = state.profile.tournament;
    if (tournament != null && tournament.active) return;
    _updateProfile(state.profile.copyWith(tournament: _createTournament()));
  }

  TennisMatchConfig buildMatch({TennisMode? mode, int? trainingLesson}) {
    final selectedMode = mode ?? state.selectedMode;
    var opponentId = state.profile.lastOpponentId;
    String? tournamentId;
    int? tournamentRound;
    if (selectedMode == TennisMode.tournament) {
      var tournament = state.profile.tournament;
      if (tournament == null || !tournament.active) {
        tournament = _createTournament();
        _updateProfile(state.profile.copyWith(tournament: tournament));
      }
      opponentId = tournament.currentOpponentId ?? opponentId;
      tournamentId = tournament.id;
      tournamentRound = tournament.currentRound;
    }
    final now = DateTime.now();
    final config = TennisMatchConfig(
      matchId:
          'tennis-${now.microsecondsSinceEpoch}-${_random.nextInt(1 << 20)}',
      mode: selectedMode,
      playerId: state.profile.selectedPlayerId,
      opponentId: opponentId,
      difficulty: state.profile.difficulty,
      seed: _random.nextInt(0x7fffffff),
      trainingLesson: selectedMode == TennisMode.training
          ? (trainingLesson ?? state.trainingLesson)
          : null,
      tournamentId: tournamentId,
      tournamentRound: tournamentRound,
    );
    emit(
      state.copyWith(
        selectedMode: selectedMode,
        phase: TennisFlowPhase.match,
        config: config,
        clearResult: true,
      ),
    );
    return config;
  }

  TennisMatchConfig resumeMatch() {
    final snapshot = state.resumeSnapshot;
    if (snapshot == null) {
      throw StateError('No Tennis Rally match is available to resume.');
    }
    emit(
      state.copyWith(
        selectedMode: snapshot.config.mode,
        phase: TennisFlowPhase.match,
        config: snapshot.config,
        clearResult: true,
      ),
    );
    return snapshot.config;
  }

  Future<void> saveSnapshot(TennisMatchSnapshot snapshot) async {
    if (snapshot.config.matchId != state.config?.matchId) return;
    emit(state.copyWith(resumeSnapshot: snapshot));
    await _storage.saveTennisMatchSnapshot(snapshot);
  }

  Future<void> clearSnapshot() async {
    emit(state.copyWith(clearResume: true));
    await _storage.clearTennisMatchSnapshot();
  }

  Future<TennisReward> settle(TennisMatchSummary summary) async {
    if (state.profile.settledMatchIds.contains(summary.matchId)) {
      return TennisReward.zero;
    }
    final reward = calculateTennisReward(summary, state.profile);
    final profile = _recordSummary(state.profile, summary, reward);
    emit(
      state.copyWith(
        profile: profile,
        phase: TennisFlowPhase.result,
        summary: summary,
        reward: reward,
        clearResume: true,
      ),
    );
    await Future.wait([
      _storage.saveTennisProfile(profile),
      _storage.clearTennisMatchSnapshot(),
    ]);
    return reward;
  }

  Future<void> abandonMatch() async {
    emit(
      state.copyWith(
        phase: TennisFlowPhase.hub,
        clearConfig: true,
        clearResume: true,
        clearResult: true,
      ),
    );
    await _storage.clearTennisMatchSnapshot();
  }

  void returnToHub() {
    emit(
      state.copyWith(
        phase: TennisFlowPhase.hub,
        clearConfig: true,
        clearResult: true,
      ),
    );
  }

  TennisTournament _createTournament() {
    final entrants = tennisPlayers.map((player) => player.id).toList();
    final rivals =
        entrants.where((id) => id != state.profile.selectedPlayerId).toList()
          ..shuffle(_random);
    return TennisTournament(
      id: 'tour-${DateTime.now().microsecondsSinceEpoch}',
      playerId: state.profile.selectedPlayerId,
      difficulty: state.profile.difficulty,
      entrants: entrants,
      opponents: rivals.take(3).toList(growable: false),
    );
  }

  TennisProfile _recordSummary(
    TennisProfile profile,
    TennisMatchSummary summary,
    TennisReward reward,
  ) {
    final settled = <String>[...profile.settledMatchIds, summary.matchId];
    if (settled.length > 256) settled.removeRange(0, settled.length - 256);
    final mastery = Map<String, int>.from(profile.masteryXp);
    mastery[summary.playerId] =
        (mastery[summary.playerId] ?? 0) + reward.masteryXp;
    final completedLessons = Set<int>.from(profile.completedLessons);
    if (summary.mode == TennisMode.training && summary.trainingLesson != null) {
      completedLessons.add(summary.trainingLesson!);
    }
    final styles = Set<TennisArchetype>.from(profile.stylesWon);
    if (summary.won &&
        (summary.mode == TennisMode.quickMatch ||
            summary.mode == TennisMode.tournament)) {
      styles.add(tennisPlayerById(summary.playerId).archetype);
    }
    final achievements = Set<String>.from(profile.achievements);
    if (summary.stats.cleanHolds > 0) achievements.add('clean-hold');
    if (summary.stats.breakPointsWon > 0) achievements.add('break-through');
    if (summary.stats.maxBreakPointsSavedInGame >= 3) {
      achievements.add('unbreakable');
    }
    if (profile.totalAces + summary.stats.aces >= 5) {
      achievements.add('ace-high');
    }
    if (summary.stats.wonTwentyShotRally) {
      achievements.add('rally-architect');
    }
    final isServeVolley =
        tennisPlayerById(summary.playerId).archetype ==
        TennisArchetype.serveAndVolley;
    final serveVolleyNetPoints =
        profile.serveVolleyNetPoints +
        (isServeVolley ? summary.stats.netPointsWon : 0);
    if (serveVolleyNetPoints >= 10) {
      achievements.add('net-authority');
    }
    if (summary.stats.comebackFromThreeGames && summary.won) {
      achievements.add('comeback-set');
    }
    if (summary.stats.tiebreakNerve && summary.won) {
      achievements.add('tiebreak-nerve');
    }
    const baseStyles = <TennisArchetype>{
      TennisArchetype.allRounder,
      TennisArchetype.powerBaseliner,
      TennisArchetype.speedDefender,
      TennisArchetype.serveAndVolley,
      TennisArchetype.spinSpecialist,
    };
    if (styles.containsAll(baseStyles)) achievements.add('all-styles');
    if (summary.tournamentChampion) achievements.add('champion');

    final isSet =
        summary.mode == TennisMode.quickMatch ||
        summary.mode == TennisMode.tournament;
    final quickSignature =
        '${summary.playerId}:${summary.opponentId}:${summary.difficulty.name}';
    final repeatCount = summary.mode == TennisMode.quickMatch
        ? (profile.lastQuickSignature == quickSignature
              ? profile.quickRepeatCount + 1
              : 1)
        : profile.quickRepeatCount;
    var tournament = profile.tournament;
    final trophies = Map<String, int>.from(profile.trophies);
    if (summary.mode == TennisMode.tournament &&
        tournament != null &&
        tournament.id == state.config?.tournamentId) {
      final results = <String>[...tournament.results, summary.won ? 'W' : 'L'];
      if (summary.won && tournament.currentRound >= 2) {
        tournament = tournament.copyWith(
          results: results,
          currentRound: 3,
          active: false,
          champion: true,
        );
        trophies[summary.difficulty.name] =
            (trophies[summary.difficulty.name] ?? 0) + 1;
      } else if (summary.won) {
        tournament = tournament.copyWith(
          results: results,
          currentRound: tournament.currentRound + 1,
        );
      } else {
        tournament = tournament.copyWith(results: results, active: false);
      }
    }

    final winStreak = isSet
        ? (summary.won ? profile.currentWinStreak + 1 : 0)
        : profile.currentWinStreak;
    return profile.copyWith(
      setsPlayed: profile.setsPlayed + (isSet ? 1 : 0),
      setsWon: profile.setsWon + (isSet && summary.won ? 1 : 0),
      currentWinStreak: winStreak,
      bestWinStreak: max(profile.bestWinStreak, winStreak),
      totalAces: profile.totalAces + summary.stats.aces,
      longestRally: max(profile.longestRally, summary.stats.longestRally),
      cleanHolds: profile.cleanHolds + summary.stats.cleanHolds,
      breaksConverted: profile.breaksConverted + summary.stats.breakPointsWon,
      breakPointsSaved:
          profile.breakPointsSaved + summary.stats.breakPointsSaved,
      netPointsWon: profile.netPointsWon + summary.stats.netPointsWon,
      serveVolleyNetPoints: serveVolleyNetPoints,
      comebackSets:
          profile.comebackSets +
          (summary.stats.comebackFromThreeGames && summary.won ? 1 : 0),
      tiebreakNerveWins:
          profile.tiebreakNerveWins +
          (summary.stats.tiebreakNerve && summary.won ? 1 : 0),
      stylesWon: styles,
      achievements: achievements,
      masteryXp: mastery,
      completedLessons: completedLessons,
      trophies: trophies,
      bestEndless: summary.mode == TennisMode.endlessRally
          ? max(profile.bestEndless, summary.practiceScore)
          : profile.bestEndless,
      bestTarget: summary.mode == TennisMode.targetPractice
          ? max(profile.bestTarget, summary.practiceScore)
          : profile.bestTarget,
      lastQuickSignature: summary.mode == TennisMode.quickMatch
          ? quickSignature
          : profile.lastQuickSignature,
      quickRepeatCount: repeatCount,
      settledMatchIds: settled,
      tournament: tournament,
    );
  }

  void _updateProfile(TennisProfile profile) {
    emit(state.copyWith(profile: profile));
    unawaited(_storage.saveTennisProfile(profile));
  }

  String _randomOpponentIdFor(String playerId) {
    final opponents = tennisPlayers
        .where((player) => player.id != playerId)
        .toList(growable: false);
    return opponents[_random.nextInt(opponents.length)].id;
  }
}
```

## Appendix B — Play-layer widgets (verbatim)

Controls and HUD. These compile against Appendix A + D with no edits.

### B.1 `lib/screens/tennis/widgets/tennis_controls.dart`

<sub>348 lines</sub>

```dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/tennis/tennis_game.dart';
import '../../../models/tennis.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class TennisControls extends StatelessWidget {
  const TennisControls({required this.game, required this.settings, super.key});

  final TennisGame game;
  final TennisSettings settings;

  @override
  Widget build(BuildContext context) {
    final movement = _MovementZone(game: game, settings: settings);
    final shot = _ShotZone(game: game, settings: settings);
    return IgnorePointer(
      ignoring: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Cyber.bg.withValues(alpha: 0.98),
              Cyber.bg.withValues(alpha: 0.78),
              Cyber.bg.withValues(alpha: 0),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: settings.leftHanded ? [shot, movement] : [movement, shot],
        ),
      ),
    );
  }
}

class _MovementZone extends StatefulWidget {
  const _MovementZone({required this.game, required this.settings});

  final TennisGame game;
  final TennisSettings settings;

  @override
  State<_MovementZone> createState() => _MovementZoneState();
}

class _MovementZoneState extends State<_MovementZone> {
  int? _pointer;
  Offset _thumb = Offset.zero;
  Offset _start = Offset.zero;
  DateTime? _startedAt;

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _start = event.localPosition;
    _startedAt = DateTime.now();
    _apply(event.localPosition);
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    _apply(event.localPosition);
  }

  void _apply(Offset local) {
    const radius = 46.0;
    final center = Offset(64 * widget.settings.controlScale, 64);
    var delta = local - center;
    if (delta.distance > radius) {
      delta = Offset.fromDirection(delta.direction, radius);
    }
    final elapsed = _startedAt == null
        ? 999
        : DateTime.now().difference(_startedAt!).inMilliseconds;
    final sprint = elapsed < 210 && (local - _start).distance > 42;
    _thumb = delta;
    widget.game.setMove(delta.dx / radius, delta.dy / radius, sprint: sprint);
    if (mounted) setState(() {});
  }

  void _up(PointerEvent event) {
    if (_pointer != event.pointer) return;
    _pointer = null;
    _thumb = Offset.zero;
    widget.game.setMove(0, 0);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.game.setMove(0, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.settings.controlScale;
    return Opacity(
      opacity: widget.settings.controlOpacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ZoneLabel(icon: Icons.open_with, label: 'MOVE / FLICK'),
          const SizedBox(height: 6),
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: ChamferedActionSurface(
              clipper: const HudChamferClipper(bigCut: 14, smallCut: 5),
              borderColor: Cyber.cyan.withValues(alpha: 0.44),
              child: Container(
                width: 128 * scale,
                height: 128,
                decoration: BoxDecoration(
                  color: Cyber.panel.withValues(alpha: 0.9),
                ),
                child: CustomPaint(painter: _MovementPainter(thumb: _thumb)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementPainter extends CustomPainter {
  const _MovementPainter({required this.thumb});

  final Offset thumb;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final guide = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, 43, guide);
    canvas.drawLine(center.translate(-48, 0), center.translate(48, 0), guide);
    canvas.drawLine(center.translate(0, -48), center.translate(0, 48), guide);
    canvas.drawCircle(
      center + thumb,
      23,
      Paint()
        ..color = thumb == Offset.zero
            ? Cyber.cyan.withValues(alpha: 0.18)
            : Cyber.cyan.withValues(alpha: 0.38),
    );
    canvas.drawCircle(
      center + thumb,
      23,
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _MovementPainter oldDelegate) =>
      oldDelegate.thumb != thumb;
}

class _ShotZone extends StatefulWidget {
  const _ShotZone({required this.game, required this.settings});

  final TennisGame game;
  final TennisSettings settings;

  @override
  State<_ShotZone> createState() => _ShotZoneState();
}

class _ShotZoneState extends State<_ShotZone> {
  int? _pointer;
  Offset _start = Offset.zero;
  Offset _delta = Offset.zero;
  DateTime? _startedAt;

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _pointer = event.pointer;
    _start = event.localPosition;
    _delta = Offset.zero;
    _startedAt = DateTime.now();
    widget.game.shotStarted();
    if (mounted) setState(() {});
  }

  void _move(PointerMoveEvent event) {
    if (_pointer != event.pointer) return;
    _delta = event.localPosition - _start;
    if (_delta.distance > 74) {
      _delta = Offset.fromDirection(_delta.direction, 74);
    }
    if (mounted) setState(() {});
  }

  void _up(PointerEvent event) {
    if (_pointer != event.pointer) return;
    final held = _startedAt == null
        ? 0.0
        : DateTime.now().difference(_startedAt!).inMilliseconds / 1000;
    widget.game.shotReleased(
      aimX: (_delta.dx / 58).clamp(-1, 1).toDouble(),
      aimY: (-_delta.dy / 58).clamp(-1, 1).toDouble(),
      holdSeconds: held,
    );
    if (widget.settings.haptics) HapticFeedback.selectionClick();
    _pointer = null;
    _delta = Offset.zero;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scale = widget.settings.controlScale;
    final active = _pointer != null;
    return Opacity(
      opacity: widget.settings.controlOpacity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _ZoneLabel(icon: Icons.sports_tennis, label: 'HIT / SWIPE'),
          const SizedBox(height: 6),
          Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _up,
            child: ClipPath(
              clipper: const HudChamferClipper(bigCut: 14, smallCut: 5),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                width: 128 * scale,
                height: 128,
                color: active
                    ? Cyber.lime.withValues(alpha: 0.22)
                    : Cyber.panel.withValues(alpha: 0.9),
                child: CustomPaint(
                  painter: _ShotPainter(delta: _delta, active: active),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShotPainter extends CustomPainter {
  const _ShotPainter({required this.delta, required this.active});

  final Offset delta;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final guide = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Cyber.lime.withValues(alpha: 0.22);
    canvas.drawCircle(center, 42, guide);
    for (var i = 0; i < 4; i++) {
      final angle = -pi / 2 + i * pi / 2;
      canvas.drawLine(
        center + Offset.fromDirection(angle, 28),
        center + Offset.fromDirection(angle, 47),
        guide,
      );
    }
    final thumb = center + delta;
    canvas.drawCircle(
      thumb,
      active ? 24 : 20,
      Paint()..color = Cyber.lime.withValues(alpha: active ? 0.42 : 0.18),
    );
    canvas.drawCircle(
      thumb,
      active ? 24 : 20,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Cyber.lime.withValues(alpha: 0.86),
    );
    final text = TextPainter(
      text: TextSpan(
        text: active ? _gestureLabel(delta) : 'TAP',
        style: Cyber.display(
          9,
          color: Colors.white.withValues(alpha: 0.88),
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, thumb - Offset(text.width / 2, text.height / 2));
  }

  String _gestureLabel(Offset value) {
    if (value.distance < 18) return 'HOLD';
    if (value.dy < -46) return 'LOB';
    if (value.dy < -16) return 'TOP';
    if (value.dy > 46) return 'DROP';
    if (value.dy > 16) return 'SLICE';
    return value.dx < 0 ? 'LEFT' : 'RIGHT';
  }

  @override
  bool shouldRepaint(covariant _ShotPainter oldDelegate) =>
      oldDelegate.delta != delta || oldDelegate.active != active;
}

class _ZoneLabel extends StatelessWidget {
  const _ZoneLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Cyber.muted),
        const SizedBox(width: 5),
        Text(label, style: Cyber.display(9, color: Cyber.muted)),
      ],
    );
  }
}
```

### B.2 `lib/screens/tennis/widgets/tennis_hud.dart`

<sub>455 lines</sub>

```dart
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../games/tennis/tennis_game.dart';
import '../../../models/tennis.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

class TennisHud extends StatelessWidget {
  const TennisHud({required this.game, required this.onPause, super.key});

  final TennisGame game;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _ModeTag(config: game.config),
                const Spacer(),
                _HudButton(
                  icon: Icons.pause_rounded,
                  semanticLabel: 'Pause match',
                  onTap: onPause,
                ),
              ],
            ),
            const SizedBox(height: 7),
            if (game.config.mode == TennisMode.quickMatch ||
                game.config.mode == TennisMode.tournament ||
                (game.config.mode == TennisMode.training &&
                    game.config.trainingLesson == 8))
              _MatchScoreboard(game: game)
            else
              _PracticeScoreboard(game: game),
            const SizedBox(height: 7),
            _ServeMeter(game: game),
          ],
        ),
      ),
    );
  }
}

class TennisStatusRails extends StatelessWidget {
  const TennisStatusRails({required this.game, super.key});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game.stamina01, game.focus01]),
      builder: (context, _) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
          decoration: BoxDecoration(
            color: Cyber.bg.withValues(alpha: 0.84),
            border: Border.all(color: Cyber.border.withValues(alpha: 0.72)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _Meter(
                  label: 'STAMINA',
                  value: game.stamina01.value,
                  color: Cyber.cyan,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _Meter(
                  label: game.engine.focusPointActive
                      ? 'FOCUS ACTIVE'
                      : 'FOCUS',
                  value: game.engine.focusPointActive ? 1 : game.focus01.value,
                  color: Cyber.lime,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TennisStingLayer extends StatelessWidget {
  const TennisStingLayer({required this.game, super.key});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TennisSting?>(
      valueListenable: game.sting,
      builder: (context, sting, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: sting == null
              ? const SizedBox.shrink()
              : Align(
                  key: ValueKey(sting.id),
                  alignment: const Alignment(0, -0.28),
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: const HudChamferClipper(bigCut: 13, smallCut: 4),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: sting.major ? 24 : 17,
                          vertical: sting.major ? 11 : 8,
                        ),
                        color: Cyber.bg.withValues(alpha: 0.9),
                        child: Text(
                          sting.label,
                          style: Cyber.display(
                            sting.major ? 19 : 14,
                            color: sting.color,
                            letterSpacing: 1.8,
                          ),
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

class _ModeTag extends StatelessWidget {
  const _ModeTag({required this.config});

  final TennisMatchConfig config;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 7, smallCut: 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        color: Cyber.panel.withValues(alpha: 0.9),
        child: Text(
          config.mode == TennisMode.training
              ? 'TRAINING // ${config.trainingLesson}'
              : config.mode.label,
          style: Cyber.display(9, color: Cyber.cyan, letterSpacing: 1),
        ),
      ),
    );
  }
}

class _MatchScoreboard extends StatelessWidget {
  const _MatchScoreboard({required this.game});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TennisScoreState>(
      valueListenable: game.score,
      builder: (context, score, _) {
        final player = tennisPlayerById(game.config.playerId);
        final opponent = tennisPlayerById(game.config.opponentId);
        return ClipPath(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
          child: Container(
            color: Cyber.bg.withValues(alpha: 0.92),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
            child: Column(
              children: [
                _ScoreRow(
                  name: opponent.name.toUpperCase(),
                  serving: score.currentServer == 1,
                  games: score.opponentGames,
                  points: score.pointLabel(1),
                  accent: Cyber.amber,
                ),
                const Divider(height: 9, color: Cyber.border),
                _ScoreRow(
                  name: player.name.toUpperCase(),
                  serving: score.currentServer == 0,
                  games: score.playerGames,
                  points: score.pointLabel(0),
                  accent: Cyber.cyan,
                ),
                if (score.isDeuce || score.tieBreak)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      score.tieBreak ? 'TIEBREAK' : 'DEUCE',
                      style: Cyber.display(8, color: Cyber.lime),
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

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    required this.name,
    required this.serving,
    required this.games,
    required this.points,
    required this.accent,
  });

  final String name;
  final bool serving;
  final int games;
  final String points;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: serving ? Cyber.lime : Cyber.border,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Cyber.display(10, color: Colors.white),
          ),
        ),
        Text('$games', style: Cyber.display(18, color: accent)),
        const SizedBox(width: 18),
        SizedBox(
          width: 43,
          child: Text(
            points,
            textAlign: TextAlign.right,
            style: Cyber.display(16, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _PracticeScoreboard extends StatelessWidget {
  const _PracticeScoreboard({required this.game});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        game.practiceScore,
        game.ballsRemaining,
        game.lessonProgress,
        game.elapsedTenths,
        game.rally,
      ]),
      builder: (context, _) {
        final mode = game.config.mode;
        late String primary;
        late String secondary;
        if (mode == TennisMode.endlessRally) {
          primary = '${game.practiceScore.value} RETURNS';
          secondary = 'PACE +2% EVERY 5';
        } else if (mode == TennisMode.targetPractice) {
          primary = '${game.practiceScore.value} PTS';
          final remaining = max(0, 90 - game.elapsedTenths.value ~/ 10);
          secondary = '${game.ballsRemaining.value} BALLS / ${remaining}s';
        } else {
          primary = 'LESSON ${game.config.trainingLesson}';
          secondary = '${game.lessonProgress.value} ACTIONS COMPLETE';
        }
        return ClipPath(
          clipper: const HudChamferClipper(bigCut: 12, smallCut: 4),
          child: Container(
            color: Cyber.bg.withValues(alpha: 0.92),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Text(primary, style: Cyber.display(15, color: Cyber.lime)),
                const Spacer(),
                Text(secondary, style: Cyber.display(8, color: Cyber.muted)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ServeMeter extends StatelessWidget {
  const _ServeMeter({required this.game});

  final TennisGame game;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([game.phase, game.serveMeter]),
      builder: (context, _) {
        final visible =
            game.phase.value == TennisMatchPhase.preServe ||
            game.phase.value == TennisMatchPhase.serving;
        return AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: visible ? 1 : 0,
          child: Container(
            width: 182,
            padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
            color: Cyber.bg.withValues(alpha: 0.82),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          game.engine.serveNumber == 1
                              ? '1ST SERVE'
                              : '2ND SERVE',
                          style: Cyber.display(8, color: Cyber.muted),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          'RELEASE IN GREEN',
                          style: Cyber.display(7, color: Cyber.lime),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Stack(
                  children: [
                    Container(height: 5, color: Cyber.border),
                    Positioned(
                      left: 122,
                      width: 26,
                      child: Container(
                        height: 5,
                        color: Cyber.lime.withValues(alpha: 0.48),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: game.serveMeter.value,
                      child: Container(height: 5, color: Cyber.cyan),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Meter extends StatelessWidget {
  const _Meter({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: Cyber.display(8, color: Cyber.muted)),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: Cyber.display(8, color: color),
            ),
          ],
        ),
        const SizedBox(height: 5),
        CyberProgressBar(
          value: value,
          accent: color,
          height: 5,
          animate: false,
        ),
      ],
    );
  }
}

class _HudButton extends StatelessWidget {
  const _HudButton({
    required this.icon,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 36,
          decoration: BoxDecoration(
            color: Cyber.panel.withValues(alpha: 0.9),
            border: Border.all(color: Cyber.cyan.withValues(alpha: 0.46)),
          ),
          child: Icon(icon, color: Cyber.cyan, size: 21),
        ),
      ),
    );
  }
}
```

## Appendix C — Host screens (verbatim, reference only)

Shown so the wiring in §7 can be read in full. **Not compile-checked**: these import source-app systems listed in §9 (global `GameBloc`, audio scenes, matchmaking gate, level-up celebration, confirm dialog). Port them by applying §9.

### C.1 `lib/screens/tennis/tennis_match_screen.dart`

<sub>722 lines</sub>

```dart
import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_event.dart';
import '../../blocs/tennis/tennis_cubit.dart';
import '../../config/theme.dart';
import '../../games/tennis/tennis_engine.dart';
import '../../games/tennis/tennis_game.dart';
import '../../models/tennis.dart';
import '../../utils/game_audio_mappings.dart';
import '../../utils/sound_effects.dart';
import '../../widgets/cyber/cyber_cta_button.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import 'widgets/tennis_controls.dart';
import 'widgets/tennis_hud.dart';

class TennisMatchScreen extends StatefulWidget {
  const TennisMatchScreen({
    required this.config,
    required this.onExit,
    required this.onRestart,
    required this.onContinueTournament,
    super.key,
  });

  final TennisMatchConfig config;
  final VoidCallback onExit;
  final VoidCallback onRestart;
  final VoidCallback onContinueTournament;

  @override
  State<TennisMatchScreen> createState() => _TennisMatchScreenState();
}

class _TennisMatchScreenState extends State<TennisMatchScreen>
    with WidgetsBindingObserver {
  late final TennisCubit _cubit;
  late final TennisGame _game;
  late TennisSettings _settings;
  bool _paused = false;
  bool _showSettings = false;
  bool _settling = false;
  bool _settled = false;
  bool _deliberateExit = false;
  TennisMatchSummary? _summary;
  TennisReward _reward = TennisReward.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cubit = context.read<TennisCubit>();
    _settings = _cubit.state.profile.settings;
    final candidate = _cubit.state.resumeSnapshot;
    final resume = candidate?.config.matchId == widget.config.matchId
        ? candidate
        : null;
    _game = TennisGame(
      config: widget.config,
      settings: _settings.copyWith(
        reducedMotion:
            _settings.reducedMotion ||
            WidgetsBinding
                .instance
                .platformDispatcher
                .accessibilityFeatures
                .disableAnimations,
      ),
      resume: resume,
      onEvents: _onEvents,
    );
    AudioController.instance.enterScene(
      AudioScene.tennis,
      musicEnabled: _settings.music,
    );
    if (!kIsWeb) {
      unawaited(
        SystemChrome.setPreferredOrientations(const [
          DeviceOrientation.portraitUp,
        ]),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _pause(auto: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioController.instance.leaveScene(AudioScene.tennis);
    if (!_settled && !_deliberateExit) {
      unawaited(_cubit.saveSnapshot(_game.snapshot()));
    }
    if (!kIsWeb) {
      unawaited(SystemChrome.setPreferredOrientations(const []));
    }
    super.dispose();
  }

  void _onEvents(List<TennisEvent> events) {
    for (final event in events) {
      if (_settings.sound) {
        playSound(tennisSoundForEvent(event.type));
      }
      if (_settings.haptics && event.team == 0) {
        if (event.type == TennisEventType.perfectContact) {
          HapticFeedback.selectionClick();
        } else if (event.type == TennisEventType.winner ||
            event.type == TennisEventType.ace) {
          HapticFeedback.mediumImpact();
        }
      }
      if (event.type == TennisEventType.setEnded) {
        unawaited(_finish());
      }
    }
  }

  Future<void> _finish() async {
    if (_settling || _settled) return;
    _settling = true;
    _game.setPaused(true);
    final tournamentChampion =
        widget.config.mode == TennisMode.tournament &&
        widget.config.tournamentRound == 2 &&
        _game.engine.score.setWinner == 0;
    final summary = _game.summary(tournamentChampion: tournamentChampion);
    final reward = await _cubit.settle(summary);
    if (!mounted) return;
    context.read<GameBloc>().add(
      TennisFinished(
        matchId: summary.matchId,
        playerName: tennisPlayerById(summary.playerId).name,
        opponentName: tennisPlayerById(summary.opponentId).name,
        modeLabel: summary.mode.label,
        difficultyLabel: summary.difficulty.label,
        resultLabel: _resultLabel(summary),
        grade: summary.grade,
        playerGames:
            summary.mode == TennisMode.quickMatch ||
                summary.mode == TennisMode.tournament
            ? summary.playerGames
            : summary.practiceScore,
        opponentGames:
            summary.mode == TennisMode.quickMatch ||
                summary.mode == TennisMode.tournament
            ? summary.opponentGames
            : 0,
        xp: reward.xp,
        coins: reward.coins,
      ),
    );
    if (_settings.sound) {
      playSound(
        summary.won ? SoundEffect.tennisVictory : SoundEffect.tennisDefeat,
      );
    }
    if (_settings.haptics) HapticFeedback.heavyImpact();
    setState(() {
      _summary = summary;
      _reward = reward;
      _settled = true;
      _settling = false;
      _paused = false;
      _showSettings = false;
    });
  }

  String _resultLabel(TennisMatchSummary summary) {
    if (summary.mode == TennisMode.training) return 'Lesson Complete';
    if (summary.mode == TennisMode.endlessRally ||
        summary.mode == TennisMode.targetPractice) {
      return 'Completed';
    }
    return summary.won ? 'Victory' : 'Defeat';
  }

  void _pause({bool auto = false}) {
    if (_settled || _game.engine.complete) return;
    _game.setPaused(true);
    AudioController.instance.setSceneMusicEnabled(false);
    unawaited(_cubit.saveSnapshot(_game.snapshot()));
    if (mounted) {
      setState(() {
        _paused = true;
        if (auto) _showSettings = false;
      });
    }
  }

  void _resume() {
    _game.setPaused(false);
    AudioController.instance.setSceneMusicEnabled(_settings.music);
    setState(() {
      _paused = false;
      _showSettings = false;
    });
  }

  Future<void> _quit() async {
    if (_settled) {
      widget.onExit();
      return;
    }
    _pause();
    final leave = await showCyberConfirmDialog(
      context,
      title: 'QUIT MATCH?',
      message: 'This run will be cleared and grants no XP or Oz Coins.',
      confirmLabel: 'Quit',
      cancelLabel: 'Resume',
      destructive: true,
    );
    if (!mounted) return;
    if (leave) {
      _deliberateExit = true;
      await _cubit.abandonMatch();
      widget.onExit();
    } else {
      _resume();
    }
  }

  Future<void> _restart() async {
    _deliberateExit = true;
    await _cubit.abandonMatch();
    widget.onRestart();
  }

  void _updateSettings(TennisSettings settings) {
    _game.applySettings(settings);
    setState(() => _settings = settings);
    AudioController.instance.setSceneMusicEnabled(settings.music);
    _cubit.updateSettings(settings);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_quit());
      },
      child: Scaffold(
        backgroundColor: Cyber.bg,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Stack(
              fit: StackFit.expand,
              children: [
                GameWidget<TennisGame>(game: _game),
                TennisHud(game: _game, onPause: _pause),
                TennisStingLayer(game: _game),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    ignoring: _paused || _settled,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TennisStatusRails(game: _game),
                        TennisControls(game: _game, settings: _settings),
                      ],
                    ),
                  ),
                ),
                if (_paused)
                  _PauseOverlay(
                    settings: _settings,
                    showSettings: _showSettings,
                    onResume: _resume,
                    onSettings: () =>
                        setState(() => _showSettings = !_showSettings),
                    onUpdateSettings: _updateSettings,
                    onRestart: () => unawaited(_restart()),
                    onQuit: () => unawaited(_quit()),
                  ),
                if (_summary != null)
                  _ResultOverlay(
                    summary: _summary!,
                    reward: _reward,
                    tournamentContinues:
                        _summary!.mode == TennisMode.tournament &&
                        _summary!.won &&
                        !_summary!.tournamentChampion,
                    onContinueTournament: widget.onContinueTournament,
                    onRestart: widget.onRestart,
                    onExit: widget.onExit,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.settings,
    required this.showSettings,
    required this.onResume,
    required this.onSettings,
    required this.onUpdateSettings,
    required this.onRestart,
    required this.onQuit,
  });

  final TennisSettings settings;
  final bool showSettings;
  final VoidCallback onResume;
  final VoidCallback onSettings;
  final ValueChanged<TennisSettings> onUpdateSettings;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.92),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 390),
              child: CyberPanel(
                accent: Cyber.cyan,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: showSettings
                      ? _SettingsPanel(
                          settings: settings,
                          onChanged: onUpdateSettings,
                          onBack: onSettings,
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'MATCH PAUSED',
                              textAlign: TextAlign.center,
                              style: Cyber.display(24, color: Cyber.cyan),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your exact point has been saved.',
                              textAlign: TextAlign.center,
                              style: Cyber.body(13, color: Cyber.muted),
                            ),
                            const SizedBox(height: 22),
                            HudCtaButton(
                              label: 'RESUME',
                              icon: Icons.play_arrow_rounded,
                              onTap: onResume,
                            ),
                            const SizedBox(height: 10),
                            _PauseAction(
                              label: 'SETTINGS',
                              icon: Icons.tune,
                              onTap: onSettings,
                            ),
                            _PauseAction(
                              label: 'RESTART MATCH',
                              icon: Icons.refresh,
                              onTap: onRestart,
                            ),
                            _PauseAction(
                              label: 'QUIT WITHOUT REWARD',
                              icon: Icons.exit_to_app,
                              color: Cyber.danger,
                              onTap: onQuit,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({
    required this.settings,
    required this.onChanged,
    required this.onBack,
  });

  final TennisSettings settings;
  final ValueChanged<TennisSettings> onChanged;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: Cyber.cyan),
            ),
            Text('ACCESSIBILITY', style: Cyber.display(17, color: Cyber.cyan)),
          ],
        ),
        _SettingSwitch(
          label: 'LEFT-HANDED CONTROLS',
          value: settings.leftHanded,
          onChanged: (value) => onChanged(settings.copyWith(leftHanded: value)),
        ),
        _SettingSwitch(
          label: 'MOVEMENT ASSIST',
          value: settings.movementAssist,
          onChanged: (value) =>
              onChanged(settings.copyWith(movementAssist: value)),
        ),
        _SettingSwitch(
          label: 'REDUCED MOTION',
          value: settings.reducedMotion,
          onChanged: (value) =>
              onChanged(settings.copyWith(reducedMotion: value)),
        ),
        _SettingSwitch(
          label: 'STRONG FLASHES',
          value: settings.strongFlashes,
          onChanged: (value) =>
              onChanged(settings.copyWith(strongFlashes: value)),
        ),
        _SettingSwitch(
          label: 'HAPTICS',
          value: settings.haptics,
          onChanged: (value) => onChanged(settings.copyWith(haptics: value)),
        ),
        _SettingSwitch(
          label: 'SOUND',
          value: settings.sound,
          onChanged: (value) => onChanged(settings.copyWith(sound: value)),
        ),
        const SizedBox(height: 10),
        Text('CONTROL SIZE', style: Cyber.display(9, color: Cyber.muted)),
        Slider(
          value: settings.controlScale,
          min: 0.8,
          max: 1.25,
          activeColor: Cyber.cyan,
          inactiveColor: Cyber.border,
          onChanged: (value) =>
              onChanged(settings.copyWith(controlScale: value)),
        ),
        Text('CONTROL OPACITY', style: Cyber.display(9, color: Cyber.muted)),
        Slider(
          value: settings.controlOpacity,
          min: 0.45,
          max: 1,
          activeColor: Cyber.lime,
          inactiveColor: Cyber.border,
          onChanged: (value) =>
              onChanged(settings.copyWith(controlOpacity: value)),
        ),
      ],
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: Cyber.display(9, color: Colors.white)),
      value: value,
      activeThumbColor: Cyber.cyan,
      onChanged: onChanged,
    );
  }
}

class _PauseAction extends StatelessWidget {
  const _PauseAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color = Cyber.muted,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label, style: Cyber.display(10, color: color)),
          ],
        ),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.summary,
    required this.reward,
    required this.tournamentContinues,
    required this.onContinueTournament,
    required this.onRestart,
    required this.onExit,
  });

  final TennisMatchSummary summary;
  final TennisReward reward;
  final bool tournamentContinues;
  final VoidCallback onContinueTournament;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final accent = summary.won ? Cyber.lime : Cyber.danger;
    final matchMode =
        summary.mode == TennisMode.quickMatch ||
        summary.mode == TennisMode.tournament;
    return ColoredBox(
      color: Cyber.bg.withValues(alpha: 0.95),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 410),
              child: CyberPanel(
                accent: accent,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        summary.tournamentChampion
                            ? 'CHAMPION'
                            : _resultTitle(summary),
                        textAlign: TextAlign.center,
                        style: Cyber.display(29, color: accent),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        matchMode
                            ? '${summary.playerGames} - ${summary.opponentGames}'
                            : summary.mode == TennisMode.training
                            ? 'LESSON ${summary.trainingLesson} COMPLETE'
                            : '${summary.practiceScore} POINTS',
                        textAlign: TextAlign.center,
                        style: Cyber.display(24, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _ResultStat(label: 'GRADE', value: summary.grade),
                          _ResultStat(label: 'XP', value: '+${reward.xp}'),
                          _ResultStat(
                            label: 'COINS',
                            value: '+${reward.coins}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _PerformanceRow(
                        label: 'FIRST SERVE',
                        value:
                            '${(summary.stats.firstServePercentage * 100).round()}%',
                      ),
                      _PerformanceRow(
                        label: 'WINNERS / ERRORS',
                        value:
                            '${summary.stats.winners} / ${summary.stats.unforcedErrors}',
                      ),
                      _PerformanceRow(
                        label: 'LONGEST RALLY',
                        value: '${summary.stats.longestRally}',
                      ),
                      _PerformanceRow(
                        label: 'PERFECT CONTACTS',
                        value: '${summary.stats.perfectContacts}',
                      ),
                      if (reward.farmed)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'REPEAT BONUS SUPPRESSED - CHANGE RIVAL OR DIFFICULTY',
                            textAlign: TextAlign.center,
                            style: Cyber.display(8, color: Cyber.amber),
                          ),
                        ),
                      const SizedBox(height: 20),
                      HudCtaButton(
                        label: tournamentContinues
                            ? 'NEXT ROUND'
                            : 'BACK TO TENNIS',
                        icon: tournamentContinues
                            ? Icons.arrow_forward
                            : Icons.sports_tennis,
                        accent: accent,
                        onTap: tournamentContinues
                            ? onContinueTournament
                            : onExit,
                      ),
                      if (!tournamentContinues) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: onRestart,
                          icon: const Icon(Icons.refresh, color: Cyber.muted),
                          label: Text(
                            'PLAY AGAIN',
                            style: Cyber.display(10, color: Cyber.muted),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _resultTitle(TennisMatchSummary summary) {
    if (summary.mode == TennisMode.training) return 'LESSON COMPLETE';
    if (summary.mode == TennisMode.endlessRally ||
        summary.mode == TennisMode.targetPractice) {
      return 'SESSION COMPLETE';
    }
    return summary.won ? 'VICTORY' : 'DEFEAT';
  }
}

class _ResultStat extends StatelessWidget {
  const _ResultStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: Cyber.display(19, color: Cyber.cyan)),
          const SizedBox(height: 4),
          Text(label, style: Cyber.display(8, color: Cyber.muted)),
        ],
      ),
    );
  }
}

class _PerformanceRow extends StatelessWidget {
  const _PerformanceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(label, style: Cyber.display(9, color: Cyber.muted)),
          const Spacer(),
          Text(value, style: Cyber.display(10, color: Colors.white)),
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

### D.2 `lib/config/enums.dart`

<sub>2 lines</sub>

```dart
// STAND-IN for the host app's lib/config/enums.dart — only what Tennis reads.
enum CardTier { bronze, silver, gold, platinum }
```

### D.3 `lib/models/starter_pack.dart`

<sub>10 lines</sub>

```dart
// STAND-IN for the host app's lib/models/starter_pack.dart — only what
// Tennis reads (TennisPlayer.tier). Verbatim thresholds.
import '../config/enums.dart';

CardTier packRarityForRating(int rating) {
  if (rating >= 90) return CardTier.platinum;
  if (rating >= 86) return CardTier.gold;
  if (rating >= 80) return CardTier.silver;
  return CardTier.bronze;
}
```

### D.4 `lib/services/secure_storage_service.dart`

<sub>75 lines</sub>

```dart
// STAND-IN for the host app's lib/services/secure_storage_service.dart.
// The real class also holds secure-storage data for other modes; the game
// records below live in plain SharedPreferences (verbatim methods + keys).
// Add `shared_preferences` to pubspec.yaml.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/tennis.dart';

class SecureGameStorage {
  static const _tennisProfileKey = 'pd_tennis_profile_v1';
  static const _tennisResumeKey = 'pd_tennis_resume_v1';
  static const _tennisSettlementKey = 'pd_tennis_settlements_v1';

  Future<TennisProfile> loadTennisProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tennisProfileKey);
      if (raw == null || raw.isEmpty) return const TennisProfile();
      return TennisProfile.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return const TennisProfile();
    }
  }

  Future<void> saveTennisProfile(TennisProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tennisProfileKey, jsonEncode(profile.toJson()));
  }

  Future<TennisMatchSnapshot?> loadTennisMatchSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_tennisResumeKey);
      if (raw == null || raw.isEmpty) return null;
      return TennisMatchSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTennisMatchSnapshot(TennisMatchSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tennisResumeKey, jsonEncode(snapshot.toJson()));
  }

  Future<void> clearTennisMatchSnapshot() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tennisResumeKey);
  }

  Future<Set<String>> loadTennisRewardSettlementIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_tennisSettlementKey) ?? const <String>[])
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveTennisRewardSettlementIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final bounded = ids.toList(growable: false);
    await prefs.setStringList(
      _tennisSettlementKey,
      bounded.length <= 256 ? bounded : bounded.sublist(bounded.length - 256),
    );
  }
}
```

### D.5 `lib/utils/sound_effects.dart`

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

### D.6 `lib/widgets/cyber/cyber_widgets.dart`

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

### D.7 `lib/widgets/cyber/cyber_cta_button.dart`

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

### E.1 `test/tennis_engine_test.dart`

<sub>542 lines</sub>

```dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/games/tennis/tennis_engine.dart';
import 'package:card_game/models/tennis.dart';

void main() {
  group('TennisScoring', () {
    test('scores a straight 6-0 set and rotates service each game', () {
      final scoring = TennisScoring(firstServer: 0);
      for (var game = 0; game < 6; game++) {
        final serverBefore = scoring.state.currentServer;
        final results = _winGame(scoring, 0);
        expect(results.last.gameWon, isTrue);
        expect(scoring.state.currentServer, 1 - serverBefore);
      }
      expect(scoring.state.playerGames, 6);
      expect(scoring.state.opponentGames, 0);
      expect(scoring.state.setWinner, 0);
    });

    test('supports a 7-5 set', () {
      final scoring = TennisScoring(firstServer: 0);
      for (var i = 0; i < 5; i++) {
        _winGame(scoring, 0);
        _winGame(scoring, 1);
      }
      _winGame(scoring, 0);
      final result = _winGame(scoring, 0).last;
      expect(result.setWon, isTrue);
      expect(scoring.state.playerGames, 7);
      expect(scoring.state.opponentGames, 5);
    });

    test('returns from advantage to deuce repeatedly', () {
      final scoring = TennisScoring(firstServer: 0);
      for (var i = 0; i < 3; i++) {
        scoring.awardPoint(0);
        scoring.awardPoint(1);
      }
      expect(scoring.state.isDeuce, isTrue);
      scoring.awardPoint(0);
      expect(scoring.state.advantage, 0);
      scoring.awardPoint(1);
      expect(scoring.state.advantage, -1);
      expect(scoring.state.isDeuce, isTrue);
      scoring.awardPoint(1);
      expect(scoring.state.advantage, 1);
      scoring.awardPoint(0);
      scoring.awardPoint(0);
      final result = scoring.awardPoint(0);
      expect(result.gameWon, isTrue);
      expect(scoring.state.playerGames, 1);
    });

    test('enters 6-6 and plays a long win-by-two tiebreak', () {
      final scoring = TennisScoring(firstServer: 0);
      for (var i = 0; i < 6; i++) {
        _winGame(scoring, 0);
        _winGame(scoring, 1);
      }
      expect(scoring.state.tieBreak, isTrue);
      expect(scoring.state.currentServer, 0);

      final servers = <int>[];
      for (final winner in <int>[0, 1, 1, 0, 0, 1, 1, 0, 0, 1, 1, 0]) {
        servers.add(scoring.state.currentServer);
        scoring.awardPoint(winner);
      }
      expect(servers.take(7), <int>[0, 1, 1, 0, 0, 1, 1]);
      expect(scoring.state.playerTieBreak, 6);
      expect(scoring.state.opponentTieBreak, 6);
      scoring.awardPoint(0);
      final result = scoring.awardPoint(0);
      expect(result.setWon, isTrue);
      expect(scoring.state.playerGames, 7);
      expect(scoring.state.opponentGames, 6);
    });

    test('reports break points, set points, and two-game end changes', () {
      final scoring = TennisScoring(firstServer: 0);
      scoring.awardPoint(1);
      scoring.awardPoint(1);
      scoring.awardPoint(1);
      expect(scoring.isBreakPointFor(1), isTrue);
      final saved = scoring.awardPoint(0);
      expect(saved.breakPointSaved, isTrue);

      _winGame(scoring, 0);
      expect(scoring.state.totalGames, 1);
      final secondGame = _winGame(scoring, 0).last;
      expect(secondGame.endChange, isTrue);

      while (scoring.state.playerGames < 5) {
        _winGame(scoring, 0);
      }
      scoring.awardPoint(0);
      scoring.awardPoint(0);
      scoring.awardPoint(0);
      expect(scoring.isSetPointFor(0), isTrue);
    });
  });

  group('Court calls and serves', () {
    test('singles lines and service-box lines are inclusive', () {
      expect(
        tennisBallInsideSingles(tennisCourtHalfWidth, tennisCourtHalfLength),
        isTrue,
      );
      expect(tennisBallInsideSingles(tennisCourtHalfWidth + 0.01, 0), isFalse);
      expect(
        tennisServeInsideBox(
          x: tennisCourtHalfWidth,
          y: -tennisServiceLine,
          server: 0,
          rightServiceCourt: true,
        ),
        isTrue,
      );
      expect(
        tennisServeInsideBox(x: -1, y: -4, server: 0, rightServiceCourt: true),
        isFalse,
      );
    });

    test('keeps a let on the same serve and faults twice', () {
      final letEngine = TennisEngine(_config(seed: 2));
      _setServeBounce(letEngine, x: 1, y: -4, netTouched: true);
      final letEvents = letEngine.step(
        TennisIntent.idle,
        TennisIntent.idle,
        1 / 120,
      );
      expect(
        letEvents.map((event) => event.type),
        contains(TennisEventType.let),
      );
      expect(letEngine.serveNumber, 1);
      expect(letEngine.score.playerPoints, 0);

      final faultEngine = TennisEngine(_config(seed: 2));
      _setServeBounce(faultEngine, x: -1, y: -4);
      final first = faultEngine.step(
        TennisIntent.idle,
        TennisIntent.idle,
        1 / 120,
      );
      expect(first.map((event) => event.type), contains(TennisEventType.fault));
      expect(faultEngine.serveNumber, 2);

      faultEngine.phase = TennisMatchPhase.rally;
      _setServeBounce(faultEngine, x: -1, y: -4);
      faultEngine.serveNumber = 2;
      final second = faultEngine.step(
        TennisIntent.idle,
        TennisIntent.idle,
        1 / 120,
      );
      expect(
        second.map((event) => event.type),
        contains(TennisEventType.doubleFault),
      );
      expect(faultEngine.score.opponentPoints, 1);
    });

    test('awards the hitter after a legal second bounce', () {
      final engine = TennisEngine(_config(seed: 2));
      engine.phase = TennisMatchPhase.rally;
      engine.ball
        ..x = 0
        ..y = -4
        ..z = 0.001
        ..vx = 0
        ..vy = 0
        ..vz = -1
        ..bounces = 1
        ..lastHitter = 0
        ..live = true
        ..serve = false;
      engine.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
      expect(engine.score.playerPoints, 1);
    });

    test('dead net cord landing on the hitter side awards the receiver', () {
      final engine = TennisEngine(_config(seed: 2));
      engine.phase = TennisMatchPhase.rally;
      engine.ball
        ..x = 0
        ..y = 3
        ..z = 0.001
        ..vx = 0
        ..vy = 0
        ..vz = -1
        ..bounces = 0
        ..lastHitter = 0
        ..live = true
        ..serve = false
        ..netTouched = true;
      engine.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
      expect(engine.score.opponentPoints, 1);
    });
  });

  group('Shots, stamina, focus, and snapshots', () {
    test('maps gesture intent to spin, lob, slice, drop, and power shots', () {
      expect(_contactShot(aimY: 0.3), TennisShotType.topspin);
      expect(_contactShot(aimY: 0.8), TennisShotType.lob);
      expect(_contactShot(aimY: -0.3), TennisShotType.slice);
      expect(_contactShot(aimY: -0.8), TennisShotType.dropShot);
      expect(_contactShot(hold: 0.4), TennisShotType.power);
    });

    test('prioritises volley, smash, and defensive returns by context', () {
      expect(
        _contactShot(playerY: 3.2, ballZ: 1.1, bounces: 0),
        TennisShotType.volley,
      );
      expect(
        _contactShot(playerY: 3.2, ballZ: 2.3, bounces: 0),
        TennisShotType.smash,
      );
      expect(
        _contactShot(ballOffsetX: 1.05, bounces: 1),
        TennisShotType.defensive,
      );
    });

    test('allows only one opponent contact per incoming ball', () {
      final engine = TennisEngine(_config(seed: 3));
      engine.phase = TennisMatchPhase.rally;
      engine.ball
        ..x = engine.opponent.x
        ..y = engine.opponent.y
        ..z = 1
        ..vx = 0
        ..vy = -1
        ..vz = 0
        ..bounces = 1
        ..lastHitter = 0
        ..live = true
        ..serve = false;

      var opponentContacts = 0;
      for (var i = 0; i < 30; i++) {
        final events = engine.step(
          TennisIntent.idle,
          const TennisIntent(shotReleased: true),
          1 / 120,
        );
        opponentContacts += events
            .where(
              (event) =>
                  event.type == TennisEventType.contact && event.team == 1,
            )
            .length;
      }

      expect(opponentContacts, 1);
      expect(engine.ball.lastHitter, 1);
      expect(engine.flightId, 1);
    });

    test('CPU return misses reflect rival ratings', () {
      final shakyMisses = _countOpponentMisses('taylor-fritz');
      final eliteMisses = _countOpponentMisses('riven-cole');

      expect(shakyMisses, greaterThan(eliteMisses));
    });

    test('CPU miss consumes the incoming flight without instant retry', () {
      final seed = _firstOpponentMissSeed('taylor-fritz');
      final engine = TennisEngine(
        _config(seed: seed, opponentId: 'taylor-fritz'),
      );
      _setOpponentReturn(engine);

      final first = engine.step(
        TennisIntent.idle,
        const TennisIntent(shotReleased: true),
        1 / 120,
      );
      final second = engine.step(
        TennisIntent.idle,
        const TennisIntent(shotReleased: true),
        1 / 120,
      );
      final contacts = [...first, ...second].where(
        (event) => event.type == TennisEventType.contact && event.team == 1,
      );

      expect(contacts, isEmpty);
      expect(engine.ball.lastHitter, 0);
    });

    test('does not let the opponent intercept target-practice returns', () {
      final engine = TennisEngine(
        _config(seed: 2, mode: TennisMode.targetPractice),
      );
      engine.phase = TennisMatchPhase.rally;
      engine.ball
        ..x = engine.opponent.x
        ..y = engine.opponent.y
        ..z = 1
        ..bounces = 0
        ..lastHitter = 0
        ..live = true;

      expect(engine.canHit(1), isFalse);
    });

    test('bounds movement and stamina even under continuous sprint', () {
      final engine = TennisEngine(_config(seed: 2));
      for (var i = 0; i < 120 * 30; i++) {
        engine.step(
          const TennisIntent(moveX: 1, moveY: 1, sprint: true),
          TennisIntent.idle,
          1 / 120,
        );
      }
      expect(engine.player.stamina, inInclusiveRange(0, 100));
      expect(
        engine.player.x,
        inInclusiveRange(
          -tennisCourtHalfWidth - 1.1,
          tennisCourtHalfWidth + 1.1,
        ),
      );
      expect(
        engine.player.y,
        inInclusiveRange(0.75, tennisCourtHalfLength + 1.1),
      );
      expect(engine.player.x.isFinite, isTrue);
      expect(engine.player.y.isFinite, isTrue);
    });

    test('restores an exact deterministic simulation and RNG state', () {
      final first = TennisEngine(_config(seed: 90210));
      for (var i = 0; i < 240; i++) {
        first.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
      }
      final restored = TennisEngine(
        first.config,
        snapshot:
            jsonDecode(jsonEncode(first.snapshot())) as Map<String, dynamic>,
      );
      for (var i = 0; i < 360; i++) {
        first.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
        restored.step(TennisIntent.idle, TennisIntent.idle, 1 / 120);
      }
      expect(jsonEncode(restored.snapshot()), jsonEncode(first.snapshot()));
    });
  });

  group('Seeded AI full-set soak', () {
    for (final difficulty in TennisDifficulty.values) {
      test(
        '${difficulty.name} completes with a deterministic legal replay',
        () {
          final a = _runAiSet(difficulty, seed: 4400 + difficulty.index);
          final b = _runAiSet(difficulty, seed: 4400 + difficulty.index);
          expect(a.summary.toJson(), b.summary.toJson());
          expect(a.snapshot, b.snapshot);
          expect(a.summary.playerGames, inInclusiveRange(0, 7));
          expect(a.summary.opponentGames, inInclusiveRange(0, 7));
          expect(a.summary.stats.durationSeconds, inInclusiveRange(20, 3600));
        },
      );
    }
  });
}

List<TennisPointResult> _winGame(TennisScoring scoring, int winner) => [
  for (var i = 0; i < 4; i++) scoring.awardPoint(winner),
];

TennisMatchConfig _config({
  int seed = 1,
  TennisDifficulty difficulty = TennisDifficulty.pro,
  TennisMode mode = TennisMode.quickMatch,
  String opponentId = 'taylor-fritz',
}) => TennisMatchConfig(
  matchId: 'test-$seed-${difficulty.name}',
  mode: mode,
  playerId: 'frances-tiafoe',
  opponentId: opponentId,
  difficulty: difficulty,
  seed: seed,
);

int _countOpponentMisses(String opponentId) {
  var misses = 0;
  for (var seed = 1; seed <= 800; seed++) {
    final engine = TennisEngine(_config(seed: seed, opponentId: opponentId));
    _setOpponentReturn(engine);
    final events = engine.step(
      TennisIntent.idle,
      const TennisIntent(shotReleased: true),
      1 / 120,
    );
    final contacted = events.any(
      (event) => event.type == TennisEventType.contact && event.team == 1,
    );
    if (!contacted) misses++;
  }
  return misses;
}

int _firstOpponentMissSeed(String opponentId) {
  for (var seed = 1; seed <= 2000; seed++) {
    final engine = TennisEngine(_config(seed: seed, opponentId: opponentId));
    _setOpponentReturn(engine);
    final events = engine.step(
      TennisIntent.idle,
      const TennisIntent(shotReleased: true),
      1 / 120,
    );
    final contacted = events.any(
      (event) => event.type == TennisEventType.contact && event.team == 1,
    );
    if (!contacted) return seed;
  }
  throw StateError('No opponent miss seed found.');
}

void _setOpponentReturn(TennisEngine engine) {
  engine.phase = TennisMatchPhase.rally;
  engine.opponent
    ..x = 0
    ..y = -8.5
    ..stamina = 18;
  engine.ball
    ..x = 0.92
    ..y = -8.5
    ..z = 1.1
    ..vx = 0
    ..vy = -3.2
    ..vz = 0
    ..bounces = 1
    ..lastHitter = 0
    ..live = true
    ..serve = false
    ..netTouched = false
    ..shot = TennisShotType.power;
}

void _setServeBounce(
  TennisEngine engine, {
  required double x,
  required double y,
  bool netTouched = false,
}) {
  engine.phase = TennisMatchPhase.rally;
  engine.ball
    ..x = x
    ..y = y
    ..z = 0.001
    ..vx = 0
    ..vy = 0
    ..vz = -1
    ..bounces = 0
    ..lastHitter = 0
    ..live = true
    ..serve = true
    ..netTouched = netTouched
    ..shot = TennisShotType.serve;
}

TennisShotType _contactShot({
  double aimY = 0,
  double hold = 0,
  double playerY = 9,
  double ballZ = 1,
  double ballOffsetX = 0,
  int bounces = 1,
}) {
  final engine = TennisEngine(_config(seed: 2));
  engine.phase = TennisMatchPhase.rally;
  engine.player
    ..x = 0
    ..y = playerY;
  engine.ball
    ..x = ballOffsetX
    ..y = playerY
    ..z = ballZ
    ..vx = 0
    ..vy = 2
    ..vz = 0
    ..bounces = bounces
    ..lastHitter = 1
    ..live = true
    ..serve = false;
  engine.step(
    TennisIntent(shotReleased: true, holdSeconds: hold, aimY: aimY),
    TennisIntent.idle,
    1 / 120,
  );
  return engine.ball.shot;
}

({TennisMatchSummary summary, String snapshot}) _runAiSet(
  TennisDifficulty difficulty, {
  required int seed,
}) {
  final config = _config(seed: seed, difficulty: difficulty);
  final engine = TennisEngine(config);
  final playerAi = TennisAI(
    difficulty: difficulty,
    seed: seed ^ 0x101,
    team: 0,
  );
  final opponentAi = TennisAI(
    difficulty: difficulty,
    seed: seed ^ 0x202,
    team: 1,
  );
  const maxSteps = 120 * 60 * 60;
  for (var i = 0; i < maxSteps && !engine.complete; i++) {
    engine.step(
      playerAi.think(engine, 1 / 120),
      opponentAi.think(engine, 1 / 120),
      1 / 120,
    );
    expect(engine.player.stamina, inInclusiveRange(0, 100));
    expect(engine.opponent.stamina, inInclusiveRange(0, 100));
    expect(engine.ball.x.isFinite, isTrue);
    expect(engine.ball.y.isFinite, isTrue);
    expect(engine.ball.z.isFinite, isTrue);
  }
  expect(
    engine.complete,
    isTrue,
    reason: '${difficulty.name} set did not finish',
  );
  return (
    summary: engine.summary(),
    snapshot: jsonEncode(<String, dynamic>{
      'engine': engine.snapshot(),
      'playerAi': playerAi.snapshot(),
      'opponentAi': opponentAi.snapshot(),
    }),
  );
}
```
