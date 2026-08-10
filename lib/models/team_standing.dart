import 'package:flutter/material.dart';

import 'sport_match.dart';

/// One row of a league standings table. Designed for both football
/// (P/W/D/L/GD/Pts) and cricket (P/W/L/NRR/Pts) — the table hides the drawn
/// column when [drawn] is null.
///
/// Mock-seeded for now (see [MockPredictionRepository.standings]); maps cleanly
/// to a backend/sports-feed payload later without any UI change. The optional
/// fields below are populated from the live ESPN standings feed
/// ([EspnLeagueStatsService]) and are all null for mock/cricket rows.
class TeamStanding {
  const TeamStanding({
    required this.team,
    required this.rank,
    required this.played,
    required this.won,
    required this.lost,
    required this.points,
    required this.diffLabel,
    required this.form,
    this.drawn,
    this.group,
    this.tableName,
    this.goalsFor,
    this.goalsAgainst,
    this.zoneNote,
    this.zoneColor,
    this.rankChange,
  });

  final SportTeam team;
  final int rank;
  final int played;
  final int won;
  final int lost;

  /// Football only; null for cricket (which has no draws table column).
  final int? drawn;

  final int points;

  /// Display-ready difference: goal difference ("+41") for football or net run
  /// rate ("+1.42") for cricket.
  final String diffLabel;

  /// Recent results, most recent last, e.g. "WWDLW". Each char is W / D / L.
  final String form;

  /// The sub-table this row belongs to, e.g. "Eastern Conference" for MLS.
  /// Null for flat, single-table leagues.
  final String? group;

  /// Table-friendly club name from the feed ("Revolution" for "New England
  /// Revolution"), used where the row is too narrow for [SportTeam.name].
  final String? tableName;

  /// Goals scored / conceded, when the feed supplies them.
  final int? goalsFor;
  final int? goalsAgainst;

  /// Qualification-zone description from the feed, e.g. "Qualifies for MLS Cup
  /// Playoffs". Rows sharing a note sit in the same zone, so a change of note
  /// between consecutive ranks is where the playoff line gets drawn.
  final String? zoneNote;

  /// The feed's colour for [zoneNote].
  final Color? zoneColor;

  /// Positions gained (+) or lost (-) since the last update; 0 or null = same.
  final int? rankChange;
}
