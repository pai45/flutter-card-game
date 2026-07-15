import '../../models/cards.dart';
import '../../models/super_over.dart';

class SuperOverState {
  const SuperOverState({
    this.flowPhase = SuperOverFlowPhase.landing,
    this.playPhase = SuperOverPlayPhase.fieldReveal,
    this.phase = SuperOverPhase.ready,
    this.config,
    this.settings = const SuperOverSettings(),
    this.jersey = CricketJersey.nightCyan,
    this.score = 0,
    this.wickets = 0,
    this.ballsFaced = 0,
    this.battingOrder = const [],
    this.strikerIndex = 0,
    this.nonStrikerIndex = 1,
    this.momentum = 0,
    this.onFire = false,
    this.combo = 0,
    this.maxCombo = 0,
    this.mode = SuperOverMode.scoreAttack,
    this.cpuTarget = 0,
    this.isOver = false,
    this.wonChase,
    this.wagonWheel = const [],
    this.ballRecords = const [],
    this.fieldSectors = const [3, 3, 3],
    this.fieldPlan,
    this.committedBall,
    this.deliveryPlan = const DeliveryPlan(),
    this.selectedSector = ShotSector.v,
    this.selectedShotStyle = ShotStyle.ground,
    this.confidence = 0,
    this.rhythmByCardId = const {},
    this.cleanContactStreak = 0,
    this.finisherProgress = 0,
    this.finisherReady = false,
    this.finisherActive = false,
    this.objective = const SuperOverObjective(
      type: SuperOverObjectiveType.runs,
      target: 12,
    ),
    this.objectiveProgress = 0,
    this.openGapHits = 0,
    this.perfectContacts = 0,
    this.inputEnabled = false,
    this.swingLocked = false,
    this.timingErrorMs,
    this.normalizedTimingError,
    this.timingTier,
    this.shotSector,
    this.shotPower,
    this.lastOutcome,
    this.summary,
  });

  final SuperOverFlowPhase flowPhase;
  final SuperOverPlayPhase playPhase;

  /// Compatibility phase consumed by the existing Flame bridge.
  final SuperOverPhase phase;
  final SuperOverMatchConfig? config;
  final SuperOverSettings settings;
  final CricketJersey jersey;
  final int score;
  final int wickets;
  final int ballsFaced;
  final List<PlayerCard> battingOrder;
  final int strikerIndex;
  final int nonStrikerIndex;
  final int momentum;
  final bool onFire;
  final int combo;
  final int maxCombo;
  final SuperOverMode mode;
  final int cpuTarget;
  final bool isOver;
  final bool? wonChase;
  final List<ShotOutcome> wagonWheel;
  final List<SuperOverBallRecord> ballRecords;

  /// Compatibility counts in OFF / STRAIGHT / LEG order.
  final List<int> fieldSectors;
  final SuperOverFieldPlan? fieldPlan;
  final SuperOverCommittedBall? committedBall;
  final DeliveryPlan deliveryPlan;
  final ShotSector selectedSector;
  final ShotStyle selectedShotStyle;

  /// [confidence] remains as a compatibility alias for current-batter Rhythm.
  final int confidence;
  final Map<String, int> rhythmByCardId;
  final int cleanContactStreak;
  final int finisherProgress;
  final bool finisherReady;
  final bool finisherActive;
  final SuperOverObjective objective;
  final int objectiveProgress;
  final int openGapHits;
  final int perfectContacts;

  final bool inputEnabled;
  final bool swingLocked;
  final int? timingErrorMs;
  final double? normalizedTimingError;
  final TimingTier? timingTier;
  final ShotSector? shotSector;
  final int? shotPower;
  final ShotOutcome? lastOutcome;
  final SuperOverMatchSummary? summary;

  SuperOverState copyWith({
    SuperOverFlowPhase? flowPhase,
    SuperOverPlayPhase? playPhase,
    SuperOverPhase? phase,
    Object? config = _sentinel,
    SuperOverSettings? settings,
    CricketJersey? jersey,
    int? score,
    int? wickets,
    int? ballsFaced,
    List<PlayerCard>? battingOrder,
    int? strikerIndex,
    int? nonStrikerIndex,
    int? momentum,
    bool? onFire,
    int? combo,
    int? maxCombo,
    SuperOverMode? mode,
    int? cpuTarget,
    bool? isOver,
    Object? wonChase = _sentinel,
    List<ShotOutcome>? wagonWheel,
    List<SuperOverBallRecord>? ballRecords,
    List<int>? fieldSectors,
    Object? fieldPlan = _sentinel,
    Object? committedBall = _sentinel,
    DeliveryPlan? deliveryPlan,
    ShotSector? selectedSector,
    ShotStyle? selectedShotStyle,
    int? confidence,
    Map<String, int>? rhythmByCardId,
    int? cleanContactStreak,
    int? finisherProgress,
    bool? finisherReady,
    bool? finisherActive,
    SuperOverObjective? objective,
    int? objectiveProgress,
    int? openGapHits,
    int? perfectContacts,
    bool? inputEnabled,
    bool? swingLocked,
    Object? timingErrorMs = _sentinel,
    Object? normalizedTimingError = _sentinel,
    Object? timingTier = _sentinel,
    Object? shotSector = _sentinel,
    Object? shotPower = _sentinel,
    Object? lastOutcome = _sentinel,
    Object? summary = _sentinel,
  }) {
    return SuperOverState(
      flowPhase: flowPhase ?? this.flowPhase,
      playPhase: playPhase ?? this.playPhase,
      phase: phase ?? this.phase,
      config: config == _sentinel
          ? this.config
          : config as SuperOverMatchConfig?,
      settings: settings ?? this.settings,
      jersey: jersey ?? this.jersey,
      score: score ?? this.score,
      wickets: wickets ?? this.wickets,
      ballsFaced: ballsFaced ?? this.ballsFaced,
      battingOrder: battingOrder ?? this.battingOrder,
      strikerIndex: strikerIndex ?? this.strikerIndex,
      nonStrikerIndex: nonStrikerIndex ?? this.nonStrikerIndex,
      momentum: momentum ?? this.momentum,
      onFire: onFire ?? this.onFire,
      combo: combo ?? this.combo,
      maxCombo: maxCombo ?? this.maxCombo,
      mode: mode ?? this.mode,
      cpuTarget: cpuTarget ?? this.cpuTarget,
      isOver: isOver ?? this.isOver,
      wonChase: wonChase == _sentinel ? this.wonChase : wonChase as bool?,
      wagonWheel: wagonWheel ?? this.wagonWheel,
      ballRecords: ballRecords ?? this.ballRecords,
      fieldSectors: fieldSectors ?? this.fieldSectors,
      fieldPlan: fieldPlan == _sentinel
          ? this.fieldPlan
          : fieldPlan as SuperOverFieldPlan?,
      committedBall: committedBall == _sentinel
          ? this.committedBall
          : committedBall as SuperOverCommittedBall?,
      deliveryPlan: deliveryPlan ?? this.deliveryPlan,
      selectedSector: selectedSector ?? this.selectedSector,
      selectedShotStyle: selectedShotStyle ?? this.selectedShotStyle,
      confidence: confidence ?? this.confidence,
      rhythmByCardId: rhythmByCardId ?? this.rhythmByCardId,
      cleanContactStreak: cleanContactStreak ?? this.cleanContactStreak,
      finisherProgress: finisherProgress ?? this.finisherProgress,
      finisherReady: finisherReady ?? this.finisherReady,
      finisherActive: finisherActive ?? this.finisherActive,
      objective: objective ?? this.objective,
      objectiveProgress: objectiveProgress ?? this.objectiveProgress,
      openGapHits: openGapHits ?? this.openGapHits,
      perfectContacts: perfectContacts ?? this.perfectContacts,
      inputEnabled: inputEnabled ?? this.inputEnabled,
      swingLocked: swingLocked ?? this.swingLocked,
      timingErrorMs: timingErrorMs == _sentinel
          ? this.timingErrorMs
          : timingErrorMs as int?,
      normalizedTimingError: normalizedTimingError == _sentinel
          ? this.normalizedTimingError
          : normalizedTimingError as double?,
      timingTier: timingTier == _sentinel
          ? this.timingTier
          : timingTier as TimingTier?,
      shotSector: shotSector == _sentinel
          ? this.shotSector
          : shotSector as ShotSector?,
      shotPower: shotPower == _sentinel ? this.shotPower : shotPower as int?,
      lastOutcome: lastOutcome == _sentinel
          ? this.lastOutcome
          : lastOutcome as ShotOutcome?,
      summary: summary == _sentinel
          ? this.summary
          : summary as SuperOverMatchSummary?,
    );
  }

  PlayerCard? get striker =>
      battingOrder.length > strikerIndex ? battingOrder[strikerIndex] : null;

  PlayerCard? get nonStriker => battingOrder.length > nonStrikerIndex
      ? battingOrder[nonStrikerIndex]
      : null;

  String? get strikerCardId => striker?.id;
  int get runsToWin => cpuTarget + 1 - score;
  int get ballsLeft => 6 - ballsFaced;
  bool get canTap => inputEnabled && !swingLocked && !isOver;
  bool get canSelectIntent =>
      !swingLocked &&
      !isOver &&
      (playPhase == SuperOverPlayPhase.fieldReveal ||
          playPhase == SuperOverPlayPhase.intentSelection ||
          playPhase == SuperOverPlayPhase.bowlerPreparation ||
          playPhase == SuperOverPlayPhase.runUp);

  DeliveryType get upcomingDelivery => deliveryPlan.type;

  ShotSector? get openSector =>
      fieldPlan?.openSector ??
      SuperOverFieldPlan.fromCounts(fieldSectors).openSector;

  Set<ShotSector> get packedSectors =>
      fieldPlan?.packedSectors ??
      SuperOverFieldPlan.fromCounts(fieldSectors).packedSectors;

  int get currentRhythm {
    final id = strikerCardId;
    return id == null ? confidence : rhythmByCardId[id] ?? confidence;
  }

  CricketBattingStyle get battingStyle {
    final trait = striker?.trait.toLowerCase();
    return switch (trait) {
      'all-rounder' => CricketBattingStyle.powerHitter,
      'wicket-keeper' => CricketBattingStyle.improviser,
      _ => CricketBattingStyle.anchor,
    };
  }

  bool get objectiveComplete => objectiveProgress >= objective.target;

  SuperOverMatchPosition get position => SuperOverMatchPosition(
    score: score,
    wickets: wickets,
    ballsFaced: ballsFaced,
    strikerIndex: strikerIndex,
    nonStrikerIndex: nonStrikerIndex,
    isComplete: isOver,
    wonChase: wonChase,
  );
}

const Object _sentinel = Object();
