# Guess the Player

Guess the Player is StatOz's daily football mystery mode. It gives the Games tab a Wordle-like daily ritual: inspect a player's career timeline, search the player pool, spend hearts on wrong guesses, and reveal the mystery player.

## Product Purpose

Guess the Player gives users a daily lightweight challenge that focuses on player knowledge rather than match prediction, cards, or wallet stakes.

The mode is built around a single daily mystery and a persistent results archive. It currently shows an XP value in the result overlay when the user wins, but that XP is not dispatched into the shared progression ledger.

## Where It Lives

Guess the Player is opened from the **GAMES** tab in the Predictions area.

The Games tab currently includes:

- **Pitch Duel**: four-round tactical card match.
- **Penalty Shootout**: standalone spot kicks.
- **Football Quiz**: trivia set ladder.
- **Football Bingo**: daily country-by-club grid puzzle.
- **Guess the Player**: daily career-timeline mystery.
- **5v5 Football Chess**: tactical squad duel.

Opening Guess the Player launches a full-screen home surface backed by `GuessPlayerCubit`. The home screen shows today's mystery entry point, solved count, unlocked count, and access to daily logs.

## Daily Mystery

The active mystery is selected deterministically from the local date string. The selected timeline identifies a target player from the app's player-card pool.

Because the selection is local and date-based, all users on the same local date should see the same deterministic target for that install's data set, without needing backend scheduling.

## Clue Format

The main clue is a career timeline.

The timeline displays the target player's clubs in order, with club badges when the club can be matched to known followable teams. The UI also shows date ranges derived from each club spell's start year.

The player portrait is hidden during play and replaced with a mystery panel.

## User Flow

1. User opens **Predictions -> Games -> Guess the Player**.
2. Home loads the saved archive and today's daily key.
3. User taps **PLAY TODAY'S MYSTERY**.
4. The game shows the mystery avatar, career timeline, player search, and 10 hearts.
5. User searches the player pool and selects a player.
6. If the guess is correct, the game finishes as a win and saves the daily result.
7. If the guess is wrong, one heart is removed and the guess is added to the local guess list.
8. When hearts reach zero, the game finishes as a loss and saves the daily result.
9. If the user submits with no selected player, the game skips the round and saves a loss.
10. The result overlay reveals the target player and returns the user to the Guess the Player home.

If today's mystery has already been played, the home CTA changes to a review action rather than starting a fresh run.

## Hearts And Guessing

Each run starts with 10 hearts.

Wrong guesses remove one heart. Correct guesses finish immediately and preserve the remaining heart count in the daily archive. Skipping ends the run as a loss with zero hearts remaining.

The player search uses autocomplete against the available player-card list.

## Daily Logs And Archive

Guess the Player persists a simple archive by day key.

Each saved result stores:

- win/loss state
- hearts remaining
- target player name

The home screen derives:

- solved count from archived wins
- unlocked count from archived day keys plus today
- today's CTA state from whether a result exists for the active day

Daily logs can open a saved day for review. Past-day guesses are not fully replayed because the archive does not persist the guess list.

## Rewards And Progression

Guess the Player currently does not credit shared XP, coins, match history, or streak activity.

The result overlay displays `50` XP on a win, but the game screen does not dispatch a `PredictionXpAdded` event. Until that is wired, the displayed XP should be treated as UI copy rather than an applied progression reward.

Current limitations:

- No shared XP ledger entry is written.
- No coin ledger entry is written.
- No match-history entry is written.
- Guess lists are not saved in the archive.
- Past days are reviewable only from saved result state and reconstructed timeline data.

## Persistence

Guess the Player persists its archive through `SecureGameStorage`.

The cubit loads the archive on entry, adds today's day key to the unlocked list, and restores today's win/loss state if the daily result already exists.

## Implementation Reference

| Concern | Source |
|---------|--------|
| Archive and daily result model | [`lib/models/guess_player.dart`](../../lib/models/guess_player.dart) |
| Timeline data | [`lib/data/guess_player_data.dart`](../../lib/data/guess_player_data.dart) |
| Daily mystery state, guesses, hearts, finish, archive save | [`lib/blocs/guess_player/guess_player_cubit.dart`](../../lib/blocs/guess_player/guess_player_cubit.dart) |
| Full-screen Guess the Player hub | [`lib/screens/guess_player/guess_player_hub.dart`](../../lib/screens/guess_player/guess_player_hub.dart) |
| Home screen, daily CTA, solved/unlocked stats | [`lib/screens/guess_player/guess_player_home_screen.dart`](../../lib/screens/guess_player/guess_player_home_screen.dart) |
| Live mystery screen, search, hearts, result overlay | [`lib/screens/guess_player/guess_player_screen.dart`](../../lib/screens/guess_player/guess_player_screen.dart) |
| Daily logs screen | [`lib/screens/guess_player/guess_player_logs_screen.dart`](../../lib/screens/guess_player/guess_player_logs_screen.dart) |
| Result overlay | [`lib/screens/guess_player/widgets/guess_result_overlay.dart`](../../lib/screens/guess_player/widgets/guess_result_overlay.dart) |
| Guess Player archive storage | [`lib/services/secure_storage_service.dart`](../../lib/services/secure_storage_service.dart) |

Relevant tests:

- [`test/guess_player_logs_test.dart`](../../test/guess_player_logs_test.dart)
