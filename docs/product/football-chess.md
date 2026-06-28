# 5v5 Football Chess

5v5 Football Chess is StatOz's tactical grid-football mode. It turns the user's active squad into a short chess-like match: choose a formation, take one board action per turn, win duels through position and ratings, and score before the two-minute clock expires.

## Product Purpose

Football Chess gives the Games tab a deeper tactical mode than Penalty Shootout while staying faster and more board-readable than a full football simulation.

It makes the user's player cards matter in a different way: ratings influence dribbles, tackles, slides, and shots, while formation and board position decide which actions are available. It shares the app's progression economy through XP, but it currently does not pay coins or write match-history entries.

## Where It Lives

Football Chess is opened from the **GAMES** tab in the Predictions area.

The Games tab currently includes:

- **Pitch Duel**: four-round tactical card match.
- **Penalty Shootout**: standalone spot kicks.
- **Football Quiz**: trivia gauntlet.
- **Football Bingo**: country-by-club grid puzzle.
- **5v5 Football Chess**: tactical squad duel.

Opening Football Chess launches a full-screen lobby owned by `FootballChessCubit`. The lobby shows lifetime record, lets the user choose a formation, and starts the match flow.

## Entry Requirements

Football Chess shares the starter-pack gate used by the deck-based games. If the starter pack has not been claimed, entering Football Chess triggers starter-pack opening before the mode launches.

The live Football Chess squad uses only the active deck's five player cards:

- 2 attackers
- 2 defenders
- 1 goalkeeper

Action cards are not used in Football Chess. The lobby blocks kickoff until the active deck has the required five-player shape.

## End-To-End User Flow

1. User opens **Predictions -> Games -> 5v5 Football Chess**.
2. If needed, the starter-pack flow runs first, then the Football Chess lobby opens.
3. Lobby loads the user's persisted Football Chess stats: wins, losses, draws, and current streak.
4. User chooses one of four formations: Box, Diamond, High Line, or Low Block.
5. User taps **FIND MATCH**.
6. The mode validates the active squad, creates a level-scaled CPU opponent, and opens the matchmaking cinematic.
7. Matchmaking scans the opponent-name pool, locks onto a CPU rival, and reveals both five-player squads.
8. User taps **KICKOFF**.
9. The live match opens with a coin toss. The user calls heads or tails.
10. Toss winner kicks off and receives possession.
11. Teams alternate one action at a time until the match clock reaches full time.
12. Goals trigger a celebration, increment the score, reset both squads to their starting formations, and give kickoff to the conceding side.
13. At full time, the result overlay shows verdict, scoreline, XP, MVP when available, and goal log.
14. The mode records local Football Chess stats and adds XP to the shared progression ledger.
15. User chooses **PLAY AGAIN** or **EXIT**.

Leaving an unfinished match stops the match clocks and discards that in-progress board state.

## Match Format

Football Chess is a two-minute match:

| Rule | Value |
|------|-------|
| Match clock | 120 seconds |
| Player decision timer | 10 seconds per player turn |
| Board size | 3 columns x 4 rows |
| On-grid pieces | 4 outfielders per side |
| Off-grid pieces | 1 goalkeeper per side |
| Turn structure | One action, then the other side acts |

The player owns the lower half of the board and attacks upward. The opponent owns the upper half and attacks downward. Keepers stand just outside the grid in their own goals and influence shot odds, but they are not selectable board pieces.

If the player decision timer expires, the cubit automatically commits a random legal player action so the match keeps moving.

## Formations

Formations define only the starting layout of the four outfielders. The goalkeeper is always off-grid.

| Formation | Code | Behavior |
|-----------|------|----------|
| Box | 2-2 | Balanced two-and-two shape. |
| Diamond | 1-2-1 | Compact centre-control shape. |
| High Line | 2-1-1 | Starts higher up the pitch. |
| Low Block | 1-1-2 | Starts closer to the user's own goal. |

The opponent receives a random formation from the same formation set.

## Board Actions

The action bar is contextual. The selected piece's side, possession, ball location, and neighboring pieces determine which verbs are available.

| Action | Who can use it | Resolution |
|--------|----------------|------------|
| Move | Most available outfielders | Move to an empty adjacent cell. If the ball carrier moves, the ball moves with them. |
| Dribble | Ball carrier with an adjacent opponent | Rating-based duel. Win swaps the carrier past the defender and keeps the ball. Loss gives possession to the defender. |
| Pass | Ball carrier with a straight clear lane to a teammate | Ball moves to the target teammate. No RNG. |
| Shoot | Ball carrier in the attacking half | Rating, distance, blockers, keeper, and momentum decide goal versus save/block. |
| Press | Defender at range who can step closer to the carrier | Moves one cell toward the ball carrier. It never wins the ball directly. |
| Tackle | Adjacent defender | Rating-and-outnumber duel. Win takes possession. Miss is safe. |
| Slide | Defender within two cells of the carrier | Higher win chance than a tackle, but a miss lets the carrier break forward and can cause a booking. |

Movement and adjacency use eight directions, so diagonal cells count.

## Duel And Shot Odds

Ratings influence all contested actions. The engine keeps these probability helpers pure so tests can assert the rules directly.

### Dribble

```dart
0.55 + (carrier.rating - defender.rating) * 0.02
```

Clamped to 20%-90%.

### Tackle

```dart
0.50 + (tackler.rating - carrier.rating) * 0.02 + outnumberBonus
```

The outnumber bonus is `0.18` for each extra adjacent defender, capped at three extra defenders. Final chance is clamped to 15%-90%.

### Slide

```dart
0.62 + (slider.rating - carrier.rating) * 0.02
```

Clamped to 20%-92%.

On a missed slide, there is a 30% foul chance. A first booking gives yellow. A second booking gives red and benches the player for two turns.

### Shoot

Shot chance starts from distance:

| Shot distance | Base goal chance |
|---------------|------------------|
| Closest shooting row | 55% |
| Farther shooting row | 30% |

Then the chance is modified by:

- blockers in the shot lane: multiplied by `0.45` per blocker
- shooter rating minus keeper rating: multiplied by `1 + diff * 0.012`
- final clamp: 3%-92%

If the shot is not a goal, possession flips to the defending side. A shot with blockers reports **BLOCKED**; otherwise it reports **SAVED**.

## Momentum

Each side has a three-pip momentum meter. Winning a duel or scoring a goal fills one pip for the acting side.

When a side starts a contested dribble, tackle, slide, or shot with full momentum, the meter is spent and that action receives a `+0.18` win-probability boost.

Momentum is side-specific. The current UI shows the player's meter at the bottom of the live match.

## CPU Opponent

Football Chess uses the same level-scaled player-picking logic as the shootout opponent generator:

```dart
targetRatingForLevel(level) = min(95, 66 + level * 2)
```

The CPU receives two attackers, two defenders, and one goalkeeper near that target rating. The displayed opponent level is near the user's current level.

CPU tactical strength scales with:

```dart
cpuSmartness(level) = min(1.0, level / 12)
```

On low-smartness rolls, the CPU chooses a random legal action. On smart rolls, it scores legal actions and prefers high-value plays such as shooting, safe tackles, useful pressure, forward passes, and productive dribbles.

## Rewards And Progression

Football Chess is XP-only. It does not award Oz Coins.

| Result | XP |
|--------|----|
| Win by 1 | +14 |
| Win by 2 | +17 |
| Win by 3 | +20 |
| Win by 4 | +23 |
| Win by 5+ | +26 |
| Draw | +6 |
| Loss | +2 |

The full-time screen dispatches a `PredictionXpAdded` event with `source: XpTransactionSource.footballChess`, title `5V5 FOOTBALL CHESS`, and details like `WIN 2-1`.

The XP ledger and profile XP history can distinguish Football Chess entries from match, shootout, quiz, prediction, pack, and daily-drop XP.

## Persistence And History

Football Chess currently persists a lightweight local record:

- wins
- losses
- draws
- current streak
- best streak

Stats are saved through `SecureGameStorage` under the Football Chess stats key.

Current limitations:

- No match-history entry is written.
- No coin ledger entry is written.
- No Football Chess-specific streak activity is written into the shared streak model.
- In-progress matches are not persisted after leaving the match screen.

## Result Screen

At full time, the result overlay shows:

- verdict: Victory, Draw, or Defeat
- final scoreline
- XP count-up and level progress
- MVP when the user scored at least one goal
- goal timeline with scorer, side, and elapsed time
- **EXIT** and **PLAY AGAIN** actions

MVP is chosen from the user's goal scorers by highest goal count.

## Implementation Reference

| Concern | Source |
|---------|--------|
| Domain enums, formations, goals, stats | [`lib/models/football_chess.dart`](../../lib/models/football_chess.dart) |
| Board cells, pieces, possession, keeper model | [`lib/games/football_chess/football_chess_board.dart`](../../lib/games/football_chess/football_chess_board.dart) |
| Legal actions, probabilities, action resolution, CPU choice | [`lib/games/football_chess/football_chess_engine.dart`](../../lib/games/football_chess/football_chess_engine.dart) |
| Match state machine, clock, toss, turns, goals, stats persistence | [`lib/blocs/football_chess/football_chess_cubit.dart`](../../lib/blocs/football_chess/football_chess_cubit.dart) |
| Match state fields and derived getters | [`lib/blocs/football_chess/football_chess_state.dart`](../../lib/blocs/football_chess/football_chess_state.dart) |
| Football Chess full-screen shell | [`lib/screens/football_chess/football_chess_hub.dart`](../../lib/screens/football_chess/football_chess_hub.dart) |
| Lobby, formation picker, deck gate, opponent creation | [`lib/screens/football_chess/football_chess_lobby_screen.dart`](../../lib/screens/football_chess/football_chess_lobby_screen.dart) |
| Matchmaking and squad faceoff | [`lib/screens/football_chess/football_chess_matchmaking_screen.dart`](../../lib/screens/football_chess/football_chess_matchmaking_screen.dart) |
| Live match screen, toss overlay, full-time XP dispatch | [`lib/screens/football_chess/football_chess_match_screen.dart`](../../lib/screens/football_chess/football_chess_match_screen.dart) |
| Live HUD, action bar, decision timer, momentum, move log | [`lib/screens/football_chess/widgets/football_chess_overlays.dart`](../../lib/screens/football_chess/widgets/football_chess_overlays.dart) |
| Full-time result overlay | [`lib/screens/football_chess/widgets/football_chess_result.dart`](../../lib/screens/football_chess/widgets/football_chess_result.dart) |
| Flame board renderer and tap handling | [`lib/games/football_chess/football_chess_game.dart`](../../lib/games/football_chess/football_chess_game.dart) |
| XP rewards, CPU smartness, opponent generation | [`lib/models/progression.dart`](../../lib/models/progression.dart) |
| Football Chess stat storage | [`lib/services/secure_storage_service.dart`](../../lib/services/secure_storage_service.dart) |

Relevant tests:

- [`test/football_chess_engine_test.dart`](../../test/football_chess_engine_test.dart)
- [`test/progression_economy_test.dart`](../../test/progression_economy_test.dart)
