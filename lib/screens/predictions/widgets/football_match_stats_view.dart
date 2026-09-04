import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/team_palettes.dart';
import '../../../models/football_match_data.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_chart.dart';
import '../../../widgets/cyber/cyber_filter_chips.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_pitch_view.dart';
import 'match_stats_shell.dart';

class FootballMatchStatsView extends StatefulWidget {
  const FootballMatchStatsView({required this.match, super.key});

  final SportMatch match;

  @override
  State<FootballMatchStatsView> createState() => _FootballMatchStatsViewState();
}

class _FootballMatchStatsViewState extends State<FootballMatchStatsView> {
  static const _tabs = <String>[
    'OVERVIEW',
    'MOMENTUM',
    'EVENTS',
    'LINEUPS',
    'COMMENTARY',
  ];

  String _activeTab = _tabs.first;

  void _selectTab(String tab) {
    if (tab == _activeTab) return;
    HapticFeedback.selectionClick();
    setState(() => _activeTab = tab);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CyberFilterChips(
          labels: _tabs,
          selected: _activeTab,
          accent: Cyber.cyan,
          onSelect: _selectTab,
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(_activeTab),
              child: switch (_activeTab) {
                'MOMENTUM' => _MomentumSection(match: widget.match),
                'EVENTS' => _EventsSection(match: widget.match),
                'LINEUPS' => MatchPitchView(match: widget.match),
                'COMMENTARY' => _CommentarySection(match: widget.match),
                _ => _OverviewSection(match: widget.match),
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _OverviewSection extends StatelessWidget {
  const _OverviewSection({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final details = match.footballDetails;
    final stats = match.teamStats ?? const <TeamStatLine>[];
    final pulse = _controlPulse(match, stats);

    return ListView(
      key: const ValueKey('football-stats-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        MatchPulseHeader(
          match: match,
          title: '${match.home.name} vs ${match.away.name}',
          statusLabel: details?.status ?? _statusLabel(match.status),
          heroValue: pulse.value,
          heroLabel: pulse.label,
          heroCaption: pulse.caption,
          heroColor: pulse.color,
          delta: pulse.delta,
          deltaSuffix: 'PRESSURE',
          deltaDecimals: 1,
          subtitle: details?.season ?? 'Live competition feed',
          metrics: [
            CyberMiniMetric(
              label: 'SCORE',
              value:
                  details?.scoreDisplay ??
                  '${match.homeScore ?? '-'} - ${match.awayScore ?? '-'}',
            ),
            CyberMiniMetric(
              label: 'KICKOFF',
              value: _clockLabel(match.kickoff),
            ),
          ],
        ),
        // With no report feed, the channel state is the most useful thing on
        // the page, so it leads rather than trailing the league card.
        if (details == null) ...[
          const SizedBox(height: 18),
          const CyberSectionHeading(label: 'SCOREBOARD CHANNEL'),
          const SizedBox(height: 10),
          _FeedStatePanel(match: match),
        ],
        const SizedBox(height: 18),
        const CyberSectionHeading(label: 'MATCH INTEL'),
        const SizedBox(height: 10),
        _MatchIntelPanel(match: match),
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 18),
          _TeamControlPanel(match: match, stats: stats),
        ],
        if (details?.scorers.isNotEmpty ?? false) ...[
          const SizedBox(height: 18),
          _GoalImpactPanel(match: match, scorers: details!.scorers),
        ],
      ],
    );
  }
}

class _MatchIntelPanel extends StatelessWidget {
  const _MatchIntelPanel({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final details = match.footballDetails;
    final statusColor = switch (match.status) {
      MatchStatus.live => Cyber.danger,
      MatchStatus.finished => Cyber.cyan,
      MatchStatus.upcoming => Cyber.gold,
    };
    final venue = details == null
        ? 'Venue awaiting feed'
        : '${details.venue} // ${details.city}, ${details.country}';
    final attendance = details == null || details.attendance <= 0
        ? '—'
        : _compactNumber(details.attendance);

    return StatsRowShell(
      accent: statusColor,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            details?.league.toUpperCase() ?? match.leagueId.toUpperCase(),
            style: Cyber.display(15, letterSpacing: 0.8),
          ),
          const SizedBox(height: 4),
          Text(
            details?.season ?? 'Live competition feed',
            style: Cyber.body(12, color: Cyber.muted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _IntelCell(
                  icon: Icons.stadium_outlined,
                  label: 'VENUE',
                  value: venue,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: _IntelCell(
                  icon: Icons.groups_outlined,
                  label: 'ATTENDANCE',
                  value: attendance,
                  numeric: true,
                ),
              ),
            ],
          ),
          if (details?.winner != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 16, color: Cyber.cyan),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${details!.winner!.toUpperCase()} SECURED THE RESULT // ${details.scoreDisplay}',
                    style: Cyber.label(
                      9.5,
                      color: Cyber.muted,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedStatePanel extends StatelessWidget {
  const _FeedStatePanel({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return StatsRowShell(
      accent: Cyber.muted,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _feedMessage(match),
            style: Cyber.body(12.5, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          _FeedFact(
            label: 'LAST UPDATED',
            value: _formatFeedDateTime(match.liveLastUpdated),
          ),
          _FeedFact(
            label: 'KICKOFF',
            value: _formatFeedDateTime(match.kickoff),
          ),
        ],
      ),
    );
  }
}

class _FeedFact extends StatelessWidget {
  const _FeedFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 0.8),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: Cyber.body(11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _IntelCell extends StatelessWidget {
  const _IntelCell({
    required this.icon,
    required this.label,
    required this.value,
    this.numeric = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Cyber.panel2.withValues(alpha: 0.56),
        border: Border.all(color: Cyber.line.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Cyber.cyan),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: Cyber.label(
                      8.5,
                      color: Cyber.muted,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style:
                (numeric
                        ? Cyber.display(13, letterSpacing: 0.6)
                        : Cyber.body(11.5, weight: FontWeight.w700))
                    .copyWith(
                      fontFeatures: numeric
                          ? const [FontFeature.tabularFigures()]
                          : null,
                    ),
          ),
        ],
      ),
    );
  }
}

/// TEAM CONTROL as market-style outcome rows — tap one to hold it highlighted.
class _TeamControlPanel extends StatefulWidget {
  const _TeamControlPanel({required this.match, required this.stats});

  final SportMatch match;
  final List<TeamStatLine> stats;

  @override
  State<_TeamControlPanel> createState() => _TeamControlPanelState();
}

class _TeamControlPanelState extends State<_TeamControlPanel> {
  String? _selectedLabel;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSectionHeading(label: 'TEAM CONTROL'),
        const SizedBox(height: 12),
        TeamLegendRow(match: match),
        const SizedBox(height: 12),
        for (final stat in widget.stats) ...[
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

class _GoalImpactPanel extends StatelessWidget {
  const _GoalImpactPanel({required this.match, required this.scorers});

  final SportMatch match;
  final List<FootballScorer> scorers;

  @override
  Widget build(BuildContext context) {
    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSectionHeading(label: 'GOAL IMPACT'),
        const SizedBox(height: 10),
        for (final scorer in scorers) ...[
          StatsRowShell(
            accent: scorer.teamId == match.home.id ? homeColor : awayColor,
            padding: const EdgeInsets.all(12),
            child: _ScorerRow(
              scorer: scorer,
              homeTeamId: match.home.id,
              homeColor: homeColor,
              awayColor: awayColor,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ScorerRow extends StatelessWidget {
  const _ScorerRow({
    required this.scorer,
    required this.homeTeamId,
    required this.homeColor,
    required this.awayColor,
  });

  final FootballScorer scorer;
  final String homeTeamId;
  final Color homeColor;
  final Color awayColor;

  @override
  Widget build(BuildContext context) {
    final isHome = scorer.teamId == homeTeamId;
    final color = isHome ? homeColor : awayColor;
    return Row(
      children: [
        Container(
          width: 44,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            border: Border.all(color: color.withValues(alpha: 0.54)),
          ),
          child: Text(
            scorer.minute,
            style: Cyber.display(
              11,
              color: color,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
        ),
        const SizedBox(width: 10),
        Icon(Icons.sports_soccer, size: 17, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(scorer.name, style: Cyber.body(13, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(
                [
                  scorer.team.toUpperCase(),
                  scorer.type.toUpperCase(),
                  if (scorer.assist != null)
                    'AST ${scorer.assist!.toUpperCase()}',
                ].join(' // '),
                style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.7),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

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

    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;
    final samples = _samplesForRange(momentum, _range);
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

class _EventsSection extends StatelessWidget {
  const _EventsSection({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final events = match.timelineEvents ?? const <MatchEvent>[];
    if (events.isEmpty) {
      return const CyberNoDataState(
        key: ValueKey('football-events-empty'),
        icon: Icons.timeline,
        title: 'Event log pending',
        message: 'Goals, cards and substitutions will be tracked here.',
        accent: Cyber.cyan,
        spark: Icons.sports_soccer,
      );
    }
    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;
    return ListView.separated(
      key: const ValueKey('football-stats-events'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: events.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _LogHeader(
            title: 'MATCH EVENT LOG',
            count: events.length,
            suffix: 'EVENTS',
          );
        }
        return _EventCard(
          event: events[index - 1],
          homeColor: homeColor,
          awayColor: awayColor,
        );
      },
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.homeColor,
    required this.awayColor,
  });

  final MatchEvent event;
  final Color homeColor;
  final Color awayColor;

  @override
  Widget build(BuildContext context) {
    if (_isPeriodMarker(event.type)) {
      return _PeriodMarker(event: event);
    }
    final teamColor = event.isHomeTeam ? homeColor : awayColor;
    final iconColor = switch (event.type) {
      MatchEventType.yellowCard => Cyber.amber,
      MatchEventType.redCard => Cyber.danger,
      MatchEventType.substitution => Cyber.lime,
      _ => teamColor,
    };
    final icon = switch (event.type) {
      MatchEventType.goal => Icons.sports_soccer,
      MatchEventType.yellowCard => Icons.style,
      MatchEventType.redCard => Icons.style,
      MatchEventType.substitution => Icons.swap_horiz,
      _ => Icons.bolt,
    };
    final secondaryPrefix = event.type == MatchEventType.substitution
        ? 'OUT'
        : 'ASSIST';
    return StatsRowShell(
      accent: teamColor,
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: teamColor, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 44,
                child: Text(
                  event.minuteLabel,
                  style: Cyber.display(12, color: teamColor).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.11),
                  border: Border.all(color: iconColor.withValues(alpha: 0.45)),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (event.playerName.isEmpty
                                    ? event.label ?? 'MATCH EVENT'
                                    : event.playerName)
                                .toUpperCase(),
                            style: Cyber.display(11.5, letterSpacing: 0.5),
                          ),
                        ),
                        if (event.scoreDisplay != null)
                          Text(
                            event.scoreDisplay!,
                            style: Cyber.display(11, color: Cyber.cyan)
                                .copyWith(
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (event.teamName != null)
                          event.teamName!.toUpperCase(),
                        if (event.label != null) event.label!.toUpperCase(),
                        if (event.secondaryPlayerName != null)
                          '$secondaryPrefix ${event.secondaryPlayerName!.toUpperCase()}',
                      ].join(' // '),
                      style: Cyber.label(
                        8,
                        color: Cyber.muted,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (event.description != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        event.description!,
                        style: Cyber.body(11.5, color: Cyber.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PeriodMarker extends StatelessWidget {
  const _PeriodMarker({required this.event});

  final MatchEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: Cyber.cyan.withValues(alpha: 0.24))),
        const SizedBox(width: 10),
        Icon(Icons.adjust, size: 12, color: Cyber.cyan),
        const SizedBox(width: 7),
        Text(
          '${event.label ?? _eventLabel(event.type)} ${event.scoreDisplay ?? ''}'
              .trim()
              .toUpperCase(),
          style: Cyber.label(9, color: Cyber.cyan, letterSpacing: 1),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: Cyber.cyan.withValues(alpha: 0.24))),
      ],
    );
  }
}

class _CommentarySection extends StatelessWidget {
  const _CommentarySection({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final commentary = match.commentary ?? const <MatchCommentary>[];
    if (commentary.isEmpty) {
      return const CyberNoDataState(
        key: ValueKey('football-commentary-empty'),
        icon: Icons.mic_none,
        title: 'Match comms silent',
        message: 'The play-by-play channel opens once commentary is available.',
        accent: Cyber.cyan,
        spark: Icons.graphic_eq,
      );
    }
    return CustomScrollView(
      key: const ValueKey('football-stats-commentary'),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _LogHeader(
              title: 'LIVE MATCH COMMS',
              count: commentary.length,
              suffix: 'ENTRIES',
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList.separated(
            itemCount: commentary.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _CommentaryCard(
              item: commentary[index],
              fallbackSequence: index,
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentaryCard extends StatelessWidget {
  const _CommentaryCard({required this.item, required this.fallbackSequence});

  final MatchCommentary item;
  final int fallbackSequence;

  @override
  Widget build(BuildContext context) {
    final sequence = item.sequence ?? fallbackSequence;
    return StatsRowShell(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 48,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.minute.isEmpty ? '—' : item.minute,
                  style: Cyber.display(11, color: Cyber.cyan).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'SEQ ${sequence.toString().padLeft(3, '0')}',
                  style: Cyber.label(
                    7.5,
                    color: Cyber.muted,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 42,
            color: Cyber.line.withValues(alpha: 0.22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.teamName != null || item.kind != null) ...[
                  Text(
                    [
                      if (item.teamName != null) item.teamName!.toUpperCase(),
                      if (item.kind != null) item.kind!.toUpperCase(),
                    ].join(' // '),
                    style: Cyber.label(
                      8,
                      color: Cyber.cyan,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 5),
                ],
                Text(item.text, style: Cyber.body(12, color: Cyber.muted)),
                if (item.players.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'PLAYERS // ${item.players.join(' · ')}',
                    style: Cyber.label(
                      7.5,
                      color: Cyber.muted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogHeader extends StatelessWidget {
  const _LogHeader({
    required this.title,
    required this.count,
    required this.suffix,
  });

  final String title;
  final int count;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return CyberSectionHeading(
      label: title,
      trailing: Text(
        '${count.toString().padLeft(3, '0')} $suffix',
        style: Cyber.label(
          8.5,
          color: Cyber.muted,
          letterSpacing: 0.8,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Football's hero number is territorial control — the leading side's share of
/// the headline possession metric, with live pressure as the movement.
({String value, String label, String caption, Color color, double? delta})
_controlPulse(SportMatch match, List<TeamStatLine> stats) {
  final momentum = match.footballMomentum;
  final control = stats
      .where(
        (stat) =>
            stat.label.toLowerCase().contains('possession') ||
            stat.label.toLowerCase().contains('control'),
      )
      .firstOrNull;
  final stat = control ?? (stats.isEmpty ? null : stats.first);
  if (stat == null) {
    return (
      value: '—',
      label: match.home.name,
      caption: 'MATCH CONTROL',
      color: Cyber.muted,
      delta: null,
    );
  }
  final homeLeads = stat.homeShare >= 0.5;
  final leader = homeLeads ? match.home : match.away;
  final display = homeLeads ? stat.homeDisplay : stat.awayDisplay;

  double? delta;
  if (momentum != null && momentum.series.length >= 2) {
    final window = momentum.series.length < 10
        ? momentum.series
        : momentum.series.sublist(momentum.series.length - 10);
    var total = 0.0;
    for (final point in window) {
      total += point.value;
    }
    final average = total / window.length;
    delta = homeLeads ? average : -average;
  }

  return (
    value: display,
    label: leader.name,
    caption: stat.label.toUpperCase(),
    color: paletteForTeam(leader, sport: match.sport).primary,
    delta: delta,
  );
}

bool _isPeriodMarker(MatchEventType type) => switch (type) {
  MatchEventType.kickoff ||
  MatchEventType.halftime ||
  MatchEventType.secondHalf ||
  MatchEventType.fullTime => true,
  _ => false,
};

String _eventLabel(MatchEventType type) => switch (type) {
  MatchEventType.kickoff => 'Kickoff',
  MatchEventType.halftime => 'Halftime',
  MatchEventType.secondHalf => 'Second half',
  MatchEventType.fullTime => 'Full time',
  MatchEventType.goal => 'Goal',
  MatchEventType.yellowCard => 'Yellow card',
  MatchEventType.redCard => 'Red card',
  MatchEventType.substitution => 'Substitution',
};

String _statusLabel(MatchStatus status) => switch (status) {
  MatchStatus.upcoming => 'Pre-match',
  MatchStatus.live => 'Live now',
  MatchStatus.finished => 'Full time',
};

String _feedMessage(SportMatch match) {
  final note = match.liveStatusNote?.trim();
  if (note != null && note.isNotEmpty) return note;
  return switch (match.status) {
    MatchStatus.upcoming => 'Scoreboard opens when the match starts.',
    MatchStatus.live =>
      match.liveMinute == null
          ? 'Live match data is active.'
          : 'Live clock: ${match.liveMinute} minutes.',
    MatchStatus.finished =>
      match.resultLine?.trim().isNotEmpty == true
          ? match.resultLine!.trim()
          : 'Final score has been recorded.',
  };
}

String _formatFeedDateTime(DateTime? value) {
  if (value == null) return 'Unavailable';
  final local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

String _clockLabel(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

String _compactNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
