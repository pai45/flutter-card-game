import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../data/cricket_match_portraits.dart';
import '../../models/cricket_match_data.dart';
import '../../models/league.dart';
import '../../models/sport_match.dart';
import '../../models/team_hub.dart';
import '../../widgets/cyber/cyber_widgets.dart';
import '../../widgets/team_logo.dart';
import 'widgets/standings_table.dart';

/// Season-level IPL dossier backed by ESPN's generated match aggregates.
class CricketPlayerSeasonScreen extends StatelessWidget {
  const CricketPlayerSeasonScreen({
    required this.league,
    required this.team,
    required this.player,
    required this.seasonLabel,
    super.key,
  });

  final League league;
  final SportTeam team;
  final TeamSeasonPlayer player;
  final String seasonLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cyber.bg,
      body: CyberPlainBackground(
        child: SafeArea(
          child: Column(
            children: [
              DetailTopBar(title: '${league.shortCode} // DOSSIER'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    CyberPanel(
                      accent: league.accent,
                      glow: true,
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CricketPlayerPortrait(
                            athleteId: player.id,
                            name: player.name,
                            accent: league.accent,
                            size: 76,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ESPN // SEASON INTEL',
                                  style: Cyber.label(
                                    8,
                                    color: Cyber.success,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  player.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Cyber.display(
                                    19,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Row(
                                  children: [
                                    TeamLogo(
                                      team: team,
                                      sport: Sport.cricket,
                                      competition: league.id,
                                      width: 24,
                                      height: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${team.shortName} // ${player.displayRole}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Cyber.label(
                                          9,
                                          color: Cyber.muted,
                                          letterSpacing: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    CyberSectionHeading(label: '$seasonLabel // SEASON TOTALS'),
                    const SizedBox(height: 10),
                    for (final group in CricketStatGroup.values)
                      if (_statsFor(group).isNotEmpty) ...[
                        _StatGroup(
                          label: group.name.toUpperCase(),
                          entries: _statsFor(group),
                          accent: _accentFor(group),
                        ),
                        const SizedBox(height: 14),
                      ],
                    if (player.stats.values.every((value) => value == 0))
                      const CyberNoDataState(
                        icon: Icons.query_stats_outlined,
                        title: 'NO SEASON SPLIT',
                        message:
                            'ESPN lists this player but has not published a season stat line.',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<(CricketStatDescriptor, num)> _statsFor(CricketStatGroup group) => [
    for (final descriptor in kCricketPlayerStatCatalog)
      if (descriptor.group == group && (player.stats[descriptor.key] ?? 0) != 0)
        (descriptor, player.stats[descriptor.key]!),
  ];

  Color _accentFor(CricketStatGroup group) => switch (group) {
    CricketStatGroup.batting => league.accent,
    CricketStatGroup.bowling => Cyber.success,
    CricketStatGroup.fielding => Cyber.amber,
  };
}

class _StatGroup extends StatelessWidget {
  const _StatGroup({
    required this.label,
    required this.entries,
    required this.accent,
  });

  final String label;
  final List<(CricketStatDescriptor, num)> entries;
  final Color accent;

  @override
  Widget build(BuildContext context) => CyberPanel(
    accent: accent,
    padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Cyber.label(9, color: accent, letterSpacing: 1.4)),
        const SizedBox(height: 10),
        for (var index = 0; index < entries.length; index += 3) ...[
          Row(
            children: [
              for (var offset = 0; offset < 3; offset++) ...[
                if (index + offset < entries.length)
                  CyberMiniMetric(
                    label: entries[index + offset].$1.label,
                    value: _display(entries[index + offset].$2),
                    accent:
                        entries[index + offset].$1.tone == CricketStatTone.good
                        ? Cyber.success
                        : entries[index + offset].$1.tone ==
                              CricketStatTone.caution
                        ? Cyber.amber
                        : null,
                  )
                else
                  const Spacer(),
                if (offset < 2) const SizedBox(width: 6),
              ],
            ],
          ),
          if (index + 3 < entries.length) const SizedBox(height: 6),
        ],
      ],
    ),
  );
}

String _display(num value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(2);
