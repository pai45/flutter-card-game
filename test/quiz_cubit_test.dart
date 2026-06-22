import 'package:card_game/blocs/quiz/quiz_cubit.dart';
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

  group('QuizProgress unlock rules', () {
    test('easy is always open; the rest start locked', () {
      final progress = QuizProgress.initial();
      expect(progress.isUnlocked(QuizMode.easy), isTrue);
      expect(progress.isUnlocked(QuizMode.medium), isFalse);
      expect(progress.isUnlocked(QuizMode.hard), isFalse);
      expect(progress.isUnlocked(QuizMode.global), isFalse);
    });

    test('clearing a mode unlocks exactly its successor', () {
      final result = QuizProgress.initial().record(
        QuizMode.easy,
        correct: 6,
        total: 8,
      );
      expect(result.newlyCleared, isTrue);
      expect(result.unlocked, QuizMode.medium);
      expect(result.progress.isUnlocked(QuizMode.medium), isTrue);
      // Two tiers down stays locked until medium is cleared too.
      expect(result.progress.isUnlocked(QuizMode.hard), isFalse);
    });

    test('a sub-threshold run does not clear or unlock', () {
      final result = QuizProgress.initial().record(
        QuizMode.easy,
        correct: 3,
        total: 8,
      );
      expect(result.newlyCleared, isFalse);
      expect(result.unlocked, isNull);
      expect(result.progress.isUnlocked(QuizMode.medium), isFalse);
    });
  });

  group('QuizModeProgress best run', () {
    test('keeps the better of two runs and counts plays', () {
      final after = const QuizModeProgress()
          .merge(correct: 4, total: 8)
          .merge(correct: 7, total: 8)
          .merge(correct: 2, total: 8);
      expect(after.bestCorrect, 7);
      expect(after.bestTotal, 8);
      expect(after.played, 3);
      expect(after.cleared, isTrue);
    });
  });

  group('QuizCubit', () {
    test('records a result and persists across reloads', () async {
      final cubit = await _loaded();
      addTearDown(cubit.close);

      expect(cubit.isUnlocked(QuizMode.medium), isFalse);
      final outcome = await cubit.recordResult(
        QuizMode.easy,
        correct: 8,
        total: 8,
      );
      expect(outcome.newlyCleared, isTrue);
      expect(outcome.unlocked, QuizMode.medium);
      expect(cubit.isUnlocked(QuizMode.medium), isTrue);
      expect(cubit.progressFor(QuizMode.easy).bestCorrect, 8);

      // A fresh cubit reading the same storage sees the unlock + best run.
      final reloaded = await _loaded();
      addTearDown(reloaded.close);
      expect(reloaded.isUnlocked(QuizMode.medium), isTrue);
      expect(reloaded.progressFor(QuizMode.easy).cleared, isTrue);
      expect(reloaded.progressFor(QuizMode.easy).bestCorrect, 8);
    });
  });

  group('buildQuizSession', () {
    test('returns answer-keyed questions only for the requested mode', () {
      for (final mode in QuizMode.values) {
        final session = buildQuizSession(mode, count: 8, seed: 7);
        expect(session, isNotEmpty);
        expect(session.length, lessThanOrEqualTo(8));
        for (final q in session) {
          expect(q.mode, mode);
          expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1));
          expect(q.options.length, greaterThanOrEqualTo(2));
        }
      }
    });

    test('same seed yields the same session (deterministic)', () {
      final a = buildQuizSession(QuizMode.hard, count: 6, seed: 42);
      final b = buildQuizSession(QuizMode.hard, count: 6, seed: 42);
      expect(a.map((q) => q.id).toList(), b.map((q) => q.id).toList());
    });
  });
}
