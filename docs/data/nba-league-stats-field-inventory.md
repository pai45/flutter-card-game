# NBA league stats field inventory

**Status:** BUILT
**Source:** ESPN, `basketball/nba` (ESPN league id `46`), season `2026` (the
2025-26 campaign)
**Asset:** `assets/data/nba-league-stats.json` (129.6 KB)
**Generator:** `tool/generate_nba_league_stats.dart`
**Probed:** 2026-09-09

What ESPN actually publishes for the NBA at league level, so the hub is
designed against real availability. Every number here is asserted by the
generator on each run — if the feed shifts, it fails loudly rather than writing
a thinner asset.

---

## 1. The headline finding: basketball is the easy sport

Cricket needed ~140 requests because ESPN's core API rejects the sport outright,
so every leader and team total had to be re-derived from match summaries (see
`ipl-match-player-field-inventory.md` §7). **Basketball has no such problem.**
All three league-level feeds football runs on exist and answer:

| Feed | Football | Cricket (IPL) | Basketball (NBA) |
|---|---|---|---|
| Standings | works | works | **works** |
| Season leaders | works | **HTTP 400** | **works** |
| Per-team season statistics | works | **HTTP 400** | **works** |

So the generator is a straight extraction — standings, the season leader
boards, and 109 season stats for each of the 30 clubs — in about 240 requests,
most of them the per-leader qualifying sweep described in §3.

```
site.web.api.espn.com/apis/v2/sports/basketball/nba/standings?level=2&season=2026
sports.core.api.espn.com/v2/sports/basketball/leagues/nba/seasons/2026/types/2/leaders
sports.core.api.espn.com/v2/sports/basketball/leagues/nba/seasons/2026/types/2/teams/{id}/statistics
```

The package still exists for the reason football's does: an instant first paint,
and a hub that works on web, where live ESPN is CORS-blocked.

## 2. Standings — two traps

**`level=2` is the conference view**, which is the table an NBA fan reads.
`level=3` nests divisions inside conferences and returns *zero* entries at the
conference level, which looks exactly like a broken feed.

**The season label lies on an unparameterised call.** Requesting standings
without `?season=` returns a payload whose `season` block reads **2026-27**
while the entries it carries are the completed **2025-26** table. Reading that
label would ship an asset a season out. The newest year in the payload's own
`seasons` array (24 are offered) is the truth, and the generator refuses any
season whose standings come back empty.

**`playoffSeed` is NOT the table.** On a finished season it is the *final,
post-play-in* seed, so Phoenix at 45-37 sits below Portland at 42-40. ESPN also
returns the entries in no order at all. A regular-season conference table is
ordered by win percentage, with the seed standing in as the tiebreak on equal
records — that is what the generator writes as `rank`, and a guardrail asserts
win percentage never climbs as rank worsens.

Each row carries: `wins`, `losses`, `winPercent`, `gamesBehind`, `streak`,
`avgPointsFor`, `avgPointsAgainst`, `differential`, `pointDifferential`,
`clincher`, plus six **record splits** — `total`, `home`, `road`, `vsdiv`,
`vsconf`, `lasttengames` — which arrive as bare strings like `"8-2"` under
human-facing names (`"Last Ten Games"`, `"vs. Div."`). They are the entries with
no numeric `value`, and the generator re-keys them by their stable `type`.

**The playoff and play-in cut lines are derived.** ESPN states only a seed
number, so the hub applies the league's published structure: seeds 1-6 go
straight through, 7-10 play the play-in. That is what draws the two lines on the
table.

## 3. Leaders — ESPN applies no qualifier of its own

16 categories, 25 players each, athlete and team as `$ref` URLs to resolve.

**The feed ranks purely by value, with no games or minutes minimum.** Taken
raw, the 2025-26 boards were topped by a two-way player with eight appearances:
PER read *Tristen Newton 32.85*, steals read *Kadary Richmond*. Applying the
NBA's own published minimums fixes it — PER becomes *Nikola Jokic 32.4* — at the
cost of one extra sweep, since qualifying needs each candidate's season totals
from `.../athletes/{id}/statistics/0`.

| Board | Minimum | Shown in the headline as |
|---|---|---|
| Per-game boards (PTS, REB, AST, 3PM, STL, BLK, PER, TO) | 58 games — 70% of 82 | `58+ GAMES` |
| Field goal % | 300 made field goals | `300+ MADE` |
| Three-point % | 82 made threes | `82+ MADE` |
| Free throw % | 125 made free throws | `125+ MADE` |
| Double-doubles | none — a count cannot be flattered by a short sample | — |

Candidates are taken 25 deep so a board still fills to 10 after the cut, and a
guardrail refuses a board that comes up short.

**`3PointPct` is a 0-1 fraction while `fieldGoalPercentage` and `FreeThrowPct`
in the SAME response are already 0-100.** The generator scales it so all three
read alike.

The four categories deliberately dropped are `points` (duplicates
`pointsPerGame`'s ranking), `NBARating` (an opaque composite), and
`minutesPerGame` / `foulsPerGame` (not achievements).

## 4. Team season statistics — 109 keys, 79 of them alive

Three categories per team: `defensive` (11), `general` (38), `offensive` (60).

**30 of the 109 are zero for all 30 clubs**, and are not merely uninteresting:

```
the entire avg48* family (20 keys), minutes, avgMinutes, avgTeamRebounds,
teamRebounds, doubleDouble, tripleDouble, gamesStarted, turnoverPoints,
defReboundRate, fantasyRating, gameDayOfYear
```

`plusMinus` is `-1` for every team, and `gamesPlayed` is 82 for every team, so
neither ranks. Several live keys are duplicates of a board already shown
(`totalRebounds`, `totalTechnicalFouls`, `threePointFieldGoalPct`) or ESPN's
inconsistent fraction spelling of a percentage it also ships as 0-100
(`fieldGoals`, `freeThrows`, `offensiveReboundPct`).

The curated STATS boards live in `basketballStatGroups` and are grouped
**SCORING / PLAYMAKING / DEFENCE / DISCIPLINE**. A test asserts every board and
pulse key is present in the shipped dictionary — a missing key renders as
NOT PUBLISHED.

**Basketball cannot be told apart by stat category.** ESPN files these under
`offensive` / `defensive` / `general`, exactly as it does football's, so
`statGroupsFor` picks the basketball boards off a signature stat instead
(`reboundRate` / `threePointPct`); no football dictionary contains a rebound.

Unlike cricket, ESPN publishes real prose descriptions for every basketball
stat, so the dictionary is shipped in the asset rather than hand-written.

## 5. Asset shape

```jsonc
{
  "generatedAt": "…", "source": "ESPN basketball/nba", "seasonType": 2,
  "statDictionary": { "<stat>": { category, displayName, abbreviation, description } },
  "leagues": [{
    "id": "nba", "espnId": "46", "aliases": [...],
    "season": "2025-26", "seasonYear": 2026,
    "teams":       [ { id, displayName, abbreviation, shortDisplayName, logo } ],
    "conferences": [ { label, rows: [ { teamId, rank, wins, losses, winPercent, … } ] } ],
    "leaders":     [ { key, unit, qualifier, leaders: [ { athleteId, teamId, value } ] } ],
    "athletes":    { "<id>": { name, role, jersey } },
    "teamStats":   { "<teamId>": { "<stat>": value } }
  }]
}
```

30 teams, 2 conferences of 15, 12 leader boards of 10, 69 athletes, 109 stat
keys per team.

The 2025-26 season it produces: Detroit 60-22 top of the East, Oklahoma City
64-18 top of the West; Luka Doncic 33.5 points a game, Nikola Jokic 12.9
rebounds, 10.7 assists and a 32.4 PER.
