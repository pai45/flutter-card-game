# Tennis Quiz

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Tennis trivia categories, set progression, answer feedback, entry cost, and XP

## Product Purpose

Tennis Quiz gives tennis fans a short knowledge gauntlet with mastery stars,
streak feedback, immediate answer verdicts, and shared progression rewards.

## Where It Lives

Open **Sports -> Games -> Tennis -> Tennis Quiz**. It uses the shared quiz hub,
lobby, play, reveal, persistence, and progression pipeline with tennis question
content.

## Player Flow

1. Choose a tennis trivia category and an unlocked set.
2. Confirm the 25 Oz Coin entry cost.
3. Answer the set one question at a time.
4. Receive a timed correct/wrong reveal after each locked answer.
5. Build a run streak and accumulate the set's potential XP.
6. Finish the reveal, receive stars and best-score updates, and bank eligible
   XP into the Quiz track.

## Mechanics and Rules

Quiz sets use the same shared question/set model as Football, Cricket,
Basketball, and F1 Quiz. Difficulty bands control question reward and set
progression. An answer cannot be changed after its verdict begins. Stars and
set unlocks are derived from the result thresholds in the shared quiz model.

## Rewards and Progression
Starting a set spends 25 Oz Coins with source `quizEntry`. Correct answers add
the configured question reward to the run. Eligible result XP is credited to
the shared **Quiz** track and XP ledger. Answer streak is feedback only and does
not multiply XP.

## Gratification and Feedback

Each answer resolves through scan, verdict, correct-answer reveal, sound,
haptic, and streak escalation. The final overlay reveals score, stars gained,
new-best status, best streak, XP, and retry/done actions.

## Visible States

- Loading, category selection, locked/unlocked set, insufficient coins
- Question picking, answer resolving, correct, incorrect, and final reveal
- Passed, failed, stars gained, new best, retry, and completed review

## Persistence

Tennis quiz progress is stored through the sport-keyed quiz progress API.
Shared game state owns coin spending, progression, and XP/coin ledgers.

## Planned Scope and Current Limitations

- **BUILT:** Shared quiz flow, tennis content, 25-coin entry, stars, XP,
  per-answer feedback, and persisted set progress.
- **PROTOTYPE:** Question content is bundled locally.
- **PLANNED:** No separate tennis-quiz roadmap is recorded.

## Implementation References

- [`lib/screens/quiz/quiz_hub.dart`](../../../lib/screens/quiz/quiz_hub.dart)
- [`lib/screens/quiz/quiz_play_screen.dart`](../../../lib/screens/quiz/quiz_play_screen.dart)
- [`lib/blocs/quiz/quiz_cubit.dart`](../../../lib/blocs/quiz/quiz_cubit.dart)
- [`lib/services/quiz_bank.dart`](../../../lib/services/quiz_bank.dart)
- [`lib/services/quiz_trivia_bank.dart`](../../../lib/services/quiz_trivia_bank.dart)

## Tests

- [`test/quiz_cubit_test.dart`](../../../test/quiz_cubit_test.dart)
- [`test/quiz_set_flow_test.dart`](../../../test/quiz_set_flow_test.dart)
- [`test/progression_tracks_test.dart`](../../../test/progression_tracks_test.dart)
