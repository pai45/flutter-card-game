import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/team_palettes.dart';
import '../../../models/basketball_match_data.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/basketball_scorecard_view.dart';
import '../../../widgets/cyber/cyber_chart.dart';
import '../../../widgets/cyber/cyber_filter_chips.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import 'match_stats_shell.dart';

class BasketballMatchStatsView extends StatefulWidget {
  const BasketballMatchStatsView({
    required this.match,
    this.enableFeedback = true,
    super.key,
  });
  final SportMatch match;
  final bool enableFeedback;

  @override
  State<BasketballMatchStatsView> createState() =>
      _BasketballMatchStatsViewState();
}

class _BasketballMatchStatsViewState extends State<BasketballMatchStatsView> {
  static const _tabs = ['OVERVIEW', 'FLOW', 'PLAYS', 'BOX SCORE', 'TEAMS'];
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
                'FLOW' => _BasketballFlow(match: widget.match),
                'PLAYS' => _BasketballPlays(match: widget.match),
                'BOX SCORE' => _BasketballBoxScore(match: widget.match),
                'TEAMS' => _BasketballTeams(
                  match: widget.match,
                  enableFeedback: widget.enableFeedback,
                ),
                _ => _BasketballOverview(match: widget.match),
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _BasketballOverview extends StatelessWidget {
  const _BasketballOverview({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final details = match.basketballDetails;
    final scorecard = match.basketballScorecard;

    return ListView(
      key: const ValueKey('basketball-stats-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        const CyberSectionHeading(label: 'GAME INTEL'),
        const SizedBox(height: 10),
        StatsRowShell(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                details?.league.toUpperCase() ?? match.leagueId.toUpperCase(),
                style: Cyber.display(15, letterSpacing: 0.8),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CyberStatPill(
                    label: 'BROADCAST',
                    value: _fallback(details?.broadcast),
                    color: Cyber.cyan,
                  ),
                  CyberStatPill(
                    label: 'FORMAT',
                    value: details?.overtime == true
                        ? 'OVERTIME'
                        : 'REGULATION',
                    color: Cyber.cyan,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoLine(
                label: 'VENUE',
                value: details == null
                    ? 'Venue awaiting feed'
                    : '${details.venue} // ${details.city}, ${details.state}',
              ),
            ],
          ),
        ),
        if (scorecard != null) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'QUARTER GRID'),
          const SizedBox(height: 10),
          _QuarterPanel(match: match),
        ],
        if (details?.series.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'SERIES SIGNAL'),
          const SizedBox(height: 10),
          for (final item in details!.series) ...[
            StatsRowShell(
              accent: Cyber.gold,
              padding: const EdgeInsets.all(12),
              child: _InfoLine(
                label: item.title,
                value:
                    '${item.description} // ${item.summary} // ${item.completed ? 'COMPLETE' : 'ACTIVE'}',
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        if (match.teamStats?.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          _BasketballStatPanel(match: match),
        ],
        if (details?.leaders.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          _LeaderPanel(match: match, groups: details!.leaders),
        ],
        if (details?.officials.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'OFFICIALS'),
          const SizedBox(height: 10),
          StatsRowShell(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: details!.officials
                  .map((item) => _InfoLine(label: item.role, value: item.name))
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuarterPanel extends StatelessWidget {
  const _QuarterPanel({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final lines = match.basketballScorecard!.linescores;
    return StatsRowShell(
      accent: Cyber.magenta,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        children: [
          _QuarterRow(
            label: match.away.shortName,
            values: lines.awayScores,
            total: lines.awayTotal,
            accent: paletteForTeam(
              match.away,
              sport: match.sport,
              competition: match.leagueId,
            ).secondaryTextColor,
          ),
          const HudLine(),
          _QuarterRow(
            label: match.home.shortName,
            values: lines.homeScores,
            total: lines.homeTotal,
            accent: paletteForTeam(
              match.home,
              sport: match.sport,
              competition: match.leagueId,
            ).secondaryTextColor,
          ),
        ],
      ),
    );
  }
}

class _QuarterRow extends StatelessWidget {
  const _QuarterRow({
    required this.label,
    required this.values,
    required this.total,
    required this.accent,
  });
  final String label;
  final List<int> values;
  final int total;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(label, style: Cyber.label(10, color: accent)),
          ),
          for (var index = 0; index < values.length; index++)
            Expanded(
              child: Column(
                children: [
                  Text(
                    'Q${index + 1}',
                    style: Cyber.label(7, color: Cyber.muted),
                  ),
                  const SizedBox(height: 2),
                  Text('${values[index]}', style: _numberStyle(12)),
                ],
              ),
            ),
          SizedBox(
            width: 38,
            child: Text(
              '$total',
              textAlign: TextAlign.right,
              style: _numberStyle(15, color: accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// TEAM CONTROL as a stack of market-style outcome rows — tap one to hold it
/// highlighted while you read the rest.
class _BasketballStatPanel extends StatefulWidget {
  const _BasketballStatPanel({required this.match});
  final SportMatch match;

  @override
  State<_BasketballStatPanel> createState() => _BasketballStatPanelState();
}

class _BasketballStatPanelState extends State<_BasketballStatPanel> {
  String? _selectedLabel;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final stats = match.teamStats!;
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
        const CyberSectionHeading(label: 'TEAM CONTROL'),
        const SizedBox(height: 12),
        TeamLegendRow(match: match),
        const SizedBox(height: 12),
        for (final stat in stats) ...[
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

class _LeaderPanel extends StatelessWidget {
  const _LeaderPanel({required this.match, required this.groups});
  final SportMatch match;
  final List<BasketballLeaderGroup> groups;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSectionHeading(label: 'IMPACT LEADERS'),
        const SizedBox(height: 10),
        for (final group in groups) ...[
          Builder(
            builder: (context) {
              final isHome = group.teamId == match.home.id;
              final accent = paletteForTeam(
                isHome ? match.home : match.away,
                sport: match.sport,
                competition: match.leagueId,
              ).secondaryTextColor;
              return StatsRowShell(
                accent: accent,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      group.team.toUpperCase(),
                      style: Cyber.label(9, color: accent),
                    ),
                    const SizedBox(height: 8),
                    for (final leader in group.leaders)
                      _InfoLine(
                        label: leader.label,
                        value: '${leader.name} // ${leader.value}',
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// FLOW: the win-probability trace and the scoring map, both on the shared
/// chart surface so they scrub and expand like a pick market.
class _BasketballFlow extends StatefulWidget {
  const _BasketballFlow({required this.match});
  final SportMatch match;

  @override
  State<_BasketballFlow> createState() => _BasketballFlowState();
}

class _BasketballFlowState extends State<_BasketballFlow> {
  static const _flowRanges = ['GAME', 'H1', 'H2', 'CLUTCH'];
  static const _mapRanges = ['ALL', 'HOME', 'AWAY', '3PT'];

  String _flowRange = _flowRanges.first;
  String _mapRange = _mapRanges.first;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final details = match.basketballDetails;
    if (details == null || details.plays.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.show_chart,
        title: 'Flow feed unavailable',
        message: 'Scoring progression and shot coordinates have not arrived.',
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
    final plays = _playsForRange(details.plays, _flowRange);
    final mapped = _mappedPlays(details.plays, _mapRange);
    final edge = _ScoringEdge.from(details.plays);

    return ListView(
      key: const ValueKey('basketball-stats-flow'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 760),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => CyberChartPanel(
            chartKey: const ValueKey('basketball-scoring-run-graph'),
            title: 'SCORING RUN',
            caption: '${plays.length} PLAYS',
            height: 220,
            stepped: true,
            yAxisLabels: true,
            gridDivisions: 4,
            glow: progress < 1,
            revealProgress: progress,
            ranges: _flowRanges,
            activeRange: _flowRange,
            onRangeChanged: (range) => setState(() => _flowRange = range),
            markers: _leadChangeMarkers(plays, homeColor, awayColor),
            xAxisLabels: _periodLabels(plays),
            contextLabelAt: (index) {
              final play = plays[index.clamp(0, plays.length - 1)];
              return 'Q${play.period} ${play.clock}';
            },
            series: [
              ChartSeries(
                label: match.home.shortName.toUpperCase(),
                color: homeColor,
                fill: true,
                readout: (value, _) => value.round().toString(),
                values: [for (final play in plays) play.homeScore.toDouble()],
              ),
              ChartSeries(
                label: match.away.shortName.toUpperCase(),
                color: awayColor,
                strokeWidth: 1.8,
                readout: (value, _) => value.round().toString(),
                values: [for (final play in plays) play.awayScore.toDouble()],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const CyberSectionHeading(label: 'SCORING EDGE'),
        const SizedBox(height: 10),
        Row(
          children: [
            CyberMiniMetric(
              label: 'BIGGEST LEAD',
              value: edge.biggestLead == 0
                  ? 'LEVEL'
                  : '${edge.leadIsHome ? match.home.shortName : match.away.shortName} +${edge.biggestLead}',
              accent: edge.biggestLead == 0
                  ? null
                  : (edge.leadIsHome ? homeColor : awayColor),
            ),
            const SizedBox(width: 10),
            CyberMiniMetric(
              label: 'LEAD CHANGES',
              value: '${edge.leadChanges}',
              accent: Cyber.cyan,
            ),
            const SizedBox(width: 10),
            CyberMiniMetric(label: 'TIES', value: '${edge.ties}'),
          ],
        ),
        const SizedBox(height: 14),
        _ScoringMapPanel(
          plays: mapped,
          homeColor: homeColor,
          awayColor: awayColor,
          homeLabel: match.home.shortName.toUpperCase(),
          awayLabel: match.away.shortName.toUpperCase(),
          range: _mapRange,
          ranges: _mapRanges,
          onRangeChanged: (range) => setState(() => _mapRange = range),
        ),
        const SizedBox(height: 18),
        const CyberSectionHeading(label: 'TURNING POINTS'),
        const SizedBox(height: 10),
        for (final point in details.turningPoints) ...[
          StatsRowShell(
            accent: point.homeScore >= point.awayScore ? homeColor : awayColor,
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 52,
                  child: Text(
                    'Q${point.period}\n${point.clock}',
                    style: Cyber.label(8, color: Cyber.muted),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(point.text, style: Cyber.body(12)),
                      const SizedBox(height: 3),
                      Text(
                        '${match.away.shortName} ${point.awayScore} // ${match.home.shortName} ${point.homeScore}',
                        style: Cyber.label(7.5, color: Cyber.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Team code + margin, not an up/down delta: at this moment one
                // side is simply ahead, and colour is what says which.
                if (point.homeScore == point.awayScore)
                  const CyberStatPill(label: 'LEVEL', color: Cyber.muted)
                else
                  CyberStatPill(
                    label: point.homeScore > point.awayScore
                        ? match.home.shortName
                        : match.away.shortName,
                    value:
                        '+${(point.homeScore - point.awayScore).abs()}',
                    color: point.homeScore > point.awayScore
                        ? homeColor
                        : awayColor,
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

/// The court map keeps its own painter — it plots coordinates, not a series —
/// but wears the same panel chrome and range switcher as the line charts.
class _ScoringMapPanel extends StatelessWidget {
  const _ScoringMapPanel({
    required this.plays,
    required this.homeColor,
    required this.awayColor,
    required this.homeLabel,
    required this.awayLabel,
    required this.range,
    required this.ranges,
    required this.onRangeChanged,
  });

  final List<BasketballPlay> plays;
  final Color homeColor;
  final Color awayColor;
  final String homeLabel;
  final String awayLabel;
  final String range;
  final List<String> ranges;
  final ValueChanged<String> onRangeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Cyber.chartSurface,
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SCORING MAP',
                  style: Cyber.label(10, color: Cyber.cyan),
                ),
              ),
              Text(
                '${plays.length} BUCKETS',
                style: Cyber.label(9, color: Cyber.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CyberChartRangeTabs(
            ranges: ranges,
            active: range,
            onChanged: onRangeChanged,
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: _CourtFrame.courtWidthFt / _CourtFrame.courtLengthFt,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  key: const ValueKey('basketball-scoring-map'),
                  painter: BasketballScoringMapPainter(
                    plays: plays,
                    homeColor: homeColor,
                    awayColor: awayColor,
                  ),
                ),
                if (plays.isEmpty)
                  Center(
                    child: Text(
                      'NO PLOTTED SHOTS IN THIS FILTER',
                      style: Cyber.label(8, color: Cyber.muted),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _ScoringMapLegend(
            homeColor: homeColor,
            awayColor: awayColor,
            homeLabel: homeLabel,
            awayLabel: awayLabel,
          ),
          const SizedBox(height: 8),
          Text(
            'COORDINATE-BEARING MADE FIELD GOALS // FREE THROWS EXCLUDED',
            textAlign: TextAlign.center,
            style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 0.7),
          ),
        ],
      ),
    );
  }
}

class _BasketballPlays extends StatelessWidget {
  const _BasketballPlays({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final plays = match.basketballDetails?.plays ?? const <BasketballPlay>[];
    if (plays.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.sports_basketball_outlined,
        title: 'Play feed unavailable',
        message:
            'Scoring actions will appear when the provider publishes them.',
      );
    }
    return CustomScrollView(
      key: const ValueKey('basketball-stats-plays'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _CountStrip(count: plays.length, label: 'SCORING PLAYS'),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          sliver: SliverList.separated(
            itemCount: plays.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final play = plays[index];
              final team = play.isHomeTeam ? match.home : match.away;
              final accent = paletteForTeam(
                team,
                sport: match.sport,
                competition: match.leagueId,
              ).secondaryTextColor;
              return StatsRowShell(
                accent: accent,
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 54,
                      child: Column(
                        children: [
                          Text(
                            'Q${play.period}',
                            style: Cyber.label(8, color: accent),
                          ),
                          Text(play.clock, style: _numberStyle(11)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            play.label.toUpperCase(),
                            style: Cyber.label(8, color: accent),
                          ),
                          const SizedBox(height: 4),
                          Text(play.text, style: Cyber.body(12)),
                          const SizedBox(height: 5),
                          Text(
                            '${match.away.shortName} ${play.awayScore} // ${match.home.shortName} ${play.homeScore}',
                            style: Cyber.label(7.2, color: Cyber.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+${play.points}',
                      style: _numberStyle(13, color: Cyber.gold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BasketballBoxScore extends StatelessWidget {
  const _BasketballBoxScore({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final scorecard = match.basketballScorecard;
    if (scorecard == null) {
      return const CyberNoDataState(
        icon: Icons.table_chart_outlined,
        title: 'Box score unavailable',
        message: 'Player totals have not been published for this fixture.',
      );
    }
    return ListView(
      key: const ValueKey('basketball-stats-box-score'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        BasketballScorecardView(scorecard: scorecard, accent: Cyber.cyan),
      ],
    );
  }
}

class _BasketballTeams extends StatefulWidget {
  const _BasketballTeams({required this.match, required this.enableFeedback});
  final SportMatch match;
  final bool enableFeedback;

  @override
  State<_BasketballTeams> createState() => _BasketballTeamsState();
}

class _BasketballTeamsState extends State<_BasketballTeams> {
  bool _home = true;

  @override
  Widget build(BuildContext context) {
    final details = widget.match.basketballDetails;
    if (details == null || details.teams.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.groups_outlined,
        title: 'Team data unavailable',
        message: 'Roster and availability data have not arrived.',
      );
    }
    final team = details.teams.firstWhere((item) => item.isHome == _home);
    final injuries = details.injuries
        .where((report) => report.teamId == team.id)
        .expand((report) => report.injuries)
        .toList();
    final accent = paletteForTeam(
      _home ? widget.match.home : widget.match.away,
      sport: widget.match.sport,
      competition: widget.match.leagueId,
    ).secondaryTextColor;

    return Column(
      key: const ValueKey('basketball-stats-teams'),
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
              CyberSectionHeading(label: team.name),
              const SizedBox(height: 10),
              StatsRowShell(
                accent: accent,
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    CyberStatPill(
                      label: 'PLAYED',
                      value: '${team.playedCount}',
                      color: accent,
                    ),
                    CyberStatPill(label: 'STARTERS', value: '5', color: accent),
                    CyberStatPill(
                      label: 'BOX SCORE',
                      value: team.boxscoreAvailable ? 'CONFIRMED' : 'PENDING',
                      color: accent,
                    ),
                  ],
                ),
              ),
              if (injuries.isNotEmpty) ...[
                const SizedBox(height: 18),
                const CyberSectionHeading(label: 'AVAILABILITY REPORT'),
                const SizedBox(height: 10),
                StatsRowShell(
                  accent: Cyber.danger,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: injuries
                        .map(
                          (injury) => _InfoLine(
                            label: '${injury.position} // ${injury.status}',
                            value:
                                '${injury.name}${injury.date == null ? '' : ' // ${_shortDate(injury.date!)}'}',
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              const CyberSectionHeading(label: 'ROSTER'),
              const SizedBox(height: 10),
              for (final player in team.players) ...[
                _RosterRow(player: player, accent: accent),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RosterRow extends StatelessWidget {
  const _RosterRow({required this.player, required this.accent});
  final BasketballRosterPlayer player;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return StatsRowShell(
      accent: player.didNotPlay ? Cyber.muted : accent,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              player.jersey.isEmpty ? '—' : '#${player.jersey}',
              style: _numberStyle(11, color: accent),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: Cyber.body(13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.position} // ${player.starter
                      ? 'STARTER'
                      : player.didNotPlay
                      ? 'DNP ${player.reason ?? ''}'
                      : 'ROTATION'}',
                  style: Cyber.label(7.5, color: Cyber.muted),
                ),
              ],
            ),
          ),
          if (!player.didNotPlay)
            Text(
              '${player.points} PTS\n${player.rebounds} REB',
              textAlign: TextAlign.right,
              style: Cyber.label(8, color: accent),
            ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});
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

class _CountStrip extends StatelessWidget {
  const _CountStrip({required this.count, required this.label});
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return StatsRowShell(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          const Icon(Icons.sensors, color: Cyber.cyan, size: 16),
          const SizedBox(width: 8),
          Text('$count', style: _numberStyle(12, color: Cyber.cyan)),
          const SizedBox(width: 6),
          Text(label, style: Cyber.label(8, color: Cyber.muted)),
        ],
      ),
    );
  }
}

/// Key for the plotted markers: which colour is which side, and how a three
/// reads against a two. Sits under the court so the plot stays uncluttered.
class _ScoringMapLegend extends StatelessWidget {
  const _ScoringMapLegend({
    required this.homeColor,
    required this.awayColor,
    required this.homeLabel,
    required this.awayLabel,
  });

  final Color homeColor;
  final Color awayColor;
  final String homeLabel;
  final String awayLabel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        _ScoringMapKey(color: homeColor, label: homeLabel),
        _ScoringMapKey(color: awayColor, label: awayLabel),
        const _ScoringMapKey(color: Cyber.muted, label: '3PT', hollow: true),
      ],
    );
  }
}

class _ScoringMapKey extends StatelessWidget {
  const _ScoringMapKey({
    required this.color,
    required this.label,
    this.hollow = false,
  });

  final Color color;
  final String label;
  final bool hollow;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hollow ? null : color.withValues(alpha: 0.85),
            border: hollow ? Border.all(color: color, width: 1.4) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Cyber.label(8, color: Cyber.muted)),
      ],
    );
  }
}

/// Maps ESPN basketball shot coordinates onto a drawn NBA half court.
///
/// The feed normalises every made field goal onto a single basket: `x` runs
/// 0..50 across the baseline and `y` is the distance out from the rim, so the
/// rim itself is the origin at `(25, 0)`. Keeping the painter in real feet and
/// converting to pixels once is what lets the court furniture (lane, arc,
/// restricted area) line up with the plotted shots.
class _CourtFrame {
  const _CourtFrame(this.rect);

  final Rect rect;

  /// Sideline-to-sideline, in feet.
  static const double courtWidthFt = 50;

  /// The rim sits 5ft 3in inside the floor, so the baseline is behind y = 0.
  static const double baselineFt = -5.25;

  /// Drawn depth. A full half court runs to 41.75ft, but nothing is ever shot
  /// from beyond ~30ft, so the court is cropped past the arc the way broadcast
  /// shot charts crop it — no permanently empty third of the panel.
  static const double frontcourtFt = 34;
  static const double courtLengthFt = frontcourtFt - baselineFt;

  // Court furniture, all in feet from the rim origin.
  static const double laneHalfWidthFt = 8; // 16ft NBA lane
  static const double freeThrowFt = 13.75; // 19ft from the baseline
  static const double freeThrowRadiusFt = 6;
  static const double threePointRadiusFt = 23.75;
  static const double cornerInsetFt =
      3; // corner line sits 3ft off the sideline
  static const double cornerBreakFt = 8.75; // where the corner meets the arc
  static const double restrictedRadiusFt = 4;
  static const double backboardFt = -1.25;
  static const double backboardHalfWidthFt = 3;
  static const double rimRadiusFt = 0.75;

  double dx(double x) => rect.left + rect.width * (x / courtWidthFt);

  double dy(double y) =>
      rect.bottom - rect.height * ((y - baselineFt) / courtLengthFt);

  Offset p(double x, double y) => Offset(dx(x), dy(y));

  /// A feet-space rectangle, given its court-coordinate edges.
  Rect box(double left, double bottom, double right, double top) =>
      Rect.fromLTRB(dx(left), dy(top), dx(right), dy(bottom));

  /// The bounding box of a feet-space circle, ready for [Canvas.drawArc].
  Rect circle(double cx, double cy, double radius) =>
      box(cx - radius, cy - radius, cx + radius, cy + radius);
}

class BasketballScoringMapPainter extends CustomPainter {
  const BasketballScoringMapPainter({
    required this.plays,
    required this.homeColor,
    required this.awayColor,
  });

  final List<BasketballPlay> plays;
  final Color homeColor;
  final Color awayColor;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = _CourtFrame(
      Rect.fromLTWH(2, 2, size.width - 4, size.height - 4),
    );
    _paintCourt(canvas, frame);
    _paintShots(canvas, frame);
  }

  void _paintCourt(Canvas canvas, _CourtFrame f) {
    final floor = Paint()..color = Cyber.bg.withValues(alpha: 0.55);
    final line = Paint()
      ..color = Cyber.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final faintLine = Paint()
      ..color = Cyber.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final laneFill = Paint()..color = Cyber.cyan.withValues(alpha: 0.07);
    final rimPaint = Paint()
      ..color = Cyber.amber.withValues(alpha: 0.75)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // The court is cropped, so the floor and the sidelines fade out at the top
    // rather than ending on a hard edge that would read as a wall.
    final court = f.box(
      0,
      _CourtFrame.baselineFt,
      _CourtFrame.courtWidthFt,
      _CourtFrame.frontcourtFt,
    );
    canvas.drawRect(court, floor);
    final fade = ui.Gradient.linear(
      court.bottomCenter,
      court.topCenter,
      [Cyber.line, Cyber.line, Cyber.line.withValues(alpha: 0)],
      const [0, 0.62, 1],
    );
    final edge = Paint()
      ..shader = fade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(court.bottomLeft, court.topLeft, edge);
    canvas.drawLine(court.bottomRight, court.topRight, edge);
    canvas.drawLine(court.bottomLeft, court.bottomRight, line);

    // Lane, free-throw line and the split free-throw circle.
    final lane = f.box(
      25 - _CourtFrame.laneHalfWidthFt,
      _CourtFrame.baselineFt,
      25 + _CourtFrame.laneHalfWidthFt,
      _CourtFrame.freeThrowFt,
    );
    canvas.drawRect(lane, laneFill);
    canvas.drawRect(lane, line);
    final freeThrowCircle = f.circle(
      25,
      _CourtFrame.freeThrowFt,
      _CourtFrame.freeThrowRadiusFt,
    );
    canvas.drawArc(freeThrowCircle, 0, -math.pi, false, line);
    _drawDashedArc(canvas, freeThrowCircle, 0, math.pi, faintLine);

    // Lane blocks — the hash marks players line up on for a free throw.
    for (final markFt in const [1.75, 2.75, 5.75, 8.75]) {
      for (final side in const [-1.0, 1.0]) {
        final edge = 25 + side * _CourtFrame.laneHalfWidthFt;
        canvas.drawLine(
          f.p(edge, markFt),
          f.p(edge + side * 0.7, markFt),
          faintLine,
        );
      }
    }

    // Three-point line: two corner runs joined by the arc.
    for (final side in const [-1.0, 1.0]) {
      final x = 25 + side * (25 - _CourtFrame.cornerInsetFt);
      canvas.drawLine(
        f.p(x, _CourtFrame.baselineFt),
        f.p(x, _CourtFrame.cornerBreakFt),
        line,
      );
    }
    final breakAngle = math.asin(
      _CourtFrame.cornerBreakFt / _CourtFrame.threePointRadiusFt,
    );
    canvas.drawArc(
      f.circle(25, 0, _CourtFrame.threePointRadiusFt),
      -breakAngle,
      -(math.pi - 2 * breakAngle),
      false,
      line,
    );

    // Restricted area, backboard and rim.
    canvas.drawArc(
      f.circle(25, 0, _CourtFrame.restrictedRadiusFt),
      0,
      -math.pi,
      false,
      faintLine,
    );
    canvas.drawLine(
      f.p(25 - _CourtFrame.backboardHalfWidthFt, _CourtFrame.backboardFt),
      f.p(25 + _CourtFrame.backboardHalfWidthFt, _CourtFrame.backboardFt),
      rimPaint,
    );
    canvas.drawLine(
      f.p(25, _CourtFrame.backboardFt),
      f.p(25, -_CourtFrame.rimRadiusFt),
      rimPaint,
    );
    canvas.drawCircle(
      f.p(25, 0),
      (f.circle(25, 0, _CourtFrame.rimRadiusFt).width / 2).clamp(2.0, 6.0),
      rimPaint,
    );
  }

  void _paintShots(Canvas canvas, _CourtFrame f) {
    // Twos first, so the rarer three-point rings read on top of the cluster.
    final ordered = [
      ...plays.where((play) => play.points != 3),
      ...plays.where((play) => play.points == 3),
    ];
    for (final play in ordered) {
      final coordinate = play.coordinate!;
      final point = f.p(
        coordinate.x.clamp(0.0, _CourtFrame.courtWidthFt),
        coordinate.y.clamp(_CourtFrame.baselineFt, _CourtFrame.frontcourtFt),
      );
      final color = play.isHomeTeam ? homeColor : awayColor;
      if (play.points == 3) {
        canvas.drawCircle(
          point,
          4.4,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
        canvas.drawCircle(
          point,
          1.1,
          Paint()..color = color.withValues(alpha: 0.9),
        );
      } else {
        canvas.drawCircle(
          point,
          3.4,
          Paint()..color = color.withValues(alpha: 0.85),
        );
        canvas.drawCircle(
          point,
          3.4,
          Paint()
            ..color = Cyber.bg.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }
  }

  /// The bottom half of the free-throw circle is dashed on a real floor.
  void _drawDashedArc(
    Canvas canvas,
    Rect bounds,
    double start,
    double sweep,
    Paint paint,
  ) {
    const segments = 9;
    final step = sweep / (segments * 2 - 1);
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(bounds, start + step * i * 2, step, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant BasketballScoringMapPainter oldDelegate) =>
      oldDelegate.plays != plays ||
      oldDelegate.homeColor != homeColor ||
      oldDelegate.awayColor != awayColor;
}

/// Filters the win-probability trace. CLUTCH is the final five minutes of the
/// last regulation quarter — the stretch that decided it.
List<BasketballPlay> _playsForRange(List<BasketballPlay> plays, String range) {
  if (range == 'GAME' || plays.isEmpty) return plays;
  final filtered = switch (range) {
    'H1' => plays.where((play) => play.period <= 2),
    'H2' => plays.where((play) => play.period >= 3),
    'CLUTCH' => plays.where(
      (play) => play.period >= 4 && _clockSeconds(play.clock) <= 300,
    ),
    _ => plays,
  }.toList();
  return filtered.length >= 2 ? filtered : plays;
}

List<BasketballPlay> _mappedPlays(List<BasketballPlay> plays, String range) {
  final mapped = plays.where((play) => play.coordinate != null);
  return switch (range) {
    'HOME' => mapped.where((play) => play.isHomeTeam),
    'AWAY' => mapped.where((play) => !play.isHomeTeam),
    '3PT' => mapped.where((play) => play.points == 3),
    _ => mapped,
  }.toList();
}

/// Lead changes ride the plot as rings in the colour of the team that took the
/// lead. Only the last flip is focal — the one the game never came back from.
List<ChartMarker> _leadChangeMarkers(
  List<BasketballPlay> plays,
  Color homeColor,
  Color awayColor,
) {
  if (plays.length < 2) return const <ChartMarker>[];
  final indices = <int>[];
  var lastLead = 0;
  for (var i = 0; i < plays.length; i++) {
    final lead = (plays[i].homeScore - plays[i].awayScore).sign;
    if (lead == 0) continue;
    if (lastLead != 0 && lead != lastLead) indices.add(i);
    lastLead = lead;
  }
  // A see-saw game flips twenty times, and every ring drawn builds a cage across
  // the plot, so only the closing stretch of flips gets marked.
  final recent = indices.length > 12
      ? indices.sublist(indices.length - 12)
      : indices;
  return [
    for (final index in recent)
      ChartMarker(
        fraction: index / (plays.length - 1),
        color: plays[index].homeScore > plays[index].awayScore
            ? homeColor
            : awayColor,
        shape: ChartMarkerShape.ring,
        alignTop: plays[index].homeScore > plays[index].awayScore,
        focal: index == recent.last,
      ),
  ];
}

/// The axis paints labels at even fractions of the plot, so each one samples the
/// real play sitting at that fraction rather than assuming even quarters.
List<String> _periodLabels(List<BasketballPlay> plays) {
  if (plays.length < 2) return const <String>[];
  return [
    for (var i = 0; i <= 4; i++)
      'Q${plays[((plays.length - 1) * i / 4).round()].period}',
  ];
}

/// One pass over the running scoreboard gives the three numbers that describe a
/// game's shape: how far ahead it ever got, how often the lead flipped, and how
/// often it levelled again.
class _ScoringEdge {
  const _ScoringEdge({
    required this.biggestLead,
    required this.leadIsHome,
    required this.leadChanges,
    required this.ties,
  });

  factory _ScoringEdge.from(List<BasketballPlay> plays) {
    var biggest = 0;
    var leadIsHome = true;
    var changes = 0;
    var ties = 0;
    var previous = 0;
    var lastLead = 0;
    for (final play in plays) {
      final margin = play.homeScore - play.awayScore;
      if (margin.abs() > biggest) {
        biggest = margin.abs();
        leadIsHome = margin > 0;
      }
      final lead = margin.sign;
      if (lead == 0) {
        if (previous != 0) ties++;
      } else {
        if (lastLead != 0 && lead != lastLead) changes++;
        lastLead = lead;
      }
      previous = lead;
    }
    return _ScoringEdge(
      biggestLead: biggest,
      leadIsHome: leadIsHome,
      leadChanges: changes,
      ties: ties,
    );
  }

  final int biggestLead;
  final bool leadIsHome;
  final int leadChanges;
  final int ties;
}

int _clockSeconds(String clock) {
  final parts = clock.split(':');
  if (parts.length != 2) return 0;
  final minutes = int.tryParse(parts.first) ?? 0;
  final seconds = int.tryParse(parts.last) ?? 0;
  return minutes * 60 + seconds;
}

TextStyle _numberStyle(double size, {Color color = Colors.white}) =>
    Cyber.display(
      size,
      color: color,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
String _fallback(String? value) =>
    value == null || value.trim().isEmpty ? 'Unavailable' : value;
String _shortDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
