# Match Momentum Chart — implementation and porting reference

> **Status:** BUILT
> **Last verified:** 2026-09-12
> **Scope:** the `MATCH MOMENTUM` chart on a football match's **STATS → MOMENTUM**
> tab — `_MomentumSection` in
> [`lib/screens/predictions/widgets/football_match_stats_view.dart`](../../lib/screens/predictions/widgets/football_match_stats_view.dart)
> — together with the whole charting engine it sits on,
> [`lib/widgets/cyber/cyber_chart.dart`](../../lib/widgets/cyber/cyber_chart.dart).

**Written to be portable.** Every widget, painter, model and helper is reproduced
*exactly as implemented*, in the section that explains it. The charting engine is
the app's **one** chart system — porting it gets you every other chart too, not
just this one. The appendices add a flattened drop-in copy of the design tokens
and stand-ins for the two things that cannot travel (team palettes, UI sound).

---

## 0. Port map

| # | Layer | Source | Here |
| --- | --- | --- | --- |
| 1 | The call site | `_MomentumSection` + state | §3 — verbatim |
| 2 | Range filter | `_samplesForRange` | §4 — verbatim |
| 3 | Goal markers | `_goalMarkers` | §5 — verbatim |
| 4 | Goal chips | `_GoalMarkerChip` | §6 — verbatim |
| 5 | Chart inputs | `ChartMarkerShape`, `ChartSeries`, `ChartMarker` | §7 — verbatim |
| 6 | The painter | `CyberChartPainter` | §8 — verbatim |
| 7 | The panel | `CyberChartPanel` + state | §9 — verbatim |
| 8 | Scrub surface | `_ChartSurface` | §10 — verbatim |
| 9 | Full screen | `CyberChartFullScreen` + state | §11 — verbatim |
| 10 | Range tabs | `CyberChartRangeTabs`, `_RangeButton` | §12 — verbatim |
| 11 | Legend | `CyberChartLegend` | §13 — verbatim |
| 12 | Pure helpers | 6 top-level functions + `drawDashedLine` | §14 — verbatim |
| 13 | Models | `FootballMomentumPoint`, `FootballMomentumGoal`, `FootballMomentum` | App. A — verbatim |
| 14 | Shared widgets | `SectionLabel`, `CyberSectionHeading`, `CyberMiniMetric`, `CyberNoDataState`, `CyberPlainBackground` | App. B — verbatim |
| 15 | Tokens + stand-ins | `Cyber`, `paletteForTeam`, `playSound` | App. C |

**Toolchain**

- **Dart 3** — switch expressions (`chartMarkerLabelOffset`) and switch statements
  over enums without a `default` (`_paintMarker`).
- **Flutter 3.27+** — `Color.withValues(alpha:)` throughout. On older Flutter swap
  every call for `withOpacity(...)`; nothing else changes.
- **Fonts** — Orbitron (labels/numbers) and Onest (legend readouts).
- **No third-party packages.** `dart:math`, `flutter/material.dart` and
  `flutter/services.dart` (`HapticFeedback`) only. `playSound` is the app's own
  audio helper — App. C has a one-line stub.

**Line budget:** the engine is ~1,144 lines and the call site ~208. The painter
alone is ~416 of those.

---

## 1. What it is

A **two-sided pressure trace**: home pressure plotted upward from a centre
baseline, away pressure mirrored downward, both filled, with goals pinned onto the
plot as markers. It answers "who was on top, and when did that change?" in one
glance, and it is **scrubbable** — drag across the plot and the legend reads out
both sides' pressure at that minute, with the minute itself as trailing context.

```
_MomentumSection(match)
  ├─ momentum == null || series.isEmpty → CyberNoDataState(show_chart / bolt)
  └─ ListView
       ├─ TweenAnimationBuilder<double>(0→1, 900ms, easeOutCubic)
       │    └─ CyberChartPanel
       │         ├─ header       MATCH MOMENTUM  ⤢  "98/SAMPLES"
       │         ├─ CyberChartRangeTabs    FULL | 1ST HALF | 2ND HALF
       │         ├─ _ChartSurface (250px)  → CustomPaint(CyberChartPainter)
       │         │      signed baseline · 2 filled series · goal markers
       │         │      · reveal sweep clipped at revealProgress
       │         │      · white dashed playhead at the scrub index
       │         └─ CyberChartLegend   swatch + readout per side + "67'"
       ├─ [shots] FootballShotMapPanel
       ├─ PEAK PRESSURE      → two CyberMiniMetric cells
       └─ [goals] GOAL IMPACT MARKERS → Wrap of _GoalMarkerChip
```

**The animation and the glow are one gesture.** `TweenAnimationBuilder` drives
`revealProgress` from 0 to 1 over 900 ms; the painter clips the plot to that
fraction so the trace draws itself left to right, and `glow: progress < 1` puts a
cyan bloom on the panel **only while the sweep is running**. When it lands, the
glow goes out and the panel is calm again. That is the glow rule applied in time
rather than in space: the reveal is the focal moment, and it expires.

---

## 2. The inputs

| Read | Used for |
| --- | --- |
| `match.footballMomentum` (`FootballMomentum?`) | the series, goals, halftime minute, peaks; `null`/empty → no-data state |
| `match.home` / `match.away`, `match.sport`, `match.leagueId` | the two identity colours via `paletteForTeam` |
| `match.footballDetails?.shots` | whether the shot map panel appears |
| `match.home.shortName` / `away.shortName` | series labels and peak captions |

From `FootballMomentum` the section reads `series`, `goals`, `halftimeMinute`,
`homePeak` and `awayPeak`. Note `homePeak!` / `awayPeak!` are **force-unwrapped** —
safe only because the `series.isEmpty` guard above already returned. Keep the
guard and the bang together, or make the getters non-nullable in your port.

**The sign convention is the whole design.** `FootballMomentumPoint` carries
`home`, `away` and a combined `value`; the chart plots `point.home.abs()` for one
series and `-point.away.abs()` for the other. Feeding *signed* source data
straight in would let a series cross the baseline and the mirror would break — so
each side is forced onto its own half with `.abs()`, and the away series is then
negated. The legend undoes it with `value.abs()` in `readout`, so the player never
sees a negative number.

---

## 3. The call site — `_MomentumSection`

Verbatim:

```dart
/// MOMENTUM: the two-sided pressure trace on the shared chart surface. Drag it
/// to read either side's pressure at any minute; goals ride the plot as markers
/// and the decisive one carries the focal halo.
class _MomentumSection extends StatefulWidget {
  const _MomentumSection({required this.match});

  final SportMatch match;

  @override
  State<_MomentumSection> createState() => _MomentumSectionState();
}

class _MomentumSectionState extends State<_MomentumSection> {
  static const _ranges = ['FULL', '1ST HALF', '2ND HALF'];
  String _range = _ranges.first;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final momentum = match.footballMomentum;
    if (momentum == null || momentum.series.isEmpty) {
      return const CyberNoDataState(
        key: ValueKey('football-momentum-empty'),
        icon: Icons.show_chart,
        title: 'Pressure feed offline',
        message: 'Momentum will map the match once enough live actions arrive.',
        accent: Cyber.cyan,
        spark: Icons.bolt,
      );
    }

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
    final samples = _samplesForRange(momentum, _range);
    final shots = match.footballDetails?.shots ?? const <FootballShot>[];
    final homePeak = momentum.homePeak!;
    final awayPeak = momentum.awayPeak!;

    return ListView(
      key: const ValueKey('football-stats-momentum'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, progress, _) => CyberChartPanel(
            chartKey: const ValueKey('football-momentum-graph'),
            title: 'MATCH MOMENTUM',
            caption: '${momentum.series.length}/SAMPLES',
            height: 250,
            signed: true,
            bloom: true,
            glow: progress < 1,
            revealProgress: progress,
            ranges: _ranges,
            activeRange: _range,
            onRangeChanged: (range) => setState(() => _range = range),
            markers: _goalMarkers(momentum, samples, homeColor, awayColor),
            contextLabelAt: (index) =>
                "${samples[index.clamp(0, samples.length - 1)].minute}'",
            series: [
              ChartSeries(
                label: '${match.home.shortName.toUpperCase()} PRESSURE',
                color: homeColor,
                fill: true,
                readout: (value, _) => value.abs().toStringAsFixed(0),
                values: [for (final point in samples) point.home.abs()],
              ),
              ChartSeries(
                label: '${match.away.shortName.toUpperCase()} PRESSURE',
                color: awayColor,
                fill: true,
                readout: (value, _) => value.abs().toStringAsFixed(0),
                values: [for (final point in samples) -point.away.abs()],
              ),
            ],
          ),
        ),
        if (shots.isNotEmpty) ...[
          const SizedBox(height: 18),
          FootballShotMapPanel(
            match: match,
            shots: shots,
            homeColor: homeColor,
            awayColor: awayColor,
          ),
        ],
        const SizedBox(height: 18),
        const CyberSectionHeading(label: 'PEAK PRESSURE'),
        const SizedBox(height: 10),
        Row(
          children: [
            CyberMiniMetric(
              label: "${match.home.shortName} PEAK // ${homePeak.minute}'",
              value: homePeak.value.abs().toStringAsFixed(1),
              accent: homeColor,
            ),
            const SizedBox(width: 10),
            CyberMiniMetric(
              label: "${match.away.shortName} PEAK // ${awayPeak.minute}'",
              value: awayPeak.value.abs().toStringAsFixed(1),
              accent: awayColor,
            ),
          ],
        ),
        if (momentum.goals.isNotEmpty) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'GOAL IMPACT MARKERS'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final goal in momentum.goals)
                _GoalMarkerChip(
                  goal: goal,
                  color: goal.isHomeTeam ? homeColor : awayColor,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
```

The five flags passed to `CyberChartPanel` are the whole configuration of this
chart, and each one is a deliberate choice:

| Flag | Value | Why |
| --- | --- | --- |
| `signed` | `true` | plot around a centre baseline, ± values — the mirror |
| `bloom` | `true` | blurred underglow per line; this is the *one* hero chart on the tab |
| `glow` | `progress < 1` | focal only while the sweep runs |
| `revealProgress` | `progress` | the 0→1 left-to-right clip |
| `height` | `250` | taller than the `200` default — a two-sided plot needs both halves legible |

`fill: true` on **both** series is the one place this chart knowingly departs from
"one focal series per chart" (see `ChartSeries.fill`'s doc comment). It is correct
here: the two washes are what make the mirror read as two territories rather than
two lines, and they can't compete because they occupy different halves.

Also note **state lives in the section, not the panel.** `_range` is the section's
`setState`; the panel is told the active range and reports changes back via
`onRangeChanged`. That is what lets `_samplesForRange` re-slice the data and the
chart rebuild with a different point count.

---

## 4. The range filter — `_samplesForRange`

Verbatim:

```dart
/// FULL keeps every sample; the half filters split on the recorded halftime
/// minute and fall back to the whole trace when a half has too few samples.
List<FootballMomentumPoint> _samplesForRange(
  FootballMomentum momentum,
  String range,
) {
  if (range == 'FULL') return momentum.series;
  final halftime = momentum.halftimeMinute;
  final filtered =
      (range == '1ST HALF'
              ? momentum.series.where((point) => point.minute <= halftime)
              : momentum.series.where((point) => point.minute > halftime))
          .toList();
  return filtered.length >= 2 ? filtered : momentum.series;
}
```

The `filtered.length >= 2 ? filtered : momentum.series` fallback is the sharp edge
worth keeping: a chart needs **at least two points** to draw a line, so a half
with one sample (or none — a match that hasn't reached halftime, a feed that
recorded the wrong halftime minute) silently falls back to the full trace rather
than rendering an empty plot. The split is `<= halftime` / `> halftime`, so the
halftime sample itself belongs to the first half.

---

## 5. The goal markers — `_goalMarkers`

Verbatim:

```dart
/// Goals pinned onto the visible window. The last goal is the decisive one, so
/// it gets the focal halo — one focal element per chart.
List<ChartMarker> _goalMarkers(
  FootballMomentum momentum,
  List<FootballMomentumPoint> samples,
  Color homeColor,
  Color awayColor,
) {
  if (momentum.goals.isEmpty || samples.length < 2) {
    return const <ChartMarker>[];
  }
  final first = samples.first.minute;
  final last = samples.last.minute;
  final span = math.max(1, last - first);
  final markers = <ChartMarker>[];
  for (final goal in momentum.goals) {
    if (goal.minute < first || goal.minute > last) continue;
    markers.add(
      ChartMarker(
        fraction: (goal.minute - first) / span,
        color: goal.isHomeTeam ? homeColor : awayColor,
        alignTop: goal.isHomeTeam,
        focal: goal == momentum.goals.last,
      ),
    );
  }
  return markers;
}
```

Three things happen here:

- **Goals are positioned as a fraction of the *visible window*, not the match.**
  `fraction = (goal.minute - first) / span` where `first`/`last` come from the
  current `samples`. Switch to 2ND HALF and a 70' goal moves from ~78% of the plot
  to ~40% — because the window changed, not the goal. Goals outside the window are
  dropped by the `continue`.
- **`alignTop: goal.isHomeTeam`** puts a home goal on the top edge and an away
  goal on the bottom, matching which half of the mirror that team owns.
- **`focal: goal == momentum.goals.last`** — exactly one marker per chart gets the
  extra halo and the full-height stub. The last goal is treated as the decisive
  one. This is an identity comparison on a `const`-constructible class with no
  `==` override, so it is reference equality: it works because both sides are the
  same list element. If your port copies or rebuilds the goal list between these
  two reads, compare by minute instead.

---

## 6. The goal chips — `_GoalMarkerChip`

Verbatim:

```dart
class _GoalMarkerChip extends StatelessWidget {
  const _GoalMarkerChip({required this.goal, required this.color});

  final FootballMomentumGoal goal;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.sports_soccer, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            '${goal.clock} ${goal.player}',
            style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}
```

A flat tinted rectangle — fill at `alpha: 0.09`, border at `0.42`, an 11px
football and `clock + player` in muted label type. Listed in a `Wrap` under
`GOAL IMPACT MARKERS` so it reflows on narrow screens. **It never glows**; the
chips are a secondary index to the markers already on the plot.

---

## 7. The chart inputs — `ChartSeries`, `ChartMarker`, `ChartMarkerShape`

Verbatim:

```dart
/// How a series marker is drawn on the plot.
enum ChartMarkerShape { dot, diamond, ring }

/// One plotted line. [values] are in the series' own units; the painter scales
/// every series together so they share one y-axis.
class ChartSeries {
  const ChartSeries({
    required this.label,
    required this.color,
    required this.values,
    this.strokeWidth = 2.4,
    this.fill = false,
    this.readout,
  });

  final String label;
  final Color color;
  final List<double> values;
  final double strokeWidth;

  /// Draws the signature gradient wash beneath the line. Reserve it for the
  /// leading/primary series — one focal series per chart.
  final bool fill;

  /// Formats the legend value at a scrubbed index. Receives the index too, so a
  /// series can read a richer state off a parallel list (a cricket score reads
  /// `84/2`, not just the runs). Defaults to a rounded number.
  final String Function(double value, int index)? readout;

  String readoutAt(int? selectedIndex) {
    if (values.isEmpty) return '—';
    final index = (selectedIndex ?? values.length - 1).clamp(
      0,
      values.length - 1,
    );
    final value = values[index];
    return readout?.call(value, index) ?? value.round().toString();
  }
}

/// A moment pinned to the plot — a goal, a wicket, a lead change.
class ChartMarker {
  const ChartMarker({
    required this.fraction,
    required this.color,
    this.shape = ChartMarkerShape.dot,
    this.label,
    this.value,
    this.alignTop = true,
    this.focal = false,
  });

  /// Horizontal position as 0..1 across the plot.
  final double fraction;
  final Color color;
  final ChartMarkerShape shape;
  final String? label;

  /// Optional y-axis value. When present the marker sits on the plotted trace;
  /// otherwise it keeps the existing top/bottom edge placement.
  final double? value;

  /// Whether the marker rides the top or the bottom edge of the plot.
  final bool alignTop;

  /// The single most decisive marker on the chart. Drawn with an extra halo.
  final bool focal;
}
```

- **`ChartSeries.values` are in the series' own units**; the painter scales every
  series together onto one shared y-axis. Two series in different units will
  mislead — convert before you hand them over.
- **`readout`** receives the index as well as the value, so a series can read
  richer state off a parallel list (a cricket score reads `84/2`, not just the
  runs). The momentum chart uses it purely to drop the sign:
  `(value, _) => value.abs().toStringAsFixed(0)`.
- **`readoutAt`** is the only behaviour on the class: it clamps, defaults a null
  selection to the **last** point, and falls back to a rounded number.
- **`ChartMarker.value`** is what distinguishes the two marker styles: with a value
  the marker sits *on* the trace and gets the numbered-badge treatment; without
  one (the momentum case) it keeps the legacy edge-pinned placement driven by
  `alignTop`. Both paths go through `chartMarkerPosition`.

---

## 8. The painter — `CyberChartPainter`

The engine room. Verbatim:

```dart
/// Paints [series] as polylines over a HUD grid, with an optional signed
/// baseline, event [markers], a reveal sweep and a scrub playhead.
class CyberChartPainter extends CustomPainter {
  const CyberChartPainter({
    required this.series,
    required this.selectedIndex,
    this.markers = const <ChartMarker>[],
    this.stepped = false,
    this.signed = false,
    this.bloom = false,
    this.percentScale = false,
    this.revealProgress = 1,
    this.xAxisLabels = const <String>[],
    this.yAxisLabels = false,
    this.yAxisFormatter,
    this.gridDivisions = 2,
  });

  final List<ChartSeries> series;
  final int? selectedIndex;
  final List<ChartMarker> markers;

  /// Pins the axis to 0..100 for probability charts. Everything else scales to
  /// its own data.
  final bool percentScale;

  /// Step interpolation (market odds hold their price until the next trade).
  /// Sports series move continuously, so they stay linear.
  final bool stepped;

  /// Plots around a centre baseline with values read as ±, for two-sided
  /// pressure/momentum charts.
  final bool signed;

  /// Adds a blurred underglow beneath each line. Costs a mask filter per
  /// segment — reserve it for the one hero chart on a screen.
  final bool bloom;

  /// 0..1 left-to-right reveal sweep.
  final double revealProgress;

  final List<String> xAxisLabels;
  final bool yAxisLabels;

  /// Formats each y-axis gridline value. Left null the axis prints the rounded
  /// number, which is right for scores and percentages but not for a series
  /// plotted in a different unit to the one it reads in — a race position chart
  /// is plotted inverted so P1 sits at the top, and a lap-time chart is plotted
  /// in milliseconds but reads as `1:22.6`.
  final String Function(double value)? yAxisFormatter;
  final int gridDivisions;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || series.isEmpty) return;

    final topInset = markers.isEmpty ? 0.0 : 14.0;
    final bottomInset = xAxisLabels.isEmpty ? 0.0 : 16.0;
    final leftInset = yAxisLabels ? 26.0 : 0.0;
    final rect = Rect.fromLTRB(
      leftInset,
      topInset,
      size.width,
      size.height - bottomInset,
    );
    if (rect.width <= 0 || rect.height <= 0) return;

    final values = [for (final item in series) ...item.values];
    if (values.isEmpty) return;

    final double minValue;
    final double maxValue;
    if (signed) {
      final extent = math.max(
        1.0,
        values.map((value) => value.abs()).reduce(math.max),
      );
      minValue = -extent;
      maxValue = extent;
    } else if (percentScale) {
      minValue = math.max(0, values.reduce(math.min) - 8);
      maxValue = math.min(100, values.reduce(math.max) + 8);
    } else {
      final low = values.reduce(math.min);
      final high = values.reduce(math.max);
      final pad = math.max(1.0, (high - low) * 0.08);
      // Don't pad an all-positive series below zero — runs and counts have no
      // negative half to show.
      minValue = low >= 0 ? math.max(0, low - pad) : low - pad;
      maxValue = high + pad;
    }
    final spread = math.max(1.0, maxValue - minValue);

    _paintGrid(canvas, rect, minValue, spread);
    _paintXAxis(canvas, rect);

    final revealX = rect.left + rect.width * revealProgress.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(rect.left, 0, revealX, size.height));

    for (var s = 0; s < series.length; s++) {
      _paintSeries(canvas, rect, series[s], minValue, spread);
    }
    for (var i = 0; i < markers.length; i++) {
      _paintMarker(canvas, rect, markers[i], minValue, spread, markerIndex: i);
    }
    canvas.restore();

    _paintPlayhead(canvas, rect, minValue, spread);
  }

  void _paintGrid(Canvas canvas, Rect rect, double minValue, double spread) {
    final grid = Paint()
      ..color = Cyber.border.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    for (var i = 0; i <= gridDivisions; i++) {
      final y = rect.top + rect.height * i / gridDivisions;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
      if (yAxisLabels) {
        final value = minValue + spread * (1 - i / gridDivisions);
        _paintText(
          canvas,
          yAxisFormatter?.call(value) ?? value.round().toString(),
          Cyber.label(7, color: Cyber.muted),
          Offset(rect.left - 5, y - 4),
          alignRight: true,
        );
      }
    }
    if (signed) {
      canvas.drawLine(
        Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy),
        Paint()
          ..color = Cyber.cyan.withValues(alpha: 0.38)
          ..strokeWidth = 1.2,
      );
    }
  }

  void _paintXAxis(Canvas canvas, Rect rect) {
    if (xAxisLabels.isEmpty) return;
    for (var i = 0; i < xAxisLabels.length; i++) {
      final x = xAxisLabels.length == 1
          ? rect.center.dx
          : rect.left + rect.width * i / (xAxisLabels.length - 1);
      _paintText(
        canvas,
        xAxisLabels[i],
        Cyber.label(7, color: Cyber.muted),
        Offset(x, rect.bottom + 5),
        centered: true,
      );
    }
  }

  void _paintSeries(
    Canvas canvas,
    Rect rect,
    ChartSeries item,
    double minValue,
    double spread,
  ) {
    final points = _pointsFor(rect, item, minValue, spread);
    if (points.isEmpty) return;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      if (stepped) path.lineTo(points[i].dx, points[i - 1].dy);
      path.lineTo(points[i].dx, points[i].dy);
    }

    if (item.fill && points.length > 1) {
      final base = signed ? rect.center.dy : rect.bottom;
      // A signed series that sits below the baseline fills downward, so its
      // wash has to run the other way to stay anchored to the baseline.
      final below = signed && item.values.reduce(math.max) <= 0;
      canvas.drawPath(
        Path.from(path)
          ..lineTo(points.last.dx, base)
          ..lineTo(points.first.dx, base)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: below ? Alignment.bottomCenter : Alignment.topCenter,
            end: below ? Alignment.topCenter : Alignment.bottomCenter,
            colors: [
              item.color.withValues(alpha: 0.18),
              item.color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    if (bloom) {
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = item.strokeWidth + 2.5
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = item.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = item.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  List<Offset> _pointsFor(
    Rect rect,
    ChartSeries item,
    double minValue,
    double spread,
  ) => [
    for (var i = 0; i < item.values.length; i++)
      Offset(
        item.values.length == 1
            ? rect.right
            : rect.left + rect.width * i / (item.values.length - 1),
        rect.bottom - ((item.values[i] - minValue) / spread) * rect.height,
      ),
  ];

  void _paintMarker(
    Canvas canvas,
    Rect rect,
    ChartMarker marker,
    double minValue,
    double spread, {
    required int markerIndex,
  }) {
    final center = chartMarkerPosition(
      marker: marker,
      plot: rect,
      minValue: minValue,
      spread: spread,
    );
    if (marker.value != null) {
      _paintValueMarker(canvas, rect, center, marker, markerIndex);
      return;
    }

    final x = center.dx;
    final y = center.dy;
    final stubEnd = marker.focal
        ? (marker.alignTop ? rect.bottom : rect.top)
        : (marker.alignTop ? y + 16 : y - 16);
    canvas.drawLine(
      Offset(x, y),
      Offset(x, stubEnd),
      Paint()
        ..color = marker.color.withValues(alpha: marker.focal ? 0.34 : 0.22)
        ..strokeWidth = 1,
    );
    final fill = Paint()..color = marker.color;

    switch (marker.shape) {
      case ChartMarkerShape.dot:
        canvas.drawCircle(center, 4.5, fill);
      case ChartMarkerShape.diamond:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx, center.dy - 4.5)
            ..lineTo(center.dx + 4.5, center.dy)
            ..lineTo(center.dx, center.dy + 4.5)
            ..lineTo(center.dx - 4.5, center.dy)
            ..close(),
          fill,
        );
      case ChartMarkerShape.ring:
        canvas.drawCircle(
          center,
          4.5,
          Paint()
            ..color = marker.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8,
        );
    }
    canvas.drawCircle(
      center,
      marker.focal ? 10 : 7.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = marker.color.withValues(alpha: marker.focal ? 0.75 : 0.48),
    );
  }

  void _paintValueMarker(
    Canvas canvas,
    Rect rect,
    Offset point,
    ChartMarker marker,
    int markerIndex,
  ) {
    canvas.drawCircle(point, 2.6, Paint()..color = marker.color);
    final label = marker.label;
    if (label == null || label.isEmpty) return;

    final labelDy = chartMarkerLabelOffset(
      markers,
      markerIndex,
      plotWidth: rect.width,
    );
    final badge = Offset(
      point.dx.clamp(rect.left + 7, rect.right - 7).toDouble(),
      (point.dy + labelDy).clamp(rect.top + 7, rect.bottom - 7).toDouble(),
    );
    canvas.drawLine(
      point,
      badge,
      Paint()
        ..color = marker.color.withValues(alpha: 0.44)
        ..strokeWidth = 0.8,
    );
    canvas.drawCircle(badge, 7, Paint()..color = marker.color);
    canvas.drawCircle(
      badge,
      7,
      Paint()
        ..color = Cyber.bg.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    _paintText(
      canvas,
      label,
      Cyber.label(7, color: Cyber.bg),
      Offset(badge.dx, badge.dy - 4),
      centered: true,
    );
  }

  void _paintPlayhead(
    Canvas canvas,
    Rect rect,
    double minValue,
    double spread,
  ) {
    final pointCount = chartPointCount(series);
    final index = selectedChartIndex(selectedIndex, pointCount);
    if (index == null) return;

    final x = pointCount <= 1
        ? rect.right
        : rect.left + rect.width * index / (pointCount - 1);
    drawDashedLine(
      canvas,
      Offset(x, rect.top),
      Offset(x, rect.bottom),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.square,
    );

    final marker = series.first;
    if (marker.values.isEmpty) return;
    final value = marker.values[index.clamp(0, marker.values.length - 1)];
    final center = Offset(
      x,
      rect.bottom - ((value - minValue) / spread) * rect.height,
    );
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      center,
      7,
      Paint()..color = marker.color.withValues(alpha: 0.18),
    );
    canvas.drawCircle(center, 4, Paint()..color = marker.color);
  }

  void _paintText(
    Canvas canvas,
    String text,
    TextStyle style,
    Offset offset, {
    bool centered = false,
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = centered
        ? offset.dx - painter.width / 2
        : alignRight
        ? offset.dx - painter.width
        : offset.dx;
    painter.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(covariant CyberChartPainter old) =>
      old.series != series ||
      old.selectedIndex != selectedIndex ||
      old.markers != markers ||
      old.revealProgress != revealProgress;
}
```

### 8.1 How the scale is chosen

Three mutually exclusive modes in `paint`, and the momentum chart takes the first:

| Mode | Range |
| --- | --- |
| `signed` | `±max(1.0, largest absolute value)` — **symmetric**, so the baseline is always dead centre |
| `percentScale` | `[min−8, max+8]` clamped to `0..100`, for probability charts |
| default | `[min−pad, max+pad]`, `pad = max(1.0, (high−low) × 0.08)`; an all-positive series is **not** padded below zero, because runs and counts have no negative half |

The symmetry in `signed` mode is load-bearing: take the extent from the larger
side and apply it to both, and a 40-pressure home peak against a 10-pressure away
peak still renders the baseline in the middle with the away trace small. Scale each
half independently and the mirror lies.

### 8.2 Insets, and why they exist

```
topInset    = markers.isEmpty ? 0 : 14     room for edge-pinned markers
bottomInset = xAxisLabels.isEmpty ? 0 : 16 room for x labels
leftInset   = yAxisLabels ? 26 : 0         room for y labels
```

The plot `Rect` is inset only where something needs the space, so a bare chart
uses its full box. The momentum chart has markers and no axis labels → `14` off
the top only.

### 8.3 Paint order

`_paintGrid` → `_paintXAxis` → **clip to `revealProgress`** → series, then markers
→ `restore` → `_paintPlayhead`.

The grid and the playhead sit **outside** the reveal clip. That is deliberate: the
grid is chrome and should be there from frame one, and the playhead must stay
visible even at `revealProgress` 0. Everything that represents *data* is inside
the clip.

### 8.4 The signed fill, and the bug it avoids

```dart
final below = signed && item.values.reduce(math.max) <= 0;
```

A filled series closes its path back to the baseline (`rect.center.dy` when
signed). The gradient runs from `0.18` alpha at the line to `0` away from it — so
for a series *below* the baseline the gradient must run bottom-to-top instead, or
the wash detaches from the line and pools at the wrong edge. `below` tests whether
the series is entirely non-positive, which is exactly the away series' contract
(`-point.away.abs()`).

### 8.5 Markers

Edge-pinned markers (`value == null`) get a vertical stub, a shape
(`dot`/`diamond`/`ring` at radius 4.5) and a surrounding ring. `focal` changes
three things: the stub runs the **full height** of the plot instead of 16px, the
ring grows `7.5 → 10`, and its alpha lifts `0.48 → 0.75`. That is the entire focal
treatment — no glow, no fill change.

Value markers take the other branch: a 2.6px anchor dot that stays on the exact
data point, a leader line, and a 7px filled badge carrying the label, offset by
`chartMarkerLabelOffset` so clustered labels alternate above/below instead of
overlapping.

### 8.6 The playhead

A white dashed vertical line (8 on, 6 off) at the scrub index, plus a three-ring
puck — 12px white stroke, 7px series-tinted wash, 4px solid — riding
**`series.first`**. With multiple series the puck tracks only the first one; for
the momentum chart that is the home side, which is why the home series is listed
first. The legend is what reads out every series.

### 8.7 `shouldRepaint`

Compares `series`, `selectedIndex`, `markers` and `revealProgress` — and **not**
the flags. Toggling `signed`, `bloom`, `stepped`, `percentScale`, the axis labels or
`gridDivisions` on a live painter will not trigger a repaint on its own. Fine as
used (those are fixed per call site), and worth knowing if you animate one.

Note also that `series` and `markers` are compared by **reference**. The momentum
call site rebuilds both lists inside `build`, so every frame of the reveal is a new
list and the repaint always fires.

---

## 9. The panel — `CyberChartPanel`

Verbatim:

```dart
/// The full chart treatment: header + optional range tabs + scrubbable plot +
/// legend readout, with an expand button that reopens the same plot full-screen.
class CyberChartPanel extends StatefulWidget {
  const CyberChartPanel({
    required this.title,
    required this.series,
    this.caption,
    this.markers = const <ChartMarker>[],
    this.ranges = const <String>[],
    this.activeRange,
    this.onRangeChanged,
    this.contextLabelAt,
    this.height = 200,
    this.stepped = false,
    this.signed = false,
    this.bloom = false,
    this.percentScale = false,
    this.revealProgress = 1,
    this.glow = false,
    this.xAxisLabels = const <String>[],
    this.yAxisLabels = false,
    this.yAxisFormatter,
    this.gridDivisions = 2,
    this.markerSound = true,
    this.chartKey,
    super.key,
  });

  final String title;
  final List<ChartSeries> series;

  /// Right-aligned muted caption — the market panel's "128 BETS" slot.
  final String? caption;
  final List<ChartMarker> markers;
  final List<String> ranges;
  final String? activeRange;
  final ValueChanged<String>? onRangeChanged;

  /// Trailing context for the legend at a scrubbed index — `67'`, `10.0 OV`,
  /// `Q4 2:31`.
  final String Function(int index)? contextLabelAt;

  final double height;
  final bool stepped;
  final bool signed;
  final bool bloom;
  final bool percentScale;
  final double revealProgress;

  /// Set only while the reveal sweep is running — the one focal moment.
  final bool glow;

  final List<String> xAxisLabels;
  final bool yAxisLabels;

  /// Formats each y-axis gridline value; see [CyberChartPainter.yAxisFormatter].
  final String Function(double value)? yAxisFormatter;
  final int gridDivisions;

  /// Clicks when the scrub crosses a marker, so dragging over a goal or wicket
  /// has a beat.
  final bool markerSound;

  final Key? chartKey;

  @override
  State<CyberChartPanel> createState() => _CyberChartPanelState();
}

class _CyberChartPanelState extends State<CyberChartPanel> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(CyberChartPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRange != widget.activeRange) _selectedIndex = null;
  }

  @override
  Widget build(BuildContext context) {
    final pointCount = chartPointCount(widget.series);
    final selectedIndex = selectedChartIndex(_selectedIndex, pointCount);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Cyber.chartSurface,
        border: Border.all(color: Cyber.border),
        boxShadow: widget.glow
            ? Cyber.glow(Cyber.cyan, alpha: 0.18, blur: 18, spread: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(10, color: Cyber.cyan),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Expand chart',
                onPressed: () => _openExpanded(context),
                icon: const Icon(
                  Icons.open_in_full,
                  color: Cyber.cyan,
                  size: 16,
                ),
              ),
              if (widget.caption != null)
                Text(
                  widget.caption!,
                  style: Cyber.label(9, color: Cyber.muted),
                ),
            ],
          ),
          if (widget.ranges.isNotEmpty) ...[
            const SizedBox(height: 10),
            CyberChartRangeTabs(
              ranges: widget.ranges,
              active: widget.activeRange ?? widget.ranges.first,
              onChanged: (range) {
                setState(() => _selectedIndex = null);
                widget.onRangeChanged?.call(range);
              },
            ),
          ],
          const SizedBox(height: 12),
          _ChartSurface(
            chartKey: widget.chartKey,
            height: widget.height,
            pointCount: pointCount,
            selectedIndex: selectedIndex,
            onScrub: _scrubTo,
            painter: _painter(selectedIndex),
          ),
          const SizedBox(height: 10),
          CyberChartLegend(
            series: widget.series,
            selectedIndex: selectedIndex,
            contextLabel: selectedIndex == null
                ? null
                : widget.contextLabelAt?.call(selectedIndex),
          ),
        ],
      ),
    );
  }

  CyberChartPainter _painter(int? selectedIndex) => CyberChartPainter(
    series: widget.series,
    selectedIndex: selectedIndex,
    markers: widget.markers,
    stepped: widget.stepped,
    signed: widget.signed,
    bloom: widget.bloom,
    percentScale: widget.percentScale,
    revealProgress: widget.revealProgress,
    xAxisLabels: widget.xAxisLabels,
    yAxisLabels: widget.yAxisLabels,
    yAxisFormatter: widget.yAxisFormatter,
    gridDivisions: widget.gridDivisions,
  );

  void _scrubTo(int index, int pointCount) {
    if (index == _selectedIndex) return;
    HapticFeedback.selectionClick();
    if (widget.markerSound &&
        _crossesMarker(_selectedIndex, index, pointCount)) {
      playSound(SoundEffect.uiTap);
    }
    setState(() => _selectedIndex = index);
  }

  bool _crossesMarker(int? from, int to, int pointCount) {
    if (widget.markers.isEmpty || pointCount <= 1) return false;
    final previous = from ?? pointCount - 1;
    final low = math.min(previous, to);
    final high = math.max(previous, to);
    for (final marker in widget.markers) {
      final index = (marker.fraction.clamp(0.0, 1.0) * (pointCount - 1))
          .round();
      if (index > low && index <= high) return true;
    }
    return false;
  }

  void _openExpanded(BuildContext context) {
    playSound(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CyberChartFullScreen(
          title: widget.title,
          caption: widget.caption,
          series: widget.series,
          markers: widget.markers,
          ranges: widget.ranges,
          activeRange: widget.activeRange,
          onRangeChanged: widget.onRangeChanged,
          contextLabelAt: widget.contextLabelAt,
          stepped: widget.stepped,
          signed: widget.signed,
          bloom: widget.bloom,
          percentScale: widget.percentScale,
          xAxisLabels: widget.xAxisLabels,
          yAxisLabels: widget.yAxisLabels,
          yAxisFormatter: widget.yAxisFormatter,
          gridDivisions: widget.gridDivisions,
        ),
      ),
    );
  }
}
```

- **The surface is flat `Cyber.chartSurface` with a `Cyber.border` outline.** The
  only `boxShadow` is the gated reveal glow:
  `Cyber.glow(Cyber.cyan, alpha: 0.18, blur: 18, spread: 1)` when `glow` is true,
  `null` otherwise.
- **`didUpdateWidget` clears the scrub on a range change.** Without it, an index
  valid in FULL can point somewhere meaningless in 2ND HALF. `onRangeChanged` also
  clears it locally before calling out — both paths are covered because the range
  can change from the full-screen route too.
- **`_crossesMarker` is the juice.** Scrubbing plays `uiTap` only when the drag
  *crosses* a marker, comparing the marker's rounded index against the
  `(low, high]` interval the drag just swept. So dragging over a goal has a beat,
  and dragging through open play is silent. `HapticFeedback.selectionClick()`
  fires on every index change regardless.
- **`_openExpanded` forwards everything except `revealProgress`, `glow` and
  `height`** — the full-screen route draws fully revealed, unglowed, and expands to
  fill. Its `onRangeChanged` is the *same* callback, so changing range full-screen
  updates the section behind it and the inline chart is already correct on pop.

---

## 10. The scrub surface — `_ChartSurface`

Verbatim:

```dart
/// The scrub surface itself — shared by the inline panel and the full-screen
/// route so the drag maths only lives in one place.
class _ChartSurface extends StatelessWidget {
  const _ChartSurface({
    required this.height,
    required this.pointCount,
    required this.selectedIndex,
    required this.onScrub,
    required this.painter,
    this.chartKey,
    this.expand = false,
  });

  final double? height;
  final int pointCount;
  final int? selectedIndex;
  final void Function(int index, int pointCount) onScrub;
  final CustomPainter painter;
  final Key? chartKey;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        void selectAt(Offset position) => onScrub(
          indexForChartDx(
            dx: position.dx,
            width: constraints.maxWidth,
            pointCount: pointCount,
          ),
          pointCount,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => selectAt(details.localPosition),
          onHorizontalDragUpdate: (details) => selectAt(details.localPosition),
          child: SizedBox(
            key: chartKey,
            height: expand ? null : height,
            child: CustomPaint(
              painter: painter,
              child: expand ? const SizedBox.expand() : null,
            ),
          ),
        );
      },
    );
  }
}
```

Shared by the inline panel and the full-screen route so the drag maths lives in
one place. `LayoutBuilder` supplies the width that `indexForChartDx` needs;
`onTapDown` and `onHorizontalDragUpdate` both route through `selectAt`, so a tap
is just a zero-length drag. `HitTestBehavior.opaque` is what makes the empty parts
of the plot draggable. The `expand` flag swaps a fixed `height` for
`SizedBox.expand()` as the `CustomPaint` child — a `CustomPaint` with no child and
no size would collapse.

`chartKey` is attached to the inner `SizedBox`, which is what
`ValueKey('football-momentum-graph')` finds in the widget test.

---

## 11. The full-screen route — `CyberChartFullScreen`

Verbatim:

```dart
/// Full-screen presentation of a [CyberChartPanel]'s plot.
class CyberChartFullScreen extends StatefulWidget {
  const CyberChartFullScreen({
    required this.title,
    required this.series,
    this.caption,
    this.markers = const <ChartMarker>[],
    this.ranges = const <String>[],
    this.activeRange,
    this.onRangeChanged,
    this.contextLabelAt,
    this.stepped = false,
    this.signed = false,
    this.bloom = false,
    this.percentScale = false,
    this.xAxisLabels = const <String>[],
    this.yAxisLabels = false,
    this.yAxisFormatter,
    this.gridDivisions = 2,
    super.key,
  });

  final String title;
  final List<ChartSeries> series;
  final String? caption;
  final List<ChartMarker> markers;
  final List<String> ranges;
  final String? activeRange;
  final ValueChanged<String>? onRangeChanged;
  final String Function(int index)? contextLabelAt;
  final bool stepped;
  final bool signed;
  final bool bloom;
  final bool percentScale;
  final List<String> xAxisLabels;
  final bool yAxisLabels;

  /// Formats each y-axis gridline value; see [CyberChartPainter.yAxisFormatter].
  final String Function(double value)? yAxisFormatter;
  final int gridDivisions;

  @override
  State<CyberChartFullScreen> createState() => _CyberChartFullScreenState();
}

class _CyberChartFullScreenState extends State<CyberChartFullScreen> {
  late String? _range = widget.activeRange;
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final pointCount = chartPointCount(widget.series);
    final selectedIndex = selectedChartIndex(_selectedIndex, pointCount);

    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.title.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Cyber.display(16, letterSpacing: 1),
                      ),
                    ),
                    if (widget.caption != null)
                      Text(
                        widget.caption!,
                        style: Cyber.label(9, color: Cyber.muted),
                      ),
                  ],
                ),
              ),
              if (widget.ranges.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CyberChartRangeTabs(
                    ranges: widget.ranges,
                    active: _range ?? widget.ranges.first,
                    onChanged: (range) {
                      setState(() {
                        _range = range;
                        _selectedIndex = null;
                      });
                      widget.onRangeChanged?.call(range);
                    },
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _ChartSurface(
                    height: null,
                    expand: true,
                    pointCount: pointCount,
                    selectedIndex: selectedIndex,
                    onScrub: (index, _) {
                      if (index == _selectedIndex) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedIndex = index);
                    },
                    painter: CyberChartPainter(
                      series: widget.series,
                      selectedIndex: selectedIndex,
                      markers: widget.markers,
                      stepped: widget.stepped,
                      signed: widget.signed,
                      bloom: widget.bloom,
                      percentScale: widget.percentScale,
                      xAxisLabels: widget.xAxisLabels,
                      yAxisLabels: widget.yAxisLabels,
                      yAxisFormatter: widget.yAxisFormatter,
                      gridDivisions: widget.gridDivisions,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: CyberChartLegend(
                  series: widget.series,
                  selectedIndex: selectedIndex,
                  contextLabel: selectedIndex == null
                      ? null
                      : widget.contextLabelAt?.call(selectedIndex),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Same painter, same legend, same tabs — just `Expanded` around the surface and its
own `_range` / `_selectedIndex`. It holds a local `_range` *and* calls
`widget.onRangeChanged`, so it stays correct whether or not the host rebuilds it.
No reveal sweep and no glow. `CyberPlainBackground` (App. B) is the only
`cyber_widgets.dart` dependency in the entire engine — drop it for a plain
`Scaffold` body if you don't want the gradient.

---

## 12. The range tabs — `CyberChartRangeTabs`

Verbatim:

```dart
/// Equal-width range switcher (ALL / WEEK / DAY, FULL / 1ST HALF / 2ND HALF…).
/// The active tab is the single tinted element; per the glow rule it doesn't glow.
class CyberChartRangeTabs extends StatelessWidget {
  const CyberChartRangeTabs({
    required this.ranges,
    required this.active,
    required this.onChanged,
    super.key,
  });

  final List<String> ranges;
  final String active;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final range in ranges) ...[
          Expanded(
            child: _RangeButton(
              label: range,
              active: range == active,
              onTap: () {
                if (range == active) return;
                playSound(SoundEffect.uiTap);
                onChanged(range);
              },
            ),
          ),
          if (range != ranges.last) const SizedBox(width: 7),
        ],
      ],
    );
  }
}

class _RangeButton extends StatelessWidget {
  const _RangeButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active
              ? Cyber.cyan.withValues(alpha: 0.14)
              : Cyber.bg.withValues(alpha: 0.34),
          border: Border.all(
            color: active ? Cyber.cyan : Cyber.border.withValues(alpha: 0.75),
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(9, color: active ? Cyber.cyan : Cyber.muted),
        ),
      ),
    );
  }
}
```

Equal-width `Expanded` buttons with a 7px gap. The active tab is the single tinted
element — cyan fill at `alpha: 0.14` and a solid cyan border against
`Cyber.bg @ 0.34` with a muted border — and **it does not glow**. The 140 ms
`AnimatedContainer` cross-fades the change. Re-tapping the active range is a no-op
that doesn't even play the sound.

---

## 13. The legend — `CyberChartLegend`

Verbatim:

```dart
/// Swatch + per-series readout at the scrubbed index, with optional trailing
/// context (the minute, the over, the game clock).
class CyberChartLegend extends StatelessWidget {
  const CyberChartLegend({
    required this.series,
    required this.selectedIndex,
    this.contextLabel,
    super.key,
  });

  final List<ChartSeries> series;
  final int? selectedIndex;
  final String? contextLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final item in series)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 3, color: item.color),
              const SizedBox(width: 6),
              Text(
                '${item.label} ${item.readoutAt(selectedIndex)}',
                style: Cyber.body(
                  10,
                  color: item.color,
                  weight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        if (contextLabel != null)
          Text(
            contextLabel!,
            style: Cyber.label(
              9,
              color: Cyber.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}
```

A `Wrap`, so it reflows rather than overflowing — with two team names plus a
minute it will wrap on a narrow phone. Each row is a `14 × 3` colour swatch and
`'<label> <readout>'` in the series colour, tabular. The optional trailing
`contextLabel` is the momentum chart's minute (`"67'"`), and it appears **only when
something is scrubbed** — the panel passes `null` when `selectedIndex` is null.

---

## 14. The pure helpers

Verbatim:

```dart
/// Longest series length across [series].
int chartPointCount(List<ChartSeries> series) {
  var count = 0;
  for (final item in series) {
    if (item.values.length > count) count = item.values.length;
  }
  return count;
}

/// Clamps a scrub index into range; a null selection reads the latest point.
int? selectedChartIndex(int? selectedIndex, int pointCount) {
  if (pointCount <= 0) return null;
  if (selectedIndex == null) return pointCount - 1;
  return selectedIndex.clamp(0, pointCount - 1);
}

/// Maps a horizontal drag position onto a series index.
int indexForChartDx({
  required double dx,
  required double width,
  required int pointCount,
}) {
  if (pointCount <= 1 || width <= 0) return 0;
  final percent = (dx / width).clamp(0.0, 1.0);
  return (percent * (pointCount - 1)).round();
}

/// Reads one series at a scrub index, clamped.
double seriesValueAt(ChartSeries series, int? selectedIndex) {
  if (series.values.isEmpty) return 0;
  final index = selectedIndex ?? series.values.length - 1;
  return series.values[index.clamp(0, series.values.length - 1)];
}

/// Resolves a marker without changing the legacy edge-pinned contract.
Offset chartMarkerPosition({
  required ChartMarker marker,
  required Rect plot,
  required double minValue,
  required double spread,
}) {
  final x = plot.left + plot.width * marker.fraction.clamp(0.0, 1.0);
  final value = marker.value;
  if (value == null) {
    return Offset(x, marker.alignTop ? plot.top + 7 : plot.bottom - 7);
  }
  final y =
      plot.bottom - ((value - minValue) / math.max(1, spread)) * plot.height;
  return Offset(x, y.clamp(plot.top, plot.bottom).toDouble());
}

/// Alternates close labels above and below their exact plotted points. The
/// small anchor stays on the data value while only the numbered badge moves.
double chartMarkerLabelOffset(
  List<ChartMarker> markers,
  int markerIndex, {
  required double plotWidth,
}) {
  if (markerIndex <= 0 || markerIndex >= markers.length) return -13;
  final marker = markers[markerIndex];
  var neighbours = 0;
  for (var i = markerIndex - 1; i >= 0; i--) {
    final previous = markers[i];
    if (previous.value == null || previous.label == null) continue;
    final gap = (marker.fraction - previous.fraction).abs() * plotWidth;
    if (gap > 18) break;
    neighbours++;
  }
  return switch (neighbours % 4) {
    0 => -13,
    1 => 13,
    2 => -25,
    _ => 25,
  };
}

void drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  const dash = 8.0;
  const gap = 6.0;
  final distance = (end - start).distance;
  if (distance <= 0) return;
  final direction = (end - start) / distance;
  var drawn = 0.0;
  while (drawn < distance) {
    canvas.drawLine(
      start + direction * drawn,
      start + direction * math.min(drawn + dash, distance),
      paint,
    );
    drawn += dash + gap;
  }
}
```

These are deliberately pure and separately testable — all six are covered by
[`test/cyber_chart_test.dart`](../../test/cyber_chart_test.dart). The two with
non-obvious behaviour:

- **`selectedChartIndex`** encodes "a null selection reads the latest point"
  (`pointCount - 1`). That is why an untouched momentum chart shows the *current*
  pressure in its legend rather than a dash.
- **`chartMarkerLabelOffset`** walks backwards over prior markers, counting how
  many sit within 18 logical pixels, and cycles the badge offset through
  `-13, 13, -25, 25`. Unused by the momentum chart (its markers carry no `value`),
  but required by the engine.

---

## 15. Every layout and timing value in one place

| Element | Value |
| --- | --- |
| Reveal animation | `TweenAnimationBuilder` 0→1, `900 ms`, `Curves.easeOutCubic` |
| Panel glow | `Cyber.glow(Cyber.cyan, alpha: 0.18, blur: 18, spread: 1)`, only while `progress < 1` |
| Panel padding | `EdgeInsets.fromLTRB(12, 12, 12, 10)` |
| Panel surface | `Cyber.chartSurface` fill, `Cyber.border` 1px outline |
| Plot height | `250` (engine default is `200`) |
| Title | `Cyber.label(10, cyan)`, uppercased |
| Caption | `Cyber.label(9, muted)` — `"98/SAMPLES"` |
| Expand icon | `Icons.open_in_full`, `16`, cyan |
| Header → tabs gap | `10`; tabs → plot `12`; plot → legend `10` |
| Range tab | height `30`, gap `7`, `AnimatedContainer` `140 ms` |
| Range tab active | fill cyan @ `0.14`, border cyan, text `Cyber.label(9, cyan)` |
| Range tab idle | fill `Cyber.bg` @ `0.34`, border `Cyber.border` @ `0.75`, text muted |
| Grid | `Cyber.border` @ `0.35`, 1px, `gridDivisions: 2` (3 lines) |
| Signed baseline | `Cyber.cyan` @ `0.38`, `1.2` wide |
| Series stroke | `2.4` default, round cap + join |
| Fill wash | series colour `0.18` → `0`, flipped for a below-baseline series |
| Bloom | colour @ `0.3`, stroke `+2.5`, `MaskFilter.blur(normal, 5)` |
| Marker shape | radius `4.5`; ring stroke `1.8` |
| Marker ring | `7.5` @ `0.48`, focal `10` @ `0.75` |
| Marker stub | 16px, or full plot height when `focal`; alpha `0.22` / `0.34` |
| Value-marker badge | `7` filled + `Cyber.bg` @ `0.42` outline, label `Cyber.label(7, bg)` |
| Playhead | dashed `8` on / `6` off, white @ `0.9`, `2.2` wide |
| Playhead puck | `12` white stroke `4`, `7` series @ `0.18`, `4` solid |
| Top inset | `14` when markers exist, else `0` |
| Axis insets | bottom `16` with x labels, left `26` with y labels |
| Axis label type | `Cyber.label(7, muted)` |
| Legend swatch | `14 × 3`; `Wrap` spacing `12` / run `7` |
| Legend readout | `Cyber.body(10, series colour, w700)` + tabular |
| Legend context | `Cyber.label(9, muted)` + tabular |
| Goal chip | padding `8 × 5`, fill @ `0.09`, border @ `0.42`, icon `11`, `Cyber.label(8.5, muted, ls 0.4)` |
| Goal chip `Wrap` | spacing `6`, run `6` |
| Section list padding | `EdgeInsets.fromLTRB(16, 14, 16, 28)`, `18` between blocks |

---

## 16. Design rules to keep

1. **The reveal is the only glow, and it expires.** `glow: progress < 1` — the
   sweep is the focal moment; once it lands the panel is calm chrome. Never leave a
   chart panel permanently glowing, and never glow two panels on one screen.
2. **One shared y-axis.** The painter scales all series together. Series in
   different units must be converted before they are handed over, or the chart
   lies.
3. **In `signed` mode the baseline stays centred.** Take the extent from the larger
   side and mirror it. Don't scale the halves independently.
4. **Exactly one `focal` marker per chart.** Here, the last goal.
5. **Sign lives in the data, not the label.** Negate the away series; strip it back
   out in `readout`. The player never sees a minus.
6. **Grid and playhead sit outside the reveal clip; data sits inside.**
7. **Numbers are tabular** in the legend, the axis labels and the caption —
   otherwise the readout jitters as you scrub.
8. **The scrub needs feedback.** Haptic on every index change, `uiTap` only when
   crossing a marker. A silent scrub reads as a static image.
9. **Reuse this engine for every chart.** It is the app's one chart system; a
   second charting approach is the thing this file exists to prevent.

---

## 17. Tests

The engine has its own suite —
[`test/cyber_chart_test.dart`](../../test/cyber_chart_test.dart), 13 tests — which
is the best thing to port alongside it:

| Group | Covers |
| --- | --- |
| helpers | `chartPointCount` takes the longest series; null selection reads the latest; out-of-range clamps; drag maps to nearest index; `seriesValueAt` clamps; marker positioning; clustered labels alternate |
| `readoutAt` | formats through `readout` with the index; falls back to a rounded value; empty series reads `—` |
| widgets | scrubbing updates the legend readout; range tabs report the selection; the expand button opens the full-screen chart |

The momentum chart itself is covered by
[`test/football_match_stats_view_test.dart:112-122`](../../test/football_match_stats_view_test.dart#L112-L122):
selecting MOMENTUM finds `ValueKey('football-momentum-graph')` and the
`98/SAMPLES` caption, then scrolls to a goal chip by scorer name.

Not covered today, worth adding in a port: the `signed` symmetric scale, the
below-baseline fill flip, `_samplesForRange`'s two-sample fallback, and that only
the last goal marker is `focal`.

---

## 18. Port checklist

1. **Tokens.** Drop in the flattened `Cyber` from App. C (9 colours, `glow`, three
   text helpers) or map onto your own theme. Declare Orbitron + Onest or retarget
   `displayFont` / `bodyFont`.
2. **Sound.** Add the `playSound` / `SoundEffect` stub from App. C, or delete the
   three call sites and pass `markerSound: false`.
3. **Engine.** Copy §7–§14 into one `cyber_chart.dart`. It is self-contained apart
   from `Cyber`, `playSound` and `CyberPlainBackground` (App. B) — and
   `drawDashedLine` is defined at the bottom of the same file, not imported.
4. **Models.** Add App. A, or map your own onto the three the section reads
   (`series` of `{minute, home, away, value}`, `goals` of
   `{minute, clock, isHomeTeam, player}`, plus `halftimeMinute` and the two peak
   getters).
5. **Shared widgets.** Add from App. B: `CyberMiniMetric` +
   `CyberSectionHeading` + `SectionLabel` (PEAK PRESSURE), `CyberNoDataState` (the
   empty branch) **and `PressableScale`, which it needs**, plus
   `CyberPlainBackground` (full-screen route) — whose single
   `AppTheme.backgroundGradient` reference is the one line in the whole port you
   must edit, to `Cyber.backgroundGradient`.
6. **Accents.** Replace `paletteForTeam(...).secondaryTextColor` with your own
   per-team colour or the App. C stand-in. It must clear 4.5:1 against
   `Cyber.chartSurface`, or the trace and its legend readout go illegible.
7. **Section.** Paste §3–§6. Drop the `FootballShotMapPanel` block unless you are
   also porting the shot map (it is a separate panel in its own file —
   `football_shot_map.dart` — and nothing in the chart depends on it).
8. **Verify.** `flutter analyze` clean, then in the running app: the sweep runs once
   and the glow goes out, the baseline sits centred with a lopsided scoreline,
   dragging moves the playhead and updates both readouts, crossing a goal clicks,
   the range tabs reset the scrub, and the expand button opens full-screen with the
   range still applied.

---

## Implementation References

- [`lib/screens/predictions/widgets/football_match_stats_view.dart`](../../lib/screens/predictions/widgets/football_match_stats_view.dart)
  — `_MomentumSection` (356), `_MomentumSectionState` (365), the `CyberChartPanel`
  call (403–439), `_samplesForRange` (490), `_goalMarkers` (506),
  `_GoalMarkerChip` (533).
- [`lib/widgets/cyber/cyber_chart.dart`](../../lib/widgets/cyber/cyber_chart.dart)
  — `ChartMarkerShape` (20), `ChartSeries` (24), `ChartMarker` (60),
  `CyberChartPainter` (90), `CyberChartPanel` (507), `_CyberChartPanelState` (574),
  `_ChartSurface` (726), `CyberChartFullScreen` (777), `CyberChartRangeTabs` (927),
  `_RangeButton` (962), `CyberChartLegend` (1003), `chartPointCount` (1054),
  `selectedChartIndex` (1062), `indexForChartDx` (1069), `seriesValueAt` (1081),
  `chartMarkerPosition` (1088), `chartMarkerLabelOffset` (1106),
  `drawDashedLine` (1129).
- [`lib/models/football_match_data.dart`](../../lib/models/football_match_data.dart)
  — `FootballMomentumPoint` (69), `FootballMomentumGoal` (83),
  `FootballMomentum` (101).
- [`lib/widgets/cyber/cyber_widgets.dart`](../../lib/widgets/cyber/cyber_widgets.dart)
  — `CyberPlainBackground` (544), `SectionLabel` (651), `CyberSectionHeading` (674),
  `CyberMiniMetric` (697), `CyberNoDataState` (921).
- [`lib/config/theme.dart`](../../lib/config/theme.dart) — `Cyber` (558),
  `Cyber.glow` (597), `AppTheme.chartSurface` (140), `AppTheme.backgroundGradient` (150).
- [`lib/data/team_palettes.dart`](../../lib/data/team_palettes.dart) —
  `paletteForTeam` (4526), `TeamPalette.secondaryTextColor` (44).
- [`lib/utils/sound_effects.dart`](../../lib/utils/sound_effects.dart) —
  `playSound` (807), `SoundEffect` (22).
- Tests: [`test/cyber_chart_test.dart`](../../test/cyber_chart_test.dart),
  [`test/football_match_stats_view_test.dart`](../../test/football_match_stats_view_test.dart).
- Sibling reference: [`match-timeline-panel.md`](match-timeline-panel.md) — the
  event spine on the same match's OVERVIEW tab.
- Product context: [`docs/product/systems/predictions.md`](../product/systems/predictions.md).

---

## Appendix A — momentum models, verbatim

From `lib/models/football_match_data.dart`:

```dart
class FootballMomentumPoint {
  const FootballMomentumPoint({
    required this.minute,
    required this.home,
    required this.away,
    required this.value,
  });

  final int minute;
  final double home;
  final double away;
  final double value;
}

class FootballMomentumGoal {
  const FootballMomentumGoal({
    required this.minute,
    required this.axis,
    required this.clock,
    required this.isHomeTeam,
    required this.team,
    required this.player,
  });

  final int minute;
  final int axis;
  final String clock;
  final bool isHomeTeam;
  final String team;
  final String player;
}

class FootballMomentum {
  const FootballMomentum({
    required this.totalMinutes,
    required this.halftimeMinute,
    required this.homeTeam,
    required this.awayTeam,
    required this.series,
    required this.goals,
  });

  final int totalMinutes;
  final int halftimeMinute;
  final String homeTeam;
  final String awayTeam;
  final List<FootballMomentumPoint> series;
  final List<FootballMomentumGoal> goals;

  FootballMomentumPoint? get homePeak {
    if (series.isEmpty) return null;
    return series.reduce((a, b) => a.value >= b.value ? a : b);
  }

  FootballMomentumPoint? get awayPeak {
    if (series.isEmpty) return null;
    return series.reduce((a, b) => a.value <= b.value ? a : b);
  }
}
```

`FootballMomentumPoint.value` is the *combined* signed pressure and is what
`homePeak` / `awayPeak` reduce over — `homePeak` takes the maximum, `awayPeak` the
minimum, so the away peak is the most negative point. The chart itself plots
`home` and `away` separately and never reads `value`.
`FootballMomentumGoal.axis` and `.team` are unused by this chart; `totalMinutes` is
unused too. A port can drop all three.

---

## Appendix B — shared widgets, verbatim

### B.1 `SectionLabel` and `CyberSectionHeading`

Used for the `PEAK PRESSURE` and `GOAL IMPACT MARKERS` headings.

```dart
class SectionLabel extends StatelessWidget {
  const SectionLabel({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: Cyber.cyan.withValues(alpha: 0.7),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

/// A [SectionLabel] with a hairline rule running out to the right edge. The
/// standard separator between the stacked sections of a data page (market
/// detail, match stats) — quieter than a panel header, so a page can carry many.
class CyberSectionHeading extends StatelessWidget {
  const CyberSectionHeading({required this.label, this.trailing, super.key});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SectionLabel(label: label),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: Cyber.line.withValues(alpha: 0.3)),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

/// Small labelled KPI cell — a muted caption over a tabular value. Sits in a
/// [Row] of two or three; expands to share the width.
class CyberMiniMetric extends StatelessWidget {
  const CyberMiniMetric({
    required this.label,
    required this.value,
    this.accent,
    super.key,
  });

  final String label;
  final String value;

  /// Tints the value only. Left null the value stays white — most cells are
  /// context, not emphasis.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 45,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: Cyber.bg.withValues(alpha: 0.42),
          border: Border.all(color: Cyber.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(9, color: Cyber.muted),
            ),
            const SizedBox(height: 5),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(
                11,
                color: accent ?? Colors.white,
                weight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`CyberMiniMetric` returns an `Expanded` **from its own build** — it must be placed
directly in a `Row`/`Flex`, and it sizes itself. That is why the two peak cells
need no wrapper.

### B.2 `PressableScale`

Required by `CyberNoDataState` below, which builds its optional action button out
of it. Needed even though this chart passes no action — the reference is in
`CyberNoDataState`'s `build`, so it must resolve.

```dart
class PressableScale extends StatefulWidget {
  const PressableScale({
    required this.child,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  bool get _active => widget.enabled && widget.onTap != null;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _active ? widget.onTap : null,
      onTapDown: _active ? (_) => _setPressed(true) : null,
      onTapUp: _active ? (_) => _setPressed(false) : null,
      onTapCancel: _active ? () => _setPressed(false) : null,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
```

### B.3 `CyberNoDataState`

The empty branch. It carries an optional action this chart doesn't use — keep it
(and `PressableScale` above) or trim both.

```dart
class CyberNoDataState extends StatelessWidget {
  const CyberNoDataState({
    required this.icon,
    required this.title,
    required this.message,
    this.accent = Cyber.cyan,
    this.spark = Icons.auto_awesome,
    this.actionLabel,
    this.actionIcon = Icons.arrow_forward,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final IconData spark;
  final String? actionLabel;
  final IconData actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final action = actionLabel == null || onAction == null
        ? null
        : PressableScale(
            onTap: onAction,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(actionIcon, color: accent, size: 16),
                  const SizedBox(width: 7),
                  Text(
                    actionLabel!,
                    style: Cyber.label(9, color: accent, letterSpacing: 1.1),
                  ),
                ],
              ),
            ),
          );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 310),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 118,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(icon, color: accent.withValues(alpha: 0.86), size: 78),
                    Positioned(
                      right: 12,
                      bottom: 6,
                      child: Icon(
                        spark,
                        color: Colors.white.withValues(alpha: 0.82),
                        size: 25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title.toUpperCase(),
                textAlign: TextAlign.center,
                style: Cyber.display(
                  14,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Cyber.body(
                  13,
                  color: Cyber.muted,
                  weight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              if (action != null) ...[const SizedBox(height: 12), action],
            ],
          ),
        ),
      ),
    );
  }
}
```

### B.4 `CyberPlainBackground`

The engine's only `cyber_widgets.dart` dependency, used by the full-screen route.

```dart
class CyberPlainBackground extends StatelessWidget {
  const CyberPlainBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppTheme.backgroundGradient),
          ),
        ),
        child,
      ],
    );
  }
}
```

**One edit required.** This is the only place in the whole port that still
references `AppTheme`. App. C puts the same gradient on the flattened token class,
so change the one line:

```dart
decoration: BoxDecoration(gradient: Cyber.backgroundGradient),
```

It is a top-left → bottom-right `LinearGradient` from `Color(0xFF010916)` to
`Color(0xFF0E2646)`. Drop this widget entirely if you'd rather give the
full-screen route a plain `Cyber.bg` `Scaffold` body — nothing else depends on it.

---

## Appendix C — tokens and stand-ins

### C.1 Flattened `Cyber`

The real `Cyber` ([`lib/config/theme.dart`](../../lib/config/theme.dart):558) is a
facade over `AppTheme` carrying the whole app palette. The chart engine and the
momentum section together touch **nine colours, `glow`, and three text helpers** —
this is a drop-in replacement with every alias resolved to a literal:

```dart
import 'package:flutter/material.dart'; // re-exports FontFeature

/// Only the tokens the momentum chart and the chart engine use. Values are the
/// resolved AppTheme literals from the source app.
class Cyber {
  // Surfaces
  static const bg = Color(0xFF0D111A); // page ground, badge ink, idle tab
  static const chartSurface = Color(0xFF10192D); // the chart panel fill
  static const panel = Color(0xFF1D293D); // used by CyberNoDataState's kin

  // Lines and muted text
  static const border = Color(0xFF314158); // panel outline + grid
  static const line = Color(0xFF45556C);
  static const muted = Color(0xFF90A1B9); // captions, axis labels, chip text

  // Accents
  static const cyan = Color(0xFF5CDFFF); // titles, baseline, active tab, glow
  static const amber = Color(0xFFFF8904); // a usable away-side fallback
  static const danger = Color(0xFFFF4D4D);

  /// The app's single glow source. The chart gates it on the reveal sweep:
  /// `Cyber.glow(Cyber.cyan, alpha: 0.18, blur: 18, spread: 1)`.
  static List<BoxShadow> glow(
    Color color, {
    double alpha = 0.3,
    double blur = 16,
    double spread = -2,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];

  /// Top-left → bottom-right page gradient, for CyberPlainBackground.
  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF010916), Color(0xFF0E2646)],
  );

  static const displayFont = 'Orbitron';
  static const bodyFont = 'Onest';

  static TextStyle display(
    double size, {
    Color color = Colors.white,
    double letterSpacing = 1.5,
    FontWeight weight = FontWeight.w900,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: 1,
    decoration: TextDecoration.none,
  );

  static TextStyle body(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w500,
    double letterSpacing = 0,
    double height = 1.35,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: bodyFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );

  static TextStyle label(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = 0.9,
    double height = 1,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );
}
```

Note `display` takes **no** `fontFeatures` — that is why the few display-styled
numbers in the wider app use `.copyWith(fontFeatures: ...)`. The chart's own
tabular numbers all go through `body` / `label`, which do take it. Keep these
signatures or the call sites stop compiling.

If you retarget the fonts: `chartSurface` must stay darker than the page ground it
sits on, and `border` must be visible against it — the grid is drawn from `border`
at `alpha: 0.35`, so a low-contrast pair makes the grid vanish.

### C.2 Sound — `playSound` stand-in

Three call sites: crossing a marker while scrubbing, tapping a range tab, and
opening the full-screen chart.

```dart
enum SoundEffect { uiTap }

/// No-op stand-in. Wire to your own audio layer, or pass
/// `markerSound: false` and delete the call sites.
void playSound(SoundEffect effect) {}
```

The haptic is separate and worth keeping either way —
`HapticFeedback.selectionClick()` from `package:flutter/services.dart` fires on
every scrub index change and is a no-op on web and desktop.

### C.3 Team accents — `paletteForTeam` stand-in

The real lookup ([`lib/data/team_palettes.dart`](../../lib/data/team_palettes.dart):4526)
resolves a sport- and competition-namespaced table of generated club palettes, then
falls back to deriving one from the team's colour. `secondaryTextColor` is
specifically the *accessible* member — the closest chromatic brand colour clearing
4.5:1 against every standard dark surface. The chart needs one `Color` per side:

```dart
/// Returns a team's accent, lightened until it clears 4.5:1 on the chart
/// surface. Replace the brand lookup with your own.
Color chartAccent(Color brand, {Color on = Cyber.chartSurface}) {
  var candidate = HSLColor.fromColor(brand);
  while (_contrast(candidate.toColor(), on) < 4.5 && candidate.lightness < 0.95) {
    candidate = candidate.withLightness(
      (candidate.lightness + 0.04).clamp(0.0, 1.0),
    );
  }
  return candidate.toColor();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
```

With no brand colours at all, `Cyber.cyan` for home and `Cyber.amber` for away
reads correctly — the two halves of the mirror are already distinguished by
position, so the colours only have to differ, not identify. Whatever you pick,
check it against `Cyber.chartSurface`: the trace, its `0.18` fill wash and the
legend readout are all drawn in this colour, so a dark navy club colour used raw
makes an entire half of the chart disappear.

### C.4 Fonts

```yaml
flutter:
  fonts:
    - family: Orbitron
      fonts:
        - asset: assets/fonts/Orbitron-Black.ttf
          weight: 900
        - asset: assets/fonts/Orbitron-ExtraBold.ttf
          weight: 800
    - family: Onest
      fonts:
        - asset: assets/fonts/Onest-Medium.ttf
          weight: 500
        - asset: assets/fonts/Onest-Bold.ttf
          weight: 700
```

The legend uses Onest at `w700`, so ship that weight or let it synthesise. A
condensed geometric face for labels and a neutral sans for readouts is the shape of
the system.
