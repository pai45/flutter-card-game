# Guess the Driver

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Daily F1 mystery, guesses, paid team hint, archive, and local records

## Product Purpose

Guess the Driver is the F1 daily ritual: identify the winner of a historical
race from the year, circuit, and progressively revealed clues before ten hearts
run out.

## Where It Lives

Open **Sports -> Games -> F1 -> Guess the Driver**. The home surface shows the
daily CTA, win streak, win rate, best hearts, wins, and 30-day logs.

## Player Flow

1. Open today's deterministic race mystery.
2. Read the year and circuit, then search the driver list.
3. Submit a driver guess.
4. A correct guess wins immediately; a wrong guess spends one of ten hearts and
   advances the clue state.
5. Optionally spend 25 Oz Coins to decrypt the team without consuming a heart.
6. Finish on a correct answer, zero hearts, or skip.
7. Reveal the driver and save the result to daily logs.

## Mechanics and Rules

The daily race is deterministic from the local day key. The archive window
shows today plus the previous 29 days. The paid team hint can be unlocked once
per day and is persisted before the wallet transaction is applied. Reopening an
unfinished current-day run resumes its in-memory guesses during the session;
completed days open as review.

## Rewards and Progression
The game records local mystery wins, hearts, streak, and hint spending. The
25-coin hint writes a `guessDriverHint` coin-ledger entry. Unlike the shared
sport Guess the Player flow, Guess the Driver does not currently dispatch the
shared daily-mystery XP/streak settlement event.

## Gratification and Feedback

Wrong guesses spend a visible heart and advance the scan; the team hint plays a
decrypt confirmation without taking a life. Correct/lost results reveal the
driver with mystery-specific audio and a result overlay, then return to the
daily archive loop.

## Visible States

- Loading, today's unplayed/resumable/completed CTA, and 30-day logs
- Active guess, selected driver, wrong guess, hint locked/unlocked, low balance
- Win, loss, skip, result reveal, and historical review

## Persistence

`GuessDriverArchive` stores results by day plus team-hint day keys. Each result
stores win/loss, hearts remaining, and target driver. The player tag/wallet and
coin ledger are shared systems.

## Planned Scope and Current Limitations

- **BUILT:** Daily selection, ten-heart guessing, paid team hint, logs,
  persistence, streak/rate stats, audio, and result reveal.
- **CURRENT LIMITATION:** No shared XP or overall activity-streak credit.
- **PROTOTYPE:** Historical race data is bundled locally and day selection uses
  the device clock.
- **PLANNED:** No additional roadmap commitments are recorded.

## Implementation References

- [`lib/models/guess_driver.dart`](../../../lib/models/guess_driver.dart)
- [`lib/data/f1_guess_data.dart`](../../../lib/data/f1_guess_data.dart)
- [`lib/blocs/guess_driver/guess_driver_cubit.dart`](../../../lib/blocs/guess_driver/guess_driver_cubit.dart)
- [`lib/screens/guess_driver/guess_driver_screen.dart`](../../../lib/screens/guess_driver/guess_driver_screen.dart)

## Tests

- Daily mystery behavior is covered by the shared mystery model/cubit tests:
  [`test/daily_mystery_cubit_test.dart`](../../../test/daily_mystery_cubit_test.dart)
  and [`test/daily_mystery_ui_test.dart`](../../../test/daily_mystery_ui_test.dart).
