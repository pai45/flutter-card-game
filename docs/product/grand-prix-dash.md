# Grand Prix Dash

Grand Prix Dash is StatOz's one-lap top-down F1-style arcade racer. The user chooses a circuit and livery, launches from the grid, races through a 20-car field, manages speed through corners, uses slipstream on straights, and earns XP based on finishing position.

## Product Purpose

Grand Prix Dash gives the F1 section a skill-first game mode with instant readability and repeat-session mastery.

It is intentionally deck-free:

- no starter-pack gate
- no squad or card requirements
- car livery is cosmetic
- player level affects CPU strength rather than user equipment

The mode creates progression through local racing stats, circuit personal bests, and shared XP rewards. It does not award coins.

## Where It Lives

Grand Prix Dash is opened from the **Games** tab's F1 section.

The app-level entry pushes `GrandPrixTabContent`, which creates `GrandPrixCubit`, loads persisted stats, and shows the lobby. The race itself is pushed as a route so the lobby Cubit survives across race attempts.

## Entry Requirements

Grand Prix Dash has no deck requirement and no starter-pack gate.

The user can start immediately once the lobby stats have loaded. The current player level is read when a race is built so CPU smartness can scale with progression.

## End-To-End User Flow

1. User opens **Games -> F1 -> Grand Prix Dash**.
2. Lobby loads persisted racing stats.
3. User chooses a circuit and team livery, or keeps the last-used choices.
4. User taps **START RACE**.
5. Cubit builds a seeded race setup with player level, selected circuit, selected livery, random start position, and random simulation seed.
6. Race screen opens on the grid.
7. After a short staging beat, the five-lights start sequence begins.
8. User holds **ACCEL** after lights out to grade launch reaction.
9. Race begins; Flame advances the pure engine at fixed substeps.
10. User holds steering, throttle, and brake controls to complete the lap.
11. HUD updates speed, lap progress, position, slipstream, stuck warnings, and overtake toasts.
12. When the player crosses the line or retires, the Cubit records result and stats.
13. Race screen dispatches shared XP once through `GameBloc`.
14. Result overlay shows verdict, position, lap time, launch, MVP move, XP, and CTAs.
15. User chooses **RACE AGAIN** or **EXIT**.

Leaving during grid, lights, or racing abandons the attempt. Abandoned races do not save stats and do not award XP.

## Race Format

| Rule | Value |
|------|-------|
| Race length | 1 lap |
| Field size | 20 cars |
| Player start slot | Random P8-P16 |
| Camera | Top-down pseudo-scroller |
| Physics model | 1D lap distance plus lateral offset |
| Controls | Left, right, brake, accelerate |
| Finish state | Classified position or DNF |
| Reward type | XP only |

## Circuits

Grand Prix Dash ships with five generic circuit archetypes:

| Circuit | Character | Difficulty | Product Behavior |
|---------|-----------|------------|------------------|
| Harbour Street | Street | 4 stars | Slow corners, punishing walls, hard passing |
| Desert Mile | Speedway | 2 stars | Long straights, heavy slipstream, many overtakes |
| Emerald Park | Balanced | 3 stars | Classic mix of straights and corners |
| Mountain Pass | Technical | 4 stars | Chicanes and braking precision |
| Coastal Sprint | Flowing | 3 stars | Fast sweepers and one major stop |

Each circuit is a list of straights, corners, and chicanes. Sections define length, corner direction, safe speed, wall threshold, and visual bend. The engine uses safe speed and section type for physics; the renderer uses bend to draw the road.

## Livery Selection

The lobby offers six cosmetic liveries:

- Scarlet
- Silver Arrow
- Papaya
- Midnight
- Racing Green
- Sky Blue

Each livery has a primary body color and accent color. These are content colors for cars only; surrounding UI uses shared Cyber tokens.

The selected circuit and livery are persisted as part of `GrandPrixStats`, so returning users can immediately start with their last setup.

## Start And Launch Mechanics

A race begins in the `grid` phase. After the race screen mounts, it waits about 1.2s, then begins the lights sequence.

### Five-Lights Sequence

Without reduced motion:

- lamps 1 through 5 light at one-second intervals
- after all five are lit, lights-out waits a random hold between 200ms and 1500ms
- if the user presses throttle before lights out, the launch is a jump start
- if the user does not press throttle for 2 seconds after lights out, the launch is slow

With reduced motion enabled:

- the reaction test is skipped
- the race starts with a fixed `good` launch

### Launch Grades

| Reaction Time | Grade |
|---------------|-------|
| `< 150ms` | Perfect |
| `< 300ms` | Great |
| `< 500ms` | Good |
| otherwise | Slow |
| throttle before lights out | Jump |

### Launch Boosts

| Grade | Initial Speed | Acceleration Factor | Boost Duration |
|-------|---------------|---------------------|----------------|
| Perfect | 14 m/s | 1.50x | 3.0s |
| Great | 10 m/s | 1.35x | 2.5s |
| Good | 7 m/s | 1.20x | 2.0s |
| Slow | 2 m/s | 1.00x | 0s |
| Jump | 0 m/s | 1.00x | 0s plus throttle cut |

A jump start applies a two-second throttle cut.

## Driving Mechanics

The simulation tracks each car as:

- distance along the lap
- lateral offset from road center
- speed
- current section
- racing/spinning/finished state
- launch timers
- slipstream state

### Speed And Control

Core tuning:

| Parameter | Value |
|-----------|-------|
| Top speed | 88 m/s |
| Acceleration | 26 m/s^2 |
| Coasting deceleration | 10 m/s^2 |
| Brake deceleration | 44 m/s^2 |
| Steering rate | 7.5 lateral m/s |

Holding throttle accelerates toward effective top speed. Holding brake sharply reduces speed. Steering moves the car laterally while the circuit bend shifts the road centerline under the car, requiring the user to steer into corners.

### Corners

Corners and chicanes define a safe speed. If the car enters above safe speed, excess speed is scrubbed over time. Overspeed does not directly throw the car sideways; loss of control happens when the car is steered or drifted into grass or wall.

### Grass And Walls

The drivable asphalt has a half-width of 4.5m. The wall clamp is at 6.5m.

When off asphalt:

- top speed is reduced to 55%
- direct grass drag is applied
- the car can bog down and become stuck

When contacting the wall:

- speed is scrubbed
- in corners, a fresh high-speed wall hit can trigger a spin
- spin lasts 0.8s and clamps speed to a crawl multiplier

### Stuck And Retirement

If the player's speed stays below 14 m/s for 10 seconds, the race ends as a DNF. The HUD warns after the player has been stuck for 2.5s and counts down to retirement.

### Slipstream

Slipstream is available on straights when another car is:

- 4m to 28m ahead
- laterally aligned within 1.8m

Slipstream increases effective top speed by 8%. The HUD displays a `TOW` chip while active.

### Contact

Contact is a downside, not an attack weapon.

When cars overlap longitudinally and laterally:

- rear car loses speed
- front car loses some speed
- both cars are nudged apart laterally
- heavy closing speed can spin the rear car
- player contact spawns amber sparks when reduced motion is off

CPU-to-CPU contact is softened to avoid slow trains.

## CPU Opponent Behavior

CPU field strength scales with player level:

```dart
cpuSmartness(level) = min(1.0, level / 12)
```

Each CPU also receives seeded variation:

- strength spread
- pace jitter
- corner-entry noise

CPU drivers:

- launch from sampled reaction times
- brake for upcoming corners using stopping distance
- use racing-line lateral targets
- steer to avoid slower cars ahead
- attempt passes on straights
- sometimes defend against attackers behind

Weaker CPUs brake later and enter corners hotter. Stronger CPUs launch better, brake more accurately, and defend more often.

## Screens And UI

### 1. Grand Prix Lobby

The lobby is a cyber-styled full-screen route with a constrained 420px content column.

Primary UI:

- `ReactHeaderBar` with title context and player level badge
- **PIT LANE OPEN** status strip
- animated racing emblem
- title `GRAND PRIX DASH`
- subtitle `ONE LAP / 20 CARS / LIGHTS OUT`
- record chip showing rookie season, races in, or race wins
- record panel with races, wins, podiums, best position, and current streak
- horizontal circuit picker
- livery swatches
- **START RACE** CTA

Animation and feedback:

- animated Cyber background
- staggered slide/fade content entrance
- racing emblem spins and pulses with magenta glow
- selected livery animates border state
- circuit selection and livery taps trigger haptic selection and UI tap sound
- start race uses play-match sound

Working behavior:

- stats load asynchronously; loading state shows a cyan progress indicator
- circuit picker opens near the last selected circuit
- circuit cards show character, difficulty stars, and personal best lap
- livery picker persists selection immediately
- start builds a fresh `RaceSetup` and pushes `GrandPrixRaceScreen`

### 2. Race Screen: Grid Phase

The race screen is a full-bleed Flame scroller with Flutter HUD layers.

During grid phase:

- cars sit in staggered two-wide grid slots behind the start line
- top HUD is already visible
- lights rig shows five unlit lamps and `ON THE GRID`
- controls are visible
- race simulation is not yet running

After about 1.2s, the Cubit starts lights.

### 3. Race Screen: Lights Phase

The lights rig displays five circular lamps.

UI states:

- lamps turn red one by one
- message reads `WAIT FOR LIGHTS OUT...`
- when lights go out, lamps clear and message reads `GO GO GO!`

Working behavior:

- pressing **ACCEL** before lights out immediately grades `jump`
- pressing **ACCEL** after lights out grades reaction
- no press within 2 seconds grades `slow`
- phase changes to `racing`

Animation and feedback:

- lamps use animated fill/border/glow
- launch grade flash animates after race start
- race-start sound and haptics fire when racing begins

### 4. Race Screen: Racing Phase

Top HUD:

- close button
- current player position, e.g. `P7/20`
- live speed in KPH
- lap progress bar
- `TOW` chip while slipstreaming

Controls:

- left and right hold pads
- **BRAKE** hold pad
- **ACCEL** hold pad
- raw pointer listeners support multi-touch, so steering and throttle can be held together
- pressed controls fill with accent color instead of glowing

Track renderer:

- grass corridor
- asphalt band
- walls
- cyan edge lines
- center dashes every 12m
- red/white kerbs on corner sections
- amber braking boards 60m and 110m before braking zones
- checker start/finish line

Car renderer:

- top-down F1 silhouettes with wheels, wings, body, cockpit, and livery colors
- player car has accent glow
- spinning cars show danger ring

Live events:

- overtake toast appears near top when the player passes a car
- wall contact spawns red sparks
- car contact spawns amber sparks
- stuck warning appears after 2.5s below stuck speed

Working behavior:

- the Flame game advances the pure engine at 1/120s fixed substeps
- high-frequency HUD values read from `ValueNotifier`s, not BLoC emissions
- Cubit only receives coarse changes: position changes, overtakes, finish, and retirement

### 5. Race Finish Beat

When the player crosses the line:

- Flame stops running the simulation
- Cubit records result and lifetime stats
- race screen dispatches `GrandPrixFinished` once
- win/podium can play match-win sound; lower finishes use banner-slam style feedback
- after about 900ms, Cubit moves from `finished` to `result`

When the player is stuck too long:

- race ends as DNF
- position is classified as P20
- lap time is 0
- personal best cannot be set
- result overlay displays retired state

### 6. Result Overlay

The result overlay is a full-screen cinematic over the race screen.

Content sequence:

1. verdict banner: **WIN**, **PODIUM**, **POINTS**, **FINISHED**, or **RETIRED**
2. circuit name
3. giant finishing position or DNF
4. places gained/lost from grid slot
5. race stat panel with lap time, PB chip, launch grade, and MVP move when available
6. XP count-up and level-progress bar
7. persistent bottom dock with **EXIT** and **RACE AGAIN**

Animation and feedback:

- single 2.4s sequence controller stages banner, position, stat rows, and XP panel
- position uses ease-out-back scale
- XP count rises with sequence progress
- if animations are disabled, sequence jumps to final state
- after sequence completion, shared level-up celebration appears if pending

Working behavior:

- **EXIT** pops the race route
- **RACE AGAIN** pops the current race route and immediately builds a new race from lobby state
- result overlay reads `GameBloc` progression after XP dispatch

## Rewards And Progression

Grand Prix Dash awards XP only. It never subtracts XP and never pays coins.

| Finish Position | XP |
|-----------------|----|
| P1 | +26 |
| P2 | +22 |
| P3 | +18 |
| P4-P6 | +12 |
| P7-P10 | +8 |
| P11-P20 | +4 |

Personal best bonus:

| Condition | XP |
|-----------|----|
| New circuit personal best | +3 |

The race screen dispatches `GrandPrixFinished` with position, field size, circuit name, lap time, verdict label, and XP.

## Persistence

`GrandPrixStats` persists:

- races
- wins
- podiums
- best finishing position
- current win streak
- best win streak
- best lap per circuit
- last selected circuit
- last selected livery

Stats are saved through `SecureGameStorage`.

Personal bests are tracked per circuit by `GrandPrixCircuitId.name`. A DNF has no lap time and does not set a personal best.

## Current Product Notes

- Grand Prix Dash is deck-free and cosmetic-livery-only.
- The mode is XP-only; no coin payout is defined.
- In-progress races are discarded on exit.
- The result records local racing stats and shared XP, but no separate race-history archive is currently documented.
- Reduced-motion users bypass the reaction test and receive a good launch.

## Implementation Reference

| Concern | Source |
|---------|--------|
| Domain enums, circuits, results, persisted stats | [`lib/models/grand_prix.dart`](../../lib/models/grand_prix.dart) |
| Circuit catalog | [`lib/data/grand_prix_circuits.dart`](../../lib/data/grand_prix_circuits.dart) |
| Livery catalog | [`lib/data/grand_prix_liveries.dart`](../../lib/data/grand_prix_liveries.dart) |
| CPU driver name generation | [`lib/data/grand_prix_drivers.dart`](../../lib/data/grand_prix_drivers.dart) |
| Pure race engine and physics | [`lib/games/grand_prix/grand_prix_engine.dart`](../../lib/games/grand_prix/grand_prix_engine.dart) |
| Flame renderer and live loop | [`lib/games/grand_prix/grand_prix_game.dart`](../../lib/games/grand_prix/grand_prix_game.dart) |
| Cubit lifecycle and persistence | [`lib/blocs/grand_prix/grand_prix_cubit.dart`](../../lib/blocs/grand_prix/grand_prix_cubit.dart) |
| Grand Prix state | [`lib/blocs/grand_prix/grand_prix_state.dart`](../../lib/blocs/grand_prix/grand_prix_state.dart) |
| Hub/tab entry | [`lib/screens/grand_prix/grand_prix_hub.dart`](../../lib/screens/grand_prix/grand_prix_hub.dart) |
| Lobby UI | [`lib/screens/grand_prix/grand_prix_lobby_screen.dart`](../../lib/screens/grand_prix/grand_prix_lobby_screen.dart) |
| Race screen, lights, HUD, finish bridge | [`lib/screens/grand_prix/grand_prix_race_screen.dart`](../../lib/screens/grand_prix/grand_prix_race_screen.dart) |
| Control pad | [`lib/screens/grand_prix/widgets/grand_prix_controls.dart`](../../lib/screens/grand_prix/widgets/grand_prix_controls.dart) |
| Result overlay | [`lib/screens/grand_prix/widgets/grand_prix_result.dart`](../../lib/screens/grand_prix/widgets/grand_prix_result.dart) |
| XP formula | [`lib/models/progression.dart`](../../lib/models/progression.dart) |

Relevant tests:

- [`test/grand_prix_engine_test.dart`](../../test/grand_prix_engine_test.dart)
- [`test/grand_prix_cubit_test.dart`](../../test/grand_prix_cubit_test.dart)
- [`test/grand_prix_stats_test.dart`](../../test/grand_prix_stats_test.dart)
- [`test/progression_economy_test.dart`](../../test/progression_economy_test.dart)
