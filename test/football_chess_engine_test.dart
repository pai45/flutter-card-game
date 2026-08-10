import 'dart:math';

import 'package:card_game/games/football_chess/football_chess_board.dart';
import 'package:card_game/games/football_chess/football_chess_engine.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/football_chess.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountingRandom implements Random {
  int calls = 0;

  @override
  bool nextBool() {
    calls++;
    return false;
  }

  @override
  double nextDouble() {
    calls++;
    return 0.5;
  }

  @override
  int nextInt(int max) {
    calls++;
    return 0;
  }
}

void main() {
  final engine = FootballChessEngine(random: Random(7));

  final strongAtk =
      (attackers.toList()..sort((a, b) => b.rating.compareTo(a.rating))).first;
  final weakAtk =
      (attackers.toList()..sort((a, b) => a.rating.compareTo(b.rating))).first;
  final strongDef =
      (defenders.toList()..sort((a, b) => b.rating.compareTo(a.rating))).first;
  final strongGk =
      (goalkeepers.toList()..sort((a, b) => b.rating.compareTo(a.rating)))
          .first;

  BoardPiece mk(
    String id,
    Side side,
    BoardCell cell,
    PlayerCard card, {
    bool keeper = false,
  }) =>
      BoardPiece(id: id, card: card, side: side, cell: cell, isKeeper: keeper);

  test('initial board: ball with kickoff side; keepers off-grid', () {
    final p = [
      attackers[0],
      attackers[1],
      defenders[0],
      defenders[1],
      goalkeepers[0],
    ];
    final o = [
      attackers[2],
      attackers[3],
      defenders[2],
      defenders[3],
      goalkeepers[1],
    ];
    final s = engine.initialBoard(
      playerSquad: p,
      opponentSquad: o,
      playerFormation: ChessFormation.box,
      opponentFormation: ChessFormation.box,
      kickoff: Side.player,
    );
    expect(s.outfield(Side.player), hasLength(4));
    expect(s.carrier?.side, Side.player);
    expect(s.keeperOf(Side.player).cell.row, -1);
    expect(s.keeperOf(Side.opponent).cell.row, kBoardRows);
  });

  test('legal moves are 8-directional (diagonals included)', () {
    final p = mk('p0', Side.player, const BoardCell(1, 1), strongAtk);
    final s = BoardState(
      pieces: [p],
      ballCell: const BoardCell(1, 1),
      possession: Side.player,
    );
    final moves = engine.legalMoves(s, p);
    expect(moves, contains(const BoardCell(0, 0))); // diagonal
    expect(moves, contains(const BoardCell(2, 2))); // diagonal
    expect(moves, contains(const BoardCell(1, 2))); // orthogonal
    expect(moves, hasLength(8)); // all neighbours empty + in bounds
  });

  group('available actions', () {
    test('carrier with an adjacent opponent: move, dribble, shoot', () {
      final carrier = mk('p0', Side.player, const BoardCell(1, 2), strongAtk);
      final foe = mk('o0', Side.opponent, const BoardCell(1, 3), strongDef);
      final s = BoardState(
        pieces: [carrier, foe],
        ballCell: const BoardCell(1, 2),
        possession: Side.player,
      );
      final verbs = engine.availableActions(s, Side.player, carrier);
      expect(verbs, contains(BoardActionType.move));
      expect(verbs, contains(BoardActionType.dribble));
      expect(verbs, contains(BoardActionType.shoot)); // in opponent half
    });

    test('defending adjacent (incl. diagonal) → tackle + slide', () {
      final carrier = mk('o0', Side.opponent, const BoardCell(1, 2), weakAtk);
      final diag = mk('p0', Side.player, const BoardCell(2, 3), strongDef);
      final s = BoardState(
        pieces: [carrier, diag],
        ballCell: const BoardCell(1, 2),
        possession: Side.opponent,
      );
      final verbs = engine.availableActions(s, Side.player, diag);
      expect(verbs, contains(BoardActionType.tackle)); // Chebyshev 1
      expect(verbs, contains(BoardActionType.slide));
      expect(verbs, isNot(contains(BoardActionType.press)));
    });

    test('benched piece has no actions', () {
      final p = BoardPiece(
        id: 'p0',
        card: strongAtk,
        side: Side.player,
        cell: const BoardCell(1, 1),
        isKeeper: false,
        benchedTurns: 2,
      );
      final s = BoardState(
        pieces: [p],
        ballCell: const BoardCell(1, 1),
        possession: Side.player,
      );
      expect(engine.availableActions(s, Side.player, p), isEmpty);
    });
  });

  group('dribble take-on', () {
    test('a win swaps squares and keeps the ball; a loss is a turnover', () {
      final carrier = mk('p0', Side.player, const BoardCell(1, 1), strongAtk);
      final foe = mk('o0', Side.opponent, const BoardCell(1, 2), weakAtk);
      final s = BoardState(
        pieces: [carrier, foe],
        ballCell: const BoardCell(1, 1),
        possession: Side.player,
      );
      var sawWin = false;
      var sawLoss = false;
      for (var i = 0; i < 80; i++) {
        final r = FootballChessEngine(random: Random(i)).apply(
          s,
          const ChessAction(
            type: BoardActionType.dribble,
            pieceId: 'p0',
            targetId: 'o0',
          ),
        );
        if (r.event == BoardEvent.advanced) {
          expect(
            r.state.pieceById('p0')!.cell,
            const BoardCell(1, 2),
          ); // swapped
          expect(r.state.pieceById('o0')!.cell, const BoardCell(1, 1));
          expect(r.state.ballCell, const BoardCell(1, 2));
          sawWin = true;
        } else if (r.event == BoardEvent.turnover) {
          expect(r.state.possession, Side.opponent);
          sawLoss = true;
        }
        if (sawWin && sawLoss) break;
      }
      expect(sawWin, isTrue);
      expect(sawLoss, isTrue);
    });
  });

  group('slide fouls', () {
    test('a missed slide can book the slider', () {
      // Weak slider vs strong carrier → frequent misses → cards appear.
      final carrier = mk('o0', Side.opponent, const BoardCell(1, 2), strongAtk);
      final slider = mk('p0', Side.player, const BoardCell(1, 1), weakAtk);
      final s = BoardState(
        pieces: [carrier, slider],
        ballCell: const BoardCell(1, 2),
        possession: Side.opponent,
      );
      var sawCard = false;
      for (var i = 0; i < 120; i++) {
        final r = FootballChessEngine(random: Random(i)).apply(
          s,
          const ChessAction(type: BoardActionType.slide, pieceId: 'p0'),
        );
        if (r.card != CardType.none) {
          expect(r.state.pieceById('p0')!.yellow, isTrue);
          sawCard = true;
          break;
        }
      }
      expect(sawCard, isTrue);
    });
  });

  test('press steps the defender closer without changing possession', () {
    final carrier = mk('o0', Side.opponent, const BoardCell(1, 2), weakAtk);
    final d = mk('p0', Side.player, const BoardCell(1, 0), strongDef);
    final s = BoardState(
      pieces: [carrier, d],
      ballCell: const BoardCell(1, 2),
      possession: Side.opponent,
    );
    final r = engine.apply(
      s,
      const ChessAction(type: BoardActionType.press, pieceId: 'p0'),
    );
    expect(r.event, BoardEvent.none);
    expect(r.state.possession, Side.opponent);
    expect(
      r.state.pieceById('p0')!.cell.distanceTo(carrier.cell),
      lessThan(d.cell.distanceTo(carrier.cell)),
    );
  });

  test('shooting: closer + clear lane + weaker keeper = higher chance', () {
    BoardState shot(BoardCell at, {List<BoardPiece> extra = const []}) =>
        BoardState(
          pieces: [
            mk('p0', Side.player, at, strongAtk),
            mk(
              'ok',
              Side.opponent,
              const BoardCell(1, kBoardRows),
              strongGk,
              keeper: true,
            ),
            ...extra,
          ],
          ballCell: at,
          possession: Side.player,
        );
    final near = shot(const BoardCell(1, 3));
    final far = shot(const BoardCell(1, 2));
    expect(
      engine.shotGoalProbability(near, near.carrier!),
      greaterThan(engine.shotGoalProbability(far, far.carrier!)),
    );
    final blocked = shot(
      const BoardCell(1, 2),
      extra: [mk('o1', Side.opponent, const BoardCell(1, 3), strongDef)],
    );
    expect(
      engine.shotGoalProbability(blocked, blocked.carrier!),
      lessThan(engine.shotGoalProbability(far, far.carrier!)),
    );
  });

  test('pass accepts diagonal clear lane', () {
    // Carrier at (0,0); teammate at (2,2); no blocker at (1,1). passTargets
    // returns piece IDs — expect 'p1' to be included.
    final carrier = mk('p0', Side.player, const BoardCell(0, 0), strongAtk);
    final mate = mk('p1', Side.player, const BoardCell(2, 2), weakAtk);
    final s = BoardState(
      pieces: [carrier, mate],
      ballCell: const BoardCell(0, 0),
      possession: Side.player,
    );
    expect(engine.passTargets(s, carrier), contains('p1'));
  });

  test('pass rejects diagonal L-shape', () {
    final carrier = mk('p0', Side.player, const BoardCell(0, 0), strongAtk);
    final mate = mk('p1', Side.player, const BoardCell(2, 3), weakAtk);
    final s = BoardState(
      pieces: [carrier, mate],
      ballCell: const BoardCell(0, 0),
      possession: Side.player,
    );
    expect(engine.passTargets(s, carrier), isNot(contains('p1')));
  });

  test('diagonal pass is blocked by a piece in the lane', () {
    final carrier = mk('p0', Side.player, const BoardCell(0, 0), strongAtk);
    final blocker = mk('o0', Side.opponent, const BoardCell(1, 1), strongDef);
    final mate = mk('p1', Side.player, const BoardCell(2, 2), weakAtk);
    final s = BoardState(
      pieces: [carrier, blocker, mate],
      ballCell: const BoardCell(0, 0),
      possession: Side.player,
    );
    expect(engine.passTargets(s, carrier), isNot(contains('p1')));
  });

  test('coin toss is roughly fair', () {
    final rng = FootballChessEngine(random: Random(3));
    var heads = 0;
    const flips = 2000;
    for (var i = 0; i < flips; i++) {
      if (rng.tossCoin() == CoinSide.heads) heads++;
    }
    expect(heads / flips, closeTo(0.5, 0.06));
  });

  group('full-strength CPU tactics', () {
    CpuDecisionContext context({
      int playerScore = 0,
      int opponentScore = 0,
      double clock = 80,
      List<BoardActionType> recent = const [],
    }) => CpuDecisionContext(
      playerScore: playerScore,
      opponentScore: opponentScore,
      clockRemaining: clock,
      recentPlayerActions: recent,
    );

    BoardState board({
      required List<BoardPiece> outfield,
      required Side possession,
      required String carrierId,
    }) {
      final carrier = outfield.firstWhere((piece) => piece.id == carrierId);
      return BoardState(
        pieces: [
          ...outfield,
          mk('pk', Side.player, const BoardCell(1, -1), strongGk, keeper: true),
          mk(
            'ok',
            Side.opponent,
            const BoardCell(1, kBoardRows),
            strongGk,
            keeper: true,
          ),
        ],
        ballCell: carrier.cell,
        possession: possession,
      );
    }

    FootballChessEngine cpu() =>
        FootballChessEngine(random: Random(91), decisionRandom: Random(7));

    test('takes a clear high-quality shot', () {
      final state = board(
        outfield: [
          mk('o0', Side.opponent, const BoardCell(1, 0), strongAtk),
          mk('p0', Side.player, const BoardCell(2, 3), weakAtk),
        ],
        possession: Side.opponent,
        carrierId: 'o0',
      );

      final action = cpu().cpuChooseAction(state, context());

      expect(action?.type, BoardActionType.shoot);
    });

    test('rejects a blocked speculative shot for a progressive pass', () {
      final state = board(
        outfield: [
          mk('o0', Side.opponent, const BoardCell(1, 1), strongAtk),
          mk('o1', Side.opponent, const BoardCell(0, 0), strongAtk),
          mk('p0', Side.player, const BoardCell(1, 0), strongDef),
          mk('p1', Side.player, const BoardCell(2, 3), weakAtk),
        ],
        possession: Side.opponent,
        carrierId: 'o0',
      );

      final action = cpu().cpuChooseAction(state, context());

      expect(action?.type, BoardActionType.pass);
      expect(action?.targetId, 'o1');
    });

    test('uses the safe standing tackle against an immediate threat', () {
      final state = board(
        outfield: [
          mk('p0', Side.player, const BoardCell(1, 3), weakAtk),
          mk('o0', Side.opponent, const BoardCell(1, 2), strongDef),
          mk('o1', Side.opponent, const BoardCell(0, 2), strongDef),
        ],
        possession: Side.player,
        carrierId: 'p0',
      );

      final action = cpu().cpuChooseAction(
        state,
        context(recent: const [BoardActionType.dribble, BoardActionType.shoot]),
      );

      expect(action?.type, BoardActionType.tackle);
    });

    test('passes to the open forward instead of a marked receiver', () {
      final state = board(
        outfield: [
          mk('o0', Side.opponent, const BoardCell(1, 3), strongAtk),
          mk('o1', Side.opponent, const BoardCell(1, 0), strongAtk),
          mk('o2', Side.opponent, const BoardCell(2, 2), weakAtk),
          mk('p0', Side.player, const BoardCell(2, 3), strongDef),
          mk('p1', Side.player, const BoardCell(0, 2), weakAtk),
        ],
        possession: Side.opponent,
        carrierId: 'o0',
      );

      final action = cpu().cpuChooseAction(state, context());

      expect(action?.type, BoardActionType.pass);
      expect(action?.targetId, 'o1');
    });

    test('presses a repeat shooter before another clear attempt', () {
      final state = board(
        outfield: [
          mk('p0', Side.player, const BoardCell(1, 2), strongAtk),
          mk('o0', Side.opponent, const BoardCell(0, 0), strongDef),
          mk('o1', Side.opponent, const BoardCell(2, 0), strongDef),
        ],
        possession: Side.player,
        carrierId: 'p0',
      );

      final action = cpu().cpuChooseAction(
        state,
        context(
          recent: const [
            BoardActionType.shoot,
            BoardActionType.shoot,
            BoardActionType.pass,
          ],
        ),
      );

      expect(action?.type, BoardActionType.press);
    });

    test('protects a late lead but attacks when trailing', () {
      final state = board(
        outfield: [
          mk('o0', Side.opponent, const BoardCell(1, 1), strongAtk),
          mk('o1', Side.opponent, const BoardCell(0, 1), strongAtk),
          mk('p0', Side.player, const BoardCell(2, 3), weakAtk),
        ],
        possession: Side.opponent,
        carrierId: 'o0',
      );

      final leading = cpu().cpuChooseAction(
        state,
        context(opponentScore: 1, clock: 8),
      );
      final trailing = cpu().cpuChooseAction(
        state,
        context(playerScore: 1, clock: 8),
      );

      expect(leading?.type, isNot(BoardActionType.shoot));
      expect(trailing?.type, BoardActionType.shoot);
    });

    test('decision search does not consume gameplay randomness', () {
      final gameplayRandom = _CountingRandom();
      final engine = FootballChessEngine(
        random: gameplayRandom,
        decisionRandom: Random(3),
      );
      final state = board(
        outfield: [
          mk('o0', Side.opponent, const BoardCell(1, 0), strongAtk),
          mk('p0', Side.player, const BoardCell(2, 3), weakAtk),
        ],
        possession: Side.opponent,
        carrierId: 'o0',
      );

      final action = engine.cpuChooseAction(state, context());

      expect(action, isNotNull);
      expect(gameplayRandom.calls, 0);
    });
  });
}
