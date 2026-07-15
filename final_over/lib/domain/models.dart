import 'dart:math' as math;

/// Every value in the domain layer is expressed without Flutter or Flame types.
enum MatchPhase {
  idle,
  matchIntro,
  deliveryPreparation,
  bowlerRunUp,
  incomingBall,
  contact,
  cameraTransition,
  fieldPlay,
  runDecision,
  runnersMoving,
  throwInProgress,
  deliveryResult,
  betweenBalls,
  paused,
  won,
  lost,
  quit,
}

enum Elevation { ground, loft }

enum ShotDirection { offSide, straight, legSide }

enum TimingGrade { perfect, good, early, late, poor, miss }

enum DeliveryLine { wideOff, off, middle, leg, wideLeg }

enum DeliveryLength { yorker, full, good, short }

enum ExtraType { none, wide, noBall }

enum DismissalType { none, bowled, caught, runOut }

enum ContactType { none, miss, clean, edge }

enum RiskLevel { safe, close, danger }

enum ObjectiveType {
  twoBoundaries,
  sixRunsFirstThreeLegalBalls,
  completeDouble,
}

enum FielderRole { outfielder, wicketkeeper, bowler }

enum FielderMotion {
  idle,
  reacting,
  chasing,
  backup,
  catching,
  carrying,
  throwing,
}

enum MatchEndReason { targetReached, ballsExhausted, wicketsLost, quit }

/// A small immutable vector used by rules and the simulation.
final class FieldVector {
  const FieldVector(this.x, this.y);

  static const zero = FieldVector(0, 0);

  final double x;
  final double y;

  double get lengthSquared => x * x + y * y;
  double get length => math.sqrt(lengthSquared);

  FieldVector get normalized {
    final magnitude = length;
    return magnitude == 0 ? zero : this / magnitude;
  }

  double distanceTo(FieldVector other) => (this - other).length;
  double dot(FieldVector other) => x * other.x + y * other.y;

  FieldVector operator +(FieldVector other) =>
      FieldVector(x + other.x, y + other.y);
  FieldVector operator -(FieldVector other) =>
      FieldVector(x - other.x, y - other.y);
  FieldVector operator *(double scale) => FieldVector(x * scale, y * scale);
  FieldVector operator /(double scale) => FieldVector(x / scale, y / scale);

  static FieldVector lerp(FieldVector a, FieldVector b, double t) =>
      a + (b - a) * t.clamp(0.0, 1.0);

  static FieldVector fromShotAngle(double angleDegrees) {
    final radians = angleDegrees * math.pi / 180;
    return FieldVector(math.sin(radians), -math.cos(radians));
  }

  @override
  bool operator ==(Object other) =>
      other is FieldVector && x == other.x && y == other.y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'FieldVector($x, $y)';
}

final class DeliverySpec {
  const DeliverySpec({
    required this.ordinal,
    required this.seed,
    required this.line,
    required this.length,
    required this.speed,
    required this.movement,
    required this.extra,
    required this.lineX,
    required this.expectedContactMicros,
    this.isFairFinalBall = false,
  });

  final int ordinal;
  final int seed;
  final DeliveryLine line;
  final DeliveryLength length;
  final double speed;
  final double movement;
  final ExtraType extra;
  final double lineX;
  final int expectedContactMicros;
  final bool isFairFinalBall;

  bool get isLegal => extra == ExtraType.none;
  bool get isWide => extra == ExtraType.wide;
  bool get isNoBall => extra == ExtraType.noBall;
  double get contactX => lineX + movement;
}

final class SwingIntent {
  const SwingIntent({
    required this.direction,
    required this.inputMicros,
    this.powerShot = false,
    this.charge,
  });

  final ShotDirection direction;
  final int inputMicros;
  final bool powerShot;

  /// How loaded the bat was when the swing was released, 0..1. Null means the
  /// input carried no backlift at all (a headless bot, a replay from before the
  /// backlift existed) — such a swing is judged on timing alone.
  final double? charge;
}

final class ContactOutcome {
  const ContactOutcome({
    required this.type,
    required this.timing,
    required this.timingErrorMs,
    required this.direction,
    required this.elevation,
    required this.power,
    required this.control,
    required this.shotAngleDegrees,
    required this.velocity,
    required this.verticalVelocity,
    required this.acceptedSwing,
    required this.powerShotUsed,
    this.bowledThreat = false,
  });

  const ContactOutcome.noSwing({
    required Elevation elevation,
    bool bowledThreat = false,
  }) : this(
         type: ContactType.miss,
         timing: TimingGrade.miss,
         timingErrorMs: 276,
         direction: ShotDirection.straight,
         elevation: elevation,
         power: 0,
         control: 0,
         shotAngleDegrees: 0,
         velocity: FieldVector.zero,
         verticalVelocity: 0,
         acceptedSwing: false,
         powerShotUsed: false,
         bowledThreat: bowledThreat,
       );

  final ContactType type;
  final TimingGrade timing;
  final int timingErrorMs;
  final ShotDirection direction;
  final Elevation elevation;
  final double power;
  final double control;
  final double shotAngleDegrees;
  final FieldVector velocity;
  final double verticalVelocity;
  final bool acceptedSwing;
  final bool powerShotUsed;
  final bool bowledThreat;

  bool get madeContact => type == ContactType.clean || type == ContactType.edge;
}

final class BallKinematics {
  const BallKinematics({
    required this.position,
    required this.velocity,
    required this.height,
    required this.verticalVelocity,
    required this.aerial,
    this.firstBounceOccurred = false,
    this.stopped = false,
  });

  static const atContact = BallKinematics(
    position: FieldVector(0, 0.19),
    velocity: FieldVector.zero,
    height: 0,
    verticalVelocity: 0,
    aerial: false,
  );

  final FieldVector position;
  final FieldVector velocity;
  final double height;
  final double verticalVelocity;
  final bool aerial;
  final bool firstBounceOccurred;
  final bool stopped;

  BallKinematics copyWith({
    FieldVector? position,
    FieldVector? velocity,
    double? height,
    double? verticalVelocity,
    bool? aerial,
    bool? firstBounceOccurred,
    bool? stopped,
  }) => BallKinematics(
    position: position ?? this.position,
    velocity: velocity ?? this.velocity,
    height: height ?? this.height,
    verticalVelocity: verticalVelocity ?? this.verticalVelocity,
    aerial: aerial ?? this.aerial,
    firstBounceOccurred: firstBounceOccurred ?? this.firstBounceOccurred,
    stopped: stopped ?? this.stopped,
  );
}

final class RunnerState {
  const RunnerState({
    this.active = false,
    this.returning = false,
    this.runNumber = 0,
    this.progress = 0,
    this.completedRuns = 0,
    this.risk = RiskLevel.safe,
  });

  final bool active;
  final bool returning;
  final int runNumber;
  final double progress;
  final int completedRuns;
  final RiskLevel risk;

  bool get canTurnBack => active && !returning && progress <= 0.45;

  RunnerState copyWith({
    bool? active,
    bool? returning,
    int? runNumber,
    double? progress,
    int? completedRuns,
    RiskLevel? risk,
  }) => RunnerState(
    active: active ?? this.active,
    returning: returning ?? this.returning,
    runNumber: runNumber ?? this.runNumber,
    progress: progress ?? this.progress,
    completedRuns: completedRuns ?? this.completedRuns,
    risk: risk ?? this.risk,
  );
}

final class FielderState {
  const FielderState({
    required this.id,
    required this.role,
    required this.homePosition,
    required this.position,
    this.velocity = FieldVector.zero,
    this.motion = FielderMotion.idle,
    this.hasBall = false,
    this.reactionRemainingSeconds = 0,
  });

  final int id;
  final FielderRole role;
  final FieldVector homePosition;
  final FieldVector position;
  final FieldVector velocity;
  final FielderMotion motion;
  final bool hasBall;
  final double reactionRemainingSeconds;

  FielderState copyWith({
    FieldVector? position,
    FieldVector? velocity,
    FielderMotion? motion,
    bool? hasBall,
    double? reactionRemainingSeconds,
  }) => FielderState(
    id: id,
    role: role,
    homePosition: homePosition,
    position: position ?? this.position,
    velocity: velocity ?? this.velocity,
    motion: motion ?? this.motion,
    hasBall: hasBall ?? this.hasBall,
    reactionRemainingSeconds:
        reactionRemainingSeconds ?? this.reactionRemainingSeconds,
  );
}

final class DeliveryLedger {
  const DeliveryLedger({
    this.extraRuns = 0,
    this.batRuns = 0,
    this.completedRuns = 0,
    this.dismissal = DismissalType.none,
    this.boundary = 0,
    this.extraApplied = false,
    this.finalized = false,
  });

  final int extraRuns;
  final int batRuns;
  final int completedRuns;
  final DismissalType dismissal;
  final int boundary;
  final bool extraApplied;
  final bool finalized;

  int get totalRuns => extraRuns + batRuns + completedRuns;

  DeliveryLedger copyWith({
    int? extraRuns,
    int? batRuns,
    int? completedRuns,
    DismissalType? dismissal,
    int? boundary,
    bool? extraApplied,
    bool? finalized,
  }) => DeliveryLedger(
    extraRuns: extraRuns ?? this.extraRuns,
    batRuns: batRuns ?? this.batRuns,
    completedRuns: completedRuns ?? this.completedRuns,
    dismissal: dismissal ?? this.dismissal,
    boundary: boundary ?? this.boundary,
    extraApplied: extraApplied ?? this.extraApplied,
    finalized: finalized ?? this.finalized,
  );
}

final class BallResult {
  const BallResult({
    required this.deliveryOrdinal,
    required this.legalBallsBefore,
    required this.legal,
    required this.extra,
    required this.extraRuns,
    required this.runsOffBat,
    required this.completedRunningRuns,
    required this.boundary,
    required this.dismissal,
    required this.contactType,
    required this.timing,
    required this.freeHitDelivery,
    required this.historyToken,
  });

  final int deliveryOrdinal;
  final int legalBallsBefore;
  final bool legal;
  final ExtraType extra;
  final int extraRuns;
  final int runsOffBat;
  final int completedRunningRuns;
  final int boundary;
  final DismissalType dismissal;
  final ContactType contactType;
  final TimingGrade timing;
  final bool freeHitDelivery;
  final String historyToken;

  int get totalRuns => extraRuns + runsOffBat + completedRunningRuns;
  bool get isWicket => dismissal != DismissalType.none;
  bool get isBoundary => boundary == 4 || boundary == 6;
  bool get isProductiveContact =>
      contactType != ContactType.none &&
      contactType != ContactType.miss &&
      (runsOffBat + completedRunningRuns) > 0;
}

final class SimulationSnapshot {
  SimulationSnapshot({
    required this.simulationMicros,
    required this.phase,
    required this.ball,
    required this.cameraTransition,
    required this.runner,
    required List<FielderState> fielders,
    required this.risk,
    required this.canRun,
  }) : fielders = List.unmodifiable(fielders);

  final int simulationMicros;
  final MatchPhase phase;
  final BallKinematics? ball;
  final double cameraTransition;
  final RunnerState runner;
  final List<FielderState> fielders;
  final RiskLevel risk;
  final bool canRun;
}

const Object _unset = Object();

/// Immutable single source of truth for a match.
final class MatchState {
  MatchState({
    required this.matchSeed,
    required this.target,
    required this.phase,
    this.suspendedPhase,
    required this.committedScore,
    required this.legalBalls,
    required this.physicalDeliveries,
    required this.wickets,
    required this.pendingRuns,
    required this.pendingExtras,
    required this.pendingBatRuns,
    required this.freeHit,
    required this.currentDeliveryFreeHit,
    required this.combo,
    required this.powerSegments,
    required this.powerShotArmed,
    required this.selectedElevation,
    required this.selectedDirection,
    required this.objective,
    required this.objectiveProgress,
    required this.objectiveCompleted,
    required this.stars,
    required this.simulationMicros,
    required this.phaseElapsedMicros,
    this.currentDelivery,
    this.swingIntent,
    this.contactOutcome,
    this.ball,
    required this.cameraTransition,
    required this.runner,
    required List<FielderState> fielders,
    required this.ledger,
    required List<BallResult> history,
    this.lastResult,
    required this.deliveryFinalized,
    required this.canRun,
    required this.holdRequested,
    required this.ballHeld,
    required this.pickupDecisionMicros,
    required this.throwArrivalMicros,
    this.endReason,
  }) : fielders = List.unmodifiable(fielders),
       history = List.unmodifiable(history);

  factory MatchState.initial() => MatchState(
    matchSeed: 0,
    target: 14,
    phase: MatchPhase.idle,
    committedScore: 0,
    legalBalls: 0,
    physicalDeliveries: 0,
    wickets: 0,
    pendingRuns: 0,
    pendingExtras: 0,
    pendingBatRuns: 0,
    freeHit: false,
    currentDeliveryFreeHit: false,
    combo: 1,
    powerSegments: 0,
    powerShotArmed: false,
    selectedElevation: Elevation.ground,
    selectedDirection: ShotDirection.straight,
    objective: ObjectiveType.completeDouble,
    objectiveProgress: 0,
    objectiveCompleted: false,
    stars: 0,
    simulationMicros: 0,
    phaseElapsedMicros: 0,
    cameraTransition: 0,
    runner: const RunnerState(),
    fielders: const [],
    ledger: const DeliveryLedger(),
    history: const [],
    deliveryFinalized: false,
    canRun: false,
    holdRequested: false,
    ballHeld: false,
    pickupDecisionMicros: 0,
    throwArrivalMicros: 0,
  );

  final int matchSeed;
  final int target;
  final MatchPhase phase;
  final MatchPhase? suspendedPhase;
  final int committedScore;
  final int legalBalls;
  final int physicalDeliveries;
  final int wickets;
  final int pendingRuns;
  final int pendingExtras;
  final int pendingBatRuns;
  final bool freeHit;
  final bool currentDeliveryFreeHit;
  final int combo;
  final int powerSegments;
  final bool powerShotArmed;
  final Elevation selectedElevation;
  final ShotDirection selectedDirection;
  final ObjectiveType objective;
  final int objectiveProgress;
  final bool objectiveCompleted;
  final int stars;
  final int simulationMicros;
  final int phaseElapsedMicros;
  final DeliverySpec? currentDelivery;
  final SwingIntent? swingIntent;
  final ContactOutcome? contactOutcome;
  final BallKinematics? ball;
  final double cameraTransition;
  final RunnerState runner;
  final List<FielderState> fielders;
  final DeliveryLedger ledger;
  final List<BallResult> history;
  final BallResult? lastResult;
  final bool deliveryFinalized;
  final bool canRun;
  final bool holdRequested;
  final bool ballHeld;
  final int pickupDecisionMicros;
  final int throwArrivalMicros;
  final MatchEndReason? endReason;

  int get score =>
      committedScore + pendingRuns + pendingExtras + pendingBatRuns;
  int get runsNeeded => math.max(0, target - score);
  int get ballsRemaining => math.max(0, 6 - legalBalls);

  /// How many more you can lose. Takes the limit because the wickets in hand
  /// are a difficulty knob (`GameplayTuning.maximumWickets`), not a constant.
  int wicketsRemaining(int maximumWickets) =>
      math.max(0, maximumWickets - wickets);
  bool get isTerminal => phase == MatchPhase.won || phase == MatchPhase.lost;
  bool get isPaused => phase == MatchPhase.paused;
  bool get canConfigureShot => phase == MatchPhase.deliveryPreparation;
  bool get canSwing =>
      phase == MatchPhase.incomingBall &&
      swingIntent == null &&
      contactOutcome == null &&
      !deliveryFinalized &&
      currentDelivery != null;

  MatchState copyWith({
    int? matchSeed,
    int? target,
    MatchPhase? phase,
    Object? suspendedPhase = _unset,
    int? committedScore,
    int? legalBalls,
    int? physicalDeliveries,
    int? wickets,
    int? pendingRuns,
    int? pendingExtras,
    int? pendingBatRuns,
    bool? freeHit,
    bool? currentDeliveryFreeHit,
    int? combo,
    int? powerSegments,
    bool? powerShotArmed,
    Elevation? selectedElevation,
    ShotDirection? selectedDirection,
    ObjectiveType? objective,
    int? objectiveProgress,
    bool? objectiveCompleted,
    int? stars,
    int? simulationMicros,
    int? phaseElapsedMicros,
    Object? currentDelivery = _unset,
    Object? swingIntent = _unset,
    Object? contactOutcome = _unset,
    Object? ball = _unset,
    double? cameraTransition,
    RunnerState? runner,
    List<FielderState>? fielders,
    DeliveryLedger? ledger,
    List<BallResult>? history,
    Object? lastResult = _unset,
    bool? deliveryFinalized,
    bool? canRun,
    bool? holdRequested,
    bool? ballHeld,
    int? pickupDecisionMicros,
    int? throwArrivalMicros,
    Object? endReason = _unset,
  }) => MatchState(
    matchSeed: matchSeed ?? this.matchSeed,
    target: target ?? this.target,
    phase: phase ?? this.phase,
    suspendedPhase: identical(suspendedPhase, _unset)
        ? this.suspendedPhase
        : suspendedPhase as MatchPhase?,
    committedScore: committedScore ?? this.committedScore,
    legalBalls: legalBalls ?? this.legalBalls,
    physicalDeliveries: physicalDeliveries ?? this.physicalDeliveries,
    wickets: wickets ?? this.wickets,
    pendingRuns: pendingRuns ?? this.pendingRuns,
    pendingExtras: pendingExtras ?? this.pendingExtras,
    pendingBatRuns: pendingBatRuns ?? this.pendingBatRuns,
    freeHit: freeHit ?? this.freeHit,
    currentDeliveryFreeHit:
        currentDeliveryFreeHit ?? this.currentDeliveryFreeHit,
    combo: combo ?? this.combo,
    powerSegments: powerSegments ?? this.powerSegments,
    powerShotArmed: powerShotArmed ?? this.powerShotArmed,
    selectedElevation: selectedElevation ?? this.selectedElevation,
    selectedDirection: selectedDirection ?? this.selectedDirection,
    objective: objective ?? this.objective,
    objectiveProgress: objectiveProgress ?? this.objectiveProgress,
    objectiveCompleted: objectiveCompleted ?? this.objectiveCompleted,
    stars: stars ?? this.stars,
    simulationMicros: simulationMicros ?? this.simulationMicros,
    phaseElapsedMicros: phaseElapsedMicros ?? this.phaseElapsedMicros,
    currentDelivery: identical(currentDelivery, _unset)
        ? this.currentDelivery
        : currentDelivery as DeliverySpec?,
    swingIntent: identical(swingIntent, _unset)
        ? this.swingIntent
        : swingIntent as SwingIntent?,
    contactOutcome: identical(contactOutcome, _unset)
        ? this.contactOutcome
        : contactOutcome as ContactOutcome?,
    ball: identical(ball, _unset) ? this.ball : ball as BallKinematics?,
    cameraTransition: cameraTransition ?? this.cameraTransition,
    runner: runner ?? this.runner,
    fielders: fielders ?? this.fielders,
    ledger: ledger ?? this.ledger,
    history: history ?? this.history,
    lastResult: identical(lastResult, _unset)
        ? this.lastResult
        : lastResult as BallResult?,
    deliveryFinalized: deliveryFinalized ?? this.deliveryFinalized,
    canRun: canRun ?? this.canRun,
    holdRequested: holdRequested ?? this.holdRequested,
    ballHeld: ballHeld ?? this.ballHeld,
    pickupDecisionMicros: pickupDecisionMicros ?? this.pickupDecisionMicros,
    throwArrivalMicros: throwArrivalMicros ?? this.throwArrivalMicros,
    endReason: identical(endReason, _unset)
        ? this.endReason
        : endReason as MatchEndReason?,
  );
}
