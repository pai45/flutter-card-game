# Predictions

> **Status:** BUILT
> **Last verified:** 2026-09-06
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

When the player's followed club plays inside the match window on screen, that
fixture is lifted out of its league group and pinned directly beneath the day
navigator under a **YOUR CLUB** header, and the rest of the day follows below.


MATCH/GAMES sport tabs, the All Sports router, and Trending sport markers use
the canonical sport identity palette: Football cyan, Cricket white, Basketball
yellow, Tennis green, and Motorsport red. Inactive tab icons retain a subdued
identity color while the selected sport owns the full-color underline. LIVE,
market-type, reward, team, and game-mode colors keep their semantic meanings.

Team branding is competition-aware. Match-aware surfaces resolve the exact
tournament palette first (including league-ID aliases such as `eng.1`/`epl`,
`ipl`, `nba`, `wnba`, and `f1`), then the supplied variant whose primary color
is closest to the feed team color. Logos retain the three supplied logo colors
exactly; surrounding team-coded UI uses the generated `secondaryTextColor`,
which clears WCAG AA against all standard dark StatOz surfaces. This applies to
fixture and search cards, prediction controls and outcomes, legends, comparison
bars, charts/maps, lineups, timelines, and team-derived frames. The persistent
match-page summary header keeps both full team names white for a stable reading
hierarchy; crests and the split score rail carry the team identity colour.
Status and reward semantics continue to take priority and team identity adds no
persistent glow.

## Player Flow

1. Browse the selected match day — the followed club's fixture first when it
   plays that day — or search available feeds by team/league name or code, and
   open an eligible fixture/quiz.
2. Answer exact-score or multiple-choice questions one at a time.
3. Optionally place one 2× and one 1.5× booster on answered questions.
4. For a fresh paid Scoreline contest, pay the 25 Oz Coin entry fee once.
5. Submit; record prediction activity for the daily streak and achievements.
6. Edit before lock, review read-only after lock/live, and return when finished.
7. Reveal settled question verdicts, XP, community comparison, and contest rank/prize.

## Mechanics and Rules

### Your club in the feed

The favorite teams chosen in onboarding (or later in Profile's clubs editor)
order and mark the match feed. See
[`systems/profile-onboarding-and-settings.md`](profile-onboarding-and-settings.md)
for how the choice is captured.

The pin is deliberately **day-scoped**: it appears only when a followed club
plays inside the window the day navigator is showing, so it can never contradict
the selected day, and the feed is byte-identical to its previous behavior for a
player who follows no club. One fixture is pinned at a time — live first, then
the next kickoff, then the most recently finished game. When more than one
followed club plays in the same window, a crest row above the pin switches
between them. The pinned fixture is removed from its league group below so it is
never shown twice.

Every other fixture involving a followed club keeps its normal place in the feed
but is sorted to the front of its league group, and that league is sorted to the
front of the day. Because the sort runs before the three-cards-per-league
preview cap, a followed club's game can never be hidden behind **VIEW MORE**.

A followed club's fixture is marked wherever its card renders — the match feed,
match search, league pages and team pages — by writing the club's own name in
its identity color and giving that color the card's resting border. The card
carries no **YOUR CLUB** badge: the fixture card is dense already, and a badge
competed with the status tag for the same top edge. Naming the club is left to
the pin header above the fixture. Live and reward-pending lifecycle colors keep
priority over the club tint, and the club cue never glows: it is persistent
chrome, not a live signal. On the Trending feed, whose tiles have a free corner
tag, a followed club's tile shows **YOUR CLUB** there unless it is LIVE.

Clubs are matched by identity, not by raw id. The EPL and IPL fixtures come from
live ESPN enrichment carrying ESPN's own numeric ids and naming, so a stored
favorite is resolved through a name/abbreviation alias table and scoped by
sport rather than by league id.

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

All MATCH Trending cards, including loading and unavailable states, share a
cyan-tinted panel background, cyan chamfered border, cyan signal line, and cyan
hard-elevation edge. LIVE, FUTURE, PREDICT, PICK, and sport identity colors stay
inside the card as semantic labels and markers rather than changing its shell.

The match STATS tab uses sport-specific report HUDs built on the **pick market
detail language** (see `design/cyber-ui-design-system.md`), so a match report and
a pick market read as one surface.

Football and cricket OVERVIEW begin directly at **MATCH INTEL**, and basketball
at **GAME INTEL**, since the persistent match header already carries the fixture
and score. The redundant overview match-pulse headers and their summary metrics
are removed for all three sports. Cricket's INNINGS GRID is also omitted from
OVERVIEW; innings detail remains in RACE and SCORECARD. Below, sections are
separated by hairline headings rather than repeated telemetry panels, and each
home-vs-away metric is a tappable market-style outcome row with a split meter.

Charts are interactive. Every graph can be **dragged to scrub**: a dashed
playhead and marker follow the finger with selection haptics, and the legend
reads every series out at that point plus its context — the minute, the over, or
the game clock. Each chart carries range tabs and expands to a full-screen view.

- **Football MOMENTUM** — two-sided pressure trace (FULL / 1ST HALF / 2ND HALF),
  goals pinned as markers, peak-pressure KPIs. Scrubbing reads both sides'
  pressure at a minute.
- **Cricket RACE** — both innings worms on one axis (20 OV / POWERPLAY / DEATH)
  with wicket markers in the batting team's identity colour; scrubbing reads
  *both* scoreboards at the same over. The chart has no duplicate RACE VERDICT
  panel; its legend already carries the live innings result. Directly beneath it,
  **INNINGS RUN RATE** switches between 1ST INNINGS and 2ND INNINGS. The selected
  batting team's resolved colour traces actual run rate; an innings with a target
  also adds REQUIRED RATE in magenta. Calm gold anchors mark every four and six
  at its legal delivery and carry a `4` or `6` badge. Close badges stagger while
  their anchors stay on the exact trace. Both charts scrub and expand full-screen.
- **Basketball SCORING RUN** — both teams' running scores climbing across the
  game on one axis (GAME / H1 / H2 / CLUTCH), drawn stepped because a score is a
  step function, with the home side filled and the away side stroked so two
  rising lines stay separable. The x-axis samples the real play at each label
  position and reads `Q1`…`Q4`; scrubbing reads *both* scoreboards at a live game
  clock (`Q3 4:12`). Lead changes ride the plot as rings in the colour of the team
  that took the lead, only the closing dozen are drawn, and only the last flip —
  the one the game never came back from — is focal. Directly beneath it a
  **SCORING EDGE** strip pays the graph off with BIGGEST LEAD (in the leading
  team's colour), LEAD CHANGES and TIES, all derived in one pass over the running
  scoreboard. Win probability is **not** surfaced anywhere in the basketball
  views: the chart is score-based, TURNING POINTS reports the point margin at each
  moment rather than a probability swing, and the PLAYS rows carry the scoreline
  alone. The feed's `homeWinPercentage` / `swing` fields are still parsed and
  stored — they are simply never rendered.

  FLOW also carries a scoring map filtered by ALL / HOME / AWAY / 3PT. The
  scoring map plots every coordinate-bearing made field goal on a drawn NBA half
  court (lane, free-throw circle, restricted arc, backboard and rim, and the
  three-point line with its corner runs), cropped just past the arc because no
  shot is taken from deeper. The feed normalises both sides onto one basket, so
  the rim is the coordinate origin and team colour is what separates them: a
  filled dot is a two, a hollow ring is a three, and a legend names both sides.
  The court itself never glows — it is a static stat surface.

Football also reveals events, confirmed lineups and commentary; basketball plays,
box scores, rosters and injuries; cricket scorecards and team-filtered ball
commentary. Cricket's STATS navigation contains OVERVIEW, RACE, SCORECARD, and
MATCH FEED; the standalone CHASE and SQUADS tabs are omitted. MATCH FEED uses one
tab per batting team and open timeline rows rather than individual comment cards;
an innings without published commentary receives its own contextual empty state.
Selection haptics,
a marker-crossing click, a hero count-up and a one-shot graph reveal provide
feedback. INNINGS RACE owns the tab's focal reveal glow; the run-rate panel uses
only its brief line reveal.

Football EVENTS and COMMENTARY use open log rows without individual panel fills
or four-sided borders. Event rows retain their team-colour timeline rail and
semantic icon, while commentary retains its minute/sequence divider.

## Visible States

Loading/empty fixture board, upcoming available, drafted/submitted, editable,
locked/live, result verifying, settleable, settled, voided question, contest
affordable/unaffordable/paid, and result-reveal states are represented. Search
also represents cross-sport scanning, partial-feed, guidance, no-result, grouped
team/league result, and matching-fixture states.

Completed football and basketball fixture cards show the score and FULL TIME
state without repeating a winner-summary line beneath the teams. Cricket cards
retain their result line because its wicket/run-margin format carries match
context beyond the score alone.

For completed football, basketball, and cricket cards with a decisive score,
the winning team name and score display in white while the losing side uses the
muted HUD text tone. Drawn games keep both sides white. Cricket places each
score beside its crest and keeps the innings overs/target context beneath that
team's name.

Sport report views also represent complete bundled packages and partial ESPN
feeds, with contextual empty states for missing flow, event, scorecard,
commentary, lineup, roster, and squad data.

### Cricket delivery progression (PROTOTYPE DATA)

The bundled RCB-GT package stores full legal-delivery progression for both
innings: 120 GT balls ending at 155 and 108 RCB balls ending at 161. Every point
carries innings and team identity, over notation, legal-ball index, cumulative
runs, and an optional boundary value. Actual run rate is calculated as cumulative
runs per six legal balls. Required rate uses the 156 target, runs still needed,
and legal balls remaining, and therefore exists only for the second innings.

The local timeline is transcribed from the fixture's published
[ball-by-ball scorecard](https://indianexpress.com/section/sports/cricket/live-score/royal-challengers-bengaluru-vs-gujarat-titans-final-t20-live-score-full-scorecard-highlights-indian-premier-league-2026-bcahm05312026270968/).
Decoder validation checks the final scores and the supplied boundary aggregates:
GT 15 fours / 3 sixes and RCB 18 fours / 7 sixes. This remains bundled prototype
data with no live delivery API or storage migration. When delivery progression
is absent, INNINGS RACE remains available and the second panel shows a contextual
unavailable state.

### Football shot positions (BUILT DATA)

Every shot event in the bundled Fulham-Chelsea package carries a real pitch
position on its commentary entry, matching ESPN's own field shape:
`fieldPositionX`, `fieldPositionY`, a `shotZone` label and a `positionSource`
marker of `espn`. All 32 shot events are covered, split 14 home / 18 away to
match the package's own `totalShots` aggregate, with 5 goals matching the 5
listed scorers.

These are genuine tracked coordinates, not estimates. The bundled fixture is a
real ESPN match (event `401879318`, Fulham 2-3 Chelsea at Craven Cottage), so the
positions join onto the package by `playId`.

The coordinate frame is ESPN's, normalized into the attacking team's own half:

- `fieldPositionX` runs 0-100 as progress toward the attacking goal, so 100 is
  the goal line. The penalty-area edge sits at 83.1 and shots described as
  "outside the box" end at 82.8; six-yard-box efforts land above 94.
- `fieldPositionY` runs 0-100 across the pitch, and the attacker's **left is the
  high** value: left-side-of-the-box shots average 67.8, centre 49.2, right 32.3.

Both teams arrive in the same attacking frame and it does not flip at half time,
so rendering a full pitch with the sides attacking opposite goals requires
mirroring one team.

This frame is season-specific and has changed between ESPN feed versions; an
older feed normalized to 0-1 with the axes oriented differently. Any future
import must be recalibrated against the commentary prose rather than assuming
these bands. Goal-mouth placement is not supplied numerically
(`goalPositionX/Y` are zero) and exists only in the commentary text.

The football report renders these on a **SHOT MAP** panel inside the MOMENTUM
sub-tab, mirroring where basketball puts its scoring map inside FLOW. The panel
draws a full pitch to real proportions with the home side attacking right and
the away side attacking left, and carries ALL / 1ST / 2ND / GOALS filters.

Marks encode outcome by shape and team by colour: goals are a filled disc with a
ring, on-target attempts a filled dot, off-target a hollow ring and blocked a
faded hollow ring. Goals are the only mark that glows, keeping one focal class
per panel. Attempts fade in on a staggered reveal when the panel or a filter is
opened, and tapping a mark selects it — with a haptic tick and a pulse ring —
to reveal the taker, minute, outcome, assist and the zone the attempt came from.

Selecting a mark also draws a **goal-mouth diagram** showing where the attempt
finished: posts, crossbar and net, with the ball placed where it crossed the
line. Placement comes from the commentary prose, which carries it for all 12
attempts that reached the frame ("to the bottom left corner") and a miss
direction for all 8 that did not; misses are plotted just outside the posts.
The 12 blocked attempts never reached the goal, so they have no placement and
render an empty frame captioned `BLOCKED // NEVER REACHED THE GOAL` — the panel
holds its height either way, so tapping between attempts never makes it jump.

Commentary names a corner without saying whose left, so the diagram uses the
broadcast convention of the viewer's, as the feed cannot settle it. Only a goal
glows and ripples the net; saves, misses and blocks stay calm.

The feed supplies **no xG or xGOT**, so the panel shows none rather than
estimating or stubbing them — everything on it comes from the feed.

The goal, net and ball are drawn by the shared `paintGoalMouth` in
`lib/widgets/cyber/goal_mouth.dart`, extracted from the penalty shootout so the
two surfaces share one goal instead of each re-deriving it.

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
  enrichment without treating these packages as live providers. The
  Fulham–Chelsea package carries real ESPN shot coordinates for all 32 shot
  events (see Football shot positions). The Fulham–Chelsea,
  NBA Finals Game 5 and RCB–Gujarat fixtures retain their supplied local start times but
  rebase to the player's current local date whenever the fixture catalog is
  read (including direct detail lookup), keeping all three completed reference
  matches in their respective TODAY boards across daily rollover.
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
