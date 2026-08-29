class CricketScorecard {
  const CricketScorecard({required this.innings});
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
    this.number,
    this.runs,
    this.wickets,
    this.overs,
    this.runRate,
    this.target,
    this.extrasBreakdown,
    this.fallOfWickets = const [],
    this.partnerships = const [],
  });
  final String teamName;
  final String scoreText;
  final List<CricketBatter> batters;
  final List<CricketBowler> bowlers;
  final List<String> didNotBat;
  final String extras;
  final List<String> fow;
  final int? number;
  final int? runs;
  final int? wickets;
  final double? overs;
  final double? runRate;
  final int? target;
  final CricketExtras? extrasBreakdown;
  final List<CricketFallOfWicket> fallOfWickets;
  final List<CricketPartnership> partnerships;
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
    this.id,
    this.position,
    this.minutes,
    this.notOut = false,
    this.milestone,
  });
  final String name;
  final int runs;
  final int balls;
  final int fours;
  final int sixes;
  final double strikeRate;
  final String?
  dismissalText; // e.g. "c Arshdeep Singh b Patel", null means not out
  final String? id;
  final int? position;
  final int? minutes;
  final bool notOut;
  final String? milestone;
}

class CricketBowler {
  const CricketBowler({
    required this.name,
    required this.overs,
    required this.maidens,
    required this.runs,
    required this.wickets,
    required this.economyRate,
    this.id,
    this.position,
    this.balls,
    this.dots,
    this.wides,
    this.noBalls,
    this.foursConceded,
    this.sixesConceded,
  });
  final String name;
  final double overs;
  final int maidens;
  final int runs;
  final int wickets;
  final double economyRate;
  final String? id;
  final int? position;
  final int? balls;
  final int? dots;
  final int? wides;
  final int? noBalls;
  final int? foursConceded;
  final int? sixesConceded;
}

class CricketExtras {
  const CricketExtras({
    required this.total,
    required this.wides,
    required this.noBalls,
    required this.byes,
    required this.legByes,
  });
  final int total;
  final int wides;
  final int noBalls;
  final int byes;
  final int legByes;
}

class CricketFallOfWicket {
  const CricketFallOfWicket({
    required this.wicket,
    required this.score,
    required this.runs,
    required this.overs,
    required this.batter,
  });
  final int wicket;
  final String score;
  final int runs;
  final double overs;
  final String batter;
}

class CricketPartnershipBatter {
  const CricketPartnershipBatter({required this.name, required this.runs});
  final String name;
  final int runs;
}

class CricketPartnership {
  const CricketPartnership({
    required this.wicket,
    required this.runs,
    required this.overs,
    required this.batters,
  });
  final String wicket;
  final int runs;
  final double overs;
  final List<CricketPartnershipBatter> batters;
}
