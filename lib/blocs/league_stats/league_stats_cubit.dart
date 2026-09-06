import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../services/espn_league_stats_service.dart';
import '../../services/league_stats_package_service.dart';
import 'league_stats_state.dart';

/// Owns the league hub's data — the grouped standings table, the player stat
/// leaderboards, and the per-team season statistics behind the STATS tab.
/// Scoped to the hub route rather than the app-wide [PredictionCubit] so
/// opening one league never triggers a league-wide sweep.
///
/// Loading is **bundled-first**: the packaged snapshot
/// (`assets/data/football-league-stats.json`) renders immediately, then the
/// live ESPN feed is layered over it in the background. The player never waits
/// on the network to see a filled table, and a failed request degrades to the
/// package rather than to an empty state.
class LeagueStatsCubit extends Cubit<LeagueStatsState> {
  LeagueStatsCubit(
    this._leagueId, {
    this.leagueName,
    this.shortCode,
    EspnLeagueStatsService service = const EspnLeagueStatsService(),
  }) : _service = service,
       super(const LeagueStatsState());

  final String _leagueId;

  /// Passed through to the package lookup so a league discovered at runtime
  /// under an unexpected id still resolves by name or short code.
  final String? leagueName;
  final String? shortCode;

  final EspnLeagueStatsService _service;

  Future<void> load() async {
    emit(state.copyWith(status: LeagueStatsStatus.loading));

    final bundled = await LeagueStatsPackageService.snapshotFor(
      _leagueId,
      leagueName: leagueName,
      shortCode: shortCode,
    );
    if (isClosed) return;

    if (bundled != null && !bundled.isEmpty) {
      emit(
        state.copyWith(
          status: LeagueStatsStatus.loaded,
          snapshot: bundled,
          categoryIndex: 0,
          groupIndex: 0,
          statGroupIndex: 0,
          statIndex: 0,
        ),
      );
      // The package already answers every tab, so the live pass is a quiet
      // freshness top-up rather than the thing the hub is waiting on.
      unawaited(_refreshLive());
      return;
    }

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

  /// Layers the live feed over the bundled snapshot already on screen. Failure
  /// is silent by design — the player is looking at a complete hub either way.
  Future<void> _refreshLive() async {
    if (!EspnLeagueStatsService.supports(_leagueId)) return;
    emit(state.copyWith(refreshingLive: true));
    try {
      final live = await _service.fetchSnapshot(_leagueId);
      if (isClosed) return;
      emit(
        state.copyWith(
          snapshot: state.snapshot.mergedWith(live),
          refreshingLive: false,
        ),
      );
      await _resolveSelected();
    } catch (e) {
      debugPrint('LeagueStatsCubit: live refresh failed for $_leagueId: $e');
      if (isClosed) return;
      emit(state.copyWith(refreshingLive: false));
    }
  }

  /// Pulls per-club season statistics for the STATS tab. Called the first time
  /// that tab is opened rather than on hub load, because it costs one request
  /// per club — the same lazy contract [_resolveSelected] uses for athletes.
  ///
  /// No-ops when the bundled package already supplied them, so the common case
  /// is free and this only pays off for leagues outside the package (or when
  /// the package failed to load).
  Future<void> ensureTeamStats() async {
    if (state.snapshot.hasTeamStats || state.loadingTeamStats) return;
    if (!EspnLeagueStatsService.supports(_leagueId)) return;

    emit(state.copyWith(loadingTeamStats: true));
    try {
      final stats = await _service.fetchTeamStats(_leagueId);
      if (isClosed) return;
      emit(
        state.copyWith(
          snapshot: state.snapshot.withTeamStats(stats),
          loadingTeamStats: false,
        ),
      );
    } catch (e) {
      debugPrint('LeagueStatsCubit: team stats failed for $_leagueId: $e');
      if (isClosed) return;
      emit(state.copyWith(loadingTeamStats: false));
    }
  }

  void selectGroup(int index) {
    if (index == state.groupIndex) return;
    emit(state.copyWith(groupIndex: index));
  }

  /// Switching STATS category resets to that category's first board, so the
  /// player never lands on a stale index from the previous group.
  void selectStatGroup(int index) {
    if (index == state.statGroupIndex) return;
    emit(state.copyWith(statGroupIndex: index, statIndex: 0));
  }

  void selectStat(int index) {
    if (index == state.statIndex) return;
    emit(state.copyWith(statIndex: index));
  }

  Future<void> selectCategory(int index) async {
    if (index == state.categoryIndex) return;
    emit(state.copyWith(categoryIndex: index));
    await _resolveSelected();
  }

  /// Fetches athlete names for the board on screen. Boards sourced from the
  /// bundled package arrive fully named, so this is a no-op for them.
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
