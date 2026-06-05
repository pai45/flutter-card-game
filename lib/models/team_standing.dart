import 'sport_match.dart';

/// One row of a league standings table. Designed for both football
/// (P/W/D/L/GD/Pts) and cricket (P/W/L/NRR/Pts) — the table hides the drawn
/// column when [drawn] is null.
///
/// Mock-seeded for now (see [MockPredictionRepository.standings]); maps cleanly
/// to a backend/sports-feed payload later without any UI change.
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
}
