class CricketScorecard {
  const CricketScorecard({
    required this.innings,
  });
  final List<CricketInnings> innings;
}

class CricketInnings {
  const CricketInnings({
    required this.teamName,
    required this.scoreText, // e.g. "171 (20 ov)"
    required this.batters,
    required this.bowlers,
    this.didNotBat = const [],
    this.extras = '',
    this.fow = const [],
  });
  final String teamName;
  final String scoreText;
  final List<CricketBatter> batters;
  final List<CricketBowler> bowlers;
  final List<String> didNotBat;
  final String extras;
  final List<String> fow;
}

class CricketBatter {
  const CricketBatter({
    required this.name,
    required this.runs,
    required this.balls,
    required this.fours,
    required this.sixes,
    required this.strikeRate,
    this.dismissalText,
  });
  final String name;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final double strikeRate;
  final String? dismissalText; // e.g. "c Arshdeep Singh b Patel", null means not out
}

class CricketBowler {
  const CricketBowler({
    required this.name,
    required this.overs,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.economyRate,
  });
  final String name;
  final double overs;
  final int maidens;
  final int runs;
  final int wickets;
  final double economyRate;
}
