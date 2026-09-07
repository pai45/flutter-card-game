import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/league_stat_leaders.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_widgets.dart';
import '../../../widgets/team_logo.dart';

/// How a stat should be read and ranked.
enum StatFormat {
  /// Whole season totals — goals, shots, tackles.
  count,

  /// Already a percentage in the feed (0-100).
  percent,

  /// A per-match average that needs two decimals.
  average,
}

/// One curated stat board: which stat, how to read it, and whether a low
/// number is the good outcome.
@immutable
class StatBoardSpec {
  const StatBoardSpec(
    this.stat,
    this.label, {
    this.format = StatFormat.count,
    this.lowerIsBetter = false,
    this.accent,
    this.caption,
  });

  /// ESPN stat key, e.g. `avgExpectedGoals`.
  final String stat;

  /// Short chip label. The full name and ESPN's own description come from the
  /// package's stat dictionary.
  final String label;

  /// Replaces ESPN's description on the leader plate. Set only where the
  /// feed's own wording is ambiguous or misspelt — everything else uses the
  /// dictionary text so the explainers stay sourced rather than invented.
  final String? caption;

  final StatFormat format;

  /// True where the league leader is the *smallest* number (goals conceded,
  /// cards). Flips both the ranking and the "LEAGUE BEST" framing.
  final bool lowerIsBetter;

  /// Overrides the group accent for a single board — used so discipline reads
  /// amber/danger even inside a calmer group.
  final Color? accent;
}

/// A STATS group: one tab of curated boards over the same accent.
@immutable
class StatBoardGroup {
  const StatBoardGroup({
    required this.label,
    required this.boards,
    this.accent,
    this.pulse = const [],
  });

  final String label;

  /// Null means "use the league's own accent" — attacking output is the
  /// league's identity colour, the other groups carry their own semantics.
  final Color? accent;

  final List<StatBoardSpec> boards;

  /// Stats summarised as league-wide totals in the group's header strip.
  final List<StatPulseSpec> pulse;
}

/// One cell of a group's header strip: a league-wide total, so the boards
/// below land in context rather than as bare rankings.
@immutable
class StatPulseSpec {
  const StatPulseSpec(this.stat, this.label, {this.perTeam = false});

  final String stat;
  final String label;

  /// Divides the league total by the number of teams — used where the average
  /// is the readable number (possession would otherwise total 2000%).
  final bool perTeam;
}

/// The curated STATS tab: four groups of boards drawn from the 112 season
/// stats ESPN publishes per team.
///
/// This is a deliberate subset. The package carries every stat, but 22 of them
/// are zero league-wide and many others (`shootOut*`, `avgRatingFrom*`) never
/// populate in league play — see
/// `docs/data/league-stats-field-inventory.md` for the full coverage audit.
/// Only stats verified as populated across both competitions appear here.
const footballStatGroups = <StatBoardGroup>[
  StatBoardGroup(
    label: 'ATTACK',
    pulse: [
      StatPulseSpec('totalGoals', 'GOALS'),
      StatPulseSpec('totalShots', 'SHOTS'),
      StatPulseSpec('bigChanceCreated', 'BIG CHANCES'),
    ],
    boards: [
      // ESPN words this one "goals scored against the opposing team", which
      // reads like goals conceded on a board headed GOALS.
      StatBoardSpec(
        'totalGoals',
        'GOALS',
        caption: 'Goals scored by this club across the season.',
      ),
      StatBoardSpec('avgExpectedGoals', 'xG', format: StatFormat.average),
      StatBoardSpec('totalShots', 'SHOTS'),
      StatBoardSpec('shotsOnTarget', 'ON TARGET'),
      StatBoardSpec('shotPct', 'ACCURACY', format: StatFormat.percent),
      StatBoardSpec('goalConversion', 'CONVERSION', format: StatFormat.percent),
      StatBoardSpec('bigChanceCreated', 'BIG CHANCES'),
      StatBoardSpec('possessionPct', 'POSSESSION', format: StatFormat.percent),
      StatBoardSpec('passPct', 'PASS %', format: StatFormat.percent),
      StatBoardSpec('wonCorners', 'CORNERS'),
    ],
  ),
  StatBoardGroup(
    label: 'DEFENCE',
    accent: Cyber.violet,
    pulse: [
      StatPulseSpec('totalTackles', 'TACKLES'),
      StatPulseSpec('interceptions', 'INTERCEPTIONS'),
      StatPulseSpec('blockedShots', 'BLOCKS'),
    ],
    boards: [
      StatBoardSpec('totalTackles', 'TACKLES'),
      // ESPN's own text misspells "percentage" here.
      StatBoardSpec(
        'tacklePct',
        'TACKLE %',
        format: StatFormat.percent,
        caption: 'The percentage of tackles where the ball is won.',
      ),
      StatBoardSpec('interceptions', 'INTERCEPTIONS'),
      StatBoardSpec('effectiveClearance', 'CLEARANCES'),
      StatBoardSpec('blockedShots', 'BLOCKS'),
      StatBoardSpec('recoveries', 'RECOVERIES'),
      StatBoardSpec('duelWinPct', 'DUELS WON %', format: StatFormat.percent),
    ],
  ),
  StatBoardGroup(
    label: 'KEEPING',
    accent: Cyber.success,
    pulse: [
      StatPulseSpec('cleanSheet', 'CLEAN SHEETS'),
      StatPulseSpec('saves', 'SAVES'),
      StatPulseSpec('goalsConceded', 'CONCEDED'),
    ],
    boards: [
      StatBoardSpec('cleanSheet', 'CLEAN SHEETS'),
      StatBoardSpec('saves', 'SAVES'),
      StatBoardSpec('savePct', 'SAVE %', format: StatFormat.percent),
      StatBoardSpec('goalsConceded', 'CONCEDED', lowerIsBetter: true),
      StatBoardSpec(
        'avgGoalsConceded',
        'CONCEDED / GAME',
        format: StatFormat.average,
        lowerIsBetter: true,
      ),
      StatBoardSpec('shotsFaced', 'SHOTS FACED', lowerIsBetter: true),
    ],
  ),
  StatBoardGroup(
    label: 'DISCIPLINE',
    accent: Cyber.amber,
    pulse: [
      StatPulseSpec('yellowCards', 'YELLOW'),
      StatPulseSpec('redCards', 'RED'),
      StatPulseSpec('foulsCommitted', 'FOULS'),
    ],
    boards: [
      StatBoardSpec('yellowCards', 'YELLOW', lowerIsBetter: true),
      StatBoardSpec(
        'redCards',
        'RED',
        lowerIsBetter: true,
        accent: Cyber.danger,
      ),
      // ESPN's own text misspells "committed" here.
      StatBoardSpec(
        'foulsCommitted',
        'FOULS',
        lowerIsBetter: true,
        caption: 'The number of fouls committed by this club.',
      ),
      StatBoardSpec('foulsSuffered', 'FOULS WON'),
      StatBoardSpec('offsides', 'OFFSIDES', lowerIsBetter: true),
    ],
  ),
];

/// Ranks all 20 clubs on one stat: a glowing leader plate over calm chaser
/// rows.
///
/// This is deliberately the same reading language as the player-facing
/// [StatLeaderboard] on the LEADERS tab — same champion-plus-chasers rhythm,
/// same single focal glow, and the same bar-free rows — so moving between the
/// two tabs feels like one system rather than two screens.
class TeamStatBoard extends StatelessWidget {
  const TeamStatBoard({
    required this.entries,
    required this.spec,
    required this.definition,
    required this.accent,
    super.key,
  });

  final List<TeamStatEntry> entries;
  final StatBoardSpec spec;
  final LeagueStatDefinition? definition;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const CyberNoDataState(
        icon: Icons.query_stats_outlined,
        title: 'NOT PUBLISHED',
        message: 'This competition has not reported that stat yet.',
      );
    }

    final leader = entries.first;
    final chasers = entries.skip(1).toList(growable: false);

    return Column(
      key: ValueKey(spec.stat),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CyberSlideUpFadeIn(
          offset: 18,
          child: _LeaderPlate(
            entry: leader,
            spec: spec,
            definition: definition,
            accent: accent,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < chasers.length; i++) ...[
          CyberSlideUpFadeIn(
            offset: 14,
            delay: Duration(milliseconds: 28 * (i + 1)),
            child: _ChaserRow(
              entry: chasers[i],
              spec: spec,
              accent: accent,
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

/// The `#1` plate — the one glowing surface on the STATS tab (glow rule).
class _LeaderPlate extends StatelessWidget {
  const _LeaderPlate({
    required this.entry,
    required this.spec,
    required this.definition,
    required this.accent,
  });

  final TeamStatEntry entry;
  final StatBoardSpec spec;
  final LeagueStatDefinition? definition;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final description = spec.caption ?? definition?.description;
    return CyberPanel(
      accent: accent,
      glow: true,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, size: 13, color: Cyber.gold),
              const SizedBox(width: 6),
              Text(
                spec.lowerIsBetter ? 'LEAGUE BEST // FEWEST' : 'LEAGUE BEST',
                style: Cyber.label(8.5, color: Cyber.gold, letterSpacing: 1.6),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  (definition?.displayName ?? spec.label).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Cyber.label(
                    8.5,
                    color: Cyber.muted,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TeamLogo(
                team: entry.team,
                width: 42,
                height: 39,
                sport: Sport.football,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.team.name,
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
                      entry.team.shortName.toUpperCase(),
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
                formatStat(entry.value, entry.display, spec.format),
                style: Cyber.display(
                  30,
                  color: accent,
                  letterSpacing: 0.5,
                ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              description.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Cyber.label(8.5, color: Cyber.muted, letterSpacing: 1.1),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ranks 2+: a flat chamfered plate — rank, crest, club, value.
class _ChaserRow extends StatelessWidget {
  const _ChaserRow({
    required this.entry,
    required this.spec,
    required this.accent,
  });

  final TeamStatEntry entry;
  final StatBoardSpec spec;
  final Color accent;

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
                '${entry.rank}',
                style: Cyber.label(
                  12,
                  color: Cyber.muted,
                  letterSpacing: 0.2,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 4),
            TeamLogo(
              team: entry.team,
              width: 26,
              height: 24,
              sport: Sport.football,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                entry.team.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.body(13, weight: FontWeight.w700, height: 1),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatStat(entry.value, entry.display, spec.format),
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

/// Renders a stat value the way its unit reads. The feed's own `display` is
/// trusted for counts (it already drops the trailing `.0`), but percentages
/// and per-match averages are reformatted so a column of them lines up.
String formatStat(double value, String display, StatFormat format) {
  switch (format) {
    case StatFormat.percent:
      return '${value.toStringAsFixed(value >= 100 ? 0 : 1)}%';
    case StatFormat.average:
      return value.toStringAsFixed(2);
    case StatFormat.count:
      if (display.isNotEmpty) return display;
      return value == value.roundToDouble()
          ? value.round().toString()
          : value.toStringAsFixed(1);
  }
}

/// Cricket's STATS boards.
///
/// Deliberately a separate list rather than extra entries on
/// [footballStatGroups]: the two sports share no stat keys at all, so a single
/// merged list would render a full page of "NOT PUBLISHED" for whichever sport
/// was not selected — which is exactly what the IPL hub did before this existed.
///
/// Every stat here is a season total aggregated from the match summaries by
/// `tool/generate_cricket_league_stats.dart`; ESPN publishes no team-level
/// cricket statistics feed of its own.
const cricketStatGroups = <StatBoardGroup>[
  StatBoardGroup(
    label: 'BATTING',
    pulse: [
      StatPulseSpec('runs', 'RUNS'),
      StatPulseSpec('sixes', 'SIXES'),
      StatPulseSpec('fours', 'FOURS'),
    ],
    boards: [
      StatBoardSpec('runs', 'RUNS'),
      StatBoardSpec('sixes', 'SIXES'),
      StatBoardSpec('fours', 'FOURS'),
      StatBoardSpec('fiftyPlus', 'FIFTIES'),
      StatBoardSpec('ballsFaced', 'BALLS FACED'),
    ],
  ),
  StatBoardGroup(
    label: 'BOWLING',
    accent: Cyber.success,
    pulse: [
      StatPulseSpec('wickets', 'WICKETS'),
      StatPulseSpec('dots', 'DOT BALLS'),
      StatPulseSpec('maidens', 'MAIDENS'),
    ],
    boards: [
      StatBoardSpec('wickets', 'WICKETS'),
      StatBoardSpec('dots', 'DOT BALLS'),
      StatBoardSpec('maidens', 'MAIDENS'),
      // Fewest runs given away is the bowling attack's headline.
      StatBoardSpec('conceded', 'RUNS CONCEDED', lowerIsBetter: true),
      StatBoardSpec('foursConceded', 'FOURS GIVEN', lowerIsBetter: true),
      StatBoardSpec('sixesConceded', 'SIXES GIVEN', lowerIsBetter: true),
    ],
  ),
  StatBoardGroup(
    label: 'FIELDING',
    accent: Cyber.violet,
    pulse: [
      StatPulseSpec('caught', 'CATCHES'),
      StatPulseSpec('stumped', 'STUMPINGS'),
      StatPulseSpec('dismissals', 'DISMISSALS'),
    ],
    boards: [
      StatBoardSpec('caught', 'CATCHES'),
      StatBoardSpec('stumped', 'STUMPINGS'),
      StatBoardSpec('dismissals', 'DISMISSALS'),
    ],
  ),
  StatBoardGroup(
    label: 'EXTRAS',
    accent: Cyber.amber,
    pulse: [
      StatPulseSpec('wides', 'WIDES'),
      StatPulseSpec('noballs', 'NO BALLS'),
    ],
    boards: [
      StatBoardSpec('wides', 'WIDES', lowerIsBetter: true),
      StatBoardSpec('noballs', 'NO BALLS', lowerIsBetter: true),
    ],
  ),
];

/// Picks the board set a league's stats belong to.
///
/// Keyed off the stat dictionary's own categories rather than a sport enum, so
/// the hub does not need to know what sport it is showing — the package that
/// filled it already said.
List<StatBoardGroup> statGroupsFor(Map<String, LeagueStatDefinition> defs) {
  for (final definition in defs.values) {
    if (definition.category == 'batting' ||
        definition.category == 'bowling' ||
        definition.category == 'fielding') {
      return cricketStatGroups;
    }
  }
  return footballStatGroups;
}
