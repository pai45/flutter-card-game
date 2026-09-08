import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/sport_match.dart';
import '../../models/team_hub.dart';
import '../../services/team_hub_repository.dart';
import 'team_hub_state.dart';

/// Route-scoped package-first controller for a single club and season.
class TeamHubCubit extends Cubit<TeamHubState> {
  TeamHubCubit({
    required TeamHubRepository repository,
    required this.leagueId,
    required this.teamId,
    required this.sport,
    required this.seasonYear,
    required this.seasonLabel,
    this.seedFixtures = const [],
  }) : _repository = repository,
       super(const TeamHubState());

  final TeamHubRepository _repository;
  final String leagueId;
  final String teamId;
  final Sport sport;
  final int seasonYear;
  final String seasonLabel;
  final List<SportMatch> seedFixtures;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    emit(const TeamHubState());
    try {
      final bundled = await _repository.loadBundled(
        leagueId: leagueId,
        teamId: teamId,
        sport: sport,
        seasonYear: seasonYear,
        seasonLabel: seasonLabel,
      );
      if (!_current(generation)) return;
      final seeded = bundled.mergedWith(
        TeamHubData(
          leagueId: leagueId,
          teamId: teamId,
          seasonYear: seasonYear,
          seasonLabel: seasonLabel,
          fixtures: _teamFixtures(seedFixtures),
        ),
      );
      emit(TeamHubState(status: TeamHubStatus.loaded, data: seeded));
      await refresh();
    } catch (error) {
      debugPrint('TeamHubCubit: package load failed: $error');
      if (!_current(generation)) return;
      final fallback = TeamHubData(
        leagueId: leagueId,
        teamId: teamId,
        seasonYear: seasonYear,
        seasonLabel: seasonLabel,
        fixtures: _teamFixtures(seedFixtures),
      );
      emit(
        TeamHubState(
          status: fallback.fixtures.isEmpty
              ? TeamHubStatus.error
              : TeamHubStatus.loaded,
          data: fallback,
          refreshFailed: true,
        ),
      );
    }
  }

  Future<void> refresh() async {
    if (state.refreshing) return;
    final generation = _generation;
    emit(state.copyWith(refreshing: true, refreshFailed: false));
    try {
      final live = await _repository.loadLive(
        leagueId: leagueId,
        teamId: teamId,
        sport: sport,
        seasonYear: seasonYear,
        seasonLabel: seasonLabel,
      );
      if (!_current(generation)) return;
      emit(
        state.copyWith(
          status: TeamHubStatus.loaded,
          data: (state.data ?? live).mergedWith(live),
          refreshing: false,
        ),
      );
    } catch (error) {
      debugPrint('TeamHubCubit: live refresh failed: $error');
      if (_current(generation)) {
        emit(state.copyWith(refreshing: false, refreshFailed: true));
      }
    }
  }

  List<SportMatch> _teamFixtures(Iterable<SportMatch> fixtures) => fixtures
      .where((match) => match.home.id == teamId || match.away.id == teamId)
      .toList(growable: false);

  bool _current(int generation) => !isClosed && generation == _generation;
}
