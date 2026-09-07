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
import 'cricket_player_match_sheet.dart';
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
