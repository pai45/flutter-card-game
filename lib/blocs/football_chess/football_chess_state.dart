import '../../games/football_chess/football_chess_board.dart';
import '../../models/cards.dart';
import '../../models/football_chess.dart';

const Object _sentinel = Object();

/// The last action's from/to cells — drives the chess.com-style board highlight.
class LastMove {
  const LastMove({
    required this.from,
    required this.to,
    required this.side,
    required this.verb,
    required this.actorName,
  });

  final BoardCell from;
  final BoardCell to;
  final Side side;
  final BoardActionType verb;
  final String actorName;
}

/// One entry in the running move log.
class MoveLogEntry {
  const MoveLogEntry({
    required this.side,
    required this.verb,
    this.card = CardType.none,
  });

  final Side side;
  final BoardActionType verb;
  final CardType card;
}

/// An in-progress (or just-finished) grid match. The spatial state lives in
/// [board]; this wraps it with match meta, the clock, the player's selection and
/// the goal log.
class ChessMatch {
  const ChessMatch({
    required this.playerSquad,
    required this.opponentSquad,
    required this.opponentName,
    required this.opponentLevel,
    required this.playerFormation,
    required this.opponentFormation,
    required this.board,
    required this.phase,
    required this.turnSide,
    required this.playerScore,
    required this.opponentScore,
    required this.clockRemaining,
    required this.decisionRemaining,
    this.tossCall,
    this.tossResult,
    this.playerWonToss,
    this.selectedPieceId,
    this.availableActions = const [],
    this.selectedAction,
    this.moveCells = const [],
    this.passTargetIds = const [],
    this.lastEvent = BoardEvent.none,
    this.banner,
    this.lastMove,
    this.moveLog = const [],
    this.goals = const [],
    this.eventTick = 0,
  });

  // Teams / meta
  final List<PlayerCard> playerSquad;
  final List<PlayerCard> opponentSquad;
  final String opponentName;
  final int opponentLevel;
  final ChessFormation playerFormation;
  final ChessFormation opponentFormation;

  // Live state
  final BoardState board;
  final ChessMatchPhase phase;
  final Side turnSide; // whose action it is (actor during resolving/goal)
  final int playerScore;
  final int opponentScore;
  final double clockRemaining; // seconds, kickoff 120 → 0
  final double decisionRemaining; // soft per-move timer (player turn)

  // Toss
  final CoinSide? tossCall;
  final CoinSide? tossResult;
  final bool? playerWonToss;

  // Player selection / highlights (only during playerTurn)
  final String? selectedPieceId;

  /// The verbs the selected piece can take (drives the action bar).
  final List<BoardActionType> availableActions;

  /// The armed verb awaiting a target tap (dribble/pass/move), or null.
  final BoardActionType? selectedAction;

  /// Targets for the armed verb: cells for dribble/move, teammate ids for pass.
  final List<BoardCell> moveCells;
  final List<String> passTargetIds;

  // Feedback
  final BoardEvent lastEvent;
  final String? banner;

  /// The last action's cells (board highlight) + the running move log.
  final LastMove? lastMove;
  final List<MoveLogEntry> moveLog;

  final List<ChessGoal> goals;
  final int eventTick;

  bool get isFinished => phase == ChessMatchPhase.fullTime;
  bool get playerWon => playerScore > opponentScore;
  bool get isDraw => playerScore == opponentScore;
  bool get hasSelection => selectedPieceId != null;

  BoardPiece? get selectedPiece =>
      selectedPieceId == null ? null : board.pieceById(selectedPieceId!);

  ChessMatch copyWith({
    BoardState? board,
    ChessMatchPhase? phase,
    Side? turnSide,
    int? playerScore,
    int? opponentScore,
    double? clockRemaining,
    double? decisionRemaining,
    CoinSide? tossCall,
    CoinSide? tossResult,
    bool? playerWonToss,
    Object? selectedPieceId = _sentinel,
    List<BoardActionType>? availableActions,
    Object? selectedAction = _sentinel,
    List<BoardCell>? moveCells,
    List<String>? passTargetIds,
    BoardEvent? lastEvent,
    Object? banner = _sentinel,
    LastMove? lastMove,
    List<MoveLogEntry>? moveLog,
    List<ChessGoal>? goals,
    int? eventTick,
  }) => ChessMatch(
    playerSquad: playerSquad,
    opponentSquad: opponentSquad,
    opponentName: opponentName,
    opponentLevel: opponentLevel,
    playerFormation: playerFormation,
    opponentFormation: opponentFormation,
    board: board ?? this.board,
    phase: phase ?? this.phase,
    turnSide: turnSide ?? this.turnSide,
    playerScore: playerScore ?? this.playerScore,
    opponentScore: opponentScore ?? this.opponentScore,
    clockRemaining: clockRemaining ?? this.clockRemaining,
    decisionRemaining: decisionRemaining ?? this.decisionRemaining,
    tossCall: tossCall ?? this.tossCall,
    tossResult: tossResult ?? this.tossResult,
    playerWonToss: playerWonToss ?? this.playerWonToss,
    selectedPieceId: identical(selectedPieceId, _sentinel)
        ? this.selectedPieceId
        : selectedPieceId as String?,
    availableActions: availableActions ?? this.availableActions,
    selectedAction: identical(selectedAction, _sentinel)
        ? this.selectedAction
        : selectedAction as BoardActionType?,
    moveCells: moveCells ?? this.moveCells,
    passTargetIds: passTargetIds ?? this.passTargetIds,
    lastEvent: lastEvent ?? this.lastEvent,
    banner: identical(banner, _sentinel) ? this.banner : banner as String?,
    lastMove: lastMove ?? this.lastMove,
    moveLog: moveLog ?? this.moveLog,
    goals: goals ?? this.goals,
    eventTick: eventTick ?? this.eventTick,
  );
}

class FootballChessState {
  const FootballChessState({
    this.loading = true,
    this.stats = const FootballChessStats(),
    this.match,
  });

  final bool loading;
  final FootballChessStats stats;
  final ChessMatch? match;

  FootballChessState copyWith({
    bool? loading,
    FootballChessStats? stats,
    ChessMatch? match,
  }) => FootballChessState(
    loading: loading ?? this.loading,
    stats: stats ?? this.stats,
    match: match ?? this.match,
  );
}
