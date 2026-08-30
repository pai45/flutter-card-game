import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../data/team_palettes.dart';
import '../../../models/cricket_match_data.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cricket_scorecard_view.dart';
import '../../../widgets/cyber/cyber_filter_chips.dart';
import '../../../widgets/cyber/cyber_widgets.dart';

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
    return ListView(
      key: const ValueKey('cricket-stats-overview'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        CyberHudPanel(
          title: 'Match Intel',
          code: 'SYS://CRICKET/REPORT',
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
                    ? _cricketStateMessage(match)
                    : '${details.stage} // ${details.formatName} // ${details.season}',
                style: Cyber.body(12, color: Cyber.muted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CricketChip(
                    label: 'STATUS',
                    value: details?.status ?? _matchStatus(match.status),
                  ),
                  _CricketChip(label: 'FORMAT', value: details?.format ?? '—'),
                  _CricketChip(
                    label: 'SITE',
                    value: details?.neutralSite == true ? 'NEUTRAL' : 'HOME',
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
          const SizedBox(height: 12),
          CyberHudPanel(
            title: 'Final Result',
            code: 'RESULT://LOCKED',
            accent: Cyber.success,
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
          const SizedBox(height: 12),
          _InningsSummaryPanel(match: match, innings: details!.innings),
        ],
        if (match.teamStats?.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          _CricketStatsPanel(match: match),
        ],
        if (details?.awards.isNotEmpty ?? false) ...[
          const SizedBox(height: 12),
          CyberHudPanel(
            title: 'Honours',
            code:
                'AWARDS://${details!.awards.length.toString().padLeft(2, '0')}',
            accent: Cyber.gold,
            child: Column(
              children: details.awards
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
          const SizedBox(height: 12),
          CyberHudPanel(
            title: 'Officials',
            code:
                'CREW://${details!.officials.length.toString().padLeft(2, '0')}',
            child: Column(
              children: details.officials
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
    return CyberHudPanel(
      title: 'Innings Grid',
      code: 'INNINGS://${innings.length.toString().padLeft(2, '0')}',
      accent: Cyber.magenta,
      child: Column(
        children: innings.map((item) {
          final team = item.teamId == match.home.id ? match.home : match.away;
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
    );
  }
}

class _CricketStatsPanel extends StatelessWidget {
  const _CricketStatsPanel({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final homeColor = paletteForTeam(match.home, sport: match.sport).primary;
    final awayColor = paletteForTeam(match.away, sport: match.sport).primary;
    return CyberHudPanel(
      title: 'Team Comparison',
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
                      width: 56,
                      child: Text(
                        stat.homeDisplay,
                        style: _cricketNumber(11, color: homeColor),
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
                      width: 56,
                      child: Text(
                        stat.awayDisplay,
                        textAlign: TextAlign.right,
                        style: _cricketNumber(11, color: awayColor),
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

class _CricketChase extends StatelessWidget {
  const _CricketChase({required this.match});
  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    final details = match.cricketDetails;
    final balls = details?.commentary ?? const <CricketBallCommentary>[];
    if (balls.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.show_chart,
        title: 'Chase feed unavailable',
        message: 'Ball-level run-rate samples have not been published.',
      );
    }
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
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 760),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) => CyberHudPanel(
            title: 'Late Chase',
            code: 'BALLS://${balls.length.toString().padLeft(2, '0')}',
            glow: progress < 1,
            child: Column(
              children: [
                SizedBox(
                  height: 230,
                  child: CustomPaint(
                    key: const ValueKey('cricket-late-chase-graph'),
                    painter: CricketChasePainter(
                      balls: balls,
                      progress: progress,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Legend(color: Cyber.cyan, label: 'ACTUAL RR'),
                    _Legend(color: Cyber.magenta, label: 'REQUIRED RR'),
                    _Legend(color: Cyber.gold, label: 'BOUNDARY'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        CyberHudPanel(
          title: 'Chase Readout',
          code: 'WINDOW://15.1-17.6',
          accent: Cyber.gold,
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
        const SizedBox(height: 12),
        CyberHudPanel(
          title: 'Ball Pressure',
          code: 'CHASE://SEQUENCE',
          child: Column(
            children: balls.map((ball) {
              final required = ball.required;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 42,
                      child: Text(
                        ball.over,
                        style: _cricketNumber(10, color: Cyber.cyan),
                      ),
                    ),
                    Expanded(
                      child: Text(ball.shortText, style: Cyber.body(11.5)),
                    ),
                    Text(
                      required == null
                          ? 'CHASE COMPLETE'
                          : '${required.runs} OFF ${required.balls}',
                      style: Cyber.label(
                        7.5,
                        color: ball.boundary ? Cyber.gold : Cyber.muted,
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
                  child: CyberPanel(
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
    return CyberPanel(
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
    return CyberPanel(
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
              CyberHudPanel(
                title: squad.name,
                code: 'SQUAD://${squad.playerCount}',
                accent: accent,
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
    return CyberPanel(
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

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 2, color: color),
        const SizedBox(width: 5),
        Text(label, style: Cyber.label(7, color: Cyber.muted)),
      ],
    );
  }
}

class CricketChasePainter extends CustomPainter {
  const CricketChasePainter({required this.balls, required this.progress});
  final List<CricketBallCommentary> balls;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (balls.length < 2) return;
    final rect = Rect.fromLTRB(12, 18, size.width - 8, size.height - 26);
    final maxRate = balls
        .fold<double>(0, (peak, ball) {
          return math.max(
            peak,
            math.max(ball.runRate, ball.required?.runRate ?? 0),
          );
        })
        .ceilToDouble()
        .clamp(1, double.infinity);
    final grid = Paint()..color = Cyber.line.withValues(alpha: 0.55);
    for (final fraction in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final y = rect.bottom - rect.height * fraction;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), grid);
    }
    final count = math.max(2, (balls.length * progress).ceil());
    Path lineFor(double Function(CricketBallCommentary ball) value) {
      final path = Path();
      for (var index = 0; index < count; index++) {
        final ball = balls[index.clamp(0, balls.length - 1)];
        final x = rect.left + rect.width * index / (balls.length - 1);
        final y =
            rect.bottom - rect.height * (value(ball) / maxRate).clamp(0, 1);
        if (index == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      return path;
    }

    canvas.drawPath(
      lineFor((ball) => ball.runRate),
      Paint()
        ..color = Cyber.cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
    canvas.drawPath(
      lineFor((ball) => ball.required?.runRate ?? 0),
      Paint()
        ..color = Cyber.magenta
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7,
    );
    for (var index = 0; index < count; index++) {
      final ball = balls[index];
      if (!ball.boundary && !ball.wicket) continue;
      final x = rect.left + rect.width * index / (balls.length - 1);
      final y =
          rect.bottom - rect.height * (ball.runRate / maxRate).clamp(0, 1);
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()..color = ball.wicket ? Cyber.danger : Cyber.gold,
      );
    }
    for (final index in [0, balls.length ~/ 2, balls.length - 1]) {
      final x = rect.left + rect.width * index / (balls.length - 1);
      final text = TextPainter(
        text: TextSpan(
          text: balls[index].over,
          style: Cyber.label(7, color: Cyber.muted),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(x - text.width / 2, rect.bottom + 6));
    }
  }

  @override
  bool shouldRepaint(covariant CricketChasePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.balls != balls;
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
