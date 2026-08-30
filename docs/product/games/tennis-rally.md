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
unlocks the first athlete. The hub exposes resume, five modes, athlete choice,
difficulty, career, trophies, mastery, achievements, and tennis-specific
settings. Supplied athlete portraits resolve by roster ID across collectible
cards and tennis shop avatars; athletes without supplied art retain the existing
fallback treatment.

## Player Flow

1. Claim the starter athlete if required.
2. Choose Quick Match, Tournament, Endless Rally, Target Practice, or Training.
3. Select an owned athlete and difficulty where the mode requires it.
4. Review the matchup and controls, then serve and rally in the 2D court.
5. Build points through tennis scoring, games, deuce/advantage, and tiebreaks.
6. Resume an interrupted supported match or finish the current session.
7. Settle XP, coins where applicable, athlete mastery, achievements, career
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

- Loading, starter-pack gate, landing, resume, selection, preview, and settings
- Training lesson selection, tournament bracket, active match, pause/resume
- Serve, rally, point complete, game/set/tiebreak complete, and practice finish
- Win/loss, reward settlement, achievement/trophy updates, rematch, and exit

## Persistence

`TennisProfile` stores settings, selected athlete, difficulty, career totals,
mastery, achievements, trophies, practice records, anti-farming signature,
settled IDs, and tournament state. A separate snapshot stores resumable match
state. Shared storage owns the starter pack, cards, XP and coin ledgers.

## Planned Scope and Current Limitations

- **BUILT:** Five modes, scoring engine, resume snapshot, tournament, training,
  mastery, achievements, settings, XP, coins, stats, and anti-farming rules.
- **PROTOTYPE:** Local CPU play and local career only; no online opponents.
- **PLANNED:** No additional roadmap commitments are recorded.

## Implementation References

- [`lib/models/tennis.dart`](../../../lib/models/tennis.dart)
- [`lib/blocs/tennis/tennis_cubit.dart`](../../../lib/blocs/tennis/tennis_cubit.dart)
- [`lib/screens/tennis/tennis_hub.dart`](../../../lib/screens/tennis/tennis_hub.dart)
- [`lib/screens/tennis/tennis_match_screen.dart`](../../../lib/screens/tennis/tennis_match_screen.dart)

## Tests

- [`test/tennis_engine_test.dart`](../../../test/tennis_engine_test.dart)
- [`test/tennis_cubit_test.dart`](../../../test/tennis_cubit_test.dart)
- [`test/tennis_game_bloc_test.dart`](../../../test/tennis_game_bloc_test.dart)
- [`test/tennis_starter_pack_test.dart`](../../../test/tennis_starter_pack_test.dart)
- [`test/tennis_widget_test.dart`](../../../test/tennis_widget_test.dart)
