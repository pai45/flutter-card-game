import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/team_palettes.dart';
import '../../../models/football_match_data.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_filter_chips.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/match_pitch_view.dart';

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
    return ListView(
      key: const ValueKey('football-stats-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _MatchIntelPanel(match: match),
        if (details == null) ...[
          const SizedBox(height: 12),
          _FeedStatePanel(match: match),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: 12),
          _TeamControlPanel(match: match, stats: stats),
        ],
        if (details?.scorers.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
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

    return _HudPanel(
      title: 'MATCH INTEL',
      code: 'SYS://FOOTBALL/REPORT',
      accent: statusColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      details?.league.toUpperCase() ??
                          match.leagueId.toUpperCase(),
                      style: Cyber.display(15, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      details?.season ?? 'Live competition feed',
                      style: Cyber.body(12, color: Cyber.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPlate(
                label: details?.status ?? _statusLabel(match.status),
                color: statusColor,
                live: match.status == MatchStatus.live,
              ),
            ],
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
    return _HudPanel(
      title: 'SCOREBOARD CHANNEL',
      code: 'FEED://MATCH/STATE',
      accent: Cyber.muted,
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

class _StatusPlate extends StatelessWidget {
  const _StatusPlate({
    required this.label,
    required this.color,
    required this.live,
  });

  final String label;
  final Color color;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.62)),
        boxShadow: live ? Cyber.glow(color, alpha: 0.28, blur: 10) : null,
      ),
      child: Text(
        label.toUpperCase(),
        style: Cyber.label(9, color: color, letterSpacing: 1.1),
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

class _TeamControlPanel extends StatelessWidget {
  const _TeamControlPanel({required this.match, required this.stats});

  final SportMatch match;
  final List<TeamStatLine> stats;

  @override
  Widget build(BuildContext context) {
    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;
    return _HudPanel(
      title: 'TEAM CONTROL',
      code: 'FEED://${stats.length.toString().padLeft(2, '0')}/METRICS',
      child: Column(
        children: [
          Row(
            children: [
              _TeamLegend(
                color: homeColor,
                code: match.home.shortName,
                name: match.home.name,
              ),
              const Spacer(),
              _TeamLegend(
                color: awayColor,
                code: match.away.shortName,
                name: match.away.name,
                alignEnd: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < stats.length; index++) ...[
            _StatComparisonRow(
              stat: stats[index],
              homeColor: homeColor,
              awayColor: awayColor,
            ),
            if (index != stats.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _TeamLegend extends StatelessWidget {
  const _TeamLegend({
    required this.color,
    required this.code,
    required this.name,
    this.alignEnd = false,
  });

  final Color color;
  final String code;
  final String name;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final swatch = Container(width: 4, height: 30, color: color);
    final copy = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(code.toUpperCase(), style: Cyber.display(13, color: color)),
        Text(
          name.toUpperCase(),
          style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.8),
        ),
      ],
    );
    return Row(
      children: alignEnd
          ? [copy, const SizedBox(width: 8), swatch]
          : [swatch, const SizedBox(width: 8), copy],
    );
  }
}

class _StatComparisonRow extends StatelessWidget {
  const _StatComparisonRow({
    required this.stat,
    required this.homeColor,
    required this.awayColor,
  });

  final TeamStatLine stat;
  final Color homeColor;
  final Color awayColor;

  @override
  Widget build(BuildContext context) {
    final homeFlex = (stat.homeShare * 1000).round().clamp(5, 995);
    final valueStyle = Cyber.display(
      14,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
    return Column(
      children: [
        Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(stat.homeDisplay, style: valueStyle),
            ),
            Expanded(
              child: Text(
                stat.label.toUpperCase(),
                textAlign: TextAlign.center,
                style: Cyber.label(9, color: Cyber.muted, letterSpacing: 1),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                stat.awayDisplay,
                textAlign: TextAlign.end,
                style: valueStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 6,
          child: Row(
            children: [
              Expanded(
                flex: homeFlex,
                child: ColoredBox(color: homeColor),
              ),
              const SizedBox(width: 3),
              Expanded(
                flex: 1000 - homeFlex,
                child: ColoredBox(color: awayColor),
              ),
            ],
          ),
        ),
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
    return _HudPanel(
      title: 'GOAL IMPACT',
      code: 'LOG://${scorers.length.toString().padLeft(2, '0')}/STRIKES',
      accent: Cyber.cyan,
      child: Column(
        children: [
          for (var index = 0; index < scorers.length; index++) ...[
            _ScorerRow(
              scorer: scorers[index],
              homeTeamId: match.home.id,
              homeColor: homeColor,
              awayColor: awayColor,
            ),
            if (index != scorers.length - 1)
              Divider(color: Cyber.line.withValues(alpha: 0.16), height: 20),
          ],
        ],
      ),
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

class _MomentumSection extends StatelessWidget {
  const _MomentumSection({required this.match});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
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
    final homePeak = momentum.homePeak!;
    final awayPeak = momentum.awayPeak!;
    return ListView(
      key: const ValueKey('football-stats-momentum'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _HudPanel(
          title: 'MATCH MOMENTUM',
          code: 'TRACE://${momentum.series.length}/SAMPLES',
          accent: Cyber.cyan,
          glow: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _PressureLegend(
                    label: match.home.shortName,
                    side: 'HOME PRESSURE',
                    color: homeColor,
                  ),
                  const Spacer(),
                  _PressureLegend(
                    label: match.away.shortName,
                    side: 'AWAY PRESSURE',
                    color: awayColor,
                    alignEnd: true,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                key: const ValueKey('football-momentum-graph'),
                height: 250,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, progress, _) => CustomPaint(
                    painter: FootballMomentumPainter(
                      momentum: momentum,
                      homeColor: homeColor,
                      awayColor: awayColor,
                      progress: progress,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'GOAL IMPACT MARKERS',
                style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.1),
              ),
              const SizedBox(height: 8),
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
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PeakPressureCard(
                label: match.home.shortName,
                minute: homePeak.minute,
                value: homePeak.value.abs(),
                color: homeColor,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PeakPressureCard(
                label: match.away.shortName,
                minute: awayPeak.minute,
                value: awayPeak.value.abs(),
                color: awayColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PressureLegend extends StatelessWidget {
  const _PressureLegend({
    required this.label,
    required this.side,
    required this.color,
    this.alignEnd = false,
  });

  final String label;
  final String side;
  final Color color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: Cyber.display(14, color: color)),
        Text(
          side,
          style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.8),
        ),
      ],
    );
  }
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

class _PeakPressureCard extends StatelessWidget {
  const _PeakPressureCard({
    required this.label,
    required this.minute,
    required this.value,
    required this.color,
  });

  final String label;
  final int minute;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: color,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label PEAK'.toUpperCase(),
            style: Cyber.label(8.5, color: color, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            value.toStringAsFixed(1),
            style: Cyber.display(
              20,
            ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          Text(
            "PRESSURE // $minute'",
            style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.8),
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
    return ClipPath(
      clipper: CyberClipper(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border(left: BorderSide(color: teamColor, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                event.minuteLabel,
                style: Cyber.display(
                  12,
                  color: teamColor,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
                          style: Cyber.display(11, color: Cyber.cyan).copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (event.teamName != null) event.teamName!.toUpperCase(),
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
    return ClipPath(
      clipper: CyberClipper(),
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Cyber.panel,
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
    return CyberPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.sensors, size: 16, color: Cyber.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, style: Cyber.display(12, letterSpacing: 0.7)),
          ),
          Text(
            '${count.toString().padLeft(3, '0')} $suffix',
            style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}

class _HudPanel extends StatelessWidget {
  const _HudPanel({
    required this.title,
    required this.code,
    required this.child,
    this.accent = Cyber.cyan,
    this.glow = false,
  });

  final String title;
  final String code;
  final Widget child;
  final Color accent;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: accent,
      glow: glow,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(width: 18, height: 2, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Cyber.label(10, color: accent, letterSpacing: 1.3),
                ),
              ),
              Text(
                code,
                style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 0.6),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class FootballMomentumPainter extends CustomPainter {
  const FootballMomentumPainter({
    required this.momentum,
    required this.homeColor,
    required this.awayColor,
    required this.progress,
  });

  final FootballMomentum momentum;
  final Color homeColor;
  final Color awayColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const topInset = 22.0;
    const bottomInset = 24.0;
    final graphRect = Rect.fromLTRB(
      0,
      topInset,
      size.width,
      size.height - bottomInset,
    );
    final baseline = graphRect.center.dy;
    final maxAxis = math.max(1, momentum.totalMinutes);
    final revealX = graphRect.left + graphRect.width * progress;

    final gridPaint = Paint()
      ..color = Cyber.line.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    for (final factor in <double>[0, 0.25, 0.5, 0.75, 1]) {
      final y = graphRect.top + graphRect.height * factor;
      canvas.drawLine(
        Offset(graphRect.left, y),
        Offset(graphRect.right, y),
        gridPaint,
      );
    }
    canvas.drawLine(
      Offset(graphRect.left, baseline),
      Offset(graphRect.right, baseline),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.38)
        ..strokeWidth = 1.2,
    );

    final halftimeX =
        graphRect.left +
        graphRect.width * (momentum.halftimeMinute / maxAxis).clamp(0, 1);
    final halfPaint = Paint()
      ..color = Cyber.line.withValues(alpha: 0.42)
      ..strokeWidth = 1;
    for (double y = graphRect.top; y < graphRect.bottom; y += 7) {
      canvas.drawLine(
        Offset(halftimeX, y),
        Offset(halftimeX, math.min(y + 3, graphRect.bottom)),
        halfPaint,
      );
    }

    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(graphRect.left, graphRect.top, revealX, graphRect.bottom),
    );
    Offset? previous;
    for (final point in momentum.series) {
      final x =
          graphRect.left +
          graphRect.width * (point.minute / maxAxis).clamp(0, 1);
      final signed = point.value.clamp(-100.0, 100.0);
      final y = baseline - signed / 100 * graphRect.height * 0.46;
      final color = signed >= 0 ? homeColor : awayColor;
      canvas.drawLine(
        Offset(x, baseline),
        Offset(x, y),
        Paint()
          ..color = color.withValues(alpha: 0.22)
          ..strokeWidth = math.max(
            2,
            graphRect.width / momentum.series.length * 0.72,
          ),
      );
      if (previous != null) {
        canvas.drawLine(
          previous,
          Offset(x, y),
          Paint()
            ..color = color.withValues(alpha: 0.22)
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
        canvas.drawLine(
          previous,
          Offset(x, y),
          Paint()
            ..color = color.withValues(alpha: 0.88)
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      }
      previous = Offset(x, y);
    }

    for (final goal in momentum.goals) {
      final x =
          graphRect.left + graphRect.width * (goal.axis / maxAxis).clamp(0, 1);
      final color = goal.isHomeTeam ? homeColor : awayColor;
      canvas.drawLine(
        Offset(x, graphRect.top),
        Offset(x, graphRect.bottom),
        Paint()
          ..color = color.withValues(alpha: 0.34)
          ..strokeWidth = 1,
      );
      final markerY = goal.isHomeTeam
          ? graphRect.top + 8
          : graphRect.bottom - 8;
      canvas.drawCircle(Offset(x, markerY), 5, Paint()..color = color);
      canvas.drawCircle(
        Offset(x, markerY),
        8,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.48),
      );
    }
    canvas.restore();

    _paintLabel(canvas, 'HOME +', Offset(graphRect.left, 0), homeColor);
    _paintLabel(
      canvas,
      'AWAY −',
      Offset(graphRect.left, graphRect.bottom + 7),
      awayColor,
    );
    _paintAxisLabel(canvas, "0'", graphRect.left, graphRect.bottom + 7);
    _paintAxisLabel(
      canvas,
      'HT',
      halftimeX,
      graphRect.bottom + 7,
      centered: true,
    );
    _paintAxisLabel(
      canvas,
      "${momentum.totalMinutes}'",
      graphRect.right,
      graphRect.bottom + 7,
      alignEnd: true,
    );
  }

  void _paintLabel(Canvas canvas, String text, Offset offset, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: Cyber.label(7.5, color: color, letterSpacing: 0.8),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  void _paintAxisLabel(
    Canvas canvas,
    String text,
    double x,
    double y, {
    bool centered = false,
    bool alignEnd = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 0.5),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignEnd
        ? x - painter.width
        : centered
        ? x - painter.width / 2
        : x;
    painter.paint(canvas, Offset(dx, y));
  }

  @override
  bool shouldRepaint(covariant FootballMomentumPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.momentum != momentum ||
      oldDelegate.homeColor != homeColor ||
      oldDelegate.awayColor != awayColor;
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

String _compactNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(',');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
