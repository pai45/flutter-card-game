/// App-side model for Final Over — the bits the *game* needs that the rules
/// engine (the `final_over` package) deliberately knows nothing about: which
/// kit you picked, how hard a chase you asked for, what you have achieved
/// across sessions, and what a chase is worth in XP.
library;

import 'package:final_over/final_over.dart' show GameplayTuning;

/// How steep a chase to set. The engine picks the actual target from its
/// approved ladder (8, 10, 12, 14, 16, 18, 20); a tier just says which rungs
/// are in play.
enum FinalOverTier { rookie, pro, elite }

extension FinalOverTierX on FinalOverTier {
  String get label => switch (this) {
    FinalOverTier.rookie => 'ROOKIE',
    FinalOverTier.pro => 'PRO',
    FinalOverTier.elite => 'ELITE',
  };

  /// The blurb under the tier tile — the whole pitch in six words.
  String get blurb => switch (this) {
    FinalOverTier.rookie => 'GET YOUR EYE IN',
    FinalOverTier.pro => 'THE HONEST CHASE',
    FinalOverTier.elite => 'BOUNDARIES OR BUST',
  };

  /// Targets this tier draws from. Every value is on the engine's ladder — do
  /// not invent one, or [GameplayTuning.targetOptions] and the balance report
  /// stop meaning anything.
  List<int> get targets => switch (this) {
    FinalOverTier.rookie => const [8, 10],
    FinalOverTier.pro => const [10, 12, 14],
    FinalOverTier.elite => const [16, 18, 20],
  };

  String get range => '${targets.first}–${targets.last}';

  /// Elite chases are worth more because they are, in fact, harder.
  double get xpMultiplier => switch (this) {
    FinalOverTier.rookie => 0.8,
    FinalOverTier.pro => 1.0,
    FinalOverTier.elite => 1.35,
  };

  /// What the tier actually *means*, mechanically. A tier that only moved the
  /// target left every chase equally razor-thin: the engine's default windows
  /// are elite windows, and nothing widened them for a beginner. So each tier
  /// now brings its own timing windows, its own wickets in hand, its own
  /// slip-fingered or safe-handed fielders, and its own OVERDRIVE price.
  ///
  /// Engine defaults are left alone and reproduced exactly by [elite] — the
  /// package's own balance suite still measures the game it was tuned against.
  GameplayTuning get tuning => switch (this) {
    FinalOverTier.rookie => GameplayTuning.rookie,
    FinalOverTier.pro => GameplayTuning.pro,
    FinalOverTier.elite => GameplayTuning.elite,
  };
}

/// Everything needed to start one chase.
class FinalOverMatchConfig {
  const FinalOverMatchConfig({
    required this.matchId,
    required this.seed,
    required this.tier,
    required this.target,
    required this.kitId,
    required this.batsmanIds,
    this.showHints = false,
  });

  final String matchId;
  final int seed;
  final FinalOverTier tier;
  final int target;
  final String kitId;
  final List<String> batsmanIds;

  /// First chase only — the control deck explains itself, then never again.
  final bool showHints;
}

/// The result of one chase, as the app cares about it.
class FinalOverMatchSummary {
  const FinalOverMatchSummary({
    required this.matchId,
    required this.won,
    required this.tier,
    required this.runs,
    required this.target,
    required this.wickets,
    required this.legalBalls,
    required this.stars,
    required this.objectiveCompleted,
    required this.sixes,
    required this.fours,
    required this.bestCombo,
    required this.xp,
  });

  final String matchId;
  final bool won;
  final FinalOverTier tier;
  final int runs;
  final int target;
  final int wickets;
  final int legalBalls;
  final int stars;
  final bool objectiveCompleted;
  final int sixes;
  final int fours;
  final int bestCombo;
  final int xp;

  int get ballsToSpare => won ? (6 - legalBalls).clamp(0, 6) : 0;

  String get scoreLine => '$runs/$wickets';

  String get resultLabel => won ? 'CHASE COMPLETE' : 'CHASE FAILED';

  /// A letter grade for the result plate. Stars come from the engine; this is
  /// the same information said louder.
  String get grade {
    if (!won) return stars >= 2 ? 'C' : 'D';
    if (stars >= 3 && ballsToSpare >= 2) return 'S';
    if (stars >= 3) return 'A';
    if (stars >= 2) return 'B';
    return 'C';
  }
}

/// Career totals. Persisted; drives the lobby's record panel.
class FinalOverStats {
  const FinalOverStats({
    this.chases = 0,
    this.wins = 0,
    this.bestScore = 0,
    this.bestStars = 0,
    this.sixes = 0,
    this.fours = 0,
    this.bestCombo = 0,
    this.hintsSeen = false,
    this.kitId = 'voltage',
    this.tier = FinalOverTier.rookie,
  });

  final int chases;
  final int wins;
  final int bestScore;
  final int bestStars;
  final int sixes;
  final int fours;
  final int bestCombo;
  final bool hintsSeen;

  /// Lobby selections ride along with the stats — one blob, one write.
  final String kitId;
  final FinalOverTier tier;

  int get losses => (chases - wins).clamp(0, chases);

  String get winRate =>
      chases == 0 ? '—' : '${((wins / chases) * 100).round()}%';

  FinalOverStats merge(FinalOverMatchSummary s) => copyWith(
    chases: chases + 1,
    wins: wins + (s.won ? 1 : 0),
    bestScore: s.runs > bestScore ? s.runs : bestScore,
    bestStars: s.stars > bestStars ? s.stars : bestStars,
    sixes: sixes + s.sixes,
    fours: fours + s.fours,
    bestCombo: s.bestCombo > bestCombo ? s.bestCombo : bestCombo,
  );

  FinalOverStats copyWith({
    int? chases,
    int? wins,
    int? bestScore,
    int? bestStars,
    int? sixes,
    int? fours,
    int? bestCombo,
    bool? hintsSeen,
    String? kitId,
    FinalOverTier? tier,
  }) => FinalOverStats(
    chases: chases ?? this.chases,
    wins: wins ?? this.wins,
    bestScore: bestScore ?? this.bestScore,
    bestStars: bestStars ?? this.bestStars,
    sixes: sixes ?? this.sixes,
    fours: fours ?? this.fours,
    bestCombo: bestCombo ?? this.bestCombo,
    hintsSeen: hintsSeen ?? this.hintsSeen,
    kitId: kitId ?? this.kitId,
    tier: tier ?? this.tier,
  );

  Map<String, dynamic> toJson() => {
    'chases': chases,
    'wins': wins,
    'bestScore': bestScore,
    'bestStars': bestStars,
    'sixes': sixes,
    'fours': fours,
    'bestCombo': bestCombo,
    'hintsSeen': hintsSeen,
    'kitId': kitId,
    'tier': tier.name,
  };

  factory FinalOverStats.fromJson(Map<String, dynamic> json) => FinalOverStats(
    chases: json['chases'] as int? ?? 0,
    wins: json['wins'] as int? ?? 0,
    bestScore: json['bestScore'] as int? ?? 0,
    bestStars: json['bestStars'] as int? ?? 0,
    sixes: json['sixes'] as int? ?? 0,
    fours: json['fours'] as int? ?? 0,
    bestCombo: json['bestCombo'] as int? ?? 0,
    hintsSeen: json['hintsSeen'] as bool? ?? false,
    kitId: json['kitId'] as String? ?? 'voltage',
    tier: FinalOverTier.values.firstWhere(
      (t) => t.name == json['tier'],
      orElse: () => FinalOverTier.rookie,
    ),
  );
}

/// What a chase pays.
///
/// Deliberately generous on effort and stingy on repetition: you are rewarded
/// for runs you actually scored, for the stars the engine awarded, and for
/// finishing early — not for pressing PLAY. Losing still pays, because a
/// six-ball chase you lost by two runs was a better game than one you won by
/// ten, and the player should not resent having played it.
int calculateFinalOverXp({
  required bool won,
  required int runs,
  required int wickets,
  required int stars,
  required bool objectiveCompleted,
  required int ballsToSpare,
  required FinalOverTier tier,
}) {
  var xp = won ? 30 : 10;
  xp += runs; // every run off the bat is worth something
  xp += stars * 8;
  if (objectiveCompleted) xp += 15;
  if (won) xp += ballsToSpare * 4; // finishing with balls in hand
  if (won && wickets == 0) xp += 10; // an unbeaten chase
  return (xp * tier.xpMultiplier).round();
}
