import 'dart:math';

import 'package:card_game/blocs/shootout/shootout_bloc.dart';
import 'package:card_game/blocs/shootout/shootout_event.dart';
import 'package:card_game/blocs/shootout/shootout_state.dart';
import 'package:card_game/config/enums.dart';
import 'package:card_game/models/cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Random whose [nextDouble] returns scripted values in order (then 0.0),
/// and whose [nextInt] is a constant. The bloc consumes exactly two doubles
/// per kick: a CPU-direction check, then the goal roll.
class _ScriptedRandom implements Random {
  _ScriptedRandom(this._doubles, {this.fixedInt = 0});

  final List<double> _doubles;
  final int fixedInt;
  int _i = 0;

  @override
  double nextDouble() => _i < _doubles.length ? _doubles[_i++] : 0.0;

  @override
  int nextInt(int max) => fixedInt % max;

  @override
  bool nextBool() => false;
}

PlayerCard _card(String id, PlayerRole role, int rating) => PlayerCard(
  id: id,
  name: id,
  shortName: id,
  country: 'X',
  countryCode: 'X',
  position: role == PlayerRole.attacker
      ? 'ST'
      : role == PlayerRole.defender
      ? 'CB'
      : 'GK',
  role: role,
  rating: rating,
  trait: 'T',
  tier: CardTier.gold,
  icon: Icons.sports_soccer,
);

List<PlayerCard> _squad(String tag) => [
  _card('$tag-a1', PlayerRole.attacker, 85),
  _card('$tag-a2', PlayerRole.attacker, 84),
  _card('$tag-d1', PlayerRole.defender, 80),
  _card('$tag-d2', PlayerRole.defender, 79),
  _card('$tag-gk', PlayerRole.goalkeeper, 82),
];

ShootoutBloc _bloc(List<double> script) {
  final player = _squad('p');
  final cpu = _squad('c');
  return ShootoutBloc(
    playerShooters: player,
    playerKeeper: player.last,
    cpuShooters: cpu,
    cpuKeeper: cpu.last,
    cpuLevel: 1,
    opponentName: 'Maya Santos',
    random: _ScriptedRandom(script, fixedInt: 0),
  );
}

// One kick = [direction-check = 1.0 (skip habit read), score roll].
const _goal = [1.0, 0.0]; // 0.0 < any chance -> scores
const _miss = [1.0, 0.99]; // 0.99 >= any chance -> saved

Future<void> _playKick(ShootoutBloc bloc) async {
  bloc.add(ShootoutDirectionSelected(PenaltyDirection.right));
  await Future<void>.delayed(Duration.zero);
  bloc.add(ShootoutKickConfirmed());
  await Future<void>.delayed(Duration.zero);
  if (!bloc.state.over) {
    bloc.add(ShootoutNextKick());
    await Future<void>.delayed(Duration.zero);
  }
}

Future<void> _startShootout(ShootoutBloc bloc) async {
  bloc.add(ShootoutOpponentRevealCompleted());
  await Future<void>.delayed(Duration.zero);
  bloc.add(ShootoutStarted());
  await Future<void>.delayed(Duration.zero);
}

void main() {
  group('shootoutGoalChance', () {
    test('a wrong-way dive is a near-certain goal', () {
      expect(
        shootoutGoalChance(
          shooterRating: 70,
          keeperRating: 99,
          keeperGuessedRight: false,
        ),
        0.95,
      );
    });

    test('a correct guess scales the save chance by rating gap', () {
      double g(int s, int k) => shootoutGoalChance(
        shooterRating: s,
        keeperRating: k,
        keeperGuessedRight: true,
      );
      expect(g(99, 70), 0.45); // diff +29
      expect(g(80, 70), 0.35); // diff +10
      expect(g(80, 80), 0.25); // diff 0
      expect(g(70, 80), 0.15); // diff -10
      expect(g(60, 99), 0.08); // diff -39
    });
  });

  group('ShootoutState getters', () {
    test('starts at opponent reveal with a named opponent', () {
      final player = _squad('p');
      final cpu = _squad('c');
      final base = ShootoutState.initial(
        playerShooters: player,
        playerKeeper: player.last,
        cpuShooters: cpu,
        cpuKeeper: cpu.last,
        cpuLevel: 1,
        opponentName: 'Maya Santos',
      );

      expect(base.stage, ShootoutStage.opponentReveal);
      expect(base.opponentName, 'Maya Santos');
      expect(
        base.copyWith(stage: ShootoutStage.lineup).opponentName,
        'Maya Santos',
      );
    });

    test('cycles the lineup once each side passes five kicks', () {
      final player = _squad('p');
      final cpu = _squad('c');
      final base = ShootoutState.initial(
        playerShooters: player,
        playerKeeper: player.last,
        cpuShooters: cpu,
        cpuKeeper: cpu.last,
        cpuLevel: 1,
        opponentName: 'Maya Santos',
      );
      // Round 0: player's 1st shooter.
      expect(base.currentShooter.id, player[0].id);
      expect(base.playerTaking, isTrue);
      expect(base.turnRole, ShootoutTurnRole.shooting);
      // Round 10: player's 6th kick wraps back to shooter index 0.
      expect(base.copyWith(round: 10).currentShooter.id, player[0].id);
      // Round 1: CPU's 1st shooter; the player's keeper is in goal.
      final cpuTurn = base.copyWith(round: 1);
      expect(cpuTurn.playerTaking, isFalse);
      expect(cpuTurn.turnRole, ShootoutTurnRole.defending);
      expect(cpuTurn.currentShooter.id, cpu[0].id);
      expect(cpuTurn.currentKeeper.id, player.last.id);
    });
  });

  group('ShootoutBloc resolution', () {
    test('opponent reveal advances to lineup before shootout starts', () async {
      final bloc = _bloc(const []);

      expect(bloc.state.stage, ShootoutStage.opponentReveal);
      bloc.add(ShootoutStarted());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.stage, ShootoutStage.opponentReveal);

      bloc.add(ShootoutOpponentRevealCompleted());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.stage, ShootoutStage.lineup);

      bloc.add(ShootoutStarted());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.stage, ShootoutStage.choose);
      expect(bloc.state.opponentName, 'Maya Santos');

      await bloc.close();
    });

    test('ends early once the lead is unbeatable', () async {
      // Player scores every kick, CPU misses every kick.
      final script = <double>[
        ..._goal, // R0 player goal
        ..._miss, // R1 cpu miss
        ..._goal, // R2 player goal
        ..._miss, // R3 cpu miss
        ..._goal, // R4 player goal
        ..._miss, // R5 cpu miss -> 3-0 with 2 each left: early out
      ];
      final bloc = _bloc(script);
      await _startShootout(bloc);
      for (var i = 0; i < 6 && !bloc.state.over; i++) {
        await _playKick(bloc);
      }
      expect(bloc.state.over, isTrue);
      expect(bloc.state.winner, 'player');
      expect(bloc.state.kicks.length, lessThan(kShootoutKicks));
      await bloc.close();
    });

    test(
      'a level shootout goes to sudden death and still finds a winner',
      () async {
        // All 10 regulation kicks score (5-5), then SD: player scores, CPU misses.
        final script = <double>[
          for (var i = 0; i < 10; i++) ..._goal, // 5-5 after regulation
          ..._goal, // R10 player goal (SD)
          ..._miss, // R11 cpu miss (SD) -> player wins the pair
        ];
        final bloc = _bloc(script);
        await _startShootout(bloc);
        for (var i = 0; i < 12 && !bloc.state.over; i++) {
          await _playKick(bloc);
        }
        expect(bloc.state.suddenDeath, isTrue);
        expect(bloc.state.over, isTrue);
        // A shootout never draws — exactly one winner.
        expect(bloc.state.winner, anyOf('player', 'opponent'));
        expect(bloc.state.winner, 'player');
        expect(bloc.state.playerScore, isNot(bloc.state.opponentScore));
        await bloc.close();
      },
    );
  });
}
