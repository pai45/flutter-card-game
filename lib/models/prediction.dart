/// Where a user's prediction sits in its lifecycle.
/// open    → submitted, match not started, still editable.
/// locked  → match kicked off, answers frozen, awaiting result.
/// settled → result known, [correctCount]/[rewardEarned] populated.
enum PredictionStatus { open, locked, settled }

enum QuizQuestionType { multipleChoice, exactScore }

enum PredictionMultiplier {
  x2('x2', '2x', 2.0),
  x15('x15', '1.5x', 1.5);

  const PredictionMultiplier(this.jsonKey, this.label, this.factor);

  final String jsonKey;
  final String label;
  final double factor;

  static PredictionMultiplier? fromJsonKey(String? key) {
    for (final multiplier in values) {
      if (multiplier.jsonKey == key) return multiplier;
    }
    return null;
  }

  int applyTo(int reward) => (reward * factor).ceil();
}

/// Encodes a predicted scoreline into the single-int slot used by
/// [UserPrediction.answers] (home × 100 + away, supports 0–99 each).
abstract final class ScoreAnswer {
  static int encode(int home, int away) => home * 100 + away;

  static (int home, int away) decode(int encoded) =>
      (encoded ~/ 100, encoded % 100);
}

/// A single quiz question attached to a fixture.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.text,
    this.options = const [],
    this.reward = 0,
    this.type = QuizQuestionType.multipleChoice,
    this.backgroundAsset,
    this.settledOptionIndex,
    this.settledHomeScore,
    this.settledAwayScore,
  });

  final String id;
  final String text;
  final List<String> options;
  final QuizQuestionType type;

  /// Optional full-bleed panel backdrop (shown at 50% opacity in the quiz UI).
  final String? backgroundAsset;

  /// XP credited if this question is answered correctly.
  final int reward;

  /// The correct option once the match is settled (multiple-choice only).
  final int? settledOptionIndex;

  /// The correct full-time score once settled (exact-score only).
  final int? settledHomeScore;
  final int? settledAwayScore;

  bool get isScorePrediction => type == QuizQuestionType.exactScore;

  int? get settledScoreEncoded {
    if (settledHomeScore == null || settledAwayScore == null) return null;
    return ScoreAnswer.encode(settledHomeScore!, settledAwayScore!);
  }

  bool get isSettled => isScorePrediction
      ? settledScoreEncoded != null
      : settledOptionIndex != null;
}

/// The full quiz for one fixture.
class PredictionQuiz {
  const PredictionQuiz({required this.matchId, required this.questions});

  final String matchId;
  final List<QuizQuestion> questions;

  int get maxReward => questions.fold(0, (sum, q) => sum + q.reward);
  bool get settleable => questions.every((q) => q.isSettled);
}

/// Aggregate crowd answers for one prediction question. For multiple-choice
/// questions the map key is the option index; for exact-score questions it is a
/// [ScoreAnswer] encoded score.
class PredictionVoteBreakdown {
  const PredictionVoteBreakdown({
    required this.matchId,
    required this.questionId,
    required this.totals,
  });

  final String matchId;
  final String questionId;
  final Map<int, int> totals;

  int get totalVotes => totals.values.fold(0, (sum, votes) => sum + votes);

  int votesFor(int answer) => totals[answer] ?? 0;

  double shareFor(int answer) {
    if (totalVotes == 0) return 0;
    return votesFor(answer) / totalVotes;
  }
}

class MatchPredictionLeaderboardEntry {
  const MatchPredictionLeaderboardEntry({
    required this.rank,
    required this.name,
    required this.points,
    required this.correct,
  });

  final int rank;
  final String name;
  final int points;
  final int correct;
}

Map<String, PredictionMultiplier> _predictionMultipliersFromJson(
  Object? value,
) {
  if (value is! Map) return const {};
  final multipliers = <String, PredictionMultiplier>{};
  for (final entry in value.entries) {
    final multiplier = PredictionMultiplier.fromJsonKey(
      entry.value is String ? entry.value as String : null,
    );
    if (entry.key is String && multiplier != null) {
      multipliers[entry.key as String] = multiplier;
    }
  }
  return multipliers;
}

/// A user's submitted answers for a fixture. Persisted locally for now.
class UserPrediction {
  const UserPrediction({
    required this.matchId,
    required this.answers,
    required this.submittedAt,
    this.multipliersByQuestion = const {},
    this.status = PredictionStatus.open,
    this.correctCount,
    this.rewardEarned = 0,
  });

  /// questionId → selected option index.
  final Map<String, int> answers;
  final Map<String, PredictionMultiplier> multipliersByQuestion;
  final String matchId;
  final DateTime submittedAt;
  final PredictionStatus status;
  final int? correctCount;
  final int rewardEarned;

  UserPrediction copyWith({
    Map<String, int>? answers,
    Map<String, PredictionMultiplier>? multipliersByQuestion,
    PredictionStatus? status,
    int? correctCount,
    int? rewardEarned,
  }) => UserPrediction(
    matchId: matchId,
    answers: answers ?? this.answers,
    multipliersByQuestion: multipliersByQuestion ?? this.multipliersByQuestion,
    submittedAt: submittedAt,
    status: status ?? this.status,
    correctCount: correctCount ?? this.correctCount,
    rewardEarned: rewardEarned ?? this.rewardEarned,
  );

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'answers': answers,
    'multipliersByQuestion': multipliersByQuestion.map(
      (questionId, multiplier) => MapEntry(questionId, multiplier.jsonKey),
    ),
    'submittedAt': submittedAt.millisecondsSinceEpoch,
    'status': status.name,
    'correctCount': correctCount,
    'rewardEarned': rewardEarned,
  };

  factory UserPrediction.fromJson(Map<String, dynamic> json) => UserPrediction(
    matchId: json['matchId'] as String,
    answers: (json['answers'] as Map).map(
      (key, value) => MapEntry(key as String, value as int),
    ),
    multipliersByQuestion: _predictionMultipliersFromJson(
      json['multipliersByQuestion'],
    ),
    submittedAt: DateTime.fromMillisecondsSinceEpoch(
      json['submittedAt'] as int,
    ),
    status: PredictionStatus.values.byName(json['status'] as String? ?? 'open'),
    correctCount: json['correctCount'] as int?,
    rewardEarned: json['rewardEarned'] as int? ?? 0,
  );
}
