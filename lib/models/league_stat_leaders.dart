import 'package:flutter/material.dart';

import 'sport_match.dart';
import 'team_standing.dart';

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

  double get topValue => leaders.isEmpty ? 0 : leaders.first.value;

  StatLeaderCategory withLeaders(List<StatLeader> next) => StatLeaderCategory(
    key: key,
    label: label,
    unitLabel: unitLabel,
    accent: accent,
    leaders: next,
  );
}

/// Everything the league hub shows from the live ESPN feed for one league.
@immutable
class LeagueStatsSnapshot {
  const LeagueStatsSnapshot({
    required this.groups,
    required this.categories,
    this.seasonLabel,
  });

  static const empty = LeagueStatsSnapshot(groups: [], categories: []);

  /// Standings sub-tables. One entry for a flat league, two for MLS.
  final List<StandingsGroup> groups;

  final List<StatLeaderCategory> categories;

  /// Season headline, e.g. "2026 MLS".
  final String? seasonLabel;

  bool get isEmpty => groups.isEmpty && categories.isEmpty;

  /// Every standings row across all groups.
  List<TeamStanding> get allRows => [for (final g in groups) ...g.rows];

  LeagueStatsSnapshot withCategory(int index, StatLeaderCategory category) {
    final next = [...categories];
    next[index] = category;
    return LeagueStatsSnapshot(
      groups: groups,
      categories: next,
      seasonLabel: seasonLabel,
    );
  }
}
