import '../../config/enums.dart';
import '../../models/cards.dart';
import '../../models/match.dart';

class ShootoutState {
  const ShootoutState({
    required this.stage,
    required this.playerShooters,
    required this.playerKeeper,
    required this.cpuShooters,
    required this.cpuKeeper,
    required this.cpuLevel,
    required this.kicks,
    required this.playerScore,
    required this.opponentScore,
    required this.round,
    required this.over,
    required this.selectedDirection,
    required this.suddenDeath,
    required this.winner,
  });

  factory ShootoutState.initial({
    required List<PlayerCard> playerShooters,
    required PlayerCard playerKeeper,
    required List<PlayerCard> cpuShooters,
    required PlayerCard cpuKeeper,
    required int cpuLevel,
  }) => ShootoutState(
    stage: ShootoutStage.lineup,
    playerShooters: playerShooters,
    playerKeeper: playerKeeper,
    cpuShooters: cpuShooters,
    cpuKeeper: cpuKeeper,
    cpuLevel: cpuLevel,
    kicks: const [],
    playerScore: 0,
    opponentScore: 0,
    round: 0,
    over: false,
    selectedDirection: null,
    suddenDeath: false,
    winner: null,
  );

  final ShootoutStage stage;

  /// Kick order: ATK1, ATK2, DEF1, DEF2, GK — the keeper steps up last.
  final List<PlayerCard> playerShooters;
  final PlayerCard playerKeeper;
  final List<PlayerCard> cpuShooters;
  final PlayerCard cpuKeeper;
  final int cpuLevel;

  final List<PenaltyKick> kicks;
  final int playerScore;
  final int opponentScore;

  /// Kick index (0-based). Player shoots on even rounds, CPU on odd.
  final int round;
  final bool over;
  final PenaltyDirection? selectedDirection;
  final bool suddenDeath;
  final String? winner; // 'player' | 'opponent'

  bool get playerTaking => round.isEven;

  /// How many kicks the side currently on the spot has already taken.
  /// The `% 5` cycles the lineup again through sudden death.
  int get sideKickIndex => round ~/ 2;

  PlayerCard get currentShooter => playerTaking
      ? playerShooters[sideKickIndex % playerShooters.length]
      : cpuShooters[sideKickIndex % cpuShooters.length];

  /// The keeper standing in goal for the current kick.
  PlayerCard get currentKeeper => playerTaking ? cpuKeeper : playerKeeper;

  ShootoutState copyWith({
    ShootoutStage? stage,
    List<PenaltyKick>? kicks,
    int? playerScore,
    int? opponentScore,
    int? round,
    bool? over,
    Object? selectedDirection = _sentinel,
    bool? suddenDeath,
    Object? winner = _sentinel,
  }) => ShootoutState(
    stage: stage ?? this.stage,
    playerShooters: playerShooters,
    playerKeeper: playerKeeper,
    cpuShooters: cpuShooters,
    cpuKeeper: cpuKeeper,
    cpuLevel: cpuLevel,
    kicks: kicks ?? this.kicks,
    playerScore: playerScore ?? this.playerScore,
    opponentScore: opponentScore ?? this.opponentScore,
    round: round ?? this.round,
    over: over ?? this.over,
    selectedDirection: selectedDirection == _sentinel
        ? this.selectedDirection
        : selectedDirection as PenaltyDirection?,
    suddenDeath: suddenDeath ?? this.suddenDeath,
    winner: winner == _sentinel ? this.winner : winner as String?,
  );
}

const _sentinel = Object();
