# Leaderboards, Rivals, History, and Statistics

> **Status:** PROTOTYPE
> **Last verified:** 2026-08-09
> **Scope:** Ranking boards, rival dossiers, game/prediction/pick histories, ledgers, and profile statistics

## Product Purpose

Competitive context answers “where do I stand?”, while history and statistics
answer “what did I do and how am I improving?”. Together they turn isolated
sessions into rivalry, accountability, and mastery.

## Where It Lives

Leaderboard is a main destination. Selecting a ranked player opens a rival
dossier/challenge surface. Profile links to prediction history, pick history,
cross-game match archive, XP history, Oz Coin history, and summary statistics;
participating game hubs expose filtered local history.

## Player Flow

1. Open a ranking type and sport/context filter.
2. Compare podium, ranked list, movement, and the pinned personal rank.
3. Inspect a rival dossier or launch an available challenge route.
4. Open personal history/statistics to review results and value movement.
5. Filter/drill into a match, prediction, pick, XP, or coin record.

## Mechanics and Rules

Leaderboard types include Match Day, Tournament, Coins, and Games with contextual
filters/scopes and individual/team boards. Rival dossiers are deterministic
local profiles built from seeded identity/XP. Game history stores bounded match
entries and round detail where a mode writes it. Predictions, picks, XP, and
coins use their dedicated records and filters.

## Rewards and Progression

These surfaces display competitive and progression outcomes; they do not mint
rewards. The owning game/settlement writes XP, coins, result, and history before
ranking/history presentation.

## Gratification and Feedback

Podiums, rank movement, “YOU” highlighting, personal rank dock, rivalry framing,
W/D/L bands, performance summaries, filter counts, and transaction deltas turn
raw records into a chaseable narrative.

## Visible States

Podium/ranked/unranked, climb/drop/held/new, individual/team, rival dossier,
empty/filter-empty, pending/final prediction/pick, detailed match, positive/
negative ledger, and local statistics states are represented.

## Persistence

Player match history, prediction/pick records, XP/coin ledgers, and participating
mode statistics persist locally. The current leaderboard and rival population
are seeded; they are not server-authoritative or cross-device.

## Planned Scope and Current Limitations

- **BUILT:** Local histories, profile summaries, transaction histories, detailed
  match archive, and rival dossier/challenge presentation.
- **PROTOTYPE:** Leaderboard ranks, rival identities, movement, podium, and team
  board use seeded data.
- **PLANNED:** Live rankings, seasons, anti-cheat, server history, real rival
  profiles, and remote challenge acceptance require backend scope.

## Implementation References

- [`lib/screens/leaderboard/leaderboard_screen.dart`](../../../lib/screens/leaderboard/leaderboard_screen.dart)
- [`lib/models/rival_dossier.dart`](../../../lib/models/rival_dossier.dart)
- [`lib/screens/profile/rival_profile_screen.dart`](../../../lib/screens/profile/rival_profile_screen.dart)
- [`lib/screens/match_history/match_history_pages.dart`](../../../lib/screens/match_history/match_history_pages.dart)
- [`lib/screens/predictions/prediction_match_history_screen.dart`](../../../lib/screens/predictions/prediction_match_history_screen.dart)
- [`lib/screens/predictions/prediction_picks_history_screen.dart`](../../../lib/screens/predictions/prediction_picks_history_screen.dart)
- [`lib/screens/profile/xp_history_screen.dart`](../../../lib/screens/profile/xp_history_screen.dart)
- [`lib/screens/profile/oz_coin_history_screen.dart`](../../../lib/screens/profile/oz_coin_history_screen.dart)

## Tests

- [`test/rival_dossier_test.dart`](../../../test/rival_dossier_test.dart)
- [`test/xp_history_widget_test.dart`](../../../test/xp_history_widget_test.dart)
