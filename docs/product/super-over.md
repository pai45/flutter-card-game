# Super Over

Super Over is StatOz's cricket arcade chase mode. It converts the user's cricket batting deck into a six-ball, two-wicket target chase: read the field, pick a scoring sector, time the delivery, and beat the CPU target before the over ends.

## Product Purpose

Super Over gives the Cricket section a fast, repeatable skill mode that makes batting cards matter without requiring a full cricket match simulation.

The mode is built around three player skills:

- team preparation through a legal cricket batting deck
- tactical shot selection through field-sector reading
- execution through timing-window mastery

It shares the app's progression economy through XP and uses local lifetime stats for mastery goals. It currently does not award coins.

## Where It Lives

Super Over is opened from the **Games** tab's Cricket section.

The app-level entry delegates into `SuperOverHub`, which owns the mode-specific BLoC, lobby/game routing, Flame game instance, deck-builder handoff, and result overlay.

## Entry Requirements

The lobby requires the cricket Super Over deck to be ready before **START CHASE** is enabled. The live batting order is read from `GameBloc.state.deckBatsmen`.

The current gameplay format uses three batsmen:

- striker starts at batting-order index 0
- non-striker starts at batting-order index 1
- third batsman comes in after the first wicket

The over ends after six legal balls or two wickets. In chase mode, it also ends immediately when the user passes the CPU target.

## End-To-End User Flow

1. User opens **Games -> Cricket -> Super Over**.
2. Super Over lobby loads persisted lifetime stats from secure storage.
3. Lobby shows readiness, deck status, career record, and start/history/deck actions.
4. User may open the Cricket Deck Builder and return directly into play.
5. User taps **START CHASE** when the deck is ready.
6. The BLoC generates a CPU target from player level, rolls the first field, and rolls the first delivery type.
7. The live play screen opens over a Flame cricket scene.
8. For each ball, the user reads field intel and chooses OFF, V, or LEG.
9. The delivery begins; the user taps **SHOOT** to stop the timing meter.
10. Timing, field placement, delivery type, card rating, and ON FIRE state resolve the shot outcome.
11. A ground-view animation plays the shot result.
12. Score, wicket, combo, momentum, striker, field, and next delivery update.
13. The flow repeats until the target is chased, the user runs out of balls, or the user loses two wickets.
14. Result overlay shows the chase verdict, ball-by-ball over summary, XP, and CTAs.
15. The mode persists lifetime Super Over stats and dispatches shared XP through `GameBloc`.

Leaving from the live game exits to the predictions area. A completed over returns to lobby through **CHASE AGAIN** or exits through **EXIT TO LOBBY**.

## Match Format

| Rule | Value |
|------|-------|
| Mode used by UI | Chase |
| Balls | 6 |
| Wickets | 2 |
| Batsmen | 3 |
| Hit sectors | OFF, V, LEG |
| Delivery types | Pace, Spin, Yorker |
| Target source | CPU target scaled by player level |
| Immediate win condition | User score greater than CPU target |
| Immediate loss condition | Over ends without passing target |

The domain model also supports `scoreAttack`, but the current lobby starts `SuperOverMode.chase`.

## Target Generation

In chase mode, the CPU target is based on the user's player level:

```dart
targetRatingForLevel(level) = min(95, 66 + level * 2)
```

That rating is mapped into a rough target band from 8 to 22, then randomized by plus or minus 2. The target is floored at 4.

The player must score `target + 1` to win, matching cricket chase language where tying the target is not enough.

## Shot Mechanics

Each delivery resolves in four stages.

### 1. Delivery Setup

The BLoC rolls:

- a delivery type: `pace`, `spin`, or `yorker`
- a field preset for OFF, V, and LEG

Field presets distribute outfielders so at least one sector is readable as a scoring opportunity. The hit-zone buttons expose this as:

- **GAP** when the sector has 0 or 1 fielder
- fielder dots for normal coverage
- **PACKED** when the sector has 4 or more fielders

### 2. Timing Window

When the user chooses a sector, the Flame strike world starts the delivery. Timing-window length is affected by card rating and delivery type:

```dart
windowScale(rating) = (1.0 + (rating - 75) * 0.012).clamp(0.85, 1.30)
```

Delivery multipliers:

| Delivery | Multiplier | Product Meaning |
|----------|------------|-----------------|
| Yorker | 0.75 | Tightest window |
| Pace | 0.90 | Standard fast ball |
| Spin | 1.10 | More readable timing |

The final delivery duration is clamped between 0.6s and 1.5s.

### 3. Timing Tier

The user taps **SHOOT** to stop the meter. The timing error maps to:

| Timing Error | Tier |
|--------------|------|
| `< 0.10` | Perfect |
| `< 0.25` | Great |
| `< 0.50` | Good |
| `< 0.80` | Early/Late |
| otherwise | Miss |

If the user never hits in time, the game auto-stops and reports a miss-like late outcome.

### 4. Field And Momentum Adjustment

Field placement modifies the timing tier:

- open sector with 0 fielders upgrades one tier
- packed sector with 2 or more fielders downgrades one tier
- perfect shots are protected from downgrade in the live hub logic

If the batsman is **ON FIRE**, the effective tier is boosted one step before outcome resolution. ON FIRE is earned after three consecutive scoring, non-wicket shots and is spent on the next resolved delivery.

### Outcome Table

| Effective Tier | Outcome Distribution |
|----------------|----------------------|
| Perfect | 75% six, 25% four |
| Great | 60% four, 20% three, 20% two |
| Good | 50% two, 50% one |
| Early/Late | 50% dot, 30% caught, 20% one |
| Miss | Bowled |

Runs are `6/4/3/2/1/0` according to outcome. Caught and bowled count as wickets.

## Batting State Rules

After every ball:

- score increases by runs
- balls faced increments by 1
- caught or bowled increments wickets
- wicket clears momentum and ON FIRE
- odd runs rotate strike
- a wicket brings in batsman index 2 as striker
- consecutive scoring shots increase combo
- dot balls and wickets reset combo

The BLoC rolls the next field and delivery immediately after a delivery is resolved.

## Screens And UI

### 1. Super Over Lobby

The lobby is a vertically scrolling cyber-styled screen with a maximum content width of 420px.

Primary UI:

- top `ReactHeaderBar` with player level badge
- **PITCH READY** status strip
- animated cricket emblem
- title `SUPER OVER`
- format line `6 BALLS / 2 WICKETS / 3 BATSMEN`
- career chip showing debutant, career runs, or chase wins
- record panel with high score, chase wins, chase losses, total sixes, and best streak
- **START CHASE** CTA
- **Deck Builder** secondary action
- **Match History** secondary action filtered to `mode == 'super_over'`

Animation and feedback:

- `CyberBackground(animated: true)` gives ambient motion
- content enters through staggered `CyberSlideUpFadeIn`
- cricket emblem spins and pulses with lime glow
- action cards use dealt-card entrance animation
- start tap plays the match-start sound

Working behavior:

- **START CHASE** is muted when the Super Over deck is incomplete
- helper text shows deck readiness and average OVR when available
- deck builder can return directly into `_startGame()`
- stats are loaded from `SecureGameStorage.loadSuperOverStats()`

### 2. Deck Builder Handoff

When the user taps **Deck Builder**, `SuperOverHub` replaces the lobby with `CricketDeckBuilderScreen`.

Working behavior:

- **Back** returns to Super Over lobby
- **Play Super Over** closes deck editing and starts the chase
- the live game always reads the latest `GameBloc.state.deckBatsmen`

### 3. Live Ready Phase

The Flame game renders the strike world beneath Flutter overlays. The ready phase is the pre-ball decision state.

Top HUD:

- close button
- score plate with score/wickets and balls faced
- chase plate with target and live need/off-balls readout
- six-ball timeline

Bottom action bar:

- incoming delivery chip
- striker plate with portrait, name, rating, momentum meter, and ON FIRE styling
- three hit-zone buttons: OFF, V, LEG
- field intel under each zone

Contextual warnings:

- target reveal appears on the first ball
- **LAST MAN** warning appears after one wicket
- **LAST BALL** warning appears before ball 6

Animation and feedback:

- score plate flashes lime/gold for runs and red for wickets
- ball timeline uses elastic pop for completed deliveries
- target reveal scales in with `bannerSlam` sound and haptics
- gap labels pulse
- hit-zone tap compresses the button, plays commit sound, and triggers haptics

Working behavior:

- tapping a sector records `selectedSector`
- phase changes to `delivery`
- strike world begins bowler run-up and ball animation

### 4. Live Delivery Phase

During delivery, hit-zone buttons are replaced by the shot meter and **SHOOT** CTA.

UI:

- **TIME YOUR SHOT** incoming strip pulses
- shot meter shows early, good, perfect, and late regions
- gold needle advances across the track
- perfect band glows lime

Flame animation:

- bowler runs up from deeper pitch position
- bowler arm windmills through release
- ball travels toward the stumps
- ball color matches delivery type
- ball emits delivery-specific trail particles
- batsman idles with breathing motion
- ON FIRE batsman emits amber particles

Working behavior:

- pressing **SHOOT** stops the meter
- strike world calculates timing error against the perfect time
- batsman swings toward OFF, V, or LEG
- timing feedback text appears: PERFECT, GREAT, GOOD, EARLY/LATE, or MISS
- camera shakes lightly on contact
- game switches to ground world for outcome animation

### 5. Ground Outcome Beat

After the shot is resolved, the Flame camera moves to the top-down ground world.

Ground visuals:

- circular cricket ground with glowing boundary rope
- 30-yard circle
- pitch and creases
- two batsmen
- keeper, bowler, and fielders
- fielders reposition each ball according to the rolled field sectors

Outcome animations:

- one/two/three: batsmen run between creases
- four: ball travels to boundary, boundary rope pulses lime
- six: ball arcs through scale animation, boundary flashes gold, confetti bursts
- caught: nearest fielder moves to ball and jumps
- bowled: stump fragments scatter
- dot: subdued single-dot celebration

Effects:

- fielders near the ball chase toward it
- non-boundary balls can be thrown back
- ball trail particles follow motion
- big outcomes spawn text such as `MAXIMUM!`, `BOUNDARY!`, `CAUGHT!`, or `BOWLED!`
- camera shake intensity scales by outcome
- sound/haptics land after the ball beat, not immediately on tap

Working behavior:

- after about 1.5s, BLoC records `SuperOverDeliveryResolved`
- result phase updates score and timeline
- after about 2s, if the over is not finished, phase returns to ready and camera switches back to strike world

### 6. Effects Overlay

`EffectsOverlay` sits between the Flame game and HUD.

It provides:

- colored full-screen flash on transition from delivery to result
- amber ON FIRE vignette
- combo counter when combo is at least 2

Flash colors:

- six: gold
- four: lime
- wicket: danger red
- other: white

The combo counter elastically pops on every combo increment and turns gold from 4x upward.

### 7. Result Screen

The result screen is a full-screen end-of-over cinematic.

Content sequence:

1. `// OVER COMPLETE` greeble header
2. verdict slam: **CHASE WON** or **CHASE LOST**
3. margin line: wickets/balls left, last-ball note, all-out note, or runs short
4. score line with target and balls
5. optional **NEW HIGH SCORE** flare
6. ball-by-ball over summary
7. stat chips for sixes, fours, and strike rate
8. XP count-up panel
9. **CHASE AGAIN** and **EXIT TO LOBBY**

Animation and feedback:

- banner slam plays at 180ms
- match win/loss sound plays at 900ms
- verdict uses elastic scale-in
- summary balls appear staggered
- XP count animates after the panel is visible
- new high score pulses gold

Working behavior:

- **CHASE AGAIN** resets the BLoC, switches Flame back to strike world, refreshes stats, and returns to lobby
- **EXIT TO LOBBY** calls the hub exit callback

## Rewards And Progression

Super Over awards XP once, when the over ends.

XP formula:

| Component | XP |
|-----------|----|
| Completion | +10 |
| Runs | +1 per run |
| Sixes | +4 per six |
| Chase win | +15 |

Example: a 17-run winning chase with two sixes awards `10 + 17 + 8 + 15 = 50 XP`.

The screen dispatches `SuperOverFinished` to `GameBloc` with runs, wickets, chase result, and calculated XP.

## Persistence And History

`SuperOverStats` persists:

- high score
- chase wins
- chase losses
- total sixes
- total runs
- current chase streak
- best chase streak

Stats are saved through `SecureGameStorage` when the over ends.

The lobby's Match History button reads shared match history entries filtered to `mode == 'super_over'`. XP is dispatched to the shared progression system through `GameBloc`.

## Current Product Notes

- The current user-facing mode is chase-only.
- Score Attack exists in the domain model but is not exposed from the lobby.
- The mode is XP-only; no coin payout is currently defined.
- In-progress overs are not persisted if the user exits mid-over.
- The BLoC persists Super Over lifetime stats independently of the shared match-history archive.

## Implementation Reference

| Concern | Source |
|---------|--------|
| Domain enums, shot resolution, timing windows | [`lib/models/super_over.dart`](../../lib/models/super_over.dart) |
| Persisted Super Over stats | [`lib/models/super_over_stats.dart`](../../lib/models/super_over_stats.dart) |
| Super Over state fields | [`lib/blocs/super_over/super_over_state.dart`](../../lib/blocs/super_over/super_over_state.dart) |
| Events and BLoC resolution/persistence | [`lib/blocs/super_over/super_over_bloc.dart`](../../lib/blocs/super_over/super_over_bloc.dart) |
| Hub, routing, XP dispatch, Flame bridge | [`lib/screens/super_over/super_over_hub.dart`](../../lib/screens/super_over/super_over_hub.dart) |
| Lobby UI | [`lib/screens/super_over/super_over_lobby_screen.dart`](../../lib/screens/super_over/super_over_lobby_screen.dart) |
| Live HUD and shot meter | [`lib/screens/super_over/widgets/super_over_overlays.dart`](../../lib/screens/super_over/widgets/super_over_overlays.dart) |
| Effects overlay | [`lib/screens/super_over/widgets/effects_overlay.dart`](../../lib/screens/super_over/widgets/effects_overlay.dart) |
| Result overlay | [`lib/screens/super_over/widgets/super_over_result.dart`](../../lib/screens/super_over/widgets/super_over_result.dart) |
| Flame game shell | [`lib/games/super_over/super_over_game.dart`](../../lib/games/super_over/super_over_game.dart) |
| Strike-world delivery renderer | [`lib/games/super_over/strike_world.dart`](../../lib/games/super_over/strike_world.dart) |
| Ground-world shot renderer | [`lib/games/super_over/ground_world.dart`](../../lib/games/super_over/ground_world.dart) |
| XP dispatch handler | [`lib/blocs/game/game_bloc.dart`](../../lib/blocs/game/game_bloc.dart) |

Relevant tests:

- [`test/super_over_bloc_test.dart`](../../test/super_over_bloc_test.dart)
- [`test/super_over_resolution_test.dart`](../../test/super_over_resolution_test.dart)
- [`test/super_over_lobby_screen_test.dart`](../../test/super_over_lobby_screen_test.dart)
