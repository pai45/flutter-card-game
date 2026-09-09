import 'package:flutter/material.dart';

import 'sport_match.dart';

/// One row of a league standings table, shaped for three sports:
/// football (P/W/D/L/GD/PTS), cricket (P/W/L/NRR/PTS) and basketball
/// (W/L/PCT/GB). The table picks its layout off the data — a non-null
/// [winPercent] means basketball, and a null [drawn] after that means cricket.
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
    this.winPercent,
    this.streak,
    this.lastTen,
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

  /// Basketball only. Win percentage as a 0-1 fraction, which is the column an
  /// NBA table is actually ordered by — and the signal that selects the
  /// basketball layout, since a sport with no draws would otherwise be read as
  /// cricket.
  final double? winPercent;

  /// Current run, already formatted by the feed, e.g. "W3".
  final String? streak;

  /// Record over the last ten games, e.g. "8-2". Basketball's answer to
  /// football's form pips, which need a per-match sequence the feed does not
  /// publish for the NBA.
  final String? lastTen;
}
