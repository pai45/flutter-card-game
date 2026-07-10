import '../../models/basketball.dart';

/// Coarse Hoop Duel session phases. The 60fps match itself lives in the Flame
/// game; this machine only drives screens/overlays.
enum BasketballPhase {
  /// Hub/lobby — no match built.
  idle,

  /// Matchmaking VS card + tip-off countdown.
  intro,

  /// A half (or overtime) is live.
  playing,

  /// Between halves — substitution overlay.
  halftime,

  /// Scores level after H2 — the OVERTIME stinger beat.
  overtimeBreak,

  /// Match decided; the screen plays its final beat before the overlay.
  finished,

  /// Result overlay is up.
  result,
}

class BasketballState {
  const BasketballState({
    this.loading = true,
    this.stats = const BasketballStats(),
    this.rosterIds = const [],
    this.starterId,
    this.difficulty = BasketballDifficulty.pro,
    this.phase = BasketballPhase.idle,
    this.halfIndex = 0,
    this.config,
    this.summary,
    this.xp = 0,
    this.teamId = 'lakers',
  });

  final bool loading;
  final BasketballStats stats;

  /// Lobby roster selection (exactly 3 to play).
  final List<String> rosterIds;
  final String? starterId;
  final BasketballDifficulty difficulty;

  final BasketballPhase phase;

  /// 0/1 = halves, 2 = overtime.
  final int halfIndex;
  final BasketballMatchConfig? config;
  final BasketballMatchSummary? summary;
  final int xp;
  final String teamId;

  bool get rosterReady =>
      rosterIds.length == 3 &&
      starterId != null &&
      rosterIds.contains(starterId);

  BasketballState copyWith({
    bool? loading,
    BasketballStats? stats,
    List<String>? rosterIds,
    String? starterId,
    BasketballDifficulty? difficulty,
    BasketballPhase? phase,
    int? halfIndex,
    BasketballMatchConfig? config,
    BasketballMatchSummary? summary,
    int? xp,
    String? teamId,
    bool clearMatch = false,
    bool clearStarter = false,
  }) => BasketballState(
    loading: loading ?? this.loading,
    stats: stats ?? this.stats,
    rosterIds: rosterIds ?? this.rosterIds,
    starterId: clearStarter ? null : (starterId ?? this.starterId),
    difficulty: difficulty ?? this.difficulty,
    phase: phase ?? this.phase,
    halfIndex: halfIndex ?? this.halfIndex,
    config: clearMatch ? null : (config ?? this.config),
    summary: clearMatch ? null : (summary ?? this.summary),
    xp: clearMatch ? 0 : (xp ?? this.xp),
    teamId: teamId ?? this.teamId,
  );
}
