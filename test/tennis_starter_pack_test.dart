import 'dart:math';

import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/data/tennis_athletes.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/packs.dart';
import 'package:card_game/utils/tennis_country_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tennis starter pack always yields exactly one bronze athlete', () {
    final ids = tennisTop100.map((player) => player.id).toSet();
    for (var seed = 0; seed < 500; seed++) {
      final result = buildTennisStarterPack(
        tennisPlayerCards,
        random: Random(seed),
      );
      expect(result.playerCards, hasLength(tennisStarterCardCount));
      expect(result.actionCards, isEmpty);
      final card = result.playerCards.single;
      expect(card.tier, CardTier.bronze, reason: 'seed $seed drew ${card.id}');
      expect(card.role, PlayerRole.tennisSingles);
      expect(ids, contains(card.id));
    }
  });

  test('the draw spreads across the bronze pool rather than fixating', () {
    final drawn = {
      for (var seed = 0; seed < 200; seed++)
        buildTennisStarterPack(tennisPlayerCards, random: Random(seed))
            .playerCards
            .single
            .id,
    };
    expect(drawn.length, greaterThan(5));
  });

  test('an empty bronze pool is a hard failure, not a silver fallback', () {
    final noBronze = tennisPlayerCards
        .where((card) => card.tier != CardTier.bronze)
        .toList();
    expect(
      () => buildTennisStarterPack(noBronze, random: Random(1)),
      throwsStateError,
    );
  });

  test('reveal data feeds the shared cinematic a single bronze card', () {
    final result = buildTennisStarterPack(
      tennisPlayerCards,
      random: Random(3),
    );
    final reveal = PackRevealData.tennisStarter(
      result: result,
      levelsGained: const [],
    );

    expect(reveal.headline, 'TENNIS\nSTARTER');
    expect(reveal.ctaLabel, 'ENTER TENNIS RALLY');
    // The animation phase machine reads animatedItems; grouping stays off so
    // the one player card is the whole reveal.
    expect(reveal.groupActionCards, isFalse);
    expect(reveal.animatedItems, hasLength(1));
    expect(reveal.groupedActionItems, isEmpty);
    final item = reveal.animatedItems.single;
    expect(item.isPlayer, isTrue);
    // CardUnpackAnimation keys its pack art and particles off tier.name.
    expect(item.tier.name, 'bronze');
    expect(item.rating, greaterThan(0));
  });

  test('tennis cards mirror the roster one-to-one', () {
    expect(tennisPlayerCards, hasLength(tennisTop100.length));
    for (final card in tennisPlayerCards) {
      expect(allPlayerCards.any((entry) => entry.id == card.id), isTrue);
    }
  });

  test('every athlete on the roster has a mapped country', () {
    final unmapped = tennisTop100
        .where((player) => TennisCountryMap.countryCodeFor(player.name) == null)
        .map((player) => player.name)
        .toList();
    expect(unmapped, isEmpty, reason: 'these would render as "INT" on a card');
  });

  test('country lookup prefers the most specific key', () {
    // "Paula Badosa" contains the shorter "paul" key for Tommy Paul.
    expect(TennisCountryMap.countryCodeFor('Paula Badosa'), 'ESP');
    expect(TennisCountryMap.countryCodeFor('Tommy Paul'), 'USA');
  });
}
