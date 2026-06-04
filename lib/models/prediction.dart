/// Where a user's prediction sits in its lifecycle.
/// open    → submitted, match not started, still editable.
/// locked  → match kicked off, answers frozen, awaiting result.
/// settled → result known, [correctCount]/[rewardEarned] populated.
enum PredictionStatus { open, locked, settled }

/// A single multiple-choice question attached to a fixture's quiz.
class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    this.reward = 0,
    this.settledOptionIndex,
  });

  final String id;
  final String text;
  final List<String> options;

  /// Virtual coins credited if this question is answered correctly.
  final int reward;

  /// The correct option once the match is settled (mock: baked into fixtures).
  final int? settledOptionIndex;
}

/// The full quiz for one fixture.
class PredictionQuiz {
  const PredictionQuiz({required this.matchId, required this.questions});

  final String matchId;
  final List<QuizQuestion> questions;

  int get maxReward => questions.fold(0, (sum, q) => sum + q.reward);
  bool get settleable => questions.every((q) => q.settledOptionIndex != null);
}

/// A user's submitted answers for a fixture. Persisted locally for now.
class UserPrediction {
  const UserPrediction({
    required this.matchId,
    required this.answers,
    required this.submittedAt,
    this.status = PredictionStatus.open,
    this.correctCount,
    this.rewardEarned = 0,
  });

  /// questionId → selected option index.
  final Map<String, int> answers;
  final String matchId;
  final DateTime submittedAt;
  final PredictionStatus status;
  final int? correctCount;
  final int rewardEarned;

  UserPrediction copyWith({
    Map<String, int>? answers,
    PredictionStatus? status,
    int? correctCount,
    int? rewardEarned,
  }) => UserPrediction(
    matchId: matchId,
    answers: answers ?? this.answers,
    submittedAt: submittedAt,
    status: status ?? this.status,
    correctCount: correctCount ?? this.correctCount,
    rewardEarned: rewardEarned ?? this.rewardEarned,
  );

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'answers': answers,
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
    submittedAt: DateTime.fromMillisecondsSinceEpoch(
      json['submittedAt'] as int,
    ),
    status: PredictionStatus.values.byName(
      json['status'] as String? ?? 'open',
    ),
    correctCount: json['correctCount'] as int?,
    rewardEarned: json['rewardEarned'] as int? ?? 0,
  );
}
