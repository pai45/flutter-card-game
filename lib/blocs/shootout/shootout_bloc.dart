import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../config/enums.dart';
import '../../models/cards.dart';
import '../../models/match.dart';
import '../../models/progression.dart';
import 'shootout_event.dart';
import 'shootout_state.dart';

/// Probability that a penalty is scored. A keeper diving the wrong way is a
/// near-certain goal; on a correct guess the save chance scales with keeper
/// vs shooter rating, mirroring the goalChanceForDiff step-table style.
double shootoutGoalChance({
  required int shooterRating,
  required int keeperRating,
  required bool keeperGuessedRight,
}) {
  if (!keeperGuessedRight) return 0.95;
  final diff = shooterRating - keeperRating;
  if (diff > 15) return 0.45;
  if (diff > 5) return 0.35;
  if (diff > -5) return 0.25;
  if (diff > -15) return 0.15;
  return 0.08;
}

/// Kicks per side before sudden death (5 each, alternating: 10 total).
const int kShootoutKicks = 10;

class ShootoutBloc extends Bloc<ShootoutEvent, ShootoutState> {
  ShootoutBloc({
    required List<PlayerCard> playerShooters,
    required PlayerCard playerKeeper,
    required List<PlayerCard> cpuShooters,
    required PlayerCard cpuKeeper,
    required int cpuLevel,
    required String opponentName,
    Random? random,
  }) : _random = random ?? Random(),
       super(
         ShootoutState.initial(
           playerShooters: playerShooters,
           playerKeeper: playerKeeper,
           cpuShooters: cpuShooters,
           cpuKeeper: cpuKeeper,
           cpuLevel: cpuLevel,
           opponentName: opponentName,
         ),
       ) {
    on<ShootoutOpponentRevealCompleted>((_, emit) {
      if (state.stage != ShootoutStage.opponentReveal) return;
      emit(state.copyWith(stage: ShootoutStage.lineup));
    });
    on<ShootoutStarted>((_, emit) {
      if (state.stage != ShootoutStage.lineup) return;
      emit(state.copyWith(stage: ShootoutStage.choose));
    });
    on<ShootoutDirectionSelected>(
      (event, emit) => emit(state.copyWith(selectedDirection: event.direction)),
    );
    on<ShootoutKickConfirmed>(_onKickConfirmed);
    on<ShootoutNextKick>(
      (_, emit) => emit(
        state.copyWith(stage: ShootoutStage.choose, selectedDirection: null),
      ),
    );
    on<ShootoutSummaryShown>(
      (_, emit) => emit(state.copyWith(stage: ShootoutStage.summary)),
    );
  }

  final Random _random;

  void _onKickConfirmed(
    ShootoutKickConfirmed event,
    Emitter<ShootoutState> emit,
  ) {
    if (state.over || state.selectedDirection == null) return;
    final playerTaking = state.playerTaking;
    final playerDir = state.selectedDirection!;
    final aiDir = _cpuDirection(playerTaking: playerTaking);

    final shootDir = playerTaking ? playerDir : aiDir;
    final diveDir = playerTaking ? aiDir : playerDir;
    final shooter = state.currentShooter;
    final keeper = state.currentKeeper;
    final scored =
        _random.nextDouble() <
        shootoutGoalChance(
          shooterRating: shooter.rating,
          keeperRating: keeper.rating,
          keeperGuessedRight: shootDir == diveDir,
        );

    final kick = PenaltyKick(
      kickNumber: state.round + 1,
      byPlayer: playerTaking,
      shootDirection: shootDir,
      diveDirection: diveDir,
      scored: scored,
      shooter: shooter,
      keeper: keeper,
    );
    final kicks = [...state.kicks, kick];
    final playerScore = state.playerScore + (playerTaking && scored ? 1 : 0);
    final opponentScore =
        state.opponentScore + (!playerTaking && scored ? 1 : 0);

    var over = false;
    var suddenDeath = state.suddenDeath;
    String? winner = state.winner;

    if (!suddenDeath) {
      if (_earlyOut(kicks, playerScore, opponentScore)) {
        over = true;
        winner = playerScore > opponentScore ? 'player' : 'opponent';
      } else if (kicks.length >= kShootoutKicks) {
        if (playerScore != opponentScore) {
          over = true;
          winner = playerScore > opponentScore ? 'player' : 'opponent';
        } else {
          suddenDeath = true; // tied after 5 each > sudden death
        }
      }
    } else {
      // In sudden death, check each completed pair (2 kicks)
      final sdDone = kicks.length - kShootoutKicks;
      if (sdDone > 0 && sdDone.isEven) {
        final pair = kicks.sublist(kicks.length - 2);
        final playerGoal = pair.any((k) => k.byPlayer && k.scored);
        final opponentGoal = pair.any((k) => !k.byPlayer && k.scored);
        if (playerGoal != opponentGoal) {
          over = true;
          winner = playerGoal ? 'player' : 'opponent';
        }
      }
    }

    emit(
      state.copyWith(
        stage: ShootoutStage.result,
        kicks: kicks,
        playerScore: playerScore,
        opponentScore: opponentScore,
        round: state.round + 1,
        over: over,
        winner: winner,
        selectedDirection: null,
        suddenDeath: suddenDeath,
      ),
    );
  }

  bool _earlyOut(List<PenaltyKick> kicks, int playerScore, int opponentScore) {
    final done = kicks.length;
    if (done >= kShootoutKicks) return false;
    var playerLeft = 0;
    var opponentLeft = 0;
    for (var i = done; i < kShootoutKicks; i++) {
      if (i.isEven) {
        playerLeft++;
      } else {
        opponentLeft++;
      }
    }
    return playerScore > opponentScore + opponentLeft ||
        opponentScore > playerScore + playerLeft;
  }

  /// The CPU's pick for the current kick. With probability scaled by level
  /// smartness it reads the player's habits this shootout; otherwise random.
  PenaltyDirection _cpuDirection({required bool playerTaking}) {
    final readChance = 0.25 + 0.35 * cpuSmartness(state.cpuLevel);
    if (_random.nextDouble() < readChance) {
      if (playerTaking) {
        // CPU keeper dives toward the player's most frequent shot so far.
        final habit = _mostFrequent(
          state.kicks.where((k) => k.byPlayer).map((k) => k.shootDirection),
        );
        if (habit != null) return habit;
      } else {
        // CPU shooter aims away from the player's most frequent dive.
        final habit = _mostFrequent(
          state.kicks.where((k) => !k.byPlayer).map((k) => k.diveDirection),
        );
        if (habit != null) {
          final options = PenaltyDirection.values
              .where((d) => d != habit)
              .toList();
          return options[_random.nextInt(options.length)];
        }
      }
    }
    return PenaltyDirection.values[_random.nextInt(3)];
  }

  /// Strictly most frequent direction, or null on no data / a tie.
  PenaltyDirection? _mostFrequent(Iterable<PenaltyDirection> dirs) {
    final counts = <PenaltyDirection, int>{};
    for (final dir in dirs) {
      counts[dir] = (counts[dir] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final best = counts.values.reduce(max);
    final leaders = counts.entries.where((e) => e.value == best).toList();
    return leaders.length == 1 ? leaders.first.key : null;
  }
}
