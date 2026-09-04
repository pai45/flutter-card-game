# Predictions

> **Status:** BUILT
> **Last verified:** 2026-08-30
> **Scope:** Fixture quiz discovery, submission/editing, boosters, lock lifecycle, XP settlement, and paid Scoreline contest

## Product Purpose

Predictions turn real/simulated fixtures into a before-and-after game loop:
build a potential reward by answering a short quiz, lock a point of view before
kickoff, then return for a staged truth-and-reward reveal.

## Where It Lives

**PREDICT** is the default tab in the PREDICT / PICK / GAMES hub. Fixtures are
grouped by date and league; match, league, standings, history, leaderboard, and
linked-pick surfaces provide context around the quiz. A fixed search action on
the MATCH sport strip opens an all-sports team and league fixture finder without
changing the selected sport or match day.

## Player Flow

1. Browse the selected match day, or search available feeds by team/league name
   or code, and open an eligible fixture/quiz.
2. Answer exact-score or multiple-choice questions one at a time.
3. Optionally place one 2× and one 1.5× booster on answered questions.
4. For a fresh paid Scoreline contest, pay the 25 Oz Coin entry fee once.
5. Submit; record prediction activity for the daily streak and achievements.
6. Edit before lock, review read-only after lock/live, and return when finished.
7. Reveal settled question verdicts, XP, community comparison, and contest rank/prize.

## Mechanics and Rules

Lifecycle states are open/editable, locked/read-only, finished-settleable, and
settled. A potential-XP ticker counts only answered questions; a default 0-0 does
not count until the score control is touched. Boosters can move until lock and
pay only on correct answers. A voided question cannot block whole-quiz settlement.

Settlement compares stored answers with question results, credits only fresh
settlements, persists the final prediction, and makes the reveal skippable
without changing rewards.

## Rewards and Progression

Standard quizzes are XP-only: correct answers pay their configured reward into
the **Predictions** track, boosters multiply correct-answer XP, wrong answers pay
zero, and no XP is subtracted.

The explicit coin exception is the paid **Scoreline Quiz** contest. Fresh entry
costs 25 Oz Coins; at settlement the seeded contest ranks the player and pays
2,000/1,000/500 coins for first/second/third, otherwise zero. Both entry and
prize are idempotent. This exception must not be generalized to free quizzes.

## Gratification and Feedback

Question staging, potential-pot pulses, booster placement, submission summary,
results-ready card treatment, sequential verdict flips, XP count-up, perfect
quiz treatment, crowd comparison, contest podium/prize, progress fill, and
level-up handoff create the prediction payoff.

The default Trending feed's FUTURE/PICK market tiles show a pulsing "hot"
delta chip when the leader's latest tick swings by 5+ percentage points on a
market that hasn't already settled — reusing the shared `CyberProgressBar`/
`CyberPulse` components rather than a bespoke meter.

The match STATS tab uses sport-specific report HUDs built on the **pick market
detail language** (see `design/cyber-ui-design-system.md`), so a match report and
a pick market read as one surface.

Every sport's OVERVIEW opens with a **match pulse hero**: a chamfered header
carrying sport/status pills, the fixture, and the match's single most important
number as a large tabular figure in the leading side's colour, with a movement
chip beside it — football shows territorial control and live pressure swing,
cricket the chase score and the gap between actual and required run rate,
basketball the favoured side's win chance and its swing inside the current
quarter. Below it, sections are separated by hairline headings rather than
repeated telemetry panels, and each home-vs-away metric is a tappable
market-style outcome row with a split meter.

Charts are interactive. Every graph can be **dragged to scrub**: a dashed
playhead and marker follow the finger with selection haptics, and the legend
reads every series out at that point plus its context — the minute, the over, or
the game clock. Each chart carries range tabs and expands to a full-screen view.

- **Football MOMENTUM** — two-sided pressure trace (FULL / 1ST HALF / 2ND HALF),
  goals pinned as markers, peak-pressure KPIs. Scrubbing reads both sides'
  pressure at a minute.
- **Cricket RACE** — both innings worms on one axis (20 OV / POWERPLAY / DEATH)
  with wicket markers; scrubbing reads *both* scoreboards at the same over.
- **Cricket CHASE** — actual run rate against required run rate
  (ALL BALLS / BOUNDARIES / FINAL OVER) with boundary and wicket markers, plus a
  chase readout and ball-pressure log.
- **Basketball FLOW** — win probability (GAME / H1 / H2 / CLUTCH) with turning
  points as markers, and a scoring map filtered by ALL / HOME / AWAY / 3PT. The
  scoring map plots every coordinate-bearing made field goal on a drawn NBA half
  court (lane, free-throw circle, restricted arc, backboard and rim, and the
  three-point line with its corner runs), cropped just past the arc because no
  shot is taken from deeper. The feed normalises both sides onto one basket, so
  the rim is the coordinate origin and team colour is what separates them: a
  filled dot is a two, a hollow ring is a three, and a legend names both sides.
  The court itself never glows — it is a static stat surface.

Football also reveals events, confirmed lineups and commentary; basketball plays,
box scores, rosters and injuries; cricket scorecards, match notes, ball
commentary and published squads. Selection haptics, a marker-crossing click, a
hero count-up and a one-shot graph reveal provide feedback, while glow stays
reserved for the chart during its reveal — one focal element per tab.

## Visible States

Loading/empty fixture board, upcoming available, drafted/submitted, editable,
locked/live, result verifying, settleable, settled, voided question, contest
affordable/unaffordable/paid, and result-reveal states are represented. Search
also represents cross-sport scanning, partial-feed, guidance, no-result, grouped
team/league result, and matching-fixture states.
Sport report views also represent complete bundled packages and partial ESPN
feeds, with contextual empty states for missing flow, event, scorecard,
commentary, lineup, roster, and squad data.

## Persistence

Predictions, answers, multipliers, contest entry/rank/prize, status, and
settlement result persist through the prediction repository/storage path.
Progression, wallet, ledgers, streaks, and achievements persist in their shared systems.

## Planned Scope and Current Limitations

- **BUILT:** Multi-sport fixture board, all-sports team/league fixture search,
  staged quizzes, edits/locking, boosters, XP settlement/reveal, histories,
  activity streak recording, achievements, and the paid Scoreline contest
  exception.
- **PROTOTYPE:** Fixtures, votes, standings, contest field, and leaderboard data
  are currently local/mock-backed. The bundled Fulham–Chelsea EPL,
  Spurs–Knicks NBA Finals, and RCB–Gujarat IPL Final packages are normalized
  reference fixtures; the same report views continue to accept partial ESPN
  enrichment without treating these packages as live providers. The NBA Finals
  Game 5 and RCB–Gujarat fixtures retain their supplied local start times but
  rebase to the player's current local date whenever the fixture catalog is
  read, keeping both completed reference matches in the TODAY basketball and
  cricket boards across daily rollover.
- **PLANNED:** Live feeds, server locks, authoritative results/contest ranks,
  and cross-device synchronization require backend scope.

## Implementation References

- [`lib/models/prediction.dart`](../../../lib/models/prediction.dart)
- [`lib/blocs/prediction/prediction_cubit.dart`](../../../lib/blocs/prediction/prediction_cubit.dart)
- [`lib/screens/predictions/prediction_home_screen.dart`](../../../lib/screens/predictions/prediction_home_screen.dart)
- [`lib/screens/predictions/match_search_screen.dart`](../../../lib/screens/predictions/match_search_screen.dart)
- [`lib/screens/predictions/match_prediction_screen.dart`](../../../lib/screens/predictions/match_prediction_screen.dart)
- [`lib/screens/predictions/widgets/settlement_reveal.dart`](../../../lib/screens/predictions/widgets/settlement_reveal.dart)
- [`lib/screens/predictions/widgets/trending_match_bento.dart`](../../../lib/screens/predictions/widgets/trending_match_bento.dart)
- [`lib/screens/predictions/widgets/football_match_stats_view.dart`](../../../lib/screens/predictions/widgets/football_match_stats_view.dart)
- [`lib/screens/predictions/widgets/basketball_match_stats_view.dart`](../../../lib/screens/predictions/widgets/basketball_match_stats_view.dart)
- [`lib/screens/predictions/widgets/cricket_match_stats_view.dart`](../../../lib/screens/predictions/widgets/cricket_match_stats_view.dart)
- [`lib/screens/predictions/trending_hub_catalog.dart`](../../../lib/screens/predictions/trending_hub_catalog.dart)

## Tests

- [`test/services/prediction_quiz_engine_test.dart`](../../../test/services/prediction_quiz_engine_test.dart)
- [`test/match_prediction_screen_test.dart`](../../../test/match_prediction_screen_test.dart)
- [`test/prediction_home_day_navigation_test.dart`](../../../test/prediction_home_day_navigation_test.dart)
- [`test/match_search_screen_test.dart`](../../../test/match_search_screen_test.dart)
- [`test/football_match_package_service_test.dart`](../../../test/football_match_package_service_test.dart)
- [`test/football_match_stats_view_test.dart`](../../../test/football_match_stats_view_test.dart)
- [`test/basketball_cricket_match_package_service_test.dart`](../../../test/basketball_cricket_match_package_service_test.dart)
- [`test/basketball_cricket_match_stats_view_test.dart`](../../../test/basketball_cricket_match_stats_view_test.dart)
