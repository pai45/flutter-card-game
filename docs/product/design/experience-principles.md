# Gamer-First Experience Principles

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Product experience rules for games, progression, feedback, friction, and planned feature design

## Product Purpose

StatOz/Pitch Duel is built for players, not administrators. Every feature should
shorten the path to fun, communicate mastery, and pay meaningful actions back
with a clear sensory or progression moment.

## Where It Lives

These principles govern all Games-tab modes, predictions, picks, social
features, progression, collections, economy, onboarding, navigation, and future
product scope. Visual execution is specified in the
[Cyber UI design system](cyber-ui-design-system.md).

## Player Flow

1. Make the next useful action obvious.
2. Let the player act with low friction and enough tactical clarity.
3. Resolve cause and effect immediately.
4. Reveal reward/progress in a satisfying beat.
5. Offer a fast replay, next challenge, or mastery target.

## Mechanics and Rules

- Reuse existing game and shared-component patterns before adding new ones.
- Prefer challenge, progression, unlocks, rivalry, mastery, and meaningful choice
  over flat form/list experiences.
- A spend, settlement, result, unlock, or milestone must explain what changed.
- Skipping animation must never change the reward outcome.
- Planned ideas are tagged `PLANNED`; copy must not imply unbuilt behavior exists.
- Optimize for speed to fun, readable decisions, and recoverable mistakes.

## Rewards and Progression

Rewards should connect to an authored loop: game XP to its track, aggregate
level, coins to acquisition/customization, cards to deck expression, streaks to
return behavior, and achievements to mastery. Avoid untracked or unexplained
value changes.

## Gratification and Feedback

Meaningful actions need proportionate payoff: impact ticks for small actions,
result beats for rounds, cinematic settlement for earned bundles, and rare
celebrations for levels, perfect results, packs, milestones, and achievements.
The presentation supports the event; it does not delay routine navigation.

## Visible States

Every flow should intentionally cover loading, ready, selected/live, locked,
insufficient-resource, success, failure/draw, reward-pending, settled, empty,
and recoverable error states as applicable.

## Persistence

The experience must distinguish temporary presentation from durable outcome.
Authoritative state and idempotent settlement persist first; animation may then
reveal that result without becoming the source of truth.

## Planned Scope and Current Limitations

- **BUILT:** Existing modes demonstrate progression, settlement reveals, pack
  unpacking, result beats, level-ups, streaks, and achievement celebrations.
- **PLANNED:** New features must name their gratification, replay/next-action,
  persistence, accessibility, and failure-state contracts before implementation.

## Implementation References

- [`lib/widgets/reward_settlement_popup.dart`](../../../lib/widgets/reward_settlement_popup.dart)
- [`lib/widgets/card_unpack_animation.dart`](../../../lib/widgets/card_unpack_animation.dart)
- [`lib/widgets/achievement_unlock_celebration.dart`](../../../lib/widgets/achievement_unlock_celebration.dart)
- [`lib/widgets/streak_celebration_host.dart`](../../../lib/widgets/streak_celebration_host.dart)
- [`lib/screens/game/widgets/final_result_phase.dart`](../../../lib/screens/game/widgets/final_result_phase.dart)

## Tests

Experience behavior is covered by the targeted mode and settlement tests linked
from each product page. New payoff moments should add widget/state tests for both
full and skipped/reduced-motion paths.
