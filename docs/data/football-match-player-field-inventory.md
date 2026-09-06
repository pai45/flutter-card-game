# Football match player field inventory

**Status:** BUILT
**Source:** ESPN, event `401879318` (Fulham 2–3 Chelsea, `eng.1`, 2026-08-24)
**Asset:** `assets/data/football-revamp.json`
**Generator:** `tool/generate_football_match_players.dart`
**Probed:** 2026-09-06

What ESPN actually publishes per player for a single football match, so the
player card can be designed against real availability instead of guesswork.
Numbers here are the values the generator asserts on every run — if ESPN's
history shifts, the generator fails loudly rather than writing a thinner asset.

---

## 1. Where each piece comes from

| Data | Feed | Cost | Availability |
|---|---|---|---|
| Per-player stat sheet | `site.api.espn.com/apis/site/v2/sports/soccer/{slug}/summary?event={id}` → `rosters[].roster[].stats` | Already fetched for the lineup | **All 40 players** |
| Starter / bench, jersey, position, `formationPlace` | same response | — | All 40 |
| `subbedIn` / `subbedOut` | same response | — | Booleans only, **no minute** |
| Substitution minutes | plays feed, `type.type == "substitution"` → `participants[].type` + `clock.displayValue` | — | 9 subs, both sides |
| Touch coordinates | `sports.core.api.espn.com/v2/.../events/{id}/competitions/{id}/plays?limit=1000` (2 pages) | **~1.5 MB** | 31 of 40 players |
| Per-shot xG | same plays feed, `expectedGoals` / `expectedGoalsOnTarget` | — | 29 shot plays |

The size split is why the app treats these differently: the stat sheet is free
and is parsed on the **live** path for every football fixture
(`espn_soccer_lineup_parser.dart`), while touches are baked into the bundled
asset only. A 1.5 MB fetch per fixture is not worth a heatmap.

## 2. The 15 stats

All 40 players return exactly 14 entries; the 15th varies by position. A missing
key means **not applicable**, not zero — the parser stores it as absent and the
card omits the pill.

| ESPN key | Card label | Group | Coverage |
|---|---|---|---|
| `totalGoals` | GOALS | ATTACK | 40 |
| `goalAssists` | ASSISTS | ATTACK | 40 |
| `totalShots` | SHOTS | ATTACK | 40 |
| `shotsOnTarget` | ON TARGET | ATTACK | 40 |
| `offsides` | OFFSIDES | ATTACK | **36 — outfield only** |
| `foulsSuffered` | FOULS WON | INVOLVEMENT | 40 |
| `foulsCommitted` | FOULS MADE | INVOLVEMENT | 40 |
| `appearances` | APPS | INVOLVEMENT | 40 |
| `subIns` | SUB ON | INVOLVEMENT | 40 |
| `yellowCards` | YELLOW | DISCIPLINE | 40 |
| `redCards` | RED | DISCIPLINE | 40 |
| `ownGoals` | OWN GOALS | DISCIPLINE | 40 |
| `saves` | SAVES | GOALKEEPING | **4 — keepers only** |
| `shotsFaced` | SHOTS FACED | GOALKEEPING | 40 (0 for outfielders) |
| `goalsConceded` | CONCEDED | GOALKEEPING | 40 (team total, not personal) |

Labels are curated in Dart (`kFootballPlayerStatCatalog`), not read from the
asset: ESPN's own `displayName` is inconsistent for this feed and the live path
has no dictionary to read from. A test asserts every shipped key resolves in the
catalogue, so a 16th stat fails loudly instead of rendering a machine-cased key.

**Not available at all:** passes, pass accuracy, distance covered, top speed,
duels, tackles, interceptions, touches (as a stat), or any player rating. The
touch *count* on the card is derived from the plays feed, not published.

## 3. Positional tracking

- **1,577 plays**; 974 carry `fieldPositionX/Y`, 989 name an athlete.
- Intersection: **1,521 attributed touches across 31 players.**
- All **22 starters** have ≥ 35 touches (max 104, Jorge Cuenca).
- Substitutes who came on: 7–32 touches.
- The **9 unused substitutes have none**, which is correct and is what drives
  the card's "stayed on the bench" state.

### Coordinate frame — calibrated, not assumed

Identical to the frame `FootballShot` already documents, verified against
known-position events:

| Event type | Median x | Median y | Reading |
|---|---|---|---|
| Goal kick | 4.9 | 50.3 | own goal area |
| Save | 6.1 | 50.2 | defending own goal |
| Throw in | 58.0 | **0.0 / 100.0** | touchlines |
| Goal | 91.1 | 48.4 | attacked goal |
| Shot on target | 88.8 | 43.3 | attacking third |

So `x` is **progress toward the goal being attacked**, expressed in the acting
side's own frame for *both* teams (both keepers' goal kicks sit at x≈5), and `y`
runs across the pitch 0–100 with the attacker's **left** as the high value.
Mirroring lives in one place, `footballAttackingOffset`.

**The feed overflows its own frame** — observed x 0.2–101.8 and y −1.6–101.8 on
events that leave the pitch — so both axes must be clamped. A test locks this.

## 4. Player images

- **ESPN publishes no headshots for soccer.** Three URL patterns tested against
  `a.espncdn.com/i/headshots/soccer/...`; all 404 for every athlete id.
- The bundled `assets/player_images/` library is the card game's roster, not
  these squads: it resolves **2 of these 40** (A. Robinson, R. James).
- **Every one of the 40 has a working kit render**:
  `stitcher.espn.com/sports/soccer/leagues/{slug}/events/{event}/athletes/{id}/jersey.png?darkMode=true`
  → HTTP 200, 1440×1440 PNG, ~240 KB, light and dark variants. Verified to load
  in the browser, so it is not CORS-blocked (unlike ESPN's JSON APIs).
  Always decode it downscaled — 40 × 1440² would be a memory trap.

## 5. Asset shape and size

`assets/data/football-revamp.json`: **82.7 KB → 96.1 KB.**

Root gains `espnEventId`, `playerStatKeys`, `playerStatsGeneratedAt`. Each
player gains `stats`, optional `subIn`/`subOut`/`xg`/`xgot`, and `t1`/`t2`.

Four size decisions:

1. `stats` is a **positional array** zipped against the hoisted `playerStatKeys`
   — not 40 copies of 15 key names.
   **It is order-fragile: never reorder one without the other.**
2. Touches are a **flat `[x,y,x,y]`** array, not a list of pairs.
3. Touches are **integers**. One unit is 1.05 m and the heatmap bins at ~4.4 m,
   so rounding is lossless for this use.
4. Touches split into `t1`/`t2` **by half**, which buys the UI a free 1ST/2ND
   filter at zero byte cost versus storing a period per coordinate.

The file stays **pretty-printed** (unlike `football-league-stats.json`) because
it is hand-authored — its commentary and timeline prose cannot be regenerated
and people need to read and edit it. Only all-numeric arrays are inlined; the
asset contained no numeric array before, so that rule reformats nothing that was
already there.

The generator **merges and never rewrites**, asserting every pre-existing
subtree is byte-identical before writing.
