import 'package:card_game/data/basketball_athletes.dart';
import 'package:card_game/models/basketball.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('basketball athlete looks', () {
    test('appearance derivation is stable for known athlete ids', () {
      final curry = basketballLookFor('gsw-stephen-curry');
      final jokic = basketballLookFor('den-nikola-jokic');
      final tatum = basketballLookFor('bos-jayson-tatum');

      expect(basketballLookFor('gsw-stephen-curry'), same(curry));
      expect(curry.hairStyle, BasketballHairStyle.fade);
      expect(curry.hairScale, closeTo(0.94, 0.0001));
      expect(curry.build, BasketballAthleteBuild.lean);
      expect(curry.buildScale, closeTo(0.916, 0.0001));

      expect(jokic.hairStyle, BasketballHairStyle.closeCrop);
      expect(jokic.hairScale, closeTo(0.98, 0.0001));
      expect(jokic.build, BasketballAthleteBuild.power);
      expect(jokic.buildScale, closeTo(1.08, 0.0001));

      expect(tatum.hairStyle, BasketballHairStyle.highTop);
      expect(tatum.hairScale, closeTo(0.94, 0.0001));
      expect(tatum.build, BasketballAthleteBuild.athletic);
      expect(tatum.buildScale, closeTo(0.982, 0.0001));
    });

    test('role build scales stay inside their render-only bands', () {
      for (final athlete in basketballAthletes) {
        final look = basketballLookFor(athlete.id);
        switch (athlete.cardRole) {
          case BasketballCardRole.guard:
            expect(look.build, BasketballAthleteBuild.lean);
            expect(look.buildScale, inInclusiveRange(0.88, 0.93));
            break;
          case BasketballCardRole.wing:
            expect(look.build, BasketballAthleteBuild.athletic);
            expect(look.buildScale, inInclusiveRange(0.97, 1.02));
            break;
          case BasketballCardRole.big:
            expect(look.build, BasketballAthleteBuild.power);
            expect(look.buildScale, inInclusiveRange(1.08, 1.14));
            break;
        }
        expect(look.hairScale, inInclusiveRange(0.9, 1.06));
      }
    });

    test('traits map to one restrained accessory', () {
      for (final athlete in basketballAthletes) {
        final expected = switch (athlete.trait) {
          BasketballTrait.quickRelease ||
          BasketballTrait.deepRange => BasketballAthleteGear.shootingSleeve,
          BasketballTrait.rimPressure => BasketballAthleteGear.headband,
          BasketballTrait.glassCleaner => BasketballAthleteGear.kneeSleeve,
        };

        expect(
          basketballLookFor(athlete.id).gear,
          expected,
          reason: athlete.id,
        );
      }
    });
  });
}
