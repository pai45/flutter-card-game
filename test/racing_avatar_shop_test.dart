import 'package:card_game/models/cards.dart';
import 'package:card_game/models/packs.dart';
import 'package:card_game/models/shop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('racing shop packs resolve progression packs', () {
    expect(racingShopPacks.length, 3);
    for (final shopPack in racingShopPacks) {
      final pack = getProgressionPack(shopPack.id);
      expect(pack, isNotNull);
      expect(pack!.actionCount, 0);
      expect(pack.playerCount, shopPack.playerCount);
      expect(pack.price, shopPack.coinPrice);
    }
  });

  test('racing pack ids are isolated from football starter', () {
    expect(kRacingPackIds.contains('starter'), isFalse);
    expect(kRacingPackIds.length, 3);
  });

  test('motorsport cards are not capped at 48 in filter logic', () {
    final allRacing = allPlayerCards
        .where((card) => card.icon == Icons.sports_motorsports)
        .length;
    expect(allRacing, racingPlayerCards.length);
    expect(allRacing > 48, isTrue);
  });
}
