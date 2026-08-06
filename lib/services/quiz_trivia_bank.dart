import 'dart:math';

import '../models/quiz_trivia.dart';
import '../models/sport_match.dart';
import 'quiz_bank.dart';

/// Answer-keyed trivia for the standalone Knowledge Arena quizzes.
///
/// The questions themselves are authored data, not code — they live in
/// `assets/quiz/<sport>_<mode>.json` and are loaded by [QuizBank]. This file is
/// only the set-indexing layer on top of that pool.
///
/// Unlike `football_question_bank.dart` (fixture-bound prediction markets that
/// settle later), every question here has a known [TriviaQuestion.correctIndex].
///
/// Callers must `await QuizBank.ensureLoaded(sport, mode)` first; the builders
/// below are synchronous reads of the cache so the play screen can lay out on
/// its first frame.

/// The 10 questions behind [setNumber] (1…[kQuizSetCount]).
///
/// Deterministic — the same set always deals the same questions in the same
/// order, which is what makes chasing a 3-star run worthwhile. Returns an empty
/// list when the pool isn't loaded, or when the set is past the authored range.
List<TriviaQuestion> buildQuizSet(Sport sport, QuizMode mode, int setNumber) {
  final pool = QuizBank.pool(sport, mode);
  final clampedSet = setNumber.clamp(1, kQuizSetCount);
  final start = (clampedSet - 1) * kQuizQuestionsPerSet;
  if (start + kQuizQuestionsPerSet > pool.length) return const [];
  return List<TriviaQuestion>.unmodifiable(
    pool.sublist(start, start + kQuizQuestionsPerSet),
  );
}

/// Legacy shuffled-session builder: draws [count] questions from anywhere in the
/// mode's pool. Superseded by the numbered set ladder, kept for callers that
/// want a one-off random run.
List<TriviaQuestion> buildQuizSession(
  Sport sport,
  QuizMode mode, {
  int count = 8,
  int? seed,
}) {
  final pool = List<TriviaQuestion>.of(QuizBank.pool(sport, mode));
  if (pool.isEmpty) return const [];
  final rng = Random(seed ?? DateTime.now().microsecondsSinceEpoch);
  pool.shuffle(rng);
  return pool.take(count.clamp(1, pool.length)).toList(growable: false);
}

/// How many questions are authored for [sport]/[mode] — used by the lobby to
/// size sessions and to tell full sets apart from upcoming ones.
int quizPoolSize(Sport sport, QuizMode mode) => QuizBank.pool(sport, mode).length;
