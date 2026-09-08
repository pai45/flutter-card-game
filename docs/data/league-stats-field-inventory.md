# League stats field inventory - EPL and LaLiga

> **Status:** BUILT
> **Last verified:** 2026-09-08
> **Scope:** Every field extracted from ESPN into `assets/data/football-league-stats.json`, and how populated each one is

Describes the asset produced by
[`tool/generate_league_stats.dart`](../../tool/generate_league_stats.dart).
Regenerate the asset with `dart run tool/generate_league_stats.dart`; verify it with
`--check`.

This page exists so the league hub's STATS page can be designed against data that
demonstrably exists, rather than against guesses. **"Teams reporting" counts how many
of the 20 teams report a non-zero value** - a stat at 0/20 is either genuinely unused
in this competition or too early in the season to have accrued, and should not anchor
a headline card.

> Both leagues were captured 3-4 matchweeks into 2026-27, so season totals are small.
> Coverage ratios, not absolute values, are what this page asserts.

## The asset at a glance

| | EPL (`eng.1`) | LaLiga (`esp.1`) |
| --- | ---: | ---: |
| Season | 2026-27 English Premier League | 2026-27 Spanish LALIGA |
| Teams | 20 | 20 |
| Standings rows | 20 | 20 |
| Leader categories | 12 | 12 |
| Leader rows | 300 | 300 |
| Full roster athletes resolved | 569 | 594 |
| Season fixtures | 380 | 380 |
| Teams with season statistics | 20 | 20 |
| Stats per team | 112 | 112 |

File size: 669.6 KB (compact JSON). Shared `statDictionary`: 112 entries.

## Reading the JSON

```jsonc
{
  "statDictionary": { "<statName>": { "category", "displayName",
                                      "shortDisplayName", "abbreviation", "description" } },
  "leagues": [{
    "slug": "eng.1", "aliases": ["eng.1", "epl", "EPL"], "name": "...",
    "season":    { "year", "displayName", "name", "type" },
    "teams":     [{ "id", "name", "displayName", "shortDisplayName",
                    "abbreviation", "location", "logo", "color", "alternateColor" }],
    "standings": [{ "teamId", "rank", "note": { "description", "color", "rank" },
                    "stats": { "<name>": [value, "displayValue"] } }],
    "leaders":   [{ "key", "displayName", "shortDisplayName", "abbreviation",
                    "leaders": [{ "rank", "athleteId", "teamId", "value", "displayValue" }] }],
    "athletes":  { "<athleteId>": { "id", "displayName", "fullName", "shortName", "jersey",
                                    "position", "positionAbbr", "citizenship", "age",
                                    "dateOfBirth", "flag" } },
    "rosters":   { "<teamId>": ["<athleteId>", "..."] },
    "fixtures":  [{ "id", "kickoff", "homeTeamId", "awayTeamId", "status",
                     "homeScore", "awayScore", "resultLine" }],
    "teamStats": { "<teamId>": { "<category>": { "<name>": [value, "displayValue"] } } }
  }]
}
```

Every stat is a `[value, displayValue]` pair: `value` is the number to compute and sort
with, `displayValue` is ESPN's own formatting. Stat metadata is **not** repeated per team -
look names up in the top-level `statDictionary`. Athletes are likewise a map keyed by id,
because the same striker appears on several leaderboards.

`aliases` exists because the app has three colliding league-id namespaces (`'epl'`,
`'eng.1'`, and ESPN's runtime numeric ids). Resolve a league by scanning `aliases`, never
by assuming one spelling.

## Standings fields (14 per row)

Sourced from `apis/v2/sports/soccer/{slug}/standings`. Present for all 20 rows in both leagues.

| Stat | Meaning | Notes |
| --- | --- | --- |
| `rank` | Table position | - |
| `rankChange` | Movement since last update | - |
| `gamesPlayed` | Matches played | - |
| `wins` | Wins | - |
| `ties` | Draws | - |
| `losses` | Losses | - |
| `points` | League points | - |
| `pointsFor` | Goals for | ESPN reuses its generic naming; these are goals |
| `pointsAgainst` | Goals against | ESPN reuses its generic naming; these are goals |
| `pointDifferential` | Goal difference | `displayValue` is signed (`+5`); `value` is bare |
| `ppg` | Points per game | Reported 0 this early in the season |
| `deductions` | Points deducted | `displayValue` is empty when zero |
| `advanced` | Advancement flag | - |
| `overall` | Aggregate W-D-L record | `value` is null - use `displayValue` (e.g. `3-0-0`) |

Each row also carries `note` - the qualification zone ESPN paints the table with:

| Zone | Colour | Present in |
| --- | --- | --- |
| Champions League | `#81d6ac` | EPL, LaLiga |
| Conference League qualifying | `#b2bfd0` | LaLiga |
| Europa League | `#b5e7ce` | EPL |
| Europa League | `#c6d1e0` | LaLiga |
| Relegation | `#ff7f84` | EPL, LaLiga |

Rows outside a zone have `note: null`.

## Leader categories (12 per league, 25 players each)

Sourced from the core `leaders` feed. The app today surfaces only 10 of these, 10 deep.

| `key` | Display | Abbr | EPL leader | LaLiga leader |
| --- | --- | --- | --- | --- |
| `goalsLeaders` | Goals | G | Erling Haaland (3) | Sergio Camello (5) |
| `assistsLeaders` | Assists | A | Cody Gakpo (3) | Unai López (3) |
| `goals` | Goals | G | Erling Haaland (3) | Sergio Camello (5) |
| `assists` | Assists | A | Cody Gakpo (3) | Unai López (3) |
| `shotsOnTarget` | Shots On Target | ST | Erling Haaland (8) | Kylian Mbappé (18) |
| `yellowCards` | Yellow Cards | YC | Vitaly Janelt (3) | Isaac Romero (3) |
| `redCards` | Red Cards | RC | João Gomes (1) | Jorge de Frutos (1) |
| `foulsCommitted` | Fouls Committed | FC | Vitaly Janelt (8) | Jon Aramburu (18) |
| `foulsSuffered` | Fouls Suffered | FS | Yoane Wissa (11) | Vinícius Júnior (17) |
| `totalShots` | Total Shots | TS | Erling Haaland (14) | Kylian Mbappé (31) |
| `accuratePasses` | Accurate Passes | AP | Rúben Dias (329) | Renato Veiga (286) |
| `saves` | Saves | S | Lukás Hornícek (13) | Unai Simón (17) |

**`goalsLeaders`/`goals` and `assistsLeaders`/`assists` are duplicate pairs** - the same
stat in two formats. The `*Leaders` variant carries a prose `displayValue`
(`"Matches: 3, Goals: 3"`); the plain variant is the bare number. Use `value` for both and
show only one of each pair, as the live service already does.

## Team season statistics (112 per team)

Sourced from `.../types/1/teams/{id}/statistics` - **a feed the app has never used.** This is
the substance a STATS page needs; the hub currently has only the table and player boards.

### `offensive` (47 stats)

| Stat | Display | Abbr | EPL | LaLiga | Description |
| --- | --- | --- | ---: | ---: | --- |
| `accurateCrosses` | Accurate Crosses | AC.CRSS | 20/20 | 20/20 | The number of crosses that find their target. |
| `accurateLongBalls` | Accurate Long Balls | AC.LONG | 20/20 | 20/20 | The number of longballs that are completed. |
| `accuratePasses` | Accurate Passes | AC.PASS | 20/20 | 20/20 | The number of passes completed. |
| `accurateThroughBalls` | Accurate Through Balls | AC.THRU | 11/20 | 15/20 | The number of through balls that find their target. |
| `avgBigChanceCreated` | Big Chances Created | ABCC | 20/20 | 19/20 | Average big chances created |
| `avgExpectedGoals` | Average Expected Goals | AxG | 20/20 | 20/20 | Average number of expected goals |
| `avgGoals` | Average Goals | AG | 17/20 | 20/20 | Average number of goals |
| `awayGoals` | Away Goals | AWYG | 15/20 | 16/20 | The number of away goals that team or player has scored |
| `bigChanceCreated` | Big Chances Created | BCC | 20/20 | 19/20 | A pass which led to a clear-cut scoring opportunity, such as a one-on-one situation or a shot from just a few yards out |
| `crossPct` | Cross Percentage | FGA | 20/20 | 20/20 | The percentage of crosses that find their target. |
| `freeKickGoals` | Free Kick Goals | FKG | 2/20 | 2/20 | The number goals scored from free kick shots. |
| `freeKickShots` | Free Kick Shots | FKS | 10/20 | 14/20 | The number of free kick shots attempted. |
| `gameWinningAssists` | Game Winning Assists | GWAST | 0/20 | 0/20 | The number of game winning assists. |
| `gameWinningGoals` | Game Winning Goals | GWG | 0/20 | 0/20 | The number of game winning goals. |
| `goalAssists` | Assists | A | 17/20 | 17/20 | The number of assists. |
| `goalConversion` | Goal Conversion Rate | GCONV | 17/20 | 20/20 | Total number of goals divided by (Attempts on target + Attempts off target). Note: Blocked shots are not included in this calculation. |
| `headedGoals` | Headed Goals | HEADG | 5/20 | 7/20 | The number of goals scored from headers. |
| `homeGoals` | Home Goals | HOMEG | 16/20 | 18/20 | The number of home goals that team or player has scored |
| `inaccurateCrosses` | Inaccurate Crosses | INCRSS | 0/20 | 0/20 | The number of times a cross was attempted and failed to find its target. |
| `inaccurateLongBalls` | Inaccurate Long Balls | FGA | 20/20 | 20/20 | The number of times a long ball was attempted and failed to be completed |
| `inaccuratePasses` | Inaccurate Passes | FGA | 20/20 | 20/20 | The number of times a pass was attempted and failed to find its target. |
| `inaccurateThroughBalls` | Inaccurate Through Balls | FGA | 5/20 | 11/20 | The number of times a through ball was attempted and failed to be completed. |
| `leftFootedShots` | Left Footed Shots | LFTSH | 20/20 | 20/20 | The number of shots attempted with a player's left foot. |
| `longballPct` | Long Ball Percentage | FGA | 20/20 | 20/20 | The percentage of long balls attempted that find their target. |
| `offsides` | Offsides | OF | 20/20 | 20/20 | The number of times a player or team gets caught offside. |
| `penaltyKickGoals` | Penalty Kick Goals | PKG | 4/20 | 6/20 | The number of goals scored from the penalty spot. |
| `penaltyKickPct` | Penatly Kick Percentage | FGA | 4/20 | 6/20 | The percentage of penalty kicks converted. |
| `penaltyKickShots` | Penalty Kicks | PKA | 5/20 | 7/20 | The number of penalty kicks attempted. |
| `penaltyKicksMissed` | Penalty Kicks Missed | PKM | 0/20 | 1/20 | The number of penalty kicks missed. |
| `possessionPct` | Possession Percentage | PP | 20/20 | 20/20 | The percentage of the game this team had possession |
| `rightFootedShots` | Right Footed Shots | RGHTSH | 20/20 | 20/20 | The number of shots attempted with the right foot. |
| `shootOutGoals` | Penalty Shootout Goals | PSG | 0/20 | 0/20 | The number of penalty kicks converted in penalty shootouts. |
| `shootOutMisses` | Penalty Shootout Misses | PSM | 0/20 | 0/20 | The number of penalty kicks missed in penalty shootouts. |
| `shootOutPct` | Penalty Shootout Misses | PS% | 0/20 | 0/20 | The percentage of penalty kicks in a penalty shootout that are converted. |
| `shotAssists` | Shot Assists | SHAST | 20/20 | 20/20 | The number of passes that directly result in a shot. |
| `shotPct` | Shots On Target Percentage | SOT% | 20/20 | 20/20 | The percentage of shots that are on target. |
| `shotsHeaded` | Headed Shots | HEADSH | 0/20 | 0/20 | The number of shots attempted with the head. |
| `shotsOffTarget` | Shots Off Target | SHOFF | 20/20 | 20/20 | The number shots attempted that miss the goal. |
| `shotsOnPost` | Shots On Post | PSTSH | 11/20 | 12/20 | The number of shots that hit the post. |
| `shotsOnTarget` | Shots On Goal | SOG | 20/20 | 20/20 | The number of shots that are on goal. |
| `throughBallPct` | Through Ball Percentage | FGA | 11/20 | 15/20 | The percentage of through balls played that find their target. |
| `totalCrosses` | Crosses | CROSS | 20/20 | 20/20 | The number of crosses attempted. |
| `totalGoals` | Total Goals | G | 17/20 | 20/20 | The number of goals scored against the opposing team. |
| `totalLongBalls` | Long Balls | FGA | 20/20 | 20/20 | The number of long balls attempted. |
| `totalPasses` | Passes | PASS | 20/20 | 20/20 | The number of passes attempted. |
| `totalShots` | Shots | SHOT | 20/20 | 20/20 | The number of shots attempted. |
| `totalThroughBalls` | Through Balls | THRU | 17/20 | 19/20 | The number of through balls attempted. |

### `defensive` (11 stats)

| Stat | Display | Abbr | EPL | LaLiga | Description |
| --- | --- | --- | ---: | ---: | --- |
| `blockedShots` | Shots Blocked | SHBLK | 20/20 | 20/20 | The number shots blocked by a defender. |
| `defensiveActions` | Defensive Actions | DACT | 20/20 | 20/20 | Number of defensive moves made by the team in the defensive third |
| `effectiveClearance` | Effective Clearance | EFFCL | 20/20 | 20/20 | The number of clearances that stops the attack of the opposing team. |
| `effectiveTackles` | Tackles Won | TKLW | 20/20 | 20/20 | The number of tackles where the player wins the ball. |
| `inneffectiveTackles` | Tackles Lost | TKLL | 20/20 | 20/20 | The number of tackles where the player doesn't win the ball. |
| `interceptions` | Interceptions | INT | 20/20 | 20/20 | The number of interceptions. |
| `recoveries` | Recoveries | REC | 20/20 | 20/20 | Total number of recoveries - when a player takes possession of a loose ball and successfully keeps possession for at least two passes or an attacking play |
| `tacklePct` | Tackle Percentage | TACKL% | 20/20 | 20/20 | The perencentage of tackles where the player wins the ball. |
| `timesTackled` | Times Tackled | TKTM | 20/20 | 20/20 | The total number of times a player has been tackled. |
| `totalClearance` | Clearances | CLR | 20/20 | 20/20 | The number of clearances attempted. |
| `totalTackles` | Tackles | TOT | 20/20 | 20/20 | The number of tackles attempted. |

### `general` (33 stats)

| Stat | Display | Abbr | EPL | LaLiga | Description |
| --- | --- | --- | ---: | ---: | --- |
| `appearances` | Appearances | APP | 20/20 | 20/20 | The number of times a player has made an appearance in a match. |
| `avgExpectedGoalDifferential` | Average Expected Goal Differential | AxGD | 20/20 | 20/20 | The average difference of average xG scored and average xG conceded. |
| `avgGoalDifferential` | Average Goal Differential | AGD | 19/20 | 18/20 | The average difference of goals scored and goals conceded. |
| `avgRatingFromCorrespondent` | Average Rating From Correspondent | RTG | 0/20 | 0/20 | The rating from a correspondent for a player. |
| `avgRatingFromDataFeed` | Average Rating From Data Feed | RTG | 0/20 | 0/20 | The rating from the data feed for a player. |
| `avgRatingFromEditor` | Average Rating From Editor | RTG | 0/20 | 0/20 | The rating from the editor(s) for a player. |
| `avgRatingFromUser` | Average Rating From Users | RTG | 0/20 | 0/20 | The average user rating for a player. |
| `dnp` | Did Not Play | DNP | 0/20 | 0/20 | The number of times a player did not play in a match. |
| `draws` | Draws | D | 0/20 | 0/20 | The number of times the scored ended even for both teams in a match and there was no extra time. |
| `duelWinPct` | Duel Win Percentage | Duel Win % | 20/20 | 20/20 | The percentage of duels won. |
| `duels` | Duels | DUEL | 20/20 | 20/20 | Total number of direct player-on-player confrontations for possession of the ball (aerial + ground duels) |
| `duelsLost` | Duels Lost | DUELL | 20/20 | 20/20 | Total number of duels over the possession of the ball where a player loses the ball - doesn't include 'overrun' situations where the attacking player takes on an opponent but the ball runs away from them out of play or to an opponent. |
| `duelsWon` | Duels Won | DUELW | 20/20 | 20/20 | Total number of duels for possession of the ball where possession was won (aerial won + ground duels won) |
| `foulsCommitted` | Fouls Committed | FC | 20/20 | 20/20 | The number of fouls comitted by a player or team. |
| `foulsSuffered` | Fouls Suffered | FA | 20/20 | 20/20 | The number of fouls suffered by a player or team. |
| `goalDifference` | Goal Difference | GD | 19/20 | 18/20 | The difference of goals scored and goals conceded. |
| `handBalls` | Handballs | HAND | 11/20 | 17/20 | The number of handball fouls committed.. |
| `losses` | Losses | L | 11/20 | 16/20 | The number of times a team has lost a match. |
| `lostCorners` | Corners Conceded | CC | 20/20 | 20/20 | The number of corners conceded to the opposing team. |
| `minutes` | Minutes | MIN | 0/20 | 0/20 | The number of minutes played by a player. |
| `ownGoals` | Own Goals | OG | 5/20 | 4/20 | The number of own goals conceded. |
| `ownGoalsAccrued` | Own Goals Accrued | OGACC | 4/20 | 4/20 | Opposition own goals |
| `passPct` | Pass Percentage | PASS% | 20/20 | 20/20 | The percentage of passes that result in the ball finding its target. |
| `redCards` | Red Cards | RC | 1/20 | 7/20 | The number of red cards that have been issued. |
| `secondYellow` | Second Yellow Cards | 2YC | 0/20 | 1/20 | Second yellow card given |
| `starts` | Starts | STRT | 20/20 | 20/20 | The number of starts a player has made in matches. |
| `subIns` | Substitute Appearances | SUB | 20/20 | 20/20 | The number of times a player has come on a sub in a match. |
| `subOuts` | Sub Out | FGA | 20/20 | 20/20 | The number of times a player has been subbed off in a match. |
| `suspensions` | Suspensions | FGA | 0/20 | 0/20 | The number of matches a player has been suspended. |
| `winPct` | Win Percentage | W% | 14/20 | 15/20 | The percentage of matches won. |
| `wins` | Wins | WINS | 14/20 | 15/20 | The number of matches won. |
| `wonCorners` | Corners Won | CW | 20/20 | 20/20 | The number of corners won. |
| `yellowCards` | Yellow Cards | YC | 20/20 | 20/20 | The number of yellow cards accumulated. |

### `goalKeeping` (21 stats)

| Stat | Display | Abbr | EPL | LaLiga | Description |
| --- | --- | --- | ---: | ---: | --- |
| `avgExpectedGoalsConceded` | Average Expected Goals Conceded | AxGC | 20/20 | 20/20 | Average number of Expected Goals Against |
| `avgGoalsConceded` | Average Goals Conceded | AGA | 18/20 | 20/20 | The average number of goals allowed by the goalkeeper. |
| `bigChanceSaves` | Big Chance Saves | BCS | 19/20 | 16/20 | Count of major scoring chances saved by the player (usually goalkeepers) |
| `cleanSheet` | Clean Sheet | CS | 13/20 | 13/20 | The number of times a goalkeeper doesn't let in a goal. |
| `crossesCaught` | Crosses Claimed | CC | 16/20 | 18/20 | The number of crosses claimed. |
| `goalsConceded` | Goals Against | GA | 18/20 | 20/20 | The number of goals allowed by the goalkeeper. |
| `partialCleenSheet` | Partial Clean Sheet | FGA | 0/20 | 0/20 | The number of times a clean sheet is kept when playing at least a part of the game. |
| `penaltyGoalsConceded` | Penalty Goals Conceded | PENGC | 4/20 | 7/20 | Penalty goal conceded (and scored) against the team in question |
| `penaltyKickConceded` | Penalty Kick Conceded | PKC | 5/20 | 8/20 | The number of goals allowed when the opposing team take a penalty. |
| `penaltyKickSavePct` | Penalty Kick Save Percentage | PK% | 0/20 | 0/20 | The percentage of penalty kicks a goalkeeper saves. |
| `penaltyKicksFaced` | Penalty Kicks Faced | PK | 0/20 | 0/20 | The number of penalty kicks faced by a goalkeeper. |
| `penaltyKicksSaved` | Penalty Kicks Saved | PKS | 0/20 | 2/20 | The number of penalty kicks saved by a goalkeeper. |
| `punches` | Punches | P | 17/20 | 11/20 | The number of punches. |
| `savePct` | Save Percentage | SV% | 20/20 | 20/20 | The percentage of shots on target that are saved by a goalkeeper. |
| `saves` | Saves | SV | 20/20 | 20/20 | The number of times a goalkeeper makes a save. |
| `shootOutKicksFaced` | Penalty Shootout Kicks Faced | PSF | 0/20 | 0/20 | The number of penalty kicks faced in a penalty shootout. |
| `shootOutKicksSaved` | Penalty Shootout Saves | PSS | 0/20 | 0/20 | The number of penalty kicks saved in a penalty shootout. |
| `shootOutSavePct` | Penalty Shoot Save Percentage | PSS% | 0/20 | 0/20 | The percentage of penalty kicks saved in a penalty shootout. |
| `shotsFaced` | Shots Faced | SHF | 20/20 | 20/20 | The number of shots on target a goalkeeper has faced. |
| `smothers` | Smothers | SM | 6/20 | 10/20 | The number of smothers. |
| `unclaimedCrosses` | Unclaimed Crosses | UC | 0/20 | 0/20 | The number of crosses that were unclaimed. |

## Stats worth building the page around

Well covered in both leagues, and meaningful to a player at a glance:

| Stat | Category | Why it earns space |
| --- | --- | --- |
| `avgExpectedGoals` | `offensive` | xG - the most recognisable modern football metric |
| `possessionPct` | `offensive` | Instantly legible team identity; pairs well with a bar |
| `goalConversion` | `offensive` | Finishing quality; a clinical-vs-wasteful axis |
| `totalShots` | `offensive` | Volume to set against conversion |
| `shotsOnTarget` | `offensive` | Accuracy half of the shooting story |
| `passPct` | `general` | Style signal; separates possession sides from direct ones |
| `bigChanceCreated` | `offensive` | Creation quality rather than raw passing |
| `cleanSheet` | `goalKeeping` | The defensive headline number players actually quote |
| `avgGoalsConceded` | `goalKeeping` | Defensive rate, comparable across matches played |
| `savePct` | `goalKeeping` | Keeper performance in one number |
| `tacklePct` | `defensive` | Defensive success rate, not just volume |
| `duelWinPct` | `general` | Physical dominance; good for a head-to-head compare |
| `recoveries` | `defensive` | Pressing / regain proxy |
| `yellowCards` | `general` | Discipline; maps to the existing amber/danger accents |

### Stats to avoid leading with

These report zero for **every** team in both leagues - either unused in league play or not
yet accrued this early in the season. Safe to store, unsafe to headline:

`avgRatingFromCorrespondent`, `avgRatingFromDataFeed`, `avgRatingFromEditor`, `avgRatingFromUser`, `dnp`, `draws`, `gameWinningAssists`, `gameWinningGoals`, `inaccurateCrosses`, `minutes`, `partialCleenSheet`, `penaltyKickSavePct`, `penaltyKicksFaced`, `shootOutGoals`, `shootOutKicksFaced`, `shootOutKicksSaved`, `shootOutMisses`, `shootOutPct`, `shootOutSavePct`, `shotsHeaded`, `suspensions`, `unclaimedCrosses`

The `shootOut*` family is structurally empty in league play - it only populates in knockout
competitions.

### Fields that contradict the standings table

Verified against the raw ESPN feed, not inferred: `teamStats.general` carries `wins`,
`draws` and `losses`, but **`draws` reports 0 for every team even when the standings say
otherwise** (Hull City sit on `ties: 1` in the EPL table while their `draws` reads 0).
`minutes` is likewise 0 across all 40 teams.

Take win/draw/loss records and anything derived from them (form, points, goal difference)
from `standings[].stats` - `wins` / `ties` / `losses` - and treat the `general` category as
the place for per-match style metrics only. This is an upstream ESPN quirk, not a gap in
the extraction.

## Known gaps

- **No headshots.** `headshot` is null for every soccer athlete on ESPN, so it is omitted.
  Player portraits remain the job of the bundled local image assets.
- **Snapshot, not live.** The asset is a point-in-time capture that does not update itself.
  Regenerate it, or layer the live `EspnLeagueStatsService` on top, before treating any
  number as current.
- **No bundled per-player season statistics.** Full roster identities are captured, but
  football stat families are still requested lazily when a player dossier opens.

## What consumes this

`LeagueStatsPackageService` decodes the asset into the models the league hub renders, and
`LeagueStatsCubit` shows it before any network call (see
[predictions.md](../product/systems/predictions.md#league-hub-data)). The hub's **STATS**
tab surfaces a curated subset of the team stats — the boards listed under
"Stats worth building the page around", grouped ATTACK / DEFENCE / KEEPING / DISCIPLINE in
`footballStatGroups` (`lib/screens/predictions/widgets/team_stat_board.dart`).

The stats **not** in that curation are still decoded and available; they are simply not
given a board, because a stat at 0/20 coverage would render an empty ranking. When
re-running the generator after more of the season has been played, re-check the coverage
tables above — stats currently at partial coverage (`redCards` at 1/20 in the EPL, for
instance) become worth promoting once they populate.
