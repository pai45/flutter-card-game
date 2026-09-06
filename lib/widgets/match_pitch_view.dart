import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../data/team_palettes.dart';
import '../models/sport_match.dart';
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
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _BenchPanel(lineup: lineup, teamColor: teamColor),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: (lineup.confirmed ? Cyber.success : Cyber.gold).withValues(
                alpha: 0.1,
              ),
              border: Border.all(
                color: (lineup.confirmed ? Cyber.success : Cyber.gold)
                    .withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              lineup.confirmed ? 'CONFIRMED' : 'PROJECTED',
              style: Cyber.label(
                8,
                color: lineup.confirmed ? Cyber.success : Cyber.gold,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormationBoard extends StatelessWidget {
  const _FormationBoard({required this.lineup, required this.teamColor});

  final MatchLineup lineup;
  final Color teamColor;

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
                    child: _PitchPlayer(player: player, teamColor: teamColor),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _PitchPlayer extends StatelessWidget {
  const _PitchPlayer({required this.player, required this.teamColor});

  final MatchPlayer player;
  final Color teamColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            foregroundPainter: OctagonBorderPainter(
              color: teamColor.withValues(alpha: 0.78),
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
                  style: Cyber.display(12, color: teamColor).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
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
              style: Cyber.body(8.5, weight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenchPanel extends StatelessWidget {
  const _BenchPanel({required this.lineup, required this.teamColor});

  final MatchLineup lineup;
  final Color teamColor;

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
  const _BenchPlayerTile({required this.player, required this.teamColor});

  final MatchPlayer player;
  final Color teamColor;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        ],
      ),
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

    const grid = 32.0;
    for (double x = 0; x < size.width; x += grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
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
