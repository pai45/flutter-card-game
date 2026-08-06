import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'sport_match.dart';

/// The four Knowledge Arena quiz modes. Three are skill tiers
/// (easy → medium → hard) and [global] is the world-sport capstone. Each mode
/// is a self-contained pool of answer-keyed trivia (see `quiz_trivia_bank.dart`).
///
/// Modes are progression-gated: [easy] is always open; every other mode unlocks
/// once its [unlockedBy] predecessor is *cleared* (see [QuizProgress.isUnlocked]).
enum QuizMode { easy, medium, hard, global }

const int kQuizSetCount = 50;
const int kQuizQuestionsPerSet = 10;
const int kQuizQuestionPoolPerMode = kQuizSetCount * kQuizQuestionsPerSet;
const int kQuizEntryCost = 25;

/// Best-score thresholds for the mastery stars shown on the set grid. There is
/// no pass/fail gate — finishing a set always clears it — so stars are the
/// reason to replay.
const int kQuizTwoStarScore = 7;

extension QuizModeX on QuizMode {
  /// HUD label.
  String get label => switch (this) {
    QuizMode.easy => 'EASY',
    QuizMode.medium => 'MEDIUM',
    QuizMode.hard => 'HARD',
    QuizMode.global => 'GLOBAL',
  };

  /// One-line pitch shown on the mode tile — sport-specific copy so cricket /
  /// tennis / basketball / motorsport never inherit football wording.
  String blurbFor(Sport sport) => switch (this) {
    QuizMode.easy => switch (sport) {
      Sport.football => 'FOOTBALL BASICS',
      Sport.cricket => 'CRICKET BASICS',
      Sport.tennis => 'TENNIS BASICS',
      Sport.basketball => 'BASKETBALL BASICS',
      Sport.motorsport => 'MOTORSPORT BASICS',
    },
    QuizMode.medium => switch (sport) {
      Sport.football => 'CLUBS & CUPS',
      Sport.cricket => 'TEAMS & TOURNAMENTS',
      Sport.tennis => 'SLAMS & TOURS',
      Sport.basketball => 'TEAMS & TITLES',
      Sport.motorsport => 'TEAMS & SERIES',
    },
    QuizMode.hard => 'DEEP-CUT TRIVIA',
    QuizMode.global => switch (sport) {
      Sport.football => 'WORLD FOOTBALL',
      Sport.cricket => 'WORLD CRICKET',
      Sport.tennis => 'WORLD TENNIS',
      Sport.basketball => 'WORLD BASKETBALL',
      Sport.motorsport => 'WORLD MOTORSPORT',
    },
  };

  /// XP paid per correct answer. Every correct answer pays, whatever the final
  /// score — there is no pass gate.
  int get reward => switch (this) {
    QuizMode.easy => 1,
    QuizMode.medium => 2,
    QuizMode.hard => 4,
    QuizMode.global => 5,
  };

  /// Accent colour — follows the glow/colour discipline: success→amber→danger
  /// climb the skill ladder, violet marks the global capstone.
  Color get accent => switch (this) {
    QuizMode.easy => Cyber.lime,
    QuizMode.medium => Cyber.amber,
    QuizMode.hard => Cyber.danger,
    QuizMode.global => Cyber.violet,
  };

  /// Easy uses the sport glyph; medium/hard/global keep the ladder icons.
  IconData iconFor(Sport sport) => switch (this) {
    QuizMode.easy => switch (sport) {
      Sport.football => Icons.sports_soccer,
      Sport.cricket => Icons.sports_cricket,
      Sport.tennis => Icons.sports_tennis,
      Sport.basketball => Icons.sports_basketball,
      Sport.motorsport => Icons.sports_motorsports,
    },
    QuizMode.medium => Icons.emoji_events_outlined,
    QuizMode.hard => Icons.local_fire_department_outlined,
    QuizMode.global => Icons.public,
  };

  /// Legacy mode-ladder dependency. Quiz categories are all open;
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
    this.completed = false,
    this.bestCorrect = 0,
    this.attempts = 0,
  });

  /// The persisted key stays `passed` (and still falls back to the older
  /// `cleared`) so saves written before the pass gate was removed keep loading.
  factory QuizSetProgress.fromJson(Map<String, dynamic> json) =>
      QuizSetProgress(
        completed: json['passed'] as bool? ?? json['cleared'] as bool? ?? false,
        bestCorrect: json['bestCorrect'] as int? ?? 0,
        attempts: json['attempts'] as int? ?? json['played'] as int? ?? 0,
      );

  /// True once the player has answered every question in the set once. Any
  /// score completes it — the score only decides [stars].
  final bool completed;
  final int bestCorrect;
  final int attempts;

  bool get hasRun => attempts > 0;
  double get bestPct => bestCorrect / kQuizQuestionsPerSet;

  /// Mastery grade, 0–3. A flawless run is the only way to three stars.
  int get stars {
    if (bestCorrect >= kQuizQuestionsPerSet) return 3;
    if (bestCorrect >= kQuizTwoStarScore) return 2;
    if (bestCorrect > 0) return 1;
    return 0;
  }

  bool get mastered => stars >= 3;

  QuizSetProgress merge({required int correct}) {
    return QuizSetProgress(
      completed: true,
      bestCorrect: correct > bestCorrect ? correct : bestCorrect,
      attempts: attempts + 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'passed': completed,
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
          completed: legacyCleared,
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
    return setProgress(setNumber - 1).completed;
  }

  int get completedCount =>
      sets.entries.where((entry) => entry.value.completed).length;

  /// Total mastery stars banked across the mode's 50 sets (max 150).
  int get starCount => sets.values.fold(0, (sum, set) => sum + set.stars);

  int get maxStars => kQuizSetCount * 3;

  bool get cleared => completedCount >= kQuizSetCount;
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

  /// Returns an updated copy with [mode]'s result folded in.
  ///
  /// [newlyCleared] is true when this run completed the set for the first time
  /// (so the reveal can play a "SET N+1 UNLOCKED" beat), [stars] is the set's
  /// mastery grade afterwards and [starsGained] is how many this run added on
  /// top of the previous best. The reveal reads all three from here rather than
  /// re-reading cubit state after an await, so they can never disagree.
  ({QuizProgress progress, bool newlyCleared, int stars, int starsGained})
  record(
    QuizMode mode, {
    required int correct,
    required int total,
    int setNumber = 1,
  }) {
    final before = forMode(mode);
    final beforeSet = before.setProgress(setNumber);
    final after = before.recordSet(setNumber, correct: correct);
    final afterSet = after.setProgress(setNumber);
    return (
      progress: QuizProgress({...byMode, mode: after}),
      newlyCleared: !beforeSet.completed && afterSet.completed,
      stars: afterSet.stars,
      starsGained: afterSet.stars - beforeSet.stars,
    );
  }

  Map<String, dynamic> toJson() => {
    for (final entry in byMode.entries) entry.key.name: entry.value.toJson(),
  };
}
