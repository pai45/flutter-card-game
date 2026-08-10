# Guess the Winner

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Daily tennis Grand Slam mystery, guesses, archive, and local records

## Product Purpose

Guess the Winner is a daily tennis history challenge. The player identifies a
Grand Slam winner from year, tournament, category, and progressively revealed
context before ten hearts run out.

## Where It Lives

Open **Sports -> Games -> Tennis -> Guess the Winner**. The home surface shows
today's state, win streak, win rate, best hearts, wins, and daily logs.

## Player Flow

1. Open today's deterministic Grand Slam card.
2. Read the visible year, tournament, and category clues.
3. Search and submit a player name.
4. Correct answers win immediately; wrong guesses spend one of ten hearts and
   advance the clue state.
5. Finish on a correct answer, zero hearts, or skip.
6. Reveal the winner and save the result for daily review.

## Mechanics and Rules

The active card is deterministic from the local day key. The bundled history
contains men's and women's Grand Slam results. Completed days are immutable;
the archive exposes today plus the previous 29 days. Wrong guesses cannot be
reversed and the result stores remaining hearts.

## Rewards and Progression
The mode currently updates only its own archive-derived streak, win rate, best
hearts, and win count. It does not dispatch shared XP, Oz Coins, or overall
activity-streak settlement.

## Gratification and Feedback

Each miss burns a visible heart with mystery audio; the final reveal resolves
the hidden winner and returns the player to a daily-record surface. The compact
one-run-per-day structure creates the return motivation.

## Visible States

- Loading, today's unplayed/resumable/completed CTA, and 30-day logs
- Active search, selected answer, wrong guess, depleted hearts, and skip
- Win, loss, result reveal, and historical review

## Persistence

`GuessWinnerArchive` stores results by day. Each result stores win/loss, hearts
remaining, and target winner name through `SecureGameStorage`.

## Planned Scope and Current Limitations

- **BUILT:** Deterministic daily card, ten-heart guessing, logs, persistence,
  local streak/rate records, audio, and reveal.
- **CURRENT LIMITATION:** No shared XP, coin, or overall streak credit.
- **PROTOTYPE:** History is bundled locally and scheduling uses the device day.
- **PLANNED:** No additional roadmap commitments are recorded.

## Implementation References

- [`lib/models/guess_winner.dart`](../../../lib/models/guess_winner.dart)
- [`lib/data/tennis_guess_data.dart`](../../../lib/data/tennis_guess_data.dart)
- [`lib/blocs/guess_winner/guess_winner_cubit.dart`](../../../lib/blocs/guess_winner/guess_winner_cubit.dart)
- [`lib/screens/guess_winner/guess_winner_screen.dart`](../../../lib/screens/guess_winner/guess_winner_screen.dart)

## Tests

- Daily mystery lifecycle is covered by the shared mystery tests:
  [`test/daily_mystery_cubit_test.dart`](../../../test/daily_mystery_cubit_test.dart)
  and [`test/daily_mystery_ui_test.dart`](../../../test/daily_mystery_ui_test.dart).
