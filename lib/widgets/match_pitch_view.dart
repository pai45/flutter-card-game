import 'package:flutter/material.dart';
import '../models/sport_match.dart';
import '../config/theme.dart';

class MatchPitchView extends StatefulWidget {
  const MatchPitchView({super.key, required this.match});
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
      return const Center(
        child: Text('Lineup data not available', style: TextStyle(color: Cyber.muted)),
      );
    }

    final activeLineup = _showHome ? homeLineup : awayLineup;
    final activeTeam = _showHome ? widget.match.home : widget.match.away;

    return Column(
      children: [
        // Team Toggle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Cyber.panel,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Cyber.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showHome = true),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _showHome ? Cyber.cyan.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.match.home.name,
                        style: Cyber.body(13, weight: _showHome ? FontWeight.w800 : FontWeight.w600, color: _showHome ? Cyber.cyan : Cyber.muted),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _showHome = false),
                    child: Container(
                      decoration: BoxDecoration(
                        color: !_showHome ? Cyber.gold.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.match.away.name,
                        style: Cyber.body(13, weight: !_showHome ? FontWeight.w800 : FontWeight.w600, color: !_showHome ? Cyber.gold : Cyber.muted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Pitch
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A), // Dark pitch color
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: CustomPaint(
                        painter: widget.match.sport == Sport.basketball ? _CourtPainter() : _PitchPainter(),
                        child: _buildFormation(activeLineup, activeTeam.color),
                      ),
                    ),
                  ),
                ),
                
                if (activeLineup.substitutes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'BENCH / SUBSTITUTES',
                          style: Cyber.label(12, color: Cyber.cyan, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 16,
                          alignment: WrapAlignment.start,
                          children: activeLineup.substitutes.map((player) {
                            return SizedBox(
                              width: 64,
                              child: _buildPlayer(player, activeTeam.color, isSubstitute: true),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormation(MatchLineup lineup, Color teamColor) {
    // Parse formation, e.g., "4-3-3" -> [1, 4, 3, 3] (1 for GK)
    final parts = lineup.formation.split('-').map((e) => int.tryParse(e) ?? 0).toList();
    final rows = [1, ...parts];

    // Distribute players into rows
    final List<List<MatchPlayer>> positionedRows = [];
    int playerIndex = 0;
    for (int count in rows) {
      final rowPlayers = <MatchPlayer>[];
      for (int i = 0; i < count; i++) {
        if (playerIndex < lineup.startingXI.length) {
          rowPlayers.add(lineup.startingXI[playerIndex]);
          playerIndex++;
        }
      }
      positionedRows.add(rowPlayers);
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: positionedRows.map((rowPlayers) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: rowPlayers.map((player) => _buildPlayer(player, teamColor)).toList(),
        );
      }).toList(),
    );
  }

  Widget _buildPlayer(MatchPlayer player, Color teamColor, {bool isSubstitute = false}) {
    final double size = isSubstitute ? 36 : 48;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Player Avatar Placeholder
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E1E1E),
                border: Border.all(color: teamColor.withValues(alpha: 0.8), width: 2),
              ),
              child: Icon(Icons.person, color: Colors.white54, size: size * 0.6),
            ),
            // Rating Badge
            if (player.rating != null && !isSubstitute)
              Positioned(
                top: -6,
                right: -12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: player.rating! >= 7.0 ? Cyber.lime : (player.rating! >= 6.0 ? Cyber.gold : Colors.orange),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    player.rating!.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        // Name and Number
        Container(
          width: isSubstitute ? 64 : 76,
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${player.number}',
                style: const TextStyle(color: Cyber.cyan, fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  player.name,
                  textAlign: TextAlign.center,
                  maxLines: isSubstitute ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Halfway line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Center circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.15,
      paint,
    );
    
    // Center dot
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = Colors.white24..style = PaintingStyle.fill,
    );

    // Penalty areas (Top and Bottom)
    final penaltyAreaWidth = size.width * 0.5;
    final penaltyAreaHeight = size.height * 0.15;
    
    // Top Penalty Area
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, penaltyAreaHeight / 2),
        width: penaltyAreaWidth,
        height: penaltyAreaHeight,
      ),
      paint,
    );

    // Bottom Penalty Area
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - (penaltyAreaHeight / 2)),
        width: penaltyAreaWidth,
        height: penaltyAreaHeight,
      ),
      paint,
    );

    // Goal areas
    final goalAreaWidth = size.width * 0.25;
    final goalAreaHeight = size.height * 0.06;

    // Top Goal Area
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, goalAreaHeight / 2),
        width: goalAreaWidth,
        height: goalAreaHeight,
      ),
      paint,
    );

    // Bottom Goal Area
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - (goalAreaHeight / 2)),
        width: goalAreaWidth,
        height: goalAreaHeight,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CourtPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Halfway line
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );

    // Center circle
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.15,
      paint,
    );

    // Center dot
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      2,
      Paint()..color = Colors.white24..style = PaintingStyle.fill,
    );

    final keyWidth = size.width * 0.35;
    final keyHeight = size.height * 0.22;

    // Top Key
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, keyHeight / 2),
        width: keyWidth,
        height: keyHeight,
      ),
      paint,
    );

    // Bottom Key
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height - (keyHeight / 2)),
        width: keyWidth,
        height: keyHeight,
      ),
      paint,
    );

    // Free Throw Circles
    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width / 2, keyHeight), width: keyWidth * 0.7, height: keyWidth * 0.7),
      0, 3.14159, false, paint,
    ); // Top free throw arc

    canvas.drawArc(
      Rect.fromCenter(center: Offset(size.width / 2, size.height - keyHeight), width: keyWidth * 0.7, height: keyWidth * 0.7),
      3.14159, 3.14159, false, paint,
    ); // Bottom free throw arc

    // 3-Point Arcs
    final arcWidth = size.width * 0.85;
    final arcHeight = size.height * 0.5;
    
    // Top 3-point arc
    final topArcRect = Rect.fromCenter(center: Offset(size.width / 2, 0), width: arcWidth, height: arcHeight);
    canvas.drawArc(topArcRect, 0.3, 3.14159 - 0.6, false, paint);
    canvas.drawLine(Offset(size.width / 2 - arcWidth / 2 + 10, 0), Offset(size.width / 2 - arcWidth / 2 + 10, arcHeight * 0.15), paint);
    canvas.drawLine(Offset(size.width / 2 + arcWidth / 2 - 10, 0), Offset(size.width / 2 + arcWidth / 2 - 10, arcHeight * 0.15), paint);

    // Bottom 3-point arc
    final bottomArcRect = Rect.fromCenter(center: Offset(size.width / 2, size.height), width: arcWidth, height: arcHeight);
    canvas.drawArc(bottomArcRect, 3.14159 + 0.3, 3.14159 - 0.6, false, paint);
    canvas.drawLine(Offset(size.width / 2 - arcWidth / 2 + 10, size.height), Offset(size.width / 2 - arcWidth / 2 + 10, size.height - arcHeight * 0.15), paint);
    canvas.drawLine(Offset(size.width / 2 + arcWidth / 2 - 10, size.height), Offset(size.width / 2 + arcWidth / 2 - 10, size.height - arcHeight * 0.15), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
