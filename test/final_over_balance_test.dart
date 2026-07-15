import 'package:flutter_test/flutter_test.dart';

import 'package:card_game/models/final_over.dart';

void main() {
  group('Final Over difficulty balance', () {
    test('new and invalid profiles default to Rookie', () {
      expect(const FinalOverStats().tier, FinalOverTier.rookie);
      expect(FinalOverStats.fromJson(const {}).tier, FinalOverTier.rookie);
      expect(
        FinalOverStats.fromJson(const {'tier': 'future'}).tier,
        FinalOverTier.rookie,
      );
    });

    test('target pools keep the full ladder with easier progression', () {
      expect(FinalOverTier.rookie.targets, [8, 10]);
      expect(FinalOverTier.pro.targets, [10, 12, 14]);
      expect(FinalOverTier.elite.targets, [16, 18, 20]);
    });

    test('Rookie applies the forgiving gameplay profile', () {
      final tuning = FinalOverTier.rookie.tuning;
      expect(tuning.perfectWindowMs, 80);
      expect(tuning.goodWindowMs, 180);
      expect(tuning.earlyLateWindowMs, 300);
      expect(tuning.poorWindowMs, 400);
      expect(tuning.maximumWickets, 3);
      expect(tuning.baseCatchChance, 0.58);
      expect(tuning.keeperCatchChance, 0.68);
      expect(tuning.fielderSpeed, 0.28);
      expect(tuning.throwSpeed, 0.68);
      expect(tuning.batterReach, 0.100);
      expect(tuning.powerShotSegments, 4);
      expect(tuning.backliftPowerFloor, 0.75);
      expect(tuning.overswingFrom, 0.98);
      expect(tuning.overswingControlPenalty, 0.10);
      expect(tuning.overswingEdgeBonus, 0.04);
      expect(tuning.groundPowerSpeed, closeTo(0.858, 0.0001));
      expect(tuning.loftPowerSpeed, closeTo(0.715, 0.0001));
    });

    test(
      'Pro is softened and Elite preserves the original field challenge',
      () {
        final pro = FinalOverTier.pro.tuning;
        expect(pro.perfectWindowMs, 65);
        expect(pro.goodWindowMs, 150);
        expect(pro.poorWindowMs, 330);
        expect(pro.baseCatchChance, 0.68);
        expect(pro.fielderSpeed, 0.32);
        expect(pro.powerShotSegments, 5);

        final elite = FinalOverTier.elite.tuning;
        expect(elite.perfectWindowMs, 50);
        expect(elite.goodWindowMs, 115);
        expect(elite.poorWindowMs, 275);
        expect(elite.baseCatchChance, 0.82);
        expect(elite.keeperCatchChance, 0.88);
        expect(elite.fielderSpeed, 0.35);
        expect(elite.throwSpeed, 0.78);
        expect(elite.powerShotSegments, 8);
      },
    );
  });
}
