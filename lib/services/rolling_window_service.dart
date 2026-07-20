import '../blocs/picks/picks_cubit.dart';
import '../blocs/prediction/prediction_cubit.dart';
import '../models/guess_player.dart' show guessPlayerDayKey;
import '../models/sport_match.dart';
import 'secure_storage_service.dart';

/// The frontend "cronjob": on resume/launch, if the day has changed since it
/// last ran, force-refreshes every sport's fixtures via
/// [PredictionCubit.refreshSport] (which also re-settles yesterday's
/// finished matches via the existing auto-settlement pipeline, and
/// naturally picks up matches for the day newly entering the rolling
/// window) and reloads picks markets the same way. Gated by a persisted
/// day-key so it's a no-op on every resume within the same day — no
/// in-session timer, no native background package, matching the
/// resume/launch-triggered catch-up pattern already proven by
/// [guessPlayerDayKey]/`GuessPlayerCubit.refreshForCurrentDay`.
class RollingWindowService {
  RollingWindowService(this._storage);

  final SecureGameStorage _storage;

  Future<bool> isDue({DateTime? now}) async {
    final todayKey = guessPlayerDayKey(now ?? DateTime.now());
    final lastKey = await _storage.loadRolloverLastDayKey();
    return lastKey != todayKey;
  }

  Future<void> runIfDue({
    required PredictionCubit predictionCubit,
    required PicksCubit picksCubit,
    DateTime? now,
  }) async {
    if (!await isDue(now: now)) return;
    for (final sport in Sport.values) {
      await predictionCubit.refreshSport(sport);
    }
    await picksCubit.load();
    await _storage.saveRolloverLastDayKey(guessPlayerDayKey(now ?? DateTime.now()));
  }
}
