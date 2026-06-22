import '../../models/quiz_trivia.dart';

/// Holds the player's persisted Football Quiz progress (per-mode cleared flags
/// and best runs). [loading] is true until the first read from storage lands.
class QuizState {
  const QuizState({
    this.loading = true,
    this.progress = const QuizProgress({}),
  });

  final bool loading;
  final QuizProgress progress;

  bool isUnlocked(QuizMode mode) => progress.isUnlocked(mode);
  QuizModeProgress progressFor(QuizMode mode) => progress.forMode(mode);

  QuizState copyWith({bool? loading, QuizProgress? progress}) => QuizState(
    loading: loading ?? this.loading,
    progress: progress ?? this.progress,
  );
}
