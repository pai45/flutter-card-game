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

  /// Fixture shown in the "already predicted" state on the home mockup. Seeded
  /// for display only (not persisted) so the card reads "Predicted … ago" on a
  /// fresh install; a real user submission overrides it.
  static const _demoPredictedMatchId = 'ipl_pjk_kkr';

  Future<void> load() async {
    final leagues = await _repository.leagues();
    final fixtures = await _repository.fixtures();
    final stored = await _storage.loadPredictions();
    final predictions = {for (final p in stored) p.matchId: p};
    predictions.putIfAbsent(
      _demoPredictedMatchId,
      () => UserPrediction(
        matchId: _demoPredictedMatchId,
        answers: const {},
        submittedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );
    emit(
      state.copyWith(
        loading: false,
        leagues: leagues,
        fixtures: fixtures,
        predictions: predictions,
      ),
    );
  }

  Future<PredictionQuiz?> quizFor(String matchId) =>
      _repository.quizFor(matchId);

  /// Stores (or replaces) the user's answers for a fixture.
  Future<void> submit(String matchId, Map<String, int> answers) async {
    final prediction = UserPrediction(
      matchId: matchId,
      answers: answers,
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
      if (picked != null && picked == q.settledOptionIndex) {
        correct++;
        reward += q.reward;
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
