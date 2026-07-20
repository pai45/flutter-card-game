import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/prediction_repository.dart';
import 'package:card_game/services/quiz_archetypes.dart';
import 'package:card_game/services/settlement_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// The WNBA demo fixture (Dallas Wings 82-75 Phoenix Mercury) deliberately
/// has NO hand-authored quiz in MockPredictionRepository — its quiz is meant
/// to be built and settled entirely by QuizArchetypes/SettlementWriter, the
/// same auto-settlement engine PredictionCubit.loadSport wires in for real
/// fixtures. These tests prove basketball reaches a real resolved state
/// without anyone hand-transcribing a result — the actual point of Phase 2.
void main() {
  const matchId = 'wnba_demo_dal_phx';

  test('the fixture exists, finished, with real score/quarter data', () async {
    final repository = MockPredictionRepository();
    final fixtures = await repository.fixtures();
    final match = fixtures.singleWhere((m) => m.id == matchId);

    expect(match.sport, Sport.basketball);
    expect(match.status, MatchStatus.finished);
    expect(match.homeScore, '82');
    expect(match.awayScore, '75');
    expect(match.basketballScorecard, isNotNull);
  });

  test('the repository has no hand-authored quiz for it (by design)', () async {
    final repository = MockPredictionRepository();
    final quizzes = await repository.quizzesFor(matchId);
    expect(
      quizzes,
      isEmpty,
      reason: 'this fixture exists to prove auto-generation, not overrides',
    );
  });

  test('QuizArchetypes + SettlementWriter settle it end-to-end', () async {
    final repository = MockPredictionRepository();
    final fixtures = await repository.fixtures();
    final match = fixtures.singleWhere((m) => m.id == matchId);

    final built = PredictionQuiz(
      matchId: matchId,
      questions: QuizArchetypes.buildFor(match),
    );
    expect(built.settleable, isFalse, reason: 'freshly built, not yet settled');

    final settled = SettlementWriter.computeQuizSettlement(match, built);
    expect(settled.settleable, isTrue);

    final byId = {for (final q in settled.questions) q.id: q};
    expect(byId['winner']!.settledOptionIndex, 0); // Dallas (home) won
    expect(byId['total_points_ou']!.settledOptionIndex, 1); // 157, Under 159.5
    expect(byId['biggest_quarter']!.settledOptionIndex, 0); // Q1 margin, home
    expect(byId['winning_margin_bracket']!.settledOptionIndex, 1); // margin 7
  });

  test('the seeded demo prediction scores 3/4 for 140 XP', () async {
    final repository = MockPredictionRepository();
    final fixtures = await repository.fixtures();
    final match = fixtures.singleWhere((m) => m.id == matchId);

    final predictions = <String, UserPrediction>{};
    PredictionCubit.applyHistoryDemos(predictions);
    final demo = predictions[predictionStorageKey(matchId, kDefaultPredictionQuizId)];
    expect(demo, isNotNull);
    expect(demo!.status, PredictionStatus.locked);

    final built = PredictionQuiz(matchId: matchId, questions: QuizArchetypes.buildFor(match));
    final settled = SettlementWriter.computeQuizSettlement(match, built);

    var correct = 0;
    var reward = 0;
    for (final q in settled.questions) {
      final picked = demo.answers[q.id];
      if (picked == null || q.forcedVoid) continue;
      if (picked == q.settledOptionIndex) {
        correct++;
        reward += q.reward;
      }
    }
    expect(correct, 3);
    expect(reward, 140);
  });
}
