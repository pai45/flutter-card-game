# Cricket Quiz

Cricket Quiz is StatOz's trivia ladder mode. It gives the Games tab a knowledge-first loop: choose a category, pay a small Oz Coin entry fee, answer a 10-question set, and earn XP when the set is passed.

## Product Purpose

Cricket Quiz gives users a fast non-card game mode that rewards cricket knowledge without requiring a deck, squad, or opponent.

It uses the shared wallet for entry costs and the shared progression track for XP rewards. It does not award coins, write match-history entries, or require starter-pack ownership.

## Where It Lives

Cricket Quiz is opened from the **GAMES** tab in the Predictions area.

The Games tab currently includes:

- **Pitch Duel**: four-round tactical card match.
- **Penalty Shootout**: standalone spot kicks.
- **Cricket Quiz**: trivia set ladder.
- **Cricket Bingo**: daily country-by-club grid puzzle.
- **Guess the Player**: daily career-timeline mystery.
- **5v5 Cricket Chess**: tactical squad duel.

Opening Cricket Quiz launches a full-screen lobby owned by `QuizCubit`. The lobby shows overall set progress and lets the user choose a trivia category.

## Categories And Sets

Cricket Quiz has four categories:

| Category | Theme | XP per correct answer |
|----------|-------|-----------------------|
| Easy | Cricket basics | 5 XP |
| Medium | Domestic and leagues | 10 XP |
| Hard | Deep-cut trivia | 20 XP |
| Global | International cricket | 30 XP |

All categories are currently open from the start. Progression is gated inside each category by numbered sets.

Each category contains 50 sets. Set 1 is unlocked by default, and each next set unlocks after the previous set is passed.

## Entry Cost

Each set attempt costs 25 Oz Coins.

The entry cost is charged before the play screen opens. If the user does not have enough coins, the set does not launch and the UI shows a short message.

Retrying the same set from the reveal screen also costs 25 Oz Coins.

## User Flow

1. User opens **Predictions -> Games -> Cricket Quiz**.
2. Lobby loads persisted quiz progress.
3. User chooses a category: Easy, Medium, Hard, or Global.
4. User chooses an unlocked set.
5. If the wallet has at least 25 coins, the entry cost is spent and the quiz opens.
6. User answers 10 multiple-choice questions.
7. The bottom dock lets the user move backward, move forward, and submit once all questions are answered.
8. On submit, the reveal overlay flips through question results.
9. If the set is passed, correct answers pay XP into the shared progression track.
10. The result is saved into category/set progress.
11. User can retry the set or return to the set ladder.

Leaving before submit discards the in-progress answer state. The entry cost is not refunded.

## Question Format

Each question contains:

- stable question id
- category
- prompt
- answer options
- correct option index
- optional background asset

The play screen shows one question at a time. The header tracks the current question number, answered state, and the visible XP pot based on answered questions.

## Pass Rule

A set has 10 questions. The user passes when they finish with 5 or fewer wrong answers.

That means a set is passed with at least 5 correct answers out of 10.

If the user does not pass, the result is still saved as an attempt and best-correct count can improve, but no XP is awarded.

## Rewards And Progression

Cricket Quiz is XP-only. It does not award coins.

XP is credited only when the set is passed:

```dart
totalXp = correctAnswers * mode.reward
```

The XP ledger entry uses source `quiz`, title `CRICKET QUIZ REWARD`, and details like `EASY SET 1`.

The reveal credits XP before the cinematic finishes, so skipping or leaving the reveal does not change the reward outcome.

## Persistence

Cricket Quiz persists personal progress through `SecureGameStorage`.

For each category, the app stores progress by set number:

- whether the set has been passed
- best correct count
- attempt count

The stored progress controls set unlocks and the progress bars shown in the lobby and category screens.

Current limitations:

- No match-history entry is written.
- No coin reward is paid.
- Category unlocks are no longer gated; all four categories are open, while set unlocks remain sequential.

## Implementation Reference

| Concern | Source |
|---------|--------|
| Quiz constants, category metadata, set progress model | [`lib/models/quiz_trivia.dart`](../../lib/models/quiz_trivia.dart) |
| Trivia question bank and deterministic set building | [`lib/services/quiz_trivia_bank.dart`](../../lib/services/quiz_trivia_bank.dart) |
| Quiz progress loading and result persistence | [`lib/blocs/quiz/quiz_cubit.dart`](../../lib/blocs/quiz/quiz_cubit.dart) |
| Quiz state fields and derived getters | [`lib/blocs/quiz/quiz_state.dart`](../../lib/blocs/quiz/quiz_state.dart) |
| Cricket Quiz shell | [`lib/screens/quiz/quiz_hub.dart`](../../lib/screens/quiz/quiz_hub.dart) |
| Lobby, category list, set ladder, entry cost handling | [`lib/screens/quiz/quiz_lobby_screen.dart`](../../lib/screens/quiz/quiz_lobby_screen.dart) |
| Live question flow, submit, retry, and XP dispatch | [`lib/screens/quiz/quiz_play_screen.dart`](../../lib/screens/quiz/quiz_play_screen.dart) |
| Quiz reveal overlay | [`lib/screens/quiz/widgets/quiz_reveal.dart`](../../lib/screens/quiz/widgets/quiz_reveal.dart) |
| Quiz progress storage | [`lib/services/secure_storage_service.dart`](../../lib/services/secure_storage_service.dart) |

Relevant tests:

- [`test/quiz_cubit_test.dart`](../../test/quiz_cubit_test.dart)
- [`test/quiz_set_flow_test.dart`](../../test/quiz_set_flow_test.dart)
