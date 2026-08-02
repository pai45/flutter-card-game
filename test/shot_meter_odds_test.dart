import 'dart:math';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('goalChanceForDiff', () {
    test('mirrors deterministic higher-total resolve', () {
      expect(goalChanceForDiff(20), 1.0);
      expect(goalChanceForDiff(0.1), 1.0);
      expect(goalChanceForDiff(0), 0.5);
      expect(goalChanceForDiff(-0.1), 0.0);
      expect(goalChanceForDiff(-20), 0.0);
    });

    test('is monotonically non-decreasing in the power advantage', () {
      final samples = [
        for (var d = -30.0; d <= 30.0; d += 2.5) goalChanceForDiff(d),
      ];
      for (var i = 1; i < samples.length; i++) {
        expect(samples[i], greaterThanOrEqualTo(samples[i - 1]));
      }
    });
  });

  group('resolveRoundDeterministic', () {
    test('positive diff is always a goal', () {
      expect(
        resolveRoundDeterministic(11, tieHeads: false),
        RoundOutcome.goal,
      );
      expect(
        resolveRoundDeterministic(0.01, tieHeads: true),
        RoundOutcome.goal,
      );
    });

    test('negative diff is always a save', () {
      expect(
        resolveRoundDeterministic(-11, tieHeads: true),
        RoundOutcome.saved,
      );
      expect(
        resolveRoundDeterministic(-0.01, tieHeads: false),
        RoundOutcome.saved,
      );
    });

    test('exact ties coin-flip between goal and blocked', () {
      expect(
        resolveRoundDeterministic(0, tieHeads: true),
        RoundOutcome.goal,
      );
      expect(
        resolveRoundDeterministic(0, tieHeads: false),
        RoundOutcome.blocked,
      );
    });
  });

  group('goalChanceForDiffProbabilistic (rollback helper)', () {
    test('keeps the former banded odds table', () {
      expect(goalChanceForDiffProbabilistic(20), 0.80);
      expect(goalChanceForDiffProbabilistic(10), 0.65);
      expect(goalChanceForDiffProbabilistic(0), 0.45);
      expect(goalChanceForDiffProbabilistic(-10), 0.10);
      expect(goalChanceForDiffProbabilistic(-20), 0.05);
      expect(goalChanceForDiffProbabilistic(15), 0.65);
      expect(goalChanceForDiffProbabilistic(5), 0.45);
      expect(goalChanceForDiffProbabilistic(-5), 0.10);
      expect(goalChanceForDiffProbabilistic(-15), 0.05);
    });
  });

  group('resolveRoundProbabilistic (rollback helper)', () {
    const attack = ActionCard(
      id: 'test-atk',
      title: 'Safe',
      category: ActionCategory.attack,
      tier: CardTier.bronze,
      effect: 'test',
      power: 10,
      risky: false,
      icon: Icons.sports_soccer,
    );
    const defense = ActionCard(
      id: 'test-def',
      title: 'Block',
      category: ActionCategory.defense,
      tier: CardTier.bronze,
      effect: 'test',
      power: 10,
      risky: false,
      icon: Icons.shield,
    );

    test('returns a valid RoundOutcome for a non-risky duel', () {
      final outcome = resolveRoundProbabilistic(
        100,
        80,
        attack,
        defense,
        Random(42),
      );
      expect(RoundOutcome.values, contains(outcome));
    });
  });
}
