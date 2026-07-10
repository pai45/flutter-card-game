import 'package:card_game/blocs/quiz/quiz_cubit.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/quiz_trivia.dart';
import 'package:card_game/services/quiz_trivia_bank.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<QuizCubit> _loaded() async {
  final cubit = QuizCubit(SecureGameStorage());
  await cubit.load();
  return cubit;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('QuizProgress set unlock rules', () {
    test('all modes are open, but only set 1 starts unlocked', () {
      final progress = QuizProgress.initial();
      for (final mode in QuizMode.values) {
        expect(progress.isUnlocked(mode), isTrue);
        expect(progress.isSetUnlocked(mode, 1), isTrue);
        expect(progress.isSetUnlocked(mode, 2), isFalse);
      }
    });

    test('passing a set unlocks exactly the next set in that mode', () {
      final result = QuizProgress.initial().record(
        QuizMode.easy,
        setNumber: 1,
        correct: 5,
        total: kQuizQuestionsPerSet,
      );
      expect(result.newlyCleared, isTrue);
      expect(result.unlocked, isNull);
      expect(result.progress.isSetUnlocked(QuizMode.easy, 2), isTrue);
      expect(result.progress.isSetUnlocked(QuizMode.easy, 3), isFalse);
      expect(result.progress.isSetUnlocked(QuizMode.medium, 2), isFalse);
    });

    test('a failed run records an attempt but does not unlock next set', () {
      final result = QuizProgress.initial().record(
        QuizMode.easy,
        setNumber: 1,
        correct: 4,
        total: kQuizQuestionsPerSet,
      );
      final set = result.progress.forMode(QuizMode.easy).setProgress(1);
      expect(result.newlyCleared, isFalse);
      expect(set.attempts, 1);
      expect(set.bestCorrect, 4);
      expect(set.passed, isFalse);
      expect(result.progress.isSetUnlocked(QuizMode.easy, 2), isFalse);
    });
  });

  group('QuizSetProgress', () {
    test('pass threshold is five or fewer wrong answers', () {
      expect(quizSetPassed(correct: 5), isTrue);
      expect(quizSetPassed(correct: 4), isFalse);
    });

    test('keeps the best run and counts attempts', () {
      final after = const QuizSetProgress()
          .merge(correct: 4)
          .merge(correct: 7)
          .merge(correct: 2);
      expect(after.bestCorrect, 7);
      expect(after.attempts, 3);
      expect(after.passed, isTrue);
    });
  });

  group('QuizCubit', () {
    test('records a set result and persists across reloads', () async {
      final cubit = await _loaded();
      addTearDown(cubit.close);

      expect(cubit.isSetUnlocked(Sport.football, QuizMode.easy, 2), isFalse);
      final outcome = await cubit.recordResult(
        Sport.football,
        QuizMode.easy,
        setNumber: 1,
        correct: 8,
        total: kQuizQuestionsPerSet,
      );
      expect(outcome.newlyCleared, isTrue);
      expect(cubit.isSetUnlocked(Sport.football, QuizMode.easy, 2), isTrue);
      expect(cubit.setProgressFor(Sport.football, QuizMode.easy, 1).bestCorrect, 8);

      final reloaded = await _loaded();
      addTearDown(reloaded.close);
      expect(reloaded.isSetUnlocked(Sport.football, QuizMode.easy, 2), isTrue);
      expect(reloaded.setProgressFor(Sport.football, QuizMode.easy, 1).passed, isTrue);
      expect(reloaded.setProgressFor(Sport.football, QuizMode.easy, 1).bestCorrect, 8);
    });
  });

  group('quiz question scaffolds', () {
    test('mode constants match the set ladder economy', () {
      expect(kQuizSetCount, 50);
      expect(kQuizQuestionsPerSet, 10);
      expect(kQuizQuestionPoolPerMode, 500);
      expect(kQuizEntryCost, 25);
      expect(QuizMode.easy.reward, 5);
      expect(QuizMode.medium.reward, 10);
      expect(QuizMode.hard.reward, 20);
      expect(QuizMode.global.reward, 30);
    });

    test('buildQuizSet returns deterministic answer-keyed sets', () {
      for (final mode in QuizMode.values) {
        final first = buildQuizSet(Sport.football, mode, 12);
        final second = buildQuizSet(Sport.football, mode, 12);
        expect(first, hasLength(kQuizQuestionsPerSet));
        expect(first.map((q) => q.id), second.map((q) => q.id));
        for (final q in first) {
          expect(q.mode, mode);
          expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
          expect(q.id, contains('${mode.name}_q'));
        }
      }
    });

    test(
      'legacy random session still draws from the 500-question mode pool',
      () {
        final session = buildQuizSession(Sport.football, QuizMode.hard, count: 14, seed: 42);
        expect(session, hasLength(14));
        expect(quizPoolSize(QuizMode.hard), kQuizQuestionPoolPerMode);
        expect(session.every((q) => q.mode == QuizMode.hard), isTrue);
      },
    );
  });
}
