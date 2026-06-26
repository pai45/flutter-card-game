# Pitch Duel Leveling System

Pitch Duel uses a single XP total to drive player level, level progress UI, match rewards, pack rewards, and CPU difficulty scaling.

## Source Of Truth

The progression model lives in [`lib/models/progression.dart`](../../lib/models/progression.dart). The persisted value is `totalXP`; the visible level and progress numbers are derived from that total each time they are read.

Progression is saved through [`SecureGameStorage`](../../lib/services/secure_storage_service.dart), which stores progression JSON containing `totalXP`.

## Level Curve

The cumulative XP needed to reach a level is:

```dart
xpToReach(level) = 50 * level * (level - 1)
```

This makes level 1 the starting level at 0 XP, then widens each level band by 100 XP.

| Level | Cumulative XP required | XP needed from previous level |
|-------|-------------------------|-------------------------------|
| 1 | 0 | N/A |
| 2 | 100 | 100 |
| 3 | 300 | 200 |
| 4 | 600 | 300 |
| 5 | 1000 | 400 |

For any total XP value, the model calculates:

- `playerLevel`: the derived level.
- `xpIntoLevel`: XP earned inside the current level band.
- `xpToNextLevel`: the size of the current level band.
- `xpRemainingToNextLevel`: the remaining XP before the next level.
- `pct`: progress through the current level band.

> Product note: the name `xpToNextLevel` is slightly misleading in code. It returns the total span of the current level, not the remaining XP. `xpRemainingToNextLevel` is the actual remaining value.

## XP From Matches

When a match finishes, [`GameBloc._onMatchFinished`](../../lib/blocs/game/game_bloc.dart) calculates an XP delta, applies it to progression, stores the previous progression snapshot, and records any crossed levels for celebration UI.

Match XP is calculated by `calculateMatchXP`:

| Result | XP behavior |
|--------|-------------|
| Draw | 0 XP |
| Victory on penalties | +6 XP |
| Defeat on penalties | -2 XP |
| Victory in regulation | `10 + goalDiff * 3 + shutoutBonus`, capped at +25 |
| Defeat in regulation | `-(5 + concededMargin * 2)`, floored at -15 |

The shutout bonus is +5 when the opponent scores 0 in a regulation victory.

Coins are awarded separately:

| Result | Coins |
|--------|-------|
| Victory | 50 |
| Draw | 25 |
| Defeat | 10 |

## XP From Penalty Shootout

Standalone [Penalty Shootout](penalty-shootout.md) uses the same total XP, level, wallet, ledger, and match-history systems as Pitch Duel, but its rewards are smaller because sessions are shorter.

Shootout XP is calculated by `calculateShootoutXP`:

| Result | XP behavior |
|--------|-------------|
| Win by 1 | +8 XP |
| Win by 2 | +10 XP |
| Win by 3+ | +12 XP, capped |
| Loss | 0 XP |

Shootout losses do not subtract XP. This differs from full Pitch Duel match losses, which can apply negative XP.

Shootout coins are awarded by `shootoutCoins`:

| Result | Coins |
|--------|-------|
| Win | 20 |
| Loss | 5 |

When a standalone shootout ends, `GameBloc._onShootoutFinished` records the XP ledger source `shootout`, coin ledger source `shootoutReward`, a `shootout` match-history entry, and penalty shootout streak activity.

## XP From Cards And Packs

Packs, daily drops, starter packs, and direct card unlocks all grant XP based on the cards revealed. Pack reward assembly lives in [`lib/models/packs.dart`](../../lib/models/packs.dart).

| Card type | XP formula |
|-----------|------------|
| Player card | Card rating |
| Action card | `max(15, 30 + card.power)` |

A pack result sums XP across all revealed player and action cards. When the pack is applied, the game:

1. Adds newly revealed cards to owned card IDs.
2. Applies the pack XP to progression.
3. Stores `previousProgression`.
4. Stores `pendingLevelUps`.
5. Stores `lastMatchXP` as the pack XP for reveal/progress presentation.
6. Saves updated progression and wallet data.

## Applying XP

`PlayerProgression.applyXP(delta)`:

1. Reads the old derived level.
2. Adds the XP delta to `totalXP`.
3. Clamps total XP at 0.
4. Derives the new level.
5. Returns the updated progression and a list of newly crossed levels.

The crossed-level list powers level-up presentation. If a reward jumps from level 2 to level 4, the returned list is `[3, 4]`.

## De-Leveling Behavior

The current implementation derives level directly from total XP after every delta. This means the player can de-level if losses drop total XP below a level threshold.

Example:

- Level 3 starts at 300 XP.
- A player at 305 XP loses 10 XP.
- New total XP is 295.
- Derived level becomes 2.

There is a code comment that says "No de-leveling occurs," but the implementation does not currently enforce that. Product language should treat de-leveling as possible until the model changes to store a max level or clamp negative match XP within the current level.

## Difficulty Scaling

Player level also controls CPU opponent strength. When a match starts, [`GameBloc._onMatchStarted`](../../lib/blocs/game/game_bloc.dart) calls `generateOpponentDeck` with the current `playerLevel`.

The scaling rules are:

| Mechanic | Formula or behavior |
|----------|---------------------|
| Opponent target rating | `min(95, 66 + level * 2)` |
| CPU smartness | `min(1.0, level / 12)` |
| Opponent deck players | Picks cards near the target rating. |
| Opponent deck actions | Higher smartness makes stronger action cards more likely. |
| In-round CPU player choice | Higher smartness makes the highest-rated available player more likely. |
| In-round CPU action choice | Higher smartness makes the best action more likely, with a penalty for risky actions. |

At level 1, CPU smartness is about 8.3%. At level 12 and above, smartness reaches 100%.

Penalty Shootout uses the same level-derived target rating and CPU smartness. `generateShootoutOpponent` builds a five-player CPU lineup near the target rating, and the shootout CPU uses smartness to decide how often it reads the user's shot or dive habits before falling back to random directions.

## UI Surfaces

Leveling appears in these user-facing areas:

- Home stats show level and total XP.
- Profile shows the level badge and total XP.
- `PlayerLevelBadge` shows current level, progress inside the level band, remaining XP, and total XP.
- Final result shows XP delta, current level, and an animated progress bar.
- Level-up celebration appears when `pendingLevelUps` is not empty.
- Starter pack and pack reveal summaries show XP gained and level-up messaging.

## Implementation References

| Concern | Source |
|---------|--------|
| Level curve and XP application | [`lib/models/progression.dart`](../../lib/models/progression.dart) |
| Match XP and coin rewards | [`lib/models/progression.dart`](../../lib/models/progression.dart) |
| Shootout XP, coin rewards, and opponent generation | [`lib/models/progression.dart`](../../lib/models/progression.dart) |
| Opponent difficulty scaling | [`lib/models/progression.dart`](../../lib/models/progression.dart) |
| Match finish reward application | [`lib/blocs/game/game_bloc.dart`](../../lib/blocs/game/game_bloc.dart) |
| Shootout finish reward application | [`lib/blocs/game/game_bloc.dart`](../../lib/blocs/game/game_bloc.dart) |
| Pack reward application | [`lib/blocs/game/game_bloc.dart`](../../lib/blocs/game/game_bloc.dart) |
| Pack XP totals | [`lib/models/packs.dart`](../../lib/models/packs.dart) |
| Progression persistence | [`lib/services/secure_storage_service.dart`](../../lib/services/secure_storage_service.dart) |
| Level badge UI | [`lib/widgets/player_level_badge.dart`](../../lib/widgets/player_level_badge.dart) |
| Final result XP UI | [`lib/screens/game/widgets/final_result_phase.dart`](../../lib/screens/game/widgets/final_result_phase.dart) |
| Progression tests | [`test/progression_economy_test.dart`](../../test/progression_economy_test.dart) |
