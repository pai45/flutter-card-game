import 'package:flutter/foundation.dart';

import 'league_stat_leaders.dart';
import 'sport_match.dart';

/// One ESPN season-stat row for an athlete dossier.
@immutable
class FootballPlayerSeasonStat {
  const FootballPlayerSeasonStat({
    required this.key,
    required this.label,
    required this.displayValue,
    required this.value,
  });

  final String key;
  final String label;
  final String displayValue;
  final double value;
}

/// One ESPN season-stat family. The feed currently exposes offensive,
/// defensive, general and goalkeeping groups.
@immutable
class FootballPlayerSeasonStatGroup {
  const FootballPlayerSeasonStatGroup({
    required this.key,
    required this.label,
    required this.stats,
  });

  final String key;
  final String label;
  final List<FootballPlayerSeasonStat> stats;

  FootballPlayerSeasonStat? stat(String key) {
    for (final entry in stats) {
      if (entry.key == key) return entry;
    }
    return null;
  }
}

/// Player identity and the exact regular-season stat split behind a league
/// leaderboard. Nullable fields are optional in ESPN's source, not invented.
@immutable
class FootballPlayerProfile {
  const FootballPlayerProfile({
    required this.athleteId,
    required this.name,
    required this.team,
    required this.seasonYear,
    required this.statGroups,
    this.shortName,
    this.position,
    this.jersey,
    this.age,
    this.dateOfBirth,
    this.displayHeight,
    this.displayWeight,
    this.citizenship,
    this.flagUrl,
    this.active,
    this.fromEspn = true,
  });

  final String athleteId;
  final String name;
  final String? shortName;
  final SportTeam? team;
  final int? seasonYear;
  final String? position;
  final String? jersey;
  final int? age;
  final DateTime? dateOfBirth;
  final String? displayHeight;
  final String? displayWeight;
  final String? citizenship;
  final String? flagUrl;
  final bool? active;
  final List<FootballPlayerSeasonStatGroup> statGroups;

  /// False for the leaderboard identity shell shown when ESPN is unavailable.
  final bool fromEspn;

  FootballPlayerSeasonStat? stat(String key) {
    for (final group in statGroups) {
      final found = group.stat(key);
      if (found != null) return found;
    }
    return null;
  }

  factory FootballPlayerProfile.seed({
    required StatLeader leader,
    required int? seasonYear,
  }) => FootballPlayerProfile(
    athleteId: leader.athleteId,
    name: leader.name ?? 'UNKNOWN PLAYER',
    team: leader.team,
    seasonYear: seasonYear,
    position: leader.position,
    flagUrl: leader.flagUrl,
    statGroups: const [],
    fromEspn: false,
  );
}
