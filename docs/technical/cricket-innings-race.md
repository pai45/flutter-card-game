# Cricket Innings Race — implementation and porting reference

> **Status:** BUILT
> **Last verified:** 2026-09-12
> **Scope:** `_CricketRace` and its six helpers in
> [`lib/screens/predictions/widgets/cricket_match_stats_view.dart`](../../lib/screens/predictions/widgets/cricket_match_stats_view.dart)
> — the **RACE** tab of a cricket match's STATS view, which stacks two charts:
> `INNINGS RACE` and `INNINGS RUN RATE`.

**Written to be portable.** Everything `_CricketRace` declares is reproduced
*exactly as implemented*, in the section that explains it. The appendices add the
models and stand-ins.

> **Related docs.** The RACE tab is also covered as §6–§7 of
> [`cricket-match-stats-view.md`](cricket-match-stats-view.md), which documents the
> whole four-tab view and carries the charting engine in its Appendix B. **This
> file is the deeper, standalone treatment of the race itself** — every branch, both
> charts' asymmetries, and the helpers' edge cases. Use this one to rebuild the
> race; use that one for the surrounding view. The charting engine
> (`CyberChartPanel`, `ChartSeries`, `ChartMarker`, `CyberChartPainter`) is given in
> full in [`match-momentum-chart.md`](match-momentum-chart.md) §7–§14 and is **not**
> repeated here.

---

## 0. Port map

| # | Layer | Source | Here |
| --- | --- | --- | --- |
| 1 | The tab | `_CricketRace` + `_CricketRaceState` | §4 — verbatim |
| 2 | Chart 1 | the `INNINGS RACE` panel in `build` | §5 |
| 3 | Chart 2 | `_buildRunRatePanel` | §6 |
| 4 | Helpers | `_pointsForRange`, `_scoreAt`, `_overLabels`, `_wicketMarkers`, `_deliveryOverLabels`, `_runRateBoundaryMarkers` | §7 — verbatim |
| 5 | Models | `CricketInningsProgress`, `CricketScoreProgressPoint`, `CricketInningsRateProgress`, `CricketInningsRatePoint` | App. A — verbatim |
| 6 | Charting engine | `CyberChartPanel` & co. | [`match-momentum-chart.md`](match-momentum-chart.md) §7–§14 |
| 7 | Tokens + stand-ins | `Cyber`, `paletteForTeam` | App. B |

**Toolchain**

- **Dart 3** — an if-case pattern with a binding
  (`if (point.boundary case final boundary?)`) in `_runRateBoundaryMarkers`.
- **Flutter 3.27+** — `Color.withValues` (via the engine and `Cyber`).
- **Fonts** — Orbitron + Onest, via the engine.
- **No third-party packages.** `flutter/material.dart` and
  `flutter/services.dart` (`HapticFeedback`).

---

## 1. What it is

Two stacked charts answering two different questions about the same match.

**`INNINGS RACE`** puts *both* innings' worms on one axis, so you can see which
side was ahead at any given over. The old static worm made you eyeball that
comparison; here, scrubbing reads out **both** scoreboards at the same over
simultaneously — `RCB 161/5` and `GT 155/8` — which is the entire reason the chart
exists.

**`INNINGS RUN RATE`** plots one innings' run rate ball by ball, with every
boundary pinned on the trace as a numbered gold badge, and — when that innings is
chasing — the required rate drawn over it in magenta so the two lines cross where
the chase turned.

```
_CricketRace(match, enableFeedback)
  ├─ either innings missing / < 2 points → CyberNoDataState('Race data unavailable')
  └─ ListView (key: cricket-stats-race)
       ├─ TweenAnimationBuilder(0→1, 760ms)
       │    └─ CyberChartPanel  INNINGS RACE        glow: progress < 1
       │         ranges  20 OV | POWERPLAY | DEATH
       │         series  HOME (fill) + AWAY,  readout → "161/5"
       │         markers wickets as diamonds, home top / away bottom
       │         context "12.0 OV"
       └─ _buildRunRatePanel
            ├─ no rate timelines → CyberNoDataState('Run-rate data unavailable')
            └─ TweenAnimationBuilder(0→1, 620ms, re-keyed per innings)
                 └─ CyberChartPanel  INNINGS RUN RATE    glow: false
                      ranges  1ST INNINGS | 2ND INNINGS   ← repurposed as a switch
                      series  RUN RATE (+ REQUIRED RATE when chasing)
                      markers boundaries as gold value-dots labelled 4 / 6
                      context "12.3 OV"
```

---

## 2. The two charts are deliberately asymmetric

They look like a matched pair and are not. Every difference is a decision:

| | INNINGS RACE | INNINGS RUN RATE |
| --- | --- | --- |
| `glow` | `progress < 1` — glows during its reveal | **`false`** — never glows |
| Reveal | `760 ms` | `620 ms`, **re-keyed per innings** |
| `ranges` used as | a real range filter (over windows) | **an innings switch** |
| Series | 2 (both innings) | 1, or 2 when chasing |
| `fill` | home only | none |
| Markers | wickets, edge-pinned diamonds | boundaries, on-trace value dots |
| Marker colour | team identity | `Cyber.gold` |
| Haptic | none | `enableFeedback`-gated |

**The glow split is the glow rule.** Two panels sit in one scroll view; if both
glowed on entry there would be two focal moments competing. The race is the
headline, so it gets the reveal glow and the run rate stays calm.

**`fill: true` on the home series only** is the engine's "one focal series per
chart" rule (see `ChartSeries.fill`). Contrast the momentum chart, which fills
*both* — legitimate there only because its two series occupy opposite halves of a
mirrored axis and cannot overlap. Here both worms climb the same half, so a second
wash would muddy the first. **Do not add `fill` to the away series.**

**The range tabs are repurposed on the second chart.** `CyberChartRangeTabs` is
generic — equal-width labels with one active — so the run-rate panel passes innings
names as `ranges` and maps the label back to an `int` in `onRangeChanged`. Reusing
the component beats building a second tab strip, and the player reads it as the
same control.

---

## 3. The data contract

| Read | For |
| --- | --- |
| `cricketDetails.inningsProgress` | per-over cumulative score, one entry per innings — drives INNINGS RACE |
| `cricketDetails.inningsRateProgress` | per-legal-delivery progression — drives INNINGS RUN RATE |
| `cricketDetails.innings` | `target`, to decide whether REQUIRED RATE exists |
| `match.home` / `match.away` (`.id`, `.shortName`) | matching timelines to sides, and labels |
| `match.sport`, `match.leagueId` | palette lookup |

The two feeds are **separate on purpose**: `inningsProgress` is a compact per-over
sample, `inningsRateProgress` is every legal delivery. Keeping them apart lets the
player-facing ball feed stay editorial while the charts still get every plotted
ball. A port can supply one without the other — each chart degrades to its own
no-data state independently, which is pinned by a test.

Timelines are matched to sides **by `teamId`, never by list order**:

```dart
final homeTimeline = timelines.where((item) => item.teamId == match.home.id);
```

In the run-rate panel the same idea resolves the colour:
`timeline.teamId == match.home.id ? match.home : match.away`. Keep that — innings 1
is not reliably the home side.

---

## 4. The tab — `_CricketRace`

Verbatim:

```dart
/// RACE: both innings worms on one axis. Scrubbing reads out BOTH scores at the
/// same over — the comparison the old static worm made you eyeball.
class _CricketRace extends StatefulWidget {
  const _CricketRace({required this.match, required this.enableFeedback});
  final SportMatch match;
  final bool enableFeedback;

  @override
  State<_CricketRace> createState() => _CricketRaceState();
}

class _CricketRaceState extends State<_CricketRace> {
  static const _ranges = ['20 OV', 'POWERPLAY', 'DEATH'];
  String _range = _ranges.first;
  int _selectedInnings = 1;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final details = match.cricketDetails;
    final timelines =
        details?.inningsProgress ?? const <CricketInningsProgress>[];
    final homeTimeline = timelines.where(
      (item) => item.teamId == match.home.id,
    );
    final awayTimeline = timelines.where(
      (item) => item.teamId == match.away.id,
    );
    if (homeTimeline.isEmpty ||
        awayTimeline.isEmpty ||
        homeTimeline.first.points.length < 2 ||
        awayTimeline.first.points.length < 2) {
      return const CyberNoDataState(
        icon: Icons.show_chart,
        title: 'Race data unavailable',
        message: 'Both innings need published scoring samples for this race.',
      );
    }

    final home = _pointsForRange(homeTimeline.first.points, _range);
    final away = _pointsForRange(awayTimeline.first.points, _range);
    final homeColor = paletteForTeam(
      match.home,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final awayColor = paletteForTeam(
      match.away,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    return ListView(
      key: const ValueKey('cricket-stats-race'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 760),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => CyberChartPanel(
            chartKey: const ValueKey('cricket-innings-race-graph'),
            title: 'INNINGS RACE',
            caption: '${home.length} OVERS',
            height: 250,
            yAxisLabels: true,
            gridDivisions: 4,
            glow: progress < 1,
            revealProgress: progress,
            ranges: _ranges,
            activeRange: _range,
            onRangeChanged: (range) => setState(() => _range = range),
            markers: _wicketMarkers(
              home,
              away,
              homeColor: homeColor,
              awayColor: awayColor,
            ),
            xAxisLabels: _overLabels(home),
            contextLabelAt: (index) =>
                '${home[index.clamp(0, home.length - 1)].over}.0 OV',
            series: [
              ChartSeries(
                label: match.home.shortName.toUpperCase(),
                color: homeColor,
                fill: true,
                readout: (value, index) => _scoreAt(home, index),
                values: [for (final point in home) point.runs.toDouble()],
              ),
              ChartSeries(
                label: match.away.shortName.toUpperCase(),
                color: awayColor,
                readout: (value, index) => _scoreAt(away, index),
                values: [for (final point in away) point.runs.toDouble()],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildRunRatePanel(match, details!),
      ],
    );
  }

  Widget _buildRunRatePanel(SportMatch match, CricketMatchDetails details) {
    final available =
        details.inningsRateProgress
            .where((timeline) => timeline.points.length >= 2)
            .toList()
          ..sort((a, b) => a.innings.compareTo(b.innings));
    if (available.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.speed,
        title: 'Run-rate data unavailable',
        message: 'Legal-delivery progression has not been published.',
      );
    }

    final timeline = available.firstWhere(
      (item) => item.innings == _selectedInnings,
      orElse: () => available.first,
    );
    final innings = details.innings.firstWhere(
      (item) => item.number == timeline.innings,
      orElse: () => details.innings.first,
    );
    final team = timeline.teamId == match.home.id ? match.home : match.away;
    final teamColor = paletteForTeam(
      team,
      sport: match.sport,
      competition: match.leagueId,
    ).secondaryTextColor;
    final points = timeline.points;
    final labels = [
      for (final item in available)
        item.innings == 1 ? '1ST INNINGS' : '2ND INNINGS',
    ];
    final activeLabel = timeline.innings == 1 ? '1ST INNINGS' : '2ND INNINGS';
    final target = innings.target;

    return TweenAnimationBuilder<double>(
      key: ValueKey('run-rate-${timeline.innings}'),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeOutCubic,
      builder: (context, progress, _) => CyberChartPanel(
        chartKey: const ValueKey('cricket-innings-run-rate-graph'),
        title: 'INNINGS RUN RATE',
        caption: '${team.shortName.toUpperCase()} // ${points.length} BALLS',
        height: 250,
        yAxisLabels: true,
        gridDivisions: 4,
        glow: false,
        revealProgress: progress,
        ranges: labels,
        activeRange: activeLabel,
        onRangeChanged: (label) {
          final selected = label == '1ST INNINGS' ? 1 : 2;
          if (selected == _selectedInnings) return;
          if (widget.enableFeedback) HapticFeedback.selectionClick();
          setState(() => _selectedInnings = selected);
        },
        markers: _runRateBoundaryMarkers(points),
        xAxisLabels: _deliveryOverLabels(points),
        contextLabelAt: (index) =>
            '${points[index.clamp(0, points.length - 1)].over} OV',
        series: [
          ChartSeries(
            label: 'RUN RATE',
            color: teamColor,
            readout: (value, _) => value.toStringAsFixed(2),
            values: [for (final point in points) point.runRate],
          ),
          if (target != null)
            ChartSeries(
              label: 'REQUIRED RATE',
              color: Cyber.magenta,
              strokeWidth: 1.8,
              readout: (value, _) => value.toStringAsFixed(2),
              values: [
                for (final point in points)
                  point.requiredRunRate(target: target),
              ],
            ),
        ],
      ),
    );
  }
}
```

### 4.1 The guard, and the `details!` that depends on it

```dart
if (homeTimeline.isEmpty ||
    awayTimeline.isEmpty ||
    homeTimeline.first.points.length < 2 ||
    awayTimeline.first.points.length < 2) {
  return const CyberNoDataState(...);
}
```

Four conditions, and the last two matter as much as the first two: a chart needs
**at least two points** to draw a line, so an innings with a single published
sample is treated as no data rather than rendered as a dot.

This guard is what makes `_buildRunRatePanel(match, details!)` safe further down.
`timelines` came from `details?.inningsProgress ?? const []`, so a null `details`
produces empty timelines and returns above. **Keep the guard and the bang
together** — if you relax the guard in a port, the force-unwrap becomes a crash.

Note the no-data state takes no `accent` or `spark` here, unlike the football
panels; it uses `CyberNoDataState`'s defaults (`Cyber.cyan`, `Icons.auto_awesome`).

### 4.2 State

Two independent pieces, deliberately not shared:

- **`_range`** (`'20 OV'` / `'POWERPLAY'` / `'DEATH'`) — filters the race only.
- **`_selectedInnings`** (`1` / `2`) — selects the run-rate innings only.

Changing one never touches the other, and neither is cleared when the other
changes. The engine handles scrub invalidation itself: `CyberChartPanel`'s
`didUpdateWidget` clears the scrub index when `activeRange` changes, so both
charts reset their playhead on a tab change without this widget doing anything.

### 4.3 The run-rate resolution chain

```dart
final available = details.inningsRateProgress
    .where((timeline) => timeline.points.length >= 2).toList()
  ..sort((a, b) => a.innings.compareTo(b.innings));
```

Filter to drawable timelines, **then sort by innings number** — the feed does not
guarantee order, and the tab labels are generated from this list, so an unsorted
list would put `2ND INNINGS` first.

Then three `firstWhere` calls with fallbacks, each guarding a different gap:

| Lookup | `orElse` | Covers |
| --- | --- | --- |
| `available` → the selected innings | `available.first` | innings 2 selected but only innings 1 has deliveries (a live first innings) |
| `details.innings` → the matching innings record | `details.innings.first` | a rate timeline with no matching innings entry |
| — | — | `available.isEmpty` returns the no-data panel before any of this |

The `orElse: available.first` is why `_selectedInnings = 2` cannot break a
first-innings-only match: it silently shows innings 1, and the tab strip only
renders labels for innings that exist.

### 4.4 REQUIRED RATE appears only when chasing

```dart
final target = innings.target;
…
if (target != null)
  ChartSeries(label: 'REQUIRED RATE', color: Cyber.magenta, strokeWidth: 1.8, …)
```

A collection-if in the `series` list. Innings 1 has no target, so that chart has
**one** series; innings 2 has two. The widget test pins exactly this — `hasLength(1)`
with label `RUN RATE` on the first innings, `hasLength(2)` with
`REQUIRED RATE` in `Cyber.magenta` after switching.

`strokeWidth: 1.8` against the default `2.4` is the hierarchy: the required rate is
a reference line, the actual rate is the subject. `Cyber.magenta` is the app's hot
secondary — it is not a team colour, and it must not be, because the required rate
belongs to the situation rather than to a side.

### 4.5 Haptics

`enableFeedback` is threaded in from the shell and gates exactly one call — the
innings switch:

```dart
if (widget.enableFeedback) HapticFeedback.selectionClick();
```

The race's own range tabs get **no** haptic; `CyberChartRangeTabs` plays its
`uiTap` sound internally and that is all they get. Whether that asymmetry is
intentional or an oversight, it is the current behaviour — a port that wants both
should add the gated haptic to the race's `onRangeChanged` too.

The innings switch also early-returns when the selection is unchanged
(`if (selected == _selectedInnings) return;`), so re-tapping the active innings
neither buzzes nor rebuilds.

---

## 5. INNINGS RACE — the panel configuration

| Property | Value | Why |
| --- | --- | --- |
| `chartKey` | `cricket-innings-race-graph` | scrub target in tests |
| `title` / `caption` | `INNINGS RACE` / `'<n> OVERS'` | count reflects the **filtered** list |
| `height` | `250` | matches the other stats charts |
| `yAxisLabels` | `true` | runs need a readable axis — unlike momentum |
| `gridDivisions` | `4` | 5 gridlines; more resolution than the default 2 |
| `glow` | `progress < 1` | the focal reveal |
| `revealProgress` | `progress` | left-to-right sweep over 760 ms |
| `xAxisLabels` | `_overLabels(home)` | 5 evenly spaced over numbers |
| `contextLabelAt` | `'<over>.0 OV'` | trailing legend context |
| `markers` | `_wicketMarkers(...)` | diamonds, home top / away bottom |

Both series read out through `_scoreAt`, which **ignores the plotted value** and
re-reads the point at that index:

```dart
readout: (value, index) => _scoreAt(home, index),
```

That is the trick that makes the legend read like a scoreboard — the y value is
`runs`, but the legend must show `runs/wickets`, which is not a number the chart
can plot. This is exactly what `ChartSeries.readout`'s `index` parameter exists
for.

**The away series reads from its own list.** `_scoreAt(away, index)` is indexed by
the *shared* scrub index, which is correct only because both innings are sampled
per over from over 1 — index `i` is over `i+1` in both. If a port's two innings can
have different sample origins, map the index through the over number instead.

---

## 6. INNINGS RUN RATE — the panel configuration

| Property | Value | Why |
| --- | --- | --- |
| `chartKey` | `cricket-innings-run-rate-graph` | test target |
| `title` / `caption` | `INNINGS RUN RATE` / `'<TEAM> // <n> BALLS'` | the `//` is HUD greeble |
| `glow` | **`false`** | the race already owns the screen's focal moment |
| `revealProgress` | `progress` | 620 ms sweep, replayed per innings |
| `ranges` / `activeRange` | innings labels | the repurposed switch |
| `markers` | `_runRateBoundaryMarkers(points)` | gold value-dots labelled `4` / `6` |
| `xAxisLabels` | `_deliveryOverLabels(points)` | 5 over numbers derived from balls |
| `contextLabelAt` | `'<over> OV'` | `over` is already a `String` like `12.3` |

Both series format with `value.toStringAsFixed(2)` — run rates are decimals and a
rounded integer would hide the whole point.

The outer `TweenAnimationBuilder` carries `key: ValueKey('run-rate-${timeline.innings}')`,
so switching innings **replays** the reveal on the new trace instead of snapping to
it. Same pattern as the shot map re-keying on its filter.

---

## 7. The six helpers

Verbatim:

```dart
/// POWERPLAY is the first six overs, DEATH the last five — the two windows that
/// usually decide a T20.
List<CricketScoreProgressPoint> _pointsForRange(
  List<CricketScoreProgressPoint> points,
  String range,
) {
  if (range == '20 OV' || points.isEmpty) return points;
  final filtered =
      (range == 'POWERPLAY'
              ? points.where((point) => point.over <= 6)
              : points.where((point) => point.over >= 15))
          .toList();
  return filtered.length >= 2 ? filtered : points;
}

/// Runs/wickets at one over, so the legend reads like a scoreboard.
String _scoreAt(List<CricketScoreProgressPoint> points, int index) {
  if (points.isEmpty) return '—';
  final point = points[index.clamp(0, points.length - 1)];
  return '${point.runs}/${point.wickets}';
}

List<String> _overLabels(List<CricketScoreProgressPoint> points) {
  if (points.length < 2) return const <String>[];
  final first = points.first.over;
  final last = points.last.over;
  return [
    for (var i = 0; i <= 4; i++) '${first + ((last - first) * i / 4).round()}',
  ];
}

/// Wickets ride the plot as diamonds, the way the old worm drew them.
List<ChartMarker> _wicketMarkers(
  List<CricketScoreProgressPoint> home,
  List<CricketScoreProgressPoint> away, {
  required Color homeColor,
  required Color awayColor,
}) {
  if (home.length < 2) return const <ChartMarker>[];
  final markers = <ChartMarker>[];
  for (var i = 0; i < home.length; i++) {
    if (home[i].wicket) {
      markers.add(
        ChartMarker(
          fraction: i / (home.length - 1),
          color: homeColor,
          shape: ChartMarkerShape.diamond,
        ),
      );
    }
  }
  for (var i = 0; i < away.length && away.length > 1; i++) {
    if (away[i].wicket) {
      markers.add(
        ChartMarker(
          fraction: i / (away.length - 1),
          color: awayColor,
          shape: ChartMarkerShape.diamond,
          alignTop: false,
        ),
      );
    }
  }
  return markers;
}

List<String> _deliveryOverLabels(List<CricketInningsRatePoint> points) {
  if (points.length < 2) return const <String>[];
  final lastOver = (points.last.legalBall / 6).ceil();
  return [for (var i = 0; i <= 4; i++) '${(lastOver * i / 4).round()}'];
}

/// Every boundary keeps its legal-delivery x position and its run-rate y value.
/// The chart painter moves only close number badges, leaving these anchors exact.
List<ChartMarker> _runRateBoundaryMarkers(
  List<CricketInningsRatePoint> points,
) {
  if (points.length < 2) return const <ChartMarker>[];
  final lastBall = points.last.legalBall;
  return [
    for (final point in points)
      if (point.boundary case final boundary?)
        ChartMarker(
          fraction: (point.legalBall - 1) / (lastBall - 1),
          value: point.runRate,
          color: Cyber.gold,
          shape: ChartMarkerShape.dot,
          label: '$boundary',
        ),
  ];
}
```

### 7.1 `_pointsForRange`

`POWERPLAY` is `over <= 6`, `DEATH` is `over >= 15` — the two windows that usually
decide a T20. Same `filtered.length >= 2 ? filtered : points` fallback as the
football momentum chart's half filter: a window that cannot be drawn falls back to
the full innings rather than rendering an empty plot.

The windows are **T20 constants**. A port covering ODIs or first-class cricket must
change them, and the labels with them.

### 7.2 `_scoreAt`

Clamps, and returns `'—'` on an empty list. The `'<runs>/<wickets>'` shape is what
makes the legend read as a scoreboard.

### 7.3 `_overLabels` and `_deliveryOverLabels`

Both return exactly **5 labels**, because the engine's `_paintXAxis` spreads
whatever it is given evenly across the plot width
(`x = left + width * i / (len - 1)`). So the labels are correct only if the data
is evenly spaced in the same dimension — which holds here: the race samples once
per over, and the rate chart once per legal delivery (and over = ball ÷ 6).

They differ in how they get there:

- `_overLabels` interpolates between the **first and last over present**, so a
  POWERPLAY filter labels `1 … 6`, not `1 … 20`.
- `_deliveryOverLabels` derives the last over from the ball count
  (`(points.last.legalBall / 6).ceil()`) and always starts at `0`, because a
  delivery-indexed chart starts before the first over completes.

Both return `const []` below two points, which the engine reads as "no x axis" and
which also removes the 16px bottom inset.

### 7.4 `_wicketMarkers`

Wickets ride the plot as diamonds, the way the old static worm drew them —
`alignTop: true` for home, `false` for away, so the two sets separate onto opposite
edges and stay attributable. Colour is the team accent. The widget test pins both
facts by partitioning `painter.markers` on `alignTop` and asserting the colours.

Two edge-case details:

- `if (home.length < 2) return const []` guards the `home.length - 1` division.
- The away loop guards the same division **inside its condition**:
  `for (var i = 0; i < away.length && away.length > 1; i++)`. It reads oddly —
  the second clause is loop-invariant — but it is what stops a single-point away
  innings dividing by zero. A cleaner port hoists it to an early return; do not
  simply delete it.
- **No marker is `focal`.** Unlike the momentum chart's decisive goal, no single
  wicket is elevated — so this chart has no focal marker at all, which is
  consistent with it being the glowing panel already.

### 7.5 `_runRateBoundaryMarkers`

The one place a `value` is set on a marker, which switches the engine into its
on-trace badge rendering: a small anchor dot stays exactly on the data point while
only the numbered badge is displaced by `chartMarkerLabelOffset` to avoid
collisions. The doc comment says precisely this — "every boundary keeps its
legal-delivery x position and its run-rate y value; the chart painter moves only
close number badges, leaving these anchors exact."

- `Cyber.gold` for every boundary — gold is the app's reward/achievement colour, and
  a boundary is the batting reward. Not a team colour: these are events, not
  identity.
- `label: '$boundary'` renders `4` or `6` in the badge. The test asserts
  `everyElement(anyOf('4', '6'))`.
- The `if (point.boundary case final boundary?)` pattern filters non-boundary balls
  **and** binds the non-null value in one step.
- `fraction: (point.legalBall - 1) / (lastBall - 1)` — 1-indexed balls mapped onto
  `0..1`. Guarded against an empty list by `points.length < 2`, though a feed that
  emitted two points with the same `legalBall` would still divide by zero; in
  practice `legalBall` is strictly increasing.

---

## 8. Design rules to keep

1. **One focal panel.** The race glows during its reveal; the run rate never glows.
2. **One filled series.** Home only, on the race. Never fill the away worm.
3. **Colour splits by meaning:** team accents for identity (worms, wickets),
   `Cyber.gold` for boundaries (events), `Cyber.magenta` for the required rate
   (situation). A required rate in a team colour would read as that team's line.
4. **The legend reads like a scoreboard**, via `readout`'s `index` — `161/5`, not
   `161`.
5. **Scrubbing reads both innings at once.** That comparison is the reason the
   chart exists; do not split it into two panels.
6. **Match timelines by `teamId`**, never by list order.
7. **Two points minimum, everywhere.** Every helper and the top-level guard treat
   a single sample as no data.
8. **Degrade independently.** No race data and no rate data are separate states;
   either chart can render without the other.
9. **Re-key the run-rate reveal per innings** so a switch replays rather than snaps.

---

## 9. Every value in one place

| Element | Value |
| --- | --- |
| Race reveal | `760 ms`, `easeOutCubic`, `glow: progress < 1` |
| Run-rate reveal | `620 ms`, `easeOutCubic`, `glow: false`, re-keyed per innings |
| Both charts | `height: 250`, `yAxisLabels: true`, `gridDivisions: 4` |
| Race ranges | `20 OV` (all) / `POWERPLAY` (`over <= 6`) / `DEATH` (`over >= 15`) |
| Run-rate ranges | `1ST INNINGS` / `2ND INNINGS` — an innings switch |
| Home worm | team accent, `fill: true` |
| Away worm | team accent, no fill |
| Run rate | team accent, default stroke `2.4` |
| Required rate | `Cyber.magenta`, `strokeWidth: 1.8` |
| Wicket markers | `ChartMarkerShape.diamond`, team accent, home `alignTop: true` / away `false` |
| Boundary markers | `ChartMarkerShape.dot`, `Cyber.gold`, `value` set, label `4`/`6` |
| Race readout | `'<runs>/<wickets>'`, `'—'` when empty |
| Rate readouts | `toStringAsFixed(2)` |
| Race context | `'<over>.0 OV'` |
| Rate context | `'<over> OV'` (already a string like `12.3`) |
| X labels | exactly 5, or `const []` below two points |
| List padding | `EdgeInsets.fromLTRB(16, 14, 16, 28)`, `18` between panels |
| Fallback rule | any filter yielding `< 2` points falls back to the full list |

---

## 10. Tests

Covered by
[`test/basketball_cricket_match_stats_view_test.dart`](../../test/basketball_cricket_match_stats_view_test.dart):

| Assertion | Pins |
| --- | --- |
| `ValueKey('cricket-innings-race-graph')` + `INNINGS RACE` | the race renders |
| `RCB 161/5` and `GT 155/8` both found | **both** innings read out at once, in scoreboard form |
| `RACE VERDICT` absent | no verdict block was reintroduced |
| markers partitioned on `alignTop`, colours `everyElement(homeColor/awayColor)` | wickets split top/bottom and keep team identity |
| tap at `centreLeft + (1, 0)` → `161/5` gone, `OV` present | scrubbing rewinds both innings to the same over |
| `ValueKey('cricket-innings-run-rate-graph')` + both innings labels | the run-rate panel and its switch |
| `series` `hasLength(1)`, label `RUN RATE`, colour `awayColor` | innings 1 has **no** required rate |
| `markers` `hasLength(18)`, labels `anyOf('4','6')`, values non-null | boundary badges are on-trace value markers |
| `onRangeChanged!('2ND INNINGS')` → `hasLength(2)`, last is `REQUIRED RATE` in `Cyber.magenta`, `markers` `hasLength(25)` | the switch swaps innings, colour and adds the chase line |
| `RACE DATA UNAVAILABLE` | the top-level guard |
| `RUN-RATE DATA UNAVAILABLE` while the race still renders | the two feeds degrade independently |

Keys: `cricket-stats-race` (the list), `cricket-innings-race-graph`,
`cricket-innings-run-rate-graph`.

Not covered today, worth adding in a port: the POWERPLAY/DEATH filters and their
two-point fallback, `_overLabels` re-basing on a filtered window, and the
`enableFeedback` gate.

---

## 11. Port checklist

1. **Engine first.** Port `cyber_chart.dart` from
   [`match-momentum-chart.md`](match-momentum-chart.md) §7–§14 — `CyberChartPanel`,
   `CyberChartPainter`, `ChartSeries`, `ChartMarker`, `CyberChartRangeTabs`,
   `CyberChartLegend` and the pure helpers. Nothing here works without it.
2. **Tokens.** The flattened `Cyber` in that doc's App. C, plus `gold`
   (`0xFFFDC700`) and `magenta` (`0xFFC27AFF`) — see App. B below.
3. **Models.** Add App. A, or map your own onto: a per-over series of
   `{over, runs, wickets, wicket}` per innings, and a per-delivery series of
   `{over, legalBall, runs, boundary?}` with a `runRate` getter and
   `requiredRunRate({target, totalLegalBalls})`.
4. **`CyberNoDataState`** for the two empty branches — in
   [`match-momentum-chart.md`](match-momentum-chart.md) App. B (it needs
   `PressableScale` too).
5. **Accents.** `paletteForTeam(...).secondaryTextColor` → your own per-team colour,
   or the stand-in in App. B. Must clear 4.5:1 on `Cyber.chartSurface`.
6. **Paste §4 and §7.** Rename `_CricketRace` to a public `CricketRacePanel` if it
   gets its own file, and make `match` whatever type carries your cricket details.
7. **Check the format constants.** `over <= 6` / `over >= 15` and
   `totalLegalBalls = 120` are T20 assumptions. ODIs and longer formats need both
   changed.
8. **Verify.** `flutter analyze` clean, then in the app: both worms draw with the
   race glowing once and the run rate staying calm; scrubbing shows two scoreboards
   at one over; wickets sit top/bottom in team colours; switching to the second
   innings adds a magenta required-rate line and replays the reveal; a
   first-innings-only match still renders without crashing.

---

## Implementation References

- [`lib/screens/predictions/widgets/cricket_match_stats_view.dart`](../../lib/screens/predictions/widgets/cricket_match_stats_view.dart)
  — `_CricketRace` (252), `_CricketRaceState` (261), `_buildRunRatePanel` (353),
  `_pointsForRange` (441), `_scoreAt` (455), `_overLabels` (461),
  `_wicketMarkers` (471), `_deliveryOverLabels` (505),
  `_runRateBoundaryMarkers` (513). Call site: the `'RACE'` branch of the shell's
  section switch (54).
- [`lib/models/cricket_match_data.dart`](../../lib/models/cricket_match_data.dart)
  — `CricketInningsProgress` (58), `CricketScoreProgressPoint` (71),
  `CricketInningsRateProgress` (87), `CricketInningsRatePoint` (99),
  `runRate` (116), `requiredRunRate` (118).
- [`lib/widgets/cyber/cyber_chart.dart`](../../lib/widgets/cyber/cyber_chart.dart)
  — the engine; `ChartSeries.readout` (46), `ChartMarker.value` (79),
  `CyberChartRangeTabs` (927), `chartMarkerLabelOffset` (1106).
- [`lib/config/theme.dart`](../../lib/config/theme.dart) — `Cyber` (558).
- [`lib/data/team_palettes.dart`](../../lib/data/team_palettes.dart) —
  `paletteForTeam` (4526).
- Tests: [`test/basketball_cricket_match_stats_view_test.dart`](../../test/basketball_cricket_match_stats_view_test.dart).
- Siblings: [`cricket-match-stats-view.md`](cricket-match-stats-view.md) (the whole
  view; this race is its §6–§7), [`match-momentum-chart.md`](match-momentum-chart.md)
  (the charting engine, in full), [`cricket-scorecard-view.md`](cricket-scorecard-view.md)
  (the SCORECARD tab next door).
- Product context: [`docs/product/systems/predictions.md`](../product/systems/predictions.md).

---

## Appendix A — models, verbatim

From `lib/models/cricket_match_data.dart`:

```dart
/// Verified cumulative scoring samples for one innings. These live separately
/// from the compact commentary feed so reports can render a full match race
/// without inflating the player-facing ball feed.
class CricketInningsProgress {
  const CricketInningsProgress({
    required this.innings,
    required this.teamId,
    required this.points,
  });

  final int innings;
  final String teamId;
  final List<CricketScoreProgressPoint> points;
}

/// The score at the end of one completed over.
class CricketScoreProgressPoint {
  const CricketScoreProgressPoint({
    required this.over,
    required this.runs,
    required this.wickets,
    required this.wicket,
  });

  final int over;
  final int runs;
  final int wickets;
  final bool wicket;
}

/// Complete legal-delivery progression for one batting innings. The compact
/// match feed can stay editorial while charts still have every plotted ball.
class CricketInningsRateProgress {
  const CricketInningsRateProgress({
    required this.innings,
    required this.teamId,
    required this.points,
  });

  final int innings;
  final String teamId;
  final List<CricketInningsRatePoint> points;
}

class CricketInningsRatePoint {
  const CricketInningsRatePoint({
    required this.innings,
    required this.teamId,
    required this.over,
    required this.legalBall,
    required this.runs,
    this.boundary,
  });

  final int innings;
  final String teamId;
  final String over;
  final int legalBall;
  final int runs;
  final int? boundary;

  double get runRate => legalBall == 0 ? 0 : runs * 6 / legalBall;

  double requiredRunRate({required int target, int totalLegalBalls = 120}) {
    final remainingRuns = (target - runs).clamp(0, target);
    if (remainingRuns == 0) return 0;
    final remainingBalls = totalLegalBalls - legalBall;
    if (remainingBalls <= 0) return double.infinity;
    return remainingRuns * 6 / remainingBalls;
  }
}
```

Two getters carry real logic:

**`runRate`** is `runs * 6 / legalBall`, guarded against ball 0. Runs per six
balls, i.e. per over — the standard cricket unit.

**`requiredRunRate`** has three branches worth preserving:

```dart
final remainingRuns = (target - runs).clamp(0, target);
if (remainingRuns == 0) return 0;          // target reached — the line drops to 0
final remainingBalls = totalLegalBalls - legalBall;
if (remainingBalls <= 0) return double.infinity;   // out of balls
return remainingRuns * 6 / remainingBalls;
```

The `clamp` stops a completed chase producing a negative rate, and the explicit
`0` makes the line settle flat at the moment of victory rather than dipping below
the axis.

**`double.infinity` is a live hazard for the chart.** The engine scales every
series together (`values.reduce(math.max)`), so a single infinite value would blow
up the shared y-axis and flatten the real trace to nothing. It does not happen
today because `inningsRateProgress` stops at the last delivery bowled, so
`legalBall` never exceeds `totalLegalBalls` while a target is still live. If your
feed can emit a ball past the limit — or a different format's `totalLegalBalls` is
wrong — filter or clamp before plotting. This is the single most likely way a port
of this chart breaks.

`totalLegalBalls = 120` is the **T20 default**. ODIs need `300`.

---

## Appendix B — tokens and stand-ins

### B.1 Extra tokens

The race needs the flattened `Cyber` from
[`match-momentum-chart.md`](match-momentum-chart.md) App. C, plus two colours that
doc does not carry:

```dart
  static const gold = Color(0xFFFDC700);    // boundary badges — reward colour
  static const magenta = Color(0xFFC27AFF); // the required-rate line
```

Everything else — `bg`, `chartSurface`, `border`, `muted`, `cyan`, `glow`,
`display`, `body`, `label` — is already in that appendix.

### B.2 Team accents

Identical to the momentum chart's: `paletteForTeam(...).secondaryTextColor`
resolved from a club palette table, replaceable with the contrast-preserving
`chartAccent` stand-in in
[`match-momentum-chart.md`](match-momentum-chart.md) App. C.3. It must clear 4.5:1
against `Cyber.chartSurface`, since the worms, the wicket diamonds and the legend
readouts are all drawn in it.

With no brand colours: `Cyber.cyan` for home and `Cyber.amber` for away. Avoid
reaching for `gold` or `magenta` as a team colour here — both are already spoken
for by boundaries and the required rate.

### B.3 Feed data

Nothing in §4–§7 knows where the samples came from; a port only has to produce two
lists per innings. The minimum:

| Field | Note |
| --- | --- |
| `CricketInningsProgress.teamId` | must match `match.home.id` / `match.away.id` |
| `.points[].over` | 1-indexed, one sample per completed over |
| `.points[].runs`, `.wickets` | cumulative; `runs` is plotted, both are read out |
| `.points[].wicket` | whether a wicket fell *in* that over — drives the diamonds |
| `CricketInningsRateProgress.innings` | `1` / `2`; the list is sorted on it |
| `.points[].legalBall` | 1-indexed, strictly increasing — the x position |
| `.points[].over` | a display string like `12.3` |
| `.points[].runs` | cumulative, for `runRate` |
| `.points[].boundary` | `4`, `6`, or `null` |
| `innings.target` | non-null only when chasing — gates REQUIRED RATE |
