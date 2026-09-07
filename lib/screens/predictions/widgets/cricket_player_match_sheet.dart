import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../data/cricket_match_portraits.dart';
import '../../../models/cricket_match_data.dart';
import '../../../widgets/cyber/cyber_chart.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/cyber/player_match_sheet.dart';
import 'cricket_innings_tape.dart';

/// Opens the per-player match card, seeded at [player] and paging that
/// player's own squad.
Future<void> showCricketPlayerMatchSheet({
  required BuildContext context,
  required CricketTeamSquad squad,
  required CricketSquadPlayer player,
  required Color accent,
}) {
  final index = squad.players.indexWhere((p) => p.id == player.id);
  return showPlayerMatchSheet(
    context: context,
    accent: accent,
    itemCount: squad.players.length,
    initialIndex: index < 0 ? 0 : index,
    itemBuilder: (context, page) => CricketPlayerMatchCard(
      player: squad.players[page],
      squad: squad,
      accent: accent,
    ),
  );
}

/// One player's match card.
class CricketPlayerMatchCard extends StatefulWidget {
  const CricketPlayerMatchCard({
    required this.player,
    required this.squad,
    required this.accent,
    super.key,
  });

  final CricketSquadPlayer player;
  final CricketTeamSquad squad;
  final Color accent;

  @override
  State<CricketPlayerMatchCard> createState() => _CricketPlayerMatchCardState();
}

class _CricketPlayerMatchCardState extends State<CricketPlayerMatchCard> {
  InningsTapeMode? _mode;

  /// An all-rounder who both batted and bowled gets a switch; everyone else is
  /// pinned to whichever side of the game they actually played.
  InningsTapeMode _resolvedMode(CricketPlayerMatchStats stats) {
    if (_mode != null) return _mode!;
    return stats.didBat ? InningsTapeMode.batting : InningsTapeMode.bowling;
  }

  @override
  Widget build(BuildContext context) {
    final stats = widget.player.matchStats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        _PlayerIdentity(
          player: widget.player,
          squad: widget.squad,
          accent: widget.accent,
        ),
        const SizedBox(height: 14),
        if (stats == null)
          const CyberNoDataState(
            icon: Icons.query_stats,
            title: 'No match sheet',
            message: 'This fixture has no per-player data from the feed yet.',
            accent: Cyber.muted,
            spark: Icons.timer_off_outlined,
          )
        else if (!stats.played)
          const CyberNoDataState(
            icon: Icons.airline_seat_recline_normal,
            title: 'Did not bat or bowl',
            message: 'This player took no part in the match.',
            accent: Cyber.muted,
            spark: Icons.timer_off_outlined,
          )
        else ...[
          _ImpactStrip(
            stats: stats,
            mode: _resolvedMode(stats),
            accent: widget.accent,
          ),
          const SizedBox(height: 16),
          _TapeSection(
            stats: stats,
            mode: _resolvedMode(stats),
            accent: widget.accent,
            onMode: (mode) => setState(() => _mode = mode),
          ),
          const SizedBox(height: 16),
          _MatchSheet(stats: stats, accent: widget.accent),
        ],
      ],
    );
  }
}

/// Name, portrait, styles and the headline figure.
class _PlayerIdentity extends StatelessWidget {
  const _PlayerIdentity({
    required this.player,
    required this.squad,
    required this.accent,
  });

  final CricketSquadPlayer player;
  final CricketTeamSquad squad;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final stats = player.matchStats;
    final headline = stats == null
        ? null
        : stats.didBat
        ? stats.battingLine
        : stats.didBowl
        ? stats.bowlingLine
        : null;

    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CricketPlayerPortrait(
                athleteId: player.id,
                name: player.name,
                accent: accent,
                size: 66,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.name.toUpperCase(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.display(
                        16,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${player.role.toUpperCase()}  //  '
                      '${squad.abbreviation.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        8.5,
                        color: Cyber.muted,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (headline != null) ...[
                const SizedBox(width: 8),
                Text(
                  headline,
                  style: Cyber.display(
                    20,
                    color: accent,
                    letterSpacing: 0.4,
                  ).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (player.captain)
                CyberStatusPill(label: 'CAPTAIN', color: Cyber.gold),
              if (player.keeper)
                CyberStatusPill(label: 'KEEPER', color: accent),
              if (stats != null && !stats.played)
                CyberStatusPill(label: 'UNUSED', color: Cyber.muted),
              if (stats != null && stats.notOut && stats.didBat)
                CyberStatusPill(label: 'NOT OUT', color: Cyber.lime),
            ],
          ),
          // battingStyle / bowlingStyle have been decoded since the package
          // shipped and never shown anywhere until now.
          if (player.styleLine.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              player.styleLine.toUpperCase(),
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.2),
            ),
          ],
        ],
      ),
    );
  }
}

/// The four numbers that read fastest, per discipline.
class _ImpactStrip extends StatelessWidget {
  const _ImpactStrip({
    required this.stats,
    required this.mode,
    required this.accent,
  });

  final CricketPlayerMatchStats stats;
  final InningsTapeMode mode;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (mode == InningsTapeMode.bowling) {
      return Row(
        children: [
          CountUpMetric(
            label: 'WICKETS',
            value: stats.wickets.toDouble(),
            format: (v) => v.round().toString(),
            accent: stats.wickets > 0 ? Cyber.lime : null,
          ),
          const SizedBox(width: 8),
          CountUpMetric(
            label: 'RUNS',
            value: stats.conceded.toDouble(),
            format: (v) => v.round().toString(),
          ),
          const SizedBox(width: 8),
          CountUpMetric(
            label: 'ECONOMY',
            value: stats.doubleStat('economyRate'),
            format: (v) => v.toStringAsFixed(2),
            accent: stats.doubleStat('economyRate') <= 7 ? Cyber.lime : null,
          ),
          const SizedBox(width: 8),
          CountUpMetric(
            label: 'DOTS',
            value: stats.doubleStat('dots'),
            format: (v) => v.round().toString(),
          ),
        ],
      );
    }
    return Row(
      children: [
        CountUpMetric(
          label: 'RUNS',
          value: stats.runs.toDouble(),
          format: (v) => v.round().toString(),
        ),
        const SizedBox(width: 8),
        CountUpMetric(
          label: 'BALLS',
          value: stats.ballsFaced.toDouble(),
          format: (v) => v.round().toString(),
        ),
        const SizedBox(width: 8),
        CountUpMetric(
          label: 'SR',
          value: stats.doubleStat('strikeRate'),
          format: (v) => v.toStringAsFixed(1),
          accent: stats.doubleStat('strikeRate') >= 150 ? Cyber.amber : null,
        ),
        const SizedBox(width: 8),
        CountUpMetric(
          label: 'BOUNDARY',
          value: stats.boundaryShare * 100,
          format: (v) => '${v.round()}%',
        ),
      ],
    );
  }
}

/// The tape, with a BAT / BOWL switch for an all-rounder.
class _TapeSection extends StatelessWidget {
  const _TapeSection({
    required this.stats,
    required this.mode,
    required this.accent,
    required this.onMode,
  });

  final CricketPlayerMatchStats stats;
  final InningsTapeMode mode;
  final Color accent;
  final ValueChanged<InningsTapeMode> onMode;

  @override
  Widget build(BuildContext context) {
    final both = stats.didBat && stats.didBowl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSectionHeading(label: 'INNINGS TAPE'),
        const SizedBox(height: 10),
        if (both) ...[
          // Full width on its own line: the range buttons are Expanded, so they
          // cannot live in the heading's unbounded trailing slot.
          CyberChartRangeTabs(
            ranges: const ['BATTING', 'BOWLING'],
            active: mode == InningsTapeMode.batting ? 'BATTING' : 'BOWLING',
            onChanged: (value) => onMode(
              value == 'BATTING'
                  ? InningsTapeMode.batting
                  : InningsTapeMode.bowling,
            ),
          ),
          const SizedBox(height: 10),
        ],
        CricketInningsTape(stats: stats, mode: mode, accent: accent),
      ],
    );
  }
}

/// ESPN's own numbers as loadout-style pills, grouped by discipline.
class _MatchSheet extends StatelessWidget {
  const _MatchSheet({required this.stats, required this.accent});

  final CricketPlayerMatchStats stats;
  final Color accent;

  static const _groupLabels = {
    CricketStatGroup.batting: 'BATTING',
    CricketStatGroup.bowling: 'BOWLING',
    CricketStatGroup.fielding: 'FIELDING',
  };

  /// Already carried by the impact strip above. Repeating them as pills would
  /// show the reader the same number twice, so the sheet stays complementary:
  /// the strip is the headline, this is everything the headline leaves out.
  static const _inTheStrip = {
    'runs',
    'ballsFaced',
    'strikeRate',
    'wickets',
    'conceded',
    'economyRate',
    'dots',
  };

  /// The feed's stat block is a union of all three disciplines, so a batter
  /// carries zeroed bowling keys and vice versa. Showing them would be noise,
  /// so a whole board is dropped unless the player actually played that way.
  bool _shows(CricketStatGroup group) => switch (group) {
    CricketStatGroup.batting => stats.didBat,
    CricketStatGroup.bowling => stats.didBowl,
    CricketStatGroup.fielding => stats.intStat('dismissals') > 0,
  };

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    for (final group in CricketStatGroup.values) {
      if (!_shows(group)) continue;
      final entries = kCricketPlayerStatCatalog
          .where(
            (d) =>
                d.group == group &&
                !_inTheStrip.contains(d.key) &&
                stats.stat(d.key) != null,
          )
          .toList(growable: false);
      if (entries.isEmpty) continue;
      sections.addAll([
        if (sections.isNotEmpty) const SizedBox(height: 14),
        CyberSectionHeading(label: _groupLabels[group]!),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              _StatPill(
                label: entry.label,
                value: stats.stat(entry.key)!,
                tone: entry.tone,
                accent: accent,
              ),
          ],
        ),
      ]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: sections,
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    required this.tone,
    required this.accent,
  });

  final String label;
  final num value;
  final CricketStatTone tone;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // A zero is context, not achievement — it stays muted so the numbers a
    // player actually put on the board carry the eye.
    final scored = value > 0;
    final colour = !scored
        ? Cyber.muted
        : switch (tone) {
            CricketStatTone.neutral => accent,
            CricketStatTone.good => Cyber.lime,
            CricketStatTone.caution => Cyber.amber,
          };
    final text = value is int || value == value.roundToDouble()
        ? value.round().toString()
        : value.toStringAsFixed(2);
    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 8, smallCut: 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(
            color: colour.withValues(alpha: scored ? 0.4 : 0.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Cyber.label(8, color: Cyber.muted, letterSpacing: 1.2),
            ),
            const SizedBox(width: 8),
            Text(
              text,
              style: Cyber.display(13, color: colour).copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
