# F1 Quiz

F1 Quiz is StatOz's trivia ladder mode. It gives the Games tab a knowledge-first loop: choose a category, pay a small Oz Coin entry fee, answer a 10-question set, and earn XP for every correct answer.

## Product Purpose

F1 Quiz gives users a fast non-card game mode that rewards F1 knowledge without requiring a deck, squad, or opponent.

It uses the shared wallet for entry costs and the shared progression track for XP rewards. It does not award coins, write match-history entries, or require starter-pack ownership.

## Where It Lives

F1 Quiz is opened from the **GAMES** tab in the Predictions area.

The Games tab currently includes:

- **Pitch Duel**: four-round tactical card match.
- **Penalty Shootout**: standalone spot kicks.
- **F1 Quiz**: trivia set ladder.
- **F1 Bingo**: daily country-by-club grid puzzle.
- **Guess the Driver**: daily career-timeline mystery.
- **5v5 F1 Chess**: tactical squad duel.

Opening F1 Quiz launches a full-screen lobby owned by `QuizCubit`. The lobby shows overall set progress and lets the user choose a trivia category.

## Categories And Sets

F1 Quiz has four categories:

| Category | Theme | XP per correct answer |
|----------|-------|-----------------------|
| Easy | Motorsport basics | 1 XP |
| Medium | Teams and series | 2 XP |
| Hard | Deep-cut trivia | 4 XP |
| Global | World motorsport | 5 XP |

All categories are currently open from the start. Progression is gated inside each category by numbered sets.

Each category contains 50 sets. Set 1 is unlocked by default, and each next set unlocks once the previous set is finished.

## Entry Cost

Each set attempt costs 25 Oz Coins.

The entry cost is charged before the play screen opens. If the user does not have enough coins, the set does not launch and the UI shows a short message.

Retrying the same set from the reveal screen also costs 25 Oz Coins.

## User Flow

1. User opens **Predictions -> Games -> F1 Quiz**.
2. Lobby loads persisted quiz progress.
3. User chooses a category: Easy, Medium, Hard, or Global.
4. User chooses an unlocked set.
5. If the wallet has at least 25 coins, the entry cost is spent and the quiz opens.
6. User answers 10 multiple-choice questions.
7. The bottom dock lets the user move backward, move forward, and submit once all questions are answered.
8. On submit, the reveal overlay flips through question results.
9. Correct answers pay XP into the shared progression track.
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

## Mastery Stars

A set has 10 questions. There is no pass gate: finishing all 10 always clears the
set and unlocks the next one, whatever the score.

The score decides mastery stars instead, which is the reason to replay a set:

| Best score | Stars |
|------------|-------|
| 10 / 10 | 3 |
| 7 - 9 | 2 |
| 1 - 6 | 1 |
| 0 | 0 |

Quitting mid-run banks the XP already earned but does not record a result, so a
set only clears on a full run.

## Difficulty Bands

Each category's 50 sets are split into five bands of 10 sets, and the questions
get harder as you climb. The set-ladder chapter selector doubles as the band
picker.

| Band | Sets | Name |
|------|------|------|
| 1 | 1 - 10 | FOUNDATION |
| 2 | 11 - 20 | PROSPECT |
| 3 | 21 - 30 | CONTENDER |
| 4 | 31 - 40 | SPECIALIST |
| 5 | 41 - 50 | LEGEND |

The category sets the subject breadth; the band sets the depth within it. Band 5
of Easy is still easier than band 1 of Medium.

## Question Data

Questions are authored data, not code. Each sport and category has one file at
`assets/quiz/<sport>_<mode>.json` holding five bands of 100 questions, loaded on
demand by `lib/services/quiz_bank.dart`. Run
`dart run tool/verify_quiz_bank.dart` to validate counts, option lengths,
duplicate prompts and answer-position balance, and to print a coverage table.

Sets past the authored range render as SOON in the ladder rather than falling
back to placeholder questions.

## Rewards And Progression

F1 Quiz is XP-only. It does not award coins.

Every correct answer pays, whatever the final score:

```dart
totalXp = correctAnswers * mode.reward
```

The XP ledger entry uses source `quiz`, title `F1 QUIZ REWARD`, and details like `EASY SET 1`.

The reveal credits XP before the cinematic finishes, so skipping or leaving the reveal does not change the reward outcome.

## Persistence

F1 Quiz persists personal progress through `SecureGameStorage`.

For each category, the app stores progress by set number:

- whether the set has been completed
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
| F1 Quiz shell | [`lib/screens/quiz/quiz_hub.dart`](../../lib/screens/quiz/quiz_hub.dart) |
| Lobby, category list, set ladder, entry cost handling | [`lib/screens/quiz/quiz_lobby_screen.dart`](../../lib/screens/quiz/quiz_lobby_screen.dart) |
| Live question flow, submit, retry, and XP dispatch | [`lib/screens/quiz/quiz_play_screen.dart`](../../lib/screens/quiz/quiz_play_screen.dart) |
| Quiz reveal overlay | [`lib/screens/quiz/widgets/quiz_reveal.dart`](../../lib/screens/quiz/widgets/quiz_reveal.dart) |
| Quiz progress storage | [`lib/services/secure_storage_service.dart`](../../lib/services/secure_storage_service.dart) |

Relevant tests:

- [`test/quiz_cubit_test.dart`](../../test/quiz_cubit_test.dart)
- [`test/quiz_set_flow_test.dart`](../../test/quiz_set_flow_test.dart)
