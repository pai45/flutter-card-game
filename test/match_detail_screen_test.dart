import 'package:card_game/blocs/achievement/achievement_celebration_controller.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_state.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/screens/predictions/all_picks_screen.dart';
import 'package:card_game/screens/predictions/match_detail_screen.dart';
import 'package:card_game/screens/predictions/prediction_home_screen.dart';
import 'package:card_game/screens/predictions/widgets/match_prediction_card.dart';
import 'package:card_game/screens/predictions/widgets/pick_market_card.dart';
import 'package:card_game/services/pick_repository.dart';
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

  testWidgets('tapping a fixture opens match detail tabs', (tester) async {
    final prediction = _TestPredictionCubit(_PredictionRepo());
    prediction.seed();
    final picks = PicksCubit(MockPickRepository(), SecureGameStorage());
    final game = GameBloc(SecureGameStorage());
    final navigatorKey = GlobalKey<NavigatorState>();
    await picks.load();
    addTearDown(prediction.close);
    addTearDown(picks.close);
    addTearDown(game.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GameBloc>.value(value: game),
          BlocProvider<PredictionCubit>.value(value: prediction),
          BlocProvider<PicksCubit>.value(value: picks),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: PredictionHomeScreen(
            activeTab: 0,
            onTabChanged: (_) {},
            activeMatchSportTab: 0,
            onMatchSportTabChanged: (_) {},
            activeGamesSportTab: 0,
            onGamesSportTabChanged: (_) {},
            onNavigate: (_) {},
            onOpenMatch: (match) {
              navigatorKey.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => MatchDetailScreen(match: match),
                ),
              );
            },
            onOpenLeague: (_) {},
            onOpenGame: () {},
            onOpenShootout: () {},
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
    await _tapTextGesture(tester, 'France');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('match-detail-screen')), findsOneWidget);
    expect(find.text('PREDICT'), findsWidgets);
    expect(find.text('PICKS'), findsOneWidget);
    expect(find.text('TOPS'), findsOneWidget);
    expect(find.text('STATS'), findsOneWidget);
  });

  testWidgets('finished fixture without prediction still opens match detail', (
    tester,
  ) async {
    final prediction = _TestPredictionCubit(_PredictionRepo());
    prediction.seed(match: _franceParaguayFinished.copyWith(kickoff: _kickoff));
    final picks = PicksCubit(MockPickRepository(), SecureGameStorage());
    final game = GameBloc(SecureGameStorage());
    final navigatorKey = GlobalKey<NavigatorState>();
    await picks.load();
    addTearDown(prediction.close);
    addTearDown(picks.close);
    addTearDown(game.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<GameBloc>.value(value: game),
          BlocProvider<PredictionCubit>.value(value: prediction),
          BlocProvider<PicksCubit>.value(value: picks),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: PredictionHomeScreen(
            activeTab: 0,
            onTabChanged: (_) {},
            activeMatchSportTab: 0,
            onMatchSportTabChanged: (_) {},
            activeGamesSportTab: 0,
            onGamesSportTabChanged: (_) {},
            onNavigate: (_) {},
            onOpenMatch: (match) {
              navigatorKey.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (_) => MatchDetailScreen(match: match),
                ),
              );
            },
            onOpenLeague: (_) {},
            onOpenGame: () {},
            onOpenShootout: () {},
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
    await _tapTextGesture(tester, 'Paraguay');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('match-detail-screen')), findsOneWidget);
    expect(find.text('STATS'), findsOneWidget);
  });

  testWidgets('match cards render upcoming prediction CTA', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MatchPredictionCard(
            match: _match.copyWith(prizeLabel: 'Win 5000 coins'),
            prediction: null,
          ),
        ),
      ),
    );

    expect(find.text('Make prediction and Win 5000 coins'), findsOneWidget);
  });

  testWidgets('picks tab only shows markets for the selected match', (
    tester,
  ) async {
    await _pumpDetail(tester, initialTab: 1);

    expect(find.byKey(const ValueKey('view-all-picks-cta')), findsOneWidget);
    expect(find.text('VIEW ALL PICKS'), findsOneWidget);
    expect(find.text('Browse every open market'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-picks-list')), findsOneWidget);
    expect(find.byType(PickMarketCard), findsAtLeastNWidgets(2));
  });

  testWidgets('match picks tab opens full all picks page with filters', (
    tester,
  ) async {
    await _pumpDetail(tester, initialTab: 1);

    await tester.tap(find.byKey(const ValueKey('view-all-picks-cta')));
    await _pumpFrames(tester, const Duration(milliseconds: 800));

    expect(find.byType(AllPicksScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('all-picks-screen')), findsOneWidget);
    expect(find.text('ALL PICKS'), findsOneWidget);
    expect(find.text('ALL'), findsAtLeastNWidgets(1));
    expect(find.text('MATCHES'), findsAtLeastNWidgets(1));
    expect(find.text('EVENT'), findsAtLeastNWidgets(1));
    expect(find.text('FUTURES'), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('all picks CTA is visible when match has no pick markets', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      initialTab: 1,
      match: _match.copyWith(id: 'match_without_pick_markets'),
    );

    expect(find.byKey(const ValueKey('view-all-picks-cta')), findsOneWidget);
    expect(find.text('VIEW ALL PICKS'), findsOneWidget);
    expect(find.text('NO PICKS FOR THIS MATCH'), findsOneWidget);
    expect(find.byKey(const ValueKey('match-picks-list')), findsNothing);
  });

  testWidgets('leaderboard tab switches between quiz-set boards', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      initialTab: 2,
      repository: _TwoQuestionPredictionRepo(),
      match: _franceParaguayUpcoming,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('match-leaderboard-tab')), findsOneWidget);
    expect(find.text('640'), findsOneWidget);

    await tester.tap(find.text('MATCH EVENTS QUIZ'));
    await tester.pumpAndSettle();

    expect(find.text('720'), findsOneWidget);
  });

  testWidgets('predict tab shows quiz-set hub for multiple quizzes', (
    tester,
  ) async {
    final prediction = await _pumpDetail(
      tester,
      repository: _TwoQuestionPredictionRepo(),
      match: _franceParaguayUpcoming,
    );

    expect(find.text('2 Quizzes to predict'), findsNothing);
    expect(find.text('Choose a quiz set'), findsNothing);
    expect(find.text('Scoreline Quiz'), findsOneWidget);
    expect(find.text('Match Events Quiz'), findsOneWidget);
    expect(find.text('+120 XP'), findsOneWidget);
    expect(find.text('+90 XP'), findsOneWidget);

    await tester.tap(find.text('Match Events Quiz'));
    await tester.pumpAndSettle();
    await _pumpFrames(tester, const Duration(seconds: 3));

    expect(find.text('2 Quizzes to predict'), findsNothing);
    expect(find.text('ALL QUIZZES'), findsNothing);
    expect(find.text('DRAW'), findsOneWidget);

    await _tapOption(tester, 'DRAW');
    await tester.pump();
    await _tapButton(tester, 'SUBMIT QUIZ');
    await tester.pump();

    expect(
      prediction.state.predictionFor(_franceParaguayUpcoming.id, 'events'),
      isNotNull,
    );
  });

  testWidgets('predict tab shows quiz-set hub for regular matches', (
    tester,
  ) async {
    await _pumpDetail(
      tester,
      repository: MockPredictionRepository(),
      match: _match,
    );

    expect(find.text('2 Quizzes to predict'), findsNothing);
    expect(find.text('Choose a quiz set'), findsNothing);
    expect(find.text('Scoreline Quiz'), findsOneWidget);
    expect(find.text('Match Events Quiz'), findsOneWidget);
  });

  testWidgets('submitted prediction open picks switches to picks tab', (
    tester,
  ) async {
    await _pumpDetail(tester);
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 5));

    await _tapOption(tester, 'YES');
    await _tapButton(tester, 'SUBMIT QUIZ');
    await tester.pump();
    await _pumpFrames(tester, const Duration(seconds: 5));

    expect(find.text('OPEN PICKS'), findsOneWidget);
    await _tapButton(tester, 'OPEN PICKS');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('match-picks-list')), findsOneWidget);
    expect(find.byType(PickMarketCard), findsAtLeastNWidgets(2));
  });

  testWidgets('scoreboard renders upcoming live and finished states', (
    tester,
  ) async {
    final scoreboardMatch = _match.copyWith(id: 'fifa_scoreboard_test');

    await _pumpScoreboard(tester, scoreboardMatch);
    expect(find.text('PRE-MATCH'), findsOneWidget);
    expect(
      find.text('Scoreboard opens when the match starts.'),
      findsOneWidget,
    );
    expect(find.text('Unavailable'), findsOneWidget);

    await _pumpScoreboard(
      tester,
      scoreboardMatch.copyWith(
        status: MatchStatus.live,
        homeScore: '1',
        awayScore: '0',
        liveMinute: 67,
        liveLastUpdated: DateTime(2026, 7, 5, 3, 15),
      ),
    );
    expect(find.text('LIVE NOW'), findsOneWidget);
    expect(find.text('Live clock: 67 minutes.'), findsOneWidget);
    expect(find.text('2026-07-05 03:15'), findsOneWidget);

    await _pumpScoreboard(
      tester,
      scoreboardMatch.copyWith(
        status: MatchStatus.finished,
        homeScore: '2',
        awayScore: '1',
        resultLine: 'France won 2-1',
      ),
    );
    await tester.scrollUntilVisible(
      find.text('FULL TIME'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('FULL TIME'), findsOneWidget);
    expect(find.text('France won 2-1'), findsWidgets);

    await _pumpScoreboard(
      tester,
      scoreboardMatch.copyWith(
        liveStatusNote: 'Live score temporarily unavailable.',
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Live score temporarily unavailable.'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Live score temporarily unavailable.'), findsOneWidget);
  });
}

Future<PredictionCubit> _pumpDetail(
  WidgetTester tester, {
  int initialTab = 0,
  PredictionRepository? repository,
  SportMatch? match,
}) async {
  final prediction = PredictionCubit(
    repository ?? _PredictionRepo(),
    SecureGameStorage(),
  );
  final picks = PicksCubit(MockPickRepository(), SecureGameStorage());
  final game = GameBloc(SecureGameStorage());
  await picks.load();
  addTearDown(prediction.close);
  addTearDown(picks.close);
  addTearDown(game.close);

  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider<GameBloc>.value(value: game),
        BlocProvider<PredictionCubit>.value(value: prediction),
        BlocProvider<PicksCubit>.value(value: picks),
        BlocProvider<AchievementCelebrationController>(
          create: (_) => AchievementCelebrationController(SecureGameStorage()),
        ),
      ],
      child: MaterialApp(
        home: MatchDetailScreen(match: match ?? _match, initialTab: initialTab),
      ),
    ),
  );
  await tester.pump();
  return prediction;
}

Future<void> _pumpScoreboard(WidgetTester tester, SportMatch match) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MatchDetailScreen(
        match: match,
        initialTab: 3,
        refreshLiveScore: false,
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpFrames(WidgetTester tester, Duration duration) async {
  final frames = (duration.inMilliseconds / 100).ceil();
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tapButton(WidgetTester tester, String label) {
  return tester.tap(
    find
        .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first,
  );
}

Future<void> _tapTextGesture(WidgetTester tester, String label) async {
  final gesture = find
      .ancestor(
        of: find.text(label).first,
        matching: find.byType(GestureDetector),
      )
      .first;
  tester.widget<GestureDetector>(gesture).onTap!();
  await tester.pump();
}

Future<void> _tapOption(WidgetTester tester, String label) async {
  final optionGesture = find
      .ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget.key is ValueKey<String> &&
              (widget.key! as ValueKey<String>).value.startsWith(
                'quiz-option-',
              ),
        ),
      )
      .first;
  tester.widget<GestureDetector>(optionGesture).onTap!();
  await tester.pump();
}

class _TestPredictionCubit extends PredictionCubit {
  _TestPredictionCubit(PredictionRepository repository)
    : super(repository, SecureGameStorage());

  void seed({SportMatch? match}) {
    emit(
      const PredictionState().copyWith(
        loading: false,
        leagues: const [_league],
        fixtures: [match ?? _match],
      ),
    );
  }
}

class _PredictionRepo implements PredictionRepository {
  @override
  Future<List<League>> leagues() async => const [_league];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async => [_match];

  @override
  Future<List<SportMatch>> enrichFixturesForSport(List<SportMatch> fixtures, Sport sport) async => fixtures;

  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) async {
    final quiz = await quizFor(matchId, kDefaultPredictionQuizId);
    return quiz != null ? [quiz] : [];
  }

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) async =>
      const PredictionQuiz(
        matchId: 'fifa_fra_par',
        questions: [
          QuizQuestion(
            id: 'q1',
            text: 'Will France win?',
            options: ['YES', 'NO'],
            reward: 5,
          ),
        ],
      );

  @override
  Future<List<TeamStanding>> standings(String leagueId) async => const [];

  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) async => const PredictionVoteBreakdown(
    matchId: 'fifa_fra_par',
    questionId: 'q1',
    totals: {0: 7, 1: 3},
  );

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async => const [];
}

class _TwoQuestionPredictionRepo extends _PredictionRepo {
  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) async => const [
    PredictionQuiz(
      id: 'main',
      matchId: 'fifa_fra_par',
      title: 'Scoreline Quiz',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Predict the full-time score',
          type: QuizQuestionType.exactScore,
          reward: 120,
        ),
      ],
    ),
    PredictionQuiz(
      id: 'events',
      matchId: 'fifa_fra_par',
      title: 'Match Events Quiz',
      questions: [
        QuizQuestion(
          id: 'q1',
          text: 'Who wins France vs Paraguay?',
          options: ['France', 'Draw', 'Paraguay'],
          reward: 90,
        ),
      ],
    ),
  ];

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) async {
    final quizzes = await quizzesFor(matchId);
    for (final quiz in quizzes) {
      if (quiz.id == quizId) return quiz;
    }
    return null;
  }

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async => [
    MatchPredictionLeaderboardEntry(
      rank: 1,
      name: 'You',
      points: quizId == 'events' ? 720 : 640,
      correct: quizId == 'events' ? 3 : 2,
    ),
  ];
}

const _league = League(
  id: 'fifa',
  name: 'FIFA',
  shortCode: 'FIFA',
  accent: Color(0xff31d0ff),
);

const _france = SportTeam(
  id: 'fra',
  name: 'France',
  shortName: 'FRA',
  color: Color(0xff1d4ed8),
);

const _paraguay = SportTeam(
  id: 'par',
  name: 'Paraguay',
  shortName: 'PAR',
  color: Color(0xffd7263d),
);

final _kickoff = DateTime(
  DateTime.now().year,
  DateTime.now().month,
  DateTime.now().day,
  18,
);

final _match = SportMatch(
  id: 'fifa_fra_par',
  leagueId: 'fifa',
  sport: Sport.football,
  home: _france,
  away: _paraguay,
  kickoff: _kickoff,
  status: MatchStatus.upcoming,
);

final _franceParaguayUpcoming = SportMatch(
  id: 'fifa_fra_par',
  leagueId: 'fifa',
  sport: Sport.football,
  home: _france,
  away: _paraguay,
  kickoff: _kickoff,
  status: MatchStatus.upcoming,
  prizeLabel: 'Win 5000 coins',
);

final _franceParaguayFinished = SportMatch(
  id: 'fifa_fra_par',
  leagueId: 'fifa',
  sport: Sport.football,
  home: _france,
  away: _paraguay,
  kickoff: DateTime(2026, 7, 5, 2, 30),
  status: MatchStatus.finished,
);
