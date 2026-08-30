import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_state.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/screens/predictions/match_search_screen.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (_) async => null,
        );
    AudioController.instance.muted.value = true;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('searches teams and leagues across sports and opens fixtures', (
    tester,
  ) async {
    final cubit = _SeededSearchCubit(_EmptyPredictionRepository())
      ..seed(_leagues, _fixtures);
    addTearDown(cubit.close);
    SportMatch? openedMatch;

    await tester.pumpWidget(
      BlocProvider<PredictionCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: MatchSearchScreen(onOpenMatch: (match) => openedMatch = match),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cubit.loadAllCalls, 1);

    await tester.enterText(
      find.byKey(const ValueKey('cyber-search-text-field')),
      '  LfC  ',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('match-search-result-team-football:liv')),
      findsOneWidget,
    );
    expect(find.text('LIVERPOOL'), findsOneWidget);
    expect(find.textContaining('TEAM // FOOTBALL'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('match-search-fixture-epl-liv-mci')),
    );
    expect(openedMatch?.id, 'epl-liv-mci');

    await tester.enterText(
      find.byKey(const ValueKey('cyber-search-text-field')),
      'ePl',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('match-search-result-league-epl')),
      findsOneWidget,
    );
    expect(find.text('ENGLISH PREMIER LEAGUE'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('cyber-search-text-field')),
      'ipl',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('match-search-result-league-ipl')),
      findsOneWidget,
    );
    expect(find.textContaining('LEAGUE // CRICKET'), findsOneWidget);
  });

  testWidgets('handles short, empty, clear, and no-result queries', (
    tester,
  ) async {
    final cubit = _SeededSearchCubit(_EmptyPredictionRepository())
      ..seed(_leagues, _fixtures);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<PredictionCubit>.value(
        value: cubit,
        child: MaterialApp(home: MatchSearchScreen(onOpenMatch: (_) {})),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SCAN THE FIXTURE NETWORK'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('cyber-search-text-field')),
      'l',
    );
    await tester.pump();
    expect(find.text('ADD ONE MORE SIGNAL'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('cyber-search-text-field')),
      'unknown club',
    );
    await tester.pumpAndSettle();
    expect(find.text('NO MATCH FOUND'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Clear search'));
    await tester.pump();
    expect(find.text('SCAN THE FIXTURE NETWORK'), findsOneWidget);
  });

  test('loadAllSports loads each missing sport once in enum order', () async {
    final repository = _TrackingPredictionRepository();
    final cubit = PredictionCubit(repository, SecureGameStorage());
    addTearDown(cubit.close);

    await cubit.loadAllSports();
    await cubit.loadAllSports();

    expect(repository.requestedSports, Sport.values);
    expect(cubit.state.loadedSports, containsAll(Sport.values));
  });
}

class _SeededSearchCubit extends PredictionCubit {
  _SeededSearchCubit(PredictionRepository repository)
    : super(repository, SecureGameStorage());

  int loadAllCalls = 0;

  void seed(List<League> leagues, List<SportMatch> fixtures) {
    emit(
      const PredictionState().copyWith(
        loading: false,
        loadedSports: Sport.values.toSet(),
        leagues: leagues,
        fixtures: fixtures,
      ),
    );
  }

  @override
  Future<void> loadAllSports() async {
    loadAllCalls++;
  }
}

class _TrackingPredictionRepository extends _EmptyPredictionRepository {
  final List<Sport> requestedSports = [];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async {
    if (sport != null) requestedSports.add(sport);
    return const [];
  }
}

class _EmptyPredictionRepository implements PredictionRepository {
  @override
  Future<List<League>> leagues() async => _leagues;

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async =>
      const [];

  @override
  Future<List<SportMatch>> enrichFixturesForSport(
    List<SportMatch> fixtures,
    Sport sport,
  ) async => fixtures;

  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) async => const [];

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) async => null;

  @override
  Future<List<TeamStanding>> standings(String leagueId) async => const [];

  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) async => null;

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async => const [];
}

const _leagues = [
  League(
    id: 'epl',
    name: 'English Premier League',
    shortCode: 'EPL',
    accent: Cyber.cyan,
  ),
  League(
    id: 'ipl',
    name: 'Indian Premier League',
    shortCode: 'IPL',
    accent: Cyber.lime,
  ),
];

final _fixtures = [
  SportMatch(
    id: 'epl-liv-mci',
    leagueId: 'epl',
    sport: Sport.football,
    home: const SportTeam(
      id: 'liv',
      name: 'Liverpool',
      shortName: 'LFC',
      color: Cyber.cyan,
    ),
    away: const SportTeam(
      id: 'mci',
      name: 'Manchester City',
      shortName: 'MCI',
      color: Cyber.violet,
    ),
    kickoff: DateTime(2026, 8, 23, 18),
    status: MatchStatus.upcoming,
  ),
  SportMatch(
    id: 'ipl-ind-eng',
    leagueId: 'ipl',
    sport: Sport.cricket,
    home: const SportTeam(
      id: 'ind',
      name: 'India',
      shortName: 'IND',
      color: Cyber.cyan,
    ),
    away: const SportTeam(
      id: 'eng',
      name: 'England',
      shortName: 'ENG',
      color: Cyber.danger,
    ),
    kickoff: DateTime(2026, 8, 24, 15),
    status: MatchStatus.upcoming,
  ),
];
