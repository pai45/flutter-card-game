# Streaks

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Daily activity streaks, mode streaks, milestones, reward claims, and calendar surfaces

## Product Purpose

Streaks turn repeated play into a visible habit loop. They reward returning to
make a prediction, place a pick, or complete supported game activity without
making a missed day erase the player's broader progression.

## Where It Lives

Streak state is available through profile and prediction surfaces, streak
widgets, the prediction calendar, and milestone celebration hosts. Supported
activity types are prediction, pick, Pitch Duel, Penalty Shootout, and daily
Guess the Player; these roll up into overall and category streaks.

## Player Flow

1. Complete an eligible action.
2. The action records one idempotent activity for the current local day.
3. The relevant activity/category streaks continue, restart, or remain unchanged.
4. A crossed milestone becomes claimable and a celebration is queued.
5. Claim the milestone reward; its claim state persists.

## Mechanics and Rules

Activity is date-keyed. Repeating the same activity in one day does not add a
second streak day. Consecutive dates increment the streak; a gap restarts the
active run. Milestones are 7 days (250 coins), 25 days (750 coins), 50 days
(gold card), 100 days (platinum card), 250 days (gold pack), and 365 days
(elite pack).

## Rewards and Progression

Streak milestones pay coins, cards, or packs through the shared economy. Daily
mystery settlement also records supported game activity and, when won, credits
its XP exactly once.

## Gratification and Feedback

Live flame/calendar states, milestone progress, claim affordances, reward
reveals, and celebration overlays make continuation and recovery legible. Glow
is reserved for live streaks and claimable moments.

## Visible States

Inactive, active-today, at-risk, restarted, milestone-ready, claiming, claimed,
and persisted calendar-history states are represented.

## Persistence

Streak history, best/current counts, recorded dates, and claimed milestones are
stored by `SecureGameStorage`. Settlement event identity prevents duplicate
daily-mystery XP or streak credit.

## Planned Scope and Current Limitations

- **BUILT:** The activity/category model, milestone schedule, persistence,
  calendar, claims, and celebration hosts.
- **PLANNED:** Any new game-specific streak must first define its recording and
  idempotency contract; undocumented game activity must not silently affect the
  overall streak.

## Implementation References

- [`lib/models/streak.dart`](../../../lib/models/streak.dart)
- [`lib/blocs/game/game_bloc.dart`](../../../lib/blocs/game/game_bloc.dart)
- [`lib/widgets/streak_widgets.dart`](../../../lib/widgets/streak_widgets.dart)
- [`lib/screens/predictions/streak_calendar_screen.dart`](../../../lib/screens/predictions/streak_calendar_screen.dart)
- [`lib/services/settlement_writer.dart`](../../../lib/services/settlement_writer.dart)

## Tests

- [`test/streak_model_test.dart`](../../../test/streak_model_test.dart)
- [`test/streak_bloc_test.dart`](../../../test/streak_bloc_test.dart)
- [`test/streak_widget_test.dart`](../../../test/streak_widget_test.dart)
- [`test/daily_mystery_cubit_test.dart`](../../../test/daily_mystery_cubit_test.dart)
