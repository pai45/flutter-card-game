import 'package:card_game/data/grand_prix_liveries.dart';
import 'package:card_game/models/grand_prix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gridLine is the free default livery', () {
    expect(grandPrixFreeLivery, GrandPrixLivery.gridLine);
    expect(grandPrixLiveryPrice(GrandPrixLivery.gridLine), 0);
  });

  test('paid liveries cost 100 coins', () {
    for (final spec in grandPrixLiveries) {
      if (isGrandPrixLiveryFree(spec.livery)) continue;
      expect(grandPrixLiveryPrice(spec.livery), grandPrixLiveryCoinPrice);
    }
  });

  test('normalization always includes the free livery', () {
    expect(
      normalizeOwnedGrandPrixLiveryIds(const []),
      defaultOwnedGrandPrixLiveryIds(),
    );
    expect(
      normalizeOwnedGrandPrixLiveryIds(['scarlet', 'scarlet']),
      containsAll(['gridLine', 'scarlet']),
    );
  });

  test('free livery is always considered owned', () {
    expect(
      isGrandPrixLiveryOwned('gridLine', const []),
      isTrue,
    );
    expect(
      isGrandPrixLiveryOwned('scarlet', const []),
      isFalse,
    );
  });

  test('ensureEquippedLiveryOwned clamps unowned picks to gridLine', () {
    expect(
      ensureEquippedLiveryOwned(const ['gridLine'], GrandPrixLivery.scarlet),
      GrandPrixLivery.gridLine,
    );
    expect(
      ensureEquippedLiveryOwned(
        const ['gridLine', 'scarlet'],
        GrandPrixLivery.scarlet,
      ),
      GrandPrixLivery.scarlet,
    );
  });
}
