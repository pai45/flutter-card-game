import '../../games/grand_prix/grand_prix_engine.dart';
import '../../models/grand_prix.dart';

const Object _sentinel = Object();

/// Race lifecycle. The 60fps simulation itself lives in the Flame game — this
/// phase machine only tracks the coarse beats around it.
enum GrandPrixPhase { idle, grid, lights, racing, finished, result }

class GrandPrixState {
  const GrandPrixState({
    this.loading = true,
    this.stats = const GrandPrixStats(),
    this.phase = GrandPrixPhase.idle,
    this.lightsOn = 0,
    this.lightsOut = false,
    this.launchGrade,
    this.playerPosition = 0,
    this.lastOvertake,
    this.eventTick = 0,
    this.setup,
    this.result,
  });

  final bool loading;
  final GrandPrixStats stats;
  final GrandPrixPhase phase;

  /// Lit start lamps, 0..5 (drops back to 0 the moment they go out).
  final int lightsOn;

  /// True once the lamps have gone dark — the launch window is open.
  final bool lightsOut;
  final LaunchGrade? launchGrade;

  /// Live position from the game's coarse callback (changes rarely).
  final int playerPosition;

  /// Last player overtake + a monotonic tick for toast listeners.
  final OvertakeEvent? lastOvertake;
  final int eventTick;

  final RaceSetup? setup;
  final GrandPrixResult? result;

  // Selection is persisted on stats so it survives restarts.
  GrandPrixCircuitId get circuitId => stats.lastCircuit;
  GrandPrixLivery get livery => stats.lastLivery;
  int get laps => stats.lastLaps;
  bool get jumpStart => launchGrade == LaunchGrade.jump;
  bool get raceLive =>
      phase == GrandPrixPhase.racing || phase == GrandPrixPhase.lights;

  GrandPrixState copyWith({
    bool? loading,
    GrandPrixStats? stats,
    GrandPrixPhase? phase,
    int? lightsOn,
    bool? lightsOut,
    Object? launchGrade = _sentinel,
    int? playerPosition,
    Object? lastOvertake = _sentinel,
    int? eventTick,
    Object? setup = _sentinel,
    Object? result = _sentinel,
  }) => GrandPrixState(
    loading: loading ?? this.loading,
    stats: stats ?? this.stats,
    phase: phase ?? this.phase,
    lightsOn: lightsOn ?? this.lightsOn,
    lightsOut: lightsOut ?? this.lightsOut,
    launchGrade: identical(launchGrade, _sentinel)
        ? this.launchGrade
        : launchGrade as LaunchGrade?,
    playerPosition: playerPosition ?? this.playerPosition,
    lastOvertake: identical(lastOvertake, _sentinel)
        ? this.lastOvertake
        : lastOvertake as OvertakeEvent?,
    eventTick: eventTick ?? this.eventTick,
    setup: identical(setup, _sentinel) ? this.setup : setup as RaceSetup?,
    result: identical(result, _sentinel)
        ? this.result
        : result as GrandPrixResult?,
  );
}
