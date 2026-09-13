# Leaderboards, Rivals, History, and Statistics

> **Status:** PROTOTYPE
> **Last verified:** 2026-09-11
> **Scope:** Ranking boards, rival dossiers, game/prediction/pick histories, ledgers, and profile statistics

## Product Purpose

Competitive context answers “where do I stand?”, while history and statistics
answer “what did I do and how am I improving?”. Together they turn isolated
sessions into rivalry, accountability, and mastery.

## Where It Lives

Leaderboard is a main destination. Every game lobby also carries a top-bar
leaderboard CTA that opens the board already filtered to that game. Selecting a
ranked player opens a rival dossier/challenge surface. Profile links to
prediction history, pick history, cross-game match archive, XP history, Oz Coin
history, and summary statistics; participating game hubs expose filtered local
history.

## Player Flow

1. Choose MATCHES or GAMES, then choose a sport from the second-row strip.
2. On MATCHES, choose the TEAMS or PLAYERS board. On PLAYERS, spin the league
   dial and choose SEASON or ALL-TIME from the same row.
3. Compare podium, ranked list, movement, and the pinned personal rank.
4. Inspect a rival dossier or launch an available challenge route.
5. Open personal history/statistics to review results and value movement.
6. Filter/drill into a match, prediction, pick, XP, or coin record.

## Mechanics and Rules

The leaderboard has two top-level boards: MATCHES and GAMES. Their two equal-width
labelled tabs use the same shared `CyberUnderlineTabs` style as the sport row:
a calm dark strip, subtle selected fill, and an animated active underline.
MATCHES retains its cyan accent and GAMES its amber accent; the raised filled
tab plates are removed. Selection feedback and board switching are unchanged.
The full sport
strip (Football, Cricket, Basketball, Motorsport, Tennis) is the second row,
so a player's sport context remains visible while changing board. MATCHES keeps
the seeded tournament player/team board and season/all-time scope.
GAMES exposes the selected sport's actual game catalogue before showing
the relevant seeded wins board: Cricket, for example, offers Final Over,
Cricket Quiz, and Guess the Player. Football, which ships the most modes, offers
six — Pitch Duel, Penalty Shootout, Football Chess, Football Bingo, Football
Quiz, and Guess the Player — so every playable lobby has a board of its own.
Rival dossiers are deterministic local
profiles built from seeded identity/XP. Game history stores bounded match
entries and round detail where a mode writes it. Predictions, picks, XP, and
coins use their dedicated records and filters.

### League dial on the PLAYERS board — BUILT / PROTOTYPE DATA

The PLAYERS board's filter row carries a league selector alongside the
SEASON/ALL-TIME segments, so "which league" and "over what span" read as one
question. SEASON is the default; the former WEEKLY scope is no longer offered.
The selector is a circular flick-to-spin wheel — a `ListWheelScrollView` laid
on its side — where one centred league is fully visible and the immediate
neighbour on each side stays partially visible, including when the first or last
catalogue entry is selected. The centred league takes its own accent, neighbours
recede and fade at the edges, and every detent ticks with a haptic and a sound.
Per the glow rule the centre notch is crisp chrome at rest and only flashes as a
league locks in. TEAMS and the GAMES board have no dial.

Each sport carries its own 2-4 league catalogue, defaulting to the league the
player follows from onboarding when there is one and otherwise the first entry:
Football EPL/LAL/SEA/BUN, Cricket IPL/T20I/BBL, Basketball NBA/EUL/WNBA,
Motorsport F1/F2/NASCAR/INDY, Tennis ATP/WTA. Leagues that already exist in the
followable catalogue are reused so ids, short codes, accents and club lists stay
consistent with onboarding and the league hubs; the rest are leaderboard-only
and are deliberately NOT followable. Each sport remembers its own selection.

Selecting a league genuinely re-ranks the seeded roster rather than relabelling
it. A stable hash of `<leagueId>:<rival>` nudges each rival's canonical base, the
board is re-sorted on that, and the score column is computed from the same
adjusted base so the ranking and the numbers agree. The result is a different
podium, a different order, and a different personal rank in every league, plus a
club/nation badge per rival carried on the existing entry subtitle (shown on the
podium tile, the rows and the pinned rank bar). When the selected league is the
one the player ranks highest in, the pinned bar reads `<CLUB> // BEST LEAGUE`.
The hash is kept to small arithmetic so the web build (where ints are JS
doubles) produces the same board as native.

### Leaderboard CTA in every game lobby — BUILT / PROTOTYPE DATA

Every game lobby's top bar carries a leaderboard action on the right: Pitch Duel,
Penalty Shootout, Football Chess, Football Bingo, the Knowledge Arena quiz lobby,
Grand Prix Dash, Hoop Duel, Final Over, Tennis Rally, and the three daily mystery
landings (Guess the Player / Driver / Winner). It is a compact chamfered plate
carrying the leaderboard glyph in the lobby's own accent — persistent chrome, so
per the glow rule it never glows.

Tapping it pushes the leaderboard **over** the lobby, opened on GAMES with that
lobby's sport and game preselected, so the player lands on their own board rather
than the default MATCHES view. Because it is pushed rather than a tab switch,
BACK returns to the lobby with the tee-up intact instead of dropping the player
out of the game. In this pushed form the bar swaps the bottom navigation for a
back action, and steps its title down a size to pay for that action's width. The
game you arrived from is named by its own selected chip in the row directly
below, so the bar does not repeat it. The board's own filters stay live, so a
player can widen out to other games or sports from there. Relatedly, the Penalty
Shootout lobby now hides its header title, as the other game lobbies already do —
the bar can't hold it beside the badge and the new action, and the hero states
the mode in display type regardless.

### Seeded demo match logs — BUILT / PROTOTYPE DATA

Every game's MATCH HISTORY page and every sport tab of the cross-sport MATCH
ARCHIVE ships pre-populated on a fresh install, so no history surface opens on
"No matches yet". Twenty-eight demo logs are seeded across the six archived
modes — Pitch Duel, Penalty Shootout, Grand Prix Dash, Hoop Duel, Final Over,
and Tennis Rally — deliberately chosen as a coverage matrix rather than a
highlight reel: between them they exercise every result label the games write
(Victory, Defeat, Draw, Podium, Points, Finished, Retired, CHASE COMPLETE,
CHASE FAILED, Completed, Lesson Complete), every mode badge including the legacy
PEN badge from the retired in-match shootout, the position readout races use in
place of a scoreline, positive/zero/negative/absent XP chips, every round-log
outcome stamp (Goal, Saved, Blocked, Missed, Foul, Red Card) in both attacking
and defending rounds, and an entry with no round data so the detail page's empty
state is reachable. Each log's XP is what the mode's own reward function would
have paid for that scoreline, so a demo never advertises a payout the game
cannot produce.

The player's own results always win. Demos are appended after stored history and
carry stable `demo-` ids, so the per-mode retention cap keeps every real result
and drops demos first as a mode fills up, and a demo persisted by a later save
is de-duplicated rather than doubled on the next launch.

Demo logs count on the history surfaces that display them — the W/D/L record
strip, win rate, and the profile GAMES band read the same list the player is
looking at — but they are flagged (`MatchHistoryEntry.isDemo`) and excluded from
the achievement snapshot, because an unlock is a reward for playing. Without
that exclusion a fresh install would fire the app-root celebration watcher for
games nobody played.

### User search ? BUILT / PROTOTYPE DATA

The Top sport-strip search icon opens USER SEARCH. It searches the complete local
`kRivalRoster` by username, excluding the self entry and ignoring sport, board,
team/player, and scope filters. It is not a live account directory.

Two or more characters trigger case-insensitive matching; surrounding/repeated
whitespace is normalized and every query word must match the username. All
matching users appear, ordered by exact name, prefix, then substring, with
alphabetical ties. Result cards reuse Friends Arena identity presentation,
showing avatar, username, level, and player tag without a search-specific rank.
VIEW opens the existing rival dossier and preserves its available challenge flow.

The route includes result counts, initial/short-query/no-result states, and
clear. Back restores the leaderboard selection. Queries are session-only;
search does not create users, change ranking, or add friends automatically.

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
- **PROTOTYPE:** Leaderboard ranks, rival identities, movement, podium, team
  board, and the per-league re-ranking behind the league dial use seeded data —
  a rival's club affiliation is derived, not a real registration. The seeded
  demo match logs are illustrative results, not games the player finished, and
  are excluded from achievement progress for that reason.
- **PLANNED:** Live rankings, seasons, anti-cheat, server history, real rival
  profiles, and remote challenge acceptance require backend scope.

## Implementation References

- [`lib/screens/leaderboard/leaderboard_screen.dart`](../../../lib/screens/leaderboard/leaderboard_screen.dart)
- [`lib/screens/leaderboard/widgets/game_leaderboard_button.dart`](../../../lib/screens/leaderboard/widgets/game_leaderboard_button.dart)
- [`lib/screens/leaderboard/widgets/league_dial.dart`](../../../lib/screens/leaderboard/widgets/league_dial.dart)
- [`lib/data/leaderboard_leagues.dart`](../../../lib/data/leaderboard_leagues.dart)
- [`lib/models/rival_dossier.dart`](../../../lib/models/rival_dossier.dart)
- [`lib/screens/profile/rival_profile_screen.dart`](../../../lib/screens/profile/rival_profile_screen.dart)
- [`lib/screens/match_history/match_history_pages.dart`](../../../lib/screens/match_history/match_history_pages.dart)
- [`lib/data/demo_match_history.dart`](../../../lib/data/demo_match_history.dart)
- [`lib/screens/predictions/prediction_match_history_screen.dart`](../../../lib/screens/predictions/prediction_match_history_screen.dart)
- [`lib/screens/predictions/prediction_picks_history_screen.dart`](../../../lib/screens/predictions/prediction_picks_history_screen.dart)
- [`lib/screens/profile/xp_history_screen.dart`](../../../lib/screens/profile/xp_history_screen.dart)
- [`lib/screens/profile/oz_coin_history_screen.dart`](../../../lib/screens/profile/oz_coin_history_screen.dart)

## Tests

- [`test/rival_dossier_test.dart`](../../../test/rival_dossier_test.dart)
- [`test/leaderboard_league_dial_test.dart`](../../../test/leaderboard_league_dial_test.dart)
- [`test/xp_history_widget_test.dart`](../../../test/xp_history_widget_test.dart)
- [`test/demo_match_history_test.dart`](../../../test/demo_match_history_test.dart)

- Search verification: `test/shop_user_search_test.dart`.
