import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/super_over.dart';
import '../../services/secure_storage_service.dart';
import 'super_over_event.dart';
import 'super_over_state.dart';

class SuperOverBloc extends Bloc<SuperOverEvent, SuperOverState> {
  SuperOverBloc(this._storage) : super(const SuperOverState()) {
    on<SuperOverStarted>(_onStarted);
    on<SuperOverPhaseChanged>(_onPhaseChanged);
    on<SuperOverInputArmed>(_onInputArmed);
    on<SuperOverSwingLocked>(_onSwingLocked);
    on<SuperOverShotResolved>(_onShotResolved);
    on<SuperOverDeliveryResolved>(_onDeliveryResolved);
    on<SuperOverNextBallRequested>(_onNextBallRequested);
    on<SuperOverReset>(_onReset);
    on<SuperOverJerseySelected>(_onJerseySelected);
  }

  final SecureGameStorage _storage;
  final Random _random = Random();

  /// OFF / V / LEG presets, covering the 9 fielders across the ground.
  static const List<List<int>> _fieldPresets = [
    [2, 4, 3],
    [3, 3, 3],
    [4, 3, 2],
    [2, 3, 4],
    [3, 4, 2],
    [4, 2, 3],
    [1, 5, 3],
    [3, 5, 1],
  ];

  List<int> _rollField() =>
      List.of(_fieldPresets[_random.nextInt(_fieldPresets.length)]);

  DeliveryType _rollDelivery() =>
      DeliveryType.values[_random.nextInt(DeliveryType.values.length)];

  void _onStarted(SuperOverStarted event, Emitter<SuperOverState> emit) {
    final target = event.mode == SuperOverMode.chase
        ? SuperOverResolution.targetForLevel(event.playerLevel, random: _random)
        : 0;

    emit(
      SuperOverState(
        battingOrder: event.battingOrder,
        mode: event.mode,
        cpuTarget: target,
        strikerIndex: 0,
        nonStrikerIndex: 1,
        fieldSectors: _rollField(),
        upcomingDelivery: _rollDelivery(),
        phase: SuperOverPhase.targetReveal,
      ),
    );
  }

  void _onPhaseChanged(
    SuperOverPhaseChanged event,
    Emitter<SuperOverState> emit,
  ) {
    if (state.isOver) return;
    emit(
      state.copyWith(
        phase: event.phase,
        inputEnabled: event.phase == SuperOverPhase.ballInFlight
            ? state.inputEnabled
            : false,
      ),
    );
  }

  void _onInputArmed(SuperOverInputArmed event, Emitter<SuperOverState> emit) {
    if (state.isOver) return;
    emit(
      state.copyWith(inputEnabled: true, phase: SuperOverPhase.ballInFlight),
    );
  }

  void _onSwingLocked(
    SuperOverSwingLocked event,
    Emitter<SuperOverState> emit,
  ) {
    if (!state.canTap) return;
    emit(
      state.copyWith(
        swingLocked: true,
        inputEnabled: false,
        phase: SuperOverPhase.swinging,
      ),
    );
  }

  void _onShotResolved(
    SuperOverShotResolved event,
    Emitter<SuperOverState> emit,
  ) {
    if (state.isOver || state.lastOutcome != null) return;

    final strikerRating = state.striker?.rating ?? 75;
    final shot = SuperOverResolution.resolveShot(
      timingErrorMs: event.timingErrorMs,
      rating: strikerRating,
      delivery: state.upcomingDelivery,
      fieldSectors: state.fieldSectors,
      onFire: state.onFire,
      leftHanded: event.leftHanded,
      random: _random,
    );

    emit(
      _stateAfterOutcome(
        shot.outcome,
        timingErrorMs: shot.timingErrorMs,
        normalizedTimingError: shot.normalizedError,
        timingTier: shot.tier,
        shotSector: shot.sector,
        shotPower: shot.power,
      ),
    );
  }

  /// Kept for older tests and any direct callers. New gameplay should dispatch
  /// [SuperOverShotResolved] so timing feedback is available.
  void _onDeliveryResolved(
    SuperOverDeliveryResolved event,
    Emitter<SuperOverState> emit,
  ) {
    if (state.isOver || state.lastOutcome != null) return;
    emit(_stateAfterOutcome(event.outcome));
  }

  void _onNextBallRequested(
    SuperOverNextBallRequested event,
    Emitter<SuperOverState> emit,
  ) {
    if (state.isOver) return;
    emit(
      state.copyWith(
        phase: SuperOverPhase.ballSetup,
        inputEnabled: false,
        swingLocked: false,
        timingErrorMs: null,
        normalizedTimingError: null,
        timingTier: null,
        shotSector: null,
        shotPower: null,
        lastOutcome: null,
      ),
    );
  }

  SuperOverState _stateAfterOutcome(
    ShotOutcome outcome, {
    int? timingErrorMs,
    double? normalizedTimingError,
    TimingTier? timingTier,
    ShotSector? shotSector,
    int? shotPower,
  }) {
    final runs = SuperOverResolution.runsForOutcome(outcome);
    final isWicket =
        outcome == ShotOutcome.caught || outcome == ShotOutcome.bowled;

    final newScore = state.score + runs;
    final newWickets = state.wickets + (isWicket ? 1 : 0);
    final newBallsFaced = state.ballsFaced + 1;
    final newWagonWheel = List<ShotOutcome>.of(state.wagonWheel)..add(outcome);

    var newMomentum = state.momentum;
    var newOnFire = state.onFire;
    var newCombo = state.combo;

    if (newOnFire) {
      newOnFire = false;
      newMomentum = 0;
    } else if (runs >= 1 && !isWicket) {
      newMomentum++;
      if (newMomentum >= 3) {
        newOnFire = true;
        newMomentum = 0;
      }
    } else {
      newMomentum = 0;
    }

    newCombo = runs >= 1 && !isWicket ? newCombo + 1 : 0;

    var newStrikerIndex = state.strikerIndex;
    var newNonStrikerIndex = state.nonStrikerIndex;

    if (isWicket) {
      newMomentum = 0;
      newOnFire = false;
      newStrikerIndex = 2;
    }

    if (runs.isOdd) {
      final temp = newStrikerIndex;
      newStrikerIndex = newNonStrikerIndex;
      newNonStrikerIndex = temp;
    }

    var overEnded = newBallsFaced >= 6 || newWickets >= 2;
    bool? wonChase;
    if (state.mode == SuperOverMode.chase) {
      if (newScore > state.cpuTarget) {
        wonChase = true;
        overEnded = true;
      } else if (overEnded) {
        wonChase = false;
      }
    }

    final newState = state.copyWith(
      score: newScore,
      wickets: newWickets,
      ballsFaced: newBallsFaced,
      wagonWheel: newWagonWheel,
      momentum: newMomentum,
      onFire: newOnFire,
      combo: newCombo,
      strikerIndex: newStrikerIndex,
      nonStrikerIndex: newNonStrikerIndex,
      isOver: overEnded,
      wonChase: wonChase,
      phase: overEnded ? SuperOverPhase.result : SuperOverPhase.outcome,
      fieldSectors: _rollField(),
      upcomingDelivery: _rollDelivery(),
      inputEnabled: false,
      swingLocked: true,
      timingErrorMs: timingErrorMs,
      normalizedTimingError: normalizedTimingError,
      timingTier: timingTier,
      shotSector: shotSector,
      shotPower: shotPower,
      lastOutcome: outcome,
    );

    if (overEnded) {
      _persistStats(newState);
    }
    return newState;
  }

  void _onReset(SuperOverReset event, Emitter<SuperOverState> emit) {
    emit(const SuperOverState());
  }

  void _onJerseySelected(
    SuperOverJerseySelected event,
    Emitter<SuperOverState> emit,
  ) {
    emit(state.copyWith(jersey: event.jersey));
  }

  Future<void> _persistStats(SuperOverState finalState) async {
    final stats = await _storage.loadSuperOverStats();
    final newHighScore = max(stats.highScore, finalState.score);
    final newChaseWins =
        stats.chaseWins + (finalState.wonChase == true ? 1 : 0);
    final newChaseLosses =
        stats.chaseLosses + (finalState.wonChase == false ? 1 : 0);

    final sixes = finalState.wagonWheel
        .where((s) => s == ShotOutcome.six)
        .length;
    final newTotalSixes = stats.totalSixes + sixes;
    final newTotalRuns = stats.totalRuns + finalState.score;

    var newCurrentStreak = stats.currentStreak;
    var newBestStreak = stats.bestStreak;

    if (finalState.mode == SuperOverMode.chase) {
      if (finalState.wonChase == true) {
        newCurrentStreak++;
        newBestStreak = max(newBestStreak, newCurrentStreak);
      } else {
        newCurrentStreak = 0;
      }
    }

    await _storage.saveSuperOverStats(
      stats.copyWith(
        highScore: newHighScore,
        chaseWins: newChaseWins,
        chaseLosses: newChaseLosses,
        totalSixes: newTotalSixes,
        totalRuns: newTotalRuns,
        currentStreak: newCurrentStreak,
        bestStreak: newBestStreak,
      ),
    );
  }
}
