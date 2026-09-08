# F1 race field inventory - what ESPN gives us per Grand Prix

> **Status:** BUILT
> **Last verified:** 2026-09-08
> **Scope:** Every field ESPN exposes for a Formula 1 race weekend, how populated each
> one is, and which fields are traps

Describes the asset produced by
[`tool/generate_f1_race.dart`](../../tool/generate_f1_race.dart).
Regenerate with `dart run tool/generate_f1_race.dart --race italian`; verify it with
`--check`.

The reference capture is the **2026 Pirelli Italian Grand Prix** (event `600057442`,
Autodromo Nazionale Monza, 4-6 September 2026) →
[`assets/data/f1-italian-gp.json`](../../assets/data/f1-italian-gp.json), 65.4 KB compact.

This page exists so an F1 race hub can be designed against data that demonstrably
exists. **"Reporting" counts how many of the 22 race entries carry the field at all**;
a stat at 1/22 cannot anchor a leaderboard.

---

## Which hosts work

ESPN serves F1 from three hosts and they do not behave alike.

| Host | Result | Used for |
| --- | --- | --- |
| `sports.core.api.espn.com/v2/sports/racing/leagues/f1/...` | 200 | everything structural |
| `site.web.api.espn.com/apis/v2/sports/racing/f1/standings` | 200 | championship tables |
| `site.api.espn.com/apis/site/v2/sports/racing/f1/...` | **403** | unusable offline |
| `.../racing/f1/summary?event=...` | **404** | does not exist for racing |

Two consequences, both load-bearing:

1. **The runtime service and this generator use different hosts on purpose.**
   [`espn_score_service.dart:204`](../../lib/services/espn_score_service.dart#L204)
   reads `site.api.../racing/f1/scoreboard?dates=2026`, which answers inside the app but
   returns 403 to an offline extractor. That is Akamai bot filtering rather than an F1
   problem - soccer 403s from the same shell. The generator is built on core.api.
2. **There is no `summary` document for racing.** Football and cricket each have one
   rich per-match feed; F1 has none. A race weekend is a reference graph that must be
   walked, which is why one weekend costs ~260 requests.

### The graph

```
/events/{id}                                      weekend dates, 5 sessions, circuit ref
  /circuits/{id}                                  length, laps, turns, lap record, maps
    /venues/{id}                                  address, country flag, photo
  /competitions/{id}/statistics                   session totals
  /competitions/{id}/competitors/{ath}/status     Classified / Retired + laps
  /competitions/{id}/competitors/{ath}/statistics per-driver stat sheet
/seasons/{yr}/athletes/{id}                       car number, engine, tyre, flag, birthplace
```

Season enumeration: `/seasons/{yr}/types/2/events?limit=60` gives 25 events for 2026.

---

## There is no lap-by-lap data (checked exhaustively)

The most common thing to want from a race feed is a lap chart — who led on each
lap. **ESPN does not publish one for F1, in any form.** Every candidate endpoint
was probed against the Italian GP race competition (`401839102`):

| Endpoint | Result |
| --- | --- |
| `.../competitions/{id}/laps` | **404** |
| `.../competitions/{id}/details` | **404** |
| `.../competitions/{id}/linescores` | **404** |
| `.../events/{id}/laps`, `.../events/{id}/plays` | **404** |
| `.../competitors/{ath}/laps` | **404** |
| `.../competitors/{ath}/details` | **404** |
| `.../competitors/{ath}/splits` | **404** |
| `.../competitions/{id}/plays?limit=1000` | 200, but **`count: 0`** |
| `.../competitions/{id}/odds` | 200, but **`count: 0`** |
| `.../competitions/{id}/officials` | 200, but **`count: 0`** |
| `.../competitions/{id}/situation` | 200, but an **empty `$ref` stub** |
| `.../competitions/{id}/probabilities` | **400** |
| `.../competitions/{id}/predictor`, `/powerindex`, `/leaders` | **400** |

And the one lap-shaped stat is not what its name says: **`lapsLead` sums to 4
across the entire field of a 53-lap race** (four drivers with 1 each). It is not
laps led. Nothing may present it as such, and it cannot be used to reconstruct a
lead sequence.

Consequences for anything built on this package:

- A leader-per-lap chart is **impossible without inventing data**, and must not
  be built. `test/f1_race_package_service_test.dart` pins the `lapsLead` total
  so this stays discoverable.
- The closest honest substitute — and what the STATS tab ships — is the
  **weekend position track**: position across FP1 → FP2 → FP3 → QUAL → GRID →
  FIN. Lines cross and swap the way a lap chart's do, but every point is a
  session ESPN actually recorded.
- Gap-to-leader can only be charted for cars **on the lead lap** (15 of 22 at
  Monza, counting the leader). A lapped car has no time gap in the feed;
  converting its `behindLaps` into seconds produced a fictional 1208-second axis
  in the first cut of that chart.

---

## The weekend

| Field | Italian GP value |
| --- | --- |
| `name` / `shortName` | Pirelli Italian Grand Prix / Pirelli Italian GP |
| `abbreviation` | `ITA` - also the key into the standings per-race grid |
| `date` to `endDate` | 2026-09-04T10:30Z to 2026-09-06T13:00Z (**the whole weekend**, not race day) |
| `links` | summary, report, circuit, results (espn.com) |
| `defendingChampion` | refs into the **prior** season: driver `4665`, constructor `106921` |

### Circuit (`/circuits/615`)

Genuinely rich, and the best material in the whole feed:

`fullName` Autodromo Nazionale Monza - `city`/`country` Monza, Italy - `lengthKm` 5.793 -
`distanceKm` 306.72 - `laps` 53 - `turns` 11 - `direction` Clockwise - `established` 1950 -
lap record **1:20.901** by driver `5579` in 2025.

Plus **track maps**, each shipped as both SVG and JPG at 2000x1125 - the generator keeps
the SVG of each variant: `circuit`, `circuitDark`, `circuitInfo`, `circuitInfoDark`,
`day`, `dayDark`. The venue also carries a photograph.

### Images that resolve

| Asset | URL | |
| --- | --- | --- |
| Driver headshot | `a.espncdn.com/i/headshots/rpm/players/full/{athleteId}.png` | works |
| Country flag | `a.espncdn.com/i/teamlogos/countries/500/{code}.png` | works |
| Circuit map | `a.espncdn.com/i/venues/f1/circuit/{venueId}.svg` | works |
| Constructor logo | `a.espncdn.com/i/teamlogos/f1/500/{id}.png` | **404 - none exist** |

There are no constructor logos. Team identity has to come from `color` (Mercedes
`00D2BE`, Ferrari `DC0000`, ...), which every constructor does carry.

---

## Sessions

Five competitions per weekend, 22 entries each: **FP1, FP2, FP3, Qualifying, Race**.
(A sprint weekend would add sessions; only a conventional weekend has been captured.)

Session-level `statistics` yields just `laps` (53) and `length` (306). Four further
fields - `avgSpeed`, `victoryMargin`, `poleSpeed`, `poleTime` - are defined but come
back `.000` on a completed race, so the generator drops them.

Per entry: `position` (finish order), `grid` (race only), `winner`, car `number`,
`constructor`, `teamColor`, and a `status` of **Classified** or **Retired** with the lap
count reached. Across the Italian GP weekend: 107 Classified, 3 Retired.

### Coverage per session (of 22 entries)

| Stat | FP1-3 | Qual | Race | Notes |
| --- | :-: | :-: | :-: | --- |
| `place` | 22 | 22 | 22 | finishing/classified order |
| `lapsCompleted` | 22 | 22 | 22 | |
| `totalTime` | 22 | 22 | **15** | race: **lead-lap finishers only** |
| `behindTime` | 21 | 21 | **14** | gap to leader, `+3.857`; leader has none |
| `behindLaps` | - | - | **7** | lapped/retired cars instead of `behindTime` |
| `qual1TimeMS` | - | 22 | - | |
| `qual2TimeMS` | - | **16** | - | absent = knocked out in Q1 |
| `qual3TimeMS` | - | **10** | - | absent = knocked out in Q1/Q2 |
| `championshipPts` | 0 | 0 | 22 (10 non-zero) | |
| `pitsTaken` | - | - | 21 | |
| `lapsLead` | - | - | **4** | |
| `fastestLap` / `fastestLapNum` | - | - | **1** | only the outright fastest-lap setter |
| `top5` / `top10` / `wins` | - | - | 22 | flags, derivable from `place` |
| `bonus` / `penaltyPts` | 22 | 22 | 22 | **always zero** in this capture |

`behindTime` and `behindLaps` are mutually exclusive: lead-lap cars get a time gap,
lapped cars get a lap count. Together they cover 21 of 22.

### Drivers

The weekend fields **26** drivers, not 22 - four reserves ran FP1 only (Ayumu Iwasa,
Luke Browning, Paul Aron, Colton Herta). Anything joining sessions to a driver list must
not assume the race entry list covers the weekend.

Per driver: full/display/short name, three-letter `abbreviation`, slug, date of birth,
birthplace city, country flag + name, headshot, car `number`, `team`, `engine`, `tire`,
and a resolved `constructorId` (26/26).

---

## Championship standings

One call returns **both** tables: 23 driver rows (23 for 22 seats - mid-season changes)
and 11 constructor rows. Each row carries `rank`, `points`, and a **per-race points grid
keyed by the 3-letter GP code** across all 25 rounds - so a whole season's scoring
history arrives with any single race.

Through Monza: Antonelli 267 (ITA 25), Russell 201 (ITA 18), Hamilton 191 (ITA 8);
Mercedes 468 (ITA 43), Ferrari 346, McLaren 287.

In the grid, a **blank cell means the race has not happened** and **`-` means the
entrant raced and scored nothing**. The generator omits the first and stores 0 for the
second; conflating them would show future rounds as scoreless.

---

## Traps

These are encoded in the generator; they are listed here because each one produces
plausible-looking wrong output if handled naively.

1. **`pole` is not a pole flag.** In a race stat sheet it holds the driver's *grid
   slot* - the Italian GP winner's value is `19`, because he started 19th. Dropped at
   extraction; `grid` comes from the competitor's `startOrder`.
2. **Grid is not qualifying position.** Antonelli qualified **P7** and started **P19**
   after a penalty. Only `startOrder` reflects that, and ESPN sets it on the race
   session alone (0/22 on practice and qualifying).
3. **`totalTime` exists only for lead-lap finishers** (15/22). Lapped and retired
   drivers have none, so a results table must fall back to laps + status.
4. **`fastestLap` is populated for exactly one driver** - the outright fastest-lap
   setter, not each driver's own best. There is no per-driver personal best in the race.
5. **A qualifying `0.000` means eliminated, not a lap.** Serialised as an absent key so
   nothing renders a 0.000s Q3.
6. **`avgSpeed`, `victoryMargin`, `poleSpeed`, `poleTime` are always `.000`.** Dropped;
   a `victoryMargin` card would have shown 0.000 for a 3.857s win.
7. **Constructor `abbreviation` is junk** - Mercedes is `"LP"`, Ferrari `"JK"`. Use
   `name`; not carried through.
8. **`/seasons/{yr}/manufacturers` returns 347 historical entries**, not the current
   grid. The 11 constructors come from the standings feed.
9. **`bonus` and `penaltyPts` are always 0** - real fields, no data behind them.
10. **`qual2TimeMS`/`qual3TimeMS` descriptions are copy-paste wrong** upstream: all
    three say "Time for the first qualifying run". Trust the name, not the description.

---

## Reading the JSON

```jsonc
{
  "generatedAt", "source": "espn", "sport": "motorsport",
  "series": { "id": "2030", "slug": "f1", "name": "Formula 1", "color": "ff1E00" },

  // Hoisted once for the file rather than repeated on all 110 classification rows.
  "statDictionary": { "<statName>": { "displayName", "shortDisplayName",
                                      "abbreviation", "description" } },

  "race": {
    "id", "name", "shortName", "abbreviation", "season", "seasonType",
    "startDate", "endDate", "links", "defendingChampion": { "driverId", "constructorId" },
    "circuit": { "id", "fullName", "city", "country", "countryFlag", "type",
                 "lengthKm", "distanceKm", "laps", "turns", "direction", "established",
                 "lapRecord": { "driverId", "time", "year" },
                 "diagrams": { "circuit", "circuitDark", ... }, "photo" }
  },

  "drivers":      { "<athleteId>": { ...identity, "number", "constructorId",
                                     "team", "engine", "tire", "headshot" } },
  "constructors": { "<teamId>":    { "id", "name", "displayName", "color" } },

  "sessions": [{
    "id", "order", "type": { "id", "text", "abbreviation" }, "date",
    "stats": { "<statName>": [value, "displayValue"] },
    "classification": [{
      "position", "driverId", "grid", "winner", "number", "constructor", "teamColor",
      "status": { "name", "description", "completed", "laps" },
      "stats":  { "<statName>": [value, "displayValue"] }
    }]
  }],

  "standings": {
    "season", "throughRace", "raceCodes": ["AUS", ..., "ITA", ...],
    "drivers":      [{ "rank", "driverId", "name", "points", "byRace": { "ITA": 25 } }],
    "constructors": [{ "rank", "constructorId", "points", "byRace": { "ITA": 43 } }]
  }
}
```

Every stat is a `[value, displayValue]` pair, matching
[`football-league-stats.json`](../../assets/data/football-league-stats.json): the number
sorts, the string renders (`83504` / `"1:23.504"`). Keys are sorted so a re-run is
byte-identical and `--check` means something.
