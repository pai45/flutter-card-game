import 'dart:math';

import 'package:card_game/config/enums.dart';
import 'package:card_game/models/starter_pack.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('packRarity mapping', () {
    test('rating bands map to the right rarity', () {
      // Platinum 90-94, gold 86-89, silver 80-85, bronze 75-79.
      expect(packRarityForRating(94), PackRarity.legendary);
      expect(packRarityForRating(90), PackRarity.legendary);
      expect(packRarityForRating(89), PackRarity.epic);
      expect(packRarityForRating(86), PackRarity.epic);
      expect(packRarityForRating(85), PackRarity.gold);
      expect(packRarityForRating(80), PackRarity.gold);
      expect(packRarityForRating(79), PackRarity.silver);
      expect(packRarityForRating(75), PackRarity.silver);
    });

    test('action power bands map to the right rarity', () {
      expect(packRarityForPower(30), PackRarity.legendary);
      expect(packRarityForPower(22), PackRarity.legendary);
      expect(packRarityForPower(20), PackRarity.epic);
      expect(packRarityForPower(16), PackRarity.epic);
      expect(packRarityForPower(15), PackRarity.gold);
      expect(packRarityForPower(10), PackRarity.gold);
      expect(packRarityForPower(9), PackRarity.silver);
      expect(packRarityForPower(8), PackRarity.silver);
    });

    test('drop chances sum to 1.0', () {
      final total = PackRarity.values
          .map((r) => r.dropChance)
          .reduce((a, b) => a + b);
      expect(total, closeTo(1.0, 1e-9));
    });
  });

  group('rollPackRarity distribution', () {
    test('roughly matches 50/35/10/5 over many rolls', () {
      final rng = Random(42);
      const n = 100000;
      final counts = {for (final r in PackRarity.values) r: 0};
      for (var i = 0; i < n; i++) {
        final r = rollPackRarity(rng);
        counts[r] = counts[r]! + 1;
      }
      expect(counts[PackRarity.silver]! / n, closeTo(0.50, 0.02));
      expect(counts[PackRarity.gold]! / n, closeTo(0.35, 0.02));
      expect(counts[PackRarity.epic]! / n, closeTo(0.10, 0.02));
      expect(counts[PackRarity.legendary]! / n, closeTo(0.05, 0.02));
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
      expect(
        pack.strikers.every((c) => c.role == PlayerRole.attacker),
        isTrue,
      );
      expect(
        pack.defenders.every((c) => c.role == PlayerRole.defender),
        isTrue,
      );
      expect(pack.keeper.role, PlayerRole.goalkeeper);
    });

    test('action cards split 3-2 between attack and defense', () {
      for (var seed = 0; seed < 50; seed++) {
        final pack = rollDefaultStarterPack(random: Random(seed));
        final counts = [
          pack.attackActions.length,
          pack.defenseActions.length,
        ]..sort();
        expect(counts, [2, 3], reason: 'seed $seed should be a 3-2 split');
        expect(
          pack.attackActions.every((c) => c.category == ActionCategory.attack),
          isTrue,
        );
        expect(
          pack.defenseActions
              .every((c) => c.category == ActionCategory.defense),
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
