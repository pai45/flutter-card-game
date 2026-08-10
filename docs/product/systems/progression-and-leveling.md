# Progression and Leveling

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Per-mode XP tracks, aggregate profile level, reward routing, migration, difficulty scaling, and level-up feedback

## Product Purpose

Progression gives each mode its own mastery path while preserving one clear
profile level. Players can see what they have mastered, keep new modes from
borrowing unrelated XP for difficulty, and still advance a shared identity.

## Where It Lives

Mode hubs use their track level and XP. Profile/HUD level chips use aggregate
XP and aggregate level. Result, prediction, pack, daily-mystery, achievement,
and reward surfaces apply typed XP transactions and can queue level-up feedback.

## Player Flow

1. Complete an XP-bearing action.
2. The action writes a typed XP ledger transaction.
3. Its source maps to exactly one `ProgressTrack`.
4. The mode track and aggregate total update.
5. Any crossed track/aggregate level is surfaced by the owning result or
   celebration flow.

## Mechanics and Rules

The source of truth is `xpByTrack`, not a single mutable total. Current tracks
are Pitch Duel, Penalty Shootout, Football Chess, Quiz, Football Bingo, Guess
Player, Final Over, Hoop Duel, Grand Prix, Tennis Rally, Predictions, and
Cards/Meta. `totalXP` is the sum of all track XP; `playerLevel` applies the same
curve to that sum. Mode level applies the curve only to that mode's XP.

The cumulative XP required for level `L` is:

```text
xpToReach(L) = 50 × L × (L - 1)
```

Level 1 starts at 0 XP, level 2 at 100, level 3 at 300, level 4 at 600, and
level 5 at 1,000. Applying XP clamps the affected track at zero. A negative
Pitch Duel result can therefore lower its track level and, if the aggregate
crosses a boundary, the profile level; there is no max-level floor stored today.

Pitch Duel match XP is:

| Result | XP |
|---|---:|
| Regulation draw | +4 |
| Win | `min(25, 10 + goal margin × 3 + 5 if shutout)` |
| Loss | `max(-15, -(5 + losing margin × 2))` |

Standalone shootout wins pay +8/+10/+12 by margin and losses pay 0. Other modes
use their own formulas documented on their game pages. Card XP is card-driven;
prediction/daily-mystery XP uses its settlement result.

## Rewards and Progression

XP never changes Oz Coins by itself. Typed sources keep history and routing
auditable. Packs/cards use Cards/Meta, quizzes share Quiz, and the three daily
Guess Player sports share Guess Player. Legacy `{totalXP}` saves migrate by
folding the XP ledger into tracks; without a ledger, the legacy balance is kept
in Cards/Meta.

## Gratification and Feedback

Mode meters show local mastery while profile meters show aggregate advancement.
Result count-ups, animated progress bars, crossed-level queues, and level-up
celebrations make movement visible without requiring players to understand the
underlying map.

## Visible States

No XP, partial level, level crossed, multiple levels crossed, negative delta,
track-only level-up, aggregate level-up, migration, and ledger history states
are represented by the model and participating surfaces.

## Persistence

`PlayerProgression.xpByTrack` and the XP ledger persist through
`SecureGameStorage`. `totalXP` remains serialized for compatibility/debugging,
but the map is authoritative. Settlement identities prevent repeat credit on
supported one-time rewards.

## Planned Scope and Current Limitations

- **BUILT:** Twelve per-mode/meta tracks, aggregate level, typed source routing,
  legacy migration, UI progress fields, and level-crossing results.
- **PLANNED:** Any promise of permanent non-deleveling, prestige, level caps, or
  new track must be separately specified and tested; none is implied here.

## Implementation References

- [`lib/models/progression.dart`](../../../lib/models/progression.dart)
- [`lib/models/xp_ledger.dart`](../../../lib/models/xp_ledger.dart)
- [`lib/blocs/game/game_bloc.dart`](../../../lib/blocs/game/game_bloc.dart)
- [`lib/services/secure_storage_service.dart`](../../../lib/services/secure_storage_service.dart)
- [`lib/widgets/player_level_badge.dart`](../../../lib/widgets/player_level_badge.dart)
- [`lib/screens/game/widgets/final_result_phase.dart`](../../../lib/screens/game/widgets/final_result_phase.dart)

## Tests

- [`test/progression_tracks_test.dart`](../../../test/progression_tracks_test.dart)
- [`test/progression_economy_test.dart`](../../../test/progression_economy_test.dart)
- [`test/xp_history_widget_test.dart`](../../../test/xp_history_widget_test.dart)
