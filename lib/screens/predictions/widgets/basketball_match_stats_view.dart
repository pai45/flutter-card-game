import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/team_palettes.dart';
import '../../../models/basketball_match_data.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/basketball_scorecard_view.dart';
import '../../../widgets/cyber/cyber_filter_chips.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

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
        CyberHudPanel(
          title: 'Game Intel',
          code: 'SYS://HOOPS/REPORT',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                details?.league.toUpperCase() ?? match.leagueId.toUpperCase(),
                style: Cyber.display(15, letterSpacing: 0.8),
              ),
              const SizedBox(height: 4),
              Text(
                details == null
                    ? _stateMessage(match)
                    : '${details.gameNote} // ${details.season}',
                style: Cyber.body(12, color: Cyber.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TelemetryChip(
                    label: 'STATUS',
                    value: details?.status ?? _status(match.status),
                  ),
                  _TelemetryChip(
                    label: 'BROADCAST',
                    value: _fallback(details?.broadcast),
                  ),
                  _TelemetryChip(
                    label: 'ATTENDANCE',
                    value: details == null || details.attendance <= 0
                        ? 'Unavailable'
                        : _commas(details.attendance),
                  ),
                  _TelemetryChip(
                    label: 'FORMAT',
                    value: details?.overtime == true
                        ? 'OVERTIME'
                        : 'REGULATION',
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          _QuarterPanel(match: match),
        ],
        if (details?.series.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          CyberHudPanel(
            title: 'Series Signal',
            code: 'BRACKET://FINALS',
            accent: Cyber.gold,
            child: Column(
              children: details!.series
                  .map(
                    (item) => _InfoLine(
                      label: item.title,
                      value:
                          '${item.description} // ${item.summary} // ${item.completed ? 'COMPLETE' : 'ACTIVE'}',
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
        if (match.teamStats?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          _BasketballStatPanel(match: match),
        ],
        if (details?.leaders.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          _LeaderPanel(match: match, groups: details!.leaders),
        ],
        if (details?.officials.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          CyberHudPanel(
            title: 'Officials',
            code:
                'CREW://${details!.officials.length.toString().padLeft(2, '0')}',
            child: Column(
              children: details.officials
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
    return CyberHudPanel(
      title: 'Quarter Grid',
      code: 'SCORE://PERIODS',
      accent: Cyber.magenta,
      child: Column(
        children: [
          _QuarterRow(
            label: match.away.shortName,
            values: lines.awayScores,
            total: lines.awayTotal,
            accent: paletteForTeam(match.away, sport: match.sport).primary,
          ),
          const HudLine(),
          _QuarterRow(
            label: match.home.shortName,
            values: lines.homeScores,
            total: lines.homeTotal,
            accent: paletteForTeam(match.home, sport: match.sport).primary,
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

class _BasketballStatPanel extends StatelessWidget {
  const _BasketballStatPanel({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;
    return CyberHudPanel(
      title: 'Team Control',
      code: 'COMPARE://${match.teamStats!.length.toString().padLeft(2, '0')}',
      child: Column(
        children: match.teamStats!.map((stat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 58,
                      child: Text(
                        stat.homeDisplay,
                        style: _numberStyle(11, color: homeColor),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        stat.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: Cyber.label(8, color: Cyber.muted),
                      ),
                    ),
                    SizedBox(
                      width: 58,
                      child: Text(
                        stat.awayDisplay,
                        textAlign: TextAlign.right,
                        style: _numberStyle(11, color: awayColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      flex: (stat.homeShare * 100).round().clamp(1, 99),
                      child: Container(height: 3, color: homeColor),
                    ),
                    const SizedBox(width: 2),
                    Expanded(
                      flex: ((1 - stat.homeShare) * 100).round().clamp(1, 99),
                      child: Container(height: 3, color: awayColor),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _LeaderPanel extends StatelessWidget {
  const _LeaderPanel({required this.match, required this.groups});
  final SportMatch match;
  final List<BasketballLeaderGroup> groups;

  @override
  Widget build(BuildContext context) {
    return CyberHudPanel(
      title: 'Impact Leaders',
      code: 'LEADERS://06',
      accent: Cyber.gold,
      child: Column(
        children: groups.map((group) {
          final isHome = group.teamId == match.home.id;
          final accent = paletteForTeam(
            isHome ? match.home : match.away,
            sport: match.sport,
          ).primary;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
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
        }).toList(),
      ),
    );
  }
}

class _BasketballFlow extends StatelessWidget {
  const _BasketballFlow({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final details = match.basketballDetails;
    if (details == null || details.plays.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.show_chart,
        title: 'Flow feed unavailable',
        message: 'Win probability and scoring coordinates have not arrived.',
      );
    }
    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;
    final mapped = details.plays
        .where((play) => play.coordinate != null)
        .toList();
    return ListView(
      key: const ValueKey('basketball-stats-flow'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 760),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => CyberHudPanel(
            title: 'Win Probability',
            code: 'FLOW://${details.plays.length.toString().padLeft(3, '0')}',
            glow: progress < 1,
            child: SizedBox(
              height: 220,
              child: CustomPaint(
                key: const ValueKey('basketball-win-probability-graph'),
                painter: BasketballWinProbabilityPainter(
                  plays: details.plays,
                  homeColor: homeColor,
                  awayColor: awayColor,
                  progress: progress,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        CyberHudPanel(
          title: 'Scoring Map',
          code: 'COURT://${mapped.length.toString().padLeft(2, '0')}',
          accent: Cyber.magenta,
          child: Column(
            children: [
              SizedBox(
                height: 230,
                child: CustomPaint(
                  key: const ValueKey('basketball-scoring-map'),
                  painter: BasketballScoringMapPainter(
                    plays: mapped,
                    homeColor: homeColor,
                    awayColor: awayColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'COORDINATE-BEARING MADE FIELD GOALS // FREE THROWS EXCLUDED',
                textAlign: TextAlign.center,
                style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 0.7),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        CyberHudPanel(
          title: 'Turning Points',
          code:
              'SWINGS://${details.turningPoints.length.toString().padLeft(2, '0')}',
          accent: Cyber.gold,
          child: Column(
            children: details.turningPoints.map((point) {
              final positive = point.swing >= 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 56,
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
                            '${point.awayScore}-${point.homeScore} // HOME ${(point.homeWinPercentage * 100).toStringAsFixed(1)}%',
                            style: Cyber.label(7.5, color: Cyber.muted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${positive ? '+' : ''}${(point.swing * 100).toStringAsFixed(1)}',
                      style: _numberStyle(
                        10,
                        color: positive ? Cyber.success : Cyber.danger,
                      ),
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
              final accent = paletteForTeam(team, sport: match.sport).primary;
              return CyberPanel(
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
                            '${match.away.shortName} ${play.awayScore} // ${match.home.shortName} ${play.homeScore}  •  HOME ${(play.homeWinPercentage * 100).toStringAsFixed(1)}% // SWING ${play.swing >= 0 ? '+' : ''}${(play.swing * 100).toStringAsFixed(1)}',
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
    ).primary;
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
              CyberHudPanel(
                title: team.name,
                code: 'ROSTER://${team.playerCount}',
                accent: accent,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _TelemetryChip(
                      label: 'PLAYED',
                      value: '${team.playedCount}',
                    ),
                    _TelemetryChip(label: 'STARTERS', value: '5'),
                    _TelemetryChip(
                      label: 'BOX SCORE',
                      value: team.boxscoreAvailable ? 'CONFIRMED' : 'PENDING',
                    ),
                  ],
                ),
              ),
              if (injuries.isNotEmpty) ...[
                const SizedBox(height: 12),
                CyberHudPanel(
                  title: 'Availability Report',
                  code: 'MED://${injuries.length.toString().padLeft(2, '0')}',
                  accent: Cyber.danger,
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
              const SizedBox(height: 12),
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
    return CyberPanel(
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

class _TelemetryChip extends StatelessWidget {
  const _TelemetryChip({required this.label, required this.value});
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
          Text(value.toUpperCase(), style: _numberStyle(9.5)),
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
    return CyberPanel(
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

class BasketballWinProbabilityPainter extends CustomPainter {
  const BasketballWinProbabilityPainter({
    required this.plays,
    required this.homeColor,
    required this.awayColor,
    required this.progress,
  });
  final List<BasketballPlay> plays;
  final Color homeColor;
  final Color awayColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (plays.length < 2) return;
    final rect = Rect.fromLTRB(8, 18, size.width - 8, size.height - 24);
    final grid = Paint()..color = Cyber.line.withValues(alpha: 0.55);
    for (final fraction in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = rect.bottom - rect.height * fraction;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    for (var quarter = 1; quarter < 4; quarter++) {
      final first = plays.indexWhere((play) => play.period == quarter + 1);
      if (first < 0) continue;
      final x = rect.left + rect.width * first / (plays.length - 1);
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), grid);
      final text = TextPainter(
        text: TextSpan(
          text: 'Q${quarter + 1}',
          style: Cyber.label(7, color: Cyber.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(x + 3, 2));
    }
    final revealCount = math.max(2, (plays.length * progress).ceil());
    final homePath = Path();
    final awayPath = Path();
    for (var index = 0; index < revealCount; index++) {
      final play = plays[index.clamp(0, plays.length - 1)];
      final x = rect.left + rect.width * index / (plays.length - 1);
      final homeY =
          rect.bottom - rect.height * play.homeWinPercentage.clamp(0, 1);
      final awayY =
          rect.bottom - rect.height * (1 - play.homeWinPercentage).clamp(0, 1);
      if (index == 0) {
        homePath.moveTo(x, homeY);
        awayPath.moveTo(x, awayY);
      } else {
        homePath.lineTo(x, homeY);
        awayPath.lineTo(x, awayY);
      }
    }
    canvas.drawPath(
      homePath,
      Paint()
        ..color = homeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawPath(
      awayPath,
      Paint()
        ..color = awayColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final mid = TextPainter(
      text: TextSpan(
        text: '50%',
        style: Cyber.label(7, color: Cyber.muted),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    mid.paint(canvas, Offset(rect.left, rect.center.dy - 12));
  }

  @override
  bool shouldRepaint(covariant BasketballWinProbabilityPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.plays != plays;
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
    final line = Paint()
      ..color = Cyber.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final court = Rect.fromLTWH(5, 5, size.width - 10, size.height - 10);
    canvas.drawRect(court, line);
    canvas.drawLine(
      Offset(court.center.dx, court.top),
      Offset(court.center.dx, court.bottom),
      line,
    );
    canvas.drawCircle(court.center, 24, line);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(court.left + 28, court.center.dy),
        width: 46,
        height: 76,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(court.right - 28, court.center.dy),
        width: 46,
        height: 76,
      ),
      line,
    );
    for (final play in plays) {
      final coordinate = play.coordinate!;
      final normalizedX = (coordinate.x / 100).clamp(0.0, 1.0);
      final normalizedY = (coordinate.y / 50).clamp(0.0, 1.0);
      final point = Offset(
        court.left + court.width * normalizedX,
        court.top + court.height * normalizedY,
      );
      canvas.drawCircle(
        point,
        play.points == 3 ? 4 : 3,
        Paint()
          ..color = (play.isHomeTeam ? homeColor : awayColor).withValues(
            alpha: 0.82,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BasketballScoringMapPainter oldDelegate) =>
      oldDelegate.plays != plays;
}

TextStyle _numberStyle(double size, {Color color = Colors.white}) =>
    Cyber.display(
      size,
      color: color,
    ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
String _fallback(String? value) =>
    value == null || value.trim().isEmpty ? 'Unavailable' : value;
String _status(MatchStatus status) => switch (status) {
  MatchStatus.upcoming => 'Pre-match',
  MatchStatus.live => 'Live now',
  MatchStatus.finished => 'Final',
};
String _stateMessage(SportMatch match) =>
    match.liveStatusNote ??
    switch (match.status) {
      MatchStatus.upcoming => 'Scoreboard opens when the match starts.',
      MatchStatus.live =>
        match.liveMinute == null
            ? 'Live game data is active.'
            : 'Live clock: ${match.liveMinute} minutes.',
      MatchStatus.finished =>
        match.resultLine ?? 'Final score has been recorded.',
    };
String _commas(int value) {
  final digits = value.toString();
  final output = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) output.write(',');
    output.write(digits[index]);
  }
  return output.toString();
}

String _shortDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}';
}
