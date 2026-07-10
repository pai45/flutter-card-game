import '../../models/cards.dart';
import '../../models/super_over.dart';

class SuperOverState {
  const SuperOverState({
    this.jersey = CricketJersey.mumbai,
    this.score = 0,
    this.wickets = 0,
    this.ballsFaced = 0,
    this.battingOrder = const [],
    this.strikerIndex = 0,
    this.nonStrikerIndex = 1,
    this.momentum = 0,
    this.onFire = false,
    this.combo = 0,
    this.mode = SuperOverMode.scoreAttack,
    this.cpuTarget = 0,
    this.isOver = false,
    this.wonChase,
    this.wagonWheel = const [],
    this.phase = SuperOverPhase.ready,
    this.fieldSectors = const [3, 3, 3],
    this.upcomingDelivery = DeliveryType.pace,
    this.inputEnabled = false,
    this.swingLocked = false,
    this.timingErrorMs,
    this.normalizedTimingError,
    this.timingTier,
    this.shotSector,
    this.shotPower,
    this.lastOutcome,
  });

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
  final SuperOverMode mode;
  final int cpuTarget;
  final bool isOver;
  final bool? wonChase;
  final List<ShotOutcome> wagonWheel;
  final SuperOverPhase phase;

  /// Fielders guarding OFF / V / LEG for the upcoming ball. Totals 9 in play.
  final List<int> fieldSectors;
  final DeliveryType upcomingDelivery;

  /// Live input and result feedback for the Flame scene and HUD.
  final bool inputEnabled;
  final bool swingLocked;
  final int? timingErrorMs;
  final double? normalizedTimingError;
  final TimingTier? timingTier;
  final ShotSector? shotSector;
  final int? shotPower;
  final ShotOutcome? lastOutcome;

  SuperOverState copyWith({
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
    SuperOverMode? mode,
    int? cpuTarget,
    bool? isOver,
    bool? wonChase,
    List<ShotOutcome>? wagonWheel,
    SuperOverPhase? phase,
    List<int>? fieldSectors,
    DeliveryType? upcomingDelivery,
    bool? inputEnabled,
    bool? swingLocked,
    Object? timingErrorMs = _sentinel,
    Object? normalizedTimingError = _sentinel,
    Object? timingTier = _sentinel,
    Object? shotSector = _sentinel,
    Object? shotPower = _sentinel,
    Object? lastOutcome = _sentinel,
  }) {
    return SuperOverState(
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
      mode: mode ?? this.mode,
      cpuTarget: cpuTarget ?? this.cpuTarget,
      isOver: isOver ?? this.isOver,
      wonChase: wonChase ?? this.wonChase,
      wagonWheel: wagonWheel ?? this.wagonWheel,
      phase: phase ?? this.phase,
      fieldSectors: fieldSectors ?? this.fieldSectors,
      upcomingDelivery: upcomingDelivery ?? this.upcomingDelivery,
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
    );
  }

  PlayerCard? get striker =>
      battingOrder.length > strikerIndex ? battingOrder[strikerIndex] : null;

  PlayerCard? get nonStriker => battingOrder.length > nonStrikerIndex
      ? battingOrder[nonStrikerIndex]
      : null;

  int get runsToWin => cpuTarget + 1 - score;
  int get ballsLeft => 6 - ballsFaced;
  bool get canTap => inputEnabled && !swingLocked && !isOver;
}

const Object _sentinel = Object();
