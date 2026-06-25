import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The four Football Quiz modes. Three are skill tiers (easy → medium → hard)
/// and [global] is the world-football capstone, unlocked after hard. Each mode
/// is a self-contained pool of answer-keyed trivia (see `quiz_trivia_bank.dart`).
///
/// Modes are progression-gated: [easy] is always open; every other mode unlocks
/// once its [unlockedBy] predecessor is *cleared* (see [QuizProgress.isUnlocked]).
enum QuizMode { easy, medium, hard, global }

const int kQuizSetCount = 50;
const int kQuizQuestionsPerSet = 10;
const int kQuizQuestionPoolPerMode = kQuizSetCount * kQuizQuestionsPerSet;
const int kQuizEntryCost = 25;
const int kQuizMaxWrongToPass = 5;

bool quizSetPassed({required int correct, int total = kQuizQuestionsPerSet}) =>
    total - correct <= kQuizMaxWrongToPass;

extension QuizModeX on QuizMode {
  /// HUD label.
  String get label => switch (this) {
    QuizMode.easy => 'EASY',
    QuizMode.medium => 'MEDIUM',
    QuizMode.hard => 'HARD',
    QuizMode.global => 'GLOBAL',
  };

  /// One-line pitch shown on the mode tile.
  String get blurb => switch (this) {
    QuizMode.easy => 'FOOTBALL BASICS',
    QuizMode.medium => 'CLUBS & CUPS',
    QuizMode.hard => 'DEEP-CUT TRIVIA',
    QuizMode.global => 'WORLD FOOTBALL',
  };

  /// XP paid per correct answer, only when a set is passed.
  int get reward => switch (this) {
    QuizMode.easy => 5,
    QuizMode.medium => 10,
    QuizMode.hard => 20,
    QuizMode.global => 30,
  };

  /// Accent colour — follows the glow/colour discipline: success→amber→danger
  /// climb the skill ladder, violet marks the global capstone.
  Color get accent => switch (this) {
    QuizMode.easy => Cyber.lime,
    QuizMode.medium => Cyber.amber,
    QuizMode.hard => Cyber.danger,
    QuizMode.global => Cyber.violet,
  };

  IconData get icon => switch (this) {
    QuizMode.easy => Icons.sports_soccer,
    QuizMode.medium => Icons.emoji_events_outlined,
    QuizMode.hard => Icons.local_fire_department_outlined,
    QuizMode.global => Icons.public,
  };

  /// Legacy mode-ladder dependency. New Football Quiz categories are all open;
  /// set progression is gated inside each mode.
  QuizMode? get unlockedBy => switch (this) {
    QuizMode.easy => null,
    QuizMode.medium => QuizMode.easy,
    QuizMode.hard => QuizMode.medium,
    QuizMode.global => QuizMode.hard,
  };
}

/// One answer-keyed trivia question. Unlike the prediction bank's fixture-bound
/// markets, the correct answer is known up front ([correctIndex]).
class TriviaQuestion {
  const TriviaQuestion({
    required this.id,
    required this.mode,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.backgroundAsset,
  });

  final String id;
  final QuizMode mode;
  final String prompt;
  final List<String> options;
  final int correctIndex;

  /// Optional full-bleed backdrop; null falls back to the panel gradient.
  final String? backgroundAsset;

  String get correctLabel => options[correctIndex];
  String labelFor(int? index) =>
      index == null || index < 0 || index >= options.length
      ? '—'
      : options[index];
}

class QuizSetProgress {
  const QuizSetProgress({
    this.passed = false,
    this.bestCorrect = 0,
    this.attempts = 0,
  });

  factory QuizSetProgress.fromJson(Map<String, dynamic> json) =>
      QuizSetProgress(
        passed: json['passed'] as bool? ?? json['cleared'] as bool? ?? false,
        bestCorrect: json['bestCorrect'] as int? ?? 0,
        attempts: json['attempts'] as int? ?? json['played'] as int? ?? 0,
      );

  final bool passed;
  final int bestCorrect;
  final int attempts;

  bool get hasRun => attempts > 0;
  double get bestPct => bestCorrect / kQuizQuestionsPerSet;

  QuizSetProgress merge({required int correct}) {
    return QuizSetProgress(
      passed: passed || quizSetPassed(correct: correct),
      bestCorrect: correct > bestCorrect ? correct : bestCorrect,
      attempts: attempts + 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'passed': passed,
    'bestCorrect': bestCorrect,
    'attempts': attempts,
  };
}

/// Persisted progress for a single mode: 50 sequential sets, where set 1 starts
/// unlocked and each next set opens after the previous set is passed.
class QuizModeProgress {
  const QuizModeProgress({this.sets = const {}});

  factory QuizModeProgress.fromJson(Map<String, dynamic> json) {
    final rawSets = json['sets'];
    if (rawSets is Map) {
      return QuizModeProgress(
        sets: {
          for (final entry in rawSets.entries)
            int.parse(entry.key.toString()): QuizSetProgress.fromJson(
              Map<String, dynamic>.from(entry.value as Map),
            ),
        },
      );
    }

    // Backwards compatibility for the old single-run-per-mode shape: if a mode
    // had been cleared, treat set 1 as passed so returning players keep access.
    final legacyCleared = json['cleared'] as bool? ?? false;
    final legacyBest = json['bestCorrect'] as int? ?? 0;
    final legacyPlayed = json['played'] as int? ?? 0;
    if (!legacyCleared && legacyBest == 0 && legacyPlayed == 0) {
      return const QuizModeProgress();
    }
    return QuizModeProgress(
      sets: {
        1: QuizSetProgress(
          passed: legacyCleared,
          bestCorrect: legacyBest.clamp(0, kQuizQuestionsPerSet),
          attempts: legacyPlayed,
        ),
      },
    );
  }

  final Map<int, QuizSetProgress> sets;

  QuizSetProgress setProgress(int setNumber) =>
      sets[setNumber] ?? const QuizSetProgress();

  bool isSetUnlocked(int setNumber) {
    if (setNumber < 1 || setNumber > kQuizSetCount) return false;
    if (setNumber == 1) return true;
    return setProgress(setNumber - 1).passed;
  }

  int get passedCount =>
      sets.entries.where((entry) => entry.value.passed).length;

  bool get cleared => passedCount >= kQuizSetCount;
  bool get hasRun => sets.values.any((set) => set.hasRun);
  int get played => sets.values.fold(0, (sum, set) => sum + set.attempts);
  int get bestCorrect => sets.values.fold(
    0,
    (best, set) => set.bestCorrect > best ? set.bestCorrect : best,
  );
  int get bestTotal => kQuizQuestionsPerSet;
  double get bestPct => bestCorrect / kQuizQuestionsPerSet;

  QuizModeProgress recordSet(int setNumber, {required int correct}) {
    final before = setProgress(setNumber);
    return QuizModeProgress(
      sets: {
        ...sets,
        setNumber: before.merge(correct: correct),
      },
    );
  }

  Map<String, dynamic> toJson() => {
    'sets': {
      for (final entry in sets.entries) '${entry.key}': entry.value.toJson(),
    },
  };
}

/// The full per-mode progress map, with set unlock rules baked in.
class QuizProgress {
  const QuizProgress(this.byMode);

  factory QuizProgress.initial() => const QuizProgress({});

  factory QuizProgress.fromJson(Map<String, dynamic> json) => QuizProgress({
    for (final mode in QuizMode.values)
      if (json[mode.name] != null)
        mode: QuizModeProgress.fromJson(
          Map<String, dynamic>.from(json[mode.name] as Map),
        ),
  });

  final Map<QuizMode, QuizModeProgress> byMode;

  QuizModeProgress forMode(QuizMode mode) =>
      byMode[mode] ?? const QuizModeProgress();

  /// All four categories are open; numbered sets are gated inside each mode.
  bool isUnlocked(QuizMode mode) => true;

  bool isSetUnlocked(QuizMode mode, int setNumber) =>
      forMode(mode).isSetUnlocked(setNumber);

  int get clearedCount =>
      QuizMode.values.where((m) => forMode(m).cleared).length;

  /// Returns an updated copy with [mode]'s result folded in. The boolean tells
  /// the caller whether [mode] crossed from not-cleared to cleared on this run
  /// (so the reveal can play a "MODE UNLOCKED" beat).
  ({QuizProgress progress, bool newlyCleared, QuizMode? unlocked}) record(
    QuizMode mode, {
    required int correct,
    required int total,
    int setNumber = 1,
  }) {
    final before = forMode(mode);
    final beforeSet = before.setProgress(setNumber);
    final after = before.recordSet(setNumber, correct: correct);
    final next = QuizProgress({...byMode, mode: after});
    final newlyCleared =
        !beforeSet.passed && after.setProgress(setNumber).passed;
    return (progress: next, newlyCleared: newlyCleared, unlocked: null);
  }

  Map<String, dynamic> toJson() => {
    for (final entry in byMode.entries) entry.key.name: entry.value.toJson(),
  };
}
