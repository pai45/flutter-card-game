# Football Bingo

Football Bingo is StatOz's daily grid puzzle. It gives the Games tab a compact football-knowledge challenge: place the active player into the matching club-intersection cell, protect the run with lifelines, and complete a 3x3 grid before moving on to the next daily puzzle.

## Product Purpose

Football Bingo gives users a daily return loop that is lighter than a full match mode and more visual than Football Quiz.

The mode tests player-club knowledge with a grid made from row and column club axes. It uses persisted daily progress and the shared wallet for lifeline purchases, but it currently does not award XP or coins for completion.

## Where It Lives

Football Bingo is opened from the **GAMES** tab in the Predictions area.

The Games tab currently includes:

- **Pitch Duel**: four-round tactical card match.
- **Penalty Shootout**: standalone spot kicks.
- **Football Quiz**: trivia set ladder.
- **Football Bingo**: daily country-by-club grid puzzle.
- **Guess the Player**: daily career-timeline mystery.
- **5v5 Football Chess**: tactical squad duel.

Opening Football Bingo launches a full-screen hub backed by `FootballBingoCubit`. The mode can open today's puzzle or archived unlocked days.

## Puzzle Format

Each Football Bingo puzzle is a 3x3 grid:

| Element | Behavior |
|---------|----------|
| Rows | Club axes shown on the left side of the grid. |
| Columns | Club axes shown across the top of the grid. |
| Cells | Each cell maps to one player who matches that row/column intersection. |
| Active player | The next player the user must place into the correct cell. |

The cell order is shuffled per puzzle/day with a stable seed, so the active-player sequence is consistent for that saved daily puzzle.

## Daily Unlocks And Archive

Football Bingo uses local day keys in `yyyy-mm-dd` format.

On first load, the current day becomes the first unlocked day. Each later local day unlocks another puzzle in sequence. The archive keeps progress by day, so users can view prior unlocked days and review completed grids.

Past days are read-only when opened from the archive.

## User Flow

1. User opens **Predictions -> Games -> Football Bingo**.
2. The mode loads the daily archive and opens today's puzzle.
3. The screen shows the 3x3 grid, club axes, active player, solved count, and lifelines.
4. User taps the grid cell that matches the active player.
5. A correct tap places the player portrait into the cell and advances to the next active player.
6. A wrong tap spends one lifeline.
7. If lifelines reach zero, the board blocks further placement until the user buys a lifeline.
8. Completing all 9 cells shows the grid-complete overlay.
9. After completion, the user returns to the Bingo home/log flow and the next grid unlocks on the next local day.

## Lifelines

Each daily puzzle starts with 5 lifelines.

A wrong answer removes one lifeline. When the player has no lifelines left, the mode enters a blocked state and asks the user to buy a lifeline before continuing.

A lifeline purchase costs 25 Oz Coins. The purchase spends coins through the shared game wallet with source `footballBingoLifeline`, title `BINGO LIFELINE`, and subtitle `+1 LIFE`.

If the wallet has fewer than 25 coins, the purchase is rejected and the UI shows a short message.

## Completion State

A grid is complete when all 9 cells are solved.

Completion triggers:

- a full-screen completion overlay
- a solved-count reveal up to `9/9`
- persisted completed state for that day
- return to the parent Bingo flow through `onCompleted`

Completed grids can still be reviewed, but active placement stops once all cells are solved.

## Rewards And Progression

Football Bingo currently has no completion XP reward and no completion coin reward.

The only wallet interaction is optional lifeline spending. This keeps the mode as a daily knowledge puzzle rather than a progression-farming source.

Current limitations:

- No XP ledger entry is written on completion.
- No coin ledger entry is written on completion.
- No match-history entry is written.
- No shared streak activity is written.

## Persistence

Football Bingo persists a daily archive through `SecureGameStorage`.

For each unlocked day, the archive stores:

- puzzle id
- started-at date
- solved cell ids
- current active-player index
- remaining lifelines
- completed flag
- stable cell order ids

The cubit also supports migration from the older single-progress storage shape into the archive shape.

## Implementation Reference

| Concern | Source |
|---------|--------|
| Grid constants, day keys, progress/archive model, validation | [`lib/models/football_bingo.dart`](../../lib/models/football_bingo.dart) |
| Puzzle definitions | [`lib/data/football_bingo_puzzles.dart`](../../lib/data/football_bingo_puzzles.dart) |
| Daily archive loading, cell selection, lifeline purchase state | [`lib/blocs/football_bingo/football_bingo_cubit.dart`](../../lib/blocs/football_bingo/football_bingo_cubit.dart) |
| Bingo state fields and derived getters | [`lib/blocs/football_bingo/football_bingo_state.dart`](../../lib/blocs/football_bingo/football_bingo_state.dart) |
| Football Bingo full-screen hub | [`lib/screens/football_bingo/football_bingo_hub.dart`](../../lib/screens/football_bingo/football_bingo_hub.dart) |
| Grid UI, active-player panel, lifeline dock, completion overlay | [`lib/screens/football_bingo/football_bingo_screen.dart`](../../lib/screens/football_bingo/football_bingo_screen.dart) |
| Bingo archive and legacy progress storage | [`lib/services/secure_storage_service.dart`](../../lib/services/secure_storage_service.dart) |

Relevant tests:

- [`test/football_bingo_test.dart`](../../test/football_bingo_test.dart)
