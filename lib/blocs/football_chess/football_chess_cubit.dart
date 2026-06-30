import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../games/football_chess/football_chess_board.dart';
import '../../games/football_chess/football_chess_engine.dart';
import '../../models/cards.dart';
import '../../models/football_chess.dart';
import '../../services/secure_storage_service.dart';
import 'football_chess_state.dart';

/// Drives a grid Football Chess match: the toss, the alternating one-action turns
/// (player taps → resolve → CPU replies), the 2:00 clock + soft per-move timer,
/// goals, and the final whistle. Authoritative state; the Flame renderer reads it
/// and reports animation completion via [onResolutionAnimated] / [onGoalReset].
class FootballChessCubit extends Cubit<FootballChessState> {
  FootballChessCubit(this._storage, {Random? random})
    : _random = random ?? Random(),
      super(const FootballChessState()) {
    _engine = FootballChessEngine(random: _random);
  }

  final SecureGameStorage _storage;
  final Random _random;
  late final FootballChessEngine _engine;
  Timer? _clock;
  Timer? _cpuTimer;

  static const double kMatchSeconds = 120;
  static const double kDecisionSeconds = 10;
  static const Duration _tickInterval = Duration(milliseconds: 100);
  static const double _dt = 0.1;

  Future<void> load() async {
    final stats = await _storage.loadFootballChessStats();
    emit(state.copyWith(loading: false, stats: stats));
  }

  /// Build a kickoff-ready match (toss pending). The CPU squad shuffles each call.
  ChessMatch buildMatch({
    required List<PlayerCard> playerSquad,
    required ChessFormation formation,
    required List<PlayerCard> opponentSquad,
    required String opponentName,
    required int opponentLevel,
  }) {
    final oppFormation =
        ChessFormation.values[_random.nextInt(ChessFormation.values.length)];
    final board = _engine.initialBoard(
      playerSquad: playerSquad,
      opponentSquad: opponentSquad,
      playerFormation: formation,
      opponentFormation: oppFormation,
      kickoff: Side.player,
    );
    return ChessMatch(
      playerSquad: playerSquad,
      opponentSquad: opponentSquad,
      opponentName: opponentName,
      opponentLevel: opponentLevel,
      playerFormation: formation,
      opponentFormation: oppFormation,
      board: board,
      phase: ChessMatchPhase.toss,
      turnSide: Side.player,
      playerScore: 0,
      opponentScore: 0,
      clockRemaining: kMatchSeconds,
      decisionRemaining: kDecisionSeconds,
    );
  }

  void startMatch(ChessMatch match) {
    _clock?.cancel();
    _cpuTimer?.cancel();
    emit(state.copyWith(match: match));
  }

  /// Resolve the coin toss; the winner kicks off (gets the ball).
  void callToss(CoinSide call) {
    final m = state.match;
    if (m == null || m.phase != ChessMatchPhase.toss) return;
    final result = _engine.tossCoin();
    final won = result == call;
    final kickoff = won ? Side.player : Side.opponent;
    emit(
      state.copyWith(
        match: m.copyWith(
          tossCall: call,
          tossResult: result,
          playerWonToss: won,
          board: _engine.kickoffReset(m.board, kickoff),
          turnSide: kickoff,
          eventTick: m.eventTick + 1,
        ),
      ),
    );
  }

  /// Kick off after the toss reveal.
  void beginPlay() {
    final m = state.match;
    if (m == null || m.phase != ChessMatchPhase.toss) return;
    _startTurn((m.playerWonToss ?? true) ? Side.player : Side.opponent);
  }

  // ---- Player input ------------------------------------------------------

  /// A tap on a board [cell]: execute the armed verb's target, (re)select a
  /// piece, or deselect.
  void tapCell(BoardCell cell) {
    final m = state.match;
    if (m == null || m.phase != ChessMatchPhase.playerTurn) return;
    final sel = m.selectedPiece;
    final verb = m.selectedAction;

    // An armed targeted verb is waiting for a destination.
    if (sel != null && verb != null && verb.needsTarget) {
      if (verb == BoardActionType.move && m.moveCells.contains(cell)) {
        _applyAction(ChessAction(type: verb, pieceId: sel.id, cell: cell));
        return;
      }
      if (verb == BoardActionType.dribble && m.moveCells.contains(cell)) {
        final opp = m.board.outfieldAt(cell);
        if (opp != null) {
          _applyAction(
            ChessAction(type: verb, pieceId: sel.id, targetId: opp.id),
          );
          return;
        }
      }
      if (verb == BoardActionType.pass) {
        final tapped = m.board.pieceAt(cell);
        if (tapped != null && m.passTargetIds.contains(tapped.id)) {
          _applyAction(
            ChessAction(
              type: BoardActionType.pass,
              pieceId: sel.id,
              targetId: tapped.id,
            ),
          );
          return;
        }
      }
      // Tapped off-target: fall through to (re)select / deselect.
    }

    final tapped = m.board.pieceAt(cell);
    if (tapped != null && tapped.side == Side.player) {
      if (tapped.id == m.selectedPieceId) {
        _clearSelection(); // tap again to deselect
      } else {
        _select(tapped);
      }
      return;
    }
    _clearSelection();
  }

  /// Choose a verb from the action bar — resolve it, or arm it for a target tap.
  void chooseAction(BoardActionType verb) {
    final m = state.match;
    if (m == null || m.phase != ChessMatchPhase.playerTurn) return;
    final sel = m.selectedPiece;
    if (sel == null || !m.availableActions.contains(verb)) return;

    if (verb.needsTarget) {
      _arm(verb, sel);
      return;
    }
    _applyAction(ChessAction(type: verb, pieceId: sel.id));
  }

  void deselect() {
    final m = state.match;
    if (m == null || !m.hasSelection) return;
    _clearSelection();
  }

  void _select(BoardPiece piece) {
    final m = state.match!;
    emit(
      state.copyWith(
        match: m.copyWith(
          selectedPieceId: piece.id,
          availableActions: _engine.availableActions(
            m.board,
            Side.player,
            piece,
          ),
          selectedAction: null,
          moveCells: const [],
          passTargetIds: const [],
          eventTick: m.eventTick + 1,
        ),
      ),
    );
  }

  void _arm(BoardActionType verb, BoardPiece piece) {
    final m = state.match!;
    final cells = switch (verb) {
      BoardActionType.move => _engine.legalMoves(m.board, piece),
      // DRIBBLE targets are adjacent opponents → highlight their cells.
      BoardActionType.dribble => [
        for (final id in _engine.dribbleTargets(m.board, piece))
          if (m.board.pieceById(id) case final o?) o.cell,
      ],
      _ => const <BoardCell>[],
    };
    final passes = verb == BoardActionType.pass
        ? _engine.passTargets(m.board, piece)
        : const <String>[];
    emit(
      state.copyWith(
        match: m.copyWith(
          selectedAction: verb,
          moveCells: cells,
          passTargetIds: passes,
          eventTick: m.eventTick + 1,
        ),
      ),
    );
  }

  void _clearSelection() {
    final m = state.match!;
    emit(
      state.copyWith(
        match: m.copyWith(
          selectedPieceId: null,
          availableActions: const [],
          selectedAction: null,
          moveCells: const [],
          passTargetIds: const [],
          eventTick: m.eventTick + 1,
        ),
      ),
    );
  }

  // ---- Resolution --------------------------------------------------------

  void _applyAction(ChessAction action) {
    final m = state.match!;
    final actor = m.board.pieceById(action.pieceId)!;
    final side = actor.side;

    final res = _engine.apply(m.board, action);

    final lastMove = _lastMoveFor(m, action, actor, res);
    final log = [
      ...m.moveLog,
      MoveLogEntry(side: side, verb: action.type, card: res.card),
    ];
    final trimmed = log.length > 8 ? log.sublist(log.length - 8) : log;

    if (res.event == BoardEvent.goal) {
      final scorerIsPlayer = res.scorer == Side.player;
      emit(
        state.copyWith(
          match: m.copyWith(
            phase: ChessMatchPhase.goalScored,
            board: res.state,
            turnSide: side,
            playerScore: scorerIsPlayer ? m.playerScore + 1 : m.playerScore,
            opponentScore: scorerIsPlayer
                ? m.opponentScore
                : m.opponentScore + 1,
            banner: 'GOAL',
            goals: [
              ...m.goals,
              ChessGoal(
                scorerShortName: actor.card.shortName,
                byPlayer: scorerIsPlayer,
                atClock: m.clockRemaining,
              ),
            ],
            lastMove: lastMove,
            moveLog: trimmed,
            selectedPieceId: null,
            availableActions: const [],
            selectedAction: null,
            moveCells: const [],
            passTargetIds: const [],
            eventTick: m.eventTick + 1,
          ),
        ),
      );
      return; // wait for onGoalReset
    }

    final banner = switch (res.card) {
      CardType.red => 'RED CARD',
      CardType.yellow => 'YELLOW CARD',
      CardType.none => _banner(res.event),
    };

    emit(
      state.copyWith(
        match: m.copyWith(
          phase: ChessMatchPhase.resolving,
          board: res.state,
          turnSide: side,
          lastEvent: res.event,
          banner: banner,
          lastMove: lastMove,
          moveLog: trimmed,
          selectedPieceId: null,
          availableActions: const [],
          selectedAction: null,
          moveCells: const [],
          passTargetIds: const [],
          eventTick: m.eventTick + 1,
        ),
      ),
    );
  }

  LastMove _lastMoveFor(
    ChessMatch m,
    ChessAction action,
    BoardPiece actor,
    ActionResult res,
  ) {
    final from = actor.cell;
    final to = switch (action.type) {
      BoardActionType.move => action.cell!,
      BoardActionType.pass ||
      BoardActionType.dribble => m.board.pieceById(action.targetId!)!.cell,
      BoardActionType.tackle ||
      BoardActionType.slide => m.board.carrier?.cell ?? from,
      _ => res.state.pieceById(actor.id)?.cell ?? from,
    };
    return LastMove(
      from: from,
      to: to,
      side: actor.side,
      verb: action.type,
      actorName: actor.card.shortName,
    );
  }

  /// Called by the renderer once a move/duel animation has played out.
  void onResolutionAnimated() {
    final m = state.match;
    if (m == null || m.phase != ChessMatchPhase.resolving) return;
    if (m.clockRemaining <= 0) {
      _endMatch();
      return;
    }
    _startTurn(m.turnSide.opposite);
  }

  /// Called by the renderer after the goal celebration + reset.
  void onGoalReset() {
    final m = state.match;
    if (m == null || m.phase != ChessMatchPhase.goalScored) return;
    if (m.clockRemaining <= 0) {
      _endMatch();
      return;
    }
    final conceder = m.turnSide.opposite; // the scorer was turnSide
    // Full reset to the starting formation; the conceding side kicks off.
    emit(
      state.copyWith(
        match: m.copyWith(
          board: _engine.kickoffReset(
            _engine.initialBoard(
              playerSquad: m.playerSquad,
              opponentSquad: m.opponentSquad,
              playerFormation: m.playerFormation,
              opponentFormation: m.opponentFormation,
              kickoff: conceder,
            ),
            conceder,
          ),
          banner: null,
        ),
      ),
    );
    _startTurn(conceder);
  }

  void _startTurn(Side side) {
    final m = state.match!;
    // Tick down any bookings (red-carded pieces sitting out) and cooldowns for this side.
    final board = m.board.copyWith(
      pieces: [
        for (final p in m.board.pieces)
          p.side == side
              ? p.copyWith(
                  benchedTurns: max(0, p.benchedTurns - 1),
                  tackleCooldownTurns: max(0, p.tackleCooldownTurns - 1),
                  slideCooldownTurns: max(0, p.slideCooldownTurns - 1),
                )
              : p,
      ],
    );
    emit(
      state.copyWith(
        match: m.copyWith(
          board: board,
          phase: side == Side.player
              ? ChessMatchPhase.playerTurn
              : ChessMatchPhase.opponentTurn,
          turnSide: side,
          decisionRemaining: kDecisionSeconds,
          banner: null,
          selectedPieceId: null,
          availableActions: const [],
          selectedAction: null,
          moveCells: const [],
          passTargetIds: const [],
          eventTick: m.eventTick + 1,
        ),
      ),
    );
    _ensureClock();
    if (side == Side.opponent) _scheduleCpu();
  }

  // ---- CPU ---------------------------------------------------------------

  void _scheduleCpu() {
    _cpuTimer?.cancel();
    _cpuTimer = Timer(const Duration(milliseconds: 650), () {
      final m = state.match;
      if (m == null || m.phase != ChessMatchPhase.opponentTurn) return;
      final action = _engine.cpuChooseAction(m.board, m.opponentLevel);
      if (action == null) {
        _startTurn(Side.player);
        return;
      }
      _applyAction(action);
    });
  }

  // ---- Clock -------------------------------------------------------------

  void _ensureClock() {
    _clock ??= Timer.periodic(_tickInterval, (_) => _tick());
  }

  void _tick() {
    final m = state.match;
    if (m == null) return;
    final active =
        m.phase == ChessMatchPhase.playerTurn ||
        m.phase == ChessMatchPhase.opponentTurn;
    if (!active) return;
    final clock = m.clockRemaining - _dt;
    if (clock <= 0) {
      emit(state.copyWith(match: m.copyWith(clockRemaining: 0)));
      _endMatch();
      return;
    }
    if (m.phase == ChessMatchPhase.playerTurn) {
      final dec = m.decisionRemaining - _dt;
      if (dec <= 0) {
        emit(
          state.copyWith(
            match: m.copyWith(clockRemaining: clock, decisionRemaining: 0),
          ),
        );
        _autoAct();
        return;
      }
      emit(
        state.copyWith(
          match: m.copyWith(clockRemaining: clock, decisionRemaining: dec),
        ),
      );
    } else {
      emit(state.copyWith(match: m.copyWith(clockRemaining: clock)));
    }
  }

  /// Out of decision time — commit a random legal move so play keeps flowing.
  void _autoAct() {
    final m = state.match!;
    final actions = _engine.allActions(m.board, Side.player);
    if (actions.isEmpty) {
      _startTurn(Side.opponent);
      return;
    }
    _applyAction(actions[_random.nextInt(actions.length)]);
  }

  Future<void> _endMatch() async {
    _clock?.cancel();
    _clock = null;
    _cpuTimer?.cancel();
    final m = state.match!;
    final updated = m.copyWith(
      phase: ChessMatchPhase.fullTime,
      banner: null,
      selectedPieceId: null,
      availableActions: const [],
      selectedAction: null,
      moveCells: const [],
      passTargetIds: const [],
      eventTick: m.eventTick + 1,
    );
    final stats = state.stats.recordResult(
      won: updated.playerWon,
      draw: updated.isDraw,
    );
    emit(state.copyWith(match: updated, stats: stats));
    await _storage.saveFootballChessStats(stats);
  }

  /// Stop the clocks when the player leaves an unfinished match (the cubit is
  /// owned by the hub, so popping the match route does not dispose it).
  void abandonMatch() {
    _clock?.cancel();
    _clock = null;
    _cpuTimer?.cancel();
  }

  String? _banner(BoardEvent event) => switch (event) {
    BoardEvent.turnover => 'BALL WON',
    BoardEvent.save => 'SAVED',
    BoardEvent.blocked => 'BLOCKED',
    BoardEvent.advanced || BoardEvent.none || BoardEvent.goal => null,
  };

  @override
  Future<void> close() {
    _clock?.cancel();
    _cpuTimer?.cancel();
    return super.close();
  }
}
