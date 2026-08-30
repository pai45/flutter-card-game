# Tennis Quiz

> **Status:** BUILT
> **Last verified:** 2026-08-21
> **Scope:** Tennis trivia categories, question database, set ladder, answer feedback, entry cost, persistence, and XP

Tennis Quiz is StatOz's tennis trivia ladder mode. It gives the Tennis Games tab a knowledge-first loop: choose a category, pay a small Oz Coin entry fee, answer a 10-question set, and earn XP for every correct answer.

## Product Purpose

Tennis Quiz gives users a fast non-card game mode that rewards tennis knowledge without requiring a deck, squad, or opponent.

It uses the shared wallet for entry costs and the shared progression track for XP rewards. It does not award coins, write match-history entries, or require starter-pack ownership.

## Where It Lives

Tennis Quiz is opened from the **GAMES** tab in the Predictions area, under the Tennis sport.

The Tennis Games tab currently includes:

- **Tennis Rally**: rally-based tennis match game.
- **Tennis Quiz**: trivia set ladder.
- **Guess the Winner**: daily career-timeline mystery.

Opening Tennis Quiz launches a full-screen lobby owned by `QuizCubit`. The lobby shows overall set progress and lets the user choose a trivia category.

## Mechanics and Rules
Tennis Quiz has four categories:

| Category | Theme | XP per correct answer |
|----------|-------|-----------------------|
| Easy | Tennis basics | 1 XP |
| Medium | Slams and tours | 2 XP |
| Hard | Deep-cut trivia | 4 XP |
| Global | World tennis | 5 XP |

All categories are currently open from the start. Progression is gated inside each category by numbered sets.

Each category contains 50 sets. Set 1 is unlocked by default, and each next set unlocks once the previous set is finished.

## Entry Cost

Each set attempt costs 25 Oz Coins.

The entry cost is charged before the play screen opens. If the user does not have enough coins, the set does not launch and the UI shows a short message.

Retrying the same set from the reveal screen also costs 25 Oz Coins.

## Player Flow
1. User opens **Predictions -> Games -> Tennis -> Tennis Quiz**.
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

| Band | Sets | Name | What the tennis bank reaches |
|------|------|------|------------------------------|
| 1 | 1 - 10 | FOUNDATION | Household names of any era - Federer, Nadal, Djokovic, Alcaraz, Sinner, Serena, Graf, Navratilova, Borg, Swiatek |
| 2 | 11 - 20 | PROSPECT | Slam champions generally, year-end No. 1s, Tour Finals winners, regular top-10 names |
| 3 | 21 - 30 | CONTENDER | Masters 1000 / WTA 1000 winners, slam finalists, coaches, venues |
| 4 | 31 - 40 | SPECIALIST | One-slam winners, famous upsets, statistical records, doubles specialists |
| 5 | 41 - 50 | LEGEND | Deep cuts - pre-Open Era and amateur champions, early Davis Cup, junior and wheelchair detail |

The category sets the subject breadth; the band sets the depth within it. Band 5
of Easy is still easier than band 1 of Medium.

**Tennis bands are ordered by fame, not by date.** This is a deliberate break
from the Motorsport bank, where chronology is the difficulty axis. Borg,
McEnroe, Navratilova and Court are household names, so a 1980 Wimbledon final
belongs in band 1, not band 5. Era only trends older as a tiebreak.

## Question Data

Questions are authored data, not code. Each sport and category has one file at
`assets/quiz/<sport>_<mode>.json` holding five bands of 100 questions, loaded on
demand by `lib/services/quiz_bank.dart`. Run
`dart run tool/verify_quiz_bank.dart` to validate counts, option lengths,
duplicate prompts and answer-position balance, and to print a coverage table.

Tennis ships the complete 2,000-question ladder. **Every one of those 2,000
questions is a distinct recorded fact.** Tennis holds the same bar as the
Motorsport bank and a step above the cricket and basketball banks, which fill
their 2,000 slots by re-wording roughly 600 seed facts up to eight ways each.
The tennis generator has no variant-padding path, and
`tool/verify_quiz_bank.dart` fails the build if a re-worded fact key ever
appears.

### The men's and women's mix

Tennis is two tours, and this bank is deliberately men-leaning while still
requiring real knowledge of the women's game. The ATP scope is the largest at
roughly 43% of the bank on its own; counting the men's share of the majors,
doubles and team-event scopes it is comfortably over half. The WTA scope holds a
fixed fifth of every single band, so no category can be cleared without knowing
Graf, Serena, Navratilova and Court.

| Mode | ATP | WTA | Majors / events | Team events | Doubles | Rules / terms | World / other |
|------|----:|----:|----------------:|------------:|--------:|--------------:|--------------:|
| Easy | 240 | 100 | 60 | 30 | 25 | 35 | 10 |
| Medium | 245 | 110 | 55 | 35 | 30 | 15 | 10 |
| Hard | 250 | 110 | 50 | 35 | 35 | 5 | 15 |
| Global | 130 | 105 | 50 | 90 | 55 | 10 | 60 |

Totals: ATP 865, WTA 425, Majors/events 215, Team events 190, Doubles 145,
World/other 95, Rules/terms 65. **Majors and events** covers the four Grand
Slams as institutions plus the Masters 1000 / WTA 1000 / Tour Finals tier -
surfaces, venues, show courts, trophies, founding years and tournament records;
**Team events** covers the Davis Cup, the Billie Jean King Cup, Olympic tennis,
the Laver Cup, the United Cup and the Hopman Cup; **World / other** covers
wheelchair tennis, junior slams, the ITF and Challenger tiers, governing bodies
and tennis geography. Every 100-question band carries the same scope
proportions.

ATP steps back sharply in GLOBAL, from 50 questions a band to 26, while team
events climb from 7 to 18 and the wider tennis world from 3 to 12. That is what
makes the world capstone read as a different category rather than "hard mode
again".

### How the two difficulty axes differ

The **mode** sets how broad your knowledge has to be; the **band** sets how
obscure the fact is.

| Axis | What it changes |
|------|-----------------|
| Easy | Recognition: terminology, surfaces, player nationalities, which city hosts a slam |
| Medium | Structure: tours, rankings, the Masters / 1000 tier, title counts, championship winners |
| Hard | Deep cuts: individual finals, all-time records, one-off winners, junior and wheelchair champions |
| Global | World breadth: Davis and Billie Jean King Cup, the Olympics, doubles, the ITF tiers, tennis geography |

The per-band ordering is listed in **Difficulty Bands** above.

### Gender disambiguation

Every singles and doubles prompt names its discipline. "Who won the 2019
Wimbledon title?" would be ambiguous between the men's and women's draws, so the
bank always asks for the men's singles, the women's singles, the men's doubles,
the women's doubles or the mixed doubles title.

### Sourcing and audit

Facts are frozen at **21 August 2026**. The tour record is authored through the
end of the **2025 season**; no 2026 results appear, because the 2026 majors fell
outside what could be verified against a primary source at the cutoff. No
time-relative wording is allowed, and every time-sensitive prompt names its year
or event.

`tool/generate_tennis_quiz.dart` builds the four runtime assets and the
development-only `tool/quiz_audit/tennis.json` ledger from 19 official primary
sources - the ATP Tour, the WTA, the Australian Open, Roland-Garros, Wimbledon,
the US Open, the Davis Cup, the Billie Jean King Cup, the ITF (rules, World
Tennis Tour and wheelchair tennis), the Olympics, the Laver Cup and the
International Tennis Hall of Fame. Every audit entry stores the canonical
answer, a unique fact key, scope, competition, season, difficulty position and
at least two source references including at least one primary.

The verifier checks all 2,000 audit entries against the runtime answer keys,
exact scope totals, source metadata, distinct fact keys, and an exact
25/25/25/25 answer-position split in every 100-question band.

Sets past the authored range render as SOON in the ladder rather than falling
back to placeholder questions.

## Rewards and Progression
Tennis Quiz is XP-only. It does not award coins.

Every correct answer pays, whatever the final score:

```dart
totalXp = correctAnswers * mode.reward
```

The XP ledger entry uses source `quiz`, title `TENNIS QUIZ REWARD`, and details like `EASY SET 1`. Note that the tennis *quiz* banks into the shared Quiz track via `XpTransactionSource.quiz`; `XpTransactionSource.tennis` belongs to Tennis Rally and is a different track.

The reveal credits XP before the cinematic finishes, so skipping or leaving the reveal does not change the reward outcome.

## Persistence

Tennis Quiz persists personal progress through `SecureGameStorage` under the key `pd_quiz_progress_tennis_v1`.

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
| Asset-backed question bank loader and cache | [`lib/services/quiz_bank.dart`](../../../lib/services/quiz_bank.dart) |
| Trivia set indexing and deterministic set building | [`lib/services/quiz_trivia_bank.dart`](../../../lib/services/quiz_trivia_bank.dart) |
| Quiz progress loading and result persistence | [`lib/blocs/quiz/quiz_cubit.dart`](../../../lib/blocs/quiz/quiz_cubit.dart) |
| Quiz state fields and derived getters | [`lib/blocs/quiz/quiz_state.dart`](../../../lib/blocs/quiz/quiz_state.dart) |
| Tennis Quiz shell | [`lib/screens/quiz/quiz_hub.dart`](../../../lib/screens/quiz/quiz_hub.dart) |
| Lobby, category list, set ladder, entry cost handling | [`lib/screens/quiz/quiz_lobby_screen.dart`](../../../lib/screens/quiz/quiz_lobby_screen.dart) |
| Live question flow, submit, retry, and XP dispatch | [`lib/screens/quiz/quiz_play_screen.dart`](../../../lib/screens/quiz/quiz_play_screen.dart) |
| Quiz reveal overlay | [`lib/screens/quiz/widgets/quiz_reveal.dart`](../../../lib/screens/quiz/widgets/quiz_reveal.dart) |
| Games-tab tile and route | [`lib/screens/predictions/prediction_home_screen.dart`](../../../lib/screens/predictions/prediction_home_screen.dart) |
| Tennis asset and audit generation | [`tool/generate_tennis_quiz.dart`](../../../tool/generate_tennis_quiz.dart) |
| Structural, coverage, and audit validation | [`tool/verify_quiz_bank.dart`](../../../tool/verify_quiz_bank.dart) |
| Quiz progress storage | [`lib/services/secure_storage_service.dart`](../../../lib/services/secure_storage_service.dart) |

## Tests

- [`test/quiz_cubit_test.dart`](../../../test/quiz_cubit_test.dart)
- [`test/quiz_set_flow_test.dart`](../../../test/quiz_set_flow_test.dart)
- [`test/game_hero_cta_test.dart`](../../../test/game_hero_cta_test.dart)
- [`test/tennis_widget_test.dart`](../../../test/tennis_widget_test.dart)
- `tool/verify_quiz_bank.dart`

## Gratification and Feedback

Answer locks, correct/wrong reveals, the visible XP pot, mastery stars, the set
result cinematic, new-best treatment, and level progress give every run a clear payoff.

## Visible States

Loading, locked/unlocked set, affordable/unaffordable entry, unanswered/locked
answer, correct/wrong reveal, incomplete exit, and completed set states are represented.

## Planned Scope and Current Limitations

- **BUILT:** The full 2,000-question audited Tennis ladder on the shared quiz
  system, with a 25-coin entry, persisted stars/best scores, and Quiz-track XP.
- **PLANNED:** Any additional categories or live question service require
  explicit scope; current questions ship locally.
