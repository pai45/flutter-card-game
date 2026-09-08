import 'package:flutter/foundation.dart';

import 'sport_match.dart';

/// One ESPN athlete normalized for a season-scoped club roster.
@immutable
class TeamSeasonPlayer {
  const TeamSeasonPlayer({
    required this.id,
    required this.teamId,
    required this.name,
    this.shortName,
    this.jersey,
    this.role,
    this.positionAbbreviation,
    this.nationality,
    this.flagUrl,
    this.stats = const {},
  });

  final String id;
  final String teamId;
  final String name;
  final String? shortName;
  final String? jersey;
  final String? role;
  final String? positionAbbreviation;
  final String? nationality;
  final String? flagUrl;
  final Map<String, num> stats;

  String get displayRole {
    final value = role?.trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'unknown') {
      return 'PLAYER';
    }
    return value.toUpperCase();
  }
}

/// Everything needed by the three tabs in a team hub.
@immutable
class TeamHubData {
  const TeamHubData({
    required this.leagueId,
    required this.teamId,
    required this.seasonYear,
    required this.seasonLabel,
    this.fixtures = const [],
    this.players = const [],
  });

  final String leagueId;
  final String teamId;
  final int seasonYear;
  final String seasonLabel;
  final List<SportMatch> fixtures;
  final List<TeamSeasonPlayer> players;

  TeamHubData mergedWith(TeamHubData live) {
    final fixturesById = <String, SportMatch>{
      for (final fixture in fixtures) fixture.id: fixture,
      for (final fixture in live.fixtures) fixture.id: fixture,
    };
    final playersById = <String, TeamSeasonPlayer>{
      for (final player in players) player.id: player,
      for (final player in live.players) player.id: player,
    };
    final mergedFixtures = fixturesById.values.toList()
      ..sort((a, b) => b.kickoff.compareTo(a.kickoff));
    final mergedPlayers = playersById.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return TeamHubData(
      leagueId: leagueId,
      teamId: teamId,
      seasonYear: seasonYear,
      seasonLabel: live.seasonLabel.isEmpty ? seasonLabel : live.seasonLabel,
      fixtures: mergedFixtures,
      players: mergedPlayers,
    );
  }
}
