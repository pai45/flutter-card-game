# Grand Prix Dash

> **Status:** BUILT
> **Last verified:** 2026-10-04
> **Scope:** Racing starter pack, pit deck, five circuits, driving, race presentation, mastery, rewards, and career

## Product Purpose

Grand Prix Dash is a top-down F1-style arcade racer: launch into a 20-car field,
brake and steer through bends, build a tow, then spend ERS energy to attack.
Circuit personal bests, three mastery stamps per circuit, and shared Grand Prix
XP give players reasons to improve and race again.

## Where It Lives

**Sports → GAMES → F1 → Grand Prix Dash** opens the racing hub. The shared
sport/game unlock rules still apply. First entry uses the racing starter pack;
the Pit Deck must equip an owned driver and owned livery before START RACE.
Grid Line is the free default livery; six other liveries are cosmetic unlocks.
Driver ownership remains an entry requirement; driving performance is not
calculated from driver-card stats. CPU difficulty follows Grand Prix track level.

The lobby retains the circuit picker, 1/3/5-lap distance picker, START RACE,
Pit Deck, Match History/career, and game leaderboard entry. A mastery panel
shows earned stamps and the next unearned goal for the selected circuit.
The same car painter supplies racing cars and livery previews.

## Player Flow

1. Claim the racing starter pack if needed and equip the Pit Deck.
2. Pick a circuit and 1, 3, or 5 laps. Last selections persist.
3. START RACE seeds a fresh 20-car grid; the player starts randomly at P8–P16.
4. First race shows a dismissible coach covering steering, lights, braking,
   tow and ERS. The saved coach acknowledgement skips it on later races.
5. After about 1.2 seconds of staging, five lamps illuminate one second apart.
   Following a random 200–1500 ms hold, they go dark.
6. Hold ACCEL after lights-out to earn a launch grade. An early press gets a
   jump-start penalty; no press within two seconds gives a slow launch.
7. Race with analogue steering, throttle/brake and ERS. Follow braking cues,
   manage grip, carry speed through clean exits and pass rivals.
8. Pause explicitly or by backgrounding/focus loss. Resume uses a 3–2–1
   countdown; platform reduced motion resumes immediately.
9. Cross the final line or retire. The race settles shared XP exactly once.
10. The result reveal shows position, places gained, race time/PB, best lap
    split, clean passes, launch, MVP pass, new mastery stamps and XP.
    RACE AGAIN returns to a new seeded attempt; EXIT returns to the lobby.

Leaving an unfinished race, including from pause, abandons it without race
stats or XP. In-progress racing is session-only and does not survive app restart.

## Mechanics and Rules

| Rule | Behavior |
|---|---|
| Field | 20 cars; random player grid slot P8–P16 |
| Distance | Lobby offers 1, 3, or 5 laps |
| Simulation | Deterministic seeded engine at 120 Hz; render interpolation |
| Camera | Top-down scrolling ribbon, anchored to the centreline under the player |
| Controls | Drag steering pad + hold BRAKE, ACCEL and ERS; optional classic left/right pads |
| Keyboard | Arrows or WASD; Space deploys ERS; Escape pauses |
| Speed | Base maximum 88 m/s, about 317 KPH; tow/ERS can exceed it |
| Acceleration / brake / coast | 26 / 44 / 10 m/s² before contextual modifiers |
| Track / wall | Asphalt half-width 4.5 m; walls at ±6.5 m |
| Car footprint | 25% smaller on both axes: 1.5 m wide, 4.125 m long contact footprint |
| Stuck | Below 14 m/s for 10 seconds retires the player |
| Recovery | Available after 2.5 stuck seconds; stationary for 3 seconds |
| Result | Classified finish or P20 DNF; a DNF has no PB |

### Launch

| Grade | Reaction | Initial speed | Acceleration boost |
|---|---|---|---|
| Perfect | <150 ms | 14 m/s | ×1.50 for 3 s |
| Great | <300 ms | 10 m/s | ×1.35 for 2.5 s |
| Good | <500 ms | 7 m/s | ×1.20 for 2 s |
| Slow | Otherwise | 2 m/s | None |
| Jump | Before lights-out | 0 | Two-second throttle cut |

Platform reduced motion bypasses the reaction test and supplies a Good launch.
Pausing during the grid/lights sequence cancels its timers and restarts the
start sequence on resume. Pausing an active race retains its field and launch;
resume never reapplies the launch boost.

### Handling, grip and recovery

Steering angle eases toward the input. Lateral velocity follows steering,
speed and grip, and heading/yaw follow the movement. Faster cars have less
steering authority; braking/coasting slightly improve rotation. Stationary
cars cannot strafe. Kerbs and grass reduce grip; grass also adds drag.
On straights, lateral movement scales with forward speed for both the player
and rivals, avoiding abrupt sideways movement while pulling away or braking.

Curvature requires steering into a bend. The same cached geometry drives the
engine, road, camera, route ribbon, rubber racing line and CPU line targets.
Overspeed lowers grip and scrubs speed without an instant sideways shove or
an automatic spin. Spins come from heavy contact or a fast corner wall impact.
The camera centreline anchor does not lag through corners.

Contact slows both cars and separates them; a third car in another lane cannot
hide an overlapping contact. Recovery preserves distance and energy, costs
three seconds while rivals continue, clears launch bonuses, and invalidates
a clean finish. It selects a clear rejoin lane and supplies one second of
collision clearance. It never advances the player along the track.

### Tow and ERS

An aligned rival 4–28 m ahead on a straight builds tow gradually. Alignment
must be within 1.8 m; tow fades after pulling out and grants up to 8% top speed.

Hold ERS while accelerating above 15 m/s on asphalt, with no braking or spin,
to deploy. Energy drains at 23% per second; deployment adds up to 8% top speed
and ×1.25 acceleration. Above 12 m/s on asphalt, braking recharges at 12% per
second of brake input and lifting adds 2.5% per second. Standing still cannot
farm energy. The HUD shows charge, deployment and tow strength.

### Rivals and timing

CPU rivals receive seeded patient, balanced or aggressive racecraft, varied
pace and corner entry, braking lookahead, shared racing-line targets, passing
lane clearance and occasional defence. They hold their grid/exit lane on
straights, make gradual speed-dependent lane changes to pass, retain the new
lane after a pass and ease toward the racing line near a bend. Defence requires
a genuinely closing attacker; longer decision cooldowns prevent continual
lane switching. Rivals also manage ERS.
Traffic braking lookahead includes closing speed and following clearance so
stationary/jump-starting cars do not cause unnecessary contact spins on launch.

The HUD shows position, KPH, gear, current lap/progress, energy, tow/clean
passes, grip warnings and a nearest-ahead rival gap marked **EST.** The compact
left card omits direction arrows, corner distance and suggested speed; braking
boards and the road itself communicate the approaching bend. The gap is a distance/speed
estimate, not a timing-line measurement. The small **ROUTE** display is a
schematic of the actual scrolling ribbon, not a closed real-world circuit map.

Lap splits are recorded at interpolated crossings; the first split includes
travel from the starting grid. Intermediate laps and improved splits trigger
feedback. A clean pass requires staying ahead for one second with no recent
contact; each distinct rival counts once per race. Clean corner exits trigger
a short line-held moment. These actions do not award extra XP.

## Circuits and Presentation

| Circuit | Driving character | Trackside environment |
|---|---|---|
| Harbour Street | Slow corners, tight passing | Buildings, lit windows, lamps and waterfront |
| Desert Mile | Long straights, tow battles | Dunes, rocks and track gantries |
| Emerald Park | Balanced straights and bends | Trees, grass and grandstands |
| Mountain Pass | Technical braking and chicanes | Rock faces and retaining barriers |
| Coastal Sprint | Fast sweepers and a major stop | Palms, cliffs, shoreline and boats |

The procedural renderer uses theme tokens and cached scenery pictures.
All race cars and shared livery previews render at 75% of their previous width
and height, preserving their proportions. Contact dimensions and passing
clearance match the smaller cars; grid spacing and the road stay wide enough
for close racing. Traffic retains safe closing-speed braking clearance.
Player glow, spin rings, tyre marks, smoke, sparks and ERS/tow trails scale
with the car. HUD typography and control touch targets retain their readable
sizes, while the smaller field leaves more visible racing space.
Textured asphalt, rubber line, kerbs, braking boards and checker markings
remain anchored in track space. Cars turn with track tangent and heading;
front wheels steer, body highlights define the shape, and ERS/braking have
distinct visual signals. Bounded tyre marks, smoke, sparks and speed streaks
respond to braking, grip, spins, impacts, tow and deployment. A subtle speed
zoom expands lookahead; contact shake is brief and impact-only.
The wide-lane scroller projection limits ordinary straight-line body tilt to
12 degrees so lane changes do not make cars look sideways; bends permit a
larger heading and genuine contact spins keep their separate animation.

## Rewards and Progression

Grand Prix awards Grand Prix-track XP only. It never subtracts XP and never
awards coins for race completion or circuit mastery.

| Finish | Base XP |
|---|---|
| P1 | 26 |
| P2 | 22 |
| P3 | 18 |
| P4–P6 | 12 |
| P7–P10 | 8 |
| P11–P20, including retirement | 4 |

Distance multiplies finish XP by ×1 / ×2 / ×3 for 1 / 3 / 5 laps. A new
current-ruleset circuit/distance PB adds 3 XP after that multiplier.
Shared history, quests, achievements and level progression keep their
existing settlement path. Duplicate finish callbacks cannot settle twice.

Three persistent mastery stamps are available **per circuit**, across distances:

- **CLEAN FINISH:** finish without car/wall contact or recovery.
- **RACECRAFT:** finish with at least three distinct clean passes.
- **PODIUM:** finish in the top three.

New stamps appear once in the existing result sequence. Repeats retain the
stamp without another reveal. Retirement earns no stamps. Mastery is a
skill goal, without a new currency, card-stat bonus or XP payout.

## Gratification and Feedback

The five-light start, graded launch flash, overtake audio, clean-pass/clean-exit
moments, lap beats, finish stinger and staged 2.4-second result reveal provide
the payoff arc. The result reuses the XP count-up, quest receipt, level bar
and shared level-up celebration. Standard HUD panels stay calm; player/live
signals and primary CTAs carry the scarce glow.

Race audio layers original engine low/high bands, wind and tyre scrub using
RPM, load, speed and grip. Engine bands crossfade without relying on platform
pitch shifting. The shared controller owns global mute and lifecycle behavior;
route ownership prevents a disposed race from stopping its retry's audio.
Pause stops racing layers; resume restarts them. Audio assets are generated
selectively and listed in the audio catalogue/manifest.

Pause exposes saved classic-controls, haptics and reduced-effects preferences
alongside shared mute. Reduced effects/platform reduced motion suppress
particles, marks, shake and speed zoom. Platform reduced motion also bypasses
start reaction and resume countdown and skips the animated result sequence.
Position, warning text, energy, cues and results remain readable.

## Visible States

Loading and Pit Deck gate; circuit/distance/mastery lobby; first-race coach;
grid/lights; launch; racing/tow/deploy/grip/contact; lap/clean-action moments;
stuck/recovering/rejoin; paused/resume countdown; finish/DNF; result/PB/new
mastery; career/history.

## Persistence

`GrandPrixStats` saves races, wins, podiums, best position, win streaks,
personal bests, last circuit/livery/distance, per-circuit mastery, control
layout, haptics, reduced effects and coach acknowledgement through
`SecureGameStorage`. Saves are ordered so a slow preference write cannot
overwrite a more recent finish.

Ruleset **v2** uses separate PB keys, e.g. `v2:emeraldPark` and
`v2:emeraldPark@3L`. Older unprefixed records remain stored/readable through
the legacy lookup; career totals and equipped livery are preserved. Current
HUD/lobby PB competition uses v2 only because handling changed. Existing
shared match history remains readable. No unfinished race is persisted.

## Planned Scope and Current Limitations

- **BUILT:** Five local circuits, 1/3/5 laps, 20 seeded rivals, refined top-down
  handling, ERS/tow, coach/pause/recovery, original scenery/effects/audio,
  circuit mastery and versioned PBs.
- **PROTOTYPE:** Competition and the existing leaderboard roster are local.
- **PLANNED:** Online races/server competition remain future scope.
- This is a scrolling arcade racer, not a full 3D or wheel-physics simulation.
  Frame-rate equivalence is verified in the pure engine; sustained mobile GPU
  performance and subjective speaker/haptic feel still need device playtesting.

## Implementation References

- [Domain and records](../../../lib/models/grand_prix.dart), [circuits](../../../lib/data/grand_prix_circuits.dart)
- [Engine](../../../lib/games/grand_prix/grand_prix_engine.dart), [shared geometry](../../../lib/games/grand_prix/grand_prix_track.dart), [fixed clock](../../../lib/games/grand_prix/grand_prix_simulation_clock.dart)
- [Renderer](../../../lib/games/grand_prix/grand_prix_game.dart), [scenery](../../../lib/games/grand_prix/grand_prix_scenery.dart), [car painter](../../../lib/games/grand_prix/grand_prix_car_painter.dart)
- [Shared car scale and contact dimensions](../../../lib/games/grand_prix/grand_prix_car_dimensions.dart)
- [Cubit](../../../lib/blocs/grand_prix/grand_prix_cubit.dart), [lobby](../../../lib/screens/grand_prix/grand_prix_lobby_screen.dart), [race screen](../../../lib/screens/grand_prix/grand_prix_race_screen.dart)
- [HUD](../../../lib/screens/grand_prix/widgets/grand_prix_driving_hud.dart), [controls](../../../lib/screens/grand_prix/widgets/grand_prix_controls.dart), [feedback/pause](../../../lib/screens/grand_prix/widgets/grand_prix_race_feedback.dart), [result](../../../lib/screens/grand_prix/widgets/grand_prix_result.dart)
- [Audio](../../../lib/utils/sound_effects.dart), [audio generator](../../../tool/audio/build_audio.py), [asset catalogue](../../audio/CUE_CATALOG.md)
- [Production-screen preview](../../../tool/grand_prix_preview.dart)

## Tests

- [Engine regressions](../../../test/grand_prix_engine_test.dart)
- [Refinement, frame rates, recovery and 15 circuit/distance combinations](../../../test/grand_prix_refinement_test.dart)
- [Three-pointer controls](../../../test/grand_prix_controls_test.dart)
- [Keyboard, small-screen HUD and accessible pause/results](../../../test/grand_prix_presentation_test.dart)
- [Pause, settlement and mastery](../../../test/grand_prix_cubit_test.dart)
- [Migration and preferences](../../../test/grand_prix_stats_test.dart)
- [Audio ownership/lifecycle](../../../test/audio_controller_test.dart), [audio mappings](../../../test/game_audio_mappings_test.dart)
- [Economy](../../../test/progression_economy_test.dart)
- Existing Grand Prix starter-pack, Pit Deck, livery shop and selector tests
