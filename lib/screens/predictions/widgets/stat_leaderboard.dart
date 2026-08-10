import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/league_stat_leaders.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/team_logo.dart';

/// One stat leaderboard: a glowing champion plate on top of calm ranked rows.
///
/// The `#1` card is the screen's single focal glow (glow rule) — everything
/// below it is a flat plate with a scaled [CyberProgressBar] so the drop-off
/// from the leader reads at a glance.
class StatLeaderboard extends StatelessWidget {
  const StatLeaderboard({
    required this.category,
    required this.leagueAccent,
    this.resolving = false,
    super.key,
  });

  final StatLeaderCategory category;
  final Color leagueAccent;

  /// True while athlete names are still being fetched for this board.
  final bool resolving;

  Color get _accent => switch (category.accent) {
    StatAccent.league => leagueAccent,
    StatAccent.success => Cyber.success,
    StatAccent.amber => Cyber.amber,
    StatAccent.danger => Cyber.danger,
  };

  @override
  Widget build(BuildContext context) {
    final leaders = category.leaders;
    if (leaders.isEmpty) {
      return const _LeaderboardNote('No leaders published yet.');
    }

    final champion = leaders.first;
    final chasers = leaders.skip(1).toList(growable: false);
    final top = category.topValue <= 0 ? 1.0 : category.topValue;

    return Column(
      key: ValueKey(category.key),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CyberSlideUpFadeIn(
          offset: 18,
          child: _ChampionCard(
            leader: champion,
            category: category,
            accent: _accent,
            resolving: resolving,
          ),
        ),
        if (chasers.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (var i = 0; i < chasers.length; i++) ...[
            CyberSlideUpFadeIn(
              offset: 14,
              delay: Duration(milliseconds: 40 * (i + 1)),
              child: _ChaserRow(
                rank: i + 2,
                leader: chasers[i],
                accent: _accent,
                fraction: (chasers[i].value / top).clamp(0.04, 1.0),
                resolving: resolving,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

/// The `#1` plate: big tabular number, champion identity, and a full bar. The
/// only glowing surface on the leaders tab.
class _ChampionCard extends StatelessWidget {
  const _ChampionCard({
    required this.leader,
    required this.category,
    required this.accent,
    required this.resolving,
  });

  final StatLeader leader;
  final StatLeaderCategory category;
  final Color accent;
  final bool resolving;

  @override
  Widget build(BuildContext context) {
    final detail = _detailLine(leader);
    return CyberPanel(
      accent: accent,
      glow: true,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.workspace_premium, size: 13, color: Cyber.gold),
              const SizedBox(width: 6),
              Text(
                'LEAGUE LEADER',
                style: Cyber.label(8.5, color: Cyber.gold, letterSpacing: 1.6),
              ),
              const Spacer(),
              Text(
                category.unitLabel,
                style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.4),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _LeaderCrest(leader: leader, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameOf(leader, resolving),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.display(
                        17,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _subtitleOf(leader),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Cyber.label(
                        9,
                        color: Cyber.muted,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                leader.shortValue,
                style: Cyber.display(
                  32,
                  color: accent,
                  letterSpacing: 0.5,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CyberProgressBar(value: 1, accent: accent, height: 6),
          if (detail != null) ...[
            const SizedBox(height: 9),
            Text(
              detail,
              style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ranks 2+: a flat chamfered plate with a bar scaled against the leader.
class _ChaserRow extends StatelessWidget {
  const _ChaserRow({
    required this.rank,
    required this.leader,
    required this.accent,
    required this.fraction,
    required this.resolving,
  });

  final int rank;
  final StatLeader leader;
  final Color accent;
  final double fraction;
  final bool resolving;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: const HudChamferClipper(bigCut: 11, smallCut: 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
        decoration: BoxDecoration(
          color: Cyber.panel,
          border: Border.all(color: accent.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                '$rank',
                style: Cyber.label(
                  12,
                  color: Cyber.muted,
                  letterSpacing: 0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _LeaderCrest(leader: leader, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _nameOf(leader, resolving),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.body(
                      13,
                      weight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  CyberProgressBar(
                    value: fraction,
                    accent: accent.withValues(alpha: 0.85),
                    height: 4,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              leader.shortValue,
              style: Cyber.display(
                15,
                color: Colors.white,
                letterSpacing: 0.4,
              ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ],
        ),
      ),
    );
  }
}

/// Club badge for a leader, falling back to a neutral plate while the athlete
/// reference is still resolving (the feed gives values before names).
class _LeaderCrest extends StatelessWidget {
  const _LeaderCrest({required this.leader, required this.size});

  final StatLeader leader;
  final double size;

  @override
  Widget build(BuildContext context) {
    final team = leader.team;
    if (team != null) {
      return TeamLogo(
        team: team,
        width: size,
        height: size * 0.92,
        sport: Sport.football,
      );
    }
    return SizedBox(
      width: size,
      height: size * 0.92,
      child: ClipPath(
        clipper: const OctagonClipper(),
        child: ColoredBox(
          color: Cyber.bg2,
          child: Icon(
            Icons.person,
            size: size * 0.5,
            color: Cyber.muted.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

class _LeaderboardNote extends StatelessWidget {
  const _LeaderboardNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Text(text, style: Cyber.body(13, color: Cyber.muted)),
    );
  }
}

String _nameOf(StatLeader leader, bool resolving) =>
    leader.name ?? (resolving ? 'LOADING…' : 'UNKNOWN PLAYER');

String _subtitleOf(StatLeader leader) {
  final parts = <String>[
    if (leader.team != null) leader.team!.name.toUpperCase(),
    if (leader.position != null) leader.position!.toUpperCase(),
  ];
  return parts.isEmpty ? 'SEASON TOTAL' : parts.join('  //  ');
}

/// The feed's prose value ("Matches: 15, Goals: 13") shown as a HUD detail
/// line. Skipped when it just repeats the headline number.
String? _detailLine(StatLeader leader) {
  final raw = leader.displayValue.trim();
  if (raw.isEmpty || raw == leader.shortValue) return null;
  if (!raw.contains(':')) return null;
  return raw.toUpperCase().replaceAll(', ', '  //  ');
}
