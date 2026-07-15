import 'package:flutter/material.dart';
import '../models/sport_match.dart';
import '../config/theme.dart';

class CricketLineupView extends StatefulWidget {
  const CricketLineupView({super.key, required this.match});
  final SportMatch match;

  @override
  State<CricketLineupView> createState() => _CricketLineupViewState();
}

class _CricketLineupViewState extends State<CricketLineupView> {
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
    final accentColor = _showHome ? Cyber.cyan : Cyber.gold;

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

        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('Playing XI', accentColor),
              ...activeLineup.startingXI.map((p) => _buildPlayerRow(p, accentColor)),
              const SizedBox(height: 24),
              if (activeLineup.substitutes.isNotEmpty) ...[
                _buildSectionHeader('Bench', Cyber.muted),
                ...activeLineup.substitutes.map((p) => _buildPlayerRow(p, Cyber.muted)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: Cyber.body(14, weight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 4),
          Container(
            height: 1,
            width: double.infinity,
            color: Cyber.line,
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerRow(MatchPlayer player, Color accent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Cyber.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Cyber.line.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Cyber.bg,
              shape: BoxShape.circle,
              border: Border.all(color: accent.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Icon(Icons.person, size: 20, color: accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name,
                  style: Cyber.body(14, weight: FontWeight.w600),
                ),
                if (player.role != null && player.role!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      player.role!,
                      style: Cyber.body(12, color: Cyber.muted),
                    ),
                  ),
              ],
            ),
          ),
          if (player.isCaptain)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Cyber.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'C',
                style: Cyber.body(10, weight: FontWeight.w800, color: Cyber.gold),
              ),
            ),
        ],
      ),
    );
  }
}
