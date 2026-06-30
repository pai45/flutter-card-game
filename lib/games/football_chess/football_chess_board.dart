import 'dart:math';

import '../../models/cards.dart';
import '../../models/football_chess.dart';

/// Board dimensions: 3 columns (L/C/R) × 4 rows. Rows 0–1 = player half (bottom),
/// rows 2–3 = opponent half (top). Goals sit just beyond row 0 (player) and row 3
/// (opponent), where the keepers stand off-grid.
const int kBoardCols = 3;
const int kBoardRows = 4;

/// A grid cell. [row] 0 is the player's back row (bottom of the vertical pitch);
/// row 3 is the opponent's back row (top).
class BoardCell {
  const BoardCell(this.col, this.row);

  final int col;
  final int row;

  bool get inBounds =>
      col >= 0 && col < kBoardCols && row >= 0 && row < kBoardRows;

  bool get inPlayerHalf => row <= 1;
  bool get inOpponentHalf => row >= 2;

  /// The opponent attacks toward the bottom; the player toward the top. This is
  /// the half a [side] is *attacking into* (where it may shoot from).
  bool isShootingHalfFor(Side side) =>
      side == Side.player ? inOpponentHalf : inPlayerHalf;

  List<BoardCell> orthoNeighbors() => [
    BoardCell(col, row - 1),
    BoardCell(col, row + 1),
    BoardCell(col - 1, row),
    BoardCell(col + 1, row),
  ].where((c) => c.inBounds).toList();

  /// All 8 in-bounds neighbours (orthogonal + diagonal).
  List<BoardCell> neighbors8() => [
    for (var dc = -1; dc <= 1; dc++)
      for (var dr = -1; dr <= 1; dr++)
        if (!(dc == 0 && dr == 0)) BoardCell(col + dc, row + dr),
  ].where((c) => c.inBounds).toList();

  /// Chebyshev distance (a diagonal step counts as 1).
  int distanceTo(BoardCell o) => max((col - o.col).abs(), (row - o.row).abs());

  bool isAdjacent8(BoardCell o) => distanceTo(o) == 1;

  bool isOrthoAdjacent(BoardCell o) =>
      (col == o.col && (row - o.row).abs() == 1) ||
      (row == o.row && (col - o.col).abs() == 1);

  @override
  bool operator ==(Object other) =>
      other is BoardCell && other.col == col && other.row == row;

  @override
  int get hashCode => Object.hash(col, row);

  @override
  String toString() => 'C($col,$row)';
}

/// A player on the board. Outfielders occupy grid cells; the keeper is flagged
/// [isKeeper] and parked in the goal (its [cell] is a sentinel just off-grid).
class BoardPiece {
  const BoardPiece({
    required this.id,
    required this.card,
    required this.side,
    required this.cell,
    required this.isKeeper,
    this.yellow = false,
    this.benchedTurns = 0,
    this.tackleCooldownTurns = 0,
    this.slideCooldownTurns = 0,
  });

  final String id;
  final PlayerCard card;
  final Side side;
  final BoardCell cell;
  final bool isKeeper;

  /// Has a yellow card (a second booking sends them off → benched).
  final bool yellow;

  /// Turns the piece must sit out (red card); 0 = available.
  final int benchedTurns;

  /// Cooldowns for actions (in turns). Ticks down at start of side's turn.
  final int tackleCooldownTurns;
  final int slideCooldownTurns;

  int get rating => card.rating;
  bool get benched => benchedTurns > 0;

  BoardPiece copyWith({
    BoardCell? cell,
    bool? yellow,
    int? benchedTurns,
    int? tackleCooldownTurns,
    int? slideCooldownTurns,
  }) => BoardPiece(
    id: id,
    card: card,
    side: side,
    cell: cell ?? this.cell,
    isKeeper: isKeeper,
    yellow: yellow ?? this.yellow,
    benchedTurns: benchedTurns ?? this.benchedTurns,
    tackleCooldownTurns: tackleCooldownTurns ?? this.tackleCooldownTurns,
    slideCooldownTurns: slideCooldownTurns ?? this.slideCooldownTurns,
  );
}

/// Immutable spatial state: where everyone is, where the ball is, and who holds
/// it. Scores/clock/turn live in the cubit; the board stays purely positional.
class BoardState {
  const BoardState({
    required this.pieces,
    required this.ballCell,
    required this.possession,
  });

  /// All ten players — eight outfielders on the grid + two keepers off-grid.
  final List<BoardPiece> pieces;

  /// The cell the ball is on (always occupied by the possessing side's carrier).
  final BoardCell ballCell;

  final Side possession;

  BoardState copyWith({
    List<BoardPiece>? pieces,
    BoardCell? ballCell,
    Side? possession,
  }) => BoardState(
    pieces: pieces ?? this.pieces,
    ballCell: ballCell ?? this.ballCell,
    possession: possession ?? this.possession,
  );

  List<BoardPiece> outfield(Side side) => [
    for (final p in pieces)
      if (p.side == side && !p.isKeeper) p,
  ];

  BoardPiece keeperOf(Side side) =>
      pieces.firstWhere((p) => p.side == side && p.isKeeper);

  BoardPiece? pieceById(String id) {
    for (final p in pieces) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// The piece (outfielder or keeper) standing on [cell], or null.
  BoardPiece? pieceAt(BoardCell cell) {
    for (final p in pieces) {
      if (p.cell == cell) return p;
    }
    return null;
  }

  /// The outfielder standing on [cell], or null.
  BoardPiece? outfieldAt(BoardCell cell) {
    for (final p in pieces) {
      if (!p.isKeeper && p.cell == cell) return p;
    }
    return null;
  }

  bool isEmpty(BoardCell cell) => cell.inBounds && outfieldAt(cell) == null;

  /// The piece currently carrying the ball (the possessing outfielder or keeper on the
  /// ball cell).
  BoardPiece? get carrier {
    final p = pieceAt(ballCell);
    return (p != null && p.side == possession) ? p : null;
  }

  /// Replace one piece (by id) with a moved copy.
  BoardState withPieceAt(
    String id,
    BoardCell cell, {
    int? tackleCooldownTurns,
    int? slideCooldownTurns,
  }) => copyWith(
    pieces: [
      for (final p in pieces)
        if (p.id == id)
          p.copyWith(
            cell: cell,
            tackleCooldownTurns: tackleCooldownTurns,
            slideCooldownTurns: slideCooldownTurns,
          )
        else
          p,
    ],
  );
}
