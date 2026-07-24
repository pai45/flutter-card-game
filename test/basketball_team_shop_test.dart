import 'package:card_game/data/basketball_teams.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('basketball jersey pricing marks statoz free and others at 100 coins', () {
    final free = basketballTeamById(basketballFreeTeamId);
    final paid = basketballTeamById('lakers');

    expect(isBasketballTeamFree(free), isTrue);
    expect(basketballTeamPrice(free), 0);
    expect(isBasketballTeamFree(paid), isFalse);
    expect(basketballTeamPrice(paid), basketballTeamCoinPrice);
  });

  test('normalizeOwnedBasketballTeamIds always includes the free jersey', () {
    expect(
      normalizeOwnedBasketballTeamIds(const ['lakers']),
      contains('statoz'),
    );
  });

  test('isBasketballTeamOwned treats free jersey as owned without wallet entry', () {
    expect(isBasketballTeamOwned('statoz', const []), isTrue);
    expect(isBasketballTeamOwned('lakers', const []), isFalse);
    expect(isBasketballTeamOwned('lakers', const ['lakers']), isTrue);
  });

  test('basketballTeamById falls back to statoz for unknown ids', () {
    expect(basketballTeamById('not-a-team').id, basketballFreeTeamId);
  });
}
