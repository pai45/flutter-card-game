import 'package:card_game/blocs/quiz/quiz_cubit.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/quiz_trivia.dart';
import 'package:card_game/services/quiz_bank.dart';
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

    test('finishing a set unlocks exactly the next set in that mode', () {
      final result = QuizProgress.initial().record(
        QuizMode.easy,
        setNumber: 1,
        correct: 5,
        total: kQuizQuestionsPerSet,
      );
      expect(result.newlyCleared, isTrue);
      expect(result.starsGained, 1);
      expect(result.progress.isSetUnlocked(QuizMode.easy, 2), isTrue);
      expect(result.progress.isSetUnlocked(QuizMode.easy, 3), isFalse);
      expect(result.progress.isSetUnlocked(QuizMode.medium, 2), isFalse);
    });

    test('a low-scoring run still clears the set and unlocks the next', () {
      final result = QuizProgress.initial().record(
        QuizMode.easy,
        setNumber: 1,
        correct: 3,
        total: kQuizQuestionsPerSet,
      );
      final set = result.progress.forMode(QuizMode.easy).setProgress(1);
      expect(result.newlyCleared, isTrue);
      expect(set.attempts, 1);
      expect(set.bestCorrect, 3);
      expect(set.completed, isTrue);
      expect(set.stars, 1);
      expect(result.progress.isSetUnlocked(QuizMode.easy, 2), isTrue);
    });

    test('a scoreless run clears the set but earns no stars', () {
      final result = QuizProgress.initial().record(
        QuizMode.easy,
        setNumber: 1,
        correct: 0,
        total: kQuizQuestionsPerSet,
      );
      final set = result.progress.forMode(QuizMode.easy).setProgress(1);
      expect(set.completed, isTrue);
      expect(set.stars, 0);
      expect(result.starsGained, 0);
      expect(result.progress.isSetUnlocked(QuizMode.easy, 2), isTrue);
    });
  });

  group('QuizSetProgress', () {
    test('mastery stars grade the best run', () {
      int starsFor(int correct) =>
          const QuizSetProgress().merge(correct: correct).stars;
      expect(starsFor(0), 0);
      expect(starsFor(1), 1);
      expect(starsFor(6), 1);
      expect(starsFor(7), 2);
      expect(starsFor(9), 2);
      expect(starsFor(10), 3);
      expect(const QuizSetProgress().merge(correct: 10).mastered, isTrue);
      expect(const QuizSetProgress().merge(correct: 9).mastered, isFalse);
    });

    test('keeps the best run and counts attempts', () {
      final after = const QuizSetProgress()
          .merge(correct: 4)
          .merge(correct: 7)
          .merge(correct: 2);
      expect(after.bestCorrect, 7);
      expect(after.attempts, 3);
      expect(after.completed, isTrue);
      expect(after.stars, 2);
    });

    test('legacy saves keyed on `passed` still load as completed', () {
      final restored = QuizSetProgress.fromJson(const {
        'passed': true,
        'bestCorrect': 8,
        'attempts': 2,
      });
      expect(restored.completed, isTrue);
      expect(restored.stars, 2);
      expect(restored.toJson()['passed'], isTrue);
    });

    test('mode totals track completions and stars separately', () {
      final progress = const QuizModeProgress()
          .recordSet(1, correct: 10)
          .recordSet(2, correct: 3);
      expect(progress.completedCount, 2);
      expect(progress.starCount, 4);
      expect(progress.maxStars, kQuizSetCount * 3);
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
      expect(outcome.starsGained, 2);
      expect(cubit.isSetUnlocked(Sport.football, QuizMode.easy, 2), isTrue);
      expect(cubit.setProgressFor(Sport.football, QuizMode.easy, 1).bestCorrect, 8);

      final reloaded = await _loaded();
      addTearDown(reloaded.close);
      expect(reloaded.isSetUnlocked(Sport.football, QuizMode.easy, 2), isTrue);
      expect(reloaded.setProgressFor(Sport.football, QuizMode.easy, 1).completed, isTrue);
      expect(reloaded.setProgressFor(Sport.football, QuizMode.easy, 1).stars, 2);
      expect(reloaded.setProgressFor(Sport.football, QuizMode.easy, 1).bestCorrect, 8);
    });
  });

  group('quiz question bank', () {
    // The bank is asset data now, so every pool has to be loaded before the
    // synchronous set builders can read it.
    setUp(() async {
      QuizBank.debugReset();
      for (final mode in QuizMode.values) {
        await QuizBank.ensureLoaded(Sport.football, mode);
      }
    });

    test('mode constants match the set ladder economy', () {
      expect(kQuizSetCount, 50);
      expect(kQuizQuestionsPerSet, 10);
      expect(kQuizQuestionPoolPerMode, 500);
      expect(kQuizEntryCost, 25);
      expect(QuizMode.easy.reward, 1);
      expect(QuizMode.medium.reward, 2);
      expect(QuizMode.hard.reward, 4);
      expect(QuizMode.global.reward, 5);
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
        expect(quizPoolSize(Sport.football, QuizMode.hard), kQuizQuestionPoolPerMode);
        expect(session.every((q) => q.mode == QuizMode.hard), isTrue);
      },
    );

    test('every football mode authors the full 50-set ladder', () {
      for (final mode in QuizMode.values) {
        expect(
          QuizBank.authoredSetCount(Sport.football, mode),
          kQuizSetCount,
          reason: 'football ${mode.name} should reach set $kQuizSetCount',
        );
      }
    });

    test('sets are dealt in band order so difficulty climbs', () {
      // Band k owns sets 10(k-1)+1..10k, so the first question of set 11 is
      // pool entry 101 — the start of band 2.
      final pool = QuizBank.pool(Sport.football, QuizMode.easy);
      expect(pool, hasLength(kQuizQuestionPoolPerMode));
      expect(buildQuizSet(Sport.football, QuizMode.easy, 1).first.id, pool[0].id);
      expect(buildQuizSet(Sport.football, QuizMode.easy, 11).first.id, pool[100].id);
      expect(buildQuizSet(Sport.football, QuizMode.easy, 50).last.id, pool[499].id);
    });

    test('every authored question is well formed', () {
      for (final mode in QuizMode.values) {
        final pool = QuizBank.pool(Sport.football, mode);
        final prompts = <String>{};
        for (final q in pool) {
          expect(q.options, hasLength(4), reason: q.prompt);
          expect(q.correctIndex, inInclusiveRange(0, 3), reason: q.prompt);
          expect(q.options.toSet(), hasLength(4), reason: q.prompt);
          expect(prompts.add(q.prompt), isTrue, reason: 'duplicate: ${q.prompt}');
        }
      }
    });

    test('an unauthored pool degrades to no playable sets', () async {
      // Sports whose ladders are not written yet must not crash or serve
      // filler — they simply have nothing to play.
      await QuizBank.ensureLoaded(Sport.cricket, QuizMode.easy);
      expect(QuizBank.authoredSetCount(Sport.cricket, QuizMode.easy), 0);
      expect(buildQuizSet(Sport.cricket, QuizMode.easy, 1), isEmpty);
    });
  });
}
