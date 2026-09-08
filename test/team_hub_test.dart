import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/team_hub/team_hub_cubit.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/league_stat_leaders.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_hub.dart';
import 'package:card_game/screens/predictions/cricket_player_season_screen.dart';
import 'package:card_game/screens/predictions/team_detail_screen.dart';
import 'package:card_game/screens/predictions/widgets/team_stat_board.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/services/team_hub_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled ESPN packages expose team fixtures and rosters', () async {
    final repository = EspnTeamHubRepository();

    final epl = await repository.loadBundled(
      leagueId: 'eng.1',
      teamId: '331',
      sport: Sport.football,
      seasonYear: 2026,
      seasonLabel: '2026-27',
    );
    expect(epl.fixtures, hasLength(38));
    expect(epl.players.length, greaterThan(20));
    expect(
      epl.players.map((player) => player.id).toSet(),
      hasLength(epl.players.length),
    );
    expect(epl.players.every((player) => player.teamId == '331'), isTrue);

    final ipl = await repository.loadBundled(
      leagueId: 'ipl',
      teamId: '335970',
      sport: Sport.cricket,
      seasonYear: 2026,
      seasonLabel: '2026',
    );
    expect(ipl.fixtures.length, greaterThanOrEqualTo(14));
    expect(ipl.players, isNotEmpty);
    expect(ipl.players.every((player) => player.teamId == '335970'), isTrue);
    expect(ipl.players.any((player) => player.stats.isNotEmpty), isTrue);
  });

  test(
    'live merge replaces matching ESPN ids without dropping package data',
    () {
      final packaged = TeamHubData(
        leagueId: 'eng.1',
        teamId: 'home',
        seasonYear: 2026,
        seasonLabel: '2026-27',
        fixtures: [_match('shared'), _match('package-only')],
        players: const [
          TeamSeasonPlayer(id: '1', teamId: 'home', name: 'Packaged Player'),
        ],
      );
      final live = TeamHubData(
        leagueId: 'eng.1',
        teamId: 'home',
        seasonYear: 2026,
        seasonLabel: '2026-27',
        fixtures: [_match('shared').copyWith(homeScore: '2', awayScore: '1')],
        players: const [
          TeamSeasonPlayer(id: '1', teamId: 'home', name: 'Live Player'),
          TeamSeasonPlayer(id: '2', teamId: 'home', name: 'New Player'),
        ],
      );

      final merged = packaged.mergedWith(live);
      expect(merged.fixtures, hasLength(2));
      expect(
        merged.fixtures.firstWhere((match) => match.id == 'shared').homeScore,
        '2',
      );
      expect(merged.players, hasLength(2));
      expect(
        merged.players.firstWhere((player) => player.id == '1').name,
        'Live Player',
      );
    },
  );

  testWidgets('team stat leader and chaser rows open their team hubs', (
    tester,
  ) async {
    SportTeam? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TeamStatBoard(
            entries: const [
              TeamStatEntry(rank: 1, team: _home, value: 8, display: '8'),
              TeamStatEntry(rank: 2, team: _away, value: 7, display: '7'),
            ],
            spec: const StatBoardSpec('goals', 'GOALS'),
            definition: null,
            accent: Colors.cyan,
            sport: Sport.football,
            competition: 'eng.1',
            onTapTeam: (team) => tapped = team,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Home FC'));
    expect(tapped, _home);
    await tester.tap(find.text('Away FC'));
    expect(tapped, _away);
  });

  testWidgets('team hub exposes all tabs and opens an IPL season dossier', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeTeamHubRepository();
    final hub = TeamHubCubit(
      repository: repository,
      leagueId: 'ipl',
      teamId: _home.id,
      sport: Sport.cricket,
      seasonYear: 2026,
      seasonLabel: '2026',
    )..load();
    final prediction = PredictionCubit(
      MockPredictionRepository(),
      SecureGameStorage(),
    );
    addTearDown(hub.close);
    addTearDown(prediction.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<TeamHubCubit>.value(value: hub),
          BlocProvider<PredictionCubit>.value(value: prediction),
        ],
        child: const MaterialApp(
          home: TeamDetailScreen(
            team: _home,
            league: _ipl,
            sport: Sport.cricket,
            seasonYear: 2026,
            seasonLabel: '2026',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('MATCHES'), findsOneWidget);
    expect(find.text('PREDICTIONS'), findsOneWidget);
    expect(find.text('PLAYERS'), findsOneWidget);
    for (final label in ['MATCHES', 'PREDICTIONS', 'PLAYERS']) {
      expect(
        tester.getSize(find.bySemanticsLabel(label)).height,
        greaterThanOrEqualTo(40),
      );
    }
    await tester.tap(find.bySemanticsLabel('PREDICTIONS'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('PLAYERS'));
    await tester.pumpAndSettle();
    expect(find.text('Sample Batter'), findsOneWidget);
    await tester.tap(find.text('Sample Batter'));
    await tester.pumpAndSettle();
    expect(find.byType(CricketPlayerSeasonScreen), findsOneWidget);
  });
}

class _FakeTeamHubRepository implements TeamHubRepository {
  @override
  Future<TeamHubData> loadBundled({
    required String leagueId,
    required String teamId,
    required Sport sport,
    required int seasonYear,
    required String seasonLabel,
  }) async => TeamHubData(
    leagueId: leagueId,
    teamId: teamId,
    seasonYear: seasonYear,
    seasonLabel: seasonLabel,
    players: const [
      TeamSeasonPlayer(
        id: 'p1',
        teamId: 'home',
        name: 'Sample Batter',
        role: 'Batter',
        stats: {'runs': 420, 'sixes': 18},
      ),
    ],
  );

  @override
  Future<TeamHubData> loadLive({
    required String leagueId,
    required String teamId,
    required Sport sport,
    required int seasonYear,
    required String seasonLabel,
  }) async => TeamHubData(
    leagueId: leagueId,
    teamId: teamId,
    seasonYear: seasonYear,
    seasonLabel: seasonLabel,
  );
}

SportMatch _match(String id) => SportMatch(
  id: id,
  leagueId: 'eng.1',
  sport: Sport.football,
  home: _home,
  away: _away,
  kickoff: DateTime(2026, 9, 1),
  status: MatchStatus.finished,
);

const _home = SportTeam(
  id: 'home',
  name: 'Home FC',
  shortName: 'HOM',
  color: Colors.blue,
);

const _away = SportTeam(
  id: 'away',
  name: 'Away FC',
  shortName: 'AWY',
  color: Colors.red,
);

const _ipl = League(
  id: 'ipl',
  name: 'Indian Premier League',
  shortCode: 'IPL',
  accent: Colors.cyan,
);
