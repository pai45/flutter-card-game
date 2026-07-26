import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// The World Cup third-place play-off (France 4-6 England, ESPN event 760516)
/// is seeded as a finished fixture with a locked prediction, so the Predict tab
/// shows the quiz in its "over" state and offers the settlement reveal. These
/// tests pin the settled answers to the real result and the XP the reveal
/// credits — the numbers are the whole point of the demo, so they should fail
/// loudly if the fixture or the answers drift.
void main() {
  const matchId = '760516';

  Future<PredictionQuiz> mainQuiz() async {
    final repository = MockPredictionRepository();
    final quiz = await repository.quizFor(matchId, kDefaultPredictionQuizId);
    expect(quiz, isNotNull, reason: 'the play-off must expose a main quiz');
    return quiz!;
  }

  test('the fixture is finished with the real 4-6 scoreline', () async {
    final repository = MockPredictionRepository();
    final fixtures = await repository.fixtures();
    final match = fixtures.singleWhere((m) => m.id == matchId);

    expect(match.home.name, 'France');
    expect(match.away.name, 'England');
    expect(match.homeScore, '4');
    expect(match.awayScore, '6');
    expect(match.status, MatchStatus.finished);
    expect(match.teamStats, isNotNull);
    expect(match.teamStats, isNotEmpty);
  });

  test('the quiz is settleable — every answer is known', () async {
    final quiz = await mainQuiz();
    expect(
      quiz.settleable,
      isTrue,
      reason: 'an unsettleable quiz reveals nothing and credits no XP',
    );
    for (final question in quiz.questions) {
      expect(question.isSettled, isTrue, reason: '${question.id} is unsettled');
    }
  });

  test('settled answers match what actually happened', () async {
    final quiz = await mainQuiz();
    final byId = {for (final q in quiz.questions) q.id: q};

    // France 4, England 6.
    expect(byId['q1']!.settledScoreEncoded, ScoreAnswer.encode(4, 6));
    // England won.
    expect(byId['q2']!.settledOptionIndex, 2);
    // Both scored.
    expect(byId['q3']!.settledOptionIndex, 0);
    // Ten goals — over 4.5.
    expect(byId['q4']!.settledOptionIndex, 0);
    // Declan Rice put England ahead in the 3rd minute.
    expect(byId['q5']!.settledOptionIndex, 1);
  });

  test('the seeded prediction is locked so the reveal is still pending', () {
    final predictions = <String, UserPrediction>{};
    PredictionCubit.applyHistoryDemos(predictions);

    final demo = predictions[predictionStorageKey(
      matchId,
      kDefaultPredictionQuizId,
    )];
    expect(demo, isNotNull, reason: 'no demo prediction to reveal');
    expect(
      demo!.status,
      PredictionStatus.locked,
      reason: 'settled would skip the reveal cinematic entirely',
    );
  });

  test('revealing credits 175 XP for 4 of 5 correct', () async {
    final quiz = await mainQuiz();
    final predictions = <String, UserPrediction>{};
    PredictionCubit.applyHistoryDemos(predictions);
    final demo = predictions[predictionStorageKey(
      matchId,
      kDefaultPredictionQuizId,
    )]!;

    // Mirrors PredictionCubit.settle's scoring loop.
    var correct = 0;
    var reward = 0;
    for (final question in quiz.questions) {
      final picked = demo.answers[question.id];
      if (picked == null) continue;
      final answer = question.isScorePrediction
          ? question.settledScoreEncoded
          : question.settledOptionIndex;
      if (answer != null && picked == answer) {
        correct++;
        reward += question.reward;
      }
    }

    expect(correct, 4);
    expect(reward, 175);
    // The exact score is the deliberate miss — 2-1 predicted, 4-6 actual.
    expect(demo.answers['q1'], ScoreAnswer.encode(2, 1));
    expect(quiz.maxReward, 275);
  });
}
