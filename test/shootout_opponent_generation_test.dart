import 'dart:math';

import 'package:card_game/data/random_opponent_names.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/progression.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shootout opponent name helper draws from a 500-name pool', () {
    expect(randomOpponentNames, hasLength(500));

    final name = randomOpponentName(random: Random(4));

    expect(randomOpponentNames, contains(name));
    expect(name.split(' '), hasLength(2));
  });

  test('shootout opponent has five shooters with keeper last', () {
    final opponent = generateShootoutOpponent(
      4,
      attackers,
      defenders,
      goalkeepers,
      random: Random(3),
    );

    expect(opponent.shooters, hasLength(5));
    expect(opponent.shooters.last, opponent.keeper);
    expect(opponent.keeper.isGoalkeeper, isTrue);
  });

  test('same-level shootout sessions can produce different squads', () {
    final lineups = <String>{};

    for (var seed = 0; seed < 8; seed++) {
      final opponent = generateShootoutOpponent(
        4,
        attackers,
        defenders,
        goalkeepers,
        random: Random(seed),
      );
      lineups.add(opponent.shooters.map((card) => card.id).join('|'));
    }

    expect(lineups.length, greaterThan(1));
  });
}
