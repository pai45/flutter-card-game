# Achievements

> **Status:** BUILT
> **Last verified:** 2026-08-11
> **Scope:** Achievement catalog, progress evaluation, unlocks, claims, profile badges, and celebration queue

## Product Purpose

Achievements recognize mastery across games, predictions, picks, progression,
and collection building. They give long-term objectives a visible finish line
and turn qualifying actions into memorable unlock moments.

## Where It Lives

Achievements are visible in Profile and are evaluated from the shared game
state. The profile view groups relevant badges into prediction, picks, and games
tabs while the global celebration host can announce unlocks over the current
screen.

## Player Flow

1. Perform an eligible action or cross a tracked threshold.
2. Progress evaluation updates matching catalog entries.
3. Newly completed entries enter the celebration queue unless their reveal is
   temporarily suppressed by the controller.
4. The player sees the unlock beat and can inspect the badge in Profile.
5. Where a bounty exists, claim it once through the shared reward pipeline.

## Mechanics and Rules

The catalog defines each badge's identifier, category, target, copy, rarity, and
optional reward. Progress is derived from authoritative game data; completion
and claim flags make unlock delivery idempotent.

## Rewards and Progression

Some achievements are recognition-only and some expose an XP bounty. Claimed XP
is written through the shared progression and ledger systems rather than being
kept as achievement-local currency.

## Gratification and Feedback

Global badge reveals, rarity treatment, progress bars, unlocked/locked states,
and an unclaimed chip create a clear anticipation-to-payoff arc. The strongest
glow and audio are reserved for the actual unlock. The **Treasury** badge still
unlocks at 1,000 coins and remains visible in Profile, but its global reveal is
currently suppressed so it does not overlap the first-run welcome-bonus moment.

## Visible States

Locked with progress, completed, newly unlocked/queued, unclaimed reward, and
claimed states are supported.

## Persistence

Achievement progress, unlock time, and claim state are stored with shared game
state. The celebration controller drains a queue without changing the reward
outcome.

## Planned Scope and Current Limitations

- **BUILT:** Cross-system catalog, evaluation service, profile grid, claims, and
  global unlock celebrations.
- **PLANNED:** New badges must be backed by an authoritative counter/event and
  tests; copy alone does not create a roadmap commitment.

## Implementation References

- [`lib/models/achievement.dart`](../../../lib/models/achievement.dart)
- [`lib/services/achievement_progress.dart`](../../../lib/services/achievement_progress.dart)
- [`lib/blocs/achievement/achievement_celebration_controller.dart`](../../../lib/blocs/achievement/achievement_celebration_controller.dart)
- [`lib/screens/profile/achievements_screen.dart`](../../../lib/screens/profile/achievements_screen.dart)
- [`lib/widgets/achievement_unlock_celebration.dart`](../../../lib/widgets/achievement_unlock_celebration.dart)

## Tests

- [`test/achievement_celebration_controller_test.dart`](../../../test/achievement_celebration_controller_test.dart)
