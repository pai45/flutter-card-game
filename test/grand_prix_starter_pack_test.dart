import 'dart:math';

import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/packs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('grand prix starter pack always yields exactly one bronze driver', () {
    final ids = racingPlayerCards.map((card) => card.id).toSet();
    for (var seed = 0; seed < 500; seed++) {
      final result = buildGrandPrixStarterPack(
        racingPlayerCards,
        random: Random(seed),
      );
      expect(result.playerCards, hasLength(grandPrixStarterCardCount));
      expect(result.actionCards, isEmpty);
      final card = result.playerCards.single;
      expect(card.tier, CardTier.bronze, reason: 'seed $seed drew ${card.id}');
      expect(
        card.role,
        isIn([
          PlayerRole.f1Driver,
          PlayerRole.f2Driver,
          PlayerRole.nascarDriver,
          PlayerRole.indycarDriver,
        ]),
      );
      expect(ids, contains(card.id));
    }
  });

  test('the draw spreads across the bronze pool rather than fixating', () {
    final drawn = {
      for (var seed = 0; seed < 200; seed++)
        buildGrandPrixStarterPack(racingPlayerCards, random: Random(seed))
            .playerCards
            .single
            .id,
    };
    expect(drawn.length, greaterThan(5));
  });

  test('an empty bronze pool is a hard failure, not a silver fallback', () {
    final noBronze = racingPlayerCards
        .where((card) => card.tier != CardTier.bronze)
        .toList();
    expect(
      () => buildGrandPrixStarterPack(noBronze, random: Random(1)),
      throwsStateError,
    );
  });

  test('reveal data feeds the shared cinematic a single bronze card', () {
    final result = buildGrandPrixStarterPack(
      racingPlayerCards,
      random: Random(3),
    );
    final reveal = PackRevealData.grandPrixStarter(
      result: result,
      levelsGained: const [],
    );

    expect(reveal.headline, 'PIT LANE\nSTARTER');
    expect(reveal.ctaLabel, 'ENTER GRAND PRIX DASH');
    expect(reveal.groupActionCards, isFalse);
    expect(reveal.animatedItems, hasLength(1));
    expect(reveal.groupedActionItems, isEmpty);
    final item = reveal.animatedItems.single;
    expect(item.isPlayer, isTrue);
    expect(item.tier.name, 'bronze');
    expect(item.rating, greaterThan(0));
  });

  test('bronze pool includes drivers from every motorsport series', () {
    final bronze = racingPlayerCards
        .where((card) => card.tier == CardTier.bronze)
        .toList();
    expect(bronze, isNotEmpty);
    expect(
      bronze.any((card) => card.role == PlayerRole.f1Driver),
      isTrue,
    );
    expect(
      bronze.any((card) => card.role == PlayerRole.f2Driver),
      isTrue,
    );
    expect(
      bronze.any((card) => card.role == PlayerRole.nascarDriver),
      isTrue,
    );
    expect(
      bronze.any((card) => card.role == PlayerRole.indycarDriver),
      isTrue,
    );
  });
}
