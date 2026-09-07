import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../data/football_match_portraits.dart';
import '../../../models/football_match_data.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_chart.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/cyber/player_match_sheet.dart';
import 'football_player_heatmap.dart';

/// Opens the per-player match card, seeded at [player].
///
/// The sheet pages across the whole squad rather than closing between players,
/// so comparing two team-mates is a swipe instead of two taps and a scroll.
Future<void> showFootballPlayerMatchSheet({
  required BuildContext context,
  required SportMatch match,
  required MatchLineup lineup,
  required MatchPlayer player,
  required bool isHomeTeam,
  required Color accent,
}) {
  final squad = [...lineup.startingXI, ...lineup.substitutes];
  final index = squad.indexWhere((p) => p.id == player.id);
  final team = isHomeTeam ? match.home : match.away;
  return showPlayerMatchSheet(
    context: context,
    accent: accent,
    itemCount: squad.length,
    initialIndex: index < 0 ? 0 : index,
    itemBuilder: (context, page) => FootballPlayerMatchCard(
      player: squad[page],
      team: team,
      accent: accent,
      eventId: match.footballDetails?.espnEventId,
      leagueSlug: match.leagueId,
    ),
  );
}

/// One player's match card.
class FootballPlayerMatchCard extends StatefulWidget {
  const FootballPlayerMatchCard({
    required this.player,
    required this.team,
    required this.accent,
    this.eventId,
    this.leagueSlug,
    super.key,
  });

  final MatchPlayer player;
  final SportTeam team;
  final Color accent;
  final String? eventId;
  final String? leagueSlug;

  @override
  State<FootballPlayerMatchCard> createState() =>
      _FootballPlayerMatchCardState();
}

class _FootballPlayerMatchCardState extends State<FootballPlayerMatchCard> {
  static const _ranges = ['FULL', '1ST', '2ND'];
  String _range = 'FULL';

  int? get _period => switch (_range) {
    '1ST' => 1,
    '2ND' => 2,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final stats = widget.player.matchStats;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      children: [
        _PlayerIdentity(
          player: widget.player,
          team: widget.team,
          accent: widget.accent,
          eventId: widget.eventId,
          leagueSlug: widget.leagueSlug,
        ),
        const SizedBox(height: 14),
        if (stats == null)
          const CyberNoDataState(
            icon: Icons.query_stats,
            title: 'No match sheet',
            message:
                'This fixture has no per-player data from the feed yet.',
            accent: Cyber.muted,
            spark: Icons.timer_off_outlined,
          )
        else ...[
          _ImpactStrip(stats: stats, accent: widget.accent),
          const SizedBox(height: 16),
          _HeatmapPanel(
            stats: stats,
            accent: widget.accent,
            range: _range,
            ranges: _ranges,
            period: _period,
            onRange: (value) => setState(() => _range = value),
          ),
          const SizedBox(height: 16),
          _MatchSheet(stats: stats, accent: widget.accent),
        ],
      ],
    );
  }
}

/// Name, kit and role — with the shirt number blown up behind it so the card
/// opens on an identity, not a table.
class _PlayerIdentity extends StatelessWidget {
  const _PlayerIdentity({
    required this.player,
    required this.team,
    required this.accent,
    this.eventId,
    this.leagueSlug,
  });

  final MatchPlayer player;
  final SportTeam team;
  final Color accent;
  final String? eventId;
  final String? leagueSlug;

  @override
  Widget build(BuildContext context) {
    final stats = player.matchStats;
    final subtitle = [
      if (player.role != null) player.role!.toUpperCase(),
      '#${player.number}',
      team.shortName.toUpperCase(),
    ].join('  //  ');

    return CyberPanel(
      accent: accent,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Stack(
        children: [
          Positioned(
            right: -6,
            top: -18,
            child: Text(
              '${player.number}',
              style: Cyber.display(
                86,
                color: accent.withValues(alpha: 0.1),
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              FootballPlayerPortrait(
                player: player,
                accent: accent,
                size: 66,
                eventId: eventId,
                leagueSlug: leagueSlug,
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
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        8.5,
                        color: Cyber.muted,
                        letterSpacing: 1.1,
                      ),
                    ),
                    if (stats != null) ...[
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          CyberStatusPill(
                            label: stats.roleLabel,
                            color: stats.played ? accent : Cyber.muted,
                          ),
                          const SizedBox(width: 6),
                          if (stats.played)
                            CyberStatusPill(
                              label: stats.minutesLabel,
                              color: Cyber.muted,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The four numbers the coordinates buy us, which ESPN does not publish.
class _ImpactStrip extends StatelessWidget {
  const _ImpactStrip({required this.stats, required this.accent});

  final FootballPlayerMatchStats stats;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final xg = stats.expectedGoals;
    final territory = stats.territory;
    return Row(
      children: [
        CountUpMetric(
          label: 'TOUCHES',
          value: stats.touchCount.toDouble(),
          format: (v) => v.round().toString(),
          accent: stats.hasTracking ? accent : null,
        ),
        const SizedBox(width: 8),
        CountUpMetric(
          label: 'xG',
          value: xg ?? 0,
          format: (v) => xg == null ? '—' : v.toStringAsFixed(2),
          accent: (xg ?? 0) >= 0.5 ? Cyber.amber : null,
        ),
        const SizedBox(width: 8),
        CountUpMetric(
          label: 'FINAL 3RD',
          value: stats.finalThirdTouches.toDouble(),
          format: (v) => stats.hasTracking ? v.round().toString() : '—',
        ),
        const SizedBox(width: 8),
        CountUpMetric(
          label: 'TERRITORY',
          value: (territory ?? 0) * 100,
          format: (v) => territory == null ? '—' : '${v.round()}%',
        ),
      ],
    );
  }
}

/// The heatmap, its half filter and the readout under it.
class _HeatmapPanel extends StatelessWidget {
  const _HeatmapPanel({
    required this.stats,
    required this.accent,
    required this.range,
    required this.ranges,
    required this.period,
    required this.onRange,
  });

  final FootballPlayerMatchStats stats;
  final Color accent;
  final String range;
  final List<String> ranges;
  final int? period;
  final ValueChanged<String> onRange;

  @override
  Widget build(BuildContext context) {
    if (!stats.hasTracking) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const CyberSectionHeading(label: 'HEAT MAP'),
          const SizedBox(height: 10),
          CyberNoDataState(
            icon: Icons.airline_seat_recline_normal,
            title: stats.played ? 'No tracked touches' : 'Unused substitute',
            message: stats.played
                ? 'The feed logged no positional data for this player.'
                : 'This player stayed on the bench for the whole match.',
            accent: Cyber.muted,
            spark: Icons.timer_off_outlined,
          ),
        ],
      );
    }

    final touches = stats.touches(period: period);
    final grid = TouchHeatGrid.from(touches);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CyberSectionHeading(label: 'HEAT MAP'),
        const SizedBox(height: 10),
        // Full width on its own line: the range buttons are Expanded, so they
        // cannot live in the heading's unbounded trailing slot.
        CyberChartRangeTabs(
          ranges: ranges,
          active: range,
          onChanged: onRange,
        ),
        const SizedBox(height: 10),
        CyberPanel(
          accent: accent,
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: PitchFrameAspect.value,
                // Keyed by range so switching halves replays the scan rather
                // than tweening one cloud into the other.
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('heat-$range-${touches.length}'),
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, reveal, _) => CustomPaint(
                    key: const ValueKey('football-player-heatmap'),
                    painter: FootballPlayerHeatmapPainter(
                      grid: grid,
                      accent: accent,
                      reveal: reveal,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TRACKED TOUCH DENSITY  //  ATTACKING →',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        7.5,
                        color: Cyber.muted,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  Text(
                    'BOX ${stats.boxTouches}',
                    style: Cyber.label(
                      7.5,
                      color: Cyber.amber,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Keeps the pitch's true proportions in one place for layout.
class PitchFrameAspect {
  const PitchFrameAspect._();

  static const value = 105 / 68;
}

/// ESPN's own numbers, grouped and shown as loadout-style pills rather than a
/// spreadsheet row.
class _MatchSheet extends StatelessWidget {
  const _MatchSheet({required this.stats, required this.accent});

  final FootballPlayerMatchStats stats;
  final Color accent;

  static const _groupLabels = {
    FootballStatGroup.attack: 'ATTACK',
    FootballStatGroup.duels: 'INVOLVEMENT',
    FootballStatGroup.discipline: 'DISCIPLINE',
    FootballStatGroup.goalkeeping: 'GOALKEEPING',
  };

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    for (final group in FootballStatGroup.values) {
      final entries = kFootballPlayerStatCatalog
          .where((d) => d.group == group && stats.stat(d.key) != null)
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
                value: stats.intStat(entry.key),
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
  final int value;
  final FootballStatTone tone;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    // A zero is context, not achievement — it stays muted so the numbers a
    // player actually put on the board carry the eye.
    final scored = value > 0;
    final colour = !scored
        ? Cyber.muted
        : switch (tone) {
            FootballStatTone.neutral => accent,
            FootballStatTone.caution => Cyber.amber,
            FootballStatTone.danger => Cyber.danger,
          };
    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 8, smallCut: 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(color: colour.withValues(alpha: scored ? 0.4 : 0.16)),
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
              '$value',
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
