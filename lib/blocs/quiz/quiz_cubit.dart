import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/quiz_trivia.dart';
import '../../services/secure_storage_service.dart';
import 'quiz_state.dart';

/// Owns the Football Quiz progression: which modes are unlocked and the best
/// run per mode. There is no backend — progress is personal and persisted
/// on-device via [SecureGameStorage], mirroring `FriendsCubit`.
class QuizCubit extends Cubit<QuizState> {
  QuizCubit(this._storage) : super(const QuizState());

  final SecureGameStorage _storage;

  Future<void> load() async {
    final progress = await _storage.loadQuizProgress();
    emit(QuizState(loading: false, progress: progress));
  }

  bool isUnlocked(QuizMode mode) => state.isUnlocked(mode);
  bool isSetUnlocked(QuizMode mode, int setNumber) =>
      state.progress.isSetUnlocked(mode, setNumber);
  QuizModeProgress progressFor(QuizMode mode) => state.progressFor(mode);
  QuizSetProgress setProgressFor(QuizMode mode, int setNumber) =>
      state.progressFor(mode).setProgress(setNumber);

  /// Folds a finished session into the persisted progress. Returns the outcome
  /// so the reveal can play a "MODE UNLOCKED" beat when a tier is first cleared.
  Future<({bool newlyCleared, QuizMode? unlocked})> recordResult(
    QuizMode mode, {
    int setNumber = 1,
    required int correct,
    required int total,
  }) async {
    final result = state.progress.record(
      mode,
      setNumber: setNumber,
      correct: correct,
      total: total,
    );
    emit(state.copyWith(progress: result.progress));
    await _storage.saveQuizProgress(result.progress);
    return (newlyCleared: result.newlyCleared, unlocked: result.unlocked);
  }
}
