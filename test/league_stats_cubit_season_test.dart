import 'dart:async';

import 'package:card_game/blocs/league_stats/league_stats_cubit.dart';
import 'package:card_game/blocs/league_stats/league_stats_state.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/league_stat_leaders.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/services/espn_league_stats_service.dart';
import 'package:card_game/services/espn_score_service.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/screens/predictions/league_detail_screen.dart';
import 'package:card_game/screens/predictions/widgets/pick_market_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('season selection resets tabs and lazily loads fixtures once', () async {
    final score = _FakeScoreService();
    final cubit = LeagueStatsCubit(
      'eng.1',
      service: _FakeStatsService(),
      scoreService: score,
    );
    addTearDown(cubit.close);
    await cubit.load();
    cubit.selectGroup(2);
    cubit.selectStatGroup(2);
    cubit.selectStat(3);

    await cubit.selectSeason(2025);
    expect(cubit.state.selectedSeasonYear, 2025);
    expect(cubit.state.snapshot.seasonYear, 2025);
    expect(cubit.state.groupIndex, 0);
    expect(cubit.state.statGroupIndex, 0);
    expect(cubit.state.statIndex, 0);
    expect(cubit.state.fixturesStatus, LeagueFixturesStatus.idle);

    await cubit.ensureSeasonFixtures();
    await cubit.ensureSeasonFixtures();
    expect(score.calls, 1);
    expect(cubit.state.fixturesStatus, LeagueFixturesStatus.loaded);
    expect(cubit.state.seasonFixtures.single.id, '2025-final');
  });

  test('late historical response cannot replace a newer season', () async {
    final service = _FakeStatsService(delay2025: true);
    final cubit = LeagueStatsCubit('eng.1', service: service);
    addTearDown(cubit.close);
    await cubit.load();

    final stale = cubit.selectSeason(2025);
    await Future<void>.delayed(Duration.zero);
    await cubit.selectSeason(2024);
    service.complete2025();
    await stale;

    expect(cubit.state.selectedSeasonYear, 2024);
    expect(cubit.state.snapshot.seasonYear, 2024);
  });

  test('two calendar feeds deduplicate overlapping ESPN event ids', () {
    final firstCopy = _match(
      'shared',
      2025,
    ).copyWith(homeScore: '1', awayScore: '0');
    final richerCopy = _match(
      'shared',
      2025,
    ).copyWith(homeScore: '2', awayScore: '1');
    final other = _match('other', 2026);

    final merged = EspnScoreService.mergeFootballSeasonMatches([
      [firstCopy],
      [richerCopy, other],
    ]);

    expect(merged.map((match) => match.id), ['shared', 'other']);
    expect(merged.first.homeScore, '2');
  });

  testWidgets('historical PICKS exposes results without a trade action', (
    tester,
  ) async {
    final stats = _SeededLeagueStatsCubit()
      ..seed(
        LeagueStatsState(
          status: LeagueStatsStatus.loaded,
          snapshot: _snapshot(2025),
          seasons: const [
            LeagueSeasonOption(year: 2026, label: '2026-27', isCurrent: true),
            LeagueSeasonOption(year: 2025, label: '2025-26'),
          ],
          selectedSeasonYear: 2025,
          seasonFixtures: [_match('2025-final', 2025)],
          fixturesStatus: LeagueFixturesStatus.loaded,
        ),
      );
    final storage = SecureGameStorage();
    final prediction = PredictionCubit(MockPredictionRepository(), storage);
    final picks = PicksCubit(MockPickRepository(), storage);
    addTearDown(stats.close);
    addTearDown(prediction.close);
    addTearDown(picks.close);
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<LeagueStatsCubit>.value(value: stats),
          BlocProvider.value(value: prediction),
          BlocProvider.value(value: picks),
        ],
        child: const MaterialApp(home: LeagueDetailScreen(league: _league)),
      ),
    );
    await tester.tap(find.bySemanticsLabel('PICKS'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('READ-ONLY RESULT ARCHIVE'), findsOneWidget);
    expect(find.text('RESULT LOCKED'), findsOneWidget);
    expect(find.byType(PickMarketCard), findsNothing);
    expect(find.text('BUY'), findsNothing);
  });
}

class _FakeStatsService extends EspnLeagueStatsService {
  _FakeStatsService({this.delay2025 = false});

  final bool delay2025;
  final Completer<LeagueStatsSnapshot> _season2025 = Completer();

  void complete2025() {
    if (!_season2025.isCompleted) _season2025.complete(_snapshot(2025));
  }

  @override
  Future<List<LeagueSeasonOption>> fetchAvailableSeasons(
    String leagueId,
  ) async => const [
    LeagueSeasonOption(year: 2026, label: '2026-27', isCurrent: true),
    LeagueSeasonOption(year: 2025, label: '2025-26'),
    LeagueSeasonOption(year: 2024, label: '2024-25'),
  ];

  @override
  Future<LeagueStatsSnapshot> fetchSnapshot(
    String leagueId, {
    int? seasonYear,
  }) {
    final year = seasonYear ?? 2026;
    if (year == 2025 && delay2025) return _season2025.future;
    return Future.value(_snapshot(year));
  }

  @override
  Future<StatLeaderCategory> resolveCategory(
    String leagueId,
    StatLeaderCategory category, {
    int? seasonYear,
  }) async => category;

  @override
  Future<LeagueTeamStats> fetchTeamStats(
    String leagueId, {
    int? seasonYear,
  }) async => LeagueTeamStats.empty;
}

class _FakeScoreService extends EspnScoreService {
  int calls = 0;

  @override
  Future<List<SportMatch>> fetchFootballSeasonMatches(
    String leagueId,
    int seasonYear,
  ) async {
    calls += 1;
    return [_match('$seasonYear-final', seasonYear)];
  }
}

class _SeededLeagueStatsCubit extends LeagueStatsCubit {
  _SeededLeagueStatsCubit() : super('eng.1');

  void seed(LeagueStatsState next) => emit(next);
}

LeagueStatsSnapshot _snapshot(int year) => LeagueStatsSnapshot(
  groups: [
    StandingsGroup(
      label: '',
      rows: [
        TeamStanding(
          team: _team,
          rank: 1,
          played: 1,
          won: 1,
          lost: 0,
          points: 3,
          diffLabel: '+1',
          form: 'W',
        ),
      ],
    ),
  ],
  categories: const [],
  seasonLabel: '$year-${(year + 1) % 100}',
  seasonYear: year,
);

SportMatch _match(String id, int year) => SportMatch(
  id: id,
  leagueId: 'eng.1',
  sport: Sport.football,
  home: _team,
  away: const SportTeam(
    id: 'away',
    name: 'Away FC',
    shortName: 'AWY',
    color: Colors.red,
  ),
  kickoff: DateTime(year, 9, 1),
  status: MatchStatus.finished,
  homeScore: '2',
  awayScore: '1',
);

const _team = SportTeam(
  id: 'home',
  name: 'Home FC',
  shortName: 'HOM',
  color: Colors.blue,
);

const _league = League(
  id: 'eng.1',
  name: 'English Premier League',
  shortCode: 'EPL',
  accent: Colors.purple,
);
