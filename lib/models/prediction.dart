/// Where a user's prediction sits in its lifecycle.
/// open    → submitted, match not started, still editable.
/// locked  → match kicked off, answers frozen, awaiting result.
/// settled → result known, [correctCount]/[rewardEarned] populated.
enum PredictionStatus { open, locked, settled }

const kDefaultPredictionQuizId = 'main';

/// Oz-coin entry fee to lock in a Scoreline Quiz (paid-contest) prediction.
const int kScorelineQuizEntryFee = 25;

/// Oz-coin prize pool for a Scoreline Quiz contest, indexed by finish rank
/// (rank 1 → 2000, rank 2 → 1000, rank 3 → 500; everyone else wins nothing).
const List<int> kScorelineContestPrizes = [2000, 1000, 500];

/// Prize for finishing a contest at [rank] (1-based). Returns 0 off the podium.
int scorelineContestPrizeFor(int rank) =>
    (rank >= 1 && rank <= kScorelineContestPrizes.length)
    ? kScorelineContestPrizes[rank - 1]
    : 0;

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
    this.forcedVoid = false,
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

  /// Set by the auto-settlement engine when a finished match's real data can't
  /// support this question (e.g. a cricket scorecard with no six-count
  /// breakdown). A voided question counts as settled — so the quiz as a whole
  /// can still be revealed — but is excluded from scoring: no XP either way.
  /// This is the per-question escape hatch that guarantees a fixture is never
  /// left permanently unsettleable just because one archetype didn't resolve.
  final bool forcedVoid;

  bool get isScorePrediction => type == QuizQuestionType.exactScore;

  int? get settledScoreEncoded {
    if (settledHomeScore == null || settledAwayScore == null) return null;
    return ScoreAnswer.encode(settledHomeScore!, settledAwayScore!);
  }

  bool get isSettled =>
      forcedVoid ||
      (isScorePrediction
          ? settledScoreEncoded != null
          : settledOptionIndex != null);

  QuizQuestion copyWith({
    int? settledOptionIndex,
    int? settledHomeScore,
    int? settledAwayScore,
    bool? forcedVoid,
  }) => QuizQuestion(
    id: id,
    text: text,
    options: options,
    reward: reward,
    type: type,
    backgroundAsset: backgroundAsset,
    settledOptionIndex: settledOptionIndex ?? this.settledOptionIndex,
    settledHomeScore: settledHomeScore ?? this.settledHomeScore,
    settledAwayScore: settledAwayScore ?? this.settledAwayScore,
    forcedVoid: forcedVoid ?? this.forcedVoid,
  );
}

/// The full quiz for one fixture.
class PredictionQuiz {
  const PredictionQuiz({
    required this.matchId,
    required this.questions,
    this.id = kDefaultPredictionQuizId,
    this.title = 'Prediction Quiz',
    this.subtitle,
    this.prizeLabel,
    this.entryFee = 0,
  });

  final String id;
  final String matchId;
  final String title;
  final String? subtitle;
  final String? prizeLabel;
  final List<QuizQuestion> questions;

  /// Oz-coin cost to enter this quiz as a paid contest. 0 = free/XP-only.
  final int entryFee;

  int get maxReward => questions.fold(0, (sum, q) => sum + q.reward);
  bool get settleable => questions.every((q) => q.isSettled);

  /// A paid coin contest (top-3 finishers win [kScorelineContestPrizes]).
  bool get isContest => entryFee > 0;
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
    this.quizId = kDefaultPredictionQuizId,
    this.multipliersByQuestion = const {},
    this.status = PredictionStatus.open,
    this.correctCount,
    this.rewardEarned = 0,
    this.contestRank,
    this.contestPrizeOz = 0,
  });

  /// questionId → selected option index.
  final Map<String, int> answers;
  final Map<String, PredictionMultiplier> multipliersByQuestion;
  final String matchId;
  final String quizId;
  final DateTime submittedAt;
  final PredictionStatus status;
  final int? correctCount;
  final int rewardEarned;

  /// Finish position in the paid-contest field once settled (1-based). Null for
  /// free quizzes or before settlement.
  final int? contestRank;

  /// Oz coins won from the contest prize pool (0 off the podium / free quizzes).
  final int contestPrizeOz;

  String get key => predictionStorageKey(matchId, quizId);

  UserPrediction copyWith({
    Map<String, int>? answers,
    Map<String, PredictionMultiplier>? multipliersByQuestion,
    String? quizId,
    PredictionStatus? status,
    int? correctCount,
    int? rewardEarned,
    int? contestRank,
    int? contestPrizeOz,
  }) => UserPrediction(
    matchId: matchId,
    quizId: quizId ?? this.quizId,
    answers: answers ?? this.answers,
    multipliersByQuestion: multipliersByQuestion ?? this.multipliersByQuestion,
    submittedAt: submittedAt,
    status: status ?? this.status,
    correctCount: correctCount ?? this.correctCount,
    rewardEarned: rewardEarned ?? this.rewardEarned,
    contestRank: contestRank ?? this.contestRank,
    contestPrizeOz: contestPrizeOz ?? this.contestPrizeOz,
  );

  Map<String, dynamic> toJson() => {
    'matchId': matchId,
    'quizId': quizId,
    'answers': answers,
    'multipliersByQuestion': multipliersByQuestion.map(
      (questionId, multiplier) => MapEntry(questionId, multiplier.jsonKey),
    ),
    'submittedAt': submittedAt.millisecondsSinceEpoch,
    'status': status.name,
    'correctCount': correctCount,
    'rewardEarned': rewardEarned,
    'contestRank': contestRank,
    'contestPrizeOz': contestPrizeOz,
  };

  factory UserPrediction.fromJson(Map<String, dynamic> json) => UserPrediction(
    matchId: json['matchId'] as String,
    quizId: json['quizId'] as String? ?? kDefaultPredictionQuizId,
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
    contestRank: json['contestRank'] as int?,
    contestPrizeOz: json['contestPrizeOz'] as int? ?? 0,
  );
}

String predictionStorageKey(String matchId, String quizId) =>
    '$matchId::$quizId';
