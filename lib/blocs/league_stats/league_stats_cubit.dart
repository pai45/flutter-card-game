import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/espn_league_stats_service.dart';
import 'league_stats_state.dart';

/// Owns the league hub's live ESPN data — the grouped standings table and the
/// stat leaderboards. Scoped to the hub route rather than the app-wide
/// [PredictionCubit] so opening one league never triggers a league-wide sweep,
/// and the shared prediction repository contract stays untouched.
class LeagueStatsCubit extends Cubit<LeagueStatsState> {
  LeagueStatsCubit(
    this._leagueId, {
    EspnLeagueStatsService service = const EspnLeagueStatsService(),
  }) : _service = service,
       super(const LeagueStatsState());

  final String _leagueId;
  final EspnLeagueStatsService _service;

  Future<void> load() async {
    emit(state.copyWith(status: LeagueStatsStatus.loading));
    try {
      final snapshot = await _service.fetchSnapshot(_leagueId);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: LeagueStatsStatus.loaded,
          snapshot: snapshot,
          categoryIndex: 0,
          groupIndex: 0,
        ),
      );
      await _resolveSelected();
    } catch (e) {
      debugPrint('LeagueStatsCubit: failed to load $_leagueId: $e');
      if (isClosed) return;
      emit(state.copyWith(status: LeagueStatsStatus.error));
    }
  }

  void selectGroup(int index) {
    if (index == state.groupIndex) return;
    emit(state.copyWith(groupIndex: index));
  }

  Future<void> selectCategory(int index) async {
    if (index == state.categoryIndex) return;
    emit(state.copyWith(categoryIndex: index));
    await _resolveSelected();
  }

  /// Fetches athlete names for the board on screen. Goals and assists arrive
  /// pre-resolved, so this is a no-op for the two default tabs.
  Future<void> _resolveSelected() async {
    final category = state.selectedCategory;
    if (category == null || category.isResolved) return;

    final index = state.categoryIndex;
    emit(state.copyWith(resolvingCategory: true));
    try {
      final resolved = await _service.resolveCategory(_leagueId, category);
      if (isClosed) return;
      // The player may have moved on while the request was in flight; only the
      // board they left behind gets patched, never the selection itself.
      emit(
        state.copyWith(
          snapshot: state.snapshot.withCategory(index, resolved),
          resolvingCategory: false,
        ),
      );
    } catch (e) {
      debugPrint('LeagueStatsCubit: failed to resolve ${category.key}: $e');
      if (isClosed) return;
      emit(state.copyWith(resolvingCategory: false));
    }
  }
}
