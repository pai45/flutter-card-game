import 'dart:math';

import 'package:card_game/models/super_over.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SuperOverResolution Tests', () {
    test('target bands match one-tap chase tuning', () {
      expect(SuperOverResolution.targetBandForLevel(1), (8, 12));
      expect(SuperOverResolution.targetBandForLevel(5), (11, 16));
      expect(SuperOverResolution.targetBandForLevel(10), (14, 19));
      expect(SuperOverResolution.targetBandForLevel(15), (16, 21));
      expect(SuperOverResolution.targetBandForLevel(25), (18, 23));
    });

    test('windowScale and deliveryMultiplier scale timing windows', () {
      expect(SuperOverResolution.windowScale(75), 1.0);
      expect(SuperOverResolution.windowScale(80), 1.06);
      expect(SuperOverResolution.windowScale(100), 1.30);
      expect(SuperOverResolution.windowScale(50), 0.85);

      expect(SuperOverResolution.deliveryMultiplier(DeliveryType.yorker), 0.78);
      expect(SuperOverResolution.deliveryMultiplier(DeliveryType.pace), 0.92);
      expect(SuperOverResolution.deliveryMultiplier(DeliveryType.slower), 1.04);
      expect(SuperOverResolution.deliveryMultiplier(DeliveryType.spin), 1.10);
    });

    test('timing tiers use normalized tap error', () {
      expect(
        SuperOverResolution.timingTierForNormalizedError(0.0),
        TimingTier.perfect,
      );
      expect(
        SuperOverResolution.timingTierForNormalizedError(0.25),
        TimingTier.great,
      );
      expect(
        SuperOverResolution.timingTierForNormalizedError(-0.50),
        TimingTier.good,
      );
      expect(
        SuperOverResolution.timingTierForNormalizedError(0.75),
        TimingTier.edgePoor,
      );
      expect(
        SuperOverResolution.timingTierForNormalizedError(1.1),
        TimingTier.miss,
      );
    });

    test('tap timing maps to shot sector', () {
      expect(SuperOverResolution.sectorForTiming(-0.4), ShotSector.leg);
      expect(SuperOverResolution.sectorForTiming(0.0), ShotSector.v);
      expect(SuperOverResolution.sectorForTiming(0.4), ShotSector.off);
    });

    test('early and late contact drift an explicit intent by one sector', () {
      final early = SuperOverResolution.resolveShot(
        timingErrorMs: -100,
        rating: 75,
        delivery: DeliveryType.pace,
        fieldSectors: const [3, 3, 3],
        intendedSector: ShotSector.v,
        random: Random(4),
      );
      final late = SuperOverResolution.resolveShot(
        timingErrorMs: 100,
        rating: 75,
        delivery: DeliveryType.pace,
        fieldSectors: const [3, 3, 3],
        intendedSector: ShotSector.v,
        random: Random(4),
      );

      expect(early.drift, TimingDrift.early);
      expect(early.sector, ShotSector.leg);
      expect(late.drift, TimingDrift.late);
      expect(late.sector, ShotSector.off);
      expect(late.power, lessThan(early.power));
    });

    test('left-handed contact mirrors early and late drift', () {
      expect(
        SuperOverResolution.sectorForIntentAndTiming(
          intendedSector: ShotSector.v,
          normalizedError: -0.4,
          leftHanded: true,
        ),
        ShotSector.off,
      );
      expect(
        SuperOverResolution.sectorForIntentAndTiming(
          intendedSector: ShotSector.v,
          normalizedError: 0.4,
          leftHanded: true,
        ),
        ShotSector.leg,
      );
    });

    test('resolveShot reports tier, sector, power and outcome', () {
      final shot = SuperOverResolution.resolveShot(
        timingErrorMs: 0,
        rating: 88,
        delivery: DeliveryType.pace,
        fieldSectors: const [2, 2, 1],
        random: Random(1),
      );

      expect(shot.tier, TimingTier.perfect);
      expect(shot.sector, ShotSector.v);
      expect(shot.power, greaterThanOrEqualTo(100));
      expect([ShotOutcome.six, ShotOutcome.four], contains(shot.outcome));
    });

    test('fielder spots spread nine players across the ground', () {
      final spots = SuperOverResolution.fielderSpotsForSectors(const [3, 3, 3]);

      expect(spots, hasLength(9));
      expect(spots.where((s) => s.sector == ShotSector.off), hasLength(3));
      expect(spots.where((s) => s.sector == ShotSector.v), hasLength(3));
      expect(spots.where((s) => s.sector == ShotSector.leg), hasLength(3));
      expect(spots.map((s) => s.radial).reduce(max), greaterThan(0.6));
      expect(spots.map((s) => s.radial).reduce(min), lessThan(0.4));
    });

    test('field plan exposes only a unique least-covered sector as Open', () {
      final unique = SuperOverFieldPlan.fromCounts(const [2, 4, 3]);
      final tied = SuperOverFieldPlan.fromCounts(const [3, 3, 3]);

      expect(unique.openSector, ShotSector.off);
      expect(unique.packedSectors, {ShotSector.v});
      expect(tied.openSector, isNull);
      expect(tied.packedSectors, isEmpty);
      expect(SuperOverResolution.openSectorForSectors(const [1, 1, 7]), isNull);
    });

    test('Perfect Ground never produces a six', () {
      final outcomes = [
        for (var seed = 0; seed < 100; seed++)
          SuperOverResolution.resolveShot(
            timingErrorMs: 0,
            rating: 99,
            delivery: DeliveryType.pace,
            fieldSectors: const [3, 3, 3],
            intendedSector: ShotSector.v,
            shotStyle: ShotStyle.ground,
            random: Random(seed),
          ).outcome,
      ];

      expect(outcomes, isNot(contains(ShotOutcome.six)));
      expect(outcomes, everyElement(anyOf(ShotOutcome.four, ShotOutcome.two)));
    });

    test('Perfect contact bypasses geometric catching', () {
      final outcomes = [
        for (var seed = 0; seed < 100; seed++)
          SuperOverResolution.resolveShot(
            timingErrorMs: 0,
            rating: 75,
            delivery: DeliveryType.pace,
            fieldSectors: const [0, 9, 0],
            intendedSector: ShotSector.v,
            random: Random(seed),
          ).outcome,
      ];

      expect(outcomes, isNot(contains(ShotOutcome.caught)));
    });

    test('fielder on the ball path can convert catchable shot into caught', () {
      final shot = SuperOverResolution.resolveShot(
        timingErrorMs: 55,
        rating: 75,
        delivery: DeliveryType.pace,
        fieldSectors: const [0, 9, 0],
        random: _SequenceRandom(ints: [3], doubles: [0.70, 0.0]),
      );

      expect(shot.tier, TimingTier.great);
      expect(shot.sector, ShotSector.v);
      expect(shot.outcome, ShotOutcome.caught);
    });

    test('fielder on the ball path can still miss catchable shot', () {
      final shot = SuperOverResolution.resolveShot(
        timingErrorMs: 55,
        rating: 75,
        delivery: DeliveryType.pace,
        fieldSectors: const [0, 9, 0],
        random: _SequenceRandom(ints: [3], doubles: [0.70, 0.99]),
      );

      expect(shot.tier, TimingTier.great);
      expect(shot.sector, ShotSector.v);
      expect(shot.outcome, isNot(ShotOutcome.caught));
    });

    test('ON FIRE improves effective window and power', () {
      final normalWindow = SuperOverResolution.effectiveTimingWindowMs(
        80,
        DeliveryType.pace,
      );
      final fireWindow = SuperOverResolution.effectiveTimingWindowMs(
        80,
        DeliveryType.pace,
        onFire: true,
      );

      expect(fireWindow, greaterThan(normalWindow));

      final normalPower = SuperOverResolution.shotPower(
        tier: TimingTier.great,
        rating: 85,
        delivery: DeliveryType.pace,
        random: Random(2),
      );
      final firePower = SuperOverResolution.shotPower(
        tier: TimingTier.great,
        rating: 85,
        delivery: DeliveryType.pace,
        onFire: true,
        random: Random(2),
      );

      expect(firePower, normalPower + 12);
    });

    test('difficulty assistance changes windows without pressure input', () {
      final rookie = SuperOverResolution.effectiveTimingWindowMs(
        80,
        DeliveryType.pace,
        difficulty: SuperOverDifficulty.rookie,
      );
      final pro = SuperOverResolution.effectiveTimingWindowMs(
        80,
        DeliveryType.pace,
      );
      final allStar = SuperOverResolution.effectiveTimingWindowMs(
        80,
        DeliveryType.pace,
        difficulty: SuperOverDifficulty.allStar,
      );

      expect(rookie, greaterThan(pro));
      expect(allStar, lessThan(pro));
    });
  });
}

class _SequenceRandom implements Random {
  _SequenceRandom({required List<int> ints, required List<double> doubles})
    : _ints = List.of(ints),
      _doubles = List.of(doubles);

  final List<int> _ints;
  final List<double> _doubles;

  @override
  bool nextBool() => nextDouble() >= 0.5;

  @override
  double nextDouble() => _doubles.isEmpty ? 0.5 : _doubles.removeAt(0);

  @override
  int nextInt(int max) =>
      _ints.isEmpty ? 0 : _ints.removeAt(0).clamp(0, max - 1).toInt();
}
