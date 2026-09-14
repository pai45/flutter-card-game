# Prediction Gamification

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Prediction activity streaks, achievements, boosters, settlement payoff, community comparison, and planned accuracy-streak layer

## Product Purpose

Prediction gamification makes the time between submit and result feel like an
arc rather than a form plus claim button. It builds anticipation at prediction
time, preserves a daily return habit, and turns truth/accuracy into a staged payoff.

## Where It Lives

Gamification is composed into the prediction quiz, fixture cards, prediction
history, streak calendar, Profile achievements, match leaderboard/community
context, and the settlement reveal. The base lifecycle is documented in
[Predictions](predictions.md).

## Player Flow

1. See question rewards and a live potential-XP pot.
2. Commit answers and strategically place boosters.
3. Submit to record prediction streak activity and achievement progress.
4. Revisit the locked prediction and community context.
5. Return to the results-ready state and reveal verdicts in order.
6. Receive XP, possible contest prize, achievement/level moments, and a clear next action.

## Mechanics and Rules

**BUILT — Daily quests:** Fresh successful prediction submissions complete
Make Your Call in the shared streak hub; edits, failed submissions and reopening
results do not count. Two eligible game completions are its built-in alternative.
Confirmed picks complete Back Your Play, with three game completions as the
alternative. The quest rewards are Oz Coins, separate from prediction XP and
accuracy. See [Streaks](streaks.md) for the daily set, claims and persistence.

Built gamification includes the potential-XP ticker, movable 2×/1.5× boosters,
daily prediction activity streak recording, shared achievements, community vote
context, match leaderboard, results-ready state, skippable cinematic settlement,
perfect-quiz treatment, and level progress/celebration.

The daily streak means “made an eligible prediction today”; it is not an
accuracy multiplier. A designed consecutive-correct-answer **accuracy streak**
and any tier multipliers remain `PLANNED` and must not affect current XP formulas.

## Rewards and Progression

Correct-answer XP routes to the Predictions track. Booster math is applied by
the prediction reward model. The Scoreline paid-contest prize is the one coin
exception and is documented in [Predictions](predictions.md). Shared achievement
bounties are settled through the achievement/progression systems.

## Gratification and Feedback

Animated question entrances, reward-pill changes, booster feedback, submission
celebration, gold results-ready signal, verdict stamps, running XP ticker,
crowd comparison, perfect result, contest podium, and level/achievement handoffs
concentrate intensity around commitment and truth.

## Visible States

No/active daily prediction streak, achievement locked/progress/unclaimed/claimed,
booster unused/placed/moved/lost, results pending/ready/revealing/settled,
perfect/non-perfect, and contest-prize states are represented where built.

## Persistence

Prediction submissions/results, streak activity, achievement progress/claims,
XP and any contest prize persist in their owning stores. Reveal progress is
presentation state and does not own reward settlement.

## Planned Scope and Current Limitations

- **BUILT:** Potential pot, boosters, submission/result celebrations, daily
  prediction activity streak, shared achievements, community comparison,
  settlement reveal, perfect treatment, and level-up handoff.
- **PLANNED:** Consecutive-correct accuracy streak/tier multiplier, inline quest
  chips outside the streak hub, streak-break beats, and accuracy-flame placement. These concepts are
  preserved as design scope only and do not change current rewards.

## Implementation References

- [`lib/screens/predictions/match_prediction_screen.dart`](../../../lib/screens/predictions/match_prediction_screen.dart)
- [`lib/screens/predictions/widgets/settlement_reveal.dart`](../../../lib/screens/predictions/widgets/settlement_reveal.dart)
- [`lib/screens/predictions/streak_calendar_screen.dart`](../../../lib/screens/predictions/streak_calendar_screen.dart)
- [`lib/models/achievement.dart`](../../../lib/models/achievement.dart)
- [`lib/models/streak.dart`](../../../lib/models/streak.dart)

## Tests

- [`test/match_prediction_screen_test.dart`](../../../test/match_prediction_screen_test.dart)
- [`test/streak_bloc_test.dart`](../../../test/streak_bloc_test.dart)
- [`test/services/prediction_quiz_engine_test.dart`](../../../test/services/prediction_quiz_engine_test.dart)
