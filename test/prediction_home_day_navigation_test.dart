import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_state.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/screens/predictions/prediction_home_screen.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AudioController.instance.muted.value = true;
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('match day header starts centered on today', (tester) async {
    final cubit = _NavCubit(_NavRepo());
    cubit.seed(_fixtures());
    addTearDown(cubit.close);

    await _pumpHome(tester, cubit);

    expect(_headingText('TODAY'), findsOneWidget);
    expect(_headingText('(1)'), findsOneWidget);
  });



  testWidgets('match day arrows move to tomorrow and yesterday', (
    tester,
  ) async {
    final cubit = _NavCubit(_NavRepo());
    cubit.seed(_fixtures());
    addTearDown(cubit.close);

    await _pumpHome(tester, cubit);

    await tester.tap(find.byKey(const ValueKey('match-day-next-button')));
    await tester.pumpAndSettle();
    expect(_headingText('TOMORROW'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('match-day-previous-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('match-day-previous-button')));
    await tester.pumpAndSettle();
    expect(_headingText('YESTERDAY'), findsOneWidget);
  });

  testWidgets('match day swipe moves between adjacent days', (tester) async {
    final cubit = _NavCubit(_NavRepo());
    cubit.seed(_fixtures());
    addTearDown(cubit.close);

    await _pumpHome(tester, cubit);

    await tester.drag(
      find.byKey(const ValueKey('match-day-swipe-area')),
      const Offset(-360, 0),
    );
    await tester.pumpAndSettle();
    expect(_headingText('TOMORROW'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('match-day-swipe-area')),
      const Offset(360, 0),
    );
    await tester.pumpAndSettle();
    expect(_headingText('TODAY'), findsOneWidget);
  });

  testWidgets('calendar picker still changes the match day', (tester) async {
    final cubit = _NavCubit(_NavRepo());
    cubit.seed(_fixtures());
    addTearDown(cubit.close);

    await _pumpHome(tester, cubit);

    await tester.tap(find.byKey(const ValueKey('match-day-calendar-button')));
    await tester.pumpAndSettle();

    final today = _today();
    final target = today.day > 1
        ? today.subtract(const Duration(days: 1))
        : today.add(const Duration(days: 1));
    final expectedLabel = target.isBefore(today) ? 'YESTERDAY' : 'TOMORROW';
    final targetCell = find.descendant(
      of: find.byType(CalendarDatePicker),
      matching: find.text('${target.day}'),
    );
    await tester.tap(targetCell.last);
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(_headingText(expectedLabel), findsOneWidget);
  });
}

Future<void> _pumpHome(
  WidgetTester tester,
  PredictionCubit cubit, {
  VoidCallback? onOpenGame,
  VoidCallback? onOpenShootout,
}) async {
  final gameBloc = GameBloc(SecureGameStorage());
  addTearDown(gameBloc.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<GameBloc>.value(value: gameBloc),
        BlocProvider<PredictionCubit>.value(value: cubit),
      ],
      child: MaterialApp(
        home: PredictionHomeScreen(
          activeTab: 0,
          onTabChanged: (_) {},
          activeMatchSportTab: 0,
          onMatchSportTabChanged: (_) {},
          activeGamesSportTab: 0,
          onGamesSportTabChanged: (_) {},
          onNavigate: (_) {},
          onOpenMatch: (_) {},
          onOpenLeague: (_) {},
          onOpenGame: onOpenGame ?? () {},
          onOpenShootout: onOpenShootout ?? () {},
          onOpenQuiz: (_) {},
          onOpenFootballBingo: () {},
          onOpenFootballChess: () {},
          onOpenGuessPlayer: () {},
          onOpenGrandPrix: () {},
          onOpenF1GuessDriver: () {},
              onOpenTennisGuessWinner: () {},
          onOpenBasketball: () {},
          onOpenBasketballGuessPlayer: () {},
          onOpenCricketGuessPlayer: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _headingText(String text) => find.descendant(
  of: find.byKey(const ValueKey('match-day-heading')),
  matching: find.text(text),
);

List<SportMatch> _fixtures() {
  final today = _today();
  return [
    _match('yesterday', today.subtract(const Duration(days: 1))),
    _match('today', today),
    _match('tomorrow', today.add(const Duration(days: 1))),
  ];
}

SportMatch _match(String id, DateTime day) => SportMatch(
  id: id,
  leagueId: _league.id,
  sport: Sport.football,
  home: _home,
  away: _away,
  kickoff: DateTime(day.year, day.month, day.day, 18),
  status: MatchStatus.upcoming,
);

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

class _NavCubit extends PredictionCubit {
  _NavCubit(PredictionRepository repository)
    : super(repository, SecureGameStorage());

  void seed(List<SportMatch> fixtures) {
    emit(
      const PredictionState().copyWith(
        loading: false,
        leagues: [_league],
        fixtures: fixtures,
      ),
    );
  }
}

class _NavRepo implements PredictionRepository {
  @override
  Future<List<League>> leagues() async => const [_league];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async => const [];

  @override
  Future<List<SportMatch>> enrichFixturesForSport(List<SportMatch> fixtures, Sport sport) async => fixtures;

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

const _league = League(
  id: 'test',
  name: 'Test League',
  shortCode: 'TST',
  accent: Color(0xff31d0ff),
);

const _home = SportTeam(
  id: 'home',
  name: 'Home FC',
  shortName: 'HOM',
  color: Color(0xff31d0ff),
);

const _away = SportTeam(
  id: 'away',
  name: 'Away FC',
  shortName: 'AWY',
  color: Color(0xfff7c948),
);
