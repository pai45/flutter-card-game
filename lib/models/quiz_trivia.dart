import 'package:flutter/material.dart';

import '../config/theme.dart';

/// The four Football Quiz modes. Three are skill tiers (easy → medium → hard)
/// and [global] is the world-football capstone, unlocked after hard. Each mode
/// is a self-contained pool of answer-keyed trivia (see `quiz_trivia_bank.dart`).
///
/// Modes are progression-gated: [easy] is always open; every other mode unlocks
/// once its [unlockedBy] predecessor is *cleared* (see [QuizProgress.isUnlocked]).
enum QuizMode { easy, medium, hard, global }

/// Fraction of a session a player must get right for a mode to count as
/// "cleared" (which unlocks the next mode).
const double kQuizClearThreshold = 0.6;

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

  /// XP paid per correct answer in this mode (harder = richer).
  int get reward => switch (this) {
    QuizMode.easy => 50,
    QuizMode.medium => 75,
    QuizMode.hard => 110,
    QuizMode.global => 90,
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

  /// The mode that must be cleared before this one opens (null = always open).
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

/// Persisted progress for a single mode: whether it's cleared (gates the next
/// mode) and the player's best run (shown on the tile for replay pull).
class QuizModeProgress {
  const QuizModeProgress({
    this.cleared = false,
    this.bestCorrect = 0,
    this.bestTotal = 0,
    this.played = 0,
  });

  factory QuizModeProgress.fromJson(Map<String, dynamic> json) =>
      QuizModeProgress(
        cleared: json['cleared'] as bool? ?? false,
        bestCorrect: json['bestCorrect'] as int? ?? 0,
        bestTotal: json['bestTotal'] as int? ?? 0,
        played: json['played'] as int? ?? 0,
      );

  final bool cleared;
  final int bestCorrect;
  final int bestTotal;
  final int played;

  bool get hasRun => bestTotal > 0;
  double get bestPct => bestTotal == 0 ? 0 : bestCorrect / bestTotal;

  /// Folds a fresh result into this record: bumps the play count, keeps the
  /// best run, and latches [cleared] once a run hits the threshold.
  QuizModeProgress merge({required int correct, required int total}) {
    final betterRun = bestTotal == 0 || correct / total > bestPct;
    return QuizModeProgress(
      cleared: cleared || (total > 0 && correct / total >= kQuizClearThreshold),
      bestCorrect: betterRun ? correct : bestCorrect,
      bestTotal: betterRun ? total : bestTotal,
      played: played + 1,
    );
  }

  Map<String, dynamic> toJson() => {
    'cleared': cleared,
    'bestCorrect': bestCorrect,
    'bestTotal': bestTotal,
    'played': played,
  };
}

/// The full per-mode progress map, with the unlock rules baked in.
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

  /// Easy is always open; every other mode needs its predecessor cleared.
  bool isUnlocked(QuizMode mode) {
    final pre = mode.unlockedBy;
    return pre == null || forMode(pre).cleared;
  }

  int get clearedCount =>
      QuizMode.values.where((m) => forMode(m).cleared).length;

  /// Returns an updated copy with [mode]'s result folded in. The boolean tells
  /// the caller whether [mode] crossed from not-cleared to cleared on this run
  /// (so the reveal can play a "MODE UNLOCKED" beat).
  ({QuizProgress progress, bool newlyCleared, QuizMode? unlocked}) record(
    QuizMode mode, {
    required int correct,
    required int total,
  }) {
    final before = forMode(mode);
    final after = before.merge(correct: correct, total: total);
    final next = QuizProgress({...byMode, mode: after});
    final newlyCleared = !before.cleared && after.cleared;
    // The mode this run just opened, if any (the one gated directly on [mode]).
    final unlocked = newlyCleared
        ? QuizMode.values
              .where((m) => m.unlockedBy == mode)
              .cast<QuizMode?>()
              .firstWhere((_) => true, orElse: () => null)
        : null;
    return (progress: next, newlyCleared: newlyCleared, unlocked: unlocked);
  }

  Map<String, dynamic> toJson() => {
    for (final entry in byMode.entries) entry.key.name: entry.value.toJson(),
  };
}
