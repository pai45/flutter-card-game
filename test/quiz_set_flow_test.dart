import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/quiz/quiz_cubit.dart';
import 'package:card_game/models/quiz_trivia.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/quiz/quiz_lobby_screen.dart';
import 'package:card_game/screens/quiz/quiz_play_screen.dart';
import 'package:card_game/services/quiz_bank.dart';
import 'package:card_game/services/quiz_trivia_bank.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameBloc> _loadedGameBloc({int coins = 0}) async {
  final bloc = GameBloc(SecureGameStorage())..add(GameLoaded());
  await bloc.stream.firstWhere((state) => !state.loading);
  if (coins > 0) {
    bloc.add(CoinsAdded(coins));
    await bloc.stream.firstWhere((state) => state.coins == coins);
  }
  return bloc;
}

Future<QuizCubit> _loadedQuizCubit() async {
  final cubit = QuizCubit(SecureGameStorage());
  await cubit.load();
  return cubit;
}

Widget _wrap({
  required GameBloc gameBloc,
  required QuizCubit quizCubit,
  required Widget child,
  MediaQueryData? mediaQuery,
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider.value(value: gameBloc),
      BlocProvider.value(value: quizCubit),
    ],
    child: MaterialApp(
      // The bundled ink_sparkle shader cannot be decoded by the test runtime,
      // so tapping any Material button would blow up. The app's own CTAs are
      // custom-painted; only the stock AlertDialog buttons splash.
      theme: ThemeData(splashFactory: NoSplash.splashFactory),
      builder: mediaQuery == null
          ? null
          : (context, child) => MediaQuery(
              data: mediaQuery,
              child: child ?? const SizedBox.shrink(),
            ),
      home: child,
    ),
  );
}

/// Picks an option and locks it in, leaving the screen showing that question's
/// verdict. Does not advance.
Future<void> _lockAnswer(
  WidgetTester tester,
  TriviaQuestion question, {
  required bool correctly,
}) async {
  final optionIndex = correctly
      ? question.correctIndex
      : (question.correctIndex + 1) % question.options.length;
  final option = find.byKey(ValueKey('quiz-option-$optionIndex')).last;
  await tester.ensureVisible(option);
  await tester.tap(option);
  await tester.pump();
  await tester.tap(find.text('LOCK IN'));
  await tester.pump();
  // Past the scan beat, so the verdict has landed.
  await tester.pump(const Duration(milliseconds: 280));
}

/// Plays a whole set, getting the first [correctCount] questions right.
/// Stops on the last verdict without pressing SEE RESULTS.
Future<void> _playSet(
  WidgetTester tester,
  List<TriviaQuestion> questions, {
  required int correctCount,
}) async {
  for (var i = 0; i < questions.length; i++) {
    await _lockAnswer(tester, questions[i], correctly: i < correctCount);
    if (i < questions.length - 1) {
      // Tap through rather than waiting out the 3s auto-advance charge.
      await tester.tap(find.byKey(const ValueKey('quiz-advance')));
      await tester.pump(const Duration(milliseconds: 300));
    }
  }
  expect(find.text('SEE RESULTS'), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    // Questions are asset data; the lobby preloads them in the app, so the
    // widget tests have to do the same before pumping a play screen.
    QuizBank.debugReset();
    for (final mode in QuizMode.values) {
      await QuizBank.ensureLoaded(Sport.football, mode);
    }
  });

  testWidgets('knowledge arena shows all categories and completion telemetry', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: QuizLobbyScreen(sport: Sport.football, onBack: () {}),
      ),
    );
    await tester.pump();

    expect(find.text('KNOWLEDGE ARENA'), findsWidgets);
    for (final mode in QuizMode.values) {
      expect(find.byKey(ValueKey('quiz-mode-${mode.name}')), findsOneWidget);
      expect(find.text('+${mode.reward} XP / CORRECT'), findsOneWidget);
    }
  });

  testWidgets('set entry briefing blocks play without enough coins', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizSetScreen(sport: Sport.football, mode: QuizMode.easy),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('quiz-set-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('ENTRY BRIEFING'), findsOneWidget);
    expect(find.text('NEED 25 MORE COINS'), findsWidgets);
    expect(find.byType(QuizPlayScreen), findsNothing);
    expect(gameBloc.state.coins, 0);
  });

  testWidgets('set entry is charged only after briefing confirmation', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc(coins: 50);
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizSetScreen(sport: Sport.football, mode: QuizMode.easy),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('quiz-set-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));
    expect(gameBloc.state.coins, 50);
    expect(find.text('BALANCE · 50 COINS'), findsOneWidget);

    final confirm = find.byKey(const ValueKey('quiz-confirm-entry'));
    await tester.drag(find.text('ENTRY BRIEFING'), const Offset(0, -500));
    await tester.pump(const Duration(milliseconds: 250));
    await tester.tap(confirm);
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(milliseconds: 300));

    expect(gameBloc.state.coins, 25);
    expect(find.byType(QuizPlayScreen), findsOneWidget);
  });

  testWidgets('set ladder uses chapters and explicit progress states', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);
    await quizCubit.recordResult(
      Sport.football,
      QuizMode.easy,
      setNumber: 1,
      correct: 8,
      total: kQuizQuestionsPerSet,
    );
    await quizCubit.recordResult(
      Sport.football,
      QuizMode.easy,
      setNumber: 2,
      correct: 3,
      total: kQuizQuestionsPerSet,
    );

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizSetScreen(sport: Sport.football, mode: QuizMode.easy),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('quiz-set-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-set-2')), findsOneWidget);
    // Both runs cleared their set; the score only decides mastery stars.
    expect(find.text('REPLAY · 8/10'), findsOneWidget);
    expect(find.text('REPLAY · 3/10'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('FINISH 3'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quiz-chapter-1')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('quiz-set-11')), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-set-1')), findsNothing);
  });

  testWidgets('play screen uses the active sport and protects paid progress', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizPlayScreen(sport: Sport.football, mode: QuizMode.easy),
      ),
    );
    await tester.pump();

    expect(find.text('FOOTBALL QUIZ'), findsOneWidget);
    expect(find.text('XP EARNED'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-option-0')));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Exit quiz'));
    await tester.pumpAndSettle();
    expect(find.text('EXIT QUIZ?'), findsOneWidget);
    expect(find.textContaining('will not be refunded'), findsOneWidget);
  });

  testWidgets('a sport with no authored ladder shows a holding screen', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizPlayScreen(sport: Sport.cricket, mode: QuizMode.easy),
      ),
    );
    await tester.pumpAndSettle();

    // No filler questions, no crash — the sport's chrome plus an honest
    // "not written yet" state.
    expect(find.text('CRICKET QUIZ'), findsOneWidget);
    expect(find.text('SET NOT WRITTEN YET'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-option-0')), findsNothing);
  });

  testWidgets('locking an answer reveals the verdict before advancing', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);
    final questions = buildQuizSet(Sport.football, QuizMode.easy, 1);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizPlayScreen(sport: Sport.football, mode: QuizMode.easy),
      ),
    );
    await tester.pump();

    // Nothing is graded until the answer is locked in.
    expect(find.text('SELECT ONE ANSWER'), findsOneWidget);
    expect(find.text('LOCK IN'), findsOneWidget);
    expect(find.text('SIGNAL LOCKED'), findsNothing);

    await _lockAnswer(tester, questions.first, correctly: true);

    expect(find.text('ANSWER LOCKED'), findsOneWidget);
    expect(find.text('SIGNAL LOCKED'), findsOneWidget);
    expect(
      find.text('ANSWER CONFIRMED · ${questions.first.correctLabel}'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('quiz-advance')), findsOneWidget);
    expect(find.text('LOCK IN'), findsNothing);
  });

  testWidgets('the verdict auto-advances after the charge tops up', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);
    final questions = buildQuizSet(Sport.football, QuizMode.easy, 1);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizPlayScreen(sport: Sport.football, mode: QuizMode.easy),
      ),
    );
    await tester.pump();
    await _lockAnswer(tester, questions.first, correctly: true);

    // Part-way through the charge we are still on question 1.
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('1/10'), findsOneWidget);
    expect(find.text('SIGNAL LOCKED'), findsOneWidget);

    // Once it tops up, question 2 is dealt with no tap at all.
    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('2/10'), findsOneWidget);
    expect(find.text('SELECT ONE ANSWER'), findsOneWidget);
    expect(find.text('LOCK IN'), findsOneWidget);
    expect(find.text(questions[1].prompt), findsOneWidget);
  });

  testWidgets('the last question waits for a tap instead of auto-advancing', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);
    final questions = buildQuizSet(Sport.football, QuizMode.easy, 1);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizPlayScreen(
          sport: Sport.football,
          mode: QuizMode.easy,
          setNumber: 1,
        ),
      ),
    );
    await tester.pump();
    await _playSet(tester, questions, correctCount: questions.length);

    // Well past the auto-advance window — the summary must not open itself.
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('SEE RESULTS'), findsOneWidget);
    expect(find.text('FLAWLESS SET'), findsNothing);
    expect(gameBloc.state.progression.totalXP, 0);
  });

  testWidgets('a wrong answer names the correct one immediately', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);
    final questions = buildQuizSet(Sport.football, QuizMode.easy, 1);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizPlayScreen(sport: Sport.football, mode: QuizMode.easy),
      ),
    );
    await tester.pump();
    await _lockAnswer(tester, questions.first, correctly: false);

    expect(find.text('SIGNAL LOST'), findsOneWidget);
    expect(
      find.text('ANSWER WAS · ${questions.first.correctLabel}'),
      findsOneWidget,
    );
    // The answer key boots on once the tear settles.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('// CORRECT'), findsOneWidget);
  });

  testWidgets('a flawless set awards XP, three stars and the next set', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);
    final questions = buildQuizSet(Sport.football, QuizMode.easy, 1);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizPlayScreen(
          sport: Sport.football,
          mode: QuizMode.easy,
          setNumber: 1,
        ),
      ),
    );
    await tester.pump();
    await _playSet(tester, questions, correctCount: questions.length);
    await tester.tap(find.text('SEE RESULTS'));
    await tester.pump(const Duration(milliseconds: 450));

    // EASY pays 1 XP per correct answer.
    expect(gameBloc.state.progression.totalXP, 10);
    expect(quizCubit.isSetUnlocked(Sport.football, QuizMode.easy, 2), isTrue);
    expect(quizCubit.setProgressFor(Sport.football, QuizMode.easy, 1).stars, 3);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('FLAWLESS SET'), findsOneWidget);
    expect(find.text('+3 STARS EARNED'), findsOneWidget);
    expect(find.text('SET 2 UNLOCKED'), findsOneWidget);
    expect(find.text('CONTINUE TO SETS'), findsOneWidget);
  });

  testWidgets('a low score still clears the set and pays for what was right', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc(coins: 25);
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);
    final questions = buildQuizSet(Sport.football, QuizMode.easy, 1);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizPlayScreen(
          sport: Sport.football,
          mode: QuizMode.easy,
          setNumber: 1,
        ),
      ),
    );
    await tester.pump();
    await _playSet(tester, questions, correctCount: 3);
    await tester.tap(find.text('SEE RESULTS'));
    await tester.pump(const Duration(milliseconds: 450));

    expect(gameBloc.state.progression.totalXP, 3);
    expect(quizCubit.isSetUnlocked(Sport.football, QuizMode.easy, 2), isTrue);
    expect(quizCubit.setProgressFor(Sport.football, QuizMode.easy, 1).stars, 1);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('SET CLEARED'), findsOneWidget);
    expect(find.text('SET 2 UNLOCKED'), findsOneWidget);
    // Answers are always reviewable now — nothing is withheld on a bad run.
    expect(find.byKey(const ValueKey('quiz-answer-review')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quiz-replay')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(gameBloc.state.coins, 0);
  });

  testWidgets('quitting mid-run banks earned XP but does not clear the set', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);
    final questions = buildQuizSet(Sport.football, QuizMode.medium, 1);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const QuizPlayScreen(
                      sport: Sport.football,
                      mode: QuizMode.medium,
                      setNumber: 1,
                    ),
                  ),
                ),
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    await _lockAnswer(tester, questions[0], correctly: true);
    await tester.tap(find.byKey(const ValueKey('quiz-advance')));
    await tester.pump(const Duration(milliseconds: 300));
    await _lockAnswer(tester, questions[1], correctly: true);

    await tester.tap(find.bySemanticsLabel('Exit quiz'));
    await tester.pumpAndSettle();
    expect(find.textContaining('+4 XP is banked'), findsOneWidget);

    await tester.tap(find.text('EXIT QUIZ'));
    await tester.pumpAndSettle();

    // MEDIUM pays 2 XP per correct answer; two correct were banked.
    expect(gameBloc.state.progression.totalXP, 4);
    expect(quizCubit.isSetUnlocked(Sport.football, QuizMode.medium, 2), isFalse);
    expect(
      quizCubit.setProgressFor(Sport.football, QuizMode.medium, 1).attempts,
      0,
    );
  });

  testWidgets('the star grid fits a narrow, large-text set screen', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);
    // A spread of grades so every tile state renders at once.
    const scores = [10, 8, 3, 10, 6, 9];
    for (var i = 0; i < scores.length; i++) {
      await quizCubit.recordResult(
        Sport.football,
        QuizMode.easy,
        setNumber: i + 1,
        correct: scores[i],
        total: kQuizQuestionsPerSet,
      );
    }

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        mediaQuery: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
          disableAnimations: true,
        ),
        child: const QuizSetScreen(sport: Sport.football, mode: QuizMode.easy),
      ),
    );
    await tester.pump();

    // `GameScaffold`'s header has a pre-existing 7px bottom overflow at
    // textScale >= 1.3 on a 320pt-wide screen — a bare `GameScaffold` with an
    // empty body reproduces it, so it is shared chrome, not this grid. Pin the
    // exact magnitude so the set tiles (wrapped in a FittedBox) can't quietly
    // start contributing overflow of their own.
    expect(
      tester.takeException().toString(),
      contains('overflowed by 7.0 pixels on the bottom'),
    );
    expect(find.text('PERFECT · 10/10'), findsNWidgets(2));
    expect(find.text('REPLAY · 8/10'), findsOneWidget);
    expect(find.text('REPLAY · 3/10'), findsOneWidget);
    expect(find.byType(CyberStarRating), findsWidgets);
  });

  testWidgets('quiz surfaces fit a narrow reduced-motion layout', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc();
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        mediaQuery: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(1.3),
          disableAnimations: true,
        ),
        child: const QuizPlayScreen(
          sport: Sport.football,
          mode: QuizMode.global,
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('quiz-option-0')), findsOneWidget);

    // Lock one in — the verdict tile plus the debrief strip are the tallest
    // the dock ever gets, and this is the tightest layout we support.
    final questions = buildQuizSet(Sport.football, QuizMode.global, 1);
    await _lockAnswer(tester, questions.first, correctly: false);
    expect(tester.takeException(), isNull);
    expect(find.text('SIGNAL LOST'), findsOneWidget);
    expect(find.text('XP EARNED'), findsOneWidget);
  });
}
