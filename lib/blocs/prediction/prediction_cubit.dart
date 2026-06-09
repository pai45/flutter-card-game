import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/prediction.dart';
import '../../services/prediction_repository.dart';
import '../../services/secure_storage_service.dart';
import 'prediction_state.dart';

/// Owns the prediction hub's data: fixtures (from [PredictionRepository]) and
/// the user's own predictions (persisted via [SecureGameStorage]).
///
/// Reward crediting is intentionally NOT done here — settlement returns the
/// reward and the UI credits the wallet through `GameBloc` (`CoinsAdded`), so
/// the cubit stays decoupled from the game economy.
class PredictionCubit extends Cubit<PredictionState> {
  PredictionCubit(this._repository, this._storage)
    : super(const PredictionState());

  final PredictionRepository _repository;
  final SecureGameStorage _storage;

  /// Demo predictions seeded so the prediction history screen can show every
  /// lifecycle bucket (pending · live · settled) on a fresh install.
  static void applyHistoryDemos(Map<String, UserPrediction> predictions) {
    final now = DateTime.now();
    predictions['ipl_pjk_kkr'] = UserPrediction(
      matchId: 'ipl_pjk_kkr',
      answers: const {},
      submittedAt: now.subtract(const Duration(hours: 2)),
      status: PredictionStatus.open,
    );
    predictions['epl_liv_mc'] = UserPrediction(
      matchId: 'epl_liv_mc',
      answers: const {'q1': 100, 'q2': 0, 'q3': 0, 'q4': 0, 'q5': 0},
      submittedAt: DateTime(now.year, now.month, now.day - 1, 23, 34),
      status: PredictionStatus.open,
    );
    predictions['epl_cfc_new'] = UserPrediction(
      matchId: 'epl_cfc_new',
      answers: const {'q1': 201, 'q2': 0},
      submittedAt: now.subtract(const Duration(minutes: 45)),
      status: PredictionStatus.locked,
    );
    // settledHome 2-1 → encoded 201; user picked 201 on q1 (✓), mixed on rest.
    predictions['epl_mu_whu'] = UserPrediction(
      matchId: 'epl_mu_whu',
      answers: const {'q1': 201, 'q2': 0, 'q3': 0, 'q4': 2, 'q5': 1},
      submittedAt: now.subtract(const Duration(days: 3, hours: 2)),
      status: PredictionStatus.settled,
      correctCount: 3,
      rewardEarned: 20,
    );
    predictions['ipl_pjk_rcb'] = UserPrediction(
      matchId: 'ipl_pjk_rcb',
      answers: const {'q1': 0, 'q2': 0, 'q3': 1, 'q4': 0, 'q5': 0},
      submittedAt: DateTime(now.year, 1, 24, 23, 34),
      status: PredictionStatus.settled,
      correctCount: 3,
      rewardEarned: 20,
    );
  }

  Future<void> load() async {
    final leagues = await _repository.leagues();
    final fixtures = await _repository.fixtures();
    final standings = {
      for (final league in leagues)
        league.id: await _repository.standings(league.id),
    };
    final stored = await _storage.loadPredictions();
    final predictions = {for (final p in stored) p.matchId: p};
    applyHistoryDemos(predictions);
    emit(
      state.copyWith(
        loading: false,
        leagues: leagues,
        fixtures: fixtures,
        predictions: predictions,
        standingsByLeague: standings,
      ),
    );
  }

  Future<PredictionQuiz?> quizFor(String matchId) =>
      _repository.quizFor(matchId);

  Future<PredictionVoteBreakdown?> votesFor(
    String matchId,
    String questionId,
  ) => _repository.votesFor(matchId, questionId);

  Future<List<MatchPredictionLeaderboardEntry>> matchLeaderboard(
    String matchId,
  ) => _repository.matchLeaderboard(matchId);

  /// Stores (or replaces) the user's answers for a fixture.
  Future<void> submit(
    String matchId,
    Map<String, int> answers, {
    Map<String, PredictionMultiplier> multipliersByQuestion = const {},
  }) async {
    final prediction = UserPrediction(
      matchId: matchId,
      answers: answers,
      multipliersByQuestion: multipliersByQuestion,
      submittedAt: DateTime.now(),
      status: PredictionStatus.open,
    );
    final next = Map<String, UserPrediction>.from(state.predictions)
      ..[matchId] = prediction;
    emit(state.copyWith(predictions: next));
    await _storage.savePredictions(next.values.toList());
  }

  /// Mock settlement: scores the stored answers against the quiz's
  /// [QuizQuestion.settledOptionIndex] and returns the coins earned so the
  /// caller can credit the wallet. Returns 0 if nothing to settle.
  Future<int> settle(String matchId) async {
    final prediction = state.predictions[matchId];
    if (prediction == null || prediction.status == PredictionStatus.settled) {
      return 0;
    }
    final quiz = await _repository.quizFor(matchId);
    if (quiz == null || !quiz.settleable) return 0;

    var correct = 0;
    var reward = 0;
    for (final q in quiz.questions) {
      final picked = prediction.answers[q.id];
      if (picked == null) continue;
      final correctAnswer = q.isScorePrediction
          ? q.settledScoreEncoded
          : q.settledOptionIndex;
      if (correctAnswer != null && picked == correctAnswer) {
        correct++;
        reward +=
            prediction.multipliersByQuestion[q.id]?.applyTo(q.reward) ??
            q.reward;
      }
    }

    final settled = prediction.copyWith(
      status: PredictionStatus.settled,
      correctCount: correct,
      rewardEarned: reward,
    );
    final next = Map<String, UserPrediction>.from(state.predictions)
      ..[matchId] = settled;
    emit(state.copyWith(predictions: next));
    await _storage.savePredictions(next.values.toList());
    return reward;
  }
}
