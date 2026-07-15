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
}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider.value(value: gameBloc),
      BlocProvider.value(value: quizCubit),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('set start is blocked when balance is below entry cost', (
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

    await tester.tap(find.text('PLAY · 25 COINS'));
    await tester.pump();

    expect(find.text('Need 25 coins to play this quiz set.'), findsOneWidget);
    expect(find.byType(QuizPlayScreen), findsNothing);
    expect(gameBloc.state.coins, 0);
  });

  testWidgets('starting an unlocked set charges 25 coins', (tester) async {
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

    await tester.tap(find.text('PLAY · 25 COINS'));
    await tester.pump(const Duration(milliseconds: 250));

    expect(gameBloc.state.coins, 25);
  });

  testWidgets('passing a set awards XP and unlocks the next set', (
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
        child: const QuizPlayScreen(sport: Sport.football, mode: QuizMode.easy, setNumber: 1),
      ),
    );
    await tester.pump();

    final questions = buildQuizSet(Sport.football, QuizMode.easy, 1);
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final option = find.byKey(ValueKey('quiz-option-${q.correctIndex}')).last;
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      await tester.tap(
        find.text(i == questions.length - 1 ? 'SUBMIT QUIZ' : 'NEXT'),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(gameBloc.state.progression.totalXP, 50);
    expect(quizCubit.isSetUnlocked(Sport.football, QuizMode.easy, 2), isTrue);
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('failing a set hides correct answers and offers paid retry', (
    tester,
  ) async {
    final gameBloc = await _loadedGameBloc(coins: 25);
    final quizCubit = await _loadedQuizCubit();
    addTearDown(gameBloc.close);
    addTearDown(quizCubit.close);

    await tester.pumpWidget(
      _wrap(
        gameBloc: gameBloc,
        quizCubit: quizCubit,
        child: const QuizPlayScreen(sport: Sport.football, mode: QuizMode.easy, setNumber: 1),
      ),
    );
    await tester.pump();

    final questions = buildQuizSet(Sport.football, QuizMode.easy, 1);
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final wrong = (q.correctIndex + 1) % q.options.length;
      final option = find.byKey(ValueKey('quiz-option-$wrong')).last;
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pump();
      await tester.tap(
        find.text(i == questions.length - 1 ? 'SUBMIT QUIZ' : 'NEXT'),
      );
      await tester.pump(const Duration(milliseconds: 350));
    }

    expect(find.text('REPLAY REQUIRED'), findsOneWidget);
    expect(find.text('RETRY - 25 COINS'), findsOneWidget);
    expect(find.textContaining('ANS '), findsNothing);
    expect(gameBloc.state.progression.totalXP, 0);
    expect(quizCubit.isSetUnlocked(Sport.football, QuizMode.easy, 2), isFalse);

    await tester.tap(find.text('RETRY - 25 COINS'));
    await tester.pump(const Duration(milliseconds: 250));
    expect(gameBloc.state.coins, 0);
  });
}
