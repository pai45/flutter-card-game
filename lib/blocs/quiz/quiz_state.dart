import '../../models/quiz_trivia.dart';
import '../../models/sport_match.dart';

/// Holds the player's persisted Quiz progress (per-mode cleared flags
/// and best runs) keyed by Sport. [loading] is true until the first read from storage lands.
class QuizState {
  const QuizState({
    this.loading = true,
    this.progressBySport = const {},
  });

  final bool loading;
  final Map<Sport, QuizProgress> progressBySport;

  QuizProgress progressForSport(Sport sport) =>
      progressBySport[sport] ?? const QuizProgress({});

  bool isUnlocked(Sport sport, QuizMode mode) =>
      progressForSport(sport).isUnlocked(mode);
  QuizModeProgress progressFor(Sport sport, QuizMode mode) =>
      progressForSport(sport).forMode(mode);

  QuizState copyWith({bool? loading, Map<Sport, QuizProgress>? progressBySport}) => QuizState(
    loading: loading ?? this.loading,
    progressBySport: progressBySport ?? this.progressBySport,
  );
}
