import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/achievement.dart';
import '../../services/secure_storage_service.dart';

/// What the [AchievementCelebrationHost] needs to render: the queue of badges
/// waiting to be revealed (the head is shown first) and whether a screen is
/// currently holding the reveal back during its own "moment".
class AchievementCelebrationState {
  const AchievementCelebrationState({this.queue = const [], this.holding = false});

  final List<Achievement> queue;
  final bool holding;

  /// The reveal is allowed to play when something is queued and nothing is
  /// deferring it.
  bool get canReveal => queue.isNotEmpty && !holding;

  AchievementCelebrationState copyWith({
    List<Achievement>? queue,
    bool? holding,
  }) => AchievementCelebrationState(
    queue: queue ?? this.queue,
    holding: holding ?? this.holding,
  );
}

/// App-root watcher that turns achievement-threshold crossings into a queue of
/// celebration moments. Fed [AchievementStats] snapshots after any source-bloc
/// change (see `app.dart`), it diffs against the persisted "already celebrated"
/// set and enqueues only the genuinely new unlocks.
///
/// On first ever run it seeds the celebrated set silently from whatever is
/// already unlocked, so badges earned before this feature shipped never replay.
class AchievementCelebrationController
    extends Cubit<AchievementCelebrationState> {
  AchievementCelebrationController(this._storage)
    : super(const AchievementCelebrationState()) {
    _load();
  }

  final SecureGameStorage _storage;

  Set<String> _celebrated = <String>{};
  bool _seeded = false;
  bool _loaded = false;
  AchievementStats? _pendingStats;

  Future<void> _load() async {
    final stored = await _storage.loadCelebratedAchievements();
    if (stored != null) {
      _celebrated = stored;
      _seeded = true;
    }
    _loaded = true;
    final pending = _pendingStats;
    if (pending != null) {
      _pendingStats = null;
      sync(pending);
    }
  }

  /// Reconcile the latest stats against what has already been celebrated and
  /// enqueue any fresh unlocks.
  void sync(AchievementStats stats) {
    if (!_loaded) {
      _pendingStats = stats; // process once persisted state is available
      return;
    }
    if (!_seeded) {
      _celebrated = unlockedAchievementIds(stats);
      _seeded = true;
      _persist();
      return; // silent baseline — never celebrate pre-existing badges
    }
    final fresh = newlyUnlockedAchievements(_celebrated, stats);
    if (fresh.isEmpty) return;
    _celebrated = {..._celebrated, for (final a in fresh) a.id};
    _persist();
    emit(state.copyWith(queue: [...state.queue, ...fresh]));
  }

  /// Defer the reveal while a screen runs its own moment (e.g. the quiz
  /// post-submit cinematic). Always pair with [release].
  void hold() {
    if (!state.holding) emit(state.copyWith(holding: true));
  }

  void release() {
    if (state.holding) emit(state.copyWith(holding: false));
  }

  /// The host calls this once the head badge finishes revealing.
  void consumeFront() {
    if (state.queue.isEmpty) return;
    emit(state.copyWith(queue: state.queue.sublist(1)));
  }

  void _persist() {
    // Fire-and-forget; a failed write just means a badge may re-celebrate once.
    _storage.saveCelebratedAchievements(_celebrated);
  }
}
