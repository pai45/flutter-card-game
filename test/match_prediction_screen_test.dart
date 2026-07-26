import 'package:card_game/blocs/achievement/achievement_celebration_controller.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/picks/picks_state.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_state.dart';
import 'package:card_game/models/league.dart';
import 'package:card_game/models/picks.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/team_standing.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/screens/predictions/match_prediction_screen.dart';
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

  test('user prediction json defaults missing quiz id to main', () {
    final prediction = UserPrediction.fromJson({
      'matchId': 'legacy_match',
      'answers': {'q1': 0},
      'submittedAt': DateTime(2026, 1, 1).millisecondsSinceEpoch,
      'status': 'open',
      'correctCount': null,
      'rewardEarned': 0,
    });

    expect(prediction.quizId, kDefaultPredictionQuizId);
    expect(prediction.key, 'legacy_match::main');
  });

  test('submitting two quiz sets keeps predictions independent', () async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    await cubit.saveDraft(_match.id, 'main', const {'q1': 0});
    await cubit.saveDraft(_match.id, 'events', const {'q1': 1});

    expect(cubit.state.predictions, hasLength(2));
    expect(cubit.state.predictionFor(_match.id, 'main')?.answers['q1'], 0);
    expect(cubit.state.predictionFor(_match.id, 'events')?.answers['q1'], 1);
  });

  test('curated multi-quiz fixtures retain the paid entry contest', () async {
    const quizzes = [
      PredictionQuiz(
        id: 'main',
        matchId: 'quiz_match',
        title: 'Scoreline Quiz',
        entryFee: kScorelineQuizEntryFee,
        questions: [
          QuizQuestion(
            id: 'score',
            text: 'Score?',
            options: ['1-0'],
            reward: 5,
          ),
        ],
      ),
      PredictionQuiz(
        id: 'events',
        matchId: 'quiz_match',
        title: 'Match Events Quiz',
        questions: [
          QuizQuestion(
            id: 'event',
            text: 'Event?',
            options: ['Yes'],
            reward: 5,
          ),
        ],
      ),
    ];
    final cubit = PredictionCubit(
      _CuratedMultiQuizRepo(_match, quizzes),
      _MemorySecureGameStorage(),
    );
    addTearDown(cubit.close);

    await cubit.loadSport(Sport.football);
    final loaded = await cubit.quizzesFor(_match.id);

    expect(loaded.map((quiz) => quiz.id), ['main', 'events']);
    expect(loaded.first.entryFee, kScorelineQuizEntryFee);
    expect(loaded.first.isContest, isTrue);
  });

  test(
    'new prediction drafts are rejected after a fixture has started',
    () async {
      final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
      cubit.seedFixtures([_liveMatch]);
      addTearDown(cubit.close);

      expect(
        await cubit.saveDraft(_liveMatch.id, 'main', const {'q1': 0}),
        isFalse,
      );
      expect(cubit.state.predictionFor(_liveMatch.id), isNull);
    },
  );

  test('draft updates preserve timestamp and cannot reopen a lock', () async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    expect(
      await cubit.saveDraft(_match.id, 'main', const {'q1': 0, 'q2': 0}),
      isTrue,
    );
    final submittedAt = cubit.state.predictionFor(_match.id)!.submittedAt;

    expect(
      await cubit.saveDraft(_match.id, 'main', const {'q1': 1, 'q2': 0}),
      isTrue,
    );
    expect(cubit.state.predictionFor(_match.id)!.submittedAt, submittedAt);

    expect(await cubit.lockPrediction(_match.id, 'main'), isTrue);
    expect(await cubit.lockPrediction(_match.id, 'main'), isTrue);
    expect(
      await cubit.saveDraft(_match.id, 'main', const {'q1': 0, 'q2': 1}),
      isFalse,
    );
    expect(cubit.state.predictionFor(_match.id)?.answers, const {
      'q1': 1,
      'q2': 0,
    });
    expect(
      cubit.state.predictionFor(_match.id)?.status,
      PredictionStatus.locked,
    );
  });

  test('deadline normalization locks the last saved draft', () async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);
    final deadline = DateTime(2026, 7, 24, 12);
    final overdue = _match.copyWith(
      kickoff: deadline.subtract(const Duration(seconds: 1)),
    );

    await cubit.saveDraft(_match.id, 'main', const {'q1': 1, 'q2': 0});
    final count = await cubit.lockDuePredictions([overdue], now: deadline);

    expect(count, 1);
    expect(
      cubit.state.predictionFor(_match.id)?.status,
      PredictionStatus.locked,
    );
  });

  test('open draft cannot settle before it is locked', () async {
    final cubit = PredictionCubit(_QuizRepo(_settledQuiz), SecureGameStorage());
    addTearDown(cubit.close);

    await cubit.saveDraft(_match.id, 'main', const {'q1': 1, 'q2': 1});
    final settlement = await cubit.settle(_match.id);

    expect(settlement.xp, 0);
    expect(cubit.state.predictionFor(_match.id)?.status, PredictionStatus.open);
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
    expect(find.text('Will'), findsNothing);
    expect(find.text('YES'), findsNothing);

    await _pumpFrames(tester, const Duration(seconds: 5));

    expect(find.text('Will'), findsOneWidget);
    expect(find.text('YES'), findsOneWidget);
  });

  testWidgets('a started fixture blocks a new quiz entry', (tester) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _liveMatch);

    expect(find.text('PREDICTIONS CLOSED'), findsOneWidget);
    expect(find.text('Will home win'), findsNothing);
    expect(find.text('SUBMIT QUIZ'), findsNothing);
    expect(find.text('HOLD TO LOCK'), findsNothing);
  });

  testWidgets('a finished unentered quiz shows community final results', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_settledQuiz));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _finishedMatch);

    expect(find.text('COMMUNITY // FINAL'), findsOneWidget);
    expect(find.text('36% CROWD ACCURACY'), findsOneWidget);
    expect(find.text('ACTUAL RESULT'), findsOneWidget);
    expect(find.text('CROWD PICK %'), findsOneWidget);
    expect(find.text('HOLD TO LOCK'), findsNothing);
    expect(find.text('YOUR PICK'), findsNothing);
  });

  testWidgets('finished multi-quiz hub opens the community results route', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(
      _CuratedMultiQuizRepo(_finishedMatch, _finishedCommunityQuizzes),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      BlocProvider<PredictionCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: MatchPredictionScreen(match: _finishedMatch, embedded: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('VIEW COMMUNITY RESULTS'), findsNWidgets(2));
    await tester.tap(find.text('Match Events Quiz'));
    await tester.pumpAndSettle();

    expect(find.text('COMMUNITY // FINAL'), findsOneWidget);
    expect(find.text('ACTUAL RESULT'), findsOneWidget);
  });

  testWidgets('prediction quiz keeps NEXT disabled until the current answer', (
    tester,
  ) async {
    final cubit = PredictionCubit(_QuizRepo(_quiz), SecureGameStorage());
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<PredictionCubit>.value(value: cubit),
          BlocProvider<AchievementCelebrationController>(
            create: (_) =>
                AchievementCelebrationController(SecureGameStorage()),
          ),
        ],
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 5));

    await _tapButton(tester, 'NEXT');
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Second'), findsNothing);
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
      find.text('Changes auto-save. Hold to lock before kickoff.'),
      findsOneWidget,
    );
    expect(find.text('Will home win'), findsOneWidget);
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('NEXT'), findsNothing);
    expect(find.text('NO').hitTestable(), findsNothing);
  });

  testWidgets('review row expands and auto-saves changed answer', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(_prediction(status: PredictionStatus.open));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _match);

    await tester.tap(find.text('Will home win'));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.ensureVisible(find.text('NO'));
    await tester.pump(const Duration(milliseconds: 220));
    await tester.tap(find.text('NO'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(cubit.state.predictionFor(_match.id)?.answers['q1'], 1);
    expect(find.text('ALL CHANGES SAVED'), findsOneWidget);
  });

  testWidgets('releasing lock before 1.2 seconds keeps draft editable', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(_prediction(status: PredictionStatus.open));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _match);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO LOCK')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(cubit.state.predictionFor(_match.id)?.status, PredictionStatus.open);
    expect(find.text('HOLD TO LOCK'), findsOneWidget);
    expect(find.bySemanticsLabel('PREDICTION LOCKED'), findsNothing);
  });

  testWidgets('full hold locks prediction and reveals crowd vote shares', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(_prediction(status: PredictionStatus.open));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _match);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO LOCK')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1250));
    await gesture.up();
    await _pumpFrames(tester, const Duration(milliseconds: 2500));
    await tester.pump();

    expect(
      cubit.state.predictionFor(_match.id)?.status,
      PredictionStatus.locked,
    );
    expect(find.bySemanticsLabel('PREDICTION LOCKED'), findsOneWidget);

    await _pumpFrames(tester, const Duration(seconds: 5));

    expect(find.text('CROWD PICK %'), findsAtLeastNWidgets(1));
    expect(find.text('100 TOTAL VOTES'), findsAtLeastNWidgets(1));
    expect(find.text('64% · 64 VOTES'), findsAtLeastNWidgets(1));
    expect(find.text('HOLD TO LOCK'), findsNothing);
  });

  testWidgets('failed lock persistence keeps the draft editable', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(
      _QuizRepo(_quiz),
      storage: _FailingPredictionStorage(),
    );
    cubit.seed(_prediction(status: PredictionStatus.open));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _match);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO LOCK')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1250));
    await gesture.up();
    await _pumpFrames(tester, const Duration(milliseconds: 500));
    await tester.pump();

    expect(cubit.state.predictionFor(_match.id)?.status, PredictionStatus.open);
    expect(find.text('SAVE FAILED • RETRY'), findsOneWidget);
    expect(find.bySemanticsLabel('PREDICTION LOCKED'), findsNothing);
    expect(find.text('HOLD TO LOCK'), findsOneWidget);
  });

  testWidgets('kickoff auto-locks an open draft with the kickoff seal', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(_prediction(status: PredictionStatus.open));
    addTearDown(cubit.close);
    final imminentMatch = _match.copyWith(
      kickoff: DateTime.now().subtract(const Duration(milliseconds: 1)),
    );

    await _pumpPredictionScreen(tester, cubit: cubit, match: imminentMatch);
    await _pumpFrames(tester, const Duration(milliseconds: 500));
    await tester.pump();

    expect(
      cubit.state.predictionFor(imminentMatch.id)?.status,
      PredictionStatus.locked,
    );
    expect(find.bySemanticsLabel('KICKOFF LOCK ACTIVATED'), findsOneWidget);
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
      MultiBlocProvider(
        providers: [
          BlocProvider<PredictionCubit>.value(value: cubit),
          BlocProvider<AchievementCelebrationController>(
            create: (_) =>
                AchievementCelebrationController(SecureGameStorage()),
          ),
        ],
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 5));

    await _tapOption(tester, 'YES');
    await tester.pumpAndSettle();
    await tester.tap(find.text('2x').first);
    await tester.pumpAndSettle();

    // Boosted value shows twice: the question's XP pill and the header
    // potential-XP ticker (5 base × 2x booster = 10 banked).
    expect(find.text('10'), findsNWidgets(2));

    await _tapButton(tester, 'NEXT');
    await _pumpFrames(tester, const Duration(seconds: 5));
    await _tapOption(tester, 'HOME');
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
      MultiBlocProvider(
        providers: [
          BlocProvider<PredictionCubit>.value(value: cubit),
          BlocProvider<AchievementCelebrationController>(
            create: (_) =>
                AchievementCelebrationController(SecureGameStorage()),
          ),
        ],
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 5));

    await _tapOption(tester, 'YES');
    await tester.pumpAndSettle();
    await tester.tap(find.text('2x').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('2x').first);
    await tester.pumpAndSettle();

    await _tapButton(tester, 'NEXT');
    await _pumpFrames(tester, const Duration(seconds: 5));
    await _tapOption(tester, 'HOME');
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
      MultiBlocProvider(
        providers: [
          BlocProvider<PredictionCubit>.value(value: cubit),
          BlocProvider<AchievementCelebrationController>(
            create: (_) =>
                AchievementCelebrationController(SecureGameStorage()),
          ),
        ],
        child: MaterialApp(home: MatchPredictionScreen(match: _match)),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _pumpFrames(tester, const Duration(seconds: 5));

    await _tapOption(tester, 'YES');
    await tester.pumpAndSettle();
    await tester.tap(find.text('2x').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1.5x').first);
    await tester.pumpAndSettle();

    await _tapButton(tester, 'NEXT');
    await _pumpFrames(tester, const Duration(seconds: 5));
    await _tapOption(tester, 'HOME');
    await tester.pumpAndSettle();
    await _tapButton(tester, 'SUBMIT QUIZ');
    await tester.pump();

    final multipliers = cubit.state
        .predictionFor(_match.id)
        ?.multipliersByQuestion;
    expect(multipliers, {'q1': PredictionMultiplier.x15});
  });

  testWidgets(
    'fresh submit lands on review list with lock CTA and inline picks',
    (tester) async {
      final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
      cubit.seedFixtures([_match]);
      final picksCubit = _TestPicksCubit([_marketFor(_match)]);
      addTearDown(cubit.close);
      addTearDown(picksCubit.close);

      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<PredictionCubit>.value(value: cubit),
            BlocProvider<PicksCubit>.value(value: picksCubit),
            BlocProvider<AchievementCelebrationController>(
              create: (_) =>
                  AchievementCelebrationController(SecureGameStorage()),
            ),
          ],
          child: MaterialApp(home: MatchPredictionScreen(match: _match)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      await _pumpFrames(tester, const Duration(seconds: 5));

      await _tapOption(tester, 'YES');
      await tester.pumpAndSettle();
      await _tapButton(tester, 'NEXT');
      await _pumpFrames(tester, const Duration(seconds: 5));
      await _tapOption(tester, 'HOME');
      await tester.pumpAndSettle();
      await _tapButton(tester, 'SUBMIT QUIZ');
      await tester.pump();

      await tester.pump(const Duration(milliseconds: 700));

      // We stay on the editable draft summary. Lock owns the dock while picks is
      // preserved as a calm inline route.
      expect(find.text('SAVE UPDATES'), findsNothing);
      expect(find.text('HOLD TO LOCK'), findsOneWidget);
      expect(find.text('OPEN SAME-MATCH PICKS'), findsOneWidget);

      await tester.tap(find.text('OPEN SAME-MATCH PICKS'));
      await tester.pumpAndSettle();

      expect(find.text('Home FC vs Away FC result'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('same_match_prediction_quiz_cta')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('PREDICTION QUIZ'), findsOneWidget);
    },
  );

  testWidgets('submitted review can move multiplier and auto-save', (
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

    await _tapButton(tester, 'Second question');
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('MOVE'), findsNothing);
    await tester.ensureVisible(find.text('2x').last);
    await tester.pump(const Duration(milliseconds: 220));
    final multiplierTap = find
        .ancestor(
          of: find.text('2x').last,
          matching: find.byType(GestureDetector),
        )
        .first;
    tester.widget<GestureDetector>(multiplierTap).onTap!();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

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
        status: PredictionStatus.locked,
      ),
    );
    addTearDown(cubit.close);

    final reward = await cubit.settle(_match.id);

    expect(reward.xp, 8);
    expect(reward.prizeOz, 0); // free (non-contest) quiz → no coin prize
    final prediction = cubit.state.predictionFor(_match.id);
    expect(prediction?.correctCount, 1);
    expect(prediction?.rewardEarned, 8);
  });

  test('contest settlement pays a podium finish and is idempotent', () async {
    final cubit = _TestPredictionCubit(
      _ContestRepo(_contestQuiz, _contestBoard),
    );
    cubit.seed(
      UserPrediction(
        matchId: _match.id,
        // 3 of 4 correct (all correct is option 0).
        answers: const {'q1': 0, 'q2': 0, 'q3': 0, 'q4': 1},
        submittedAt: DateTime.now(),
        status: PredictionStatus.locked,
      ),
    );
    addTearDown(cubit.close);

    final settlement = await cubit.settle(_match.id);

    // One rival scored 4 (> the player's 3) → 2nd place → 1000 Oz.
    expect(settlement.xp, 15);
    expect(settlement.rank, 2);
    expect(settlement.prizeOz, 1000);
    expect(settlement.fieldSize, 4);
    final prediction = cubit.state.predictionFor(_match.id);
    expect(prediction?.contestRank, 2);
    expect(prediction?.contestPrizeOz, 1000);

    // Re-settling never re-awards the prize.
    final again = await cubit.settle(_match.id);
    expect(again.xp, 0);
    expect(again.prizeOz, 0);
  });

  test('contest settlement pays nothing off the podium', () async {
    final cubit = _TestPredictionCubit(
      _ContestRepo(_contestQuiz, _contestBoard),
    );
    cubit.seed(
      UserPrediction(
        matchId: _match.id,
        // 0 correct → every rival finishes ahead → 4th → no prize.
        answers: const {'q1': 1, 'q2': 1, 'q3': 1, 'q4': 1},
        submittedAt: DateTime.now(),
        status: PredictionStatus.locked,
      ),
    );
    addTearDown(cubit.close);

    final settlement = await cubit.settle(_match.id);

    expect(settlement.rank, 4);
    expect(settlement.prizeOz, 0);
    final prediction = cubit.state.predictionFor(_match.id);
    expect(prediction?.contestPrizeOz, 0);
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

    expect(find.text('CROWD PICK %'), findsAtLeastNWidgets(1));
    expect(find.text('100 TOTAL VOTES'), findsAtLeastNWidgets(1));
    expect(find.text('SAVE UPDATES'), findsNothing);
  });

  testWidgets('live review shows question and player-pick status', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    final prediction = _prediction(
      matchId: _liveMatch.id,
      status: PredictionStatus.locked,
    );
    cubit.seedLiveReview(
      match: _liveMatch,
      quiz: _quiz,
      prediction: prediction,
      intel: LiveQuestionIntel(
        questionId: 'q1',
        questionState: PredictionQuestionState.live,
        pickState: PredictionPickState.leading,
        updatedAt: DateTime(2026, 7, 24, 12, 30),
      ),
    );
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _liveMatch);

    expect(find.text('LIVE'), findsAtLeastNWidgets(1));
    expect(find.text('YOUR PICK · LEADING'), findsOneWidget);
    expect(find.text('12:30'), findsOneWidget);
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
    expect(find.text('CROWD PICK %'), findsAtLeastNWidgets(1));
  });

  testWidgets('settleable review auto-reveals on open and credits XP', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_settledQuiz));
    cubit.seed(
      _prediction(matchId: _finishedMatch.id, status: PredictionStatus.locked),
    );
    final gameBloc = GameBloc(SecureGameStorage());
    addTearDown(cubit.close);
    addTearDown(gameBloc.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<PredictionCubit>.value(value: cubit),
          BlocProvider<GameBloc>.value(value: gameBloc),
        ],
        child: MaterialApp(home: MatchPredictionScreen(match: _finishedMatch)),
      ),
    );
    // Pump through the full async chain: _load → settle → savePredictions →
    // setState fires overlay. 3 pumps replaces the original 2 pre-tap +
    // 1 post-tap pumps; the 16ms render pump finishes the sequence.
    await tester.pump();
    await tester.pump();
    await tester.pump();
    final coinsBefore = gameBloc.state.coins;
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.text('RESULTS ARE IN'), findsOneWidget);

    // Header beat + two verdict flips, then the summary beat.
    await _pumpFrames(tester, const Duration(seconds: 4));
    expect(find.text('+5 XP'), findsAtLeastNWidgets(1));
    expect(find.text('CONTINUE'), findsOneWidget);

    await tester.tap(find.text('CONTINUE'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('MATCH INTEL // FINAL'), findsOneWidget);
    expect(find.text('YOU VS FIELD'), findsOneWidget);
    expect(find.text('ACCURACY DUEL'), findsOneWidget);
    expect(find.text('CROWD VS REALITY'), findsOneWidget);
    expect(find.text('#2/3'), findsOneWidget);
    expect(find.text('36% OVERALL'), findsOneWidget);
    expect(find.text('DONE'), findsOneWidget);

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();

    expect(find.text('MATCH INTEL // FINAL'), findsNothing);
    expect(
      cubit.state.predictionFor(_finishedMatch.id)?.status,
      PredictionStatus.settled,
    );
    // q1 was wrong, q2 right → 5 XP credited to progression, no coins.
    expect(gameBloc.state.progression.totalXP, 5);
    expect(gameBloc.state.coins, coinsBefore);
  });

  testWidgets('quiz top bar no longer exposes standalone leaderboard button', (
    tester,
  ) async {
    final cubit = _TestPredictionCubit(_QuizRepo(_quiz));
    cubit.seed(_prediction(status: PredictionStatus.open));
    addTearDown(cubit.close);

    await _pumpPredictionScreen(tester, cubit: cubit, match: _match);

    expect(find.byIcon(Icons.emoji_events_outlined), findsNothing);
    expect(find.text('MATCH LEADERBOARD'), findsNothing);
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

class _QuizRepo implements PredictionRepository {
  const _QuizRepo(this.quiz);

  final PredictionQuiz quiz;

  @override
  Future<List<League>> leagues() async => const [];

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async =>
      const [];

  @override
  Future<List<SportMatch>> enrichFixturesForSport(
    List<SportMatch> fixtures,
    Sport sport,
  ) async => fixtures;

  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) async =>
      matchId == quiz.matchId ? [quiz] : const [];

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) async =>
      matchId == quiz.matchId && quizId == quiz.id ? quiz : null;

  @override
  Future<List<TeamStanding>> standings(String leagueId) async => const [];

  @override
  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String quizId,
    String questionId,
  ) async => PredictionVoteBreakdown(
    matchId: matchId,
    questionId: questionId,
    totals: const {0: 64, 1: 36},
  );

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async => const [
    MatchPredictionLeaderboardEntry(
      rank: 1,
      name: 'You',
      points: 640,
      correct: 4,
    ),
    MatchPredictionLeaderboardEntry(
      rank: 2,
      name: 'Maya',
      points: 610,
      correct: 2,
    ),
    MatchPredictionLeaderboardEntry(
      rank: 3,
      name: 'Dev',
      points: 580,
      correct: 1,
    ),
  ];
}

class _CuratedMultiQuizRepo extends _QuizRepo {
  _CuratedMultiQuizRepo(this.fixture, this.quizzes) : super(_quiz);

  final SportMatch fixture;
  final List<PredictionQuiz> quizzes;

  @override
  Future<List<SportMatch>> fixtures({DateTime? day, Sport? sport}) async =>
      sport == null || sport == fixture.sport ? [fixture] : const [];

  @override
  Future<List<PredictionQuiz>> quizzesFor(String matchId) async =>
      matchId == fixture.id ? quizzes : const [];

  @override
  Future<PredictionQuiz?> quizFor(String matchId, String quizId) async {
    if (matchId != fixture.id) return null;
    for (final quiz in quizzes) {
      if (quiz.id == quizId) return quiz;
    }
    return null;
  }
}

/// [_QuizRepo] with a caller-supplied contest leaderboard, for settlement tests.
class _ContestRepo extends _QuizRepo {
  const _ContestRepo(super.quiz, this.board);

  final List<MatchPredictionLeaderboardEntry> board;

  @override
  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
    String quizId,
  ) async => board;
}

class _PickRepo implements PickRepository {
  const _PickRepo(this._markets);

  final List<PickMarket> _markets;

  @override
  Future<List<PickMarket>> markets() async => _markets;

  @override
  Future<PickMarket?> marketById(String marketId) async {
    for (final market in _markets) {
      if (market.id == marketId) return market;
    }
    return null;
  }
}

class _TestPicksCubit extends PicksCubit {
  _TestPicksCubit(List<PickMarket> markets)
    : super(_PickRepo(markets), SecureGameStorage()) {
    emit(const PicksState().copyWith(loading: false, markets: markets));
  }
}

class _TestPredictionCubit extends PredictionCubit {
  _TestPredictionCubit(
    PredictionRepository repository, {
    SecureGameStorage? storage,
  }) : super(repository, storage ?? _MemorySecureGameStorage());

  void seed(UserPrediction prediction) {
    emit(state.copyWith(predictions: {prediction.key: prediction}));
  }

  void seedFixtures(List<SportMatch> fixtures) {
    emit(state.copyWith(fixtures: fixtures));
  }

  @override
  Future<void> refreshMatch(String matchId) async {}

  void seedLiveReview({
    required SportMatch match,
    required PredictionQuiz quiz,
    required UserPrediction prediction,
    required LiveQuestionIntel intel,
  }) {
    emit(
      state.copyWith(
        fixtures: [match],
        quizzes: {predictionStorageKey(match.id, quiz.id): quiz},
        predictions: {prediction.key: prediction},
        questionIntel: {
          predictionQuestionIntelKey(match.id, quiz.id, intel.questionId):
              intel,
        },
      ),
    );
  }
}

class _MemorySecureGameStorage extends SecureGameStorage {
  @override
  Future<void> savePredictions(List<UserPrediction> predictions) async {}
}

class _FailingPredictionStorage extends SecureGameStorage {
  @override
  Future<void> savePredictions(List<UserPrediction> predictions) async {
    throw StateError('simulated persistence failure');
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

PickMarket _marketFor(SportMatch match) => PickMarket(
  id: '${match.id}_winner',
  question: '${match.home.name} vs ${match.away.name} result',
  type: PickMarketType.match,
  sport: match.sport,
  leagueId: match.leagueId,
  leagueLabel: 'TEST',
  status: PickMarketStatus.upcoming,
  outcomes: [
    PickOutcome(
      id: match.home.id,
      label: match.home.name,
      probabilityPercent: 55,
      color: match.home.color,
    ),
    const PickOutcome(
      id: 'draw',
      label: 'Draw',
      probabilityPercent: 20,
      color: Color(0xff64748b),
    ),
    PickOutcome(
      id: match.away.id,
      label: match.away.name,
      probabilityPercent: 25,
      color: match.away.color,
    ),
  ],
  volumeOz: 100,
  closesAt: match.kickoff,
  matchId: match.id,
  contextSubtitle: 'Winner after 90 minutes',
  homeLabel: match.home.name,
  awayLabel: match.away.name,
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

const _finishedCommunityQuizzes = [
  PredictionQuiz(
    id: 'main',
    matchId: 'quiz_match',
    title: 'Scoreline Quiz',
    questions: [
      QuizQuestion(
        id: 'q1',
        text: 'Final score market',
        options: ['Home win', 'Away win'],
        reward: 5,
        settledOptionIndex: 0,
      ),
    ],
  ),
  PredictionQuiz(
    id: 'events',
    matchId: 'quiz_match',
    title: 'Match Events Quiz',
    questions: [
      QuizQuestion(
        id: 'q2',
        text: 'Did both teams score?',
        options: ['Yes', 'No'],
        reward: 5,
        settledOptionIndex: 1,
      ),
    ],
  ),
];

/// A settled paid-contest quiz: 4 questions, correct answer is option 0.
const _contestQuiz = PredictionQuiz(
  matchId: 'quiz_match',
  entryFee: kScorelineQuizEntryFee,
  questions: [
    QuizQuestion(
      id: 'q1',
      text: 'q1',
      options: ['A', 'B'],
      reward: 5,
      settledOptionIndex: 0,
    ),
    QuizQuestion(
      id: 'q2',
      text: 'q2',
      options: ['A', 'B'],
      reward: 5,
      settledOptionIndex: 0,
    ),
    QuizQuestion(
      id: 'q3',
      text: 'q3',
      options: ['A', 'B'],
      reward: 5,
      settledOptionIndex: 0,
    ),
    QuizQuestion(
      id: 'q4',
      text: 'q4',
      options: ['A', 'B'],
      reward: 5,
      settledOptionIndex: 0,
    ),
  ],
);

/// Seeded field for the contest: "You" is ignored; one rival scored 4/4, so a
/// player on 3/4 places 2nd and a player on 0/4 places 4th (field of 4).
const _contestBoard = [
  MatchPredictionLeaderboardEntry(
    rank: 1,
    name: 'You',
    points: 600,
    correct: 5,
  ),
  MatchPredictionLeaderboardEntry(
    rank: 2,
    name: 'Aarav',
    points: 590,
    correct: 4,
  ),
  MatchPredictionLeaderboardEntry(
    rank: 3,
    name: 'Maya',
    points: 560,
    correct: 3,
  ),
  MatchPredictionLeaderboardEntry(
    rank: 4,
    name: 'Dev',
    points: 540,
    correct: 2,
  ),
];
