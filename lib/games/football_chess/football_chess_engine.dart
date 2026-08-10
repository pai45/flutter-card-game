import 'dart:math';

import '../../models/cards.dart';
import '../../models/football_chess.dart';
import 'football_chess_board.dart';

/// One chosen action: who acts, and the destination (move/dribble) or target
/// (pass). Shoot/press derive their target from the board.
class ChessAction {
  const ChessAction({
    required this.type,
    required this.pieceId,
    this.cell,
    this.targetId,
  });

  final BoardActionType type;
  final String pieceId;
  final BoardCell? cell; // move / dribble destination
  final String? targetId; // pass target piece id
}

/// The result of applying an action: the new board + what happened.
class ActionResult {
  const ActionResult({
    required this.state,
    required this.event,
    this.scorer,
    this.card = CardType.none,
  });

  final BoardState state;
  final BoardEvent event;
  final Side? scorer;

  /// A booking handed out this action (missed slide), if any.
  final CardType card;
}

/// Match information that lets the CPU manage risk and counter the player's
/// recent habits without seeing any hidden information.
class CpuDecisionContext {
  const CpuDecisionContext({
    required this.playerScore,
    required this.opponentScore,
    required this.clockRemaining,
    this.recentPlayerActions = const [],
  });

  final int playerScore;
  final int opponentScore;
  final double clockRemaining;
  final List<BoardActionType> recentPlayerActions;
}

class _ExpectedOutcome {
  const _ExpectedOutcome(this.probability, this.result);

  final double probability;
  final ActionResult result;
}

/// Pure rules engine for grid Football Chess. All randomness flows through an
/// injectable [Random]; the probability helpers are pure so they can be asserted
/// directly in tests.
class FootballChessEngine {
  FootballChessEngine({Random? random, Random? decisionRandom})
    : _random = random ?? Random(),
      _decisionRandom = decisionRandom ?? Random();

  final Random _random;
  final Random _decisionRandom;

  // ---- Setup -------------------------------------------------------------

  /// Build the kickoff board. Squads are `[atk, atk, def, def, gk]`. The player
  /// owns the bottom two rows, the opponent the top two; the [kickoff] side gets
  /// the ball on its most-central forward piece.
  BoardState initialBoard({
    required List<PlayerCard> playerSquad,
    required List<PlayerCard> opponentSquad,
    required ChessFormation playerFormation,
    required ChessFormation opponentFormation,
    required Side kickoff,
  }) {
    final playerCells = _formationCells(playerFormation);
    final oppCells = [
      // Mirror into the opponent half (row r → 3 - r).
      for (final c in _formationCells(opponentFormation))
        BoardCell(c.col, kBoardRows - 1 - c.row),
    ];

    final pieces = <BoardPiece>[
      for (var i = 0; i < 4; i++)
        BoardPiece(
          id: 'p$i',
          card: playerSquad[i],
          side: Side.player,
          cell: playerCells[i],
          isKeeper: false,
        ),
      BoardPiece(
        id: 'pk',
        card: playerSquad[4],
        side: Side.player,
        cell: const BoardCell(1, -1), // bottom goal
        isKeeper: true,
      ),
      for (var i = 0; i < 4; i++)
        BoardPiece(
          id: 'o$i',
          card: opponentSquad[i],
          side: Side.opponent,
          cell: oppCells[i],
          isKeeper: false,
        ),
      BoardPiece(
        id: 'ok',
        card: opponentSquad[4],
        side: Side.opponent,
        cell: const BoardCell(1, kBoardRows), // top goal
        isKeeper: true,
      ),
    ];

    final state = BoardState(
      pieces: pieces,
      ballCell: const BoardCell(1, 1),
      possession: kickoff,
    );
    return _giveKickoffBall(state, kickoff);
  }

  /// Reset to a kickoff for [kickoff] (after a goal): ball to that side's
  /// most-central forward outfielder.
  BoardState _giveKickoffBall(BoardState s, Side kickoff) {
    final mine = s.outfield(kickoff);
    // Forward = nearer the halfway line: highest row for the player, lowest for
    // the opponent. Tie-break toward the centre column.
    mine.sort((a, b) {
      final fa = kickoff == Side.player ? -a.cell.row : a.cell.row;
      final fb = kickoff == Side.player ? -b.cell.row : b.cell.row;
      if (fa != fb) return fa.compareTo(fb);
      return (a.cell.col - 1).abs().compareTo((b.cell.col - 1).abs());
    });
    final carrier = mine.first;
    return s.copyWith(ballCell: carrier.cell, possession: kickoff);
  }

  BoardState kickoffReset(BoardState s, Side kickoff) =>
      _giveKickoffBall(s, kickoff);

  /// Outfield starting cells in the player's half (rows 0 = back, 1 = front),
  /// in squad order `[atk0, atk1, def0, def1]`.
  List<BoardCell> _formationCells(ChessFormation f) => switch (f) {
    ChessFormation.box => const [
      BoardCell(0, 1),
      BoardCell(2, 1),
      BoardCell(0, 0),
      BoardCell(2, 0),
    ],
    ChessFormation.diamond => const [
      BoardCell(0, 1),
      BoardCell(2, 1),
      BoardCell(1, 0),
      BoardCell(1, 1),
    ],
    ChessFormation.attacking => const [
      BoardCell(1, 1),
      BoardCell(0, 1),
      BoardCell(2, 1),
      BoardCell(1, 0),
    ],
    ChessFormation.defensive => const [
      BoardCell(1, 1),
      BoardCell(1, 0),
      BoardCell(0, 0),
      BoardCell(2, 0),
    ],
  };

  // ---- Legal options -----------------------------------------------------

  /// Empty 8-directional neighbours.
  List<BoardCell> legalMoves(BoardState s, BoardPiece p) => [
    for (final c in p.cell.neighbors8())
      if (s.isEmpty(c)) c,
  ];

  /// Adjacent opponents a carrier can take on (DRIBBLE targets).
  List<String> dribbleTargets(BoardState s, BoardPiece carrier) {
    final out = <String>[];
    for (final c in carrier.cell.neighbors8()) {
      final o = s.outfieldAt(c);
      if (o != null && o.side != carrier.side) out.add(o.id);
    }
    return out;
  }

  /// The legal verbs for [p] (drives the action bar), in display order.
  List<BoardActionType> availableActions(
    BoardState s,
    Side side,
    BoardPiece p,
  ) {
    if (p.side != side || p.benched) return const [];
    final carrier = s.carrier;
    final isCarrier = carrier != null && carrier.id == p.id;
    final verbs = <BoardActionType>[];

    // Keeper can only pass, and only when they have the ball.
    if (p.isKeeper) {
      if (isCarrier && passTargets(s, p).isNotEmpty) {
        verbs.add(BoardActionType.pass);
      }
      return verbs;
    }

    if (s.possession == side) {
      if (isCarrier) {
        if (legalMoves(s, p).isNotEmpty) verbs.add(BoardActionType.move);
        if (dribbleTargets(s, p).isNotEmpty) verbs.add(BoardActionType.dribble);
        if (passTargets(s, p).isNotEmpty) verbs.add(BoardActionType.pass);
        if (p.cell.isShootingHalfFor(side)) verbs.add(BoardActionType.shoot);
      } else if (legalMoves(s, p).isNotEmpty) {
        verbs.add(BoardActionType.move);
      }
      return verbs;
    }

    // Defending — press (close down from range), tackle (adjacent), slide
    // (adjacent), then move. Distances are Chebyshev (diagonals count as 1).
    if (carrier != null) {
      final d = p.cell.distanceTo(carrier.cell);
      if (d >= 2 && _pressStep(s, p, carrier) != null) {
        verbs.add(BoardActionType.press);
      }
      if (d == 1) {
        if (p.tackleCooldownTurns == 0) verbs.add(BoardActionType.tackle);
        if (p.slideCooldownTurns == 0) verbs.add(BoardActionType.slide);
      }
    }
    if (legalMoves(s, p).isNotEmpty) verbs.add(BoardActionType.move);
    return verbs;
  }

  /// Teammates reachable by a straight (row/column) pass with a clear lane.
  /// Keepers can pass to ANY teammate.
  List<String> passTargets(BoardState s, BoardPiece carrier) {
    final out = <String>[];
    for (final t in s.outfield(carrier.side)) {
      if (t.id == carrier.id) continue;
      if (carrier.isKeeper || _clearLine(s, carrier.cell, t.cell)) {
        out.add(t.id);
      }
    }
    return out;
  }

  /// The empty neighbour of [p] that gets closest to [carrier] (for PRESS), or
  /// null if none gets closer.
  BoardCell? _pressStep(BoardState s, BoardPiece p, BoardPiece carrier) {
    final cur = p.cell.distanceTo(carrier.cell);
    BoardCell? best;
    var bestD = cur;
    for (final c in legalMoves(s, p)) {
      final d = c.distanceTo(carrier.cell);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }

  int _adjacentDefenders(BoardState s, Side side, BoardCell carrierCell) =>
      s.outfield(side).where((p) => p.cell.isAdjacent8(carrierCell)).length;

  bool _clearLine(BoardState s, BoardCell from, BoardCell to) {
    final dc = (to.col - from.col).sign;
    final dr = (to.row - from.row).sign;
    // Allow orthogonal AND diagonal straight lanes; reject L-shapes.
    if (dc != 0 &&
        dr != 0 &&
        (to.col - from.col).abs() != (to.row - from.row).abs()) {
      return false;
    }
    if (dc == 0 && dr == 0) return false;
    var c = BoardCell(from.col + dc, from.row + dr);
    while (c != to) {
      if (s.outfieldAt(c) != null) return false; // blocked by any piece
      c = BoardCell(c.col + dc, c.row + dr);
    }
    return true;
  }

  List<ChessAction> allActions(BoardState s, Side side) {
    final out = <ChessAction>[];
    for (final p in s.outfield(side)) {
      for (final v in availableActions(s, side, p)) {
        switch (v) {
          case BoardActionType.move:
            for (final c in legalMoves(s, p)) {
              out.add(ChessAction(type: v, pieceId: p.id, cell: c));
            }
          case BoardActionType.dribble:
            for (final t in dribbleTargets(s, p)) {
              out.add(ChessAction(type: v, pieceId: p.id, targetId: t));
            }
          case BoardActionType.pass:
            for (final t in passTargets(s, p)) {
              out.add(ChessAction(type: v, pieceId: p.id, targetId: t));
            }
          case BoardActionType.shoot:
          case BoardActionType.press:
          case BoardActionType.tackle:
          case BoardActionType.slide:
            out.add(ChessAction(type: v, pieceId: p.id));
        }
      }
    }
    return out;
  }

  // ---- Apply -------------------------------------------------------------

  /// Foul chance on a missed slide, and how long a red card benches a piece.
  static const double _foulChance = 0.3;
  static const int kBenchTurns = 2;

  ActionResult apply(BoardState s, ChessAction a) => switch (a.type) {
    BoardActionType.move => _move(s, a.pieceId, a.cell!),
    BoardActionType.dribble => _dribble(s, a.targetId!),
    BoardActionType.pass => _pass(s, a.targetId!),
    BoardActionType.shoot => _shoot(s),
    BoardActionType.press => _press(s, a.pieceId),
    BoardActionType.tackle => _tackle(s, a.pieceId),
    BoardActionType.slide => _slide(s, a.pieceId),
  };

  /// MOVE — reposition to an empty cell; if the mover is the carrier the ball
  /// goes with them (carry into space).
  ActionResult _move(BoardState s, String pieceId, BoardCell to) {
    var ns = s.withPieceAt(pieceId, to);
    if (s.carrier?.id == pieceId) ns = ns.copyWith(ballCell: to);
    return ActionResult(state: ns, event: BoardEvent.none);
  }

  /// DRIBBLE — take on an adjacent defender. Win → swap squares (advance past),
  /// ball follows. Lose → turnover to that defender.
  ActionResult _dribble(BoardState s, String defenderId) {
    final carrier = s.carrier!;
    final defender = s.pieceById(defenderId)!;
    final p = (dribbleWinProbability(carrier, defender)).clamp(0.0, 1.0);
    if (_random.nextDouble() < p) {
      final ns = s
          .withPieceAt(carrier.id, defender.cell)
          .withPieceAt(defender.id, carrier.cell)
          .copyWith(ballCell: defender.cell);
      return ActionResult(state: ns, event: BoardEvent.advanced);
    }
    return ActionResult(
      state: s.copyWith(ballCell: defender.cell, possession: defender.side),
      event: BoardEvent.turnover,
    );
  }

  ActionResult _pass(BoardState s, String targetId) {
    final target = s.pieceById(targetId)!;
    return ActionResult(
      state: s.copyWith(ballCell: target.cell),
      event: BoardEvent.advanced,
    );
  }

  ActionResult _shoot(BoardState s) {
    final shooter = s.carrier!;
    final goalP = (shotGoalProbability(s, shooter)).clamp(0.0, 1.0);
    if (_random.nextDouble() < goalP) {
      return ActionResult(
        state: s,
        event: BoardEvent.goal,
        scorer: shooter.side,
      );
    }
    // Missed: keeper/defender deals with it; possession flips to the defenders.
    final defending = shooter.side.opposite;
    final blocked = _shotBlockers(s, shooter) > 0;

    BoardState nextState;
    if (blocked) {
      nextState = _distributeTo(s, defending);
    } else {
      final keeper = s.keeperOf(defending);
      nextState = s.copyWith(ballCell: keeper.cell, possession: defending);
    }

    return ActionResult(
      state: nextState,
      event: blocked ? BoardEvent.blocked : BoardEvent.save,
    );
  }

  /// PRESS — close down: step one cell toward the carrier. Never wins the ball.
  ActionResult _press(BoardState s, String presserId) {
    final presser = s.pieceById(presserId)!;
    final carrier = s.carrier;
    if (carrier == null) return ActionResult(state: s, event: BoardEvent.none);
    final step = _pressStep(s, presser, carrier);
    if (step == null) return ActionResult(state: s, event: BoardEvent.none);
    return ActionResult(
      state: s.withPieceAt(presserId, step),
      event: BoardEvent.none,
    );
  }

  /// TACKLE — adjacent standing tackle: rating + outnumber; safe on a miss.
  ActionResult _tackle(BoardState s, String tacklerId) {
    final tackler = s.pieceById(tacklerId)!;
    final carrier = s.carrier!;
    final adj = _adjacentDefenders(s, tackler.side, carrier.cell);
    final p = (tackleWinProbability(
      tackler,
      carrier,
      adjacentCount: adj,
    )).clamp(0.0, 1.0);

    var ns = s.withPieceAt(tacklerId, tackler.cell, tackleCooldownTurns: 2);

    if (_random.nextDouble() < p) {
      return ActionResult(
        state: ns.copyWith(ballCell: tackler.cell, possession: tackler.side),
        event: BoardEvent.turnover,
      );
    }
    return ActionResult(state: ns, event: BoardEvent.none);
  }

  /// SLIDE — committed lunge (reach ≤2): high win chance, but a miss lets the
  /// carrier break past and risks a foul (yellow → red → benched).
  ActionResult _slide(BoardState s, String sliderId) {
    final slider = s.pieceById(sliderId)!;
    final carrier = s.carrier!;
    final p = (slideWinProbability(slider, carrier)).clamp(0.0, 1.0);

    var ns = s.withPieceAt(sliderId, slider.cell, slideCooldownTurns: 3);

    if (_random.nextDouble() < p) {
      final landing = _slideLanding(ns, slider, carrier) ?? slider.cell;
      return ActionResult(
        state: ns
            .withPieceAt(sliderId, landing, slideCooldownTurns: 3)
            .copyWith(ballCell: landing, possession: slider.side),
        event: BoardEvent.turnover,
      );
    }
    // Miss: maybe a foul + card.
    var card = CardType.none;
    if (_random.nextDouble() < _foulChance) {
      final red = slider.yellow; // already booked → second yellow = red
      card = red ? CardType.red : CardType.yellow;
      ns = ns.copyWith(
        pieces: [
          for (final pc in ns.pieces)
            if (pc.id == sliderId)
              pc.copyWith(
                yellow: true,
                benchedTurns: red ? kBenchTurns : pc.benchedTurns,
              )
            else
              pc,
        ],
      );
    }
    return ActionResult(state: ns, event: BoardEvent.none, card: card);
  }

  /// An empty cell adjacent to the carrier nearest the slider (the lunge end).
  BoardCell? _slideLanding(
    BoardState s,
    BoardPiece slider,
    BoardPiece carrier,
  ) {
    if (slider.cell.isAdjacent8(carrier.cell)) return slider.cell;
    BoardCell? best;
    var bestD = 999;
    for (final c in carrier.cell.neighbors8()) {
      if (c != slider.cell && !s.isEmpty(c)) continue;
      final d = slider.cell.distanceTo(c);
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }

  /// Hand the ball to [side] after a save/block: its outfielder nearest its own
  /// goal becomes the carrier.
  BoardState _distributeTo(BoardState s, Side side) {
    final mine = s.outfield(side);
    mine.sort((a, b) {
      // Nearest own goal: lowest row for the player, highest for the opponent.
      final da = side == Side.player ? a.cell.row : -a.cell.row;
      final db = side == Side.player ? b.cell.row : -b.cell.row;
      return da.compareTo(db);
    });
    final receiver = mine.first;
    return s.copyWith(ballCell: receiver.cell, possession: side);
  }

  // ---- Probabilities (pure) ---------------------------------------------

  int _shotBlockers(BoardState s, BoardPiece shooter) {
    final col = shooter.cell.col;
    final defending = shooter.side.opposite;
    var count = 0;
    if (shooter.side == Side.player) {
      for (var r = shooter.cell.row + 1; r < kBoardRows; r++) {
        final p = s.outfieldAt(BoardCell(col, r));
        if (p != null && p.side == defending) count++;
      }
    } else {
      for (var r = shooter.cell.row - 1; r >= 0; r--) {
        final p = s.outfieldAt(BoardCell(col, r));
        if (p != null && p.side == defending) count++;
      }
    }
    return count;
  }

  /// Goal probability for a shot from [shooter]: closer + clearer lane + a
  /// rating edge over the keeper = better. Pure (no RNG).
  double shotGoalProbability(BoardState s, BoardPiece shooter) {
    final dist = shooter.side == Side.player
        ? kBoardRows -
              shooter
                  .cell
                  .row // row 3 → 1, row 2 → 2
        : shooter.cell.row + 1; // row 0 → 1, row 1 → 2
    var p = dist <= 1 ? 0.55 : 0.30;
    p *= pow(0.45, _shotBlockers(s, shooter)).toDouble();
    final keeper = s.keeperOf(shooter.side.opposite);
    p *= 1 + (shooter.rating - keeper.rating) * 0.012;
    return p.clamp(0.03, 0.92);
  }

  /// Standing-tackle win chance: rating edge + a boost per extra adjacent
  /// team-mate ([adjacentCount] includes the tackler). Pure.
  double tackleWinProbability(
    BoardPiece tackler,
    BoardPiece carrier, {
    required int adjacentCount,
  }) {
    final outnumber = (adjacentCount - 1).clamp(0, 3) * 0.18;
    final p = 0.5 + (tackler.rating - carrier.rating) * 0.02 + outnumber;
    return p.clamp(0.15, 0.9);
  }

  /// Slide-tackle win chance: higher base than a lone tackle, but a miss lets
  /// the carrier break free. Pure.
  double slideWinProbability(BoardPiece slider, BoardPiece carrier) {
    final p = 0.62 + (slider.rating - carrier.rating) * 0.02;
    return p.clamp(0.2, 0.92);
  }

  /// Take-on win chance for the carrier dribbling a defender. Pure.
  double dribbleWinProbability(BoardPiece carrier, BoardPiece defender) {
    final p = 0.55 + (carrier.rating - defender.rating) * 0.02;
    return p.clamp(0.2, 0.9);
  }

  CoinSide tossCoin() => _random.nextBool() ? CoinSide.heads : CoinSide.tails;

  // ---- CPU ---------------------------------------------------------------

  /// Pick the opponent's strongest tactical action. Every candidate is scored
  /// across its probability-weighted outcomes and the player's best immediate
  /// reply. Only exactly equivalent choices use the separate decision RNG, so
  /// thinking never changes gameplay rolls.
  ChessAction? cpuChooseAction(BoardState s, CpuDecisionContext context) {
    final actions = allActions(s, Side.opponent);
    if (actions.isEmpty) return null;

    var bestScore = double.negativeInfinity;
    final best = <ChessAction>[];
    for (final a in actions) {
      final score = _scoreCpuAction(s, a, context);
      if (score > bestScore + 0.001) {
        bestScore = score;
        best
          ..clear()
          ..add(a);
      } else if ((score - bestScore).abs() <= 0.001) {
        best.add(a);
      }
    }
    return best[_decisionRandom.nextInt(best.length)];
  }

  double _scoreCpuAction(
    BoardState s,
    ChessAction action,
    CpuDecisionContext context,
  ) {
    var value = 0.0;
    for (final outcome in _expectedOutcomes(s, action)) {
      value +=
          outcome.probability * _valueAfterCpuOutcome(outcome.result, context);
    }
    return value + _contextualActionBias(s, action, context);
  }

  double _valueAfterCpuOutcome(
    ActionResult outcome,
    CpuDecisionContext context,
  ) {
    if (outcome.event == BoardEvent.goal) {
      return outcome.scorer == Side.opponent ? 1200 : -1200;
    }

    final afterCpu = _boardUtility(outcome.state, context);
    final replies = allActions(outcome.state, Side.player);
    if (replies.isEmpty) return afterCpu;

    var strongestReply = double.infinity;
    for (final reply in replies) {
      var replyValue = 0.0;
      for (final response in _expectedOutcomes(outcome.state, reply)) {
        final result = response.result;
        final value = result.event == BoardEvent.goal
            ? (result.scorer == Side.player ? -1200.0 : 1200.0)
            : _boardUtility(result.state, context);
        replyValue += response.probability * value;
      }
      strongestReply = min(strongestReply, replyValue);
    }

    // Keep some value on the position the CPU creates, but make the player's
    // strongest counter the dominant part of the decision.
    return afterCpu * 0.35 + strongestReply * 0.65;
  }

  double _boardUtility(BoardState s, CpuDecisionContext context) {
    final carrier = s.carrier;
    var value = s.possession == Side.opponent ? 150.0 : -165.0;

    if (carrier != null && !carrier.isKeeper) {
      if (carrier.side == Side.opponent) {
        final progress = (kBoardRows - 1 - carrier.cell.row).toDouble();
        value += progress * 44;
        value += passTargets(s, carrier).length * 11;
        if (carrier.cell.isShootingHalfFor(Side.opponent)) {
          value += shotGoalProbability(s, carrier) * 290;
        }
        final pressure = _adjacentDefenders(s, Side.player, carrier.cell);
        value -= pressure * 28;
      } else {
        final danger = carrier.cell.row.toDouble();
        value -= danger * 52;
        value -= passTargets(s, carrier).length * 12;
        if (carrier.cell.isShootingHalfFor(Side.player)) {
          value -= shotGoalProbability(s, carrier) * 340;
          value += _shotBlockers(s, carrier) * 42;
        }

        final counters = context.recentPlayerActions;
        final dribbles = _frequency(counters, BoardActionType.dribble);
        final passes = _frequency(counters, BoardActionType.pass);
        final shoots = _frequency(counters, BoardActionType.shoot);
        final carries = _frequency(counters, BoardActionType.move);
        final crowd = _adjacentDefenders(s, Side.opponent, carrier.cell);
        value += crowd * dribbles * 18;
        value -= passTargets(s, carrier).length * passes * 7;
        value -= shotGoalProbability(s, carrier) * shoots * 42;
        value -= danger * carries * 5;
      }
    }

    for (final piece in s.pieces) {
      final sign = piece.side == Side.opponent ? 1.0 : -1.0;
      if (piece.benched) value += sign * -145;
      if (piece.yellow) value += sign * -24;
      value +=
          sign *
          -(piece.tackleCooldownTurns * 4 + piece.slideCooldownTurns * 3);
      if (!piece.isKeeper && piece.cell.col == 1) value += sign * 5;
    }

    final late = context.clockRemaining <= 30;
    final cpuLeading = context.opponentScore > context.playerScore;
    final cpuTrailing = context.opponentScore < context.playerScore;
    if (late && cpuLeading) {
      value += s.possession == Side.opponent ? 95 : -65;
    } else if (late && cpuTrailing) {
      if (carrier != null && carrier.side == Side.opponent) {
        value += (kBoardRows - 1 - carrier.cell.row) * 18;
        if (carrier.cell.isShootingHalfFor(Side.opponent)) {
          value += shotGoalProbability(s, carrier) * 100;
        }
      }
    }

    return value;
  }

  int _frequency(List<BoardActionType> actions, BoardActionType action) =>
      actions.where((candidate) => candidate == action).length;

  double _contextualActionBias(
    BoardState s,
    ChessAction action,
    CpuDecisionContext context,
  ) {
    final piece = s.pieceById(action.pieceId)!;
    final carrier = s.carrier;
    var bias = 0.0;

    final late = context.clockRemaining <= 30;
    final cpuLeading = context.opponentScore > context.playerScore;
    final cpuTrailing = context.opponentScore < context.playerScore;
    if (late && cpuLeading && s.possession == Side.opponent) {
      if (action.type == BoardActionType.pass) bias += 48;
      if (action.type == BoardActionType.shoot) {
        final chance = shotGoalProbability(s, piece);
        bias -= (1 - chance) * 105;
      }
      if (action.type == BoardActionType.dribble) {
        final defender = s.pieceById(action.targetId!)!;
        bias -= (1 - dribbleWinProbability(piece, defender)) * 75;
      }
    }
    if (late && cpuTrailing) {
      if (action.type == BoardActionType.shoot) {
        bias += shotGoalProbability(s, piece) * 250;
        if (context.clockRemaining <= 10) bias += 350;
      }
      if (action.type == BoardActionType.pass) bias += 16;
    }

    final recent = context.recentPlayerActions;
    final shoots = _frequency(recent, BoardActionType.shoot);
    final dribbles = _frequency(recent, BoardActionType.dribble);
    final passes = _frequency(recent, BoardActionType.pass);
    if (carrier != null && carrier.side == Side.player) {
      if (action.type == BoardActionType.tackle) {
        bias += shoots * 12 + dribbles * 14;
      }
      if (action.type == BoardActionType.press) {
        bias += shoots * 10 + passes * 8;
      }
      if (action.type == BoardActionType.slide) {
        final chance = slideWinProbability(piece, carrier);
        bias -= (1 - chance) * (55 + (piece.yellow ? 90 : 0));
      }
    }

    switch (action.type) {
      case BoardActionType.shoot:
        final chance = shotGoalProbability(s, piece);
        bias += chance * 80 - (1 - chance) * 24;
      case BoardActionType.tackle:
        final adjacent = _adjacentDefenders(s, Side.opponent, carrier!.cell);
        bias +=
            tackleWinProbability(piece, carrier, adjacentCount: adjacent) * 34 +
            carrier.cell.row * 8;
      case BoardActionType.slide:
        final chance = slideWinProbability(piece, carrier!);
        bias += chance * 24 - (1 - chance) * 58;
        if (piece.yellow) bias -= 70;
      case BoardActionType.press:
        bias += 22 + carrier!.cell.row * 6;
      case BoardActionType.pass:
        final target = s.pieceById(action.targetId!)!;
        final advance = (s.ballCell.row - target.cell.row).toDouble();
        final pressure = target.cell
            .neighbors8()
            .map(s.outfieldAt)
            .where((p) => p != null && p.side == Side.player)
            .length;
        bias += advance * 18 - pressure * 24;
      case BoardActionType.dribble:
        final defender = s.pieceById(action.targetId!)!;
        final chance = dribbleWinProbability(piece, defender);
        final advance = (s.ballCell.row - defender.cell.row).toDouble();
        bias += chance * 38 + advance * 16 - (1 - chance) * 34;
      case BoardActionType.move:
        if (carrier != null &&
            carrier.side == Side.player &&
            action.cell != null) {
          final before = piece.cell.distanceTo(carrier.cell);
          final after = action.cell!.distanceTo(carrier.cell);
          bias += (before - after) * 12;
        }
    }
    return bias;
  }

  List<_ExpectedOutcome> _expectedOutcomes(BoardState s, ChessAction action) {
    switch (action.type) {
      case BoardActionType.move:
        return [_ExpectedOutcome(1, _move(s, action.pieceId, action.cell!))];
      case BoardActionType.pass:
        return [_ExpectedOutcome(1, _pass(s, action.targetId!))];
      case BoardActionType.press:
        return [_ExpectedOutcome(1, _press(s, action.pieceId))];
      case BoardActionType.dribble:
        final carrier = s.carrier!;
        final defender = s.pieceById(action.targetId!)!;
        final chance = dribbleWinProbability(carrier, defender);
        final success = s
            .withPieceAt(carrier.id, defender.cell)
            .withPieceAt(defender.id, carrier.cell)
            .copyWith(ballCell: defender.cell);
        final failure = s.copyWith(
          ballCell: defender.cell,
          possession: defender.side,
        );
        return [
          _ExpectedOutcome(
            chance,
            ActionResult(state: success, event: BoardEvent.advanced),
          ),
          _ExpectedOutcome(
            1 - chance,
            ActionResult(state: failure, event: BoardEvent.turnover),
          ),
        ];
      case BoardActionType.shoot:
        final shooter = s.carrier!;
        final chance = shotGoalProbability(s, shooter);
        return [
          _ExpectedOutcome(
            chance,
            ActionResult(
              state: s,
              event: BoardEvent.goal,
              scorer: shooter.side,
            ),
          ),
          _ExpectedOutcome(1 - chance, _missedShotOutcome(s, shooter)),
        ];
      case BoardActionType.tackle:
        final tackler = s.pieceById(action.pieceId)!;
        final carrier = s.carrier!;
        final adjacent = _adjacentDefenders(s, tackler.side, carrier.cell);
        final chance = tackleWinProbability(
          tackler,
          carrier,
          adjacentCount: adjacent,
        );
        final base = s.withPieceAt(
          tackler.id,
          tackler.cell,
          tackleCooldownTurns: 2,
        );
        return [
          _ExpectedOutcome(
            chance,
            ActionResult(
              state: base.copyWith(
                ballCell: tackler.cell,
                possession: tackler.side,
              ),
              event: BoardEvent.turnover,
            ),
          ),
          _ExpectedOutcome(
            1 - chance,
            ActionResult(state: base, event: BoardEvent.none),
          ),
        ];
      case BoardActionType.slide:
        final slider = s.pieceById(action.pieceId)!;
        final carrier = s.carrier!;
        final chance = slideWinProbability(slider, carrier);
        final base = s.withPieceAt(
          slider.id,
          slider.cell,
          slideCooldownTurns: 3,
        );
        final landing = _slideLanding(base, slider, carrier) ?? slider.cell;
        final success = base
            .withPieceAt(slider.id, landing, slideCooldownTurns: 3)
            .copyWith(ballCell: landing, possession: slider.side);
        final red = slider.yellow;
        final card = red ? CardType.red : CardType.yellow;
        final booked = base.copyWith(
          pieces: [
            for (final piece in base.pieces)
              if (piece.id == slider.id)
                piece.copyWith(
                  yellow: true,
                  benchedTurns: red ? kBenchTurns : piece.benchedTurns,
                )
              else
                piece,
          ],
        );
        final miss = 1 - chance;
        return [
          _ExpectedOutcome(
            chance,
            ActionResult(state: success, event: BoardEvent.turnover),
          ),
          _ExpectedOutcome(
            miss * (1 - _foulChance),
            ActionResult(state: base, event: BoardEvent.none),
          ),
          _ExpectedOutcome(
            miss * _foulChance,
            ActionResult(state: booked, event: BoardEvent.none, card: card),
          ),
        ];
    }
  }

  ActionResult _missedShotOutcome(BoardState s, BoardPiece shooter) {
    final defending = shooter.side.opposite;
    final blocked = _shotBlockers(s, shooter) > 0;
    final nextState = blocked
        ? _distributeTo(s, defending)
        : s.copyWith(
            ballCell: s.keeperOf(defending).cell,
            possession: defending,
          );
    return ActionResult(
      state: nextState,
      event: blocked ? BoardEvent.blocked : BoardEvent.save,
    );
  }
}
