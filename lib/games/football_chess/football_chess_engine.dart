import 'dart:math';

import '../../models/cards.dart';
import '../../models/football_chess.dart';
import '../../models/progression.dart';
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

/// Pure rules engine for grid Football Chess. All randomness flows through an
/// injectable [Random]; the probability helpers are pure so they can be asserted
/// directly in tests.
class FootballChessEngine {
  FootballChessEngine({Random? random}) : _random = random ?? Random();

  final Random _random;

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

  /// Pick the opponent's action. A low-level CPU plays loosely (random legal
  /// move); a smart one advances, shoots in range, and presses to win the ball.
  ChessAction? cpuChooseAction(BoardState s, int level) {
    final actions = allActions(s, Side.opponent);
    if (actions.isEmpty) return null;
    if (_random.nextDouble() > cpuSmartness(level)) {
      return actions[_random.nextInt(actions.length)];
    }
    ChessAction? best;
    var bestScore = -1e9;
    for (final a in actions) {
      final score = _scoreCpuAction(s, a);
      if (score > bestScore) {
        bestScore = score;
        best = a;
      }
    }
    return best ?? actions[_random.nextInt(actions.length)];
  }

  double _scoreCpuAction(BoardState s, ChessAction a) {
    final piece = s.pieceById(a.pieceId)!;
    final carrier = s.carrier;
    
    switch (a.type) {
      case BoardActionType.shoot:
        // Scale purely by probability. A 10% shot is 15, an 80% shot is 120.
        // Prevents mindless shooting from terrible positions.
        return shotGoalProbability(s, piece) * 150.0;
        
      case BoardActionType.tackle:
        final adj = _adjacentDefenders(s, Side.opponent, carrier!.cell);
        final win = tackleWinProbability(piece, carrier, adjacentCount: adj);
        // Increased desperation if the player is closer to the CPU goal (row 3).
        final danger = carrier.cell.row * 10.0;
        return 40.0 + danger + win * 50.0;
        
      case BoardActionType.slide:
        final win = slideWinProbability(piece, carrier!);
        final danger = carrier.cell.row * 15.0; // Higher desperation modifier
        // High reward, but discount the risk of missing.
        return 30.0 + danger + win * 50.0 - (1.0 - win) * 35.0;
        
      case BoardActionType.press:
        final step = _pressStep(s, piece, carrier!);
        if (step == null) return 0.0; // Failsafe
        final before = piece.cell.distanceTo(carrier.cell);
        final after = step.distanceTo(carrier.cell);
        final progress = (before - after).toDouble();
        // Bonus for getting between the carrier and the goal.
        final blockingBonus = (step.row > carrier.cell.row) ? 10.0 : 0.0;
        return 20.0 + progress * 15.0 + carrier.cell.row * 5.0 + blockingBonus;
        
      case BoardActionType.pass:
        final t = s.pieceById(a.targetId!)!;
        final advance = (s.ballCell.row - t.cell.row).toDouble();
        
        // Evaluate if the target is open
        int pressure = 0;
        for (final n in t.cell.neighbors8()) {
          final opp = s.outfieldAt(n);
          if (opp != null && opp.side == Side.player) pressure++;
        }
        return 35.0 + advance * 15.0 - pressure * 12.0;
        
      case BoardActionType.dribble:
        final defender = s.pieceById(a.targetId!)!;
        final win = dribbleWinProbability(piece, defender);
        final advance = (s.ballCell.row - defender.cell.row).toDouble();
        return 25.0 + win * 40.0 + advance * 15.0;
        
      case BoardActionType.move:
        if (carrier != null && carrier.side == Side.player) {
          // Defending move (not pressing, just repositioning)
          final before = piece.cell.distanceTo(carrier.cell);
          final after = a.cell!.distanceTo(carrier.cell);
          final progress = (before - after).toDouble();
          return 10.0 + progress * 10.0;
        }
        
        if (carrier != null && carrier.side == Side.opponent) {
          if (carrier.id == piece.id) {
            // Carrier moving into space
            final advance = (piece.cell.row - a.cell!.row).toDouble();
            return 25.0 + advance * 20.0;
          } else {
            // Off-ball attacker making a run
            final advance = (piece.cell.row - a.cell!.row).toDouble();
            final spread = (a.cell!.col - carrier.cell.col).abs().toDouble();
            return 15.0 + advance * 12.0 + spread * 5.0;
          }
        }
        return 5.0;
    }
  }
}
