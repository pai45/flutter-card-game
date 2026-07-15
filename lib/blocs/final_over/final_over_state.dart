import '../../models/final_over.dart';

/// The coarse flow of a Final Over session. This is the ONLY thing the widget
/// tree rebuilds on — the six-ball chase itself runs at 60fps inside the Flame
/// game and reports through `ValueNotifier`s, never through here.
enum FinalOverPhase {
  /// In the lobby.
  idle,

  /// Match screen up, VS card + countdown running.
  intro,

  /// The chase is live.
  playing,

  /// The engine has called it; the result cinematic has not started yet.
  finished,

  /// The result cinematic is on screen.
  result,
}

class FinalOverState {
  const FinalOverState({
    this.phase = FinalOverPhase.idle,
    this.stats = const FinalOverStats(),
    this.config,
    this.summary,
    this.loaded = false,
  });

  final FinalOverPhase phase;
  final FinalOverStats stats;
  final FinalOverMatchConfig? config;
  final FinalOverMatchSummary? summary;
  final bool loaded;

  FinalOverTier get tier => stats.tier;
  String get kitId => stats.kitId;

  FinalOverState copyWith({
    FinalOverPhase? phase,
    FinalOverStats? stats,
    FinalOverMatchConfig? config,
    FinalOverMatchSummary? summary,
    bool? loaded,
    bool clearSummary = false,
  }) => FinalOverState(
    phase: phase ?? this.phase,
    stats: stats ?? this.stats,
    config: config ?? this.config,
    summary: clearSummary ? null : (summary ?? this.summary),
    loaded: loaded ?? this.loaded,
  );
}
