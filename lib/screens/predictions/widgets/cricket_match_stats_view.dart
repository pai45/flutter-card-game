import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/team_palettes.dart';
import '../../../models/cricket_match_data.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cricket_scorecard_view.dart';
import '../../../widgets/cyber/cyber_chart.dart';
import '../../../widgets/cyber/cyber_filter_chips.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import 'match_stats_shell.dart';

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
  static const _tabs = [
    'OVERVIEW',
    'RACE',
    'CHASE',
    'SCORECARD',
    'MATCH FEED',
    'SQUADS',
  ];
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
                'RACE' => _CricketRace(match: widget.match),
                'CHASE' => _CricketChase(match: widget.match),
                'SCORECARD' => _CricketScorecard(match: widget.match),
                'MATCH FEED' => _CricketFeed(
                  match: widget.match,
                  enableFeedback: widget.enableFeedback,
                ),
                'SQUADS' => _CricketSquads(
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

class _CricketOverview extends StatelessWidget {
  const _CricketOverview({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final details = match.cricketDetails;
    final pulse = _chasePulse(match);

    return ListView(
      key: const ValueKey('cricket-stats-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        MatchPulseHeader(
          match: match,
          title: '${match.home.name} vs ${match.away.name}',
          statusLabel: details?.status ?? _matchStatus(match.status),
          heroValue: pulse.value,
          heroLabel: pulse.label,
          heroCaption: pulse.caption,
          heroColor: pulse.color,
          delta: pulse.delta,
          deltaSuffix: 'RUN RATE',
          deltaDecimals: 2,
          subtitle: details == null
              ? _cricketStateMessage(match)
              : '${details.stage} // ${details.formatName} // ${details.season}',
          metrics: [
            CyberMiniMetric(label: 'FORMAT', value: details?.format ?? '—'),
            CyberMiniMetric(
              label: 'TARGET',
              value: pulse.target,
              accent: Cyber.gold,
            ),
          ],
        ),
        const SizedBox(height: 18),
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
        if (details?.innings.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          _InningsSummaryPanel(match: match, innings: details!.innings),
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

class _InningsSummaryPanel extends StatelessWidget {
  const _InningsSummaryPanel({required this.match, required this.innings});
  final SportMatch match;
  final List<CricketInningsSummary> innings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSectionHeading(label: 'INNINGS GRID'),
        const SizedBox(height: 10),
        StatsRowShell(
          accent: Cyber.magenta,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Column(
            children: innings.map((item) {
              final team = item.teamId == match.home.id
                  ? match.home
                  : match.away;
              final accent = paletteForTeam(team, sport: match.sport).primary;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        item.abbreviation,
                        style: Cyber.label(9, color: accent),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.score,
                            style: _cricketNumber(15, color: accent),
                          ),
                          Text(
                            '${_overs(item.overs)} OV // ${item.fours}×4 // ${item.sixes}×6',
                            style: Cyber.label(7.5, color: Cyber.muted),
                          ),
                        ],
                      ),
                    ),
                    if (item.target != null)
                      Text(
                        'TARGET ${item.target}',
                        style: Cyber.label(8, color: Cyber.gold),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

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
    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;

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

/// RACE: both innings worms on one axis. Scrubbing reads out BOTH scores at the
/// same over — the comparison the old static worm made you eyeball.
class _CricketRace extends StatefulWidget {
  const _CricketRace({required this.match});
  final SportMatch match;

  @override
  State<_CricketRace> createState() => _CricketRaceState();
}

class _CricketRaceState extends State<_CricketRace> {
  static const _ranges = ['20 OV', 'POWERPLAY', 'DEATH'];
  String _range = _ranges.first;

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
    final homeInnings = details!.innings.firstWhere(
      (innings) => innings.teamId == match.home.id,
    );
    final awayInnings = details.innings.firstWhere(
      (innings) => innings.teamId == match.away.id,
    );
    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;
    final chaserWon =
        homeInnings.target != null && homeInnings.runs >= homeInnings.target!;
    final winner = chaserWon ? match.home : match.away;
    final ballsRemaining = homeInnings.target == null
        ? null
        : (120 - (homeTimeline.first.points.last.over * 6)).clamp(0, 120);

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
            markers: _wicketMarkers(home, away),
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
        const CyberSectionHeading(label: 'RACE VERDICT'),
        const SizedBox(height: 10),
        StatsRowShell(
          accent: paletteForTeam(winner, sport: match.sport).primary,
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CricketChip(label: 'WINNER', value: winner.shortName),
              _CricketChip(
                label: 'TARGET',
                value: '${homeInnings.target ?? '—'}',
              ),
              _CricketChip(
                label: match.home.shortName,
                value: '${homeInnings.runs}/${homeInnings.wickets}',
              ),
              _CricketChip(
                label: match.away.shortName,
                value: '${awayInnings.runs}/${awayInnings.wickets}',
              ),
              if (ballsRemaining != null)
                _CricketChip(label: 'BALLS LEFT', value: '$ballsRemaining'),
            ],
          ),
        ),
      ],
    );
  }
}

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
  List<CricketScoreProgressPoint> away,
) {
  if (home.length < 2) return const <ChartMarker>[];
  final markers = <ChartMarker>[];
  for (var i = 0; i < home.length; i++) {
    if (home[i].wicket) {
      markers.add(
        ChartMarker(
          fraction: i / (home.length - 1),
          color: Cyber.danger,
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
          color: Cyber.danger,
          shape: ChartMarkerShape.diamond,
          alignTop: false,
        ),
      );
    }
  }
  return markers;
}

/// CHASE: actual run rate against the rate the chase demanded, ball by ball.
/// Where RACE shows who scored more, CHASE shows whether they were ever behind.
class _CricketChase extends StatefulWidget {
  const _CricketChase({required this.match});
  final SportMatch match;

  @override
  State<_CricketChase> createState() => _CricketChaseState();
}

class _CricketChaseState extends State<_CricketChase> {
  static const _ranges = ['ALL BALLS', 'BOUNDARIES', 'FINAL OVER'];
  String _range = _ranges.first;

  @override
  Widget build(BuildContext context) {
    final details = widget.match.cricketDetails;
    final all = details?.commentary ?? const <CricketBallCommentary>[];
    if (all.length < 2) {
      return const CyberNoDataState(
        icon: Icons.speed,
        title: 'Chase feed unavailable',
        message: 'Ball-level run-rate samples have not been published.',
      );
    }
    final balls = _ballsForRange(all, _range);
    final chase = details!.innings.firstWhere(
      (innings) => innings.target != null,
      orElse: () => details.innings.last,
    );
    final boundaries = balls.where((ball) => ball.boundary).length;
    final wickets = balls.where((ball) => ball.wicket).length;

    return ListView(
      key: const ValueKey('cricket-stats-chase'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 760),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => CyberChartPanel(
            chartKey: const ValueKey('cricket-late-chase-graph'),
            title: 'LATE CHASE',
            caption: '${balls.length} BALLS',
            height: 230,
            yAxisLabels: true,
            glow: progress < 1,
            revealProgress: progress,
            ranges: _ranges,
            activeRange: _range,
            onRangeChanged: (range) => setState(() => _range = range),
            markers: _boundaryMarkers(balls),
            contextLabelAt: (index) =>
                balls[index.clamp(0, balls.length - 1)].over,
            series: [
              ChartSeries(
                label: 'ACTUAL RR',
                color: Cyber.cyan,
                fill: true,
                readout: (value, _) => value.toStringAsFixed(1),
                values: [for (final ball in balls) ball.runRate],
              ),
              ChartSeries(
                label: 'REQUIRED RR',
                color: Cyber.magenta,
                strokeWidth: 1.8,
                readout: (value, _) => value.toStringAsFixed(1),
                values: [for (final ball in balls) ball.required?.runRate ?? 0],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const CyberSectionHeading(label: 'CHASE READOUT'),
        const SizedBox(height: 10),
        StatsRowShell(
          accent: Cyber.gold,
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CricketChip(label: 'TARGET', value: '${chase.target ?? '—'}'),
              _CricketChip(label: 'FINISH', value: chase.score),
              _CricketChip(label: 'BOUNDARIES', value: '$boundaries'),
              _CricketChip(label: 'WICKETS', value: '$wickets'),
              _CricketChip(label: 'SAMPLES', value: '${balls.length}'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const CyberSectionHeading(label: 'BALL PRESSURE'),
        const SizedBox(height: 10),
        for (final ball in balls) ...[
          StatsRowShell(
            accent: ball.wicket
                ? Cyber.danger
                : ball.boundary
                ? Cyber.gold
                : null,
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  child: Text(
                    ball.over,
                    style: _cricketNumber(10, color: Cyber.cyan),
                  ),
                ),
                Expanded(child: Text(ball.shortText, style: Cyber.body(11.5))),
                Text(
                  ball.required == null
                      ? 'CHASE COMPLETE'
                      : '${ball.required!.runs} OFF ${ball.required!.balls}',
                  style: Cyber.label(
                    7.5,
                    color: ball.boundary ? Cyber.gold : Cyber.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

List<CricketBallCommentary> _ballsForRange(
  List<CricketBallCommentary> balls,
  String range,
) {
  if (range == 'ALL BALLS' || balls.isEmpty) return balls;
  if (range == 'BOUNDARIES') {
    final hits = balls.where((ball) => ball.boundary || ball.wicket).toList();
    return hits.length >= 2 ? hits : balls;
  }
  final lastOver = balls.last.overNumber;
  final finalOver = balls.where((ball) => ball.overNumber == lastOver).toList();
  return finalOver.length >= 2 ? finalOver : balls;
}

/// Boundaries mark the chase; the last wicket is the decisive beat.
List<ChartMarker> _boundaryMarkers(List<CricketBallCommentary> balls) {
  if (balls.length < 2) return const <ChartMarker>[];
  final lastWicket = balls.lastIndexWhere((ball) => ball.wicket);
  return [
    for (var i = 0; i < balls.length; i++)
      if (balls[i].boundary || balls[i].wicket)
        ChartMarker(
          fraction: i / (balls.length - 1),
          color: balls[i].wicket ? Cyber.danger : Cyber.gold,
          shape: balls[i].wicket
              ? ChartMarkerShape.diamond
              : ChartMarkerShape.dot,
          focal: i == lastWicket,
        ),
  ];
}

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
    return ListView(
      key: const ValueKey('cricket-stats-scorecard'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        CricketScorecardView(scorecard: scorecard, accent: Cyber.cyan),
      ],
    );
  }
}

/// Cricket's hero number is the chase: the chasing side's score, with the swing
/// between the required rate and what they were actually scoring at.
({
  String value,
  String label,
  String caption,
  Color color,
  double? delta,
  String target,
})
_chasePulse(SportMatch match) {
  final details = match.cricketDetails;
  final innings = details?.innings ?? const <CricketInningsSummary>[];
  if (innings.isEmpty) {
    return (
      value: '—',
      label: match.home.name,
      caption: 'CHASE',
      color: Cyber.muted,
      delta: null,
      target: '—',
    );
  }
  final chase = innings.firstWhere(
    (item) => item.target != null,
    orElse: () => innings.last,
  );
  final team = chase.teamId == match.home.id ? match.home : match.away;

  double? delta;
  final balls = details?.commentary ?? const <CricketBallCommentary>[];
  if (balls.isNotEmpty) {
    final required = balls.last.required?.runRate;
    if (required != null) delta = balls.last.runRate - required;
  }

  return (
    value: '${chase.runs}/${chase.wickets}',
    label: team.name,
    caption: chase.target == null ? 'INNINGS TOTAL' : 'CHASE',
    color: paletteForTeam(team, sport: match.sport).primary,
    delta: delta,
    target: '${chase.target ?? '—'}',
  );
}

class _CricketFeed extends StatefulWidget {
  const _CricketFeed({required this.match, required this.enableFeedback});
  final SportMatch match;
  final bool enableFeedback;

  @override
  State<_CricketFeed> createState() => _CricketFeedState();
}

class _CricketFeedState extends State<_CricketFeed> {
  String _mode = 'COMMENTARY';

  @override
  Widget build(BuildContext context) {
    final details = widget.match.cricketDetails;
    if (details == null ||
        (details.commentary.isEmpty && details.notes.isEmpty)) {
      return const CyberNoDataState(
        icon: Icons.sensors,
        title: 'Match feed unavailable',
        message: 'Commentary and match notes have not arrived.',
      );
    }
    final commentary = details.commentary;
    final notes = details.notes;
    return Column(
      key: const ValueKey('cricket-stats-match-feed'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: CyberFilterChips(
            labels: const ['COMMENTARY', 'NOTES'],
            selected: _mode,
            accent: Cyber.cyan,
            onSelect: (value) {
              if (widget.enableFeedback) HapticFeedback.selectionClick();
              setState(() => _mode = value);
            },
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: StatsRowShell(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Text(
                      _mode == 'COMMENTARY'
                          ? '${commentary.length} BALL ENTRIES // INNINGS 2'
                          : '${notes.length} MATCH NOTES // ALL CATEGORIES',
                      style: Cyber.label(8, color: Cyber.cyan),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: _mode == 'COMMENTARY'
                    ? SliverList.separated(
                        itemCount: commentary.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _BallCard(ball: commentary[index]),
                      )
                    : SliverList.separated(
                        itemCount: notes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) =>
                            _NoteCard(note: notes[index]),
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
    return StatsRowShell(
      accent: accent,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            child: Text(ball.over, style: _cricketNumber(11, color: accent)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ball.preText != null) ...[
                  Text(
                    ball.preText!,
                    style: Cyber.body(10.5, color: Cyber.muted),
                  ),
                  const SizedBox(height: 5),
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
                  const SizedBox(height: 5),
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

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});
  final CricketMatchNote note;

  @override
  Widget build(BuildContext context) {
    final accent = switch (note.kind) {
      'milestone' => Cyber.gold,
      'review' => Cyber.magenta,
      'impact-sub' => Cyber.violet,
      'powerplay' => Cyber.cyan,
      _ => Cyber.muted,
    };
    return StatsRowShell(
      accent: accent,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              note.kind.toUpperCase(),
              style: Cyber.label(7.5, color: accent),
            ),
          ),
          Expanded(child: Text(note.text, style: Cyber.body(12))),
          const SizedBox(width: 8),
          Text(
            'INN ${note.innings}',
            style: Cyber.label(7, color: Cyber.muted),
          ),
        ],
      ),
    );
  }
}

class _CricketSquads extends StatefulWidget {
  const _CricketSquads({required this.match, required this.enableFeedback});
  final SportMatch match;
  final bool enableFeedback;

  @override
  State<_CricketSquads> createState() => _CricketSquadsState();
}

class _CricketSquadsState extends State<_CricketSquads> {
  bool _home = true;

  @override
  Widget build(BuildContext context) {
    final teams =
        widget.match.cricketDetails?.teams ?? const <CricketTeamSquad>[];
    if (teams.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.groups_outlined,
        title: 'Squads unavailable',
        message: 'Published player roles and styles have not arrived.',
      );
    }
    final squad = teams.firstWhere((team) => team.isHome == _home);
    final matchTeam = _home ? widget.match.home : widget.match.away;
    final accent = paletteForTeam(matchTeam, sport: widget.match.sport).primary;
    return Column(
      key: const ValueKey('cricket-stats-squads'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: CyberFilterChips(
            labels: [widget.match.home.shortName, widget.match.away.shortName],
            selected: _home
                ? widget.match.home.shortName
                : widget.match.away.shortName,
            accent: accent,
            onSelect: (value) {
              if (widget.enableFeedback) HapticFeedback.selectionClick();
              setState(() => _home = value == widget.match.home.shortName);
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              CyberSectionHeading(label: squad.name),
              const SizedBox(height: 10),
              StatsRowShell(
                accent: accent,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    _CricketInfo(label: 'CAPTAIN', value: squad.captain),
                    _CricketInfo(label: 'KEEPER', value: squad.keeper),
                    _CricketInfo(
                      label: 'STATUS',
                      value: squad.squadPublished ? 'CONFIRMED' : 'PROVISIONAL',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final player in squad.players) ...[
                _SquadPlayerCard(player: player, accent: accent),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SquadPlayerCard extends StatelessWidget {
  const _SquadPlayerCard({required this.player, required this.accent});
  final CricketSquadPlayer player;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tags = <String>[
      if (player.captain) 'C',
      if (player.keeper) 'WK',
      if (player.starter) 'PLAYING XI',
      if (player.subbedIn) 'IMPACT IN',
      if (player.subbedOut) 'SUBBED OUT',
      if (player.active) 'ACTIVE',
    ];
    return StatsRowShell(
      accent: accent,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name,
                      style: Cyber.body(13, weight: FontWeight.w700),
                    ),
                    Text(
                      '${player.role.toUpperCase()} // ${player.battingName}',
                      style: Cyber.label(7.5, color: Cyber.muted),
                    ),
                  ],
                ),
              ),
              if (tags.isNotEmpty)
                Text(
                  tags.join(' // '),
                  style: Cyber.label(7.5, color: Cyber.gold),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(player.fullName, style: Cyber.body(10.5, color: Cyber.muted)),
          const SizedBox(height: 4),
          Text(
            '${player.battingStyle}${player.bowlingStyle.isEmpty ? '' : ' // ${player.bowlingStyle}'}',
            style: Cyber.body(10.5, color: Cyber.muted),
          ),
          if (player.performances.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: player.performances.map((performance) {
                final values = <String>[
                  if (performance.battingScore != null)
                    'BAT ${performance.battingScore}',
                  if (performance.bowlingFigures != null)
                    'BOWL ${performance.bowlingFigures}',
                  if (performance.catches > 0) 'C ${performance.catches}',
                  if (performance.stumpings > 0) 'ST ${performance.stumpings}',
                ];
                return Text(
                  'INN ${performance.innings} // ${values.join(' // ')}',
                  style: Cyber.label(7.5, color: accent),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CricketChip extends StatelessWidget {
  const _CricketChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Cyber.card,
        border: Border.all(color: Cyber.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Cyber.label(7, color: Cyber.muted)),
          const SizedBox(height: 2),
          Text(value.toUpperCase(), style: _cricketNumber(9.5)),
        ],
      ),
    );
  }
}

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

TextStyle _cricketNumber(double size, {Color color = Colors.white}) =>
    Cyber.display(
      size,
      color: color,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
String _overs(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1);
String _matchStatus(MatchStatus status) => switch (status) {
  MatchStatus.upcoming => 'Pre-match',
  MatchStatus.live => 'Live now',
  MatchStatus.finished => 'Result',
};
String _cricketStateMessage(SportMatch match) =>
    match.liveStatusNote ??
    switch (match.status) {
      MatchStatus.upcoming => 'Scoreboard opens when the match starts.',
      MatchStatus.live => 'Live innings data is active.',
      MatchStatus.finished =>
        match.resultLine ?? 'Final score has been recorded.',
    };
