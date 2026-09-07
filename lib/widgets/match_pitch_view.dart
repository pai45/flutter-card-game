import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../data/team_palettes.dart';
import '../models/football_match_data.dart';
import '../models/sport_match.dart';
import '../screens/predictions/widgets/football_player_match_sheet.dart';
import 'cyber/cyber_filter_chips.dart';
import 'cyber/cyber_widgets.dart';
import 'team_logo.dart';

class MatchPitchView extends StatefulWidget {
  const MatchPitchView({required this.match, super.key});

  final SportMatch match;

  @override
  State<MatchPitchView> createState() => _MatchPitchViewState();
}

class _MatchPitchViewState extends State<MatchPitchView> {
  bool _showHome = true;

  @override
  Widget build(BuildContext context) {
    final homeLineup = widget.match.homeLineup;
    final awayLineup = widget.match.awayLineup;
    if (homeLineup == null || awayLineup == null) {
      return const CyberNoDataState(
        key: ValueKey('match-lineups-empty'),
        icon: Icons.groups_outlined,
        title: 'Lineups not locked',
        message: 'Confirmed formations and squad roles will appear here.',
        accent: Cyber.cyan,
        spark: Icons.stadium_outlined,
      );
    }

    final lineup = _showHome ? homeLineup : awayLineup;
    final team = _showHome ? widget.match.home : widget.match.away;
    final teamColor = paletteForTeam(
      team,
      sport: widget.match.sport,
      competition: widget.match.leagueId,
    ).secondaryTextColor;
    // Only football has a per-player match sheet to open. Basketball shares
    // this board and stays a read-only diagram.
    final onTapPlayer = widget.match.sport == Sport.football
        ? (MatchPlayer player) {
            HapticFeedback.selectionClick();
            showFootballPlayerMatchSheet(
              context: context,
              match: widget.match,
              lineup: lineup,
              player: player,
              isHomeTeam: _showHome,
              accent: teamColor,
            );
          }
        : null;
    return Column(
      children: [
        CyberFilterChips(
          labels: [widget.match.home.shortName, widget.match.away.shortName],
          selected: _showHome
              ? widget.match.home.shortName
              : widget.match.away.shortName,
          accent: teamColor,
          onSelect: (label) {
            HapticFeedback.selectionClick();
            setState(() => _showHome = label == widget.match.home.shortName);
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            key: ValueKey('match-lineup-${team.id}'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LineupIdentityPanel(
                  team: team,
                  lineup: lineup,
                  sport: widget.match.sport,
                  competition: widget.match.leagueId,
                  teamColor: teamColor,
                ),
                const SizedBox(height: 12),
                CyberPanel(
                  accent: teamColor,
                  padding: const EdgeInsets.all(8),
                  child: AspectRatio(
                    aspectRatio: widget.match.sport == Sport.basketball
                        ? 0.74
                        : 0.66,
                    child: ClipPath(
                      clipper: CyberClipper(),
                      child: ColoredBox(
                        color: Cyber.panel2,
                        child: CustomPaint(
                          painter: _PitchSurfacePainter(
                            basketball: widget.match.sport == Sport.basketball,
                            accent: teamColor,
                          ),
                          child: _FormationBoard(
                            lineup: lineup,
                            teamColor: teamColor,
                            onTapPlayer: onTapPlayer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _BenchPanel(
                  lineup: lineup,
                  teamColor: teamColor,
                  onTapPlayer: onTapPlayer,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LineupIdentityPanel extends StatelessWidget {
  const _LineupIdentityPanel({
    required this.team,
    required this.lineup,
    required this.sport,
    required this.competition,
    required this.teamColor,
  });

  final SportTeam team;
  final MatchLineup lineup;
  final Sport sport;
  final String competition;
  final Color teamColor;

  @override
  Widget build(BuildContext context) {
    final playerCount =
        lineup.reportedPlayerCount ??
        lineup.startingXI.length + lineup.substitutes.length;
    return CyberPanel(
      accent: teamColor,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          TeamLogo(
            team: team,
            width: 48,
            height: 48,
            sport: sport,
            competition: competition,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name.toUpperCase(),
                  style: Cyber.display(15, color: teamColor),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lineup.formation} FORMATION // $playerCount PLAYER SQUAD',
                  style: Cyber.label(
                    8.5,
                    color: Cyber.muted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CyberStatusPill(
            label: lineup.confirmed ? 'CONFIRMED' : 'PROJECTED',
            color: lineup.confirmed ? Cyber.success : Cyber.gold,
          ),
        ],
      ),
    );
  }
}

class _FormationBoard extends StatelessWidget {
  const _FormationBoard({
    required this.lineup,
    required this.teamColor,
    this.onTapPlayer,
  });

  final MatchLineup lineup;
  final Color teamColor;
  final ValueChanged<MatchPlayer>? onTapPlayer;

  @override
  Widget build(BuildContext context) {
    final players = [...lineup.startingXI]
      ..sort((a, b) {
        final aPlace = int.tryParse(a.formationPlace ?? '');
        final bPlace = int.tryParse(b.formationPlace ?? '');
        if (aPlace == null || bPlace == null) return 0;
        return aPlace.compareTo(bPlace);
      });
    final rows = <int>[
      1,
      ...lineup.formation.split('-').map((part) {
        return int.tryParse(part) ?? 0;
      }),
    ];
    final positionedRows = <List<MatchPlayer>>[];
    var cursor = 0;
    for (final count in rows) {
      final end = (cursor + count).clamp(cursor, players.length);
      positionedRows.add(players.sublist(cursor, end));
      cursor = end;
    }
    if (cursor < players.length) positionedRows.add(players.sublist(cursor));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final row in positionedRows)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final player in row)
                  Flexible(
                    child: _PitchPlayer(
                      player: player,
                      teamColor: teamColor,
                      onTap: onTapPlayer,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PitchPlayer extends StatelessWidget {
  const _PitchPlayer({
    required this.player,
    required this.teamColor,
    this.onTap,
  });

  final MatchPlayer player;
  final Color teamColor;
  final ValueChanged<MatchPlayer>? onTap;

  @override
  Widget build(BuildContext context) {
    final stats = player.matchStats;
    // A player who never came on is dimmed but still tappable — their card is
    // short and honest, and a dead tap target reads as a bug.
    final dim = stats != null && !stats.played;
    final tint = dim ? Cyber.muted.withValues(alpha: 0.55) : teamColor;

    final node = SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CustomPaint(
                foregroundPainter: OctagonBorderPainter(
                  color: tint.withValues(alpha: 0.78),
                  strokeWidth: 1.5,
                ),
                child: ClipPath(
                  clipper: const OctagonClipper(),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    color: Cyber.card,
                    child: Text(
                      player.number.toString(),
                      style: Cyber.display(12, color: tint).copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ),
              if (stats != null)
                Positioned(
                  right: -5,
                  top: -5,
                  child: _PlayerMarks(stats: stats),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: BoxDecoration(
              color: Cyber.bg.withValues(alpha: 0.82),
              border: Border.all(color: Cyber.line.withValues(alpha: 0.2)),
            ),
            child: Text(
              player.shortName ?? player.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Cyber.body(
                8.5,
                weight: FontWeight.w800,
                color: dim ? Cyber.muted : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    final handler = onTap;
    if (handler == null) return node;
    return _TapPunch(
      key: ValueKey('pitch-player-${player.id}'),
      onTap: () => handler(player),
      child: node,
    );
  }
}

/// What a player earned in this match, pinned to the shirt badge: a ball per
/// goal, an assist mark, a card, a sub arrow.
///
/// This is what turns the formation board from a diagram into a match report
/// you can read at a glance. Only a goal glows — the glow rule holds even here,
/// where several nodes carry a mark.
class _PlayerMarks extends StatelessWidget {
  const _PlayerMarks({required this.stats});

  final FootballPlayerMatchStats stats;

  @override
  Widget build(BuildContext context) {
    final marks = <Widget>[];
    final goals = stats.intStat('totalGoals');
    for (var i = 0; i < goals && i < 3; i++) {
      marks.add(
        const _Mark(
          icon: Icons.sports_soccer,
          color: Cyber.gold,
          glow: true,
        ),
      );
    }
    if (stats.intStat('goalAssists') > 0) {
      marks.add(const _Mark(icon: Icons.ads_click, color: Cyber.cyan));
    }
    if (stats.intStat('redCards') > 0) {
      marks.add(const _Mark(icon: Icons.style, color: Cyber.danger));
    } else if (stats.intStat('yellowCards') > 0) {
      marks.add(const _Mark(icon: Icons.style, color: Cyber.amber));
    }
    if (stats.subOutMinute != null || stats.subInMinute != null) {
      marks.add(const _Mark(icon: Icons.swap_horiz, color: Cyber.muted));
    }
    if (marks.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final mark in marks) Padding(
          padding: const EdgeInsets.only(left: 1),
          child: mark,
        ),
      ],
    );
  }
}

class _Mark extends StatelessWidget {
  const _Mark({required this.icon, required this.color, this.glow = false});

  final IconData icon;
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Cyber.bg,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.75)),
        boxShadow: glow ? Cyber.glow(color, alpha: 0.5, blur: 6) : null,
      ),
      child: Icon(icon, size: 8, color: color),
    );
  }
}

/// A tap target that punches inward, so a node feels pressed rather than just
/// navigating.
class _TapPunch extends StatefulWidget {
  const _TapPunch({required this.child, required this.onTap, super.key});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_TapPunch> createState() => _TapPunchState();
}

class _TapPunchState extends State<_TapPunch> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTap: () {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _BenchPanel extends StatelessWidget {
  const _BenchPanel({
    required this.lineup,
    required this.teamColor,
    this.onTapPlayer,
  });

  final MatchLineup lineup;
  final Color teamColor;
  final ValueChanged<MatchPlayer>? onTapPlayer;

  @override
  Widget build(BuildContext context) {
    return CyberPanel(
      accent: teamColor,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'BENCH UNIT',
                style: Cyber.label(10, color: teamColor, letterSpacing: 1.2),
              ),
              const Spacer(),
              Text(
                '${lineup.substitutes.length.toString().padLeft(2, '0')} AVAILABLE',
                style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.7),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (lineup.substitutes.isEmpty)
            Text(
              'No substitutes supplied.',
              style: Cyber.body(12, color: Cyber.muted),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = (constraints.maxWidth - 8) / 2;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final player in lineup.substitutes)
                      SizedBox(
                        width: width,
                        child: _BenchPlayerTile(
                          player: player,
                          teamColor: teamColor,
                          onTap: onTapPlayer,
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BenchPlayerTile extends StatelessWidget {
  const _BenchPlayerTile({
    required this.player,
    required this.teamColor,
    this.onTap,
  });

  final MatchPlayer player;
  final Color teamColor;
  final ValueChanged<MatchPlayer>? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Cyber.panel2.withValues(alpha: 0.48),
        border: Border.all(color: Cyber.line.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              player.number.toString(),
              style: Cyber.display(
                10,
                color: teamColor,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.shortName ?? player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.body(10, weight: FontWeight.w800),
                ),
                Text(
                  (player.role ?? 'Squad player').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Cyber.label(7, color: Cyber.muted, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          if (player.matchStats != null)
            _PlayerMarks(stats: player.matchStats!),
        ],
      ),
    );

    final handler = onTap;
    if (handler == null) return tile;
    return _TapPunch(
      key: ValueKey('bench-player-${player.id}'),
      onTap: () => handler(player),
      child: tile,
    );
  }
}

class _PitchSurfacePainter extends CustomPainter {
  const _PitchSurfacePainter({required this.basketball, required this.accent});

  final bool basketball;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Cyber.line.withValues(alpha: 0.32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final signalPaint = Paint()
      ..color = accent.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    // No blueprint grid on the football pitch: the panel already sits on the
    // app's textured background, so a second grid inside it was texture on
    // texture and competed with the markings and the player nodes. The
    // basketball court keeps its grid until that board is looked at too.
    if (basketball) {
      const grid = 32.0;
      for (double x = 0; x < size.width; x += grid) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
      for (double y = 0; y < size.height; y += grid) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }
    canvas.drawRect(Offset.zero & size, linePaint);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      linePaint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.15,
      linePaint,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2.5,
      signalPaint,
    );

    if (basketball) {
      _paintBasketball(canvas, size, linePaint);
    } else {
      _paintFootball(canvas, size, linePaint);
    }
  }

  void _paintFootball(Canvas canvas, Size size, Paint paint) {
    final penaltyWidth = size.width * 0.54;
    final penaltyHeight = size.height * 0.15;
    final goalWidth = size.width * 0.26;
    final goalHeight = size.height * 0.055;
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - penaltyWidth) / 2,
        0,
        penaltyWidth,
        penaltyHeight,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - penaltyWidth) / 2,
        size.height - penaltyHeight,
        penaltyWidth,
        penaltyHeight,
      ),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH((size.width - goalWidth) / 2, 0, goalWidth, goalHeight),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - goalWidth) / 2,
        size.height - goalHeight,
        goalWidth,
        goalHeight,
      ),
      paint,
    );
  }

  void _paintBasketball(Canvas canvas, Size size, Paint paint) {
    final keyWidth = size.width * 0.36;
    final keyHeight = size.height * 0.22;
    canvas.drawRect(
      Rect.fromLTWH((size.width - keyWidth) / 2, 0, keyWidth, keyHeight),
      paint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        (size.width - keyWidth) / 2,
        size.height - keyHeight,
        keyWidth,
        keyHeight,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _PitchSurfacePainter oldDelegate) =>
      oldDelegate.basketball != basketball || oldDelegate.accent != accent;
}
