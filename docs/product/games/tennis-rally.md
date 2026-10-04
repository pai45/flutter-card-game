# Tennis Rally

> **Status:** BUILT
> **Last verified:** 2026-08-18
> **Scope:** Tennis roster, five play modes, match engine, mastery, rewards, career, and settings

## Product Purpose

Tennis Rally is the deepest arcade-sport mode in StatOz. It combines timing,
movement, shot variety, stamina, athlete archetypes, a persistent tournament,
training, practice score attacks, mastery, and accessibility settings.

## Where It Lives

Open **Sports -> Games -> Tennis -> Tennis Rally**. A free tennis starter pack
grants the first athlete card, and the athletes you can play are the tennis
cards in your active deck. The routed hub (`TennisRallyHub`) is a single
Quick Match lobby. It shows athlete mastery, set wins, streak and a controls
brief, with **PLAY MATCH** (a random rival through matchmaking) or **RESUME
MATCH** when a suspended match exists. It also links to the Deck Builder and
to Match History, where the career numbers, trophies, athlete mastery and
achievements live. The five-mode hub with athlete, difficulty and settings
screens (`TennisRallyV2Hub`) is built and tested but not routed.

Supplied athlete portraits resolve by roster ID across collectible
cards and tennis shop avatars; athletes without supplied art retain the existing
fallback treatment.

## Player Flow

1. Claim the starter athlete if required. The hub adopts the deck's tennis cards and starter.
2. In the lobby, press **PLAY MATCH** for a Quick Match against a random rival at the saved difficulty, or **RESUME MATCH**. (Choosing Tournament, Endless Rally, Target Practice or Training, an athlete, and a difficulty exists only in the unrouted prototype hub.)
3. Pass matchmaking, then serve and rally in the 2D court.
4. Build points through tennis scoring, games, deuce/advantage, and tiebreaks.
5. Resume an interrupted supported match or finish the current session.
6. Settle XP, coins where applicable, athlete mastery, achievements, career
   statistics, and tournament advancement exactly once.

## Mechanics and Rules

- **Quick Match:** one set against a CPU athlete.
- **Tournament:** persistent eight-player bracket with three rounds.
- **Endless Rally:** score attack based on rally survival.
- **Target Practice:** score attack based on target execution.
- **Training:** guided lessons with first-completion rewards.
- Shot types include normal, power, topspin, slice, lob, volley, smash, drop
  shot, defensive return, and serve.
- Tennis scoring supports love/15/30/40, deuce, advantage, games, set
  completion, and tiebreak service order.

## Rewards and Progression
Tennis Rally credits the **Tennis Rally** XP track, athlete mastery XP, and
coins for eligible wins. Quick/tournament settlement starts from 12 XP, adds
win, difficulty, grade, and performance bonuses, and applies an anti-farming
reduction to repeated Rookie matchups. Rookie/Pro/All-Star wins normally pay
20/30/40 coins; tournament wins receive a multiplier and the champion receives
an additional reward. Practice XP is capped by score, and each training lesson
pays 5 XP only on first completion.

## Gratification and Feedback

Perfect contact, aces, winners, breaks, saved break points, long rallies,
tiebreak wins, tournament advancement, trophies, mastery gains, and achievement
unlocks all provide layered HUD, sound, haptic, result, or celebration beats.
The result does not merely show a score: it grades performance and advances the
career/tournament loop.

## Visible States

- Loading, starter-pack gate, match lobby (athlete ready or match saved), matchmaking, and resume
- Prototype only: landing, mode selection, athlete selection, training lessons, tournament bracket, and settings
- Active match and pause/resume
- Serve, rally, point complete, game/set/tiebreak complete, and practice finish
- Win/loss, reward settlement, achievement/trophy updates, rematch, and exit

## Persistence

`TennisProfile` stores settings, selected athlete, difficulty, career totals,
mastery, achievements, trophies, practice records, anti-farming signature,
settled IDs, and tournament state. A separate snapshot stores resumable match
state. Shared storage owns the starter pack, cards, XP and coin ledgers.

## Planned Scope and Current Limitations

- **BUILT:** Five-mode engine and settlement, scoring engine, resume snapshot,
  mastery, achievements, XP, coins, stats, and anti-farming rules. The routed
  hub is the Quick Match lobby, with the career board in Match History.
- **PROTOTYPE:** `TennisRallyV2Hub` (mode picker, athlete and difficulty
  select, training lab, tournament bracket, settings) is built and tested
  but not routed. It still carries old-roster leftovers and a debug
  `ListTile` assertion on its settings view.
- **CURRENT LIMITATION:** In the shipped lobby, PLAY MATCH fires its haptic
  and start cue twice; REMATCH on the result returns to the lobby; the
  rival's matchmaking badge shows the player's level; and the career board
  lists all 100 roster athletes' mastery before recent matches.
- **PROTOTYPE:** Local CPU play and local career only; no online opponents.
- **PLANNED:** No additional roadmap commitments are recorded.

## Implementation References

- [`lib/models/tennis.dart`](../../../lib/models/tennis.dart)
- [`lib/blocs/tennis/tennis_cubit.dart`](../../../lib/blocs/tennis/tennis_cubit.dart)
- [`lib/screens/tennis/tennis_hub.dart`](../../../lib/screens/tennis/tennis_hub.dart)
- Technical: [Tennis Rally port](../../technical/tennis-rally-port.md) ·
  [Tennis Rally hub port](../../technical/tennis-rally-hub-port.md)
- [`lib/screens/tennis/tennis_match_screen.dart`](../../../lib/screens/tennis/tennis_match_screen.dart)

## Tests

- [`test/tennis_engine_test.dart`](../../../test/tennis_engine_test.dart)
- [`test/tennis_cubit_test.dart`](../../../test/tennis_cubit_test.dart)
- [`test/tennis_game_bloc_test.dart`](../../../test/tennis_game_bloc_test.dart)
- [`test/tennis_starter_pack_test.dart`](../../../test/tennis_starter_pack_test.dart)
- [`test/tennis_widget_test.dart`](../../../test/tennis_widget_test.dart)
