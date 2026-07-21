import 'dart:math';
import 'dart:io';

import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/packs.dart';
import 'package:card_game/models/starter_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('packRarity mapping', () {
    test('rating bands map to the right tier', () {
      expect(packRarityForRating(94), CardTier.platinum);
      expect(packRarityForRating(90), CardTier.platinum);
      expect(packRarityForRating(89), CardTier.gold);
      expect(packRarityForRating(86), CardTier.gold);
      expect(packRarityForRating(85), CardTier.silver);
      expect(packRarityForRating(80), CardTier.silver);
      expect(packRarityForRating(79), CardTier.bronze);
      expect(packRarityForRating(75), CardTier.bronze);
    });

    test('action power bands map to the right tier', () {
      expect(packRarityForPower(30), CardTier.platinum);
      expect(packRarityForPower(22), CardTier.platinum);
      expect(packRarityForPower(20), CardTier.gold);
      expect(packRarityForPower(16), CardTier.gold);
      expect(packRarityForPower(15), CardTier.silver);
      expect(packRarityForPower(10), CardTier.silver);
      expect(packRarityForPower(9), CardTier.bronze);
      expect(packRarityForPower(8), CardTier.bronze);
    });

    test('drop chances sum to 1.0', () {
      final total = CardTier.values
          .map((tier) => tier.starterDropChance)
          .reduce((a, b) => a + b);
      expect(total, closeTo(1.0, 1e-9));
    });
  });

  group('rollPackRarity distribution', () {
    test('roughly matches 55/35/4/1 weights over many rolls', () {
      final rng = Random(42);
      const n = 100000;
      final counts = {for (final tier in CardTier.values) tier: 0};
      for (var i = 0; i < n; i++) {
        final tier = rollPackRarity(rng);
        counts[tier] = counts[tier]! + 1;
      }
      expect(
        counts[CardTier.bronze]! / n,
        closeTo(CardTier.bronze.starterDropChance, 0.02),
      );
      expect(
        counts[CardTier.silver]! / n,
        closeTo(CardTier.silver.starterDropChance, 0.02),
      );
      expect(
        counts[CardTier.gold]! / n,
        closeTo(CardTier.gold.starterDropChance, 0.01),
      );
      expect(
        counts[CardTier.platinum]! / n,
        closeTo(CardTier.platinum.starterDropChance, 0.005),
      );
    });
  });

  group('rollStarterPack composition', () {
    test('has 2 strikers, 2 defenders, 1 keeper and 5 actions', () {
      final pack = rollDefaultStarterPack(random: Random(1));
      expect(pack.strikers, hasLength(2));
      expect(pack.defenders, hasLength(2));
      expect(pack.keeper, isNotNull);
      expect(pack.players, hasLength(5));
      expect(pack.actions, hasLength(5));
    });

    test('players have the correct roles', () {
      final pack = rollDefaultStarterPack(random: Random(7));
      expect(pack.strikers.every((c) => c.role == PlayerRole.attacker), isTrue);
      expect(
        pack.defenders.every((c) => c.role == PlayerRole.defender),
        isTrue,
      );
      expect(pack.keeper.role, PlayerRole.goalkeeper);
    });

    test('action cards split 3-2 between attack and defense', () {
      for (var seed = 0; seed < 50; seed++) {
        final pack = rollDefaultStarterPack(random: Random(seed));
        final counts = [pack.attackActions.length, pack.defenseActions.length]
          ..sort();
        expect(counts, [2, 3], reason: 'seed $seed should be a 3-2 split');
        expect(
          pack.attackActions.every((c) => c.category == ActionCategory.attack),
          isTrue,
        );
        expect(
          pack.defenseActions.every(
            (c) => c.category == ActionCategory.defense,
          ),
          isTrue,
        );
      }
    });

    test('contains no duplicate cards', () {
      for (var seed = 0; seed < 50; seed++) {
        final pack = rollDefaultStarterPack(random: Random(seed));
        final playerIds = pack.players.map((c) => c.id).toList();
        final actionIds = pack.actions.map((c) => c.id).toList();
        expect(playerIds.toSet(), hasLength(playerIds.length));
        expect(actionIds.toSet(), hasLength(actionIds.length));
      }
    });

    test('rarity breakdown counts all 10 cards', () {
      final pack = rollDefaultStarterPack(random: Random(99));
      final total = pack.rarityBreakdown.values.reduce((a, b) => a + b);
      expect(total, 10);
    });
  });

  group('cricket catalog and starter pack', () {
    test('catalog includes every CSV player', () {
      final rowCount =
          File(
            'ipl_players.csv',
          ).readAsLinesSync().where((line) => line.trim().isNotEmpty).length -
          1;

      expect(cricketPlayerCards, hasLength(rowCount));
      expect(
        allPlayerCards,
        hasLength(
          footballPlayerCards.length +
              cricketPlayerCards.length +
              basketballPlayerCards.length +
              tennisPlayerCards.length,
        ),
      );
    });

    test('image-backed cricket cards resolve portraits', () {
      final kohli = cricketPlayerCards.firstWhere(
        (card) => card.name == 'Virat Kohli',
      );

      expect(
        kohli.resolvedPortraitAsset,
        'assets/cricketer_images/virat_kohli.webp',
      );
      expect(kohli.hasPortrait, isTrue);
    });

    test('cricket starter contains 3 unique bronze batting cards', () {
      final result = buildCricketStarterPack(
        cricketBattingCards,
        random: Random(8),
      );
      final ids = result.playerCards.map((card) => card.id).toList();

      expect(result.playerCards, hasLength(cricketStarterCardCount));
      expect(result.actionCards, isEmpty);
      expect(ids.toSet(), hasLength(ids.length));
      expect(
        result.playerCards.every((card) => card.role == PlayerRole.batsman),
        isTrue,
      );
      expect(
        result.playerCards.every((card) => card.tier == CardTier.bronze),
        isTrue,
      );
    });

    test('basketball starter contains one guard, one wing and one big', () {
      final result = buildBasketballStarterPack(
        basketballPlayerCards,
        random: Random(12),
      );
      final ids = result.playerCards.map((card) => card.id).toList();

      expect(result.playerCards, hasLength(basketballStarterCardCount));
      expect(result.actionCards, isEmpty);
      expect(ids.toSet(), hasLength(ids.length));
      expect(
        result.playerCards.every((card) => card.tier != CardTier.platinum),
        isTrue,
      );
      expect(
        result.playerCards.where(
          (card) => card.role == PlayerRole.basketballGuard,
        ),
        hasLength(1),
      );
      expect(
        result.playerCards.where(
          (card) => card.role == PlayerRole.basketballWing,
        ),
        hasLength(1),
      );
      expect(
        result.playerCards.where(
          (card) => card.role == PlayerRole.basketballBig,
        ),
        hasLength(1),
      );
    });
  });

  group('match deck constraint', () {
    test('max is 5 cards', () {
      expect(maxMatchDeckCards, 5);
    });

    test('isValidMatchDeckSize accepts 1..5 and rejects others', () {
      expect(isValidMatchDeckSize(0), isFalse);
      expect(isValidMatchDeckSize(1), isTrue);
      expect(isValidMatchDeckSize(5), isTrue);
      expect(isValidMatchDeckSize(6), isFalse);
    });

    test('canAddToMatchDeck blocks the 6th card', () {
      expect(canAddToMatchDeck(4), isTrue);
      expect(canAddToMatchDeck(5), isFalse);
    });

    test('enforceMatchDeckLimit trims to 5 preserving order', () {
      final ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g'];
      expect(enforceMatchDeckLimit(ids), ['a', 'b', 'c', 'd', 'e']);
    });
  });
}
