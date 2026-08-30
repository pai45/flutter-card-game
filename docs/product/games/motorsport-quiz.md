# Motorsport Quiz

> **Status:** BUILT
> **Last verified:** 2026-08-19
> **Scope:** Motorsport trivia categories, question database, set ladder, answer feedback, entry cost, persistence, and XP

Motorsport Quiz is StatOz's trivia ladder mode. It gives the Games tab a knowledge-first loop: choose a category, pay a small Oz Coin entry fee, answer a 10-question set, and earn XP for every correct answer.

## Product Purpose

Motorsport Quiz gives users a fast non-card game mode that rewards motorsport knowledge without requiring a deck, squad, or opponent.

It uses the shared wallet for entry costs and the shared progression track for XP rewards. It does not award coins, write match-history entries, or require starter-pack ownership.

## Where It Lives

Motorsport Quiz is opened from the **GAMES** tab in the Predictions area.

The Games tab currently includes:

- **Pitch Duel**: four-round tactical card match.
- **Penalty Shootout**: standalone spot kicks.
- **Motorsport Quiz**: trivia set ladder.
- **F1 Bingo**: daily country-by-club grid puzzle.
- **Guess the Driver**: daily career-timeline mystery.
- **5v5 F1 Chess**: tactical squad duel.

Opening Motorsport Quiz launches a full-screen lobby owned by `QuizCubit`. The lobby shows overall set progress and lets the user choose a trivia category.

## Mechanics and Rules
Motorsport Quiz has four categories:

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

## Player Flow
1. User opens **Predictions -> Games -> Motorsport Quiz**.
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

| Band | Sets | Name | Era the motorsport bank reaches |
|------|------|------|---------------------------------|
| 1 | 1 - 10 | FOUNDATION | 2020s, active drivers, household names |
| 2 | 11 - 20 | PROSPECT | 2010s |
| 3 | 21 - 30 | CONTENDER | 2000s |
| 4 | 31 - 40 | SPECIALIST | 1980s - 90s |
| 5 | 41 - 50 | LEGEND | 1950s - 70s, back to 1911 for the Indy 500 and 1923 for Le Mans |

The category sets the subject breadth; the band sets the depth within it. Band 5
of Easy is still easier than band 1 of Medium.

## Question Data

Questions are authored data, not code. Each sport and category has one file at
`assets/quiz/<sport>_<mode>.json` holding five bands of 100 questions, loaded on
demand by `lib/services/quiz_bank.dart`. Run
`dart run tool/verify_quiz_bank.dart` to validate counts, option lengths,
duplicate prompts and answer-position balance, and to print a coverage table.

Motorsport ships the complete 2,000-question ladder. **Every one of those 2,000
questions is a distinct recorded fact.** This is a deliberate step above the
cricket and basketball banks, which fill their 2,000 slots by re-wording roughly
600 seed facts up to eight ways each; motorsport has no variant-padding path,
and `tool/verify_quiz_bank.dart` fails the build if a re-worded fact key ever
appears.

Formula 1 leads the bank at roughly half the questions, but steps back sharply
in GLOBAL so the world capstone reads as a different category rather than a
harder Hard:

| Mode | F1 | MotoGP | NASCAR | IndyCar | Endurance | Rally | Feeder / other |
|------|---:|-------:|-------:|--------:|----------:|------:|---------------:|
| Easy | 300 | 55 | 50 | 40 | 30 | 15 | 10 |
| Medium | 285 | 55 | 50 | 45 | 40 | 15 | 10 |
| Hard | 265 | 55 | 50 | 45 | 45 | 25 | 15 |
| Global | 135 | 80 | 45 | 50 | 85 | 60 | 45 |

Totals: F1 985, MotoGP 245, Endurance 200, NASCAR 195, IndyCar 180, Rally 115,
Feeder/other 80. **Endurance** covers Le Mans, the FIA WEC and IMSA;
**Rally** covers the WRC, the Dakar Rally and hill climbs; **Feeder / other**
covers Formula E, Formula 2 / GP2, FIA Formula 3, touring cars and Super
Formula. Every 100-question band carries the same scope proportions.

### How the two difficulty axes differ

The **mode** sets how broad your knowledge has to be; the **band** sets how far
back in time it has to reach. Chronology is the honest difficulty axis in
motorsport, so each scope's questions are authored newest-first and banded by
era.

| Axis | What it changes |
|------|-----------------|
| Easy | Recognition: terminology, flags, driver nationalities, which country hosts a circuit |
| Medium | Structure: constructors, engine suppliers, manufacturers, season line-ups, championship winners |
| Hard | Deep cuts: individual race winners, all-time records, one-off winners |
| Global | World breadth: Le Mans, Dakar, WRC, Formula E, Super Formula, world-championship geography |

The per-band eras are listed in **Difficulty Bands** above.

### Sourcing and audit

Facts are frozen at **19 August 2026**. No unresolved 2026-season standings or
awards appear, and every time-sensitive prompt names its season or event. The
WRC scope stops at the 2024 title because the 2025 rally season fell outside
what could be verified against a primary source at the cutoff.

`tool/generate_motorsport_quiz.dart` builds the four runtime assets and the
development-only `tool/quiz_audit/motorsport.json` ledger from 18 official
primary sources - Formula 1, the FIA, MotoGP, NASCAR, INDYCAR, the
Indianapolis Motor Speedway, the FIA WEC, the ACO, IMSA, the WRC, the Dakar
Rally, Formula E, and FIA Formula 2 and Formula 3. Every audit entry stores the
canonical answer, a unique fact key, scope, competition, season, difficulty
position and at least two source references including at least one primary.

The verifier checks all 2,000 audit entries against the runtime answer keys,
exact scope totals, source metadata, distinct fact keys, and an exact
25/25/25/25 answer-position split in every 100-question band.

Sets past the authored range render as SOON in the ladder rather than falling
back to placeholder questions.

## Rewards and Progression
Motorsport Quiz is XP-only. It does not award coins.

Every correct answer pays, whatever the final score:

```dart
totalXp = correctAnswers * mode.reward
```

The XP ledger entry uses source `quiz`, title `MOTORSPORT QUIZ REWARD`, and details like `EASY SET 1`.

The reveal credits XP before the cinematic finishes, so skipping or leaving the reveal does not change the reward outcome.

## Persistence

Motorsport Quiz persists personal progress through `SecureGameStorage`.

For each category, the app stores progress by set number:

- whether the set has been completed
- best correct count
- attempt count

The stored progress controls set unlocks and the progress bars shown in the lobby and category screens.

Current limitations:

- No match-history entry is written.
- No coin reward is paid.
- Category unlocks are no longer gated; all four categories are open, while set unlocks remain sequential.

## Implementation References
| Concern | Source |
|---------|--------|
| Quiz constants, category metadata, set progress model | [`lib/models/quiz_trivia.dart`](../../../lib/models/quiz_trivia.dart) |
| Trivia question bank and deterministic set building | [`lib/services/quiz_trivia_bank.dart`](../../../lib/services/quiz_trivia_bank.dart) |
| Quiz progress loading and result persistence | [`lib/blocs/quiz/quiz_cubit.dart`](../../../lib/blocs/quiz/quiz_cubit.dart) |
| Quiz state fields and derived getters | [`lib/blocs/quiz/quiz_state.dart`](../../../lib/blocs/quiz/quiz_state.dart) |
| Motorsport Quiz shell | [`lib/screens/quiz/quiz_hub.dart`](../../../lib/screens/quiz/quiz_hub.dart) |
| Lobby, category list, set ladder, entry cost handling | [`lib/screens/quiz/quiz_lobby_screen.dart`](../../../lib/screens/quiz/quiz_lobby_screen.dart) |
| Live question flow, submit, retry, and XP dispatch | [`lib/screens/quiz/quiz_play_screen.dart`](../../../lib/screens/quiz/quiz_play_screen.dart) |
| Quiz reveal overlay | [`lib/screens/quiz/widgets/quiz_reveal.dart`](../../../lib/screens/quiz/widgets/quiz_reveal.dart) |
| Motorsport asset and audit generation | [`tool/generate_motorsport_quiz.dart`](../../../tool/generate_motorsport_quiz.dart) |
| Structural, coverage, and audit validation | [`tool/verify_quiz_bank.dart`](../../../tool/verify_quiz_bank.dart) |
| Quiz progress storage | [`lib/services/secure_storage_service.dart`](../../../lib/services/secure_storage_service.dart) |

## Tests

- [`test/quiz_cubit_test.dart`](../../../test/quiz_cubit_test.dart)
- [`test/quiz_set_flow_test.dart`](../../../test/quiz_set_flow_test.dart)
- `tool/verify_quiz_bank.dart`

## Gratification and Feedback

Answer locks, correct/wrong reveals, the visible XP pot, mastery stars, the set
result cinematic, new-best treatment, and level progress give every run a clear payoff.

## Visible States

Loading, locked/unlocked set, affordable/unaffordable entry, unanswered/locked
answer, correct/wrong reveal, incomplete exit, and completed set states are represented.

## Planned Scope and Current Limitations

- **BUILT:** The full 2,000-question audited Motorsport ladder on the shared
  quiz system, with a 25-coin entry, persisted stars/best scores, and
  Quiz-track XP.
- **PLANNED:** Any additional categories or live question service require
  explicit scope; current questions ship locally.
