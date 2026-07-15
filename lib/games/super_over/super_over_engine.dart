import 'dart:math';

import '../../models/cards.dart';
import '../../models/super_over.dart';

/// Pure Super Over rules. A committed ball is derived only from match config
/// and completed balls, so the bowler cannot inspect or counter a live input.
class SuperOverEngine {
  SuperOverEngine({Random? random, int? seed})
    : _random = random ?? Random(seed);

  final Random _random;

  static final List<SuperOverFieldPlan> fieldPresets = [
    SuperOverFieldPlan.fromCounts(const [2, 4, 3], id: 'straight-packed'),
    SuperOverFieldPlan.fromCounts(const [3, 3, 3], id: 'balanced'),
    SuperOverFieldPlan.fromCounts(const [4, 3, 2], id: 'off-packed'),
    SuperOverFieldPlan.fromCounts(const [2, 3, 4], id: 'leg-packed'),
    SuperOverFieldPlan.fromCounts(const [3, 4, 2], id: 'straight-leg-gap'),
    SuperOverFieldPlan.fromCounts(const [4, 2, 3], id: 'off-straight-gap'),
    SuperOverFieldPlan.fromCounts(const [1, 5, 3], id: 'extreme-straight'),
    SuperOverFieldPlan.fromCounts(const [3, 5, 1], id: 'reverse-extreme'),
  ];

  /// Commits the next field and delivery without accepting current-ball input.
  SuperOverCommittedBall planNextBall({
    required SuperOverMatchConfig config,
    required List<SuperOverBallRecord> completedBalls,
    int? target,
  }) {
    if (completedBalls.length >= 6) {
      throw StateError('A Super Over cannot contain more than six balls');
    }
    final ballNumber = completedBalls.length + 1;
    final planningSeed = _planningSeed(config.seed, ballNumber, completedBalls);
    if (config.tutorial) {
      return _tutorialBall(ballNumber, planningSeed);
    }
    final rng = Random(planningSeed);
    final tendency = _tendencyFor(completedBalls);
    final score = completedBalls.isEmpty ? 0 : completedBalls.last.scoreAfter;
    final finalBallBoundaryNeeded =
        config.mode == SuperOverMode.chase &&
        target != null &&
        ballNumber == 6 &&
        target + 1 - score >= 6;

    final planId = _bowlingPlanId(
      difficulty: config.difficulty,
      tendency: tendency,
      finalBallBoundaryNeeded: finalBallBoundaryNeeded,
    );
    final field = _fieldForPlan(
      planId: planId,
      tendency: tendency,
      difficulty: config.difficulty,
      rng: rng,
    );
    final delivery = _deliveryForPlan(
      planId: planId,
      playerLevel: config.level,
      ballNumber: ballNumber,
      difficulty: config.difficulty,
      rng: rng,
    );
    return SuperOverCommittedBall(
      ballNumber: ballNumber,
      planningSeed: planningSeed,
      fieldPlan: field,
      delivery: delivery,
    );
  }

  /// Alias used by state-management code that treats planning as a commit.
  SuperOverCommittedBall commitNextBall({
    required SuperOverMatchConfig config,
    required List<SuperOverBallRecord> completedBalls,
    int? target,
  }) => planNextBall(
    config: config,
    completedBalls: completedBalls,
    target: target,
  );

  int targetForConfig(SuperOverMatchConfig config) => config.tutorial
      ? 17
      : SuperOverResolution.targetForLevel(
          config.level,
          random: Random(_mixSeed(config.seed, const [0x74617267])),
        );

  SuperOverCommittedBall _tutorialBall(int ballNumber, int planningSeed) {
    final deliveries = <DeliveryPlan>[
      const DeliveryPlan(
        type: DeliveryType.pace,
        line: DeliveryLine.middle,
        length: DeliveryLength.good,
      ),
      const DeliveryPlan(
        type: DeliveryType.pace,
        line: DeliveryLine.off,
        length: DeliveryLength.full,
      ),
      const DeliveryPlan(
        type: DeliveryType.slower,
        line: DeliveryLine.leg,
        length: DeliveryLength.good,
        paceFactor: .82,
      ),
      const DeliveryPlan(
        type: DeliveryType.pace,
        line: DeliveryLine.leg,
        length: DeliveryLength.short,
        paceFactor: 1.05,
      ),
      const DeliveryPlan(
        type: DeliveryType.yorker,
        line: DeliveryLine.middle,
        length: DeliveryLength.yorker,
        paceFactor: 1.02,
      ),
      const DeliveryPlan(
        type: DeliveryType.slower,
        line: DeliveryLine.off,
        length: DeliveryLength.full,
        paceFactor: .78,
      ),
    ];
    final fields = <List<int>>[
      const [4, 3, 2],
      const [2, 4, 3],
      const [3, 3, 3],
      const [3, 5, 1],
      const [4, 2, 3],
      const [2, 3, 4],
    ];
    final index = (ballNumber - 1).clamp(0, 5);
    return SuperOverCommittedBall(
      ballNumber: ballNumber,
      planningSeed: planningSeed,
      fieldPlan: SuperOverFieldPlan.fromCounts(
        fields[index],
        id: 'tutorial-$ballNumber',
      ),
      delivery: deliveries[index],
    );
  }

  SuperOverObjective objectiveForConfig(
    SuperOverMatchConfig config, {
    int? target,
  }) {
    if (config.tutorial) {
      return const SuperOverObjective(
        type: SuperOverObjectiveType.runs,
        target: 12,
      );
    }
    final rng = Random(_mixSeed(config.seed, const [0x6f626a65]));
    final objective = _rollObjective(config.mode, config.level, rng);
    if (config.mode == SuperOverMode.chase &&
        target != null &&
        objective.type == SuperOverObjectiveType.runs) {
      return SuperOverObjective(
        type: SuperOverObjectiveType.runs,
        target: target + 1,
      );
    }
    return objective;
  }

  /// Legacy delivery API retained for existing BLoC callers.
  DeliveryPlan rollDelivery(
    int playerLevel, {
    SuperOverDifficulty difficulty = SuperOverDifficulty.pro,
  }) => _deliveryForPlan(
    planId: 'balanced',
    playerLevel: playerLevel,
    ballNumber: 1,
    difficulty: difficulty,
    rng: _random,
  );

  SuperOverFieldPlan rollField() =>
      fieldPresets[_random.nextInt(fieldPresets.length)];

  /// Legacy objective API retained for existing BLoC callers.
  SuperOverObjective rollObjective(SuperOverMode mode, int playerLevel) =>
      _rollObjective(mode, playerLevel, _random);

  List<SuperOverObjective> objectiveCandidates(
    SuperOverMode mode,
    int playerLevel,
  ) {
    final candidates = <SuperOverObjective>[
      SuperOverObjective(
        type: SuperOverObjectiveType.runs,
        target: mode == SuperOverMode.chase
            ? SuperOverResolution.targetBandForLevel(playerLevel).$1
            : 12 + min(6, playerLevel ~/ 4),
      ),
      const SuperOverObjective(
        type: SuperOverObjectiveType.attackGap,
        target: 2,
      ),
      const SuperOverObjective(
        type: SuperOverObjectiveType.protectWicket,
        target: 1,
      ),
      const SuperOverObjective(
        type: SuperOverObjectiveType.boundaries,
        target: 2,
      ),
      const SuperOverObjective(
        type: SuperOverObjectiveType.allSectors,
        target: 3,
      ),
      const SuperOverObjective(
        type: SuperOverObjectiveType.groundRuns,
        target: 6,
      ),
    ];
    if (mode == SuperOverMode.chase) {
      candidates.addAll(const [
        SuperOverObjective(
          type: SuperOverObjectiveType.chaseWithBallRemaining,
          target: 1,
        ),
        SuperOverObjective(
          type: SuperOverObjectiveType.winWithoutFinisher,
          target: 1,
        ),
      ]);
    }
    return List<SuperOverObjective>.unmodifiable(candidates);
  }

  CricketBattingStyle battingStyleFor(PlayerCard? card) {
    if (card == null) return CricketBattingStyle.anchor;
    return switch (card.trait.toLowerCase()) {
      'all-rounder' => CricketBattingStyle.powerHitter,
      'wicket-keeper' => CricketBattingStyle.improviser,
      _ => CricketBattingStyle.anchor,
    };
  }

  int effectiveTimingWindowMs({
    required int rating,
    required DeliveryPlan delivery,
    required CricketBattingStyle battingStyle,
    int confidence = 0,
    int? rhythm,
    required bool onFire,
    bool finisherMode = false,
    SuperOverDifficulty difficulty = SuperOverDifficulty.pro,
  }) {
    final deliveryType = _resolutionDeliveryType(delivery);
    final styleScale = switch (battingStyle) {
      CricketBattingStyle.anchor => 1.10,
      CricketBattingStyle.powerHitter => 0.94,
      CricketBattingStyle.improviser => 1.0,
    };
    final batterRhythm = (rhythm ?? confidence).clamp(0, 100);
    final rhythmScale = 1 + batterRhythm * 0.0012;
    return (SuperOverResolution.effectiveTimingWindowMs(
              rating,
              deliveryType,
              onFire: onFire || finisherMode,
              difficulty: difficulty,
            ) *
            styleScale *
            rhythmScale)
        .round();
  }

  /// Compatibility resolver. New matches should call [resolveCommittedBall].
  SuperOverShotResult resolve({
    required ShotIntent intent,
    required DeliveryPlan delivery,
    required int rating,
    required CricketBattingStyle battingStyle,
    List<int> fieldSectors = const [3, 3, 3],
    SuperOverFieldPlan? fieldPlan,
    int confidence = 0,
    int? rhythm,
    required bool onFire,
    bool finisherMode = false,
    SuperOverDifficulty difficulty = SuperOverDifficulty.pro,
  }) => _resolveInput(
    intent: intent,
    delivery: delivery,
    rating: rating,
    battingStyle: battingStyle,
    fieldSectors: fieldPlan?.sectorCounts ?? fieldSectors,
    rhythm: rhythm ?? confidence,
    finisherMode: finisherMode || onFire,
    difficulty: difficulty,
    random: _random,
  );

  SuperOverShotResult resolveCommittedBall({
    required SuperOverCommittedBall committedBall,
    ShotIntent? intent,
    required int rating,
    required CricketBattingStyle battingStyle,
    int rhythm = 0,
    bool finisherMode = false,
    SuperOverDifficulty difficulty = SuperOverDifficulty.pro,
  }) {
    final resolutionSeed = _mixSeed(committedBall.planningSeed, [
      rating,
      rhythm,
      battingStyle.index,
      finisherMode ? 1 : 0,
      intent?.timingErrorMs ?? 0x4c454156,
      intent?.sector.index ?? -1,
      intent?.style.index ?? -1,
    ]);
    final rng = Random(resolutionSeed);
    if (intent == null) {
      if (committedBall.fieldPlan.id.startsWith('tutorial-')) {
        return SuperOverShotResult(
          timingErrorMs: 999,
          normalizedError: 1.01,
          tier: TimingTier.miss,
          sector: _naturalSector(committedBall.delivery.line),
          power: 0,
          outcome: ShotOutcome.dot,
          drift: TimingDrift.late,
          contactType: SuperOverContactType.beaten,
        );
      }
      return _resolveNoInput(
        committedBall: committedBall,
        rating: rating,
        battingStyle: battingStyle,
        rhythm: rhythm,
        finisherMode: finisherMode,
        difficulty: difficulty,
        random: rng,
      );
    }
    final resolved = _resolveInput(
      intent: intent,
      delivery: committedBall.delivery,
      rating: rating,
      battingStyle: battingStyle,
      fieldSectors: committedBall.fieldPlan.sectorCounts,
      rhythm: rhythm,
      finisherMode: finisherMode,
      difficulty: difficulty,
      random: rng,
    );
    if (!committedBall.fieldPlan.id.startsWith('tutorial-')) return resolved;
    final guidedOutcomes = <ShotOutcome>[
      ShotOutcome.two,
      ShotOutcome.four,
      ShotOutcome.two,
      ShotOutcome.four,
      ShotOutcome.two,
      ShotOutcome.four,
    ];
    final index = (committedBall.ballNumber - 1).clamp(0, 5);
    final finalLessonMiss =
        committedBall.ballNumber >= 5 && resolved.tier == TimingTier.miss;
    final outcome = finalLessonMiss ? ShotOutcome.dot : guidedOutcomes[index];
    return SuperOverShotResult(
      timingErrorMs: resolved.timingErrorMs,
      normalizedError: resolved.normalizedError,
      tier: resolved.tier,
      sector: resolved.sector,
      power: resolved.power,
      outcome: outcome,
      drift: resolved.drift,
      contactType: resolved.contactType,
    );
  }

  SuperOverMatchPosition applyOutcome({
    required SuperOverMatchPosition position,
    required ShotOutcome outcome,
    required SuperOverMode mode,
    int? target,
  }) {
    if (position.isComplete) return position;
    final runs = SuperOverResolution.runsForOutcome(outcome);
    final wicket =
        outcome == ShotOutcome.caught || outcome == ShotOutcome.bowled;
    final score = position.score + runs;
    final wickets = position.wickets + (wicket ? 1 : 0);
    final ballsFaced = position.ballsFaced + 1;
    var strikerIndex = position.strikerIndex;
    var nonStrikerIndex = position.nonStrikerIndex;

    if (wicket && wickets == 1) {
      strikerIndex = 2;
    } else if (!wicket && runs.isOdd) {
      final previousStriker = strikerIndex;
      strikerIndex = nonStrikerIndex;
      nonStrikerIndex = previousStriker;
    }

    var isComplete = ballsFaced >= 6 || wickets >= 2;
    bool? wonChase;
    if (mode == SuperOverMode.chase) {
      final opponentScore = target ?? 0;
      if (score > opponentScore) {
        isComplete = true;
        wonChase = true;
      } else if (isComplete) {
        wonChase = false;
      }
    }

    return SuperOverMatchPosition(
      score: score,
      wickets: wickets,
      ballsFaced: ballsFaced,
      strikerIndex: strikerIndex,
      nonStrikerIndex: nonStrikerIndex,
      isComplete: isComplete,
      wonChase: wonChase,
    );
  }

  int rhythmAfter({
    required int currentRhythm,
    required SuperOverShotResult result,
  }) {
    final wicket =
        result.outcome == ShotOutcome.caught ||
        result.outcome == ShotOutcome.bowled;
    final runs = SuperOverResolution.runsForOutcome(result.outcome);
    final delta = wicket
        ? -32
        : runs == 0 ||
              result.tier == TimingTier.edgePoor ||
              result.tier == TimingTier.miss
        ? -15
        : switch (result.tier) {
            TimingTier.perfect => 20,
            TimingTier.great => 13,
            TimingTier.good => 8,
            TimingTier.edgePoor || TimingTier.miss => -15,
          };
    return (currentRhythm + delta).clamp(0, 100).toInt();
  }

  int objectiveProgress({
    required SuperOverObjective objective,
    required List<SuperOverBallRecord> ballRecords,
    int? score,
    int? wickets,
    bool matchComplete = false,
    bool? wonChase,
  }) {
    final resolvedScore =
        score ?? (ballRecords.isEmpty ? 0 : ballRecords.last.scoreAfter);
    final resolvedWickets =
        wickets ?? (ballRecords.isEmpty ? 0 : ballRecords.last.wicketsAfter);
    return switch (objective.type) {
      SuperOverObjectiveType.runs => resolvedScore,
      SuperOverObjectiveType.attackGap =>
        ballRecords.where((ball) => ball.scoredInOpenSector).length,
      SuperOverObjectiveType.protectWicket =>
        matchComplete && resolvedWickets == 0 ? 1 : 0,
      SuperOverObjectiveType.boundaries =>
        ballRecords.where((ball) => ball.isBoundary).length,
      SuperOverObjectiveType.allSectors =>
        ballRecords
            .where((ball) => ball.runs > 0)
            .map((ball) => ball.resolvedSector)
            .toSet()
            .length,
      SuperOverObjectiveType.chaseWithBallRemaining =>
        wonChase == true && ballRecords.length < 6 ? 1 : 0,
      SuperOverObjectiveType.groundRuns =>
        ballRecords
            .where((ball) => ball.intent?.style == ShotStyle.ground)
            .fold<int>(0, (sum, ball) => sum + ball.runs),
      SuperOverObjectiveType.winWithoutFinisher =>
        wonChase == true && !ballRecords.any((ball) => ball.usedFinisherMode)
            ? 1
            : 0,
    };
  }

  bool objectiveCompleted({
    required SuperOverObjective objective,
    required List<SuperOverBallRecord> ballRecords,
    int? score,
    int? wickets,
    bool matchComplete = false,
    bool? wonChase,
  }) =>
      objectiveProgress(
        objective: objective,
        ballRecords: ballRecords,
        score: score,
        wickets: wickets,
        matchComplete: matchComplete,
        wonChase: wonChase,
      ) >=
      objective.target;

  SuperOverMatchSummary buildSummary({
    required SuperOverMatchConfig config,
    required int? target,
    required SuperOverMatchPosition position,
    required SuperOverObjective objective,
    required List<SuperOverBallRecord> ballRecords,
    bool isNewRecord = false,
    int completedAtEpochMs = 0,
  }) {
    final objectiveComplete = objectiveCompleted(
      objective: objective,
      ballRecords: ballRecords,
      score: position.score,
      wickets: position.wickets,
      matchComplete: position.isComplete,
      wonChase: position.wonChase,
    );
    final finishingIndex = position.strikerIndex.clamp(0, 2).toInt();
    final finishingBatterCardId = ballRecords.isEmpty
        ? config.battingCardIds[finishingIndex]
        : ballRecords.last.strikerCardId;
    return SuperOverMatchSummary(
      matchId: config.matchId,
      seed: config.seed,
      mode: config.mode,
      difficulty: config.difficulty,
      target: target,
      score: position.score,
      wickets: position.wickets,
      ballsFaced: position.ballsFaced,
      wonChase: position.wonChase,
      objective: objective,
      objectiveComplete: objectiveComplete,
      battingCardIds: config.battingCardIds,
      ballRecords: ballRecords,
      finishingBatterCardId: finishingBatterCardId,
      grade: performanceGrade(
        mode: config.mode,
        target: target,
        position: position,
        ballRecords: ballRecords,
        objectiveComplete: objectiveComplete,
      ),
      isNewRecord: isNewRecord,
      completedAtEpochMs: completedAtEpochMs,
      tutorial: config.tutorial,
    );
  }

  SuperOverPerformanceGrade performanceGrade({
    required SuperOverMode mode,
    required int? target,
    required SuperOverMatchPosition position,
    required List<SuperOverBallRecord> ballRecords,
    required bool objectiveComplete,
  }) {
    var points = position.score;
    if (mode == SuperOverMode.chase && position.wonChase == true) points += 12;
    points += ballRecords.where((ball) => ball.isBoundary).length * 2;
    points += ballRecords
        .where((ball) => ball.timingTier == TimingTier.perfect)
        .length;
    points += ballRecords.where((ball) => ball.scoredInOpenSector).length;
    points += objectiveComplete ? 3 : 0;
    points += position.ballsRemaining;
    points -= position.wickets * 3;
    if (mode == SuperOverMode.chase && position.wonChase != true) points -= 8;
    if (points >= 42) return SuperOverPerformanceGrade.s;
    if (points >= 32) return SuperOverPerformanceGrade.a;
    if (points >= 22) return SuperOverPerformanceGrade.b;
    if (points >= 12) return SuperOverPerformanceGrade.c;
    return SuperOverPerformanceGrade.d;
  }

  SuperOverObjective _rollObjective(
    SuperOverMode mode,
    int playerLevel,
    Random rng,
  ) {
    final candidates = objectiveCandidates(mode, playerLevel);
    return candidates[rng.nextInt(candidates.length)];
  }

  SuperOverShotResult _resolveInput({
    required ShotIntent intent,
    required DeliveryPlan delivery,
    required int rating,
    required CricketBattingStyle battingStyle,
    required List<int> fieldSectors,
    required int rhythm,
    required bool finisherMode,
    required SuperOverDifficulty difficulty,
    required Random random,
  }) {
    final deliveryType = _resolutionDeliveryType(delivery);
    final baseWindow = SuperOverResolution.effectiveTimingWindowMs(
      rating,
      deliveryType,
      onFire: finisherMode,
      difficulty: difficulty,
    );
    final tunedWindow = effectiveTimingWindowMs(
      rating: rating,
      delivery: delivery,
      battingStyle: battingStyle,
      rhythm: rhythm,
      onFire: false,
      finisherMode: finisherMode,
      difficulty: difficulty,
    );
    final lengthMatchup = switch ((delivery.length, intent.style)) {
      (DeliveryLength.short, ShotStyle.loft) => 1.10,
      (DeliveryLength.short, ShotStyle.ground) => 0.88,
      (DeliveryLength.yorker, ShotStyle.ground) => 1.05,
      (DeliveryLength.yorker, ShotStyle.loft) => 0.76,
      (DeliveryLength.full, ShotStyle.ground) => 1.04,
      _ => 1.0,
    };
    final naturalSector = _naturalSector(delivery.line);
    final lineMatchup =
        battingStyle == CricketBattingStyle.improviser ||
            naturalSector == intent.sector
        ? 1.0
        : 0.90;
    final intentWindow = max(1.0, tunedWindow * lengthMatchup * lineMatchup);
    final tunedError = baseWindow == 0
        ? intent.timingErrorMs
        : (intent.timingErrorMs * baseWindow / intentWindow).round();
    final effectiveField = List<int>.of(fieldSectors);
    if (battingStyle == CricketBattingStyle.improviser &&
        effectiveField.length >= 3) {
      final index = SuperOverResolution.sectorIndex(intent.sector);
      effectiveField[index] = max(0, effectiveField[index] - 1);
      final missing = 9 - effectiveField.fold<int>(0, (a, b) => a + b);
      if (missing > 0) {
        final opposite = 2 - index;
        effectiveField[opposite] += missing;
      }
    }
    return SuperOverResolution.resolveShot(
      timingErrorMs: tunedError,
      rating: rating,
      delivery: deliveryType,
      fieldSectors: effectiveField,
      onFire: finisherMode,
      leftHanded: intent.leftHanded,
      intendedSector: intent.sector,
      shotStyle: intent.style,
      battingStyle: battingStyle,
      difficulty: difficulty,
      random: random,
    );
  }

  SuperOverShotResult _resolveNoInput({
    required SuperOverCommittedBall committedBall,
    required int rating,
    required CricketBattingStyle battingStyle,
    required int rhythm,
    required bool finisherMode,
    required SuperOverDifficulty difficulty,
    required Random random,
  }) {
    final delivery = committedBall.delivery;
    final window = effectiveTimingWindowMs(
      rating: rating,
      delivery: delivery,
      battingStyle: battingStyle,
      rhythm: rhythm,
      onFire: false,
      finisherMode: finisherMode,
      difficulty: difficulty,
    );
    final safeLeave =
        delivery.line == DeliveryLine.off &&
        delivery.type != DeliveryType.spin &&
        delivery.length != DeliveryLength.full &&
        delivery.length != DeliveryLength.yorker;
    final naturalSector = _naturalSector(delivery.line);
    if (safeLeave) {
      return SuperOverShotResult(
        timingErrorMs: window + 1,
        normalizedError: 1.01,
        tier: TimingTier.miss,
        sector: naturalSector,
        power: 0,
        outcome: ShotOutcome.dot,
        drift: TimingDrift.none,
        contactType: SuperOverContactType.leave,
      );
    }

    var bowledChance = switch (delivery.line) {
      DeliveryLine.off => 0.12,
      DeliveryLine.middle => 0.50,
      DeliveryLine.leg => 0.30,
    };
    if (delivery.length == DeliveryLength.full) bowledChance += 0.08;
    if (delivery.length == DeliveryLength.yorker ||
        delivery.type == DeliveryType.yorker) {
      bowledChance = 0.82;
    }
    if (delivery.type == DeliveryType.pace) bowledChance += 0.04;
    bowledChance = bowledChance.clamp(0.08, 0.90).toDouble();
    final bowled = random.nextDouble() < bowledChance;
    return SuperOverShotResult(
      timingErrorMs: window + 1,
      normalizedError: 1.01,
      tier: TimingTier.miss,
      sector: naturalSector,
      power: 0,
      outcome: bowled ? ShotOutcome.bowled : ShotOutcome.dot,
      drift: TimingDrift.late,
      contactType: bowled
          ? SuperOverContactType.missed
          : SuperOverContactType.beaten,
    );
  }

  String _bowlingPlanId({
    required SuperOverDifficulty difficulty,
    required _CompletedBallTendency tendency,
    required bool finalBallBoundaryNeeded,
  }) {
    if (difficulty == SuperOverDifficulty.rookie) return 'rookie-sequence';
    if (finalBallBoundaryNeeded) return 'death-yorker';
    if (tendency.repeatedLoft) return 'loft-trap';
    if (tendency.repeatedSector != null) return 'sector-pressure';
    if (tendency.repeatedEarly) return 'change-of-pace';
    if (tendency.repeatedLate) return 'pace-up';
    return difficulty == SuperOverDifficulty.allStar
        ? 'contextual-mix'
        : 'balanced';
  }

  SuperOverFieldPlan _fieldForPlan({
    required String planId,
    required _CompletedBallTendency tendency,
    required SuperOverDifficulty difficulty,
    required Random rng,
  }) {
    final trapSector = tendency.repeatedSector ?? tendency.lastSector;
    if ((planId == 'sector-pressure' || planId == 'loft-trap') &&
        trapSector != null) {
      final matching = fieldPresets
          .where((field) => field.countFor(trapSector) >= 4)
          .toList();
      if (matching.isNotEmpty) return matching[rng.nextInt(matching.length)];
    }
    if (difficulty == SuperOverDifficulty.rookie) {
      final readable = fieldPresets.take(4).toList();
      return readable[rng.nextInt(readable.length)];
    }
    return fieldPresets[rng.nextInt(fieldPresets.length)];
  }

  DeliveryPlan _deliveryForPlan({
    required String planId,
    required int playerLevel,
    required int ballNumber,
    required SuperOverDifficulty difficulty,
    required Random rng,
  }) {
    DeliveryType? forcedType;
    DeliveryLength? forcedLength;
    DeliveryLine? forcedLine;

    switch (planId) {
      case 'death-yorker':
        if (playerLevel >= 10) {
          forcedType = DeliveryType.yorker;
          forcedLength = DeliveryLength.yorker;
          forcedLine = DeliveryLine.middle;
        }
        break;
      case 'loft-trap':
        if (playerLevel >= 10 && difficulty == SuperOverDifficulty.allStar) {
          forcedType = DeliveryType.yorker;
          forcedLength = DeliveryLength.yorker;
        } else {
          forcedType = DeliveryType.slower;
          forcedLength = DeliveryLength.full;
        }
        break;
      case 'change-of-pace':
        forcedType = DeliveryType.slower;
        forcedLength = DeliveryLength.good;
        break;
      case 'pace-up':
        forcedType = DeliveryType.pace;
        forcedLength = DeliveryLength.full;
        break;
      case 'rookie-sequence':
        final rookieTypes = const [
          DeliveryType.pace,
          DeliveryType.pace,
          DeliveryType.slower,
          DeliveryType.pace,
          DeliveryType.spin,
          DeliveryType.pace,
        ];
        forcedType = rookieTypes[(ballNumber - 1) % rookieTypes.length];
        break;
      case 'sector-pressure':
      case 'contextual-mix':
      case 'balanced':
        break;
    }

    if (forcedLength == null && playerLevel >= 10) {
      final yorkerChance = switch (difficulty) {
        SuperOverDifficulty.rookie => 0.0,
        SuperOverDifficulty.pro => 0.14,
        SuperOverDifficulty.allStar => 0.32,
      };
      if (rng.nextDouble() < yorkerChance) {
        forcedType = DeliveryType.yorker;
        forcedLength = DeliveryLength.yorker;
      }
    }

    final type = forcedType ?? _randomDeliveryType(rng);
    final line = forcedLine ?? DeliveryLine.values[rng.nextInt(3)];
    final unlockedLengths = _unlockedLengths(playerLevel, difficulty);
    var length =
        forcedLength ?? unlockedLengths[rng.nextInt(unlockedLengths.length)];
    if (!unlockedLengths.contains(length)) {
      length = unlockedLengths.last;
    }
    final typePace = switch (type) {
      DeliveryType.pace || DeliveryType.yorker => 1.08,
      DeliveryType.slower => 0.84,
      DeliveryType.spin => 0.76,
    };
    final lengthPace = switch (length) {
      DeliveryLength.short => 0.92,
      DeliveryLength.good => 1.0,
      DeliveryLength.full => 1.04,
      DeliveryLength.yorker => 1.10,
    };
    final disguiseChance = switch (difficulty) {
      SuperOverDifficulty.rookie => 0.0,
      SuperOverDifficulty.pro => 0.32,
      SuperOverDifficulty.allStar => 0.68,
    };
    final canDisguise = type == DeliveryType.slower || planId == 'loft-trap';
    return DeliveryPlan(
      type: type,
      line: line,
      length: length,
      paceFactor: typePace * lengthPace,
      planId: planId,
      sequenceIndex: ballNumber - 1,
      disguised: canDisguise && rng.nextDouble() < disguiseChance,
    );
  }

  List<DeliveryLength> _unlockedLengths(
    int playerLevel,
    SuperOverDifficulty difficulty,
  ) {
    if (playerLevel < 5 || difficulty == SuperOverDifficulty.rookie) {
      return const [DeliveryLength.good, DeliveryLength.full];
    }
    if (playerLevel < 10) {
      return const [
        DeliveryLength.short,
        DeliveryLength.good,
        DeliveryLength.full,
      ];
    }
    return DeliveryLength.values;
  }

  DeliveryType _randomDeliveryType(Random rng) {
    final roll = rng.nextInt(100);
    if (roll < 52) return DeliveryType.pace;
    if (roll < 72) return DeliveryType.slower;
    return DeliveryType.spin;
  }

  _CompletedBallTendency _tendencyFor(
    List<SuperOverBallRecord> completedBalls,
  ) {
    final recent = completedBalls.length <= 2
        ? completedBalls
        : completedBalls.sublist(completedBalls.length - 2);
    if (recent.length < 2) {
      return _CompletedBallTendency(
        lastSector: recent.isEmpty ? null : recent.last.intent?.sector,
      );
    }
    final intents = recent.map((ball) => ball.intent).toList();
    final firstSector = intents.first?.sector;
    final repeatedSector =
        firstSector != null &&
            intents.every((intent) => intent?.sector == firstSector)
        ? firstSector
        : null;
    return _CompletedBallTendency(
      repeatedLoft: intents.every((intent) => intent?.style == ShotStyle.loft),
      repeatedSector: repeatedSector,
      repeatedEarly: recent.every((ball) => ball.drift == TimingDrift.early),
      repeatedLate: recent.every((ball) => ball.drift == TimingDrift.late),
      lastSector: intents.last?.sector,
    );
  }

  int _planningSeed(
    int configSeed,
    int ballNumber,
    List<SuperOverBallRecord> completedBalls,
  ) {
    final values = <int>[ballNumber, completedBalls.length];
    for (final ball in completedBalls) {
      values.addAll([
        ball.ballNumber,
        ball.outcome.index,
        ball.runs,
        ball.resolvedSector.index,
        ball.intent?.sector.index ?? -1,
        ball.intent?.style.index ?? -1,
        ball.drift.index,
      ]);
    }
    return _mixSeed(configSeed, values);
  }

  int _mixSeed(int base, List<int> values) {
    var hash = (base ^ 0x45d9f3b) & 0x3fffffff;
    for (final value in values) {
      hash = ((hash * 1103515245) ^ (value + 0x9e3779b9)) & 0x3fffffff;
    }
    return hash;
  }

  DeliveryType _resolutionDeliveryType(DeliveryPlan delivery) =>
      delivery.length == DeliveryLength.yorker
      ? DeliveryType.yorker
      : delivery.type;

  ShotSector _naturalSector(DeliveryLine line) => switch (line) {
    DeliveryLine.off => ShotSector.off,
    DeliveryLine.middle => ShotSector.v,
    DeliveryLine.leg => ShotSector.leg,
  };
}

class _CompletedBallTendency {
  const _CompletedBallTendency({
    this.repeatedLoft = false,
    this.repeatedSector,
    this.repeatedEarly = false,
    this.repeatedLate = false,
    this.lastSector,
  });

  final bool repeatedLoft;
  final ShotSector? repeatedSector;
  final bool repeatedEarly;
  final bool repeatedLate;
  final ShotSector? lastSector;
}
