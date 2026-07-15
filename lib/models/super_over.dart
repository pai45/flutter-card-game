import 'dart:math';

enum TimingTier { perfect, great, good, edgePoor, miss }

enum DeliveryType { pace, slower, spin, yorker }

enum DeliveryLine { off, middle, leg }

enum DeliveryLength { short, good, full, yorker }

enum ShotOutcome { six, four, three, two, one, dot, caught, bowled }

enum ShotSector { off, v, leg }

enum ShotStyle { ground, loft }

enum CricketBattingStyle { anchor, powerHitter, improviser }

enum SuperOverObjectiveType {
  runs,
  attackGap,
  protectWicket,
  boundaries,
  allSectors,
  chaseWithBallRemaining,
  groundRuns,
  winWithoutFinisher,
}

enum SuperOverMode { scoreAttack, chase }

enum SuperOverDifficulty { rookie, pro, allStar }

/// App-level navigation and settlement states. Ball animation is represented
/// separately by [SuperOverPlayPhase], so pausing never destroys play context.
enum SuperOverFlowPhase {
  loading,
  landing,
  deckInvalid,
  modeSelection,
  preMatch,
  targetReveal,
  playing,
  paused,
  quitConfirmation,
  result,
  rewardSettlement,
}

/// Authoritative phases within a single legal delivery.
enum SuperOverPlayPhase {
  fieldReveal,
  intentSelection,
  bowlerPreparation,
  runUp,
  release,
  inputArmed,
  contact,
  outcome,
  scoreUpdate,
  wicketTransition,
  complete,
}

enum TimingDrift { none, early, late }

enum SuperOverContactType { played, leave, beaten, missed }

enum SuperOverPerformanceGrade { s, a, b, c, d }

extension SuperOverPerformanceGradeLabel on SuperOverPerformanceGrade {
  String get label => name.toUpperCase();
}

class DeliveryPlan {
  const DeliveryPlan({
    this.type = DeliveryType.pace,
    this.line = DeliveryLine.middle,
    this.length = DeliveryLength.good,
    this.paceFactor = 1,
    this.planId = 'balanced',
    this.sequenceIndex = 0,
    this.disguised = false,
  });

  final DeliveryType type;
  final DeliveryLine line;
  final DeliveryLength length;
  final double paceFactor;
  final String planId;
  final int sequenceIndex;
  final bool disguised;

  String get typeLabel => switch (type) {
    DeliveryType.pace => 'PACE',
    DeliveryType.slower => 'SLOWER',
    DeliveryType.spin => 'SPIN',
    DeliveryType.yorker => 'PACE',
  };

  String get lengthLabel => switch (length) {
    DeliveryLength.short => 'SHORT',
    DeliveryLength.good => 'GOOD LENGTH',
    DeliveryLength.full => 'FULL',
    DeliveryLength.yorker => 'YORKER',
  };

  String get cue => '$typeLabel // $lengthLabel';

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'line': line.name,
    'length': length.name,
    'paceFactor': paceFactor,
    'planId': planId,
    'sequenceIndex': sequenceIndex,
    'disguised': disguised,
  };

  factory DeliveryPlan.fromJson(Map<String, dynamic> json) => DeliveryPlan(
    type: _enumByName(DeliveryType.values, json['type'], DeliveryType.pace),
    line: _enumByName(DeliveryLine.values, json['line'], DeliveryLine.middle),
    length: _enumByName(
      DeliveryLength.values,
      json['length'],
      DeliveryLength.good,
    ),
    paceFactor: (json['paceFactor'] as num?)?.toDouble() ?? 1,
    planId: json['planId'] as String? ?? 'balanced',
    sequenceIndex: (json['sequenceIndex'] as num?)?.toInt() ?? 0,
    disguised: json['disguised'] as bool? ?? false,
  );
}

class ShotIntent {
  const ShotIntent({
    required this.sector,
    required this.style,
    required this.timingErrorMs,
    this.leftHanded = false,
  });

  final ShotSector sector;
  final ShotStyle style;
  final int timingErrorMs;
  final bool leftHanded;

  Map<String, dynamic> toJson() => {
    'sector': sector.name,
    'style': style.name,
    'timingErrorMs': timingErrorMs,
    'leftHanded': leftHanded,
  };

  factory ShotIntent.fromJson(Map<String, dynamic> json) => ShotIntent(
    sector: _enumByName(ShotSector.values, json['sector'], ShotSector.v),
    style: _enumByName(ShotStyle.values, json['style'], ShotStyle.ground),
    timingErrorMs: (json['timingErrorMs'] as num?)?.toInt() ?? 0,
    leftHanded: json['leftHanded'] as bool? ?? false,
  );
}

class SuperOverObjective {
  const SuperOverObjective({required this.type, required this.target});

  final SuperOverObjectiveType type;
  final int target;

  String get label => switch (type) {
    SuperOverObjectiveType.runs => 'SCORE $target RUNS',
    SuperOverObjectiveType.attackGap => 'HIT THE OPEN GAP $target TIMES',
    SuperOverObjectiveType.protectWicket => 'FINISH WITHOUT A WICKET',
    SuperOverObjectiveType.boundaries => 'HIT $target BOUNDARIES',
    SuperOverObjectiveType.allSectors => 'SCORE FROM ALL THREE SECTORS',
    SuperOverObjectiveType.chaseWithBallRemaining =>
      'CHASE WITH A BALL REMAINING',
    SuperOverObjectiveType.groundRuns => 'SCORE $target RUNS ALONG THE GROUND',
    SuperOverObjectiveType.winWithoutFinisher => 'WIN WITHOUT FINISHER MODE',
  };

  Map<String, dynamic> toJson() => {'type': type.name, 'target': target};

  factory SuperOverObjective.fromJson(Map<String, dynamic> json) =>
      SuperOverObjective(
        type: _enumByName(
          SuperOverObjectiveType.values,
          json['type'],
          SuperOverObjectiveType.runs,
        ),
        target: (json['target'] as num?)?.toInt() ?? 0,
      );
}

extension SuperOverModeLabel on SuperOverMode {
  String get label => switch (this) {
    SuperOverMode.chase => 'CHASE',
    SuperOverMode.scoreAttack => 'SCORE ATTACK',
  };
}

extension SuperOverDifficultySpec on SuperOverDifficulty {
  String get label => switch (this) {
    SuperOverDifficulty.rookie => 'ROOKIE',
    SuperOverDifficulty.pro => 'PRO',
    SuperOverDifficulty.allStar => 'ALL-STAR',
  };

  /// Explicit assistance only; pressure and score never alter this scale.
  double get timingWindowScale => switch (this) {
    SuperOverDifficulty.rookie => 1.18,
    SuperOverDifficulty.pro => 1.0,
    SuperOverDifficulty.allStar => 0.86,
  };

  double get pitchMarkerStrength => switch (this) {
    SuperOverDifficulty.rookie => 1.0,
    SuperOverDifficulty.pro => 0.68,
    SuperOverDifficulty.allStar => 0.42,
  };

  int get cueLeadMs => switch (this) {
    SuperOverDifficulty.rookie => 240,
    SuperOverDifficulty.pro => 150,
    SuperOverDifficulty.allStar => 90,
  };

  double get disguiseStrength => switch (this) {
    SuperOverDifficulty.rookie => 0,
    SuperOverDifficulty.pro => 0.5,
    SuperOverDifficulty.allStar => 1,
  };
}

extension ShotSectorLabel on ShotSector {
  String get label => switch (this) {
    ShotSector.off => 'OFF',
    ShotSector.v => 'STRAIGHT',
    ShotSector.leg => 'LEG',
  };
}

extension ShotStyleLabel on ShotStyle {
  String get label => switch (this) {
    ShotStyle.ground => 'GROUND',
    ShotStyle.loft => 'LOFT',
  };
}

extension CricketBattingStyleLabel on CricketBattingStyle {
  String get label => switch (this) {
    CricketBattingStyle.anchor => 'ANCHOR',
    CricketBattingStyle.powerHitter => 'POWER HITTER',
    CricketBattingStyle.improviser => 'IMPROVISER',
  };
}

enum CricketJersey {
  nightCyan,
  violetPulse,
  goldStrike,
  emberRed,
  tealVector,
  monoIce,
}

enum SuperOverPhase {
  ready,
  targetReveal,
  ballSetup,
  runUp,
  ballInFlight,
  swinging,
  outcome,
  result,
  paused,
}

/// The nine-player field committed before the batter can lock an intent.
/// [openSector] is null whenever the least-covered count is tied.
class SuperOverFieldPlan {
  const SuperOverFieldPlan({
    required this.id,
    required this.sectorCounts,
    required this.openSector,
    required this.packedSectors,
  }) : assert(sectorCounts.length == 3);

  factory SuperOverFieldPlan.fromCounts(
    List<int> counts, {
    String id = 'custom',
  }) {
    if (counts.length != 3) {
      throw ArgumentError.value(counts, 'counts', 'Must contain OFF/V/LEG');
    }
    if (counts.any((count) => count < 0) ||
        counts.fold<int>(0, (sum, count) => sum + count) != 9) {
      throw ArgumentError.value(counts, 'counts', 'Must place nine fielders');
    }
    final immutableCounts = List<int>.unmodifiable(counts);
    final minimum = immutableCounts.reduce(min);
    final minimumIndexes = <int>[
      for (var i = 0; i < immutableCounts.length; i++)
        if (immutableCounts[i] == minimum) i,
    ];
    final openSector = minimumIndexes.length == 1
        ? SuperOverResolution.sectorFromIndex(minimumIndexes.single)
        : null;
    final packed = <ShotSector>{
      for (var i = 0; i < immutableCounts.length; i++)
        if (immutableCounts[i] >= 4) SuperOverResolution.sectorFromIndex(i),
    };
    return SuperOverFieldPlan(
      id: id,
      sectorCounts: immutableCounts,
      openSector: openSector,
      packedSectors: Set<ShotSector>.unmodifiable(packed),
    );
  }

  final String id;
  final List<int> sectorCounts;
  final ShotSector? openSector;
  final Set<ShotSector> packedSectors;

  int countFor(ShotSector sector) =>
      sectorCounts[SuperOverResolution.sectorIndex(sector)];

  bool isOpen(ShotSector sector) => openSector == sector;
  bool isPacked(ShotSector sector) => packedSectors.contains(sector);

  Map<String, dynamic> toJson() => {
    'id': id,
    'sectorCounts': sectorCounts,
    'openSector': openSector?.name,
    'packedSectors': packedSectors.map((sector) => sector.name).toList(),
  };

  factory SuperOverFieldPlan.fromJson(Map<String, dynamic> json) {
    final counts = _intList(json['sectorCounts']);
    if (counts.length == 3 && counts.fold<int>(0, (a, b) => a + b) == 9) {
      return SuperOverFieldPlan.fromCounts(
        counts,
        id: json['id'] as String? ?? 'custom',
      );
    }
    return SuperOverFieldPlan.fromCounts(const [
      3,
      3,
      3,
    ], id: json['id'] as String? ?? 'balanced');
  }
}

class SuperOverMatchConfig {
  const SuperOverMatchConfig({
    required this.matchId,
    required this.seed,
    required this.mode,
    this.difficulty = SuperOverDifficulty.pro,
    required this.level,
    required this.battingCardIds,
    required this.jerseyId,
    this.tutorial = false,
  }) : assert(matchId != ''),
       assert(level > 0),
       assert(battingCardIds.length == 3);

  final String matchId;
  final int seed;
  final SuperOverMode mode;
  final SuperOverDifficulty difficulty;
  final int level;
  final List<String> battingCardIds;
  final String jerseyId;
  final bool tutorial;

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'seed': seed,
    'mode': mode.name,
    'difficulty': difficulty.name,
    'level': level,
    'battingCardIds': battingCardIds,
    'jerseyId': jerseyId,
    'tutorial': tutorial,
  };

  factory SuperOverMatchConfig.fromJson(Map<String, dynamic> json) {
    final cardIds = _stringList(json['battingCardIds']);
    return SuperOverMatchConfig(
      matchId: json['matchId'] as String? ?? 'restored-match',
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      mode: _enumByName(
        SuperOverMode.values,
        json['mode'],
        SuperOverMode.chase,
      ),
      difficulty: _enumByName(
        SuperOverDifficulty.values,
        json['difficulty'],
        SuperOverDifficulty.pro,
      ),
      level: max(1, (json['level'] as num?)?.toInt() ?? 1),
      battingCardIds: cardIds.length == 3
          ? cardIds
          : const ['batter-1', 'batter-2', 'batter-3'],
      jerseyId: json['jerseyId'] as String? ?? CricketJersey.nightCyan.name,
      tutorial: json['tutorial'] as bool? ?? false,
    );
  }
}

class SuperOverSettings {
  const SuperOverSettings({
    this.difficulty = SuperOverDifficulty.pro,
    this.soundEnabled = true,
    this.musicEnabled = true,
    this.crowdEnabled = true,
    this.hapticsEnabled = true,
    this.reducedMotion = false,
    this.leftHandedControls = false,
    this.batButtonScale = 1,
    this.controlOpacity = 1,
    this.largerFieldRadar = false,
  }) : assert(batButtonScale >= 0.75 && batButtonScale <= 1.5),
       assert(controlOpacity >= 0.4 && controlOpacity <= 1);

  final SuperOverDifficulty difficulty;
  final bool soundEnabled;
  final bool musicEnabled;
  final bool crowdEnabled;
  final bool hapticsEnabled;
  final bool reducedMotion;
  final bool leftHandedControls;
  final double batButtonScale;
  final double controlOpacity;
  final bool largerFieldRadar;

  SuperOverSettings copyWith({
    SuperOverDifficulty? difficulty,
    bool? soundEnabled,
    bool? musicEnabled,
    bool? crowdEnabled,
    bool? hapticsEnabled,
    bool? reducedMotion,
    bool? leftHandedControls,
    double? batButtonScale,
    double? controlOpacity,
    bool? largerFieldRadar,
  }) => SuperOverSettings(
    difficulty: difficulty ?? this.difficulty,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    musicEnabled: musicEnabled ?? this.musicEnabled,
    crowdEnabled: crowdEnabled ?? this.crowdEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    leftHandedControls: leftHandedControls ?? this.leftHandedControls,
    batButtonScale: batButtonScale ?? this.batButtonScale,
    controlOpacity: controlOpacity ?? this.controlOpacity,
    largerFieldRadar: largerFieldRadar ?? this.largerFieldRadar,
  );

  Map<String, dynamic> toJson() => {
    'difficulty': difficulty.name,
    'soundEnabled': soundEnabled,
    'musicEnabled': musicEnabled,
    'crowdEnabled': crowdEnabled,
    'hapticsEnabled': hapticsEnabled,
    'reducedMotion': reducedMotion,
    'leftHandedControls': leftHandedControls,
    'batButtonScale': batButtonScale,
    'controlOpacity': controlOpacity,
    'largerFieldRadar': largerFieldRadar,
  };

  factory SuperOverSettings.fromJson(Map<String, dynamic> json) =>
      SuperOverSettings(
        difficulty: _enumByName(
          SuperOverDifficulty.values,
          json['difficulty'],
          SuperOverDifficulty.pro,
        ),
        soundEnabled: json['soundEnabled'] as bool? ?? true,
        musicEnabled: json['musicEnabled'] as bool? ?? true,
        crowdEnabled: json['crowdEnabled'] as bool? ?? true,
        hapticsEnabled: json['hapticsEnabled'] as bool? ?? true,
        reducedMotion: json['reducedMotion'] as bool? ?? false,
        leftHandedControls: json['leftHandedControls'] as bool? ?? false,
        batButtonScale: ((json['batButtonScale'] as num?)?.toDouble() ?? 1)
            .clamp(0.75, 1.5),
        controlOpacity: ((json['controlOpacity'] as num?)?.toDouble() ?? 1)
            .clamp(0.4, 1.0),
        largerFieldRadar: json['largerFieldRadar'] as bool? ?? false,
      );
}

/// A field and delivery pair produced before the current intent is known.
class SuperOverCommittedBall {
  const SuperOverCommittedBall({
    required this.ballNumber,
    required this.planningSeed,
    required this.fieldPlan,
    required this.delivery,
  }) : assert(ballNumber >= 1 && ballNumber <= 6);

  final int ballNumber;
  final int planningSeed;
  final SuperOverFieldPlan fieldPlan;
  final DeliveryPlan delivery;

  Map<String, dynamic> toJson() => {
    'ballNumber': ballNumber,
    'planningSeed': planningSeed,
    'fieldPlan': fieldPlan.toJson(),
    'delivery': delivery.toJson(),
  };

  factory SuperOverCommittedBall.fromJson(Map<String, dynamic> json) =>
      SuperOverCommittedBall(
        ballNumber: ((json['ballNumber'] as num?)?.toInt() ?? 1).clamp(1, 6),
        planningSeed: (json['planningSeed'] as num?)?.toInt() ?? 0,
        fieldPlan: SuperOverFieldPlan.fromJson(_jsonMap(json['fieldPlan'])),
        delivery: DeliveryPlan.fromJson(_jsonMap(json['delivery'])),
      );
}

class SuperOverMatchPosition {
  const SuperOverMatchPosition({
    this.score = 0,
    this.wickets = 0,
    this.ballsFaced = 0,
    this.strikerIndex = 0,
    this.nonStrikerIndex = 1,
    this.isComplete = false,
    this.wonChase,
  });

  final int score;
  final int wickets;
  final int ballsFaced;
  final int strikerIndex;
  final int nonStrikerIndex;
  final bool isComplete;
  final bool? wonChase;

  int get ballsRemaining => max(0, 6 - ballsFaced);
}

class SuperOverBallRecord {
  const SuperOverBallRecord({
    required this.ballNumber,
    required this.strikerCardId,
    required this.nonStrikerCardId,
    required this.committedBall,
    this.intent,
    required this.contactType,
    required this.timingErrorMs,
    required this.normalizedTimingError,
    required this.timingTier,
    required this.drift,
    required this.resolvedSector,
    required this.outcome,
    required this.runs,
    required this.usedFinisherMode,
    required this.rhythmBefore,
    required this.rhythmAfter,
    required this.scoreAfter,
    required this.wicketsAfter,
  }) : assert(ballNumber >= 1 && ballNumber <= 6),
       assert(runs >= 0 && runs <= 6),
       assert(rhythmBefore >= 0 && rhythmBefore <= 100),
       assert(rhythmAfter >= 0 && rhythmAfter <= 100);

  final int ballNumber;
  final String strikerCardId;
  final String nonStrikerCardId;
  final SuperOverCommittedBall committedBall;
  final ShotIntent? intent;
  final SuperOverContactType contactType;
  final int timingErrorMs;
  final double normalizedTimingError;
  final TimingTier timingTier;
  final TimingDrift drift;
  final ShotSector resolvedSector;
  final ShotOutcome outcome;
  final int runs;
  final bool usedFinisherMode;
  final int rhythmBefore;
  final int rhythmAfter;
  final int scoreAfter;
  final int wicketsAfter;

  bool get isWicket =>
      outcome == ShotOutcome.caught || outcome == ShotOutcome.bowled;
  bool get isBoundary =>
      outcome == ShotOutcome.four || outcome == ShotOutcome.six;
  bool get scoredInOpenSector =>
      runs > 0 && committedBall.fieldPlan.openSector == resolvedSector;

  Map<String, dynamic> toJson() => {
    'ballNumber': ballNumber,
    'strikerCardId': strikerCardId,
    'nonStrikerCardId': nonStrikerCardId,
    'committedBall': committedBall.toJson(),
    'intent': intent?.toJson(),
    'contactType': contactType.name,
    'timingErrorMs': timingErrorMs,
    'normalizedTimingError': normalizedTimingError,
    'timingTier': timingTier.name,
    'drift': drift.name,
    'resolvedSector': resolvedSector.name,
    'outcome': outcome.name,
    'runs': runs,
    'usedFinisherMode': usedFinisherMode,
    'rhythmBefore': rhythmBefore,
    'rhythmAfter': rhythmAfter,
    'scoreAfter': scoreAfter,
    'wicketsAfter': wicketsAfter,
  };

  factory SuperOverBallRecord.fromJson(Map<String, dynamic> json) {
    final intentJson = json['intent'];
    return SuperOverBallRecord(
      ballNumber: ((json['ballNumber'] as num?)?.toInt() ?? 1).clamp(1, 6),
      strikerCardId: json['strikerCardId'] as String? ?? 'batter-1',
      nonStrikerCardId: json['nonStrikerCardId'] as String? ?? 'batter-2',
      committedBall: SuperOverCommittedBall.fromJson(
        _jsonMap(json['committedBall']),
      ),
      intent: intentJson is Map
          ? ShotIntent.fromJson(Map<String, dynamic>.from(intentJson))
          : null,
      contactType: _enumByName(
        SuperOverContactType.values,
        json['contactType'],
        SuperOverContactType.played,
      ),
      timingErrorMs: (json['timingErrorMs'] as num?)?.toInt() ?? 0,
      normalizedTimingError:
          (json['normalizedTimingError'] as num?)?.toDouble() ?? 0,
      timingTier: _enumByName(
        TimingTier.values,
        json['timingTier'],
        TimingTier.miss,
      ),
      drift: _enumByName(TimingDrift.values, json['drift'], TimingDrift.none),
      resolvedSector: _enumByName(
        ShotSector.values,
        json['resolvedSector'],
        ShotSector.v,
      ),
      outcome: _enumByName(
        ShotOutcome.values,
        json['outcome'],
        ShotOutcome.dot,
      ),
      runs: ((json['runs'] as num?)?.toInt() ?? 0).clamp(0, 6),
      usedFinisherMode: json['usedFinisherMode'] as bool? ?? false,
      rhythmBefore: ((json['rhythmBefore'] as num?)?.toInt() ?? 0).clamp(
        0,
        100,
      ),
      rhythmAfter: ((json['rhythmAfter'] as num?)?.toInt() ?? 0).clamp(0, 100),
      scoreAfter: max(0, (json['scoreAfter'] as num?)?.toInt() ?? 0),
      wicketsAfter: ((json['wicketsAfter'] as num?)?.toInt() ?? 0).clamp(0, 2),
    );
  }
}

class SuperOverMatchSummary {
  const SuperOverMatchSummary({
    required this.matchId,
    required this.seed,
    required this.mode,
    required this.difficulty,
    this.target,
    required this.score,
    required this.wickets,
    required this.ballsFaced,
    required this.wonChase,
    required this.objective,
    required this.objectiveComplete,
    required this.battingCardIds,
    required this.ballRecords,
    this.finishingBatterCardId,
    this.grade = SuperOverPerformanceGrade.c,
    this.isNewRecord = false,
    this.completedAtEpochMs = 0,
    this.tutorial = false,
  }) : assert(score >= 0),
       assert(wickets >= 0 && wickets <= 2),
       assert(ballsFaced >= 0 && ballsFaced <= 6),
       assert(battingCardIds.length == 3);

  final String matchId;
  final int seed;
  final SuperOverMode mode;
  final SuperOverDifficulty difficulty;

  /// Opponent score. A Chase is won when [score] exceeds this value.
  final int? target;
  final int score;
  final int wickets;
  final int ballsFaced;
  final bool? wonChase;
  final SuperOverObjective objective;
  final bool objectiveComplete;
  final List<String> battingCardIds;
  final List<SuperOverBallRecord> ballRecords;
  final String? finishingBatterCardId;
  final SuperOverPerformanceGrade grade;
  final bool isNewRecord;
  final int completedAtEpochMs;
  final bool tutorial;

  int get ballsRemaining => max(0, 6 - ballsFaced);
  int get fours =>
      ballRecords.where((ball) => ball.outcome == ShotOutcome.four).length;
  int get sixes =>
      ballRecords.where((ball) => ball.outcome == ShotOutcome.six).length;
  int get boundaries => fours + sixes;
  int get perfectContacts =>
      ballRecords.where((ball) => ball.timingTier == TimingTier.perfect).length;
  int get openSectorHits =>
      ballRecords.where((ball) => ball.scoredInOpenSector).length;
  int get requiredChaseScore => (target ?? 0) + 1;
  SuperOverRewardBreakdown get rewardBreakdown =>
      SuperOverRewardBreakdown.fromSummary(this);
  SuperOverRewardBreakdown get rewards => rewardBreakdown;
  int get xpEarned => rewardBreakdown.totalXp;

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'seed': seed,
    'mode': mode.name,
    'difficulty': difficulty.name,
    'target': target,
    'score': score,
    'wickets': wickets,
    'ballsFaced': ballsFaced,
    'wonChase': wonChase,
    'objective': objective.toJson(),
    'objectiveComplete': objectiveComplete,
    'battingCardIds': battingCardIds,
    'ballRecords': ballRecords.map((ball) => ball.toJson()).toList(),
    'finishingBatterCardId': finishingBatterCardId,
    'grade': grade.name,
    'isNewRecord': isNewRecord,
    'completedAtEpochMs': completedAtEpochMs,
    'tutorial': tutorial,
  };

  factory SuperOverMatchSummary.fromJson(Map<String, dynamic> json) {
    final cardIds = _stringList(json['battingCardIds']);
    return SuperOverMatchSummary(
      matchId: json['matchId'] as String? ?? 'restored-match',
      seed: (json['seed'] as num?)?.toInt() ?? 0,
      mode: _enumByName(
        SuperOverMode.values,
        json['mode'],
        SuperOverMode.chase,
      ),
      difficulty: _enumByName(
        SuperOverDifficulty.values,
        json['difficulty'],
        SuperOverDifficulty.pro,
      ),
      target: (json['target'] as num?)?.toInt(),
      score: max(0, (json['score'] as num?)?.toInt() ?? 0),
      wickets: ((json['wickets'] as num?)?.toInt() ?? 0).clamp(0, 2),
      ballsFaced: ((json['ballsFaced'] as num?)?.toInt() ?? 0).clamp(0, 6),
      wonChase: json['wonChase'] as bool?,
      objective: SuperOverObjective.fromJson(_jsonMap(json['objective'])),
      objectiveComplete: json['objectiveComplete'] as bool? ?? false,
      battingCardIds: cardIds.length == 3
          ? cardIds
          : const ['batter-1', 'batter-2', 'batter-3'],
      ballRecords: _jsonMapList(
        json['ballRecords'],
      ).map(SuperOverBallRecord.fromJson).take(6).toList(),
      finishingBatterCardId: json['finishingBatterCardId'] as String?,
      grade: _enumByName(
        SuperOverPerformanceGrade.values,
        json['grade'],
        SuperOverPerformanceGrade.c,
      ),
      isNewRecord: json['isNewRecord'] as bool? ?? false,
      completedAtEpochMs: (json['completedAtEpochMs'] as num?)?.toInt() ?? 0,
      tutorial: json['tutorial'] as bool? ?? false,
    );
  }
}

class SuperOverRewardBreakdown {
  const SuperOverRewardBreakdown({
    required this.completionXp,
    required this.runsXp,
    required this.sixesXp,
    required this.chaseWinXp,
    required this.objectiveXp,
  });

  factory SuperOverRewardBreakdown.fromSummary(SuperOverMatchSummary summary) {
    if (summary.tutorial) {
      return const SuperOverRewardBreakdown(
        completionXp: 0,
        runsXp: 0,
        sixesXp: 0,
        chaseWinXp: 0,
        objectiveXp: 0,
      );
    }
    return SuperOverRewardBreakdown(
      completionXp: 10,
      runsXp: summary.score,
      sixesXp: summary.sixes * 4,
      chaseWinXp:
          summary.mode == SuperOverMode.chase && summary.wonChase == true
          ? 15
          : 0,
      objectiveXp: summary.objectiveComplete ? 8 : 0,
    );
  }

  final int completionXp;
  final int runsXp;
  final int sixesXp;
  final int chaseWinXp;
  final int objectiveXp;

  int get totalXp => completionXp + runsXp + sixesXp + chaseWinXp + objectiveXp;

  Map<String, dynamic> toJson() => {
    'completionXp': completionXp,
    'runsXp': runsXp,
    'sixesXp': sixesXp,
    'chaseWinXp': chaseWinXp,
    'objectiveXp': objectiveXp,
    'totalXp': totalXp,
  };

  factory SuperOverRewardBreakdown.fromJson(Map<String, dynamic> json) =>
      SuperOverRewardBreakdown(
        completionXp: max(0, (json['completionXp'] as num?)?.toInt() ?? 0),
        runsXp: max(0, (json['runsXp'] as num?)?.toInt() ?? 0),
        sixesXp: max(0, (json['sixesXp'] as num?)?.toInt() ?? 0),
        chaseWinXp: max(0, (json['chaseWinXp'] as num?)?.toInt() ?? 0),
        objectiveXp: max(0, (json['objectiveXp'] as num?)?.toInt() ?? 0),
      );
}

class SuperOverMatchSnapshot {
  const SuperOverMatchSnapshot({
    this.version = 1,
    required this.config,
    this.target,
    required this.objective,
    this.score = 0,
    this.wickets = 0,
    this.strikerIndex = 0,
    this.nonStrikerIndex = 1,
    this.rhythmByCardId = const {},
    this.finisherReady = false,
    this.combo = 0,
    this.maxCombo = 0,
    this.ballRecords = const [],
    required this.committedBall,
    this.selectedSector = ShotSector.v,
    this.selectedShotStyle = ShotStyle.ground,
    this.playPhase = SuperOverPlayPhase.fieldReveal,
    this.savedAtEpochMs = 0,
  }) : assert(version > 0),
       assert(wickets >= 0 && wickets <= 2),
       assert(ballRecords.length <= 6);

  final int version;
  final SuperOverMatchConfig config;
  final int? target;
  final SuperOverObjective objective;
  final int score;
  final int wickets;
  final int strikerIndex;
  final int nonStrikerIndex;
  final Map<String, int> rhythmByCardId;
  final bool finisherReady;
  final int combo;
  final int maxCombo;
  final List<SuperOverBallRecord> ballRecords;

  /// The unresolved ball is restarted from this immutable commitment.
  final SuperOverCommittedBall committedBall;
  final ShotSector selectedSector;
  final ShotStyle selectedShotStyle;
  final SuperOverPlayPhase playPhase;
  final int savedAtEpochMs;

  int get ballsFaced => ballRecords.length;

  SuperOverMatchSnapshot copyWith({
    int? version,
    SuperOverMatchConfig? config,
    Object? target = _sentinel,
    SuperOverObjective? objective,
    int? score,
    int? wickets,
    int? strikerIndex,
    int? nonStrikerIndex,
    Map<String, int>? rhythmByCardId,
    bool? finisherReady,
    int? combo,
    int? maxCombo,
    List<SuperOverBallRecord>? ballRecords,
    SuperOverCommittedBall? committedBall,
    ShotSector? selectedSector,
    ShotStyle? selectedShotStyle,
    SuperOverPlayPhase? playPhase,
    int? savedAtEpochMs,
  }) => SuperOverMatchSnapshot(
    version: version ?? this.version,
    config: config ?? this.config,
    target: target == _sentinel ? this.target : target as int?,
    objective: objective ?? this.objective,
    score: score ?? this.score,
    wickets: wickets ?? this.wickets,
    strikerIndex: strikerIndex ?? this.strikerIndex,
    nonStrikerIndex: nonStrikerIndex ?? this.nonStrikerIndex,
    rhythmByCardId: rhythmByCardId ?? this.rhythmByCardId,
    finisherReady: finisherReady ?? this.finisherReady,
    combo: combo ?? this.combo,
    maxCombo: maxCombo ?? this.maxCombo,
    ballRecords: ballRecords ?? this.ballRecords,
    committedBall: committedBall ?? this.committedBall,
    selectedSector: selectedSector ?? this.selectedSector,
    selectedShotStyle: selectedShotStyle ?? this.selectedShotStyle,
    playPhase: playPhase ?? this.playPhase,
    savedAtEpochMs: savedAtEpochMs ?? this.savedAtEpochMs,
  );

  Map<String, dynamic> toJson() => {
    'version': version,
    'config': config.toJson(),
    'target': target,
    'objective': objective.toJson(),
    'score': score,
    'wickets': wickets,
    'strikerIndex': strikerIndex,
    'nonStrikerIndex': nonStrikerIndex,
    'rhythmByCardId': rhythmByCardId,
    'finisherReady': finisherReady,
    'combo': combo,
    'maxCombo': maxCombo,
    'ballRecords': ballRecords.map((ball) => ball.toJson()).toList(),
    'committedBall': committedBall.toJson(),
    'selectedSector': selectedSector.name,
    'selectedShotStyle': selectedShotStyle.name,
    'playPhase': playPhase.name,
    'savedAtEpochMs': savedAtEpochMs,
  };

  factory SuperOverMatchSnapshot.fromJson(Map<String, dynamic> json) =>
      SuperOverMatchSnapshot(
        version: max(1, (json['version'] as num?)?.toInt() ?? 1),
        config: SuperOverMatchConfig.fromJson(_jsonMap(json['config'])),
        target: (json['target'] as num?)?.toInt(),
        objective: SuperOverObjective.fromJson(_jsonMap(json['objective'])),
        score: max(0, (json['score'] as num?)?.toInt() ?? 0),
        wickets: ((json['wickets'] as num?)?.toInt() ?? 0).clamp(0, 2),
        strikerIndex: ((json['strikerIndex'] as num?)?.toInt() ?? 0).clamp(
          0,
          2,
        ),
        nonStrikerIndex: ((json['nonStrikerIndex'] as num?)?.toInt() ?? 1)
            .clamp(0, 2),
        rhythmByCardId: _intMap(json['rhythmByCardId']),
        finisherReady: json['finisherReady'] as bool? ?? false,
        combo: max(0, (json['combo'] as num?)?.toInt() ?? 0),
        maxCombo: max(0, (json['maxCombo'] as num?)?.toInt() ?? 0),
        ballRecords: _jsonMapList(
          json['ballRecords'],
        ).map(SuperOverBallRecord.fromJson).take(6).toList(),
        committedBall: SuperOverCommittedBall.fromJson(
          _jsonMap(json['committedBall']),
        ),
        selectedSector: _enumByName(
          ShotSector.values,
          json['selectedSector'],
          ShotSector.v,
        ),
        selectedShotStyle: _enumByName(
          ShotStyle.values,
          json['selectedShotStyle'],
          ShotStyle.ground,
        ),
        playPhase: _enumByName(
          SuperOverPlayPhase.values,
          json['playPhase'],
          SuperOverPlayPhase.fieldReveal,
        ),
        savedAtEpochMs: (json['savedAtEpochMs'] as num?)?.toInt() ?? 0,
      );
}

class SuperOverShotResult {
  const SuperOverShotResult({
    required this.timingErrorMs,
    required this.normalizedError,
    required this.tier,
    required this.sector,
    required this.power,
    required this.outcome,
    this.drift = TimingDrift.none,
    this.contactType = SuperOverContactType.played,
  });

  final int timingErrorMs;
  final double normalizedError;
  final TimingTier tier;
  final ShotSector sector;
  final int power;
  final ShotOutcome outcome;
  final TimingDrift drift;
  final SuperOverContactType contactType;
}

class SuperOverFielderSpot {
  const SuperOverFielderSpot({
    required this.sector,
    required this.angle,
    required this.radial,
    this.closeCatcher = false,
  });

  final ShotSector sector;

  /// Radians from the striker: straight is -pi / 2, off is left, leg is right.
  final double angle;

  /// Distance from striker, normalized to the top-down oval.
  final double radial;

  final bool closeCatcher;
}

class SuperOverResolution {
  static final Random _random = Random();

  static const int baseTimingWindowMs = 360;

  static const List<SuperOverFielderSpot> _offFieldTemplate = [
    SuperOverFielderSpot(
      sector: ShotSector.off,
      angle: -2.72,
      radial: 0.30,
      closeCatcher: true,
    ),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.34, radial: 0.48),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.05, radial: 0.66),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.56, radial: 0.82),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.20, radial: 0.96),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.86, radial: 0.94),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -1.98, radial: 0.42),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.44, radial: 0.62),
    SuperOverFielderSpot(sector: ShotSector.off, angle: -2.10, radial: 0.84),
  ];

  static const List<SuperOverFielderSpot> _vFieldTemplate = [
    SuperOverFielderSpot(
      sector: ShotSector.v,
      angle: -pi / 2,
      radial: 0.26,
      closeCatcher: true,
    ),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.83, radial: 0.45),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.31, radial: 0.45),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.82, radial: 0.78),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.32, radial: 0.78),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -pi / 2, radial: 0.98),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.68, radial: 0.62),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -1.44, radial: 0.62),
    SuperOverFielderSpot(sector: ShotSector.v, angle: -pi / 2, radial: 0.54),
  ];

  static const List<SuperOverFielderSpot> _legFieldTemplate = [
    SuperOverFielderSpot(
      sector: ShotSector.leg,
      angle: -0.42,
      radial: 0.34,
      closeCatcher: true,
    ),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.78, radial: 0.50),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -1.08, radial: 0.66),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.68, radial: 0.86),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.22, radial: 0.72),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -1.12, radial: 0.92),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.54, radial: 0.58),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.92, radial: 0.74),
    SuperOverFielderSpot(sector: ShotSector.leg, angle: -0.28, radial: 0.92),
  ];

  /// Calculates the target rating based on player level.
  static int targetRatingForLevel(int level) {
    return min(95, 66 + level * 2);
  }

  /// First-pass chase target bands tuned for the one-tap arcade scoring rate.
  static (int min, int max) targetBandForLevel(int level) {
    if (level <= 3) return (8, 12);
    if (level <= 7) return (11, 16);
    if (level <= 12) return (14, 19);
    if (level <= 18) return (16, 21);
    return (18, 23);
  }

  static int targetForLevel(int level, {Random? random}) {
    final rng = random ?? _random;
    final band = targetBandForLevel(level);
    return band.$1 + rng.nextInt(band.$2 - band.$1 + 1);
  }

  /// Calculates the window scale multiplier for a given card rating.
  static double windowScale(int rating) {
    return (1.0 + (rating - 75) * 0.012).clamp(0.85, 1.30);
  }

  /// Adjusts the base window size by the delivery type multiplier.
  static double deliveryMultiplier(DeliveryType type) {
    return switch (type) {
      DeliveryType.yorker => 0.78,
      DeliveryType.pace => 0.92,
      DeliveryType.slower => 1.04,
      DeliveryType.spin => 1.10,
    };
  }

  static int effectiveTimingWindowMs(
    int rating,
    DeliveryType delivery, {
    bool onFire = false,
    SuperOverDifficulty difficulty = SuperOverDifficulty.pro,
  }) {
    final scale =
        windowScale(rating) *
        deliveryMultiplier(delivery) *
        (onFire ? 1.08 : 1.0) *
        difficulty.timingWindowScale;
    return (baseTimingWindowMs * scale).round();
  }

  static double normalizedTimingError({
    required int timingErrorMs,
    required int effectiveWindowMs,
  }) {
    if (effectiveWindowMs <= 0) return timingErrorMs.sign.toDouble();
    return timingErrorMs / effectiveWindowMs;
  }

  static TimingTier timingTierForNormalizedError(double normalizedError) {
    final absError = normalizedError.abs();
    if (absError <= 0.14) return TimingTier.perfect;
    if (absError <= 0.32) return TimingTier.great;
    if (absError <= 0.58) return TimingTier.good;
    if (absError <= 0.90) return TimingTier.edgePoor;
    return TimingTier.miss;
  }

  static ShotSector sectorForTiming(
    double normalizedError, {
    bool leftHanded = false,
  }) {
    if (normalizedError < -0.18) {
      return leftHanded ? ShotSector.off : ShotSector.leg;
    }
    if (normalizedError > 0.18) {
      return leftHanded ? ShotSector.leg : ShotSector.off;
    }
    return ShotSector.v;
  }

  static TimingDrift timingDriftForNormalizedError(double normalizedError) {
    if (normalizedError < -0.18) return TimingDrift.early;
    if (normalizedError > 0.18) return TimingDrift.late;
    return TimingDrift.none;
  }

  /// Perfect and near-perfect contact follows the selected intent. Earlier or
  /// later contact drifts one sector in the physically expected direction.
  static ShotSector sectorForIntentAndTiming({
    required ShotSector intendedSector,
    required double normalizedError,
    bool leftHanded = false,
  }) {
    final drift = timingDriftForNormalizedError(normalizedError);
    if (drift == TimingDrift.none) return intendedSector;
    final earlyStep = leftHanded ? -1 : 1;
    final step = drift == TimingDrift.early ? earlyStep : -earlyStep;
    return sectorFromIndex(
      (sectorIndex(intendedSector) + step).clamp(0, 2).toInt(),
    );
  }

  static int sectorIndex(ShotSector sector) {
    return switch (sector) {
      ShotSector.off => 0,
      ShotSector.v => 1,
      ShotSector.leg => 2,
    };
  }

  static ShotSector sectorFromIndex(int index) {
    return switch (index) {
      0 => ShotSector.off,
      2 => ShotSector.leg,
      _ => ShotSector.v,
    };
  }

  static double shotAngleForSector(ShotSector sector) {
    return switch (sector) {
      ShotSector.off => -2.32,
      ShotSector.v => -pi / 2,
      ShotSector.leg => -0.82,
    };
  }

  static List<SuperOverFielderSpot> fielderSpotsForSectors(
    List<int> fieldSectors,
  ) {
    final counts = [
      fieldSectors.elementAtOrNull(0) ?? 0,
      fieldSectors.elementAtOrNull(1) ?? 0,
      fieldSectors.elementAtOrNull(2) ?? 0,
    ];
    final spots = <SuperOverFielderSpot>[
      ..._offFieldTemplate.take(
        counts[0].clamp(0, _offFieldTemplate.length).toInt(),
      ),
      ..._vFieldTemplate.take(
        counts[1].clamp(0, _vFieldTemplate.length).toInt(),
      ),
      ..._legFieldTemplate.take(
        counts[2].clamp(0, _legFieldTemplate.length).toInt(),
      ),
    ];
    return spots;
  }

  static ShotSector? openSectorForSectors(List<int> fieldSectors) {
    if (fieldSectors.length < 3) return null;
    final counts = fieldSectors.take(3).toList(growable: false);
    final minimum = counts.reduce(min);
    final indexes = <int>[
      for (var i = 0; i < counts.length; i++)
        if (counts[i] == minimum) i,
    ];
    return indexes.length == 1 ? sectorFromIndex(indexes.single) : null;
  }

  static int shotPower({
    required TimingTier tier,
    required int rating,
    required DeliveryType delivery,
    bool onFire = false,
    Random? random,
  }) {
    final rng = random ?? _random;
    final tierPower = switch (tier) {
      TimingTier.perfect => 100,
      TimingTier.great => 78,
      TimingTier.good => 55,
      TimingTier.edgePoor => 25,
      TimingTier.miss => 0,
    };
    final ratingPower = ((rating - 70) * 0.7).clamp(0, 18).round();
    final deliveryPower = switch (delivery) {
      DeliveryType.pace when tier != TimingTier.miss => 5,
      DeliveryType.yorker when tier != TimingTier.perfect => -8,
      _ => 0,
    };
    final momentumPower = onFire ? 12 : 0;
    final variance = tier == TimingTier.miss ? 0 : rng.nextInt(7) - 3;
    return max(
      0,
      tierPower + ratingPower + deliveryPower + momentumPower + variance,
    );
  }

  static SuperOverShotResult resolveShot({
    required int timingErrorMs,
    required int rating,
    required DeliveryType delivery,
    required List<int> fieldSectors,
    bool onFire = false,
    bool leftHanded = false,
    ShotSector? intendedSector,
    ShotStyle shotStyle = ShotStyle.loft,
    CricketBattingStyle battingStyle = CricketBattingStyle.anchor,
    SuperOverDifficulty difficulty = SuperOverDifficulty.pro,
    Random? random,
  }) {
    final window = effectiveTimingWindowMs(
      rating,
      delivery,
      onFire: onFire,
      difficulty: difficulty,
    );
    final normalized = normalizedTimingError(
      timingErrorMs: timingErrorMs,
      effectiveWindowMs: window,
    );
    final tier = timingTierForNormalizedError(normalized);
    final drift = timingDriftForNormalizedError(normalized);
    final sector = intendedSector == null
        ? sectorForTiming(normalized, leftHanded: leftHanded)
        : sectorForIntentAndTiming(
            intendedSector: intendedSector,
            normalizedError: normalized,
            leftHanded: leftHanded,
          );
    var power = shotPower(
      tier: tier,
      rating: rating,
      delivery: delivery,
      onFire: onFire,
      random: random,
    );
    if (shotStyle == ShotStyle.loft) power += 8;
    if (shotStyle == ShotStyle.ground) power -= 4;
    if (battingStyle == CricketBattingStyle.powerHitter &&
        shotStyle == ShotStyle.loft) {
      power += 10;
    }
    if (drift == TimingDrift.early) power = max(0, power - 4);
    if (drift == TimingDrift.late) power = max(0, power - 10);
    final outcome = resolveOutcome(
      tier,
      sector: sector,
      power: power,
      fieldSectors: fieldSectors,
      sectorFielders: fieldSectors.elementAtOrNull(sectorIndex(sector)) ?? 2,
      delivery: delivery,
      onFire: onFire,
      shotStyle: shotStyle,
      battingStyle: battingStyle,
      random: random,
    );

    return SuperOverShotResult(
      timingErrorMs: timingErrorMs,
      normalizedError: normalized,
      tier: tier,
      sector: sector,
      power: power,
      outcome: outcome,
      drift: drift,
    );
  }

  static ShotOutcome resolveOutcome(
    TimingTier tier, {
    ShotSector? sector,
    int? power,
    List<int>? fieldSectors,
    int sectorFielders = 2,
    DeliveryType delivery = DeliveryType.pace,
    bool onFire = false,
    ShotStyle shotStyle = ShotStyle.loft,
    CricketBattingStyle battingStyle = CricketBattingStyle.anchor,
    Random? random,
  }) {
    final rng = random ?? _random;
    final weights = <ShotOutcome, double>{};

    switch (tier) {
      case TimingTier.perfect:
        weights[ShotOutcome.six] = 65;
        weights[ShotOutcome.four] = 35;
      case TimingTier.great:
        weights[ShotOutcome.four] = 45;
        weights[ShotOutcome.three] = 25;
        weights[ShotOutcome.two] = 25;
        weights[ShotOutcome.one] = 5;
      case TimingTier.good:
        weights[ShotOutcome.four] = 15;
        weights[ShotOutcome.two] = 35;
        weights[ShotOutcome.one] = 35;
        weights[ShotOutcome.dot] = 15;
      case TimingTier.edgePoor:
        weights[ShotOutcome.caught] = 18;
        weights[ShotOutcome.dot] = 35;
        weights[ShotOutcome.one] = 32;
        weights[ShotOutcome.two] = 15;
      case TimingTier.miss:
        weights[ShotOutcome.bowled] = delivery == DeliveryType.yorker ? 88 : 80;
        weights[ShotOutcome.dot] = 100 - weights[ShotOutcome.bowled]!;
    }

    final openGap = fieldSectors == null
        ? sectorFielders <= 1
        : sector != null && openSectorForSectors(fieldSectors) == sector;
    final packed = sectorFielders >= 4;
    if (openGap) {
      _scale(weights, ShotOutcome.caught, 0.55);
      _shiftBoundaryAndDot(weights, boundaryDelta: 10, dotDelta: -10);
    } else if (packed) {
      _scale(weights, ShotOutcome.caught, 1.15);
      _shiftBoundaryAndDot(weights, boundaryDelta: -10, dotDelta: 7);
    }

    if (onFire) {
      _scale(weights, ShotOutcome.caught, 0.85);
      _shiftBoundaryAndDot(weights, boundaryDelta: 5, dotDelta: -5);
    }

    if (shotStyle == ShotStyle.ground) {
      final six = weights.remove(ShotOutcome.six) ?? 0;
      weights[ShotOutcome.four] = (weights[ShotOutcome.four] ?? 0) + six * 0.72;
      weights[ShotOutcome.two] = (weights[ShotOutcome.two] ?? 0) + six * 0.28;
      _scale(weights, ShotOutcome.caught, 0.42);
      if (battingStyle == CricketBattingStyle.anchor) {
        _scale(weights, ShotOutcome.caught, 0.72);
        _shiftBoundaryAndDot(weights, boundaryDelta: 3, dotDelta: -3);
      }
    } else {
      _scale(weights, ShotOutcome.caught, 1.34);
      _shiftBoundaryAndDot(weights, boundaryDelta: 8, dotDelta: -4);
      if (battingStyle == CricketBattingStyle.powerHitter) {
        _shiftBoundaryAndDot(weights, boundaryDelta: 7, dotDelta: -3);
      }
    }

    _normalize(weights);
    final total = weights.values.fold<double>(0, (s, n) => s + n);
    var roll = rng.nextDouble() * total;
    for (final entry in weights.entries) {
      roll -= entry.value;
      if (roll <= 0) {
        return _applyCatchingField(
          entry.key,
          tier: tier,
          sector: sector,
          power: power,
          fieldSectors: fieldSectors,
          onFire: onFire,
          random: rng,
        );
      }
    }
    return _applyCatchingField(
      weights.keys.last,
      tier: tier,
      sector: sector,
      power: power,
      fieldSectors: fieldSectors,
      onFire: onFire,
      random: rng,
    );
  }

  static ShotOutcome _applyCatchingField(
    ShotOutcome outcome, {
    required TimingTier tier,
    ShotSector? sector,
    int? power,
    List<int>? fieldSectors,
    required bool onFire,
    required Random random,
  }) {
    if (outcome == ShotOutcome.bowled || outcome == ShotOutcome.caught) {
      return outcome;
    }
    if (sector == null || power == null || fieldSectors == null) return outcome;
    if (!_isCatchableTier(tier)) return outcome;
    if (outcome == ShotOutcome.six) return outcome;
    if (outcome == ShotOutcome.dot && tier != TimingTier.edgePoor) {
      return outcome;
    }

    final range = _rangeForOutcome(outcome, power: power);
    final angle = shotAngleForSector(sector);
    final end = Point(cos(angle) * range, sin(angle) * range);
    const start = Point<double>(0, 0);

    final catchRadius = switch (tier) {
      TimingTier.perfect => 0.0,
      TimingTier.great => 0.028,
      TimingTier.good => 0.045,
      TimingTier.edgePoor => 0.082,
      TimingTier.miss => 0.0,
    };
    final adjustedRadius = catchRadius * (onFire ? 0.74 : 1.0);
    if (adjustedRadius <= 0) return outcome;

    var bestChance = 0.0;
    final sectorFielders =
        fieldSectors.elementAtOrNull(sectorIndex(sector)) ?? 0;
    final fieldPressure = max(0, sectorFielders - 3) * 0.018;
    for (final spot in fielderSpotsForSectors(fieldSectors)) {
      if (spot.sector != sector && tier != TimingTier.edgePoor) continue;
      final fielder = Point(
        cos(spot.angle) * spot.radial,
        sin(spot.angle) * spot.radial,
      );
      final radius = adjustedRadius + (spot.closeCatcher ? 0.012 : 0.0);
      if (fielder.distanceTo(start) > range + radius) continue;
      final distance = _distanceToSegment(fielder, start, end);
      if (distance > radius) continue;

      final proximity = (1 - distance / radius).clamp(0.0, 1.0);
      final baseChance = switch (tier) {
        TimingTier.perfect => 0.0,
        TimingTier.great => 0.025,
        TimingTier.good => 0.070,
        TimingTier.edgePoor => 0.220,
        TimingTier.miss => 0.0,
      };
      var chance =
          baseChance +
          proximity * 0.075 +
          fieldPressure +
          (spot.closeCatcher ? 0.025 : 0.0);
      if (outcome == ShotOutcome.four) chance *= 0.45;
      if (onFire) chance *= 0.70;
      bestChance = max(bestChance, chance.clamp(0.0, 0.42));
    }
    return random.nextDouble() < bestChance ? ShotOutcome.caught : outcome;
  }

  static bool _isCatchableTier(TimingTier tier) {
    return switch (tier) {
      TimingTier.great || TimingTier.good || TimingTier.edgePoor => true,
      TimingTier.perfect || TimingTier.miss => false,
    };
  }

  static double _rangeForOutcome(ShotOutcome outcome, {required int power}) {
    final base = switch (outcome) {
      ShotOutcome.six => 1.08,
      ShotOutcome.four => 0.96,
      ShotOutcome.three => 0.80,
      ShotOutcome.two => 0.64,
      ShotOutcome.one => 0.48,
      ShotOutcome.dot => 0.28,
      ShotOutcome.caught => 0.68,
      ShotOutcome.bowled => 0.0,
    };
    if (outcome == ShotOutcome.six || outcome == ShotOutcome.four) {
      return base;
    }
    return (base + (power - 55).clamp(-24, 36) * 0.003).clamp(0.20, 0.92);
  }

  static double _distanceToSegment(
    Point<double> p,
    Point<double> a,
    Point<double> b,
  ) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final lengthSq = dx * dx + dy * dy;
    if (lengthSq == 0) return p.distanceTo(a);
    final t = (((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq).clamp(
      0.0,
      1.0,
    );
    final projection = Point(a.x + dx * t, a.y + dy * t);
    return p.distanceTo(projection);
  }

  static void _scale(
    Map<ShotOutcome, double> weights,
    ShotOutcome outcome,
    double factor,
  ) {
    if (weights.containsKey(outcome)) {
      weights[outcome] = weights[outcome]! * factor;
    }
  }

  static void _shiftBoundaryAndDot(
    Map<ShotOutcome, double> weights, {
    required double boundaryDelta,
    required double dotDelta,
  }) {
    final boundaryOutcomes = [ShotOutcome.six, ShotOutcome.four];
    final boundaryTotal = boundaryOutcomes.fold<double>(
      0,
      (sum, outcome) => sum + (weights[outcome] ?? 0),
    );
    if (boundaryTotal > 0) {
      for (final outcome in boundaryOutcomes) {
        final current = weights[outcome];
        if (current == null) continue;
        weights[outcome] = max(
          0,
          current + boundaryDelta * (current / boundaryTotal),
        );
      }
    }
    if (weights.containsKey(ShotOutcome.dot)) {
      weights[ShotOutcome.dot] = max(0, weights[ShotOutcome.dot]! + dotDelta);
    }
  }

  static void _normalize(Map<ShotOutcome, double> weights) {
    weights.removeWhere((_, value) => value <= 0);
    final total = weights.values.fold<double>(0, (sum, n) => sum + n);
    if (total <= 0) {
      weights
        ..clear()
        ..[ShotOutcome.dot] = 1;
    }
  }

  static int runsForOutcome(ShotOutcome outcome) {
    return switch (outcome) {
      ShotOutcome.six => 6,
      ShotOutcome.four => 4,
      ShotOutcome.three => 3,
      ShotOutcome.two => 2,
      ShotOutcome.one => 1,
      ShotOutcome.dot => 0,
      ShotOutcome.caught => 0,
      ShotOutcome.bowled => 0,
    };
  }
}

CricketJersey cricketJerseyFromName(String? name) {
  final current = CricketJersey.values.where((jersey) => jersey.name == name);
  if (current.isNotEmpty) return current.first;
  return switch (name) {
    // Version-zero IPL-derived persisted values are migrated by colour only.
    'mumbai' || 'delhi' => CricketJersey.nightCyan,
    'kolkata' || 'rajasthan' => CricketJersey.violetPulse,
    'chennai' => CricketJersey.goldStrike,
    'bangalore' || 'punjab' => CricketJersey.emberRed,
    'hyderabad' || 'gujarat' => CricketJersey.tealVector,
    'lucknow' => CricketJersey.monoIce,
    _ => CricketJersey.nightCyan,
  };
}

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final value in values) {
    if (value.name == raw) return value;
  }
  return fallback;
}

Map<String, dynamic> _jsonMap(Object? raw) {
  if (raw is! Map) return const {};
  return Map<String, dynamic>.from(raw);
}

List<Map<String, dynamic>> _jsonMapList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map) Map<String, dynamic>.from(item),
  ];
}

List<int> _intList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final value in raw)
      if (value is num) value.toInt(),
  ];
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final value in raw)
      if (value is String) value,
  ];
}

Map<String, int> _intMap(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries)
      if (entry.key is String && entry.value is num)
        entry.key as String: (entry.value as num).toInt(),
  };
}

const Object _sentinel = Object();
