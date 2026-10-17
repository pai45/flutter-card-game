import '../../../models/prediction.dart';
import '../../../models/sport_match.dart';

class PersonalPredictionEntry {
  const PersonalPredictionEntry(this.match, this.quiz, this.prediction);
  final SportMatch match;
  final PredictionQuiz quiz;
  final UserPrediction prediction;
  bool get reveal =>
      match.status == MatchStatus.finished &&
      prediction.status != PredictionStatus.settled &&
      quiz.questions.isNotEmpty &&
      quiz.settleable;
}

List<PersonalPredictionEntry> selectPersonalPredictions({
  required Iterable<UserPrediction> predictions,
  required Map<String, SportMatch> fixtures,
  required Map<String, PredictionQuiz> quizzes,
  required bool Function(Sport) visible,
}) {
  final seen = <String>{};
  final entries = <PersonalPredictionEntry>[];
  for (final prediction in predictions) {
    if (!seen.add(prediction.key)) continue;
    final match = fixtures[prediction.matchId];
    final quiz = quizzes[prediction.key];
    if (match == null || quiz == null || !visible(match.sport)) continue;
    entries.add(PersonalPredictionEntry(match, quiz, prediction));
  }
  entries.sort((a, b) {
    final ready = (b.reveal ? 1 : 0).compareTo(a.reveal ? 1 : 0);
    if (ready != 0) return ready;
    final time = b.prediction.submittedAt.compareTo(a.prediction.submittedAt);
    return time != 0 ? time : a.prediction.key.compareTo(b.prediction.key);
  });
  return entries;
}
