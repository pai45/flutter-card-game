import 'dart:math';

import 'package:card_game/games/super_over/super_over_engine.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/super_over.dart';
import 'package:card_game/models/super_over_stats.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SuperOverEngine planning', () {
    test('same seed and completed history commit the same ball', () {
      final engineA = SuperOverEngine(seed: 41);
      final engineB = SuperOverEngine(seed: 999);
      final history = [
        _record(
          ballNumber: 1,
          intent: const ShotIntent(
            sector: ShotSector.off,
            style: ShotStyle.ground,
            timingErrorMs: 20,
          ),
          outcome: ShotOutcome.two,
          scoreAfter: 2,
        ),
      ];

      final first = engineA.planNextBall(
        config: _config(seed: 2026),
        completedBalls: history,
        target: 15,
      );
      final second = engineB.planNextBall(
        config: _config(seed: 2026),
        completedBalls: history,
        target: 15,
      );

      expect(first.toJson(), second.toJson());
      expect(first.ballNumber, 2);
      expect(first.fieldPlan.sectorCounts.reduce((a, b) => a + b), 9);
    });

    test('AI adapts only after completed repeated loft/off choices', () {
      final engine = SuperOverEngine(seed: 1);
      final history = [
        _record(
          ballNumber: 1,
          intent: const ShotIntent(
            sector: ShotSector.off,
            style: ShotStyle.loft,
            timingErrorMs: 0,
          ),
          outcome: ShotOutcome.four,
          scoreAfter: 4,
        ),
        _record(
          ballNumber: 2,
          intent: const ShotIntent(
            sector: ShotSector.off,
            style: ShotStyle.loft,
            timingErrorMs: 0,
          ),
          outcome: ShotOutcome.six,
          scoreAfter: 10,
        ),
      ];

      final plan = engine.planNextBall(
        config: _config(
          seed: 8,
          difficulty: SuperOverDifficulty.allStar,
          level: 15,
        ),
        completedBalls: history,
      );

      expect(plan.delivery.planId, 'loft-trap');
      expect(plan.fieldPlan.countFor(ShotSector.off), greaterThanOrEqualTo(4));
    });

    test('Rookie remains readable instead of counter-planning', () {
      final engine = SuperOverEngine(seed: 1);
      final history = [
        _record(ballNumber: 1, outcome: ShotOutcome.six, scoreAfter: 6),
        _record(ballNumber: 2, outcome: ShotOutcome.six, scoreAfter: 12),
      ];
      final plan = engine.planNextBall(
        config: _config(
          seed: 8,
          difficulty: SuperOverDifficulty.rookie,
          level: 20,
        ),
        completedBalls: history,
      );

      expect(plan.delivery.planId, 'rookie-sequence');
      expect(plan.delivery.length, isNot(DeliveryLength.yorker));
      expect(plan.delivery.disguised, isFalse);
    });

    test('low levels receive readable legacy delivery plans', () {
      final engine = SuperOverEngine(random: Random(7));

      for (var i = 0; i < 30; i++) {
        final plan = engine.rollDelivery(1);
        expect(plan.type, isNot(DeliveryType.yorker));
        expect(plan.length, anyOf(DeliveryLength.good, DeliveryLength.full));
        expect(plan.paceFactor, inInclusiveRange(.6, 1.3));
      }
    });

    test('objective pool filters chase-only goals out of Score Attack', () {
      final engine = SuperOverEngine(seed: 2);

      final scoreAttackTypes = engine
          .objectiveCandidates(SuperOverMode.scoreAttack, 5)
          .map((objective) => objective.type)
          .toSet();
      final chaseTypes = engine
          .objectiveCandidates(SuperOverMode.chase, 5)
          .map((objective) => objective.type)
          .toSet();

      expect(
        scoreAttackTypes,
        isNot(contains(SuperOverObjectiveType.chaseWithBallRemaining)),
      );
      expect(
        scoreAttackTypes,
        isNot(contains(SuperOverObjectiveType.winWithoutFinisher)),
      );
      expect(chaseTypes, contains(SuperOverObjectiveType.boundaries));
      expect(chaseTypes, contains(SuperOverObjectiveType.allSectors));
      expect(chaseTypes, contains(SuperOverObjectiveType.groundRuns));
      expect(chaseTypes, contains(SuperOverObjectiveType.winWithoutFinisher));
    });
  });

  group('SuperOverEngine resolution', () {
    test('card traits map to lightweight batting archetypes', () {
      final engine = SuperOverEngine(random: Random(1));
      final anchor = cricketBattingCards.firstWhere(
        (card) => card.trait == 'Batsman',
      );
      final power = cricketBattingCards.firstWhere(
        (card) => card.trait == 'All-rounder',
      );
      final improviser = cricketBattingCards.firstWhere(
        (card) => card.trait == 'Wicket-keeper',
      );

      expect(engine.battingStyleFor(anchor), CricketBattingStyle.anchor);
      expect(engine.battingStyleFor(power), CricketBattingStyle.powerHitter);
      expect(
        engine.battingStyleFor(improviser),
        CricketBattingStyle.improviser,
      );
    });

    test('explicit aim is honoured for perfect Ground contact', () {
      final engine = SuperOverEngine(random: Random(3));
      final shot = engine.resolve(
        intent: const ShotIntent(
          sector: ShotSector.leg,
          style: ShotStyle.ground,
          timingErrorMs: 0,
        ),
        delivery: const DeliveryPlan(),
        rating: 88,
        battingStyle: CricketBattingStyle.anchor,
        fieldSectors: const [3, 3, 3],
        confidence: 0,
        onFire: false,
      );

      expect(shot.sector, ShotSector.leg);
      expect(shot.drift, TimingDrift.none);
      expect(shot.outcome, isNot(ShotOutcome.six));
    });

    test('difficulty and Anchor rhythm widen only the explicit window', () {
      final engine = SuperOverEngine(random: Random(4));
      const plan = DeliveryPlan();
      final allStar = engine.effectiveTimingWindowMs(
        rating: 80,
        delivery: plan,
        battingStyle: CricketBattingStyle.powerHitter,
        confidence: 0,
        onFire: false,
        difficulty: SuperOverDifficulty.allStar,
      );
      final pro = engine.effectiveTimingWindowMs(
        rating: 80,
        delivery: plan,
        battingStyle: CricketBattingStyle.anchor,
        rhythm: 50,
        onFire: false,
      );
      final rookie = engine.effectiveTimingWindowMs(
        rating: 80,
        delivery: plan,
        battingStyle: CricketBattingStyle.anchor,
        rhythm: 80,
        onFire: false,
        difficulty: SuperOverDifficulty.rookie,
      );

      expect(allStar, lessThan(pro));
      expect(pro, lessThan(rookie));
      expect(SuperOverDifficulty.rookie.cueLeadMs, greaterThan(150));
      expect(SuperOverDifficulty.allStar.disguiseStrength, 1);
    });

    test('committed resolution is repeatable', () {
      final engine = SuperOverEngine(seed: 1);
      final committed = SuperOverCommittedBall(
        ballNumber: 1,
        planningSeed: 778,
        fieldPlan: SuperOverFieldPlan.fromCounts(const [2, 4, 3]),
        delivery: const DeliveryPlan(
          type: DeliveryType.slower,
          line: DeliveryLine.off,
          length: DeliveryLength.full,
        ),
      );
      const intent = ShotIntent(
        sector: ShotSector.off,
        style: ShotStyle.loft,
        timingErrorMs: -60,
      );

      final first = engine.resolveCommittedBall(
        committedBall: committed,
        intent: intent,
        rating: 86,
        battingStyle: CricketBattingStyle.powerHitter,
        rhythm: 30,
      );
      final second = engine.resolveCommittedBall(
        committedBall: committed,
        intent: intent,
        rating: 86,
        battingStyle: CricketBattingStyle.powerHitter,
        rhythm: 30,
      );

      expect(second.outcome, first.outcome);
      expect(second.power, first.power);
      expect(second.sector, first.sector);
      expect(second.normalizedError, first.normalizedError);
    });

    test('no input safely outside off becomes a leave', () {
      final engine = SuperOverEngine(seed: 1);
      final result = engine.resolveCommittedBall(
        committedBall: SuperOverCommittedBall(
          ballNumber: 1,
          planningSeed: 7,
          fieldPlan: SuperOverFieldPlan.fromCounts(const [3, 3, 3]),
          delivery: const DeliveryPlan(
            type: DeliveryType.pace,
            line: DeliveryLine.off,
            length: DeliveryLength.good,
          ),
        ),
        rating: 80,
        battingStyle: CricketBattingStyle.anchor,
      );

      expect(result.contactType, SuperOverContactType.leave);
      expect(result.outcome, ShotOutcome.dot);
      expect(result.power, 0);
    });

    test('dangerous no-input balls can beat or bowl the batter', () {
      final engine = SuperOverEngine(seed: 1);
      final results = <SuperOverShotResult>[
        for (var seed = 0; seed < 24; seed++)
          engine.resolveCommittedBall(
            committedBall: SuperOverCommittedBall(
              ballNumber: 1,
              planningSeed: seed,
              fieldPlan: SuperOverFieldPlan.fromCounts(const [3, 3, 3]),
              delivery: const DeliveryPlan(
                type: DeliveryType.yorker,
                line: DeliveryLine.middle,
                length: DeliveryLength.yorker,
              ),
            ),
            rating: 80,
            battingStyle: CricketBattingStyle.anchor,
          ),
      ];

      expect(
        results.map((result) => result.outcome),
        everyElement(anyOf(ShotOutcome.dot, ShotOutcome.bowled)),
      );
      expect(
        results.map((result) => result.outcome),
        contains(ShotOutcome.bowled),
      );
      expect(
        results.map((result) => result.contactType),
        everyElement(
          anyOf(SuperOverContactType.beaten, SuperOverContactType.missed),
        ),
      );
    });
  });

  group('Super Over innings rules', () {
    test('odd runs rotate strike while even runs retain it', () {
      final engine = SuperOverEngine(seed: 1);
      final afterOne = engine.applyOutcome(
        position: const SuperOverMatchPosition(),
        outcome: ShotOutcome.one,
        mode: SuperOverMode.scoreAttack,
      );
      final afterTwo = engine.applyOutcome(
        position: afterOne,
        outcome: ShotOutcome.two,
        mode: SuperOverMode.scoreAttack,
      );

      expect((afterOne.strikerIndex, afterOne.nonStrikerIndex), (1, 0));
      expect((afterTwo.strikerIndex, afterTwo.nonStrikerIndex), (1, 0));
    });

    test(
      'Batter 3 replaces first wicket and second wicket ends immediately',
      () {
        final engine = SuperOverEngine(seed: 1);
        final firstWicket = engine.applyOutcome(
          position: const SuperOverMatchPosition(),
          outcome: ShotOutcome.caught,
          mode: SuperOverMode.scoreAttack,
        );
        final secondWicket = engine.applyOutcome(
          position: firstWicket,
          outcome: ShotOutcome.bowled,
          mode: SuperOverMode.scoreAttack,
        );

        expect(firstWicket.strikerIndex, 2);
        expect(firstWicket.wickets, 1);
        expect(firstWicket.isComplete, isFalse);
        expect(secondWicket.wickets, 2);
        expect(secondWicket.isComplete, isTrue);
        expect(secondWicket.ballsFaced, 2);
      },
    );

    test('Chase needs target plus one and ends immediately when exceeded', () {
      final engine = SuperOverEngine(seed: 1);
      final tied = engine.applyOutcome(
        position: const SuperOverMatchPosition(score: 4),
        outcome: ShotOutcome.four,
        mode: SuperOverMode.chase,
        target: 8,
      );
      final won = engine.applyOutcome(
        position: tied,
        outcome: ShotOutcome.one,
        mode: SuperOverMode.chase,
        target: 8,
      );

      expect(tied.score, 8);
      expect(tied.isComplete, isFalse);
      expect(tied.wonChase, isNull);
      expect(won.score, 9);
      expect(won.isComplete, isTrue);
      expect(won.wonChase, isTrue);
    });

    test('sixth legal ball ends Score Attack', () {
      final engine = SuperOverEngine(seed: 1);
      final finalBall = engine.applyOutcome(
        position: const SuperOverMatchPosition(ballsFaced: 5, score: 12),
        outcome: ShotOutcome.six,
        mode: SuperOverMode.scoreAttack,
      );

      expect(finalBall.score, 18);
      expect(finalBall.ballsFaced, 6);
      expect(finalBall.isComplete, isTrue);
      expect(finalBall.wonChase, isNull);
    });
  });

  group('summaries, rewards, and snapshots', () {
    test('shared reward calculator includes every documented component', () {
      final balls = [
        _record(ballNumber: 1, outcome: ShotOutcome.six, scoreAfter: 6),
        _record(ballNumber: 2, outcome: ShotOutcome.six, scoreAfter: 12),
        _record(ballNumber: 3, outcome: ShotOutcome.two, scoreAfter: 14),
      ];
      final summary = SuperOverMatchSummary(
        matchId: 'reward-match',
        seed: 5,
        mode: SuperOverMode.chase,
        difficulty: SuperOverDifficulty.pro,
        target: 13,
        score: 14,
        wickets: 0,
        ballsFaced: 3,
        wonChase: true,
        objective: const SuperOverObjective(
          type: SuperOverObjectiveType.boundaries,
          target: 2,
        ),
        objectiveComplete: true,
        battingCardIds: const ['one', 'two', 'three'],
        ballRecords: balls,
      );

      expect(summary.rewardBreakdown.completionXp, 10);
      expect(summary.rewardBreakdown.runsXp, 14);
      expect(summary.rewardBreakdown.sixesXp, 8);
      expect(summary.rewardBreakdown.chaseWinXp, 15);
      expect(summary.rewardBreakdown.objectiveXp, 8);
      expect(summary.rewardBreakdown.totalXp, 55);
    });

    test('tutorial summary awards no account XP', () {
      final summary = SuperOverMatchSummary(
        matchId: 'tutorial',
        seed: 5,
        mode: SuperOverMode.chase,
        difficulty: SuperOverDifficulty.rookie,
        target: 5,
        score: 6,
        wickets: 0,
        ballsFaced: 2,
        wonChase: true,
        objective: const SuperOverObjective(
          type: SuperOverObjectiveType.runs,
          target: 6,
        ),
        objectiveComplete: true,
        battingCardIds: const ['one', 'two', 'three'],
        ballRecords: const [],
        tutorial: true,
      );

      expect(summary.rewardBreakdown.totalXp, 0);
    });

    test(
      'finishing batter is the hitter even when winning odd runs rotate',
      () {
        final engine = SuperOverEngine(seed: 1);
        final position = engine.applyOutcome(
          position: const SuperOverMatchPosition(),
          outcome: ShotOutcome.one,
          mode: SuperOverMode.chase,
          target: 0,
        );
        final balls = [
          _record(ballNumber: 1, outcome: ShotOutcome.one, scoreAfter: 1),
        ];
        final summary = engine.buildSummary(
          config: _config(seed: 90),
          target: 0,
          position: position,
          objective: const SuperOverObjective(
            type: SuperOverObjectiveType.runs,
            target: 1,
          ),
          ballRecords: balls,
        );

        expect(position.strikerIndex, 1);
        expect(summary.finishingBatterCardId, 'one');
      },
    );

    test('typed safe-boundary snapshot survives JSON round trip', () {
      final committed = SuperOverCommittedBall(
        ballNumber: 2,
        planningSeed: 99,
        fieldPlan: SuperOverFieldPlan.fromCounts(const [
          2,
          4,
          3,
        ], id: 'straight-packed'),
        delivery: const DeliveryPlan(
          type: DeliveryType.spin,
          line: DeliveryLine.leg,
          length: DeliveryLength.good,
          planId: 'contextual-mix',
          sequenceIndex: 1,
          disguised: true,
        ),
      );
      final snapshot = SuperOverMatchSnapshot(
        config: _config(seed: 13),
        target: 12,
        objective: const SuperOverObjective(
          type: SuperOverObjectiveType.allSectors,
          target: 3,
        ),
        score: 2,
        strikerIndex: 0,
        nonStrikerIndex: 1,
        rhythmByCardId: const {'one': 20},
        combo: 1,
        maxCombo: 1,
        ballRecords: [
          _record(ballNumber: 1, outcome: ShotOutcome.two, scoreAfter: 2),
        ],
        committedBall: committed,
        selectedSector: ShotSector.leg,
        selectedShotStyle: ShotStyle.loft,
        playPhase: SuperOverPlayPhase.release,
        savedAtEpochMs: 1234,
      );

      final restored = SuperOverMatchSnapshot.fromJson(snapshot.toJson());

      expect(restored.toJson(), snapshot.toJson());
      expect(restored.ballsFaced, 1);
      expect(restored.committedBall.ballNumber, 2);
      expect(restored.committedBall.fieldPlan.openSector, ShotSector.off);
    });

    test('objective progress covers all-sector and Ground goals', () {
      final engine = SuperOverEngine(seed: 1);
      final balls = [
        _record(
          ballNumber: 1,
          sector: ShotSector.off,
          style: ShotStyle.ground,
          outcome: ShotOutcome.two,
          scoreAfter: 2,
        ),
        _record(
          ballNumber: 2,
          sector: ShotSector.v,
          style: ShotStyle.ground,
          outcome: ShotOutcome.two,
          scoreAfter: 4,
        ),
        _record(
          ballNumber: 3,
          sector: ShotSector.leg,
          style: ShotStyle.ground,
          outcome: ShotOutcome.two,
          scoreAfter: 6,
        ),
      ];

      expect(
        engine.objectiveProgress(
          objective: const SuperOverObjective(
            type: SuperOverObjectiveType.allSectors,
            target: 3,
          ),
          ballRecords: balls,
        ),
        3,
      );
      expect(
        engine.objectiveCompleted(
          objective: const SuperOverObjective(
            type: SuperOverObjectiveType.groundRuns,
            target: 6,
          ),
          ballRecords: balls,
        ),
        isTrue,
      );
    });

    test('legacy stats migrate with safe neutral defaults', () {
      final stats = SuperOverStats.fromJson({
        'highScore': 21,
        'chaseWins': 4,
        'lastJersey': 'chennai',
      });

      expect(stats.highScore, 21);
      expect(stats.chaseWins, 4);
      expect(stats.scoreAttackHighScore, 0);
      expect(stats.perfectContacts, 0);
      expect(stats.batterMastery, isEmpty);
      expect(stats.lastJersey, CricketJersey.goldStrike);
    });

    test('tutorial script creates the Need 6 from 2 finish', () {
      final engine = SuperOverEngine(seed: 81);
      final config = SuperOverMatchConfig(
        matchId: 'tutorial-match',
        seed: 81,
        mode: SuperOverMode.chase,
        difficulty: SuperOverDifficulty.rookie,
        level: 1,
        battingCardIds: ['one', 'two', 'three'],
        jerseyId: 'nightCyan',
        tutorial: true,
      );
      var score = 0;
      final records = <SuperOverBallRecord>[];
      for (var ball = 1; ball <= 4; ball++) {
        final committed = engine.commitNextBall(
          config: config,
          completedBalls: records,
          target: 17,
        );
        final result = engine.resolveCommittedBall(
          committedBall: committed,
          intent: const ShotIntent(
            sector: ShotSector.v,
            style: ShotStyle.ground,
            timingErrorMs: 0,
          ),
          rating: 80,
          battingStyle: CricketBattingStyle.anchor,
          difficulty: SuperOverDifficulty.rookie,
        );
        score += SuperOverResolution.runsForOutcome(result.outcome);
        records.add(
          _record(ballNumber: ball, outcome: result.outcome, scoreAfter: score),
        );
      }

      expect(score, 12);
      expect(18 - score, 6);
      expect(6 - records.length, 2);
      expect(engine.targetForConfig(config), 17);
    });

    test('expanded stats survive a storage round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = SecureGameStorage();
      const saved = SuperOverStats(
        scoreAttackHighScore: 27,
        perfectContacts: 8,
        bestCombo: 5,
        objectivesCompleted: 3,
        batterMastery: {'card-one': 145},
      );

      await storage.saveSuperOverStats(saved);
      final loaded = await storage.loadSuperOverStats();

      expect(loaded.scoreAttackHighScore, 27);
      expect(loaded.perfectContacts, 8);
      expect(loaded.bestCombo, 5);
      expect(loaded.objectivesCompleted, 3);
      expect(loaded.batterMastery['card-one'], 145);
    });
  });
}

SuperOverMatchConfig _config({
  int seed = 1,
  SuperOverDifficulty difficulty = SuperOverDifficulty.pro,
  int level = 12,
}) => SuperOverMatchConfig(
  matchId: 'match-$seed',
  seed: seed,
  mode: SuperOverMode.chase,
  difficulty: difficulty,
  level: level,
  battingCardIds: const ['one', 'two', 'three'],
  jerseyId: CricketJersey.nightCyan.name,
);

SuperOverBallRecord _record({
  required int ballNumber,
  ShotIntent? intent,
  ShotSector sector = ShotSector.v,
  ShotStyle style = ShotStyle.loft,
  ShotOutcome outcome = ShotOutcome.four,
  TimingTier tier = TimingTier.great,
  TimingDrift drift = TimingDrift.none,
  required int scoreAfter,
  int wicketsAfter = 0,
}) {
  final resolvedIntent =
      intent ?? ShotIntent(sector: sector, style: style, timingErrorMs: 0);
  return SuperOverBallRecord(
    ballNumber: ballNumber,
    strikerCardId: 'one',
    nonStrikerCardId: 'two',
    committedBall: SuperOverCommittedBall(
      ballNumber: ballNumber,
      planningSeed: ballNumber,
      fieldPlan: SuperOverFieldPlan.fromCounts(const [2, 4, 3]),
      delivery: const DeliveryPlan(),
    ),
    intent: resolvedIntent,
    contactType: SuperOverContactType.played,
    timingErrorMs: resolvedIntent.timingErrorMs,
    normalizedTimingError: 0,
    timingTier: tier,
    drift: drift,
    resolvedSector: resolvedIntent.sector,
    outcome: outcome,
    runs: SuperOverResolution.runsForOutcome(outcome),
    usedFinisherMode: false,
    rhythmBefore: 0,
    rhythmAfter: 13,
    scoreAfter: scoreAfter,
    wicketsAfter: wicketsAfter,
  );
}
