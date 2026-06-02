import 'dart:math';

import 'package:card_game/models/cards.dart';
import 'package:card_game/models/packs.dart';
import 'package:card_game/models/progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('progression math follows prompt curve', () {
    expect(xpToReach(1), 0);
    expect(xpToReach(2), 100);
    expect(xpToReach(3), 300);
    expect(levelFromXp(-10), 1);
    expect(levelFromXp(0), 1);
    expect(levelFromXp(100), 2);
    expect(levelFromXp(299), 2);
    expect(levelFromXp(300), 3);

    final progress = levelProgress(150);
    expect(progress.level, 2);
    expect(progress.intoLevel, 50);
    expect(progress.levelSpan, 200);
    expect(progress.toNextLevel, 150);
    expect(progress.pct, 0.25);
  });

  test('card XP, daily countdown, and match coins use prompt formulas', () {
    expect(playerCardXp(attackers.first), attackers.first.rating);
    // actionCards.first is act1 bronze (power 9); .last is act16 platinum (power 10).
    expect(actionCardXp(actionCards.first), 39);
    expect(actionCardXp(actionCards.last), 40);
    expect(coinsForResult('Victory'), 50);
    expect(coinsForResult('Draw'), 25);
    expect(coinsForResult('Defeat'), 10);

    final now = DateTime(2026, 1, 1, 12);
    expect(dailyDropStatus(null, now).ready, isTrue);
    final cooldown = dailyDropStatus(
      now.subtract(const Duration(hours: 2)),
      now,
    );
    expect(cooldown.ready, isFalse);
    expect(formatCountdown(cooldown.remaining), '22h 0m');
  });

  test('starter pack is a legal playable deck', () {
    final result = buildStarterPack(attackers, defenders, actionCards);
    expect(result.playerCards.length, 5);
    expect(result.actionCards.length, 6);
    expect(
      result.playerCards.where((card) => card.role.name == 'attacker').length,
      greaterThanOrEqualTo(2),
    );
    expect(
      result.playerCards.where((card) => card.role.name == 'defender').length,
      2,
    );
    expect(result.xpGained, greaterThan(0));
  });

  test('shop and daily rolls return configured counts', () {
    final bronze = getProgressionPack('bronze')!;
    final rolled = rollPack(
      bronze,
      [...attackers, ...defenders],
      actionCards,
      random: Random(1),
    );
    expect(rolled.playerCards.length, bronze.playerCount);
    expect(rolled.actionCards.length, bronze.actionCount);
    expect(rolled.xpGained, greaterThan(0));

    final daily = rollDailyDrop(
      [...attackers, ...defenders],
      actionCards,
      random: Random(2),
    );
    expect(daily.cardCount, 1);
    expect(daily.xpGained, greaterThan(0));
  });
}
