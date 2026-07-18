import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/quiz/quiz_cubit.dart';
import 'package:card_game/models/quiz_trivia.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/screens/quiz/quiz_lobby_screen.dart';
import 'package:card_game/screens/quiz/quiz_play_screen.dart';
import 'package:card_game/services/quiz_trivia_bank.dart';
import 'package:card_game/services/secure_storage_service.dart';
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

Future<void> _answerSet(
  WidgetTester tester,
  List<TriviaQuestion> questions, {
  required bool correctly,
}) async {
  for (var i = 0; i < questions.length; i++) {
    final question = questions[i];
    final optionIndex = correctly
        ? question.correctIndex
        : (question.correctIndex + 1) % question.options.length;
    final option = find.byKey(ValueKey('quiz-option-$optionIndex')).last;
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pump();
    await tester.tap(
      find.text(i == questions.length - 1 ? 'REVIEW ANSWERS' : 'NEXT'),
    );
    await tester.pump(const Duration(milliseconds: 280));
  }
  expect(find.byKey(const ValueKey('quiz-review-stage')), findsOneWidget);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
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

    await tester.tap(find.byKey(const ValueKey('quiz-next-challenge-button')));
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

    await tester.tap(find.byKey(const ValueKey('quiz-next-challenge-button')));
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
    expect(find.text('CLEARED'), findsOneWidget);
    expect(find.text('RETRY'), findsOneWidget);
    expect(find.text('CLEAR 2'), findsWidgets);

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
        child: const QuizPlayScreen(sport: Sport.cricket, mode: QuizMode.easy),
      ),
    );
    await tester.pump();

    expect(find.text('CRICKET QUIZ'), findsOneWidget);
    expect(find.text('MAX REWARD'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quiz-option-0')));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Exit quiz'));
    await tester.pumpAndSettle();
    expect(find.text('EXIT QUIZ?'), findsOneWidget);
    expect(find.textContaining('will not be refunded'), findsOneWidget);
  });

  testWidgets('review stage preserves answers and can reopen a question', (
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
    await _answerSet(tester, questions, correctly: true);

    expect(
      find.text('ANSWER · ${questions.first.correctLabel}'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('quiz-review-0')));
    await tester.pump(const Duration(milliseconds: 280));
    expect(find.text(questions.first.prompt), findsWidgets);
    expect(find.byKey(const ValueKey('quiz-option-0')), findsOneWidget);
  });

  testWidgets('passing a set awards XP and unlocks the next set', (
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
    await _answerSet(tester, questions, correctly: true);
    await tester.tap(find.byKey(const ValueKey('quiz-lock-answers')));
    await tester.pump(const Duration(milliseconds: 450));

    expect(gameBloc.state.progression.totalXP, 50);
    expect(quizCubit.isSetUnlocked(Sport.football, QuizMode.easy, 2), isTrue);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('PERFECT SET'), findsOneWidget);
    expect(find.text('SET 2 UNLOCKED'), findsOneWidget);
    expect(find.text('CONTINUE TO SETS'), findsOneWidget);
  });

  testWidgets('failing hides answers and offers a paid retry', (tester) async {
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
    await _answerSet(tester, questions, correctly: false);
    await tester.tap(find.byKey(const ValueKey('quiz-lock-answers')));
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('SET NOT CLEARED'), findsOneWidget);
    expect(find.text('RETRY · 25 COINS'), findsOneWidget);
    expect(find.byKey(const ValueKey('quiz-answer-review')), findsNothing);
    expect(gameBloc.state.progression.totalXP, 0);
    expect(quizCubit.isSetUnlocked(Sport.football, QuizMode.easy, 2), isFalse);

    await tester.tap(find.text('RETRY · 25 COINS'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(gameBloc.state.coins, 0);
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
    expect(find.text('MAX REWARD'), findsOneWidget);
  });
}
