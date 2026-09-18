# StatOz / Pitch Duel Product Documentation

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Audience:** Product, design, engineering, QA, and coding agents

This folder is the canonical product source of truth for StatOz, the sports
prediction and games app whose flagship card mode is Pitch Duel. It describes
the player experience, game rules, progression, economy, design language,
persistence, current limitations, and planned scope. Runtime code remains the
authority when a discrepancy is found; the documentation must then be corrected
and recorded in the [documentation ledger](DOCUMENTATION_LEDGER.md).

## Product Purpose

This index gives contributors one verified map of the app: what players can
reach, how the major loops connect, which behavior is built or planned, and
where to verify every rule in code and tests.

## Where It Lives

This file is the entry point for product documentation. Game pages live in
`games/`, shared feature pages in `systems/`, and gamer-experience/design rules
in `design/`. The repository root README links here rather than restating features.

## Player Flow

The whole-app journey begins with identity onboarding and its welcome reward,
then cycles through predicting, placing picks, playing games, collecting and
customizing, progressing mastery/level, comparing rivals/history, and returning
for streaks, daily content, rewards, and fresh fixtures.

## Mechanics and Rules

This index owns navigation, coverage, status vocabulary, cross-system loops,
and documentation governance. Individual pages own formulas, state machines,
settlement rules, persistence, and page-level planned scope.

## Rewards and Progression

Shared progression uses per-mode XP tracks plus an aggregate level. Oz Coins,
cards/packs, streak milestones, achievements, cosmetics, histories, and typed
settlement ledgers connect the 18 game entries and prediction/pick loops. Each
linked page states its exact reward contract and exceptions.

## Status Legend

- **BUILT**: reachable, functional behavior in the current app.
- **PROTOTYPE**: functional local or demo-backed behavior that is not yet a
  production-integrated service.
- **PLANNED**: approved product scope without a reachable implementation.
- **DEPRECATED**: superseded behavior retained only for historical reference.

Pages can contain both built and planned sections, but every planned section
must be explicitly tagged.

## App Map

First launch plays WELCOME TO STATOZ, opens the **PROTOTYPE** login/signup
preview, then enters profile setup. Completing setup saves the player's identity and
awards an idempotent 1,000 Oz Coin welcome bonus with a reward animation.
Setup's single-select **home sport** is the only sport open to a new player:
the other sports sit on the sport strip as padlocked teasers that unlock for 50
Oz each, and within every sport only the first game is open. The rest unlock by
playing through that sport's **Beginner's Quest**
([Sport and Game Unlocks](systems/sport-and-game-unlocks.md)). Profiles
onboarded before this shipped keep everything open. The main app then opens the
sports hub with four persistent destinations:

- **Sports**: PREDICT, PICK, and GAMES tabs, each with sport filters.
- **Shop**: avatars, frames, banners, kits/liveries, coins, packs, and cards,
  with cross-sport catalogue search and shopping directly from results.
- **Top**: leaderboard, podium, rival, and challenge surfaces, plus username
  search across the existing local rival roster.
- **Profile**: progression, achievements, activity history, decks, collection,
  friends, following preferences, tutorials, support, and settings.

Game modes open as full-screen experiences. Every game lobby's top bar carries a
leaderboard CTA that opens that game's own board over the lobby, so standings are
reachable without leaving the tee-up. Shared systems connect them through XP
tracks, total level, Oz Coins, cards and decks, achievements, streaks, starter
packs, reward reveals, and local persistence.

## Playable Game Coverage

The current Games tab contains 18 playable entries. The three sport-specific
Guess the Player entries share one implementation and one product page.

| Sport | Game | Status | Product page |
|---|---|---|---|
| Football | Pitch Duel | BUILT | [Pitch Duel](games/pitch-duel.md) |
| Football | Penalty Shootout | BUILT | [Penalty Shootout](games/penalty-shootout.md) |
| Football | 5v5 Football Chess | BUILT | [Football Chess](games/football-chess.md) |
| Football | Football Quiz | BUILT | [Football Quiz](games/football-quiz.md) |
| Football | Football Bingo | BUILT | [Football Bingo](games/football-bingo.md) |
| Football | Guess the Player | BUILT | [Guess the Player](games/guess-the-player.md) |
| Cricket | Final Over | BUILT | [Final Over](games/final-over.md) |
| Cricket | Cricket Quiz | BUILT | [Cricket Quiz](games/cricket-quiz.md) |
| Cricket | Guess the Player | BUILT | [Guess the Player](games/guess-the-player.md#sport-variants) |
| Basketball | Hoop Duel | BUILT | [Hoop Duel](games/hoop-duel.md) |
| Basketball | Basketball Quiz | BUILT | [Basketball Quiz](games/basketball-quiz.md) |
| Basketball | Guess the Player | BUILT | [Guess the Player](games/guess-the-player.md#sport-variants) |
| F1 | Grand Prix Dash | BUILT | [Grand Prix Dash](games/grand-prix-dash.md) |
| F1 | Motorsport Quiz | BUILT | [Motorsport Quiz](games/motorsport-quiz.md) |
| F1 | Guess the Driver | BUILT | [Guess the Driver](games/guess-the-driver.md) |
| Tennis | Tennis Rally | BUILT | [Tennis Rally](games/tennis-rally.md) |
| Tennis | Tennis Quiz | BUILT | [Tennis Quiz](games/tennis-quiz.md) |
| Tennis | Guess the Winner | BUILT | [Guess the Winner](games/guess-the-winner.md) |

## Product Systems

| System | Status | Product page |
|---|---|---|
| Match discovery/search, predictions, sport STATS (including Cricket innings race/run-rate), quizzes, scoreline contests, and settlement | BUILT / PROTOTYPE DATA | [Predictions](systems/predictions.md) |
| Season-aware league and team hubs: TABLE, player LEADERS/dossiers, tappable club STATS, GAMES, PICKS, plus per-club MATCHES/PREDICTIONS/PLAYERS (EPL, LaLiga, IPL) | BUILT / SNAPSHOT + LIVE ESPN DATA | [Predictions](systems/predictions.md) |
| F1 league hub: TABLE (WDC/WCC), ROUNDS, STATS, match-card GAMES and PICKS | BUILT / ESPN STATS + EXISTING APP MARKETS | [Predictions](systems/predictions.md#f1-championship-hub--built) |
| Prediction feedback, rewards, daily quests, and planned accuracy streaks | BUILT / PLANNED | [Prediction Gamification](systems/prediction-gamification.md) |
| Outcome markets, positions, settlement, and payouts | BUILT / PROTOTYPE DATA | [Picks](systems/picks.md) |
| Per-mode XP tracks and aggregate player level | BUILT | [Progression and Leveling](systems/progression-and-leveling.md) |
| Home sport, locked sports (50 Oz unlock), per-sport game ladders, and the Beginner's Quest | BUILT | [Sport and Game Unlocks](systems/sport-and-game-unlocks.md) |
| Daily activity streaks, streak shields + at-risk state, escalating streak reminder popups, three daily quests + sweep bonus, milestones, and claims | BUILT | [Streaks](systems/streaks.md) |
| Cross-app badges and unlock celebrations | BUILT | [Achievements](systems/achievements.md) |
| Cards, decks, packs, starter packs, and daily drops | BUILT | [Collections, Decks, and Packs](systems/collections-decks-and-packs.md) |
| Oz Coins, shop, cosmetics, XP/coin ledgers, and settlement | BUILT / PROTOTYPE COMMERCE | [Economy, Shop, and Ledgers](systems/economy-shop-and-ledgers.md) |
| Leaderboards, per-league player boards, rivals, challenges, and activity history | BUILT / PROTOTYPE DATA | [Leaderboards, Rivals, and History](systems/leaderboards-rivals-and-history.md) |
| Identity, onboarding, followed leagues, favorite clubs, and settings | BUILT; account entry PROTOTYPE | [Profile, Onboarding, and Settings](systems/profile-onboarding-and-settings.md) |
| Local friend bookmarks and CPU-themed challenges | BUILT / PROTOTYPE SOCIAL DATA | [Friends](systems/friends.md) |
| Invite links and demo referral rewards | PROTOTYPE | [Referrals](systems/referrals.md) |
| Tutorials, How to Play, and support | BUILT / PARTIAL COVERAGE | [Tutorials, How to Play, and Support](systems/tutorials-how-to-play-and-support.md) |

## Core Product Loops

### Predict and settle

1. Choose a sport, league, fixture, and quiz.
2. Answer one question at a time, optionally assigning available boosters.
3. Submit before lock; reopen an editable review until kickoff.
4. Review live/finished states and reveal settled results cinematically.
5. Credit prediction XP through the shared progression ledger. Paid scoreline
   contests are the explicit exception that can also pay Oz Coin prizes.

### Play, master, and collect

1. Choose one of the 18 game entries.
2. Claim a sport starter pack when the mode requires a roster or deck.
3. Play a short, readable session with live HUD feedback and decisive result
   beats.
4. Receive XP, coins where applicable, stats, streak activity, and achievement
   progress.
5. Improve the relevant mastery track, collection, loadout, and personal bests.

### Return and progress

1. Complete predictions, picks, games, or daily mysteries.
2. Extend activity streaks and unlock milestone claims.
   The streak hub (opened from any top-bar flame, the Trending quest tile, or a
   Profile streak badge) has four tabs: TODAY quests, per-mode STREAKS, the
   CALENDAR, and the road-to-365 MILESTONES. Complete three daily quests for up to 50
   extra Oz Coins; predictions and picks each have a game alternative. The
   Daily Sweep forges a streak shield (bank of 2) that covers a missed day.
3. Claim the 24-hour daily drop and open packs.
4. Review XP and Oz Coin histories, achievements, leaderboards, rivals, and
   career statistics.
5. Return through a reward, challenge, fresh fixture, or daily puzzle rather
   than a flat task list.

## Product Design

- [Gamer-First Experience Principles](design/experience-principles.md)
- [Cyber UI Design System](design/cyber-ui-design-system.md)
- [Motion, Audio, Haptics, and Celebration](design/motion-audio-haptics.md)
- [Screen and State Catalog](design/screen-state-catalog.md)

The design contract is dark, fast, cyber-HUD, and reward-led. Shared UI is
reused before new components are introduced, and every meaningful action must
produce clear feedback or gratification. Sport identity is consistent across
tabs, onboarding, Trending, collections, shop, and leaderboards: Football is
cyan, Cricket white, Basketball yellow, Tennis green, and Motorsport red.
Semantic state, reward, team, and game-mode colors remain separate. Data-dense
surfaces share one language:

Team identity comes from the checked-in competition-scoped palette. Logos use
the supplied primary, secondary, and label colors without substitution, while
team-related UI uses a generated hue-related `secondaryTextColor` that reaches
at least 4.5:1 on every standard dark surface. Match context selects the exact
competition variant before deterministic aliases and closest-color fallback;
semantic LIVE, danger, success, reward, and selected states still win.

[Picks](systems/picks.md) market detail and the [Predictions](systems/predictions.md)
match STATS tab are built from the same chart system and data-page furniture, so
a match report and a pick market read as one surface.

The favorite club chosen in
[Profile and onboarding](systems/profile-onboarding-and-settings.md) orders and
marks the [Predictions](systems/predictions.md) match feed: the club's fixture is
pinned above the rest of its match day and marked wherever its card renders.
Nothing is filtered away, and a player who follows no club sees the feed
unchanged.

## Gratification and Feedback

Across the app, small decisions receive immediate input feedback, game actions
resolve through readable beats, and meaningful outcomes use proportionate
reward reveals. Pack unpacking, settlement cinematics, result phases, level-up,
achievement, streak, referral, onboarding, and shop acquisition moments are the
shared payoff patterns. Skipping presentation never changes settlement.

## Visible States

Canonical feature pages own their loading, available/locked, active, result,
reward, empty, error, and review states. This index identifies current coverage
and status; it does not replace those state contracts.

## Persistence

Current product state is primarily local through `SecureGameStorage` and
feature repositories. Pages distinguish durable results/ownership/ledgers from
session-only presentation and identify mock/seeded data that is not a remote service.

## Planned Scope and Current Limitations

- **BUILT:** All 18 Games-tab entries and the shared systems linked above are
  reachable as described, subject to page-level status qualifications.
- **PROTOTYPE:** Social graphs, leaderboard populations, several data feeds,
  contest fields, and pick markets are local or seeded.
- **PLANNED:** Backend, network, live-data, and additional game/design ideas are
  commitments only where a page explicitly tags them `PLANNED`.

## Implementation References

- [`lib/main.dart`](../../lib/main.dart)
- [`lib/screens/predictions/prediction_home_screen.dart`](../../lib/screens/predictions/prediction_home_screen.dart)
- [`lib/blocs/game/game_bloc.dart`](../../lib/blocs/game/game_bloc.dart)
- [`lib/models/progression.dart`](../../lib/models/progression.dart)
- [`lib/services/secure_storage_service.dart`](../../lib/services/secure_storage_service.dart)

## Tests

- [`test/sport_modules_test.dart`](../../test/sport_modules_test.dart)
- [`test/progression_tracks_test.dart`](../../test/progression_tracks_test.dart)
- [`test/streak_bloc_test.dart`](../../test/streak_bloc_test.dart)
- [`test/daily_mystery_cubit_test.dart`](../../test/daily_mystery_cubit_test.dart)

## Documentation Contract

- Start new pages from [the document template](DOCUMENT_TEMPLATE.md).
- Record every product-document update in the
  [documentation ledger](DOCUMENTATION_LEDGER.md).
- Update this index whenever navigation, game coverage, system coverage, or
  cross-feature behavior changes.
- Mark planned ideas explicitly; never describe an unbuilt feature as shipped.
- Verify rules and formulas against current code and tests, then include the
  relevant implementation references.
- Historical documents live under `docs/archive/legacy/` and are never product
  sources of truth. Canonical pages do not link to archived material.

## Supporting Technical References

- [Round resolution and match settlement](../technical/round-resolution.md)
- [Audio cue catalog](../audio/CUE_CATALOG.md)
- [IPL player data sheet](../data/ipl_players.md)
- [League stats field inventory (EPL and LaLiga)](../data/league-stats-field-inventory.md)
