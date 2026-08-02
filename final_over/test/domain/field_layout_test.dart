import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('field layouts are complete, unique, and inside the rope', () {
    expect(GameplayTuning.fieldLayouts, hasLength(5));

    for (final layout in GameplayTuning.fieldLayouts) {
      expect(layout.id, isNotEmpty);
      expect(layout.label, isNotEmpty);
      expect(layout.fielders, hasLength(10));
      expect(
        layout.fielders.map((fielder) => fielder.id).toSet(),
        hasLength(10),
      );
      expect(
        layout.fielders.where(
          (fielder) => fielder.role == FielderRole.outfielder,
        ),
        hasLength(8),
      );
      expect(
        layout.fielders.where(
          (fielder) => fielder.role == FielderRole.wicketkeeper,
        ),
        hasLength(1),
      );
      expect(
        layout.fielders.where((fielder) => fielder.role == FielderRole.bowler),
        hasLength(1),
      );
      for (final fielder in layout.fielders) {
        expect(fielder.position.length, lessThan(1));
        expect(fielder.homePosition, fielder.position);
      }
    }
  });

  test('seeded layout rotation changes on every physical delivery', () {
    for (final seed in [-7, 0, 19]) {
      final sequence = [
        for (var ordinal = 1; ordinal <= 12; ordinal++)
          GameplayTuning.fieldLayoutFor(
            matchSeed: seed,
            physicalOrdinal: ordinal,
          ).id,
      ];

      for (var index = 1; index < sequence.length; index++) {
        expect(sequence[index], isNot(sequence[index - 1]));
      }
      expect(
        GameplayTuning.fieldLayoutFor(matchSeed: seed, physicalOrdinal: 1).id,
        sequence.first,
      );
    }
  });
}
