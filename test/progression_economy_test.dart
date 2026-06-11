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

  test('match XP rewards wins, small draw, and floors losses', () {
    // Win scales by margin + shutout, capped at 25.
    expect(
      calculateMatchXP(resultLabel: 'Victory', playerScore: 1, opponentScore: 0),
      18, // 10 + 1*3 + 5 shutout
    );
    expect(
      calculateMatchXP(resultLabel: 'Victory', playerScore: 5, opponentScore: 1),
      22, // 10 + 4*3, no shutout
    );
    // A level score after 4 rounds is a small positive draw award.
    expect(
      calculateMatchXP(resultLabel: 'Draw', playerScore: 2, opponentScore: 2),
      4,
    );
    // Defeats lose XP scaled by conceded margin, floored at -15.
    expect(
      calculateMatchXP(resultLabel: 'Defeat', playerScore: 0, opponentScore: 1),
      -7,
    );
    expect(
      calculateMatchXP(resultLabel: 'Defeat', playerScore: 0, opponentScore: 9),
      -15,
    );
  });

  test('shootout XP and coins are smaller, margin-scaled, never punish', () {
    expect(calculateShootoutXP(won: true, margin: 1), 8);
    expect(calculateShootoutXP(won: true, margin: 2), 10);
    expect(calculateShootoutXP(won: true, margin: 5), 12); // capped at 12
    expect(calculateShootoutXP(won: false, margin: 3), 0);
    expect(shootoutCoins(true), 20);
    expect(shootoutCoins(false), 5);
  });

  test('shootout opponent fields a full five-man squad with a keeper', () {
    final cpu = generateShootoutOpponent(
      6,
      attackers,
      defenders,
      goalkeepers,
      random: Random(7),
    );
    expect(cpu.shooters.length, 5);
    expect(cpu.shooters.last.isGoalkeeper, isTrue);
    expect(cpu.keeper.isGoalkeeper, isTrue);
    expect(cpu.shooters.last.id, cpu.keeper.id);
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
