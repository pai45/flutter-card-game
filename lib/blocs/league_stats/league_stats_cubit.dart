import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/league_stat_leaders.dart';
import '../../services/cricket_league_stats_package_service.dart';
import '../../services/espn_league_stats_service.dart';
import '../../services/espn_score_service.dart';
import '../../services/league_stats_package_service.dart';
import '../../services/nba_league_stats_package_service.dart';
import 'league_stats_state.dart';

/// Route-scoped controller for every season-aware league-hub surface.
class LeagueStatsCubit extends Cubit<LeagueStatsState> {
  LeagueStatsCubit(
    this._leagueId, {
    this.leagueName,
    this.shortCode,
    EspnLeagueStatsService service = const EspnLeagueStatsService(),
    EspnScoreService? scoreService,
  }) : _service = service,
       _scoreService = scoreService ?? EspnScoreService(),
       super(const LeagueStatsState());

  final String _leagueId;
  final String? leagueName;
  final String? shortCode;
  final EspnLeagueStatsService _service;
  final EspnScoreService _scoreService;
  int _requestGeneration = 0;

  Future<void> load() async {
    final generation = ++_requestGeneration;
    emit(state.copyWith(status: LeagueStatsStatus.loading));

    // Cricket first, and terminally. ESPN's core API rejects the sport, so
    // there is no live leaders or team-statistics feed to layer over the
    // package and no season archive to offer — everything the IPL hub shows is
    // aggregated offline from the season's match summaries.
    final cricket = await CricketLeagueStatsPackageService.snapshotFor(
      _leagueId,
      leagueName: leagueName,
      shortCode: shortCode,
    );
    if (!_isCurrent(generation)) return;
    if (cricket != null && !cricket.isEmpty) {
      emit(
        state.copyWith(
          status: LeagueStatsStatus.loaded,
          snapshot: cricket,
          categoryIndex: 0,
          groupIndex: 0,
          statGroupIndex: 0,
          statIndex: 0,
        ),
      );
      // No season list is emitted, so the archive picker stays hidden.
      // `archiveUnavailable` is NOT set: that flag replaces the whole table
      // with a "use mobile" empty state, which is not what "this sport has no
      // archive" means.
      return;
    }

    // Basketball next, and also terminally. Every ESPN feed the football hub
    // uses does answer for the NBA — that is why the package is a straight
    // extraction rather than cricket's re-derivation — but the live service
    // itself is soccer-shaped: `EspnLeagueStatsService` builds
    // `sports/soccer/...` URLs, so there is nothing to layer over the package
    // until that service learns a second sport.
    final basketball = await NbaLeagueStatsPackageService.snapshotFor(
      _leagueId,
      leagueName: leagueName,
      shortCode: shortCode,
    );
    if (!_isCurrent(generation)) return;
    if (basketball != null && !basketball.isEmpty) {
      emit(
        state.copyWith(
          status: LeagueStatsStatus.loaded,
          snapshot: basketball,
          categoryIndex: 0,
          groupIndex: 0,
          statGroupIndex: 0,
          statIndex: 0,
        ),
      );
      // As with cricket: no season list is emitted, so the archive picker
      // stays hidden, and `archiveUnavailable` is deliberately NOT set —
      // that flag replaces the table with a "use mobile" empty state.
      return;
    }

    final bundled = await LeagueStatsPackageService.snapshotFor(
      _leagueId,
      leagueName: leagueName,
      shortCode: shortCode,
    );
    var seasons = await LeagueStatsPackageService.seasonsFor(
      _leagueId,
      leagueName: leagueName,
      shortCode: shortCode,
    );
    if (!_isCurrent(generation)) return;
    if (seasons.isEmpty && !kIsWeb) {
      seasons = await _service.fetchAvailableSeasons(_leagueId);
      if (!_isCurrent(generation)) return;
    }

    final initialYear =
        bundled?.seasonYear ??
        _currentSeasonYear(seasons) ??
        DateTime.now().year;
    emit(
      state.copyWith(
        seasons: seasons,
        selectedSeasonYear: initialYear,
        archiveUnavailable: false,
      ),
    );

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
      if (!kIsWeb) unawaited(_refreshSeasonCatalog(generation));
      unawaited(_refreshLive(generation, initialYear));
      return;
    }
    await _loadSeason(initialYear, generation);
  }

  Future<void> selectSeason(int year) async {
    if (year == state.selectedSeasonYear) return;
    final generation = ++_requestGeneration;
    final webArchive = kIsWeb && !_isCurrentSeasonYear(year, state.seasons);
    emit(
      state.copyWith(
        status: LeagueStatsStatus.loading,
        snapshot: LeagueStatsSnapshot.empty,
        selectedSeasonYear: year,
        seasonFixtures: const [],
        fixturesStatus: webArchive
            ? LeagueFixturesStatus.unavailable
            : LeagueFixturesStatus.idle,
        archiveUnavailable: webArchive,
        categoryIndex: 0,
        groupIndex: 0,
        statGroupIndex: 0,
        statIndex: 0,
        resolvingCategory: false,
        refreshingLive: false,
        loadingTeamStats: false,
      ),
    );
    if (webArchive) {
      emit(state.copyWith(status: LeagueStatsStatus.error));
      return;
    }
    await _loadSeason(year, generation);
  }

  Future<void> _loadSeason(int year, int generation) async {
    final bundled = await LeagueStatsPackageService.snapshotFor(
      _leagueId,
      leagueName: leagueName,
      shortCode: shortCode,
      seasonYear: year,
    );
    if (!_isCurrent(generation, year)) return;
    if (bundled != null && !bundled.isEmpty) {
      emit(
        state.copyWith(
          status: LeagueStatsStatus.loaded,
          snapshot: bundled,
          archiveUnavailable: false,
        ),
      );
      unawaited(_refreshLive(generation, year));
      return;
    }

    try {
      final snapshot = await _service.fetchSnapshot(
        _leagueId,
        seasonYear: year,
      );
      if (!_isCurrent(generation, year)) return;
      emit(
        state.copyWith(
          status: snapshot.isEmpty
              ? LeagueStatsStatus.error
              : LeagueStatsStatus.loaded,
          snapshot: snapshot,
        ),
      );
      if (!snapshot.isEmpty) await _resolveSelected();
    } catch (error) {
      debugPrint('LeagueStatsCubit: failed to load $_leagueId/$year: $error');
      if (_isCurrent(generation, year)) {
        emit(state.copyWith(status: LeagueStatsStatus.error));
      }
    }
  }

  Future<void> _refreshLive(int generation, int seasonYear) async {
    if (!EspnLeagueStatsService.supports(_leagueId)) return;
    emit(state.copyWith(refreshingLive: true));
    try {
      final live = await _service.fetchSnapshot(
        _leagueId,
        seasonYear: seasonYear,
      );
      if (!_isCurrent(generation, seasonYear)) return;
      emit(
        state.copyWith(
          snapshot: state.snapshot.mergedWith(live),
          refreshingLive: false,
        ),
      );
      await _resolveSelected();
    } catch (error) {
      debugPrint(
        'LeagueStatsCubit: live refresh failed for $_leagueId/$seasonYear: $error',
      );
      if (_isCurrent(generation, seasonYear)) {
        emit(state.copyWith(refreshingLive: false));
      }
    }
  }

  Future<void> ensureTeamStats() async {
    if (state.snapshot.hasTeamStats || state.loadingTeamStats) return;
    final seasonYear = state.selectedSeasonYear;
    if (seasonYear == null || state.archiveUnavailable) return;
    if (!EspnLeagueStatsService.supports(_leagueId)) return;
    final generation = _requestGeneration;
    emit(state.copyWith(loadingTeamStats: true));
    try {
      final stats = await _service.fetchTeamStats(
        _leagueId,
        seasonYear: seasonYear,
      );
      if (!_isCurrent(generation, seasonYear)) return;
      emit(
        state.copyWith(
          snapshot: state.snapshot.withTeamStats(stats),
          loadingTeamStats: false,
        ),
      );
    } catch (error) {
      debugPrint('LeagueStatsCubit: team stats failed for $_leagueId: $error');
      if (_isCurrent(generation, seasonYear)) {
        emit(state.copyWith(loadingTeamStats: false));
      }
    }
  }

  Future<void> ensureSeasonFixtures() async {
    if (state.fixturesStatus == LeagueFixturesStatus.loading ||
        state.fixturesStatus == LeagueFixturesStatus.loaded ||
        state.fixturesStatus == LeagueFixturesStatus.unavailable) {
      return;
    }
    final seasonYear = state.selectedSeasonYear;
    if (seasonYear == null) return;
    if (state.archiveUnavailable) {
      emit(state.copyWith(fixturesStatus: LeagueFixturesStatus.unavailable));
      return;
    }
    final generation = _requestGeneration;
    emit(state.copyWith(fixturesStatus: LeagueFixturesStatus.loading));
    try {
      final fixtures = await _scoreService.fetchFootballSeasonMatches(
        _leagueId,
        seasonYear,
      );
      if (!_isCurrent(generation, seasonYear)) return;
      emit(
        state.copyWith(
          fixturesStatus: LeagueFixturesStatus.loaded,
          seasonFixtures: fixtures,
        ),
      );
    } catch (error) {
      debugPrint('LeagueStatsCubit: season fixtures failed: $error');
      if (_isCurrent(generation, seasonYear)) {
        emit(state.copyWith(fixturesStatus: LeagueFixturesStatus.error));
      }
    }
  }

  void selectGroup(int index) {
    if (index != state.groupIndex) emit(state.copyWith(groupIndex: index));
  }

  void selectStatGroup(int index) {
    if (index != state.statGroupIndex) {
      emit(state.copyWith(statGroupIndex: index, statIndex: 0));
    }
  }

  void selectStat(int index) {
    if (index != state.statIndex) emit(state.copyWith(statIndex: index));
  }

  Future<void> selectCategory(int index) async {
    if (index == state.categoryIndex) return;
    emit(state.copyWith(categoryIndex: index));
    await _resolveSelected();
  }

  Future<void> _resolveSelected() async {
    final category = state.selectedCategory;
    if (category == null || category.isResolved) return;
    final index = state.categoryIndex;
    final seasonYear = state.selectedSeasonYear;
    final generation = _requestGeneration;
    emit(state.copyWith(resolvingCategory: true));
    try {
      final resolved = await _service.resolveCategory(
        _leagueId,
        category,
        seasonYear: seasonYear,
      );
      if (!_isCurrent(generation, seasonYear)) return;
      emit(
        state.copyWith(
          snapshot: state.snapshot.withCategory(index, resolved),
          resolvingCategory: false,
        ),
      );
    } catch (error) {
      debugPrint('LeagueStatsCubit: failed to resolve ${category.key}: $error');
      if (_isCurrent(generation, seasonYear)) {
        emit(state.copyWith(resolvingCategory: false));
      }
    }
  }

  Future<void> _refreshSeasonCatalog(int generation) async {
    final live = await _service.fetchAvailableSeasons(_leagueId);
    if (!_isCurrent(generation) || live.isEmpty) return;
    emit(state.copyWith(seasons: live));
  }

  int? _currentSeasonYear(List<LeagueSeasonOption> seasons) {
    for (final season in seasons) {
      if (season.isCurrent) return season.year;
    }
    return seasons.isEmpty ? null : seasons.first.year;
  }

  bool _isCurrentSeasonYear(int year, List<LeagueSeasonOption> seasons) =>
      _currentSeasonYear(seasons) == year;

  bool _isCurrent(int generation, [int? seasonYear]) =>
      !isClosed &&
      generation == _requestGeneration &&
      (seasonYear == null || state.selectedSeasonYear == seasonYear);
}
