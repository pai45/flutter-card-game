class TennisScorecard {
  const TennisScorecard({
    required this.sets,
  });
  final List<TennisSet> sets;
}

class TennisSet {
  const TennisSet({
    required this.homeScore,
    required this.awayScore,
    this.homeTiebreak,
    this.awayTiebreak,
    this.isHomeWinner = false,
    this.isAwayWinner = false,
  });
  final int homeScore;
  final int awayScore;
  final int? homeTiebreak;
  final int? awayTiebreak;
  final bool isHomeWinner;
  final bool isAwayWinner;
}
