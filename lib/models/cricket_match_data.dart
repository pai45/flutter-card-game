class CricketMatchDetails {
  const CricketMatchDetails({
    required this.league,
    required this.leagueAbbreviation,
    required this.season,
    required this.title,
    required this.stage,
    required this.format,
    required this.formatName,
    required this.status,
    required this.state,
    required this.result,
    required this.seriesNote,
    required this.venue,
    required this.city,
    required this.country,
    required this.neutralSite,
    required this.toss,
    required this.innings,
    required this.awards,
    required this.officials,
    required this.notes,
    required this.commentary,
    this.inningsProgress = const [],
    this.inningsRateProgress = const [],
    required this.teams,
  });

  final String league;
  final String leagueAbbreviation;
  final int season;
  final String title;
  final String stage;
  final String format;
  final String formatName;
  final String status;
  final String state;
  final String result;
  final String seriesNote;
  final String venue;
  final String city;
  final String country;
  final bool neutralSite;
  final CricketToss toss;
  final List<CricketInningsSummary> innings;
  final List<CricketAward> awards;
  final List<CricketOfficial> officials;
  final List<CricketMatchNote> notes;
  final List<CricketBallCommentary> commentary;
  final List<CricketInningsProgress> inningsProgress;
  final List<CricketInningsRateProgress> inningsRateProgress;
  final List<CricketTeamSquad> teams;
}

/// Verified cumulative scoring samples for one innings. These live separately
/// from the compact commentary feed so reports can render a full match race
/// without inflating the player-facing ball feed.
class CricketInningsProgress {
  const CricketInningsProgress({
    required this.innings,
    required this.teamId,
    required this.points,
  });

  final int innings;
  final String teamId;
  final List<CricketScoreProgressPoint> points;
}

/// The score at the end of one completed over.
class CricketScoreProgressPoint {
  const CricketScoreProgressPoint({
    required this.over,
    required this.runs,
    required this.wickets,
    required this.wicket,
  });

  final int over;
  final int runs;
  final int wickets;
  final bool wicket;
}

/// Complete legal-delivery progression for one batting innings. The compact
/// match feed can stay editorial while charts still have every plotted ball.
class CricketInningsRateProgress {
  const CricketInningsRateProgress({
    required this.innings,
    required this.teamId,
    required this.points,
  });

  final int innings;
  final String teamId;
  final List<CricketInningsRatePoint> points;
}

class CricketInningsRatePoint {
  const CricketInningsRatePoint({
    required this.innings,
    required this.teamId,
    required this.over,
    required this.legalBall,
    required this.runs,
    this.boundary,
  });

  final int innings;
  final String teamId;
  final String over;
  final int legalBall;
  final int runs;
  final int? boundary;

  double get runRate => legalBall == 0 ? 0 : runs * 6 / legalBall;

  double requiredRunRate({required int target, int totalLegalBalls = 120}) {
    final remainingRuns = (target - runs).clamp(0, target);
    if (remainingRuns == 0) return 0;
    final remainingBalls = totalLegalBalls - legalBall;
    if (remainingBalls <= 0) return double.infinity;
    return remainingRuns * 6 / remainingBalls;
  }
}

class CricketToss {
  const CricketToss({required this.team, required this.decision});
  final String team;
  final String decision;
}

class CricketInningsSummary {
  const CricketInningsSummary({
    required this.number,
    required this.team,
    required this.teamId,
    required this.abbreviation,
    required this.runs,
    required this.wickets,
    required this.overs,
    required this.fours,
    required this.sixes,
    required this.score,
    required this.description,
    required this.current,
    this.target,
  });
  final int number;
  final String team;
  final String teamId;
  final String abbreviation;
  final int runs;
  final int wickets;
  final double overs;
  final int fours;
  final int sixes;
  final int? target;
  final String score;
  final String description;
  final bool current;
}

class CricketAward {
  const CricketAward({
    required this.id,
    required this.name,
    required this.award,
    required this.team,
    required this.teamId,
  });
  final String id;
  final String name;
  final String award;
  final String team;
  final String teamId;
}

class CricketOfficial {
  const CricketOfficial({
    required this.name,
    required this.role,
    required this.country,
  });
  final String name;
  final String role;
  final String country;
}

class CricketMatchNote {
  const CricketMatchNote({
    required this.id,
    required this.innings,
    required this.day,
    required this.kind,
    required this.text,
  });
  final String id;
  final int innings;
  final int day;
  final String kind;
  final String text;
}

class CricketRequiredRate {
  const CricketRequiredRate({
    required this.runs,
    required this.balls,
    required this.runRate,
  });
  final int runs;
  final int balls;
  final double runRate;
}

class CricketBallCommentary {
  const CricketBallCommentary({
    required this.id,
    required this.sequence,
    required this.innings,
    required this.over,
    required this.overNumber,
    required this.ball,
    required this.batter,
    required this.bowler,
    required this.runs,
    required this.boundary,
    required this.wicket,
    required this.score,
    required this.runRate,
    required this.shortText,
    required this.text,
    this.dismissal,
    this.required,
    this.preText,
    this.postText,
  });
  final String id;
  final int sequence;
  final int innings;
  final String over;
  final int overNumber;
  final int ball;
  final String batter;
  final String bowler;
  final int runs;
  final bool boundary;
  final bool wicket;
  final String? dismissal;
  final String score;
  final double runRate;
  final CricketRequiredRate? required;
  final String shortText;
  final String text;
  final String? preText;
  final String? postText;
}

class CricketTeamSquad {
  const CricketTeamSquad({
    required this.id,
    required this.name,
    required this.abbreviation,
    required this.isHome,
    required this.captain,
    required this.keeper,
    required this.squadPublished,
    required this.playerCount,
    required this.players,
  });
  final String id;
  final String name;
  final String abbreviation;
  final bool isHome;
  final String captain;
  final String keeper;
  final bool squadPublished;
  final int playerCount;
  final List<CricketSquadPlayer> players;
}

class CricketPlayerPerformance {
  const CricketPlayerPerformance({
    required this.innings,
    this.battingScore,
    this.bowlingFigures,
    this.catches = 0,
    this.stumpings = 0,
  });
  final int innings;
  final String? battingScore;
  final String? bowlingFigures;
  final int catches;
  final int stumpings;
}

class CricketSquadPlayer {
  const CricketSquadPlayer({
    required this.id,
    required this.name,
    required this.fullName,
    required this.battingName,
    required this.role,
    required this.keeper,
    required this.captain,
    required this.starter,
    required this.subbedIn,
    required this.subbedOut,
    required this.active,
    required this.battingStyle,
    required this.bowlingStyle,
    required this.performances,
    this.matchStats,
  });
  final String id;
  final String name;
  final String fullName;
  final String battingName;
  final String role;
  final bool keeper;
  final bool captain;
  final bool starter;
  final bool subbedIn;
  final bool subbedOut;
  final bool active;
  final String battingStyle;
  final String bowlingStyle;
  final List<CricketPlayerPerformance> performances;

  /// What this player actually did in this match. Null when the package
  /// predates the generated player layer, or on a feed that carries no sheet.
  final CricketPlayerMatchStats? matchStats;

  /// "Left-hand bat // Right-arm medium", skipping whichever half is blank.
  String get styleLine => [
    if (battingStyle.isNotEmpty) battingStyle,
    if (bowlingStyle.isNotEmpty) bowlingStyle,
  ].join('  //  ');
}

/// What happened on one delivery.
///
/// ESPN publishes **no positional data for cricket** — no wagon wheel, no pitch
/// map, no line and length; the core plays feed that carries soccer's
/// coordinates does not exist for this sport. So a delivery is a point in a
/// sequence, not a point in space, and everything built on it reads as a
/// timeline rather than a map.
class CricketDelivery {
  const CricketDelivery({
    required this.innings,
    required this.over,
    required this.ball,
    required this.batterId,
    required this.bowlerId,
    required this.runs,
    required this.outcome,
    required this.isWicket,
  });

  final int innings;

  /// 1-based over (1..20 in a T20).
  final int over;

  /// 1-based delivery within the over, counting extras.
  final int ball;

  final String batterId;
  final String bowlerId;

  /// Runs credited by the feed for this ball, including extras. Use
  /// [runsOffTheBat] for the batter's own account.
  final int runs;

  final CricketBallOutcome outcome;
  final bool isWicket;

  /// A wide is not a ball faced; a leg bye is. Verified against the stat sheet:
  /// this rule reproduces every batter's `ballsFaced` exactly.
  bool get countsAsBallFaced => outcome != CricketBallOutcome.wide;

  /// Extras are not the batter's runs.
  int get runsOffTheBat => switch (outcome) {
    CricketBallOutcome.wide || CricketBallOutcome.legBye => 0,
    _ => runs,
  };

  bool get isBoundary =>
      outcome == CricketBallOutcome.four || outcome == CricketBallOutcome.six;

  CricketMatchPhase get phase => CricketMatchPhase.forOver(over);
}

/// The outcomes the feed distinguishes. [other] keeps an unfamiliar future
/// value renderable instead of crashing the tape.
enum CricketBallOutcome { dot, run, four, six, wide, legBye, wicket, other }

/// Reads the feed's own wording. Kept as a lookup rather than an index so the
/// asset's `deliveryOutcomes` list can grow without shifting meanings.
CricketBallOutcome cricketBallOutcomeFor(String raw) => switch (raw) {
  'no run' => CricketBallOutcome.dot,
  'run' => CricketBallOutcome.run,
  'four' => CricketBallOutcome.four,
  'six' => CricketBallOutcome.six,
  'wide' => CricketBallOutcome.wide,
  'leg bye' || 'bye' => CricketBallOutcome.legBye,
  'out' => CricketBallOutcome.wicket,
  _ => CricketBallOutcome.other,
};

/// The three phases a T20 innings is read in.
enum CricketMatchPhase {
  powerplay,
  middle,
  death;

  /// Overs 1-6 / 7-15 / 16-20, the standard T20 split.
  static CricketMatchPhase forOver(int over) {
    if (over <= 6) return CricketMatchPhase.powerplay;
    if (over <= 15) return CricketMatchPhase.middle;
    return CricketMatchPhase.death;
  }

  String get label => switch (this) {
    CricketMatchPhase.powerplay => 'POWERPLAY',
    CricketMatchPhase.middle => 'MIDDLE',
    CricketMatchPhase.death => 'DEATH',
  };
}

/// Which board a per-player match stat belongs on.
enum CricketStatGroup { batting, bowling, fielding }

/// Semantic weight of a stat, mapped to a palette colour by the UI. An enum so
/// this file stays import-free and purely a model.
enum CricketStatTone { neutral, good, caution }

/// One entry on the per-player match sheet, with our own label copy.
class CricketStatDescriptor {
  const CricketStatDescriptor(
    this.key,
    this.label,
    this.group, {
    this.tone = CricketStatTone.neutral,
  });

  final String key;
  final String label;
  final CricketStatGroup group;
  final CricketStatTone tone;
}

/// The stats worth showing out of the 46 ESPN publishes per player.
///
/// The feed's block is a union of batting, bowling and fielding, so a batter
/// carries zeroed bowling keys and vice versa. The card decides what to show
/// from [CricketPlayerMatchStats.didBat] / [CricketPlayerMatchStats.didBowl]
/// rather than from the presence of a key.
///
/// Deliberately curated, not exhaustive. Left out: `bpo`, `illegalOverLimit`,
/// `retiredDescription` and `dismissalCard` (chrome); the season-shaped
/// counters `tenWickets`, `fiveWickets` and `hundreds` (always 0 in a T20);
/// and `dismissal`, which is a dismissal-TYPE code rather than a count — it
/// reads 12 for a not-out batter, so rendering it as a number would be
/// nonsense.
const kCricketPlayerStatCatalog = <CricketStatDescriptor>[
  CricketStatDescriptor('runs', 'RUNS', CricketStatGroup.batting),
  CricketStatDescriptor('ballsFaced', 'BALLS', CricketStatGroup.batting),
  CricketStatDescriptor('fours', 'FOURS', CricketStatGroup.batting),
  CricketStatDescriptor('sixes', 'SIXES', CricketStatGroup.batting),
  CricketStatDescriptor('strikeRate', 'STRIKE RATE', CricketStatGroup.batting),
  CricketStatDescriptor(
    'battingPosition',
    'BAT POS',
    CricketStatGroup.batting,
  ),
  CricketStatDescriptor('minutes', 'MINUTES', CricketStatGroup.batting),
  CricketStatDescriptor(
    'fiftyPlus',
    'FIFTIES',
    CricketStatGroup.batting,
    tone: CricketStatTone.good,
  ),
  CricketStatDescriptor(
    'notouts',
    'NOT OUT',
    CricketStatGroup.batting,
    tone: CricketStatTone.good,
  ),
  CricketStatDescriptor(
    'ducks',
    'DUCKS',
    CricketStatGroup.batting,
    tone: CricketStatTone.caution,
  ),
  CricketStatDescriptor(
    'wickets',
    'WICKETS',
    CricketStatGroup.bowling,
    tone: CricketStatTone.good,
  ),
  CricketStatDescriptor('overs', 'OVERS', CricketStatGroup.bowling),
  CricketStatDescriptor('conceded', 'RUNS CONCEDED', CricketStatGroup.bowling),
  CricketStatDescriptor('economyRate', 'ECONOMY', CricketStatGroup.bowling),
  CricketStatDescriptor('maidens', 'MAIDENS', CricketStatGroup.bowling),
  CricketStatDescriptor('dots', 'DOT BALLS', CricketStatGroup.bowling),
  CricketStatDescriptor(
    'wides',
    'WIDES',
    CricketStatGroup.bowling,
    tone: CricketStatTone.caution,
  ),
  CricketStatDescriptor(
    'noballs',
    'NO BALLS',
    CricketStatGroup.bowling,
    tone: CricketStatTone.caution,
  ),
  CricketStatDescriptor(
    'foursConceded',
    'FOURS GIVEN',
    CricketStatGroup.bowling,
  ),
  CricketStatDescriptor('sixesConceded', 'SIXES GIVEN', CricketStatGroup.bowling),
  CricketStatDescriptor(
    'fourPlusWickets',
    'FOUR-FERS',
    CricketStatGroup.bowling,
    tone: CricketStatTone.good,
  ),
  CricketStatDescriptor(
    'caught',
    'CATCHES',
    CricketStatGroup.fielding,
    tone: CricketStatTone.good,
  ),
  CricketStatDescriptor(
    'caughtKeeper',
    'KEEPER CATCHES',
    CricketStatGroup.fielding,
  ),
  CricketStatDescriptor(
    'stumped',
    'STUMPINGS',
    CricketStatGroup.fielding,
    tone: CricketStatTone.good,
  ),
  CricketStatDescriptor('dismissals', 'DISMISSALS', CricketStatGroup.fielding),
];

/// Falls back to a humanised label so a stat ESPN adds later renders as
/// something readable instead of vanishing.
CricketStatDescriptor cricketStatDescriptor(String key) {
  for (final entry in kCricketPlayerStatCatalog) {
    if (entry.key == key) return entry;
  }
  final spaced = key
      .replaceAllMapped(RegExp(r'(?<=[a-z])(?=[A-Z])'), (_) => ' ')
      .toUpperCase();
  return CricketStatDescriptor(key, spaced, CricketStatGroup.fielding);
}

/// One player's record of a single match: ESPN's 46-stat sheet plus the
/// deliveries the ball feed attributes to them.
class CricketPlayerMatchStats {
  const CricketPlayerMatchStats({
    required this.values,
    this.faced = const [],
    this.bowled = const [],
  });

  /// ESPN stat name to value, folded across innings.
  final Map<String, num> values;

  /// Deliveries this player faced, in bowling order.
  final List<CricketDelivery> faced;

  /// Deliveries this player bowled, in bowling order.
  final List<CricketDelivery> bowled;

  num? stat(String key) => values[key];

  int intStat(String key) => values[key]?.round() ?? 0;

  double doubleStat(String key) => values[key]?.toDouble() ?? 0;

  // ESPN reports `batted` as 1 for anyone who came to the crease, which is the
  // honest test — a batter can be dismissed first ball with no runs.
  bool get didBat => intStat('batted') > 0 || faced.isNotEmpty;

  bool get didBowl => doubleStat('overs') > 0 || bowled.isNotEmpty;

  bool get played => didBat || didBowl || intStat('inningsFielded') > 0;

  int get runs => intStat('runs');
  int get ballsFaced => intStat('ballsFaced');
  int get wickets => intStat('wickets');
  int get conceded => intStat('conceded');
  bool get notOut => intStat('notouts') > 0;

  /// "75 (42)", with a `*` for an unbeaten innings.
  String get battingLine => '$runs${notOut ? '*' : ''} ($ballsFaced)';

  /// "2/28".
  String get bowlingLine => '$wickets/$conceded';

  /// Runs that came in boundaries, as a share of the innings. The clearest one
  /// number for how a batter scored rather than how much.
  double get boundaryShare {
    if (runs <= 0) return 0;
    final fromBoundaries = intStat('fours') * 4 + intStat('sixes') * 6;
    return (fromBoundaries / runs).clamp(0.0, 1.0);
  }

  /// Balls faced without scoring — pressure, and not published directly.
  int get dotsFaced =>
      faced.where((d) => d.countsAsBallFaced && d.runsOffTheBat == 0).length;

  /// Runs and balls in one phase of the innings, from the batter's deliveries.
  ({int runs, int balls}) battingPhase(CricketMatchPhase phase) {
    var r = 0;
    var b = 0;
    for (final ball in faced) {
      if (ball.phase != phase) continue;
      r += ball.runsOffTheBat;
      if (ball.countsAsBallFaced) b++;
    }
    return (runs: r, balls: b);
  }

  /// Runs conceded and wickets taken in one phase, from the bowler's
  /// deliveries.
  ({int runs, int wickets, int balls}) bowlingPhase(CricketMatchPhase phase) {
    var r = 0;
    var w = 0;
    var b = 0;
    for (final ball in bowled) {
      if (ball.phase != phase) continue;
      r += ball.runs;
      if (ball.isWicket) w++;
      if (ball.countsAsBallFaced) b++;
    }
    return (runs: r, wickets: w, balls: b);
  }

  bool get hasBallByBall => faced.isNotEmpty || bowled.isNotEmpty;
}
