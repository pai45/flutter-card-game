import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/quiz_trivia.dart';
import '../../models/sport_match.dart';
import '../../services/secure_storage_service.dart';
import 'quiz_state.dart';

/// Owns the Quiz progression: which modes are unlocked and the best
/// run per mode across all sports. There is no backend — progress is personal and persisted
/// on-device via [SecureGameStorage], mirroring `FriendsCubit`.
class QuizCubit extends Cubit<QuizState> {
  QuizCubit(this._storage) : super(const QuizState());

  final SecureGameStorage _storage;

  Future<void> load() async {
    final Map<Sport, QuizProgress> progressBySport = {};
    for (final sport in Sport.values) {
      progressBySport[sport] = await _storage.loadQuizProgress(sport);
    }
    emit(QuizState(loading: false, progressBySport: progressBySport));
  }

  bool isUnlocked(Sport sport, QuizMode mode) => state.isUnlocked(sport, mode);
  bool isSetUnlocked(Sport sport, QuizMode mode, int setNumber) =>
      state.progressForSport(sport).isSetUnlocked(mode, setNumber);
  QuizModeProgress progressFor(Sport sport, QuizMode mode) => state.progressFor(sport, mode);
  QuizSetProgress setProgressFor(Sport sport, QuizMode mode, int setNumber) =>
      state.progressFor(sport, mode).setProgress(setNumber);

  /// Folds a finished session into the persisted progress. Returns the outcome
  /// so the reveal can play a "MODE UNLOCKED" beat when a tier is first cleared.
  Future<({bool newlyCleared, QuizMode? unlocked})> recordResult(
    Sport sport,
    QuizMode mode, {
    int setNumber = 1,
    required int correct,
    required int total,
  }) async {
    final result = state.progressForSport(sport).record(
      mode,
      setNumber: setNumber,
      correct: correct,
      total: total,
    );
    final nextProgressBySport = Map<Sport, QuizProgress>.from(state.progressBySport);
    nextProgressBySport[sport] = result.progress;

    emit(state.copyWith(progressBySport: nextProgressBySport));
    await _storage.saveQuizProgress(sport, result.progress);
    return (newlyCleared: result.newlyCleared, unlocked: result.unlocked);
  }
}
