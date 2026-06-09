import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_state.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/screens/predictions/match_prediction_screen.dart';
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

  testWidgets('prediction quiz reveals number, words, then options', (
    tester,
  ) async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<PredictionCubit>.value(
        value: cubit,
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('1'), findsOneWidget);
    expect(find.text('WILL'), findsNothing);
    expect(find.text('YES'), findsNothing);

    await _pumpFrames(tester, const Duration(seconds: 4));

    expect(find.text('WILL'), findsOneWidget);
    expect(find.text('YES'), findsOneWidget);
  });

  testWidgets('prediction quiz keeps NEXT disabled until the current answer', (
    tester,
  ) async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 4));

    await _tapButton(tester, 'NEXT');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('SECOND'), findsNothing);
    expect(find.text('2'), findsNothing);
  });

  testWidgets('existing upcoming prediction opens collapsed review list', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(_prediction(status: PredictionStatus.open));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _match);

    expect(
      find.text('You can update answers until match starts.'),
      findsOneWidget,
    );
    expect(find.text('WILL HOME WIN'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
    expect(find.text('NO').hitTestable(), findsNothing);
  });

  testWidgets('review row expands and save updates stores changed answer', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(_prediction(status: PredictionStatus.open));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _match);

    await tester.tap(find.text('WILL HOME WIN'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('NO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NO'));
    await tester.pumpAndSettle();
    await _tapButton(tester, 'SAVE UPDATES');
    await tester.pumpAndSettle();

    expect(cubit.state.predictionFor(_match.id)?.answers['q1'], 1);
  });

  test('old prediction json loads with empty multipliers', () {
    final prediction = UserPrediction.fromJson({
      'matchId': 'quiz_match',
      'answers': {'q1': 0},
      'submittedAt': DateTime(2026).millisecondsSinceEpoch,
      'status': 'open',
      'correctCount': null,
      'rewardEarned': 0,
    });

    expect(prediction.multipliersByQuestion, isEmpty);
  });

  testWidgets('selecting and moving 2x updates boosted xp placement', (
    tester,
  ) async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 4));

    await tester.tap(find.text('YES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2x').first);
    await tester.pumpAndSettle();

    expect(find.text('10'), findsOneWidget);

    await _tapButton(tester, 'NEXT');
    await _pumpFrames(tester, const Duration(seconds: 4));
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();

    expect(find.text('MOVE'), findsNothing);
    await tester.tap(find.text('2x').first);
    await tester.pumpAndSettle();
    await _tapButton(tester, 'SUBMIT QUIZ');
    await tester.pump();

    final prediction = cubit.state.predictionFor(_match.id);
    expect(prediction?.multipliersByQuestion['q1'], isNull);
    expect(prediction?.multipliersByQuestion['q2'], PredictionMultiplier.x2);
  });

  testWidgets('tapping active multiplier removes it', (tester) async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 4));

    await tester.tap(find.text('YES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2x').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2x').first);
    await tester.pumpAndSettle();

    await _tapButton(tester, 'NEXT');
    await _pumpFrames(tester, const Duration(seconds: 4));
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    await _tapButton(tester, 'SUBMIT QUIZ');
    await tester.pump();

    expect(
      cubit.state.predictionFor(_match.id)?.multipliersByQuestion,
      isEmpty,
    );
  });

  testWidgets('one question cannot hold both multipliers', (tester) async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider.value(
        value: cubit,
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 4));

    await tester.tap(find.text('YES'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2x').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').first);
    await tester.pumpAndSettle();

    await _tapButton(tester, 'NEXT');
    await _pumpFrames(tester, const Duration(seconds: 4));
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    await _tapButton(tester, 'SUBMIT QUIZ');
    await tester.pump();

    final multipliers = cubit.state
        .predictionFor(_match.id)
        ?.multipliersByQuestion;
    expect(multipliers, {'q1': PredictionMultiplier.x15});
  });

  testWidgets('submitted review can move multiplier and save updates', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(
      _prediction(
        status: PredictionStatus.open,
        multipliersByQuestion: const {'q1': PredictionMultiplier.x2},
      ),
    );
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _match);

    await tester.tap(find.text('SECOND QUESTION'));
    await tester.pumpAndSettle();
    expect(find.text('MOVE'), findsNothing);
    await tester.ensureVisible(find.text('2x').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2x').last);
    await tester.pumpAndSettle();
    await _tapButton(tester, 'SAVE UPDATES');
    await tester.pumpAndSettle();

    final multipliers = cubit.state
        .predictionFor(_match.id)
        ?.multipliersByQuestion;
    expect(multipliers, {'q2': PredictionMultiplier.x2});
  });

  testWidgets('live prediction review shows multiplier badge read only', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(
      _prediction(
        matchId: _liveMatch.id,
        status: PredictionStatus.locked,
        multipliersByQuestion: const {'q1': PredictionMultiplier.x2},
      ),
    );
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _liveMatch);

    expect(find.text('2x'), findsAtLeastNWidgets(1));
    expect(find.text('BOOST'), findsNothing);
    expect(find.text('SAVE UPDATES'), findsNothing);
  });

  test('settlement applies multipliers only to correct answers', () async {
    final cubit = _TestPredictionCubit(_QuizRepo(_settledQuiz));
    cubit.seed(
      UserPrediction(
        matchId: _match.id,
        answers: const {'q1': 0, 'q2': 1},
        multipliersByQuestion: const {
          'q1': PredictionMultiplier.x2,
          'q2': PredictionMultiplier.x15,
        },
        submittedAt: DateTime.now(),
      ),
    );
    addTearDown(cubit.close);

    final reward = await cubit.settle(_match.id);

    expect(reward, 8);
    final prediction = cubit.state.predictionFor(_match.id);
    expect(prediction?.correctCount, 1);
    expect(prediction?.rewardEarned, 8);
  });

  testWidgets('live prediction review shows vote bars and no edit CTA', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(
      _prediction(matchId: _liveMatch.id, status: PredictionStatus.locked),
    );
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _liveMatch);

    expect(find.text('CROWD VOTES'), findsAtLeastNWidgets(1));
    expect(find.text('100 votes'), findsAtLeastNWidgets(1));
    expect(find.text('SAVE UPDATES'), findsNothing);
  });

  testWidgets('finished prediction review highlights right answer and votes', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_settledQuiz));
    cubit.seed(
      _prediction(matchId: _finishedMatch.id, status: PredictionStatus.settled),
    );
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _finishedMatch);

    expect(find.text('CORRECT ANSWER: No'), findsOneWidget);
    expect(find.text('RIGHT'), findsAtLeastNWidgets(1));
    expect(find.text('CROWD VOTES'), findsAtLeastNWidgets(1));
  });

  testWidgets('match leaderboard button opens leaderboard sheet', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(_prediction(status: PredictionStatus.open));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _match);

    await tester.tap(find.byIcon(Icons.emoji_events_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('MATCH LEADERBOARD'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('640'), findsOneWidget);
  });
}

Future<void> _pumpPredictionScreen(
  WidgetTester tester, {
  required PredictionCubit cubit,
  required SportMatch match,
}) async {
  await tester.pumpWidget(
    BlocProvider<PredictionCubit>.value(
      value: cubit,
      child: MaterialApp(home: MatchPredictionScreen(match: match)),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _pumpFrames(WidgetTester tester, Duration duration) async {
  var elapsed = Duration.zero;
  const step = Duration(milliseconds: 16);
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

Future<void> _tapButton(WidgetTester tester, String label) {
  return tester.tap(
    find
        .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
        .first,
  );
}

class _QuizRepo implements PredictionRepository {
  const _QuizRepo(this.quiz);

  final PredictionQuiz quiz;

  @override
  Future<List<League>> leagues() async => const [];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day}) async => const [];

  @override
  Future<PredictionQuiz?> quizFor(String matchId) async =>
      matchId == quiz.matchId ? quiz : null;

  @override
  Future<List<TeamStanding>> standings(String leagueId) async => const [];

  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String questionId,
  ) async => PredictionVoteBreakdown(
    matchId: matchId,
    questionId: questionId,
    totals: const {0: 64, 1: 36},
  );

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
  ) async => const [
    MatchPredictionLeaderboardEntry(
      rank: 1,
      name: 'You',
      points: 640,
      correct: 4,
    ),
  ];
}

class _TestPredictionCubit extends PredictionCubit {
  _TestPredictionCubit(PredictionRepository repository)
    : super(repository, SecureGameStorage());

  void seed(UserPrediction prediction) {
    emit(
      const PredictionState().copyWith(
        predictions: {prediction.matchId: prediction},
      ),
    );
  }
}

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

final _match = SportMatch(
  id: 'quiz_match',
  leagueId: 'test',
  sport: Sport.football,
  home: _home,
  away: _away,
  kickoff: DateTime.now().add(const Duration(hours: 2)),
  status: MatchStatus.upcoming,
);

final _liveMatch = SportMatch(
  id: 'quiz_match',
  leagueId: 'test',
  sport: Sport.football,
  home: _home,
  away: _away,
  kickoff: DateTime.now().subtract(const Duration(minutes: 67)),
  status: MatchStatus.live,
  liveMinute: 67,
  homeScore: '2',
  awayScore: '1',
);

final _finishedMatch = SportMatch(
  id: 'quiz_match',
  leagueId: 'test',
  sport: Sport.football,
  home: _home,
  away: _away,
  kickoff: DateTime.now().subtract(const Duration(hours: 4)),
  status: MatchStatus.finished,
  homeScore: '2',
  awayScore: '1',
);

UserPrediction _prediction({
  String matchId = 'quiz_match',
  required PredictionStatus status,
  Map<String, PredictionMultiplier> multipliersByQuestion = const {},
}) => UserPrediction(
  matchId: matchId,
  answers: const {'q1': 0, 'q2': 1},
  multipliersByQuestion: multipliersByQuestion,
  submittedAt: DateTime.now().subtract(const Duration(hours: 1)),
  status: status,
);

const _quiz = PredictionQuiz(
  matchId: 'quiz_match',
  questions: [
    QuizQuestion(
      id: 'q1',
      text: 'Will home win',
      options: ['Yes', 'No'],
      reward: 5,
    ),
    QuizQuestion(
      id: 'q2',
      text: 'Second question',
      options: ['Home', 'Away'],
      reward: 5,
    ),
  ],
);

const _settledQuiz = PredictionQuiz(
  matchId: 'quiz_match',
  questions: [
    QuizQuestion(
      id: 'q1',
      text: 'Will home win',
      options: ['Yes', 'No'],
      reward: 5,
      settledOptionIndex: 1,
    ),
    QuizQuestion(
      id: 'q2',
      text: 'Second question',
      options: ['Home', 'Away'],
      reward: 5,
      settledOptionIndex: 1,
    ),
  ],
);
