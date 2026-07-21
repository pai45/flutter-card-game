import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/grand_prix_circuits.dart';
import '../../data/grand_prix_liveries.dart' as gp_liveries;
import '../../games/grand_prix/grand_prix_engine.dart';
import '../../models/grand_prix.dart';
import '../../models/progression.dart';
import '../../services/secure_storage_service.dart';
import 'grand_prix_state.dart';

/// Drives a Grand Prix Dash session: lobby selections, the five-lights start
/// sequence (with jump-start detection and launch grading), the coarse race
/// beats reported up by the Flame game, and settlement + stats persistence.
///
/// The 60fps simulation never touches this cubit — the Flame game owns the
/// [RaceField] and only calls back on position changes, overtakes, and the
/// finish. Rewards are dispatched by the race screen (GameBloc lives in the
/// widget tree), mirroring the Football Chess pattern.
class GrandPrixCubit extends Cubit<GrandPrixState> {
  GrandPrixCubit(this._storage, {Random? random})
    : _random = random ?? Random(),
      super(const GrandPrixState());

  final SecureGameStorage _storage;
  final Random _random;
  final List<Timer> _lightTimers = [];
  DateTime? _lightsOutAt;

  static const _lightIntervalMs = 1000;
  static const _minHoldMs = 200;
  static const _maxHoldMs = 1500;

  /// No launch tap this long after lights-out auto-grades a Slow start.
  static const _launchTimeout = Duration(seconds: 2);

  Future<void> load() async {
    final stats = await _storage.loadGrandPrixStats();
    emit(state.copyWith(loading: false, stats: stats));
  }

  /// Clamps an equipped livery the player no longer owns back to the free
  /// default.
  void ensureEquippedLiveryOwned(Iterable<String> ownedLiveryIds) {
    final clamped = gp_liveries.ensureEquippedLiveryOwned(
      ownedLiveryIds,
      state.stats.lastLivery,
    );
    if (clamped == state.stats.lastLivery) return;
    _persistStats(state.stats.copyWith(lastLivery: clamped));
  }

  // -- lobby ----------------------------------------------------------------

  void selectCircuit(GrandPrixCircuitId id) {
    if (id == state.stats.lastCircuit) return;
    _persistStats(state.stats.copyWith(lastCircuit: id));
  }

  void selectLivery(
    GrandPrixLivery livery, {
    required Iterable<String> ownedLiveryIds,
  }) {
    if (!gp_liveries.isGrandPrixLiveryOwned(livery.name, ownedLiveryIds)) return;
    if (livery == state.stats.lastLivery) return;
    _persistStats(state.stats.copyWith(lastLivery: livery));
  }

  void selectLaps(int laps) {
    if (laps == state.stats.lastLaps) return;
    _persistStats(state.stats.copyWith(lastLaps: laps));
  }

  void _persistStats(GrandPrixStats stats) {
    emit(state.copyWith(stats: stats));
    unawaited(_storage.saveGrandPrixStats(stats));
  }

  // -- race lifecycle -------------------------------------------------------

  /// Seeds a fresh race from the current selections. The [RaceSetup] is the
  /// single source the Flame game rebuilds the whole field from.
  void buildRace(int playerLevel) {
    _cancelTimers();
    final setup = RaceSetup(
      circuit: grandPrixCircuit(state.stats.lastCircuit),
      playerLivery: state.stats.lastLivery,
      playerLevel: playerLevel,
      startPosition: 8 + _random.nextInt(9), // P8–P16
      seed: _random.nextInt(1 << 31),
      laps: state.stats.lastLaps,
    );
    emit(
      state.copyWith(
        phase: GrandPrixPhase.grid,
        setup: setup,
        result: null,
        launchGrade: null,
        lightsOn: 0,
        lightsOut: false,
        playerPosition: setup.startPosition,
        lastOvertake: null,
      ),
    );
  }

  /// Runs the five-lights sequence. With [reducedMotion] the reaction test is
  /// skipped entirely and the car gets a fixed average launch (spec).
  void beginLights({required bool reducedMotion}) {
    if (state.phase != GrandPrixPhase.grid) return;
    _cancelTimers();
    if (reducedMotion) {
      emit(
        state.copyWith(
          phase: GrandPrixPhase.racing,
          launchGrade: LaunchGrade.good,
          lightsOut: true,
        ),
      );
      return;
    }
    emit(
      state.copyWith(
        phase: GrandPrixPhase.lights,
        lightsOn: 0,
        lightsOut: false,
      ),
    );
    for (var lamp = 1; lamp <= 5; lamp++) {
      final lit = lamp;
      _lightTimers.add(
        Timer(Duration(milliseconds: _lightIntervalMs * lamp), () {
          if (state.phase == GrandPrixPhase.lights) {
            emit(state.copyWith(lightsOn: lit));
          }
        }),
      );
    }
    final outMs =
        _lightIntervalMs * 5 +
        _minHoldMs +
        _random.nextInt(_maxHoldMs - _minHoldMs + 1);
    _lightTimers.add(
      Timer(Duration(milliseconds: outMs), () {
        if (state.phase != GrandPrixPhase.lights) return;
        _lightsOutAt = DateTime.now();
        emit(state.copyWith(lightsOn: 0, lightsOut: true));
        _lightTimers.add(
          Timer(_launchTimeout, () {
            if (state.phase == GrandPrixPhase.lights) {
              _goRacing(LaunchGrade.slow);
            }
          }),
        );
      }),
    );
  }

  /// First Accelerate press during the start sequence. Before lights-out this
  /// is a jump start; after, the reaction time grades the launch.
  void registerThrottleTap() {
    if (state.phase != GrandPrixPhase.lights) return;
    if (!state.lightsOut) {
      _goRacing(LaunchGrade.jump);
      return;
    }
    final outAt = _lightsOutAt;
    final reaction = outAt == null
        ? Duration.zero
        : DateTime.now().difference(outAt);
    _goRacing(gradeLaunch(reaction));
  }

  void _goRacing(LaunchGrade grade) {
    _cancelTimers();
    emit(
      state.copyWith(
        phase: GrandPrixPhase.racing,
        launchGrade: grade,
        lightsOn: 0,
        lightsOut: true,
      ),
    );
  }

  // -- callbacks from the Flame game (coarse, on-change only) ----------------

  void onPlayerPositionChanged(int position) {
    if (state.phase != GrandPrixPhase.racing) return;
    if (position == state.playerPosition) return;
    emit(state.copyWith(playerPosition: position));
  }

  void onOvertake(OvertakeEvent event) {
    if (state.phase != GrandPrixPhase.racing) return;
    emit(
      state.copyWith(lastOvertake: event, eventTick: state.eventTick + 1),
    );
  }

  Future<void> onRaceFinished(PlayerRaceOutcome outcome) async {
    final setup = state.setup;
    if (setup == null || state.phase != GrandPrixPhase.racing) return;
    final circuitId = setup.circuit.id;
    final laps = setup.laps;
    // A DNF sets no lap and can never be a personal best.
    final personalBest = !outcome.dnf &&
        state.stats.isPersonalBest(circuitId, outcome.lapTimeMs, laps: laps);
    final result = GrandPrixResult(
      position: outcome.position,
      fieldSize: kFieldSize,
      startPosition: setup.startPosition,
      lapTimeMs: outcome.lapTimeMs,
      personalBest: personalBest,
      launchGrade: state.launchGrade ?? LaunchGrade.slow,
      circuit: circuitId,
      xp: calculateGrandPrixXP(
        outcome.position,
        personalBest: personalBest,
        laps: laps,
      ),
      laps: laps,
      bestOvertakeName: outcome.bestOvertakeName,
      retired: outcome.dnf,
    );
    final stats = state.stats.recordResult(
      position: outcome.position,
      lapTimeMs: outcome.lapTimeMs,
      circuit: circuitId,
      laps: laps,
    );
    emit(
      state.copyWith(
        phase: GrandPrixPhase.finished,
        result: result,
        stats: stats,
        playerPosition: outcome.position,
      ),
    );
    await _storage.saveGrandPrixStats(stats);
  }

  /// The race screen calls this after its finish beat to raise the overlay.
  void showResult() {
    if (state.phase != GrandPrixPhase.finished) return;
    emit(state.copyWith(phase: GrandPrixPhase.result));
  }

  /// Leaving mid-race discards the attempt — no stats, no reward (spec).
  void abandonRace() {
    _cancelTimers();
    emit(
      state.copyWith(
        phase: GrandPrixPhase.idle,
        setup: null,
        result: null,
        launchGrade: null,
        lightsOn: 0,
        lightsOut: false,
        lastOvertake: null,
      ),
    );
  }

  void _cancelTimers() {
    for (final timer in _lightTimers) {
      timer.cancel();
    }
    _lightTimers.clear();
    _lightsOutAt = null;
  }

  @override
  Future<void> close() {
    _cancelTimers();
    return super.close();
  }
}
