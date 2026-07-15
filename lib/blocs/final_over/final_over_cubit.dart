import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/final_over.dart';
import '../../services/secure_storage_service.dart';
import 'final_over_state.dart';

/// Owns the Final Over *session*: lobby selections, the coarse phase machine,
/// and career stats.
///
/// It deliberately knows nothing about balls, runs or wickets — that is the
/// engine's job, and the renderer's. If this cubit ever grows a `score` field,
/// something has gone wrong.
class FinalOverCubit extends Cubit<FinalOverState> {
  FinalOverCubit(this._storage) : super(const FinalOverState());

  final SecureGameStorage _storage;
  final Random _random = Random();

  Future<void> load() async {
    final stats = await _storage.loadFinalOverStats();
    emit(state.copyWith(stats: stats, loaded: true));
  }

  void selectTier(FinalOverTier tier) {
    if (tier == state.stats.tier) return;
    final stats = state.stats.copyWith(tier: tier);
    emit(state.copyWith(stats: stats));
    _storage.saveFinalOverStats(stats);
  }

  void selectKit(String kitId) {
    if (kitId == state.stats.kitId) return;
    final stats = state.stats.copyWith(kitId: kitId);
    emit(state.copyWith(stats: stats));
    _storage.saveFinalOverStats(stats);
  }

  /// Builds a chase. The seed is what makes a match reproducible — the engine
  /// derives the delivery sequence from it, so the same seed is the same over.
  FinalOverMatchConfig buildMatch() {
    final tier = state.stats.tier;
    final targets = tier.targets;
    final config = FinalOverMatchConfig(
      matchId: 'finalover-${DateTime.now().microsecondsSinceEpoch}',
      seed: _random.nextInt(1 << 31),
      tier: tier,
      target: targets[_random.nextInt(targets.length)],
      kitId: state.stats.kitId,
      showHints: !state.stats.hintsSeen,
    );
    emit(state.copyWith(
      config: config,
      phase: FinalOverPhase.intro,
      clearSummary: true,
    ));
    return config;
  }

  void beginPlay() {
    if (state.phase != FinalOverPhase.intro) return;
    emit(state.copyWith(phase: FinalOverPhase.playing));
  }

  void markHintsSeen() {
    if (state.stats.hintsSeen) return;
    final stats = state.stats.copyWith(hintsSeen: true);
    emit(state.copyWith(stats: stats));
    _storage.saveFinalOverStats(stats);
  }

  /// The engine has ended the match. Folds the result into career stats and
  /// parks in [FinalOverPhase.finished] so the screen can land the sound and
  /// the haptic before the cinematic starts.
  Future<void> onMatchEnded(FinalOverMatchSummary summary) async {
    final stats = state.stats.merge(summary);
    emit(state.copyWith(
      phase: FinalOverPhase.finished,
      summary: summary,
      stats: stats,
    ));
    await _storage.saveFinalOverStats(stats);
  }

  void showResult() {
    if (state.phase != FinalOverPhase.finished) return;
    emit(state.copyWith(phase: FinalOverPhase.result));
  }

  /// Walking out mid-chase. No stats, no XP — the match never happened.
  void abandonMatch() {
    if (state.phase == FinalOverPhase.idle) return;
    emit(state.copyWith(phase: FinalOverPhase.idle, clearSummary: true));
  }

  void backToLobby() =>
      emit(state.copyWith(phase: FinalOverPhase.idle, clearSummary: true));
}
