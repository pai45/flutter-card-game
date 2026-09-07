import 'package:flutter/material.dart';

import 'sport_match.dart';
import 'team_standing.dart';

/// One ESPN competition season offered by the league hub selector.
@immutable
class LeagueSeasonOption {
  const LeagueSeasonOption({
    required this.year,
    required this.label,
    this.startDate,
    this.endDate,
    this.isCurrent = false,
  });

  final int year;
  final String label;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isCurrent;

  /// Compact HUD copy such as `2024-25`, without repeating the league name.
  String get shortLabel {
    final match = RegExp(r'\d{4}(?:[-/]\d{2,4})?').firstMatch(label);
    if (match != null) return match.group(0)!.replaceAll('/', '-');
    return year.toString();
  }

  LeagueSeasonOption copyWith({bool? isCurrent}) => LeagueSeasonOption(
    year: year,
    label: label,
    startDate: startDate,
    endDate: endDate,
    isCurrent: isCurrent ?? this.isCurrent,
  );
}

/// One sub-table of a league standings page — a conference (MLS East/West),
/// a group, or the single flat table most leagues use.
@immutable
class StandingsGroup {
  const StandingsGroup({required this.label, required this.rows});

  /// Feed label, e.g. "Eastern Conference". Empty for a single flat table.
  final String label;

  /// Rank-sorted rows within this group.
  final List<TeamStanding> rows;

  /// Compact label for the group toggle, e.g. "EAST" for "Eastern Conference".
  String get shortLabel {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return 'TABLE';
    const suffixes = [' Conference', ' Division', ' Group'];
    for (final suffix in suffixes) {
      if (trimmed.endsWith(suffix)) {
        final head = trimmed.substring(0, trimmed.length - suffix.length);
        // "Eastern" reads better as "EAST" on a two-chip toggle.
        if (head.endsWith('ern')) {
          return head.substring(0, head.length - 3).toUpperCase();
        }
        return head.toUpperCase();
      }
    }
    return trimmed.toUpperCase();
  }
}

/// One player on a stat leaderboard (top scorer, top assists, most saves, ...).
@immutable
class StatLeader {
  const StatLeader({
    required this.athleteId,
    required this.value,
    required this.displayValue,
    this.name,
    this.teamId,
    this.team,
    this.position,
    this.flagUrl,
  });

  final String athleteId;

  /// Numeric value used to scale the leaderboard bars.
  final double value;

  /// Feed-formatted value, e.g. "13" or "Matches: 15, Goals: 13".
  final String displayValue;

  /// Null until the athlete reference has been resolved (see
  /// EspnLeagueStatsService.resolveCategory).
  final String? name;

  /// ESPN team id, parsed out of the leader's team reference URL.
  final String? teamId;

  /// Resolved from the standings payload's team map, so no extra request.
  final SportTeam? team;

  final String? position;

  /// Nationality flag image from the athlete payload.
  final String? flagUrl;

  bool get isResolved => name != null;

  /// The headline number, without the feed's "Matches: 15, Goals: 13" prose.
  String get shortValue {
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(2);
  }

  StatLeader copyWith({
    String? name,
    SportTeam? team,
    String? position,
    String? flagUrl,
  }) => StatLeader(
    athleteId: athleteId,
    value: value,
    displayValue: displayValue,
    name: name ?? this.name,
    teamId: teamId,
    team: team ?? this.team,
    position: position ?? this.position,
    flagUrl: flagUrl ?? this.flagUrl,
  );
}

/// Which accent a leaderboard is tinted with. Resolved to a real colour by the
/// UI so the league's own accent can stand in for [StatAccent.league].
enum StatAccent { league, success, amber, danger }

/// A single leaderboard: one stat, its top players, and how it should be
/// tinted. [accent] drives the palette so discipline stats read as danger and
/// shot-stopping reads as success (see the cyber-ui colour discipline).
@immutable
class StatLeaderCategory {
  const StatLeaderCategory({
    required this.key,
    required this.label,
    required this.unitLabel,
    required this.accent,
    required this.leaders,
  });

  /// ESPN category name, e.g. "goalsLeaders", "saves".
  final String key;

  /// Tab label, e.g. "GOALS".
  final String label;

  /// Headline noun for the hero card, e.g. "GOALS SCORED".
  final String unitLabel;

  final StatAccent accent;

  final List<StatLeader> leaders;

  bool get isResolved => leaders.every((l) => l.isResolved);

  StatLeaderCategory withLeaders(List<StatLeader> next) => StatLeaderCategory(
    key: key,
    label: label,
    unitLabel: unitLabel,
    accent: accent,
    leaders: next,
  );
}

/// What one team recorded for one stat across the season.
@immutable
class TeamStatValue {
  const TeamStatValue({required this.value, required this.display});

  final double value;

  /// The feed's own formatting, e.g. "61.5" or "3".
  final String display;
}

/// ESPN's description of a stat, hoisted out of the per-team payload so the
/// same metadata isn't repeated 40 times. Drives labels and the explainer line
/// under each board.
@immutable
class LeagueStatDefinition {
  const LeagueStatDefinition({
    required this.name,
    required this.category,
    required this.displayName,
    this.shortDisplayName,
    this.abbreviation,
    this.description,
  });

  /// ESPN stat key, e.g. `avgExpectedGoals`.
  final String name;

  /// Owning group: `offensive`, `defensive`, `general` or `goalKeeping`.
  final String category;

  final String displayName;
  final String? shortDisplayName;
  final String? abbreviation;

  /// ESPN's own prose explanation, shown as the board's caption.
  final String? description;
}

/// One team's full season statistics, flattened across ESPN's four categories
/// so a stat can be read by name without knowing which group it belongs to.
@immutable
class TeamSeasonStats {
  const TeamSeasonStats({required this.team, required this.values});

  final SportTeam team;
  final Map<String, TeamStatValue> values;

  TeamStatValue? operator [](String stat) => values[stat];
}

/// A league's per-club season statistics plus the stat metadata they share.
/// Produced by either source — the bundled package or a live ESPN sweep — so
/// the STATS tab renders identically whichever one answered.
@immutable
class LeagueTeamStats {
  const LeagueTeamStats({required this.teams, required this.definitions});

  static const empty = LeagueTeamStats(teams: [], definitions: {});

  final List<TeamSeasonStats> teams;
  final Map<String, LeagueStatDefinition> definitions;

  bool get isEmpty => teams.isEmpty;
}

/// One team on a team-stat board — the team equivalent of [StatLeader].
@immutable
class TeamStatEntry {
  const TeamStatEntry({
    required this.rank,
    required this.team,
    required this.value,
    required this.display,
  });

  final int rank;
  final SportTeam team;
  final double value;
  final String display;
}

/// Everything the league hub shows for one league. [groups] and [categories]
/// drive the TABLE and LEADERS tabs; [teamStats] drives STATS.
@immutable
class LeagueStatsSnapshot {
  const LeagueStatsSnapshot({
    required this.groups,
    required this.categories,
    this.teamStats = const [],
    this.statDefinitions = const {},
    this.seasonLabel,
    this.seasonYear,
  });

  static const empty = LeagueStatsSnapshot(groups: [], categories: []);

  /// Standings sub-tables. One entry for a flat league, two for MLS.
  final List<StandingsGroup> groups;

  final List<StatLeaderCategory> categories;

  /// Per-team season statistics — 112 stats per team from the bundled package.
  /// Empty for competitions the package doesn't cover.
  final List<TeamSeasonStats> teamStats;

  /// Stat metadata keyed by ESPN stat name.
  final Map<String, LeagueStatDefinition> statDefinitions;

  /// Season headline, e.g. "2026 MLS".
  final String? seasonLabel;

  /// ESPN's numeric season, kept so a player dossier can request the exact
  /// campaign represented by this leaderboard rather than guessing a year.
  final int? seasonYear;

  bool get isEmpty => groups.isEmpty && categories.isEmpty && teamStats.isEmpty;

  bool get hasTeamStats => teamStats.isNotEmpty;

  /// Every standings row across all groups.
  List<TeamStanding> get allRows => [for (final g in groups) ...g.rows];

  /// Every team ranked by [stat], best first. [lowerIsBetter] flips the order
  /// for stats where a small number is the good outcome (goals conceded,
  /// cards). Teams missing the stat are dropped rather than ranked as zero.
  List<TeamStatEntry> boardFor(String stat, {bool lowerIsBetter = false}) {
    final scored = <(TeamSeasonStats, TeamStatValue)>[];
    for (final team in teamStats) {
      final value = team[stat];
      if (value != null) scored.add((team, value));
    }
    scored.sort(
      (a, b) => lowerIsBetter
          ? a.$2.value.compareTo(b.$2.value)
          : b.$2.value.compareTo(a.$2.value),
    );
    return [
      for (var i = 0; i < scored.length; i++)
        TeamStatEntry(
          rank: i + 1,
          team: scored[i].$1.team,
          value: scored[i].$2.value,
          display: scored[i].$2.display,
        ),
    ];
  }

  /// League-wide total of [stat] across every team.
  double totalOf(String stat) {
    var sum = 0.0;
    for (final team in teamStats) {
      sum += team[stat]?.value ?? 0;
    }
    return sum;
  }

  LeagueStatsSnapshot withCategory(int index, StatLeaderCategory category) {
    final next = [...categories];
    next[index] = category;
    return LeagueStatsSnapshot(
      groups: groups,
      categories: next,
      teamStats: teamStats,
      statDefinitions: statDefinitions,
      seasonLabel: seasonLabel,
      seasonYear: seasonYear,
    );
  }

  /// Layers live feed data over the bundled package, keeping whichever side
  /// actually has content — an empty live section never blanks a filled one.
  LeagueStatsSnapshot mergedWith(LeagueStatsSnapshot live) {
    if (live.isEmpty) return this;
    final keepResolvedCategories =
        categories.isNotEmpty &&
        categories.every((category) => category.isResolved) &&
        live.categories.any((category) => !category.isResolved);
    return LeagueStatsSnapshot(
      groups: live.groups.isEmpty ? groups : live.groups,
      categories: live.categories.isEmpty || keepResolvedCategories
          ? categories
          : live.categories,
      teamStats: live.teamStats.isEmpty ? teamStats : live.teamStats,
      statDefinitions: live.statDefinitions.isEmpty
          ? statDefinitions
          : live.statDefinitions,
      seasonLabel: live.seasonLabel ?? seasonLabel,
      seasonYear: live.seasonYear ?? seasonYear,
    );
  }

  /// Attaches per-club season statistics fetched after the fact — the STATS
  /// tab pulls them lazily, so they arrive later than the rest of the hub.
  LeagueStatsSnapshot withTeamStats(LeagueTeamStats stats) {
    if (stats.isEmpty) return this;
    return LeagueStatsSnapshot(
      groups: groups,
      categories: categories,
      teamStats: stats.teams,
      statDefinitions: stats.definitions,
      seasonLabel: seasonLabel,
      seasonYear: seasonYear,
    );
  }
}
