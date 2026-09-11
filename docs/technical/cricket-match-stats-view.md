# Cricket Match STATS View — implementation and porting reference

> **Status:** BUILT
> **Last verified:** 2026-09-09
> **Scope:** Everything inside
> [`lib/screens/predictions/widgets/cricket_match_stats_view.dart`](../../lib/screens/predictions/widgets/cricket_match_stats_view.dart)
> — the four-tab cricket match report: OVERVIEW, RACE, SCORECARD, MATCH FEED.

**This page is written to be portable.** Every widget the file declares is
reproduced *exactly as implemented*, in the section that explains it, and the
appendices carry the full source of the components it composes plus a flattened,
drop-in copy of the design tokens — enough to rebuild this view in another
Flutter project. Where a dependency is a whole feature of its own (the scorecard
table, the player dossier, the 4,699-line generated team palette), the page gives
its exact contract and a working stand-in instead of inlining it.

---

## 0. Port map

Copy in this order. "Verbatim" means the code in this page is the whole thing.

| # | Layer | Source file | Lines | Needed for | Here |
| --- | --- | --- | --- | --- | --- |
| 1 | Design tokens | `lib/config/theme.dart` (`Cyber`) | 911 (subset) | everything | §11.2 — flattened, verbatim |
| 2 | The view | `cricket_match_stats_view.dart` | 785 | everything | §2–§10 — verbatim |
| 3 | Tab strip | `lib/widgets/cyber/cyber_filter_chips.dart` | 139 | all tabs | App. A.1 — verbatim |
| 4 | HUD leaves | `lib/widgets/cyber/cyber_widgets.dart` (subset) | 8 classes | all tabs | App. A.2 — verbatim |
| 5 | Comparison rows | `match_stats_shell.dart` (subset) | 5 classes | OVERVIEW | App. A.3 — verbatim |
| 6 | Charting engine | `lib/widgets/cyber/cyber_chart.dart` | 1,144 | RACE | App. B — verbatim, whole file |
| 7 | Models | `cricket_match_data.dart`, `sport_match.dart` | subsets | all tabs | App. C — verbatim |
| 8 | Scorecard table | `lib/widgets/cricket_scorecard_view.dart` | 720 | SCORECARD | App. D — contract + options |
| 9 | Player dossier | `cricket_player_match_sheet.dart` (+3 files) | 472+ | scorecard taps | App. D — contract + options |
| 10 | Team colours | `lib/data/team_palettes.dart` | 4,699 (generated) | every tab | §11.3 — stub |
| 11 | UI sound | `lib/utils/sound_effects.dart` | 816 | chip taps | §11.3 — stub |

**Toolchain the code assumes:**

- **Dart 3** — `switch` expressions (`switch (_selected) { 'RACE' => … }`), an
  object pattern (`if (point.boundary case final boundary?)`) and wildcard
  parameters (`separatorBuilder: (_, _) =>`, which needs Dart 3.7+).
- **Flutter 3.27+** — `Color.withValues(alpha:)` throughout.
- **Fonts** — Orbitron (display) and Onest (body); see §11.1.
- No third-party packages. `flutter/material.dart` and `flutter/services.dart`
  are the only imports outside the project.

---

## 1. What it is and where it lives

One caller, [`match_detail_screen.dart:923`](../../lib/screens/predictions/match_detail_screen.dart#L923):

```dart
if (widget.match.sport == Sport.cricket) {
  return CricketMatchStatsView(match: widget.match);
}
```

Presentational only — no bloc, no service, no fetch. Everything is read off the
`SportMatch` it is handed, which is why the widget tests can drive it straight
from a bundled package fixture.

```
CricketMatchStatsView(match, enableFeedback)
  ├─ CyberFilterChips              OVERVIEW  RACE  SCORECARD  MATCH FEED
  └─ AnimatedSwitcher (240ms, keyed on the active tab)
       ├─ _CricketOverview         MATCH INTEL / FINAL RESULT / TEAM COMPARISON / HONOURS / OFFICIALS
       │    ├─ StatsRowShell + _CricketInfo + CyberStatPill
       │    └─ _CricketStatsPanel  → TeamLegendRow + StatComparisonRow (tap to hold)
       ├─ _CricketRace             INNINGS RACE chart + INNINGS RUN RATE chart
       │    └─ CyberChartPanel × 2 (scrub, range tabs, markers, full-screen)
       ├─ _CricketScorecard        → CricketScorecardView → player dossier sheet
       └─ _CricketFeed             innings chips + ball-by-ball _BallCard list
```

---

## 2. Public API and shell state

```dart
CricketMatchStatsView({required SportMatch match, bool enableFeedback = true})
```

`enableFeedback` is the one thing this view has that its football sibling does
not: it gates `HapticFeedback` so widget tests can run without a haptics channel.
Every cricket test constructs the view with `enableFeedback: false`.

State is a single `String _selected`, defaulting to `'OVERVIEW'`. `_select`
no-ops on a repeat tap, fires the selection haptic when feedback is enabled, and
`setState`s. The body is an `AnimatedSwitcher` (240 ms, default curves) over a
`KeyedSubtree` keyed on the tab name, so **switching tabs destroys the outgoing
section** — the held TEAM COMPARISON row, the RACE range, the selected innings
and the feed innings all reset. That is intentional.

**One inconsistency to carry across or fix deliberately:** `enableFeedback` is
threaded into `_CricketRace` and `_CricketFeed` but **not** into
`_CricketStatsPanel`, which calls `HapticFeedback.selectionClick()`
unconditionally when a comparison row is tapped.

**Full source — the shell:**

```dart
class CricketMatchStatsView extends StatefulWidget {
  const CricketMatchStatsView({
    required this.match,
    this.enableFeedback = true,
    super.key,
  });
  final SportMatch match;
  final bool enableFeedback;

  @override
  State<CricketMatchStatsView> createState() => _CricketMatchStatsViewState();
}

class _CricketMatchStatsViewState extends State<CricketMatchStatsView> {
  static const _tabs = ['OVERVIEW', 'RACE', 'SCORECARD', 'MATCH FEED'];
  String _selected = _tabs.first;

  void _select(String value) {
    if (value == _selected) return;
    if (widget.enableFeedback) HapticFeedback.selectionClick();
    setState(() => _selected = value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CyberFilterChips(
          labels: _tabs,
          selected: _selected,
          accent: Cyber.cyan,
          onSelect: _select,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            child: KeyedSubtree(
              key: ValueKey(_selected),
              child: switch (_selected) {
                'RACE' => _CricketRace(
                  match: widget.match,
                  enableFeedback: widget.enableFeedback,
                ),
                'SCORECARD' => _CricketScorecard(match: widget.match),
                'MATCH FEED' => _CricketFeed(
                  match: widget.match,
                  enableFeedback: widget.enableFeedback,
                ),
                _ => _CricketOverview(match: widget.match),
              },
            ),
          ),
        ),
      ],
    );
  }
}
```

---

## 3. Data contract

| Tab | Reads | When absent |
| --- | --- | --- |
| OVERVIEW | `match.cricketDetails` (league, title, venue/city/country, neutralSite, toss, result, seriesNote, awards, officials), `match.leagueId`, `match.teamStats` | MATCH INTEL still renders (venue falls back to `'Venue awaiting feed'`, and FIXTURE/TOSS are simply dropped); FINAL RESULT, TEAM COMPARISON, HONOURS and OFFICIALS each disappear with their data |
| RACE | `cricketDetails.inningsProgress` (per-team `points`), `cricketDetails.inningsRateProgress`, `cricketDetails.innings` (for `target`) | needs **both** sides with ≥2 points, else `CyberNoDataState`; the run-rate panel has its own empty state |
| SCORECARD | `match.cricketScorecard`, and `cricketDetails.teams ?? match.cricketSquads` | no scorecard → empty state; no squads → rows render but are **not** tappable |
| MATCH FEED | `cricketDetails.innings`, `cricketDetails.commentary` | no details or no commentary → empty state; an innings with no balls → a nested empty state inside the list |

Team colour, in both `_CricketStatsPanel` and `_CricketRace`:

```dart
paletteForTeam(match.home, sport: match.sport, competition: match.leagueId)
    .secondaryTextColor;
```

See §11.3 for the portable stand-in.

---

## 4. OVERVIEW — `_CricketOverview`

A `ListView` keyed `cricket-stats-overview`, padded `fromLTRB(16, 14, 16, 28)`.
It opens at **MATCH INTEL** — no match-pulse hero, because the screen above
already carries the fixture and score — and there is deliberately **no innings
grid** here; innings detail belongs to RACE and SCORECARD.

Blocks in order: MATCH INTEL (always) → FINAL RESULT (`Cyber.success` accent,
details only) → TEAM COMPARISON (`teamStats` non-empty) → HONOURS (`Cyber.gold`,
awards non-empty) → OFFICIALS (awards' plain twin).

Inside MATCH INTEL: the league in `Cyber.display(15)`, a `CyberStatPill` reading
`SITE // NEUTRAL|HOME`, then `_CricketInfo` rows for FIXTURE, VENUE and TOSS
(`'<team> chose to <decision>'`).

**Full source:**

```dart
class _CricketOverview extends StatelessWidget {
  const _CricketOverview({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final details = match.cricketDetails;

    return ListView(
      key: const ValueKey('cricket-stats-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const CyberSectionHeading(label: 'MATCH INTEL'),
        const SizedBox(height: 10),
        StatsRowShell(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                details?.league.toUpperCase() ?? match.leagueId.toUpperCase(),
                style: Cyber.display(15, letterSpacing: 0.8),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CyberStatPill(
                    label: 'SITE',
                    value: details?.neutralSite == true ? 'NEUTRAL' : 'HOME',
                    color: Cyber.cyan,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (details != null)
                _CricketInfo(label: 'FIXTURE', value: details.title),
              _CricketInfo(
                label: 'VENUE',
                value: details == null
                    ? 'Venue awaiting feed'
                    : '${details.venue} // ${details.city}, ${details.country}',
              ),
              if (details != null)
                _CricketInfo(
                  label: 'TOSS',
                  value:
                      '${details.toss.team} chose to ${details.toss.decision}',
                ),
            ],
          ),
        ),
        if (details != null) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'FINAL RESULT'),
          const SizedBox(height: 10),
          StatsRowShell(
            accent: Cyber.success,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  details.result,
                  style: Cyber.display(13, color: Cyber.success),
                ),
                const SizedBox(height: 6),
                Text(
                  details.seriesNote,
                  style: Cyber.body(12, color: Cyber.muted),
                ),
              ],
            ),
          ),
        ],
        if (match.teamStats?.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          _CricketStatsPanel(match: match),
        ],
        if (details?.awards.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'HONOURS'),
          const SizedBox(height: 10),
          StatsRowShell(
            accent: Cyber.gold,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: details!.awards
                  .map(
                    (award) => _CricketInfo(
                      label: award.award,
                      value: '${award.name} // ${award.team}',
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (details?.officials.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'OFFICIALS'),
          const SizedBox(height: 10),
          StatsRowShell(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: details!.officials
                  .map(
                    (official) => _CricketInfo(
                      label: official.role,
                      value: '${official.name} // ${official.country}',
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}
```

---

## 5. TEAM COMPARISON — `_CricketStatsPanel`

The only stateful piece of OVERVIEW: `_selectedLabel` holds one row lit, and
tapping the lit row clears it. Rows are `StatComparisonRow` (App. A.3) — two
tabular figures either side of a centred label over a split meter at the home
share, accented by whichever side leads. `TeamLegendRow` heads the block.

**Full source:**

```dart
/// TEAM COMPARISON as market-style outcome rows — tap one to hold it lit.
class _CricketStatsPanel extends StatefulWidget {
  const _CricketStatsPanel({required this.match});
  final SportMatch match;

  @override
  State<_CricketStatsPanel> createState() => _CricketStatsPanelState();
}

class _CricketStatsPanelState extends State<_CricketStatsPanel> {
  String? _selectedLabel;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSectionHeading(label: 'TEAM COMPARISON'),
        const SizedBox(height: 12),
        TeamLegendRow(match: match),
        const SizedBox(height: 12),
        for (final stat in match.teamStats!) ...[
          StatComparisonRow(
            stat: stat,
            homeColor: homeColor,
            awayColor: awayColor,
            selected: stat.label == _selectedLabel,
            onTap: () {
              HapticFeedback.selectionClick();
              setState(
                () => _selectedLabel = stat.label == _selectedLabel
                    ? null
                    : stat.label,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
```

---

## 6. RACE — `_CricketRace`

Two charts on one tab, both `CyberChartPanel` (App. B): the innings race, then
the run-rate panel.

### 6.1 Guard

Both sides' timelines are pulled out of `inningsProgress` by `teamId`. If either
is missing, or either has fewer than two points, the whole tab is a
`CyberNoDataState` — a one-point worm is not a race.

### 6.2 INNINGS RACE

| Property | Value |
| --- | --- |
| `chartKey` | `cricket-innings-race-graph` |
| `title` / `caption` | `INNINGS RACE` / `'<n> OVERS'` |
| `height`, `yAxisLabels`, `gridDivisions` | 250, `true`, 4 |
| reveal | `TweenAnimationBuilder` 760 ms `easeOutCubic`, driving `revealProgress` **and** `glow: progress < 1` |
| `ranges` | `20 OV` / `POWERPLAY` / `DEATH` → `_pointsForRange` |
| `markers` | `_wicketMarkers` — diamonds, home above the line, away below |
| `xAxisLabels` | `_overLabels` — five evenly spaced over numbers |
| `contextLabelAt` | `'<over>.0 OV'` |
| series | home **filled**, away **stroked**, both reading out `'<runs>/<wickets>'` |

Filling only the home series is what keeps two rising lines separable — the same
trick the basketball scoring run uses.

### 6.3 INNINGS RUN RATE — `_buildRunRatePanel`

Distinct enough to call out:

- **The range tabs are repurposed as an innings switch.** `ranges` is
  `['1ST INNINGS', '2ND INNINGS']` built from whatever timelines have ≥2 points,
  and `onRangeChanged` maps the label back to `_selectedInnings`. No second
  control is introduced for what is the same affordance.
- **`glow: false`, explicitly.** One glowing reveal per tab; the race above owns
  it.
- **`key: ValueKey('run-rate-<innings>')`** on the `TweenAnimationBuilder`, so
  switching innings rebuilds it and replays the 620 ms reveal.
- **REQUIRED RATE** is added in `Cyber.magenta` at 1.8 stroke only when that
  innings has a `target`; it is computed per point via
  `point.requiredRunRate(target: target)`.
- Boundaries ride the plot as gold dots carrying their own run value as a label
  (`_runRateBoundaryMarkers`), anchored at the exact legal delivery.
- Every lookup is total: `firstWhere(..., orElse: () => …first)` for both the
  timeline and the innings summary, so a mismatched innings number degrades to
  the first innings instead of throwing.

**Full source — the whole section, including the run-rate builder:**

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

---

## 7. RACE helpers

| Helper | Contract |
| --- | --- |
| `_pointsForRange` | `20 OV` → everything; `POWERPLAY` → `over <= 6`; `DEATH` → `over >= 15`; a window with fewer than 2 points falls back to the full list |
| `_scoreAt` | `'<runs>/<wickets>'` at an index, clamped; `'—'` for an empty list |
| `_overLabels` | five labels interpolated between the first and last over |
| `_wicketMarkers` | one diamond per wicket ball, home `alignTop` (default `true`), away `alignTop: false` |
| `_deliveryOverLabels` | five labels from 0 to `ceil(lastLegalBall / 6)` |
| `_runRateBoundaryMarkers` | one gold dot per boundary at `(legalBall - 1) / (lastBall - 1)`, carrying `value: runRate` and the boundary runs as its label |

**Sharp edges worth preserving knowingly:**

- `_wicketMarkers` returns empty when **home** has <2 points, even if away is
  fine — the away loop also carries its guard inside the loop condition
  (`i < away.length && away.length > 1`), which is a per-iteration re-check
  rather than an early return. Behaviour is correct; the shape is unusual.
- `_runRateBoundaryMarkers` divides by `lastBall - 1`. The `points.length < 2`
  guard covers the realistic case; a two-point timeline whose last delivery is
  still ball 1 would divide by zero.
- `_overLabels` and `_deliveryOverLabels` both return `const []` below two
  points, which the chart reads as "no x-axis labels".

**Full source:**

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

---

## 8. SCORECARD — `_CricketScorecard`

A thin host: empty state when there is no scorecard or no innings, otherwise a
single `CricketScorecardView` (App. D) inside a keyed `ListView`.

The interesting part is **squad resolution**. The bundled package carries squads
on `cricketDetails.teams`; the live ESPN path produces no `cricketDetails` at all
but does carry `match.cricketSquads`. The view tries both, and passes
`onTapPlayer: null` when neither exists — so rows stay untappable rather than
opening an empty dossier. `_openPlayer` then walks the squads for the athlete id
the row reported and opens that player's sheet, accented by that squad's side.

**Full source:**

```dart
class _CricketScorecard extends StatelessWidget {
  const _CricketScorecard({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final scorecard = match.cricketScorecard;
    if (scorecard == null || scorecard.innings.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.table_chart_outlined,
        title: 'Scorecard unavailable',
        message: 'Batting and bowling figures have not been published.',
      );
    }
    // The bundled package carries squads on cricketDetails; the live ESPN path
    // produces no cricketDetails at all but does carry cricketSquads.
    final squads =
        match.cricketDetails?.teams ??
        match.cricketSquads ??
        const <CricketTeamSquad>[];
    return ListView(
      key: const ValueKey('cricket-stats-scorecard'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        CricketScorecardView(
          scorecard: scorecard,
          accent: Cyber.cyan,
          // Only tappable when there are squads to resolve an id against.
          onTapPlayer: squads.isEmpty
              ? null
              : (playerId) => _openPlayer(context, squads, playerId),
        ),
      ],
    );
  }

  /// Resolves a scorecard row's athlete id to the squad player it belongs to,
  /// then opens that player's dossier paging their own side.
  void _openPlayer(
    BuildContext context,
    List<CricketTeamSquad> squads,
    String playerId,
  ) {
    for (final squad in squads) {
      for (final player in squad.players) {
        if (player.id != playerId) continue;
        showCricketPlayerMatchSheet(
          context: context,
          squad: squad,
          player: player,
          accent: paletteForTeam(
            squad.isHome ? match.home : match.away,
            sport: match.sport,
            competition: match.leagueId,
          ).secondaryTextColor,
        );
        return;
      }
    }
  }
}
```

---

## 9. MATCH FEED — `_CricketFeed` and `_BallCard`

**`_selectedInnings` starts at 2**, not 1 — you almost always want the chase
first. The `firstWhere(..., orElse: () => innings.last)` makes that safe for a
one-innings match.

Innings are sorted by number and offered as a second `CyberFilterChips` strip
(labelled by `abbreviation`), the header is a greeble line
(`'<ABBR> // <n> BALL ENTRIES // INNINGS <n>'`), and the body is a
`CustomScrollView` so the header sliver and the list keep different padding. An
innings with no balls gets a `SliverFillRemaining` empty state rather than an
empty scroll view.

`_BallCard` colours the whole entry by what happened:

| Ball | Accent |
| --- | --- |
| `wicket` | `Cyber.danger` |
| `boundary` | `Cyber.gold` |
| otherwise | `Cyber.cyan` |

…then lays out a 46 px over column, a 2 px rail (`minHeight: 64`), and the text
stack: optional `preText`, the `shortText` in the accent, the commentary `text`,
an uppercased `dismissal` in danger, optional `postText`, and a telemetry footer
reading `'<score> // <runs> RUNS // RR <x.xx>'` plus
`' // NEED <r> OFF <b> @ <rr>'` when the ball carries a required-rate block.

**Full source:**

```dart
class _CricketFeed extends StatefulWidget {
  const _CricketFeed({required this.match, required this.enableFeedback});
  final SportMatch match;
  final bool enableFeedback;

  @override
  State<_CricketFeed> createState() => _CricketFeedState();
}

class _CricketFeedState extends State<_CricketFeed> {
  int _selectedInnings = 2;

  @override
  Widget build(BuildContext context) {
    final details = widget.match.cricketDetails;
    if (details == null || details.commentary.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.sensors,
        title: 'Match feed unavailable',
        message: 'Ball-by-ball commentary has not arrived.',
      );
    }
    final innings = [...details.innings]
      ..sort((a, b) => a.number.compareTo(b.number));
    final selected = innings.firstWhere(
      (item) => item.number == _selectedInnings,
      orElse: () => innings.last,
    );
    final commentary = details.commentary
        .where((ball) => ball.innings == selected.number)
        .toList();
    return Column(
      key: const ValueKey('cricket-stats-match-feed'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: CyberFilterChips(
            labels: [
              for (final item in innings) item.abbreviation.toUpperCase(),
            ],
            selected: selected.abbreviation.toUpperCase(),
            accent: Cyber.cyan,
            onSelect: (value) {
              if (widget.enableFeedback) HapticFeedback.selectionClick();
              final next = innings.firstWhere(
                (item) => item.abbreviation.toUpperCase() == value,
              );
              if (next.number != _selectedInnings) {
                setState(() => _selectedInnings = next.number);
              }
            },
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    '${selected.abbreviation.toUpperCase()} // ${commentary.length} BALL ENTRIES // INNINGS ${selected.number}',
                    style: Cyber.label(8, color: Cyber.cyan),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: commentary.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: CyberNoDataState(
                          icon: Icons.sensors,
                          title: 'Commentary unavailable',
                          message:
                              'This innings has no published ball-by-ball feed.',
                        ),
                      )
                    : SliverList.separated(
                        itemCount: commentary.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) =>
                            _BallCard(ball: commentary[index]),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BallCard extends StatelessWidget {
  const _BallCard({required this.ball});
  final CricketBallCommentary ball;

  @override
  Widget build(BuildContext context) {
    final accent = ball.wicket
        ? Cyber.danger
        : ball.boundary
        ? Cyber.gold
        : Cyber.cyan;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(ball.over, style: _cricketNumber(11, color: accent)),
          ),
          Container(
            width: 2,
            constraints: const BoxConstraints(minHeight: 64),
            color: accent.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ball.preText != null) ...[
                  Text(
                    ball.preText!,
                    style: Cyber.body(10.5, color: Cyber.muted),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(ball.shortText, style: Cyber.label(8, color: accent)),
                const SizedBox(height: 4),
                Text(ball.text, style: Cyber.body(12)),
                if (ball.dismissal != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ball.dismissal!.toUpperCase(),
                    style: Cyber.label(8, color: Cyber.danger),
                  ),
                ],
                if (ball.postText != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    ball.postText!,
                    style: Cyber.body(10.5, color: Cyber.muted),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${ball.score} // ${ball.runs} RUNS // RR ${ball.runRate.toStringAsFixed(2)}'
                  '${ball.required == null ? '' : ' // NEED ${ball.required!.runs} OFF ${ball.required!.balls} @ ${ball.required!.runRate.toStringAsFixed(2)}'}',
                  style: Cyber.label(7.2, color: Cyber.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 10. Leaves

`_CricketInfo` is the label/value row used by MATCH INTEL, HONOURS and OFFICIALS
(96 px label column, muted uppercase label, body value). `_cricketNumber` is the
file's one text helper: display type with tabular figures, used by `_BallCard`'s
over column.

**Full source:**

```dart
class _CricketInfo extends StatelessWidget {
  const _CricketInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label.toUpperCase(),
              style: Cyber.label(7.5, color: Cyber.muted),
            ),
          ),
          Expanded(child: Text(value, style: Cyber.body(11.5))),
        ],
      ),
    );
  }
}
```

```dart
TextStyle _cricketNumber(double size, {Color color = Colors.white}) =>
    Cyber.display(
      size,
      color: color,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
```

---

## 11. Porting guide

### 11.1 pubspec

No packages. You need the two fonts and nothing else:

```yaml
flutter:
  fonts:
    - family: Orbitron
      fonts:
        - asset: assets/fonts/Orbitron-VariableFont_wght.ttf
    - family: Onest
      fonts:
        - asset: assets/fonts/Onest-VariableFont_wght.ttf
```

Swap in any condensed display face + neutral body face if you do not have these;
`Cyber.displayFont` / `Cyber.bodyFont` are the only two places the names appear.

### 11.2 The design tokens — flattened, drop-in

In this repo `Cyber` is a facade over `AppTheme`. Below is the same class with
every value resolved to a literal, carrying exactly the tokens this view and its
components use, plus the three text helpers and the glow helper **verbatim**:

```dart
import 'package:flutter/material.dart';

/// Flattened copy of the app's design tokens. In the source project every
/// value below is an alias onto `AppTheme` in lib/config/theme.dart; they are
/// resolved to literals here so this class drops into a new project as-is.
class Cyber {
  // Surfaces
  static const Color bg = Color.fromRGBO(13, 17, 26, 1);
  static const Color bg2 = Color.fromRGBO(7, 12, 31, 1);
  static const Color card = Color.fromRGBO(15, 23, 43, 1);
  static const Color panel = Color.fromRGBO(29, 41, 61, 1);
  static const Color panel2 = Color.fromRGBO(15, 23, 43, 1);

  // Accents
  static const Color cyan = Color.fromRGBO(92, 223, 255, 1);
  static const Color accentGlow = Color(0x405cdfff);
  static const Color magenta = Color.fromRGBO(194, 122, 255, 1);
  static const Color lime = Color.fromRGBO(81, 255, 148, 1);
  static const Color amber = Color.fromRGBO(255, 137, 4, 1);
  static const Color gold = Color.fromRGBO(253, 199, 0, 1);
  static const Color danger = Color.fromRGBO(255, 77, 77, 1);
  static const Color success = Color.fromRGBO(5, 223, 114, 1);
  static const Color red = Color.fromRGBO(227, 31, 38, 1);
  static const Color violet = Color.fromRGBO(194, 122, 255, 1);

  // Lines and text
  static const Color border = Color.fromRGBO(49, 65, 88, 1);
  static const Color line = Color.fromRGBO(69, 85, 108, 1);
  static const Color borderSubtle = Color.fromRGBO(255, 255, 255, 0.1);
  static const Color borderActive = Color.fromRGBO(173, 70, 255, 0.5);
  static const Color muted = Color.fromRGBO(144, 161, 185, 1);
  static const Color textPrimary = Color.fromRGBO(92, 223, 255, 1);
  static const Color borderMuted = Color(0xFF243654);
  static const Color chartSurface = Color(0xFF10192D);

  static const displayFont = 'Orbitron';
  static const bodyFont = 'Onest';

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

### 11.3 The two stand-ins

**Team colours.** `paletteForTeam(team, sport:, competition:)` returns a
`TeamPalette`; this view only ever reads `.secondaryTextColor`, the
readable-on-dark identity colour. The real implementation is a 4,699-line
generated lookup — do not copy it. A working stand-in:

```dart
// Port stand-in for lib/data/team_palettes.dart.
class TeamPalette {
  const TeamPalette(this.secondaryTextColor);
  final Color secondaryTextColor;
}

TeamPalette paletteForTeam(
  SportTeam team, {
  Sport? sport,
  String? competition,
}) => TeamPalette(team.color); // or your own brand lookup
```

**UI sound.** `CyberFilterChips` calls `playSound(SoundEffect.uiTap)` and the
chart panel does the same on range taps and marker crossings. Either wire your
own audio or stub it:

```dart
// Port stand-in for lib/utils/sound_effects.dart.
enum SoundEffect { uiTap }
void playSound(SoundEffect effect) {}
```

**Haptics** come straight from `flutter/services.dart` and need no adaptation —
but keep the `enableFeedback` flag if you want testable widgets.

### 11.4 The two subsystems

SCORECARD and its player dossier are features in their own right, with their own
dependency trees (`cricket_scorecard.dart` models, a shared player-sheet chrome,
an innings tape, a portrait map). App. D gives their exact constructors. Three
options, cheapest first:

1. **Drop the tab.** Remove `'SCORECARD'` from `_tabs` and its `switch` arm; the
   other three tabs have no dependency on it.
2. **Render your own table** behind the same contract —
   `CricketScorecardView({required scorecard, required accent, void Function(String playerId)? onTapPlayer})`
   — and keep `_CricketScorecard` untouched.
3. **Port the files** listed in App. D as-is.

### 11.5 Checklist

- [ ] Fonts declared; `Cyber` from §11.2 compiles
- [ ] `paletteForTeam` + `playSound` stand-ins in place
- [ ] App. C models (or your own with the same field names) — the view reads
      `.over`, `.runs`, `.wickets`, `.wicket`, `.runRate`, `.legalBall`,
      `.boundary`, `.requiredRunRate(target:)` directly
- [ ] App. A widgets compile (chips → cyber widgets → stats shell)
- [ ] App. B `cyber_chart.dart` compiles — it is the only heavy dependency, and
      RACE is the only tab that needs it
- [ ] The view pasted in verbatim from §2–§10
- [ ] SCORECARD decision made (§11.4)
- [ ] Dart 3.7+ / Flutter 3.27+ toolchain

---

## 12. Design rules the port should keep

- **Glow scarcity.** Exactly one glowing element on the whole view: the innings
  race's reveal sweep, gated `glow: progress < 1`. The run-rate chart sets
  `glow: false` explicitly *because* the race above already owns the moment.
  Panels, pills, rails and rows are flat fill + border.
- **Colour semantics.** Team identity colours carry the data; `Cyber.gold` means
  boundary or honour, `Cyber.danger` means wicket, `Cyber.success` means the
  settled result, `Cyber.magenta` is the required rate, cyan is structural
  chrome.
- **Type.** No raw `TextStyle` anywhere — `Cyber.display` / `Cyber.body` /
  `Cyber.label`, and numbers ride `FontFeature.tabularFigures()` via
  `_cricketNumber` and the shared components.
- **Greeble.** `//`-joined telemetry (`'<ABBR> // 122 BALL ENTRIES // INNINGS 2'`,
  `'<VENUE> // <CITY>, <COUNTRY>'`) is deliberate HUD texture, not filler.
- **Charts are interactive.** Every `CyberChartPanel` scrubs with a dashed
  playhead and selection haptics, reads every series out at the scrubbed point
  with its context label, and expands full-screen. Do not port them as static
  images.

---

## 13. Test hooks

| Key | Where |
| --- | --- |
| `cricket-stats-overview` | OVERVIEW list |
| `cricket-stats-race` | RACE list |
| `cricket-innings-race-graph` | innings race chart surface (scrub target) |
| `cricket-innings-run-rate-graph` | run-rate chart surface |
| `run-rate-<innings>` | the run-rate reveal builder, re-keyed per innings |
| `cricket-stats-scorecard` | SCORECARD list |
| `cricket-stats-match-feed` | MATCH FEED column |

Covered by
[`test/basketball_cricket_match_stats_view_test.dart`](../../test/basketball_cricket_match_stats_view_test.dart):
*cricket HUD exposes four sections with both race charts*, *sport HUDs keep
contextual empty states for partial feeds*, *innings race remains when delivery
progression is unavailable*, *tapping a scorecard row opens that player dossier*,
*the cricket dossier pages across the squad*, and *a bowler opens on their spell,
not an empty tape*. All construct the view with `enableFeedback: false`.

---

## Implementation References

- [`lib/screens/predictions/widgets/cricket_match_stats_view.dart`](../../lib/screens/predictions/widgets/cricket_match_stats_view.dart)
- [`lib/screens/predictions/widgets/match_stats_shell.dart`](../../lib/screens/predictions/widgets/match_stats_shell.dart)
- [`lib/screens/predictions/widgets/cricket_player_match_sheet.dart`](../../lib/screens/predictions/widgets/cricket_player_match_sheet.dart)
- [`lib/widgets/cricket_scorecard_view.dart`](../../lib/widgets/cricket_scorecard_view.dart)
- [`lib/widgets/cyber/cyber_chart.dart`](../../lib/widgets/cyber/cyber_chart.dart)
- [`lib/widgets/cyber/cyber_filter_chips.dart`](../../lib/widgets/cyber/cyber_filter_chips.dart)
- [`lib/widgets/cyber/cyber_widgets.dart`](../../lib/widgets/cyber/cyber_widgets.dart)
- [`lib/models/cricket_match_data.dart`](../../lib/models/cricket_match_data.dart)
- [`lib/models/sport_match.dart`](../../lib/models/sport_match.dart)
- [`lib/config/theme.dart`](../../lib/config/theme.dart)
- [`lib/data/team_palettes.dart`](../../lib/data/team_palettes.dart)
- [`lib/screens/predictions/match_detail_screen.dart`](../../lib/screens/predictions/match_detail_screen.dart)

## Tests

- [`test/basketball_cricket_match_stats_view_test.dart`](../../test/basketball_cricket_match_stats_view_test.dart)

---

## Appendix A — shared widgets, in full

### A.1 `cyber_filter_chips.dart` — the tab strip

The whole file. `_CutCornerBorder` is the chamfered silhouette; the active chip
is tinted, never glowing.

```dart
import '../../config/theme.dart';
import '../../utils/sound_effects.dart';

/// A horizontal, scrollable strip of cut-corner filter chips — the leaderboard
/// sport-filter look, reused on the shop catalogue tabs (nation on AVATAR, sport
/// on BORDER / BANNER). The active chip is the single tinted/outlined element;
/// per the glow rule it doesn't glow — the rest stay calm muted outlines.
class CyberFilterChips extends StatelessWidget {
  const CyberFilterChips({
    required this.labels,
    required this.selected,
    required this.onSelect,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 12, 10),
    super.key,
  });

  final List<String> labels;
  final String selected;
  final ValueChanged<String> onSelect;
  final Color accent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final label in labels)
            Padding(
              padding: const EdgeInsets.only(right: 7),
              child: CyberFilterChip(
                label: label,
                active: label == selected,
                accent: accent,
                onTap: () {
                  if (label == selected) return;
                  playSound(SoundEffect.uiTap);
                  onSelect(label);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class CyberFilterChip extends StatelessWidget {
  const CyberFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.accent = Cyber.cyan,
    super.key,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final color = active ? accent : Cyber.muted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: ShapeDecoration(
          color: active ? accent.withValues(alpha: 0.14) : Colors.transparent,
          shape: _CutCornerBorder(
            cut: 8,
            side: BorderSide(
              color: active
                  ? accent.withValues(alpha: 0.72)
                  : Cyber.line.withValues(alpha: 0.28),
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: Cyber.displayFont,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Diagonal corner-cut (top-left + bottom-right) border — the cyber chip
/// silhouette, matching the leaderboard's filter chips.
class _CutCornerBorder extends ShapeBorder {
  const _CutCornerBorder({required this.cut, this.side = BorderSide.none});

  final double cut;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      _CutCornerBorder(cut: cut * t, side: side.scale(t));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final safeCut = cut.clamp(0, rect.shortestSide / 2).toDouble();
    return Path()
      ..moveTo(rect.left + safeCut, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.bottom - safeCut)
      ..lineTo(rect.right - safeCut, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top + safeCut)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width <= 0) return;
    final paint = side.toPaint()..style = PaintingStyle.stroke;
    canvas.drawPath(getOuterPath(rect, textDirection: textDirection), paint);
  }
}
```

### A.2 `cyber_widgets.dart` — the leaves this view uses

`CyberSectionHeading`, `CyberStatPill` and `CyberNoDataState` are used directly;
`PressableScale` is what `CyberNoDataState` needs for its optional action;
`CyberPanel` (+ its border painter and `CyberClipper`) and `CyberPlainBackground`
(+ `CyberGridPainter`) are what the charting engine in App. B needs.

```dart
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

/// Tinted outline pill for a status/type/telemetry token. Never glows — pills
/// are secondary chrome.
class CyberStatPill extends StatelessWidget {
  const CyberStatPill({
    required this.label,
    required this.color,
    this.value,
    super.key,
  });

  final String label;
  final Color color;

  /// When set the pill reads `LABEL value`, with the value in white.
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: value == null
          ? Text(label.toUpperCase(), style: Cyber.label(9, color: color))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label.toUpperCase(), style: Cyber.label(9, color: color)),
                const SizedBox(width: 6),
                Text(
                  value!,
                  style: Cyber.label(
                    9,
                    color: Colors.white,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
    );
  }
}

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

/// Standard press feedback for tappable HUD surfaces: a quick scale-down to
/// 0.97 while the pointer is down, matching the action-card tap feel. Wrap the
/// visual only — supply [onTap] here instead of an outer GestureDetector.
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

class CyberPanel extends StatelessWidget {
  const CyberPanel({
    required this.child,
    this.accent = Cyber.cyan,
    this.padding = const EdgeInsets.all(16),
    this.glow = false,
    super.key,
  });

  final Widget child;
  final Color accent;
  final EdgeInsetsGeometry padding;

  /// Whether this is a focal / active surface that should glow. Off by default:
  /// most panels are plain surfaces and rely on the fill + border for depth.
  /// Reserve [glow] for the panel the user should look at first on a screen.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent.withValues(alpha: 0.5);
    return CustomPaint(
      foregroundPainter: _CyberPanelBorderPainter(color: borderColor),
      child: ClipPath(
        clipper: CyberClipper(),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Cyber.panel,
            boxShadow: glow
                ? Cyber.glow(accent, alpha: 0.18, blur: 18, spread: 1)
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class _CyberPanelBorderPainter extends CustomPainter {
  const _CyberPanelBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      CyberClipper.buildPath(size),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_CyberPanelBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

class CyberClipper extends CustomClipper<Path> {
  static const double cut = 12;

  static Path buildPath(Size size, {double cut = cut}) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - cut)
      ..lineTo(size.width - cut, size.height)
      ..lineTo(cut, size.height)
      ..lineTo(0, size.height - cut)
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

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

class CyberGridPainter extends CustomPainter {
  const CyberGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = Cyber.bg);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
```

### A.3 `match_stats_shell.dart` — the comparison rows

Shared with the football and basketball reports. `MatchPulseHeader`, the file's
fourth export, is **not** used by the cricket view and is omitted here.

```dart
/// The flat data-surface shell every stat row, event card and roster row sits
/// on — the market detail outcome-row container. Tinting is opt-in via
/// [accent]; per the glow rule it never glows.
class StatsRowShell extends StatelessWidget {
  const StatsRowShell({
    required this.child,
    this.accent,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(10),
    super.key,
  });

  final Widget child;
  final Color? accent;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final accent = this.accent;
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected && accent != null
            ? accent.withValues(alpha: 0.12)
            : Cyber.chartSurface,
        border: Border.all(
          color: selected && accent != null
              ? accent
              : accent?.withValues(alpha: 0.4) ?? Cyber.border,
        ),
      ),
      child: child,
    );
    if (onTap == null) return surface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: surface,
    );
  }
}

/// One home-vs-away metric, shaped like a market outcome row: the two values as
/// big tabular figures either side of the label, over a split meter at the home
/// side's share. Replaces the three near-identical split-bar implementations
/// the sport views each carried.
class StatComparisonRow extends StatelessWidget {
  const StatComparisonRow({
    required this.stat,
    required this.homeColor,
    required this.awayColor,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final TeamStatLine stat;
  final Color homeColor;
  final Color awayColor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final homeLeads = stat.homeShare >= 0.5;
    final valueStyle = Cyber.display(
      16,
      letterSpacing: 0,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

    return StatsRowShell(
      accent: homeLeads ? homeColor : awayColor,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 62,
                child: Text(
                  stat.homeDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle.copyWith(
                    color: homeLeads ? homeColor : Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  stat.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1),
                ),
              ),
              SizedBox(
                width: 62,
                child: Text(
                  stat.awayDisplay,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: valueStyle.copyWith(
                    color: homeLeads ? Colors.white : awayColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _SplitBar(
            share: stat.homeShare,
            homeColor: homeColor,
            awayColor: awayColor,
          ),
        ],
      ),
    );
  }
}

/// Two meters back to back, split at the home share, so the pair reads as one
/// contested bar.
class _SplitBar extends StatelessWidget {
  const _SplitBar({
    required this.share,
    required this.homeColor,
    required this.awayColor,
  });

  final double share;
  final Color homeColor;
  final Color awayColor;

  @override
  Widget build(BuildContext context) {
    final homeFlex = (share * 1000).round().clamp(5, 995);
    // Each side carries its own height: a childless ColoredBox collapses to
    // zero under the row's loose cross-axis constraints.
    return Row(
      children: [
        Expanded(
          flex: homeFlex,
          child: Container(height: 6, color: homeColor),
        ),
        const SizedBox(width: 3),
        Expanded(
          flex: 1000 - homeFlex,
          child: Container(height: 6, color: awayColor),
        ),
      ],
    );
  }
}

/// Team identity marker used above a comparison block — a colour swatch, the
/// short code and the full name.
class TeamLegendMark extends StatelessWidget {
  const TeamLegendMark({
    required this.team,
    required this.sport,
    this.competition,
    this.alignEnd = false,
    super.key,
  });

  final SportTeam team;
  final Sport sport;
  final String? competition;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final color = paletteForTeam(
      team,
      sport: sport,
      competition: competition,
    ).secondaryTextColor;
    final swatch = Container(width: 4, height: 30, color: color);
    final copy = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          team.shortName.toUpperCase(),
          style: Cyber.display(13, color: color),
        ),
        Text(
          team.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.8),
        ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd
          ? [Flexible(child: copy), const SizedBox(width: 8), swatch]
          : [swatch, const SizedBox(width: 8), Flexible(child: copy)],
    );
  }
}

/// The home/away identity pair that heads a comparison block. Both sides flex,
/// so a long club name ellipsises instead of overflowing the row.
class TeamLegendRow extends StatelessWidget {
  const TeamLegendRow({required this.match, super.key});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TeamLegendMark(
            team: match.home,
            sport: match.sport,
            competition: match.leagueId,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TeamLegendMark(
            team: match.away,
            sport: match.sport,
            competition: match.leagueId,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}
```

---

## Appendix B — `cyber_chart.dart`, the charting engine, in full

The app's one charting system: a flat panel, a cyan title, optional range tabs, a
scrubbable plot with a dashed playhead and selection haptics, event markers, a
reveal sweep, a legend that reads every series out at the scrubbed point, and a
full-screen route. RACE is the only cricket tab that needs it. Imports are
stripped; it needs `dart:math`, `flutter/material.dart`, `flutter/services.dart`,
your `Cyber` tokens (§11.2), the `playSound` stub (§11.3) and A.2's
`CyberPlainBackground`.

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';
import '../../utils/sound_effects.dart';
import 'cyber_widgets.dart';

/// The app's one charting system, lifted out of the pick market detail screen so
/// picks and match stats read as the same surface.
///
/// A chart is a flat [Cyber.chartSurface] panel with a cyan section label, an
/// optional range switcher, a scrubbable plot, and a legend that reads out every
/// series at the scrubbed point. Per the glow rule the panel itself stays calm —
/// the single focal moment is the reveal sweep (see [CyberChartPanel.glow]) and
/// the white playhead the player is dragging.

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

---

## Appendix C — models

### C.1 Cricket data — `cricket_match_data.dart` (the classes this view reads)

```dart
class CricketMatchDetails {
  const CricketMatchDetails({
    required this.league,
    required this.leagueAbbreviation,
    required this.season,
    required this.title,
    required this.stage,
    required this.format,
    required this.formatName,
    required this.status,
    required this.state,
    required this.result,
    required this.seriesNote,
    required this.venue,
    required this.city,
    required this.country,
    required this.neutralSite,
    required this.toss,
    required this.innings,
    required this.awards,
    required this.officials,
    required this.notes,
    required this.commentary,
    this.inningsProgress = const [],
    this.inningsRateProgress = const [],
    required this.teams,
  });

  final String league;
  final String leagueAbbreviation;
  final int season;
  final String title;
  final String stage;
  final String format;
  final String formatName;
  final String status;
  final String state;
  final String result;
  final String seriesNote;
  final String venue;
  final String city;
  final String country;
  final bool neutralSite;
  final CricketToss toss;
  final List<CricketInningsSummary> innings;
  final List<CricketAward> awards;
  final List<CricketOfficial> officials;
  final List<CricketMatchNote> notes;
  final List<CricketBallCommentary> commentary;
  final List<CricketInningsProgress> inningsProgress;
  final List<CricketInningsRateProgress> inningsRateProgress;
  final List<CricketTeamSquad> teams;
}

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

class CricketToss {
  const CricketToss({required this.team, required this.decision});
  final String team;
  final String decision;
}

class CricketInningsSummary {
  const CricketInningsSummary({
    required this.number,
    required this.team,
    required this.teamId,
    required this.abbreviation,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.fours,
    required this.sixes,
    required this.score,
    required this.description,
    required this.current,
    this.target,
  });
  final int number;
  final String team;
  final String teamId;
  final String abbreviation;
  final int runs;
  final int wickets;
  final double overs;
  final int fours;
  final int sixes;
  final int? target;
  final String score;
  final String description;
  final bool current;
}

class CricketAward {
  const CricketAward({
    required this.id,
    required this.name,
    required this.award,
    required this.team,
    required this.teamId,
  });
  final String id;
  final String name;
  final String award;
  final String team;
  final String teamId;
}

class CricketOfficial {
  const CricketOfficial({
    required this.name,
    required this.role,
    required this.country,
  });
  final String name;
  final String role;
  final String country;
}

class CricketRequiredRate {
  const CricketRequiredRate({
    required this.runs,
    required this.balls,
    required this.runRate,
  });
  final int runs;
  final int balls;
  final double runRate;
}

class CricketBallCommentary {
  const CricketBallCommentary({
    required this.id,
    required this.sequence,
    required this.innings,
    required this.over,
    required this.overNumber,
    required this.ball,
    required this.batter,
    required this.bowler,
    required this.runs,
    required this.boundary,
    required this.wicket,
    required this.score,
    required this.runRate,
    required this.shortText,
    required this.text,
    this.dismissal,
    this.required,
    this.preText,
    this.postText,
  });
  final String id;
  final int sequence;
  final int innings;
  final String over;
  final int overNumber;
  final int ball;
  final String batter;
  final String bowler;
  final int runs;
  final bool boundary;
  final bool wicket;
  final String? dismissal;
  final String score;
  final double runRate;
  final CricketRequiredRate? required;
  final String shortText;
  final String text;
  final String? preText;
  final String? postText;
}

class CricketTeamSquad {
  const CricketTeamSquad({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.isHome,
    required this.captain,
    required this.keeper,
    required this.squadPublished,
    required this.playerCount,
    required this.players,
  });
  final String id;
  final String name;
  final String abbreviation;
  final bool isHome;
  final String captain;
  final String keeper;
  final bool squadPublished;
  final int playerCount;
  final List<CricketSquadPlayer> players;
}
```

The remaining classes in that file (`CricketDelivery`, the stat catalogue,
`CricketPlayerMatchStats`, `CricketSquadPlayer`) belong to the player dossier —
see App. D.

### C.2 Match data — `sport_match.dart` (the pieces this view reads)

```dart
/// Sport governs how sport-specific surfaces lay out scores and modules.
enum Sport { football, cricket, motorsport, basketball, tennis }

/// Lifecycle of a fixture, which drives whether a prediction can still be made.
enum MatchStatus { upcoming, live, finished }

/// One side of a fixture. Crest art can be added later via [crestAsset];
/// until then the UI falls back to an initials badge tinted with [color].
class SportTeam {
  const SportTeam({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    this.crestAsset,
    this.flagUrl,
  });

  final String id;
  final String name;

  /// 2–4 letter code shown on the badge (e.g. "CSK", "MI").
  final String shortName;
  final Color color;
  final String? crestAsset;

  /// Real flag image URL for a tennis player's nationality, when the source
  /// feed provides one (e.g. ESPN's `athlete.flag.href`). Null falls back to
  /// [TennisCountryMap]'s emoji/colour badge.
  final String? flagUrl;
}

/// One head-to-head statistic — the same metric for both sides, ready to draw
/// as a labelled split bar. [homeDisplay]/[awayDisplay] carry the formatted
/// text ("54.1%", "469"), while the numeric pair sizes the bar.
class TeamStatLine {
  const TeamStatLine({
    required this.label,
    required this.homeDisplay,
    required this.awayDisplay,
    required this.homeValue,
    required this.awayValue,
  });

  final String label;
  final String homeDisplay;
  final String awayDisplay;
  final double homeValue;
  final double awayValue;

  /// The home side's share of the pair (0..1), used as the split point. Falls
  /// back to an even split when neither side recorded anything, so a 0–0 stat
  /// renders as a balanced bar rather than collapsing to one side.
  double get homeShare {
    final total = homeValue + awayValue;
    if (total <= 0) return 0.5;
    return homeValue / total;
  }
}
```

`SportMatch` itself is a 402-line aggregate across five sports. The cricket view
touches only `id`, `leagueId`, `sport`, `home`, `away`, `teamStats`,
`cricketDetails`, `cricketScorecard` and `cricketSquads` — a port can carry a
much smaller class as long as those names match.

---

## Appendix D — the two subsystems, by contract

Not inlined: each is a feature with its own model layer. Copy the files, or
reimplement behind these signatures and leave §8 untouched.

### D.1 The scorecard table

```dart
// lib/widgets/cricket_scorecard_view.dart (720 lines)
// Needs: lib/models/cricket_scorecard.dart, cyber_filter_chips.dart,
//        cyber_widgets.dart, lib/widgets/cyber/player_match_sheet.dart
class CricketScorecardView extends StatefulWidget {
  const CricketScorecardView({
    super.key,
    required this.scorecard,
    required this.accent,
    this.onTapPlayer,
  });

  final CricketScorecard scorecard;
  final Color accent;

  /// Opens a player's match dossier. Null when the caller has no squad data to
  /// resolve an id against — a live scorecard, for instance — in which case the
  /// rows stay untappable rather than opening an empty card.
  final void Function(String playerId)? onTapPlayer;
}
```

### D.2 The player dossier

```dart
// lib/screens/predictions/widgets/cricket_player_match_sheet.dart (472 lines)
// Needs: cricket_match_data.dart, cricket_innings_tape.dart,
//        lib/data/cricket_match_portraits.dart, cyber_chart.dart,
//        cyber_widgets.dart, lib/widgets/cyber/player_match_sheet.dart
Future<void> showCricketPlayerMatchSheet({
  required BuildContext context,
  required CricketTeamSquad squad,
  required CricketSquadPlayer player,
  required Color accent,
});
```

Its real body pages the whole squad through the shared `showPlayerMatchSheet`
chrome:

```dart
/// Opens the per-player match card, seeded at [player] and paging that
/// player's own squad.
Future<void> showCricketPlayerMatchSheet({
  required BuildContext context,
  required CricketTeamSquad squad,
  required CricketSquadPlayer player,
  required Color accent,
}) {
  final index = squad.players.indexWhere((p) => p.id == player.id);
  return showPlayerMatchSheet(
    context: context,
    accent: accent,
    itemCount: squad.players.length,
    initialIndex: index < 0 ? 0 : index,
    itemBuilder: (context, page) => CricketPlayerMatchCard(
      player: squad.players[page],
      squad: squad,
      accent: accent,
    ),
  );
}
```
