import '../models/prediction.dart';
import '../models/sport_match.dart';

/// Per-question result glyph on the history screen.
enum QuestionOutcome { correct, wrong, pending }

/// Filter tabs on the prediction match history screen.
enum PredictionHistoryFilter { all, live, pending, out }

/// Which bucket a predicted fixture falls into for filtering.
enum PredictionHistoryBucket { live, pending, out }

QuestionOutcome questionOutcome(QuizQuestion question, UserPrediction prediction) {
  if (prediction.status == PredictionStatus.settled && question.isSettled) {
    final picked = prediction.answers[question.id];
    if (picked == null) return QuestionOutcome.pending;
    final correct = question.isScorePrediction
        ? question.settledScoreEncoded
        : question.settledOptionIndex;
    if (correct == null) return QuestionOutcome.pending;
    return picked == correct ? QuestionOutcome.correct : QuestionOutcome.wrong;
  }
  return QuestionOutcome.pending;
}

List<QuestionOutcome> questionOutcomes(
  PredictionQuiz quiz,
  UserPrediction prediction,
) => [for (final q in quiz.questions) questionOutcome(q, prediction)];

PredictionHistoryBucket historyBucket(SportMatch match, UserPrediction prediction) {
  if (match.status == MatchStatus.live) return PredictionHistoryBucket.live;
  if (prediction.status == PredictionStatus.settled) {
    return PredictionHistoryBucket.out;
  }
  return PredictionHistoryBucket.pending;
}

bool matchesHistoryFilter(
  SportMatch match,
  UserPrediction prediction,
  PredictionHistoryFilter filter,
) {
  return switch (filter) {
    PredictionHistoryFilter.all => true,
    PredictionHistoryFilter.live =>
      historyBucket(match, prediction) == PredictionHistoryBucket.live,
    PredictionHistoryFilter.pending =>
      historyBucket(match, prediction) == PredictionHistoryBucket.pending,
    PredictionHistoryFilter.out =>
      historyBucket(match, prediction) == PredictionHistoryBucket.out,
  };
}

String formatPredictionTimestamp(DateTime time) {
  final local = time.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final month = switch (local.month) {
    1 => 'JAN',
    2 => 'FEB',
    3 => 'MAR',
    4 => 'APR',
    5 => 'MAY',
    6 => 'JUN',
    7 => 'JUL',
    8 => 'AUG',
    9 => 'SEP',
    10 => 'OCT',
    11 => 'NOV',
    _ => 'DEC',
  };
  return '$hour:$minute, ${local.day} $month';
}

String formatKickoffSchedule(DateTime kickoff) {
  final local = kickoff.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  const suffixes = ['th', 'st', 'nd', 'rd', 'th', 'th', 'th', 'th', 'th', 'th'];
  final day = local.day;
  final suffix = day >= 11 && day <= 13 ? 'th' : suffixes[day % 10];
  final month = switch (local.month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    _ => 'Dec',
  };
  return '$hour:$minute, $day$suffix $month';
}
