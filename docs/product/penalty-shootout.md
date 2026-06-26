# Penalty Shootout

Penalty Shootout is StatOz's standalone spot-kick game mode. It gives users a faster football game loop than a full Pitch Duel match: use the active squad, trade penalties with a CPU opponent, and earn smaller XP and coin rewards from the result.

## Product Purpose

Penalty Shootout gives the Games tab a quick-session mode that still makes the user's squad, player ratings, progression, match history, wallet, and streak systems matter.

It is separate from the four-round Pitch Duel card match. It shares Pitch Duel's squad/deck setup and progression economy, but it has its own lobby, opponent reveal, kick loop, result summary, match-history entries, and streak category.

## Where It Lives

Penalty Shootout is opened from the **GAMES** tab in the Predict area.

The Games tab currently offers:

- **Pitch Duel**: the four-round tactical card game.
- **Penalty Shootout**: standalone spot kicks.
- **Football Quiz**: trivia gauntlet.

Opening Penalty Shootout launches a full-screen shootout hub. From there, users can play a shootout, open the shared Deck Builder, or view Match History.

## Entry Requirements

Penalty Shootout reuses Pitch Duel's active deck readiness gate. The deck must be complete and owned before the lobby enables **PLAY SHOOTOUT**:

- 2 attackers
- 2 defenders
- 1 goalkeeper
- 6 action cards

The action-card portion of the deck is not used during penalties. The actual shootout takers are the five players: two attackers, two defenders, and the goalkeeper.

## User Flow

1. User opens **Predict -> Games -> Penalty Shootout**.
2. Lobby shows level, total XP, shootout wins, squad readiness, Deck Builder, and Match History.
3. User taps **PLAY SHOOTOUT**.
4. Opponent reveal searches the global penalty queue and introduces the CPU rival.
5. Lineup phase shows both five-player squads.
6. Kick loop alternates between choosing a shot direction and choosing a dive direction.
7. Each kick resolves into a goal or save with a short result beat and kick-history row.
8. When the shootout is decided, the user continues to the summary.
9. Summary shows win/loss, penalty scoreline, XP progress, kick log, **PLAY AGAIN**, and **HOME**.

Quitting during an active shootout asks for confirmation because current shootout progress is discarded.

## Squad And Opponent Rules

The user's five takers are built from the active squad in this order:

1. attacker 1
2. attacker 2
3. defender 1
4. defender 2
5. goalkeeper

The CPU opponent is generated at the user's current level. It receives the same five-player structure: two attackers, two defenders, and one goalkeeper. CPU players are picked near the level-scaled target rating:

```dart
targetRatingForLevel(level) = min(95, 66 + level * 2)
```

The goalkeeper also takes the fifth kick. If the shootout reaches sudden death and the lineup runs past five kicks per side, the same order cycles again.

## Shootout Format

Penalty Shootout uses a five-kicks-each format:

- The player takes the first kick.
- Player kicks happen on even-numbered internal rounds.
- CPU kicks happen on odd-numbered internal rounds.
- Each side can take up to five regulation kicks.
- The shootout can end early when one side can no longer catch up.
- If scores are tied after five kicks each, the mode enters sudden death.
- Sudden death resolves in pairs: one player kick and one CPU kick.
- A shootout never ends in a draw.

Example: if the player leads 3-0 after the CPU has only two kicks left, the shootout ends immediately. If both sides score all five regulation kicks, the next player/CPU pair decides the winner as soon as one side scores and the other does not.

## Direction Mechanics

Every kick uses three directions:

- left
- center
- right

When the user is shooting, the user chooses the shot direction and the CPU keeper chooses a dive. When the CPU is shooting, the CPU chooses the shot direction and the user chooses the dive.

Each resolved kick records:

- kick number
- whether the player or CPU took the kick
- shot direction
- dive direction
- scored or saved result
- shooter
- keeper

The result table always places the user on the left and the opponent on the right, regardless of which side took the kick.

## Scoring Odds

Penalty scoring is rating-influenced, not a pure direction match.

If the keeper dives the wrong way, the shot has a **95%** goal chance. If the keeper guesses the correct direction, the chance is based on the shooter rating minus keeper rating:

| Rating gap | Goal chance |
|------------|-------------|
| `diff > 15` | 45% |
| `diff > 5` | 35% |
| `diff > -5` | 25% |
| `diff > -15` | 15% |
| otherwise | 8% |

This keeps direction choice highly important while still letting strong keepers and strong takers matter.

## CPU Behavior

CPU smartness scales with player level:

```dart
cpuSmartness(level) = min(1.0, level / 12)
```

For each CPU direction choice, the CPU has a read chance:

```dart
readChance = 0.25 + 0.35 * cpuSmartness(level)
```

When the CPU reads the user and has a clear pattern:

- as keeper, it dives toward the user's most frequent shot direction so far
- as shooter, it aims away from the user's most frequent dive direction so far

If there is no prior data or the pattern is tied, the CPU chooses randomly.

## Rewards And Progression

Penalty Shootout has smaller stakes than a full Pitch Duel match.

XP rewards:

| Result | XP |
|--------|----|
| Win by 1 | +8 |
| Win by 2 | +10 |
| Win by 3+ | +12 |
| Loss | 0 |

Coin rewards:

| Result | Coins |
|--------|-------|
| Win | 20 |
| Loss | 5 |

Shootout losses do not subtract XP. The summary still shows the XP panel and level progress after rewards are applied.

## Persistence And History

When a shootout finishes, the game records:

- a `shootout` match-history entry
- deck name
- timestamp
- victory or defeat
- player and CPU penalty score
- XP earned
- XP ledger entry with source `shootout`
- coin ledger entry with source `shootoutReward`
- penalty shootout streak activity

Match History identifies standalone shootouts separately from Pitch Duel matches. The shootout lobby's win count reads from history entries where `mode == 'shootout'` and the player score is higher than the opponent score.

## Implementation Reference

| Concern | Source |
|---------|--------|
| Shootout state machine and resolution | [`lib/blocs/shootout/shootout_bloc.dart`](../../lib/blocs/shootout/shootout_bloc.dart) |
| Shootout state fields and derived getters | [`lib/blocs/shootout/shootout_state.dart`](../../lib/blocs/shootout/shootout_state.dart) |
| Standalone shootout screen shell | [`lib/screens/shootout/shootout_screen.dart`](../../lib/screens/shootout/shootout_screen.dart) |
| Lobby and shared deck entry gate | [`lib/screens/shootout/shootout_home_screen.dart`](../../lib/screens/shootout/shootout_home_screen.dart) |
| Kick-loop UI | [`lib/screens/shootout/widgets/shootout_phase.dart`](../../lib/screens/shootout/widgets/shootout_phase.dart) |
| Summary UI | [`lib/screens/shootout/widgets/shootout_result_phase.dart`](../../lib/screens/shootout/widgets/shootout_result_phase.dart) |
| XP, coins, CPU scaling, opponent generation | [`lib/models/progression.dart`](../../lib/models/progression.dart) |
| Reward, history, ledger, and streak application | [`lib/blocs/game/game_bloc.dart`](../../lib/blocs/game/game_bloc.dart) |
| History model | [`lib/models/match.dart`](../../lib/models/match.dart) |

Relevant tests:

- [`test/shootout_bloc_test.dart`](../../test/shootout_bloc_test.dart)
- [`test/shootout_phase_test.dart`](../../test/shootout_phase_test.dart)
- [`test/shootout_opponent_generation_test.dart`](../../test/shootout_opponent_generation_test.dart)
- [`test/shootout_opponent_reveal_test.dart`](../../test/shootout_opponent_reveal_test.dart)
- [`test/progression_economy_test.dart`](../../test/progression_economy_test.dart)
