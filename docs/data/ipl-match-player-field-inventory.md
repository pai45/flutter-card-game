# IPL match player field inventory

**Status:** BUILT
**Source:** ESPN, league `8048` (Indian Premier League), event `1535465`
(Royal Challengers Bengaluru 161/5 beat Gujarat Titans 155/8, IPL 2026 final,
2026-05-31)
**Asset:** `assets/data/cricket-revamp.json`
**Generator:** `tool/generate_cricket_match_players.dart`
**Probed:** 2026-09-07

What ESPN actually publishes per player for a single cricket match, so the
player card is designed against real availability. Numbers here are asserted by
the generator on every run — if ESPN's history shifts, it fails loudly rather
than writing a thinner asset.

---

## 1. The headline finding: no coordinates exist

**ESPN publishes no positional data for cricket at all.** No wagon wheel, no
pitch map, no line and length, no field placement. The core `plays` feed that
gives football its `fieldPositionX/Y` **does not exist for this sport**:

```
sports.core.api.espn.com/v2/sports/cricket/leagues/8048/events/1535465/competitions/1535465/plays
→ HTTP 400  {"error":{"message":"Invalid sport/league combination (cricket/8048)"}}
```

A search of every key in the play-by-play response returns nothing positional
(the only near-hit is `fielder`, which names a person, not a place).

So the cricket dossier's hero visual is an **innings tape** — the sequence of
deliveries — not a heatmap. That is a data constraint, not a design preference.
Do not go looking for a wagon wheel again.

## 2. Where each piece comes from

| Data | Feed | Cost | Availability |
|---|---|---|---|
| Per-player stat sheet | `site.api.espn.com/apis/site/v2/sports/cricket/8048/summary?event={id}` | Already fetched for the scorecard | **All 24 players** |
| Captain / keeper / styles | same response (`athlete.style[]`, `position`) | — | All 24 |
| Ball-by-ball | `.../cricket/8048/playbyplay?event={id}&limit=1000` | ~64 KB | **All 233 deliveries** |
| Positional | — | — | **None. See §1.** |

The stat sheet is free — it rides on the response the scorecard already needs —
so it is parsed on the **live** path too (`espn_cricket_roster_parser.dart`) and
every cricket fixture gets a player card. Ball-by-ball is a separate request, so
it is baked into the bundled asset only.

### The nesting differs from football

Football puts a flat `stats` array on each roster entry. Cricket buries them:

```
rosters[].roster[].linescores[].linescores[].statistics.categories[].stats[]
```

One block per innings, so a player who batted in one and bowled in another
contributes to both. The parser folds them by **larger magnitude**, not sum —
ESPN sends a zero-filled block for the discipline a player did not play, and
summing would double-count it.

## 3. The 46 stats

All 24 players return all 46 names. 45 are numeric; **`dismissalCard` is a
display string** and is skipped. `dismissal` is a dismissal-TYPE code, not a
count — it reads 12 for a not-out batter — so it is deliberately not shown.

| Group | Keys shown on the card |
|---|---|
| **BATTING** | `runs`, `ballsFaced`, `fours`, `sixes`, `strikeRate`, `battingPosition`, `minutes`, `fiftyPlus`, `notouts`, `ducks` |
| **BOWLING** | `wickets`, `overs`, `conceded`, `economyRate`, `maidens`, `dots`, `wides`, `noballs`, `foursConceded`, `sixesConceded`, `fourPlusWickets` |
| **FIELDING** | `caught`, `caughtKeeper`, `stumped`, `dismissals` |

Also published but deliberately unused: `balls`, `batted`, `bowled`,
`bowlingPosition`, `bpo`, `caughtFielder`, `dismissal`, `dismissalCard`,
`fielded`, `fielderKeeper`, `fielderSub`, `fiveWickets`, `hundreds`,
`illegalOverLimit`, `innings`, `inningsBowled`, `inningsFielded`,
`inningsNumber`, `outs`, `retiredDescription`, `tenWickets` — chrome, or
season-shaped counters that are always 0 in a T20.

Labels are curated in Dart (`kCricketPlayerStatCatalog`), not read from the
asset, because the live path has no dictionary to read from. A test asserts
every catalogued key is actually shipped — it already caught one invented key
(`catches`; ESPN calls it `caught`).

## 4. Ball-by-ball

- **233 deliveries**, 124 in the first innings and 109 in the second.
- Each names the `batsman`, the `bowler`, `over.number` (1-based), `over.ball`
  (1-based within the over, **counting extras**), `playType`, `scoreValue` and a
  full `dismissal` object naming the fielder.
- `playType` universe for this match: `no run`, `run`, `four`, `six`, `wide`,
  `leg bye`, `out`.
- Substitutions and innings breaks are separate items with no batter, and are
  skipped.

### The rule that makes it reconcile

**A wide is not a ball faced; a leg bye is. Runs off the bat exclude both.**

With that rule, rebuilding every batter's innings from the ball feed reproduces
the stat sheet **exactly for all 12 batters** — runs *and* balls faced (Kohli
75(42), Sundar 50(37), …) — and also matches the hand-transcribed `scorecard[]`
already in the asset. Three independent sources agreeing is what makes the tape
safe to draw, and the generator asserts it on every run.

### Phases

Overs 1–6 powerplay, 7–15 middle, 16–20 death — the standard T20 split, and the
basis of the card's phase strip.

## 5. Player images — better than football

| Source | Coverage of these 24 |
|---|---|
| Bundled `assets/cricketer_images/` | **18** by the plain slug, **22** once the resolver reaches the odd-named files |
| ESPN headshot (`athlete.headshot.href`) | **9** resolve; the other 15 return 404 despite the href being present |
| Neither | **2** — Jacob Duffy, Nishant Sindhu |

Cricket athletes *do* carry a real `headshot` (soccer athletes carry none at
all), but it is a partial middle fallback, not a primary source.

**The resolver fix:** 20 of the 180 bundled images were unreachable because they
are named `10_Tim_David.webp` or `Bhuvneshwar_Kumar.webp` while
`cricketPortraitAssetForName` lowercases. `cricketPortraitAliases` in
`lib/models/cards.dart` now maps them, which rescues all 20 app-wide — including
four players in this very fixture.

## 6. Asset shape and size

`assets/data/cricket-revamp.json`: **114.6 KB → 128.9 KB.**

The generated layer lives **entirely at the root**, keyed by athlete id:
`espnEventId`, `playerStatKeys`, `playerStats`, `deliveryAthletes`,
`deliveryOutcomes`, `deliveries`, `playerStatsGeneratedAt`.

```jsonc
"deliveries": [ [innings, over, ball, batIdx, bowlIdx, runs, outcomeIdx, wicket], … ]
```

`batIdx`/`bowlIdx` index `deliveryAthletes`; `outcomeIdx` indexes
`deliveryOutcomes` (by name, so the list can grow without shifting meanings).
One shared array, not per-player copies — a ball belongs to both a batter and a
bowler.

**Why root-level, and why a text splice:** this asset is hand-transcribed and
its commentary, notes and innings progressions have no generator that could
reproduce them. An early attempt to decode, merge and re-encode reflowed
thousands of lines, because the file mixes formatting styles — `inningsProgress`
points sit on one line each while player `batting[]` entries are expanded, and
no single structural rule reproduces both. The generator now **splices text
before the closing brace and re-encodes nothing**, so the diff is 346 added
lines and 1 removed (the previous last bracket gaining a comma). It refuses to
run twice over the same file.

`playerStats` values are **positional against `playerStatKeys`** — never reorder
one without the other.

---

## 7. League-level data (the IPL hub)

The hub's TABLE, LEADERS and STATS need season data, and cricket has almost none
of the feeds football uses.

| Feed | Football | Cricket (IPL 8048) |
|---|---|---|
| Standings | `site.web.api.espn.com/apis/v2/sports/soccer/{slug}/standings` | **Works** — `.../sports/cricket/8048/standings`, 10 teams |
| Season leaders | `sports.core.api.espn.com/.../leaders` | **HTTP 400** — core API rejects the sport |
| Per-team season statistics | `sports.core.api.espn.com/.../teams/{id}/statistics` | **HTTP 400** — same |
| Site statistics | `site.api.espn.com/.../{slug}/statistics` | **HTTP 403** |

So **LEADERS and STATS are aggregated from every match summary of the season**
by `tool/generate_cricket_league_stats.dart` → `assets/data/cricket-league-stats.json`
(135.9 KB). It walks the 62-date calendar for event ids, stores all **74**
normalized fixtures, fetches every completed summary, and sums the 46-stat
sheets into per-player and per-team season totals. The package keeps all
**202** season participants rather than only top-25 leaderboard athletes.

Notes that cost time to discover:

- **A completed cricket match has no `completed` boolean.** The scoreboard marks
  it `status.type.state == 'post'` (description "Result"). Filtering on
  `completed == true` silently returns zero matches.
- **Rates must be recomputed from season totals, never averaged.** Averaging
  per-match strike rates would weight a 4-ball cameo like a 60-ball innings.
- **Rate boards need a qualifying minimum** (100 balls faced, 120 balls bowled),
  or whoever bowled one tidy over tops the economy chart. The minimum is shown
  in the board's headline.
- **`qualified` arrives as the numeric `1`** on the four playoff teams and is
  absent elsewhere; only its `displayValue` is the string `'Y'`.
- **ESPN's cricket position taxonomy has no "Batter"** — a specialist batter
  can come back as the literal string `"Unknown"`, so
  the decoder drops it rather than printing UNKNOWN under a leader's name.
- **The generator refuses a partial season.** A single 502 mid-run would
  otherwise understate whoever played in that match, with nothing downstream
  able to tell.
- ESPN rate-limits an IP hard (403 across all sports for tens of minutes), so
  the generator runs at concurrency 2 with a `--delay` between requests.

The 2026 leaders it produces: Vaibhav Sooryavanshi 776 runs, Kagiso Rabada 29
wickets, Sunil Narine 6.65 economy.
