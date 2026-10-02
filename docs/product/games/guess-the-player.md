# Guess the Player

> **Status:** BUILT
> **Last verified:** 2026-10-01
> **Scope:** Shared football, cricket, and basketball daily-player mystery variants

## Product Purpose

Guess the Player is a daily knowledge ritual: decode a career path, manage a
limited set of guesses, and identify the mystery athlete. One shared product
and state model serves football, cricket, and basketball with sport-specific
data, labels, visuals, and audio profiles.

## Where It Lives

The Games tab exposes **Guess Player** under Football, Cricket, and Basketball.
Each entry opens `GuessPlayerHub` with its sport, producing an independent
sport-keyed daily archive and settlement identity.

## Player Flow

1. Open today's mystery for the selected sport.
2. Review the hidden athlete and progressively revealed career timeline.
3. Search the sport's card/player pool and submit one of six free guesses.
4. A wrong guess consumes an attempt and reveals more route information.
5. Optionally buy profile intel or one final restored guess with Oz Coins.
6. Win by identifying the athlete, give up, or lose when attempts expire.
7. See the debrief, XP/score result, archive update, and streak settlement.

## Mechanics and Rules

The daily puzzle is selected deterministically from a local date key and the
sport's puzzle pool. Runs begin with six attempts. A correct guess scores
`attempts remaining × 100` and earns `20 + attempts remaining × 5` XP. Each
position and affiliation/team intel hint costs 25 coins. Once the six free
attempts are exhausted, a single extra guess can be restored for 25 coins.
Purchased hints and guesses persist before the wallet spend is presented.

The clue language adapts by sport: football emphasizes nationality/club route,
while cricket and basketball use their relevant team/role data. The underlying
archive, result, hint, and settlement contracts remain shared.

The Cricket lobby uses the StatOz Cyberpunk UI kit. A case dossier shows the
current date, new/in-progress/completed status, potential or earned XP, the
number of career signals, and the time until the next daily case. PLAY TODAY,
RESUME CASE, and REVIEW RESULT route to the same puzzle flow as before. A
second section shows the real solve streak, win rate, average tries, solved and
played totals, plus the 30-day archive action. Only the main case action glows.
Football and Basketball retain their existing lobby presentation.

### Sport Variants

| Games-tab entry | Puzzle pool and presentation | Shared reward track |
|---|---|---|
| Football — Guess the Player | Football careers, clubs, position, nationality | Guess Player |
| Cricket — Guess the Player | Cricket teams and roles | Guess Player |
| Basketball — Guess the Player | Basketball teams and positions | Guess Player |

## Rewards and Progression
A win credits the calculated XP into the **Guess Player** progression track and
XP ledger. Completed daily mysteries record `guessPlayer` streak activity,
which contributes to the games/overall streak categories. Settlement uses
`guess-player:<sport>:<day>` identity, so reopening the result cannot pay twice.
Losses award zero XP. The mode does not pay coins; hints/extra attempts spend them.

## Gratification and Feedback

Wrong/correct/duplicate cues, haptics, clue decrypts, heart/attempt pressure,
sport-specific audio, a staged debrief, score and XP count-ups, and archived
performance make the short daily loop feel consequential.
The Cricket lobby's primary action uses the kit's press, sound and haptic cues;
the archive uses its quieter secondary action.

## Visible States

Today's locked/available/in-progress/completed states, selected guess,
wrong/correct/duplicate feedback, affordable/unaffordable intel, final-guess
offer, win/loss debrief, archive calendar/log, and settlement-pending states are
represented.

## Persistence

Each sport persists its own daily archive, guessed player IDs, attempts,
revealed clues, purchased hints, score, XP, timing, and completion status through
`SecureGameStorage`. Settlement IDs separately protect shared XP/streak credit.
The returning-career preset now saves catalog-backed daily puzzle IDs. Previously
saved `preset-<sport>-<day>` records are repaired when the archive loads: a
matching athlete's authored puzzle is used where available, otherwise that
day's scheduled puzzle is used. The result, score, XP, and dates remain in the
archive, and the repaired puzzle ID is persisted. Preset results are marked
settled so opening them cannot pay their seeded XP a second time. Unrelated
missing puzzle IDs still surface a data error.

## Planned Scope and Current Limitations

- **BUILT:** Football, cricket, and basketball variants; six-attempt daily
  puzzles; paid intel/extra guess; persistent archive; XP and streak settlement.
- **PLANNED:** Server-synchronized daily identity, cross-device archive, and
  competitive daily leaderboards require backend scope. The local date remains
  authoritative in the current build.

## Implementation References

- [`lib/models/guess_player.dart`](../../../lib/models/guess_player.dart)
- [`lib/data/guess_player_data.dart`](../../../lib/data/guess_player_data.dart)
- [`lib/blocs/guess_player/guess_player_cubit.dart`](../../../lib/blocs/guess_player/guess_player_cubit.dart)
- [`lib/screens/guess_player/guess_player_hub.dart`](../../../lib/screens/guess_player/guess_player_hub.dart)
- [`lib/screens/guess_player/cricket_guess_player_lobby.dart`](../../../lib/screens/guess_player/cricket_guess_player_lobby.dart)
- [`lib/screens/guess_player/guess_player_screen.dart`](../../../lib/screens/guess_player/guess_player_screen.dart)
- [`lib/screens/guess_player/guess_player_logs_screen.dart`](../../../lib/screens/guess_player/guess_player_logs_screen.dart)
- [`lib/blocs/game/game_bloc.dart`](../../../lib/blocs/game/game_bloc.dart)

## Tests

- [`test/daily_mystery_cubit_test.dart`](../../../test/daily_mystery_cubit_test.dart)
- [`test/daily_mystery_ui_test.dart`](../../../test/daily_mystery_ui_test.dart)
- [`test/guess_player_logs_test.dart`](../../../test/guess_player_logs_test.dart)
- [`test/progression_tracks_test.dart`](../../../test/progression_tracks_test.dart)
- [`test/cricket_guess_player_lobby_test.dart`](../../../test/cricket_guess_player_lobby_test.dart)
- [`test/guess_player_preset_recovery_test.dart`](../../../test/guess_player_preset_recovery_test.dart)
