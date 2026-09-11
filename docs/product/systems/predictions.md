# Predictions

> **Status:** BUILT
> **Last verified:** 2026-09-07
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


Sports appear in one canonical order everywhere they are tabbed —
**Football, Cricket, Basketball, Motorsport, Tennis** — defined by
`sportTabOrder` in `lib/config/sport_modules.dart` and mirrored by the
collection, leaderboard and shop strips, which keep their own lists because each
shows a different subset. The compact MATCH/GAMES strip is the one exception: it
shows four sports plus an **ALL SPORTS** overflow and deliberately omits
Motorsport, which is reached through that overflow.

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
match-page summary header stacks each team name directly beneath its own crest,
so each side of the scoreline reads as a single identity block with the score
centred between them on the crest line. Each block hugs its own outer edge, 16px
from the screen edge, matching the header's corner-bracket frame — home left
aligned, away right aligned. Team names render on one line and truncate with an
ellipsis rather than wrapping, so the crest-to-name stack keeps a fixed height
across fixtures. Both names stay white for a stable reading hierarchy, and crests
and the split score rail carry the team identity colour. Cricket splits its
innings score across that stack the way the SCORECARD innings header does: the
runs/wickets figure sits beside the crest on the crest line (inside it, so the
crest keeps the outer edge), and the parenthesised qualifier — overs faced and
any chase target — becomes a muted uppercase line under the club name. An
innings with no qualifier shows only the runs, and a fixture with no score shows
only the crest and name.
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
competed with the status tag for the same top edge. The pin header above the
fixture reads **YOUR CLUB** alone — the club is already named on the card it
sits over, so repeating it there was redundant. The header's right-hand readout
carries only forward-looking status: a pulsing LIVE NOW, KICKING OFF, or the
kickoff countdown. A finished fixture shows nothing there, since the card's own
FULL TIME tag and final score already say so. Live and reward-pending lifecycle colors keep
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

The cricket report's implementation — every widget verbatim, its data contract,
the race/run-rate chart configuration, and a guide to rebuilding it in another
Flutter project — is documented in
[Cricket match STATS view](../../technical/cricket-match-stats-view.md).

Football's STATS navigation is **OVERVIEW / MOMENTUM / LINEUPS / COMMENTARY**.
There is no separate EVENTS tab: the event log was never a destination of its
own — it is how a match reads — so it now sits in OVERVIEW as the **MATCH
TIMELINE**, in the slot the GOAL IMPACT scorer list used to hold. Goals carry
their running scoreline and assist inside the timeline, so nothing the scorer
list said is lost.

Football and cricket OVERVIEW begin directly at **MATCH INTEL**, and basketball
at **GAME INTEL**, since the persistent match header already carries the fixture
and score. The redundant overview match-pulse headers and their summary metrics
are removed for all three sports. Football's MATCH INTEL panel lists VENUE and
ATTENDANCE as two full-width stacked rows so long venue strings read in full,
and it carries no winner/result line — the result already lives in the match
header and the settlement surfaces. Cricket's INNINGS GRID is also omitted from
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

### Player match dossier (football LINEUPS) — BUILT

Every player on the football LINEUPS pitch is a tap target, and every node
carries what that player earned in the match: a ball per goal, an assist mark, a
yellow or red card, a substitution arrow. Only the goal badge glows, so the
formation board reads as a match report at a glance without breaking glow
scarcity. Players who did not come on are dimmed but stay tappable — their card
is short and honest, and a dead tap target reads as a bug. Bench tiles behave the
same way.

The pitch behind the formation carries only real markings — outline, halfway
line, centre circle, penalty and goal boxes. The decorative 32px blueprint grid
was removed: the panel already sits on the app's textured background, so a
second grid inside it was texture on texture and competed with both the markings
and the player nodes. The basketball lineup board shares the painter and keeps
its grid for now.

Tapping one opens the **MATCH DOSSIER**, a bottom sheet that pages across the
whole squad, so comparing two team-mates is a swipe rather than two taps and a
scroll. Each page is:

1. **Identity** — the shirt number blown up behind the plate as wallpaper, the
   player image, name, `POSITION // #NUM // TEAM`, and STARTER / SUBBED OFF /
   SUBSTITUTE / UNUSED plus minutes as status pills.
2. **Impact strip** — TOUCHES, xG, FINAL 3RD and TERRITORY, each counting up
   from zero on entry. These four are derived from the tracked coordinates and
   are not published by ESPN at all; they are the payoff for having them.
3. **HEAT MAP** — touch density on the true-proportion pitch, with a FULL / 1ST
   / 2ND half filter and a BOX touch count.
4. **MATCH SHEET** — ESPN's own numbers as loadout-style pills grouped under
   ATTACK / INVOLVEMENT / DISCIPLINE / GOALKEEPING. Stats that do not apply to a
   position are omitted rather than shown as zero; zeros are dimmed so the
   numbers a player actually put on the board carry the eye; cards take amber
   and red tints.

The heatmap is drawn with **additive radial falloffs** — each live cell of a
24×16 grid draws a soft circle at `BlendMode.plus` inside one `saveLayer`, so
the cloud emerges from overlap with no blur filter, no offscreen bitmap and no
new dependency. Density is a bilinear splat followed by two separable 1-2-1 blur
passes, computed once per player and never inside `paint`. The ramp is fixed
(cyan → lime → amber → white) rather than keyed to the team colour: a ramp has
to be perceptually ordered, and a club whose accent is already white or amber
would collapse both ends into the same colour. Team identity enters through the
panel border and the chamfered outlines on the hottest cells, which is also what
stops it reading as a generic weather map. One glow only, on the single hottest
cell. The reveal is a left-to-right scan wipe that replays on every player swipe
and half change. Every player attacks right, home or away — a single-player map
is about that player's own pitch, and mirroring the away side would make their
cards read backwards for no reader benefit.

Player images degrade in three steps: a bundled portrait where one exists (the
portrait library is the card game's roster, so it covers 2 of these 40 players),
then ESPN's per-event kit render decoded downscaled, then the shirt-number
octagon — the same badge the pitch draws, so card and formation board speak the
same language. The number badge sits permanently *behind* the image, so a slow,
missing or failed kit never leaves a blank plate. **ESPN publishes no headshots
for soccer at all**; the kit render is the only player image its API offers.

Data sources split by cost. The per-player stat sheet rides on the summary
response the lineup already needs, so it is parsed on the live path and every
football fixture gets a match sheet. Positional tracking lives in a separate
~1.5 MB plays feed, so it is baked into the bundled Fulham v Chelsea package
only; live fixtures show a "no tracked touches" state and keep the full stat
sheet. See `data/football-match-player-field-inventory.md`.

Football also reveals its timeline, confirmed lineups and commentary; basketball plays,
box scores, rosters and injuries; cricket scorecards and team-filtered ball
commentary. Cricket's STATS navigation contains OVERVIEW, RACE, SCORECARD, and
MATCH FEED; the standalone CHASE and SQUADS tabs are omitted. MATCH FEED uses one
tab per batting team and open timeline rows rather than individual comment cards;
an innings without published commentary receives its own contextual empty state.
### IPL hub (league TABLE / LEADERS / STATS) — BUILT

The IPL hub used to open on a six-team mock table with NO STAT LEADERS and NO
CLUB STATS. It now shows the real 2026 season: a ten-team table with net run
rate and a playoff cut line, nine leader boards, and four STATS board groups.

Cricket cannot reach that data the way football does. ESPN's core API rejects
the sport outright, so there is **no season leaders feed and no per-team
statistics feed** — the two feeds the football hub is built on — and the site
statistics endpoint 403s. Only standings works. Everything else is therefore
**aggregated offline from all 74 match summaries of the season** into
`assets/data/cricket-league-stats.json`, which makes the package the hub's only
source rather than a first-render optimisation: there is nothing to layer over
it, and no season archive to offer.

- **TABLE** reuses `StandingsTable`'s existing cricket layout — P/W/L/NRR/PTS
  instead of football's P/W/D/L/GD — which it selects when a row's `drawn` is
  null. Net run rate carries its sign, and the top four are marked PLAYOFFS.
- **LEADERS** carries nine boards: runs, wickets, sixes, fours, fifties, dot
  balls, catches, strike rate and economy. The two rate boards state their
  qualifying minimum in the headline (100 balls faced, 120 bowled), because a
  rate board without one is topped by whoever bowled a single tidy over.
- **STATS** uses `cricketStatGroups` — BATTING / BOWLING / FIELDING / EXTRAS —
  picked from the package's own stat-dictionary categories rather than a sport
  flag, so the hub does not need to know what sport it is showing. The two
  sports share no stat keys at all, which is why one merged list would have
  rendered a page of NOT PUBLISHED.

### Player match dossier (cricket SCORECARD) — BUILT

Every batting and bowling row on the cricket SCORECARD is a tap target, opening
the same **MATCH DOSSIER** shell the football pitch uses. The join key was
already there and unused: `CricketBatter.id` and `CricketBowler.id` have shipped
since the package landed but nothing read them, and `CricketSquadPlayer` was
decoded and rendered nowhere after the SQUADS tab was removed. The card pages
across the tapped player's own squad.

1. **Identity** — portrait, name, `ROLE // TEAM`, the headline figure
   (`75* (42)` or `3/27`), CAPTAIN / KEEPER / NOT OUT pills, and the batting and
   bowling styles ("LEFT-HAND BAT // RIGHT-ARM OFFBREAK") that had been decoded
   and never shown.
2. **Impact strip** — RUNS · BALLS · SR · BOUNDARY for a batter, WICKETS · RUNS
   · ECONOMY · DOTS for a bowler, counting up on entry.
3. **INNINGS TAPE** — the hero, with POWERPLAY / MIDDLE / DEATH splits and a
   BAT/BOWL switch for an all-rounder.
4. **MATCH SHEET** — ESPN's own numbers as pills grouped BATTING / BOWLING /
   FIELDING. A board is dropped entirely unless the player played that way, and
   the four figures already in the impact strip are not repeated.

**The tape is a sequence, not a map, and that is a data constraint.** ESPN
publishes no coordinates for cricket at all — no wagon wheel, no pitch map, no
line and length — and the core plays feed that gives football its coordinates
does not exist for the sport. What it does publish is every delivery with the
batter and bowler named, so a batter's tape is one chip per ball in bowling
order (dot hollow and muted, runs cyan, four lime, six amber, wicket in danger
and the only glow), and a bowler's is over-by-over spell bars. Both stagger in
ball by ball on open, replaying on every swipe.

Like the football heatmap ramp, **the tape's colours are semantic rather than
team-keyed**: a club whose accent is red or gold would otherwise render an
ordinary single as an alert and a tidy over as a warning. Team identity lives in
the panel border and the headline figure.

Data splits by cost, as football's does. The 46-stat sheet rides on the summary
response the scorecard already needs, so it is parsed on the live path and every
cricket fixture gets a card; ball-by-ball is a separate request and is baked into
the bundled IPL final only, with live cards showing a "no ball-by-ball" state and
the full stat sheet. See `data/ipl-match-player-field-inventory.md`.

SCORECARD uses a cut-corner innings control and a compact innings command panel,
then separates batting, partnership and bowling figures with open HUD rails and
chamfered data tables. The active innings and score own cyan emphasis, while top
run and wicket figures use score-semantic gold; static rows remain glow-free.
Selection haptics,
a marker-crossing click, a hero count-up and a one-shot graph reveal provide
feedback. INNINGS RACE owns the tab's focal reveal glow; the run-rate panel uses
only its brief line reveal.

### Football MATCH TIMELINE (OVERVIEW) — BUILT

The timeline is **two-sided around a centre spine**. Minutes run down the middle
on a continuous hairline, and each moment is pushed out to the side of the team
that made it — home left, away right — so who-did-what-when reads in one pass
instead of one column of rows that all have to be re-parsed for their team. The
glyph always hugs the spine with the copy reading outward from it.

Type is carried by shape and semantic colour, never by the team accent alone: a
booking is drawn as an actual tilted card rather than a borrowed icon, and a
substitution is the two names it really is — who came on in `lime`, who came off
in `danger`. **A goal is the only event class that glows.** It is also the only
one that moved the score, so the scarce focal mark down the whole spine is
earned, and a goal plate additionally carries the new scoreline and the assist.
Period markers (`KICKOFF`, `HALFTIME`, `END REGULAR TIME`) cross the full width
with their running score.

Every row's full feed report stays folded away until asked for: tapping a moment
expands ESPN's own prose on it, pinned to that team's side behind an accent
edge. That keeps twenty-plus events readable as a timeline rather than a wall of
text, and makes reading the match a sequence of small reveals.

At the interval the timeline keeps only the `HALFTIME` score marker; the
same-clock `START 2ND HALF` feed marker is intentionally suppressed as redundant.
Football COMMENTARY still uses open log rows without individual panel fills or
four-sided borders, retaining its minute/sequence divider.

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

## League hub data

Tapping a league's standing strip opens the per-league hub, which carries five
tabs: **TABLE**, **LEADERS**, **STATS**, **GAMES**, and **PICKS**.

The persistent league lockup keeps its subtitle to the compact season token
only (for example, `2026-27`). The league name already owns the primary line,
so duplicated competition text and team count do not compete for header space.
In the TABLE standings, club names stay white for a consistent readable text
hierarchy; club identity colour remains on the crest rather than tinting the
row label.

### Where the data comes from

Both sources produce the same models, so the hub renders identically from
either.

Loading is **bundled-first**. `LeagueStatsCubit` renders the packaged snapshot at
`assets/data/football-league-stats.json` immediately, then layers the live ESPN
feed over it in the background; a failed or blocked request silently keeps the
package rather than emptying the hub. The player never waits on the network to
see a filled table.

Club stats have a **live fallback**. When the package is unavailable — an older
install, or any competition it doesn't cover — `EspnLeagueStatsService`
fetches per-club season statistics directly from
`.../seasons/{year}/types/1/teams/{id}/statistics`, one request per club at six
in flight. That sweep is lazy: it runs the first time the STATS tab is opened,
never on hub load, and no-ops when the package already answered. It is the same
lazy contract the LEADERS boards use for resolving athlete names.

The package (~670 KB, generated by `tool/generate_league_stats.dart`) holds, for
the Premier League (`eng.1`) and LaLiga (`esp.1`): the 20-team table with
qualification zones, all 12 ESPN leader categories with athlete identities
already resolved (so LEADERS never shows a loading placeholder), and per-team
season statistics — 112 stats per club across `offensive`, `defensive`,
`general` and `goalKeeping`. Every field and its coverage is catalogued in the
[league stats field inventory](../../data/league-stats-field-inventory.md).

The same package also carries a roster map keyed by ESPN team ID and one
normalized copy of every league fixture. Team pages filter these shared records
rather than duplicating a 38-match schedule inside every club.

Leagues resolve by **alias**, never by a single id: the same competition reaches
the hub as `eng.1` (curated repository league), `epl` (follow list), `700`
(ESPN scoreboard) or `23` (ESPN standings), and league name and short code are
consulted as a fallback. Before this, the id mismatch meant the EPL hub rendered
`0 TEAMS` with empty TABLE and LEADERS tabs.

### F1 race weekend package

**BUILT (data only):** F1 now has a bundled, structured race-weekend package at
`assets/data/f1-italian-gp.json`, generated by `tool/generate_f1_race.dart`
(`--race italian`, verified with `--check`). The reference capture is the 2026
Pirelli Italian Grand Prix at Monza.

The package now drives the **motorsport STATS tab**, which was the last sport
still falling through the legacy scoreboard branch. Races the package does not
cover keep that branch: they render ESPN's pre-formatted result strings from
`SportMatch.f1Sessions` / `f1DriverStandings`, which is exactly why they cannot
be charted.

It holds the full weekend rather than a results list: the circuit (5.793 km, 53
laps, 11 turns, clockwise, established 1950, lap record 1:20.901) with six SVG
track maps; all five sessions (FP1, FP2, FP3, Qualifying, Race) with a 22-car
classification each; 26 drivers, because four reserves ran FP1 only; 11
constructors with identity colours; and both championship tables carrying a
per-race points grid across all 25 rounds.

Two things shaped the extraction. **F1 has no `summary` feed** — unlike football
and cricket, `.../racing/f1/summary?event=` 404s, so a weekend is a reference
graph walked over ~260 requests instead of one rich document. And the generator
deliberately uses a **different ESPN host to the runtime service**: `site.api`
answers inside the app but returns 403 to an offline extractor, so the package is
built on `sports.core.api` plus `site.web.api` for standings.

Several ESPN fields are actively misleading and are dropped or renamed at
extraction — `pole` holds a grid slot rather than a pole flag, a qualifying
`0.000` means eliminated rather than a lap time, and `victoryMargin` is always
`.000`. All of them, with per-field coverage counts, are catalogued in the
[F1 race field inventory](../../data/f1-race-field-inventory.md).

### The motorsport STATS tab

**BUILT:** `MotorsportMatchStatsView` mirrors the football, cricket and
basketball stats views — `CyberFilterChips` sub-tabs over keyed sections — with
three tabs: **RACE**, **WEEKEND** and **QUALIFYING**.

A Grand Prix is not a 1v1, so it takes **no `MatchPulseHeader`**: there is no
home-vs-away pair to sit either side of a split bar. The hero is the circuit —
ESPN's Monza track map over 53 laps / 5.793 km / 11 turns, the 1:20.901 lap
record, and the winner's plate reading `FROM P19 · +18`.

Four charts and one board, all on the shared `CyberChartPanel`:

- **Weekend position track** (RACE tab's counterpart on WEEKEND, and the one
  focal element on the screen) — position across FP1 → FP2 → FP3 → QUAL → GRID →
  FIN, plotted inverted so P1 rides the top. Only the top finishers who ran every
  session are drawn; FP1-only reserves are excluded rather than interpolated into
  a start they never made.
- **Gap to leader** — the lead lap's spread, lead-lap runners only.
- **Pace evolution** — best lap per session through the timed running.
- **Qualifying elimination** — Q1 → Q2 → Q3, where a line simply stops at the
  segment its driver was knocked out in.
- **Grid vs finish** — a ranked signed bar board rather than a chart, because
  each driver is a separate category and a polyline between them would imply a
  trend across drivers that does not exist.

**There is deliberately no lap chart.** ESPN publishes no lap-by-lap data for F1
— every lap endpoint 404s, the `plays` feed returns `count: 0`, and `lapsLead`
totals 4 across a 53-lap race — so a leader-per-lap graph could only be
fabricated. The weekend position track is the honest substitute: its lines cross
and swap the way a lap chart's do, but every point is a session that was actually
recorded. Two related honesty constraints hold in the UI: the gap chart plots
only cars on the lead lap (converting a lapped car's `behindLaps` into seconds
drew a fictional 1208-second axis in the first cut), and no surface labels
`lapsLead` as laps led.

Since two team-mates share one livery colour and ESPN publishes no constructor
logos, the second driver of each team is drawn in a lightened shade so a pair
reads as two cars rather than one line doubling back.

### Team hubs

**BUILT:** Every club row in TABLE and every leader/chaser plate in STATS opens
a season-scoped team hub. The route preserves the league's selected season and
has three 48 px tabs: **MATCHES**, **PREDICTIONS**, and **PLAYERS**.

- MATCHES contains only that club's selected league campaign, with ALL,
  UPCOMING, and RESULTS filters. Domestic cups and international fixtures are
  not mixed into the list.
- PREDICTIONS imports those ESPN event IDs into the existing prediction system.
  Authored or saved quizzes win; only a missing quiz is generated. Upcoming
  challenges and the player's locked, reveal-ready, and settled entries remain
  together without duplicating or resetting answers.
- PLAYERS groups the ESPN roster by football position or IPL role. Names stay
  white, cyan is reserved for active controls, and every row opens a dossier.
  Football reuses the live season profile overlay; IPL uses the bundled season
  aggregate and never invents an absent role or statistic.

`TeamHubCubit` renders the generated ESPN package first and then merges a live
refresh by event and athlete ID. EPL and LaLiga packages contain all 380 league
fixtures and complete rosters; native builds refresh the selected team from
ESPN. IPL ships 74 normalized fixtures and all 202 season participants from the
same summary aggregation used by LEADERS/STATS. A refresh failure leaves the
packaged content usable and exposes a small retry strip rather than a blank
route.

### Season selection, games, and archive

**BUILT:** ESPN-backed football league hubs expose a compact season selector in
the existing league lockup. Each route starts on the current campaign; changing
the year resets local board selections and makes TABLE, LEADERS, STATS, GAMES,
PICKS, and player season dossiers read from that one selected snapshot. Requests
are generation-guarded so a slow older season cannot overwrite a newer choice.
Club statistics and the complete match calendar stay lazy until their tabs need
them, and every cache includes the season year.

Season metadata comes from ESPN core and is backed by the lightweight bundled
`assets/data/football-league-seasons.json`, keeping the selector populated
offline. Historical standings use `season={year}` and leaderboards use ESPN core.
The site statistics response is never trusted for a requested historical year
because ESPN returns its current campaign there. A season schedule joins the
selected start year and following calendar year, filters on each event's embedded
ESPN season year, and deduplicates event IDs. For the current campaign, the app's
rolling fixture feed replaces matching archive events so LIVE state remains the
richest available copy.

PICKS remains tradable only for the current season. A historical season becomes
a clearly labelled, read-only result archive built from final scores: it contains
no generated price, buy action, stake, or wallet mutation. Flutter web retains
the bundled current campaign and reports that archive data requires mobile or
desktop because ESPN blocks browser JSON requests and the product has no proxy.

The same header can FOLLOW or UNFOLLOW a supported league. The action persists
immediately through prediction storage and never invents a favourite club.
Unfollowing a league that owns a favourite club requires confirmation and removes
that favourite; follow aliases resolve to the canonical stored league identity.

### Player season dossier

**BUILT:** Every player plate in **LEADERS** opens a full-screen player season
dossier. It begins with the bundled leaderboard identity so the route opens
instantly, then lazily requests ESPN's public core athlete profile and matching
regular-season stat split for the exact `seasonYear` carried by the leaderboard.
The dossier presents verified bio intel (position, shirt, age/date of birth,
height, weight, citizenship and active status), a compact GOALS / ASSISTS / APPS
/ MINUTES impact strip, and expandable ESPN stat families for ATTACK, DEFENCE,
GENERAL and KEEPING. Non-zero active signals appear first; the player can then
unfold the complete raw ESPN family.

This is a scouting moment, not a static admin profile: the identity plate is the
one live/glowing focal point, `SCOUT COMPLETE` confirms a loaded scan, and the
remaining intelligence stays in calm cut-corner data surfaces. The screen never
fabricates fields ESPN does not send. Preferred foot, contract end, transfer
value and a reliable soccer headshot are intentionally absent; a jersey/flag
identity glyph replaces a broken portrait. If the public feed is unavailable
(including browser CORS restrictions), the leaderboard identity remains visible
with a clear cached-data notice rather than a blank route.

The SCOUTING REPORT deliberately has no enclosing panel: its independent
cut-corner stat tiles carry the information hierarchy without adding a second,
heavy box around the report.

### STATS tab

Four category tabs — **ATTACK**, **DEFENCE**, **KEEPING**, **DISCIPLINE** — over
a league-total pulse strip, a stat chip selector, and one board ranking all 20
clubs. Accents follow the existing colour discipline: attack takes the league's
own identity colour, defence violet, keeping success-green, discipline amber
with red cards in danger red.

Each board is the team-side twin of the LEADERS player boards — a glowing
`#1` plate over calm chaser rows, so the two tabs read as one system. Boards
where the *smallest* number wins (goals conceded, cards, fouls) rank ascending
and are framed `LEAGUE BEST // FEWEST`.

Neither board draws a progress meter behind its rows. Both carry short values
already right-aligned in a tabular column, so a per-row bar added weight without
adding information; rank, crest, name and number carry the comparison on their
own. The leader plate keeps its glow and oversized number as the single focal
element.

Only stats verified as populated in both competitions are surfaced — 22 of the
112 are zero league-wide. Explainer captions come from ESPN's own stat
dictionary, overridden only where the feed's wording is ambiguous or misspelt.

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
  and cross-device synchronization require backend scope. The bundled league
  package is a point-in-time snapshot refreshed by re-running
  `tool/generate_league_stats.dart`, not a live service; club stats fall back to
  a live ESPN sweep when it is absent. STATS covers any competition in
  `EspnLeagueStatsService`'s slug map, and shows an empty state for the rest.

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
- [`lib/screens/predictions/league_detail_screen.dart`](../../../lib/screens/predictions/league_detail_screen.dart)
- [`lib/screens/predictions/football_player_profile_screen.dart`](../../../lib/screens/predictions/football_player_profile_screen.dart)
- [`lib/screens/predictions/widgets/team_stat_board.dart`](../../../lib/screens/predictions/widgets/team_stat_board.dart)
- [`lib/services/league_stats_package_service.dart`](../../../lib/services/league_stats_package_service.dart)
- [`lib/services/espn_football_player_profile_service.dart`](../../../lib/services/espn_football_player_profile_service.dart)
- [`lib/blocs/league_stats/league_stats_cubit.dart`](../../../lib/blocs/league_stats/league_stats_cubit.dart)

## Tests

- [`test/services/prediction_quiz_engine_test.dart`](../../../test/services/prediction_quiz_engine_test.dart)
- [`test/match_prediction_screen_test.dart`](../../../test/match_prediction_screen_test.dart)
- [`test/prediction_home_day_navigation_test.dart`](../../../test/prediction_home_day_navigation_test.dart)
- [`test/match_search_screen_test.dart`](../../../test/match_search_screen_test.dart)
- [`test/football_match_package_service_test.dart`](../../../test/football_match_package_service_test.dart)
- [`test/league_stats_package_service_test.dart`](../../../test/league_stats_package_service_test.dart)
- [`test/espn_league_team_stats_live_test.dart`](../../../test/espn_league_team_stats_live_test.dart) (skipped by default; hits the live ESPN API)
- [`test/football_match_stats_view_test.dart`](../../../test/football_match_stats_view_test.dart)
- [`test/basketball_cricket_match_package_service_test.dart`](../../../test/basketball_cricket_match_package_service_test.dart)
- [`test/basketball_cricket_match_stats_view_test.dart`](../../../test/basketball_cricket_match_stats_view_test.dart)
