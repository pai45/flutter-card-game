# Super Over

Super Over is StatOz's six-ball cricket arcade mode. Build a three-batter unit, read each delivery and field, choose an aim and shot type, then time the swing to either chase a target or set the best possible score.

It is a short-form skill mode rather than a full cricket simulation. Card ratings, batter archetypes, field placement, delivery plans, timing, and shot choice all influence the result.

## Purpose

Super Over gives cricket batting cards a fast, replayable use case built around:

- preparing a legal three-batter deck;
- reading the field and the incoming ball;
- deliberately selecting a scoring sector and shot style; and
- executing the swing in the timing window.

The mode contributes XP, match history, and its own saved lifetime stats. It does not award coins or save an unfinished over.

## Where It Lives

Open **Games -> Cricket -> Super Over**. `SuperOverHub` owns the lobby, deck-builder handoff, live Flame scene, pause flow, results, and progression dispatch.

## Requirements and Match Format

**START CHASE** or **START SCORE ATTACK** is available only when the active Cricket deck contains exactly three owned batting cards. Those cards become the batting order:

1. Batter 1 starts on strike.
2. Batter 2 starts at the non-striker's end.
3. Batter 3 replaces the striker after the first wicket.

| Rule | Value |
| --- | --- |
| Balls | 6 legal balls |
| Wickets | 2 |
| Batters | 3 |
| Aim sectors | OFF, STRAIGHT, LEG |
| Shot styles | GROUND, LOFT |
| Modes | Chase and Score Attack |
| End conditions | 6 balls, 2 wickets, or (in Chase) a successful target chase |

Odd runs rotate the strike. Dots and wickets reset the scoring combo. A wicket clears the active momentum/on-fire build-up; the third batter comes in as striker.

## Modes

### Chase

The CPU target is selected from the player-level band below. The displayed chase requirement is one more than that target, so the player must exceed it rather than tie it.

| Player level | CPU target | Required score to win |
| --- | ---: | ---: |
| 1-3 | 8-12 | 9-13 |
| 4-7 | 11-16 | 12-17 |
| 8-12 | 14-19 | 15-20 |
| 13-18 | 16-21 | 17-22 |
| 19+ | 18-23 | 19-24 |

The chase ends as soon as the score passes the CPU target. Otherwise it is lost after the final ball or second wicket.

### Score Attack

Score Attack has no CPU target. Play all available balls to maximise runs and beat the saved Score Attack high score. Its result is recorded as **Completed** in shared match history; chase results are recorded as **Victory** or **Defeat**.

## Round Flow

1. Choose **CHASE** or **SCORE ATTACK** in the lobby.
2. Confirm the three-batter unit and optionally choose a team jersey.
3. Start the mode. The target (for Chase) and a bonus objective are revealed.
4. Each ball rolls a fresh field and delivery plan.
5. Before swinging, choose OFF, STRAIGHT, or LEG, then choose GROUND or LOFT.
6. Read the ball's type, length, and line. Tap the bat after release to swing.
7. The Flame scene plays the delivery, contact, and outcome. The BLoC updates score, strike, confidence, objectives, and match state.
8. After the animation, the next ball starts unless the over is complete.
9. The result screen shows the score, ball trail, key statistics, XP, and **PLAY AGAIN** / **Back To Games** actions.

The close button exits to Games. Pause freezes the current ball; **RESUME** continues it and **QUIT TO HUB** abandons it without saving a completed-over result.

## Ball Setup and Player Choices

### Field

Nine fielders are distributed across OFF / STRAIGHT / LEG using one of these presets:

`[2,4,3]`, `[3,3,3]`, `[4,3,2]`, `[2,3,4]`, `[3,4,2]`, `[4,2,3]`, `[1,5,3]`, `[3,5,1]`.

The sector with the fewest fielders is shown as **OPEN**. A scoring shot into that sector counts toward an *Attack the Open Gap* objective. Sectors with four or more fielders are packed, making catches and low-value outcomes more likely; a sector with one or fewer fielders receives boundary/dot weighting in the batter's favour.

### Delivery plan

A delivery plan has a type, line, length, and pace factor. The HUD reveals the type/length cue and line when the ball can be played.

- Types: **pace**, **slower**, and **spin**. The model also supports the legacy **yorker** type.
- Lines: **off**, **middle**, or **leg**.
- At levels 1-4, lengths are good length or full. Levels 5-9 also unlock short balls; level 10+ can receive yorkers.
- Type probabilities are 52% pace, 20% slower, and 28% spin.

The aim is intentionally selected by the player. Matching the ball's natural line (off -> OFF, middle -> STRAIGHT, leg -> LEG) avoids the normal off-line timing penalty. Improvisers are exempt from that penalty.

### Shot styles

| Style | Trade-off |
| --- | --- |
| **GROUND** | Lower peak power, no sixes from the base result table, and a substantially lower caught chance. Anchors gain an extra safety/boundary adjustment. It is favoured against yorkers. |
| **LOFT** | Higher power and boundary weighting, but a higher caught chance. Power hitters gain an additional loft bonus. It is favoured against short balls. |

## Batting Archetypes and Form

The game derives a lightweight batting style from the striker's card trait:

| Card trait | Style | Gameplay effect |
| --- | --- | --- |
| Batsman and other traits | Anchor | 10% wider timing window; safer ground shots |
| All-rounder | Power Hitter | 6% tighter timing window; loft power/boundary bonus |
| Wicket-keeper | Improviser | Standard window; no off-line aim penalty and one fewer effective fielder in the chosen sector |

Card rating starts from a 360 ms base timing window:

```dart
ratingScale = clamp(1 + (rating - 75) * 0.012, 0.85, 1.30)
```

The legacy delivery multipliers are pace `0.92`, slower `1.04`, spin `1.10`, and yorker `0.78`; **ON FIRE** adds 8%. Archetype, delivery-length matchup, line matchup, and confidence then tune the window used for the shot.

Confidence starts at 0 and is displayed under the striker. A clean scoring contact earns +13 confidence (+20 for perfect timing). A dot/poor contact loses 15 and a wicket loses 32, clamped to 0-100.

Three consecutive clean scoring contacts arm **ON FIRE** for the next resolved delivery. It increases the timing window and shot power, reduces catch risk, then is spent after that delivery. The HUD also tracks a run combo and its best value for the over.

## Timing and Outcome Resolution

Timing error is measured against the tuned contact window. The normalized absolute error maps to tiers as follows:

| Absolute normalized error | Tier |
| --- | --- |
| `<= 0.14` | Perfect |
| `<= 0.32` | Great |
| `<= 0.58` | Good |
| `<= 0.90` | Edge/Poor |
| `> 0.90` | Miss |

No swing before the ball passes the playable window is treated as an automatic late miss using the currently selected aim and shot style.

The tier determines a weighted starting outcome set, then the game applies field pressure, shot style, archetype, ON FIRE, and catch geometry. This makes the table a guide rather than a promise:

| Tier | Base outcomes |
| --- | --- |
| Perfect | Six or four |
| Great | Four, three, two, or one |
| Good | Four, two, one, or dot |
| Edge/Poor | Caught, dot, one, or two |
| Miss | Usually bowled; otherwise dot |

Caught and bowled are wickets. Perfect shots cannot be caught by the geometric catching pass; great, good, and edge/poor contacts can be.

## Objectives

Every over rolls one optional objective, shown below the live HUD:

- **Score N Runs** - in Chase, `N` is the bottom of the current level's CPU target band; in Score Attack it is `12 + min(6, level ~/ 4)`.
- **Hit the Open Gap 2 Times** - score runs in the currently least-covered sector twice.
- **Finish Without a Wicket** - completes only when the over ends with zero wickets.

Objective progress is updated after each resolved ball. Completion increases stored objective totals, adds mastery progress, and awards bonus XP.

## Screens

### Lobby

The cyber-styled lobby provides:

- mode cards for Chase and Score Attack;
- a three-batter unit panel with card archetype, rating, and Super Over mastery level;
- five headline stats: Score Attack record, chase wins, perfect contacts, sixes, and best combo;
- a horizontal IPL-style team jersey picker;
- start / add-batters action, deck builder, and Super Over-filtered match history.

The selected jersey is saved immediately and is used by the batter rendered in the live scene.

### Live match

The live HUD has score/wickets, balls, target or Score Attack status, six-ball tracker, exit and pause controls. It also shows the active objective, selected batter and confidence bar, field counts for each sector, shot-style controls, delivery feedback, and the central bat button when the input window is armed.

The Flame renderer depicts the run-up, release, swing, stadium, fielders, selected jersey, outcome animation, and impact effects. It respects the device's reduced-motion setting.

### Result

Chase games show **CHASE WON** or **CHASE LOST**; Score Attack shows **OVER COMPLETE**. The result includes a margin/summary, new-record indication, six-ball trail, sixes, fours, strike rate, and XP.

## Rewards, Stats, and History

XP is dispatched once after a completed over:

| Component | XP |
| --- | ---: |
| Completion | +10 |
| Runs | +1 per run |
| Sixes | +4 per six |
| Chase win | +15 |
| Objective complete | +8 |

The shared XP ledger labels the source **SUPER OVER** and records runs/wickets. No coin transaction is made.

`SuperOverStats` persists separately in secure storage:

- chase high score and Score Attack high score;
- chase wins, losses, current streak, and best streak;
- total runs, sixes, perfect contacts, and best combo;
- objectives completed;
- mastery XP per batter; and
- the most recently selected jersey.

Each completed over grants every batter in the selected three-card unit the same mastery gain: `max(1, score + perfectContacts * 2 + (objectiveComplete ? 5 : 0))`. A mastery level is displayed as `1 + floor(masteryXP / 100)`.

The lobby's **Match History** is the shared archive filtered to `mode == 'super_over'`; it keeps the latest 12 shared entries.

## Current Notes

- Both Chase and Score Attack are user-selectable from the lobby.
- Score Attack has its own high score and does not alter the chase win streak.
- Objectives are awarded in the progression event (+8 XP). The current result-card calculation displays completion/runs/sixes/chase-win XP but does not yet include that objective bonus, so it can understate the ledger award by 8 XP.
- Statistics and history are written only once the over ends. Quitting mid-over discards it.

## Implementation Reference

| Concern | Source |
| --- | --- |
| Enums, timing, field and base outcome resolution | [`lib/models/super_over.dart`](../../lib/models/super_over.dart) |
| Delivery plans, objectives, archetype tuning | [`lib/games/super_over/super_over_engine.dart`](../../lib/games/super_over/super_over_engine.dart) |
| Persistent stats | [`lib/models/super_over_stats.dart`](../../lib/models/super_over_stats.dart) |
| State, scoring, objectives, and persistence | [`lib/blocs/super_over/super_over_bloc.dart`](../../lib/blocs/super_over/super_over_bloc.dart) |
| Hub, pause handling, animation bridge, and XP dispatch | [`lib/screens/super_over/super_over_hub.dart`](../../lib/screens/super_over/super_over_hub.dart) |
| Lobby, mode picker, batting unit, and jersey picker | [`lib/screens/super_over/super_over_lobby_screen.dart`](../../lib/screens/super_over/super_over_lobby_screen.dart) |
| Live HUD and controls | [`lib/screens/super_over/widgets/super_over_overlays.dart`](../../lib/screens/super_over/widgets/super_over_overlays.dart) |
| Result UI | [`lib/screens/super_over/widgets/super_over_result.dart`](../../lib/screens/super_over/widgets/super_over_result.dart) |
| Flame game renderer | [`lib/games/super_over/super_over_game.dart`](../../lib/games/super_over/super_over_game.dart) |
| Cricket character rig and jersey data | [`lib/games/super_over/cricket_rig.dart`](../../lib/games/super_over/cricket_rig.dart), [`lib/data/super_over_jerseys.dart`](../../lib/data/super_over_jerseys.dart) |
| Shared XP/history settlement | [`lib/blocs/game/game_bloc.dart`](../../lib/blocs/game/game_bloc.dart) |

Relevant tests:

- [`test/super_over_engine_test.dart`](../../test/super_over_engine_test.dart)
- [`test/super_over_bloc_test.dart`](../../test/super_over_bloc_test.dart)
- [`test/super_over_resolution_test.dart`](../../test/super_over_resolution_test.dart)
- [`test/super_over_lobby_screen_test.dart`](../../test/super_over_lobby_screen_test.dart)
