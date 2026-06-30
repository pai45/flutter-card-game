import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame/text.dart';
import 'package:flutter/material.dart'
    show Colors, Curves, FontWeight, TextStyle, Icons;

import '../../blocs/football_chess/football_chess_state.dart';
import '../../config/theme.dart';
import '../../models/cards.dart';
import '../../models/football_chess.dart';
import 'football_chess_board.dart';

/// Flame renderer for grid Football Chess: a 3×4 board with piece tokens, the
/// ball, selection highlights and a tap layer. Match *logic* lives in the cubit;
/// this class draws the state it's fed via [syncMatch], animates piece movement,
/// and forwards board taps via [onCellTapped] (null = tap off the board).
class FootballChessGame extends FlameGame {
  FootballChessGame({required this.match, this.onCellTapped});

  ChessMatch match;
  final void Function(BoardCell? cell)? onCellTapped;

  late final GridComponent _grid;
  final Map<String, PlayerTokenComponent> _tokens = {};
  late final BallComponent _ball;
  final Random _rng = Random();

  @override
  Color backgroundColor() => Cyber.bg;

  @override
  Future<void> onLoad() async {
    _grid = GridComponent();
    add(_grid);

    for (final p in match.board.pieces) {
      final token = PlayerTokenComponent(
        card: p.card,
        teamColor: p.side == Side.player ? Cyber.cyan : Cyber.magenta,
        isKeeper: p.isKeeper,
      );
      _tokens[p.id] = token;
      add(token);
    }

    _ball = BallComponent();
    add(_ball);

    add(_BoardTapLayer(onTap: _handleTap)..priority = 100);

    _layout();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (isLoaded) _layout();
  }

  void syncMatch(ChessMatch m, {bool animate = true}) {
    match = m;
    if (isLoaded) _layout(animate: animate);
  }

  void _handleTap(Vector2 pos) {
    final f = _field;
    final cw = f.width / kBoardCols;
    final ch = f.height / kBoardRows;

    // Allow taps up to 1 row above and below the field for keepers.
    final extendedF = Rect.fromLTRB(f.left, f.top - ch, f.right, f.bottom + ch);

    if (!extendedF.contains(Offset(pos.x, pos.y))) {
      onCellTapped?.call(null);
      return;
    }

    final col = ((pos.x - f.left) / cw).floor().clamp(0, kBoardCols - 1);
    final rowFromTop = ((pos.y - f.top) / ch).floor();
    final row = kBoardRows - 1 - rowFromTop;

    // Keeper cells are at col=1, row=-1 (bottom) and row=4 (top)
    if (row == -1 && col == 1) {
      onCellTapped?.call(const BoardCell(1, -1));
    } else if (row == kBoardRows && col == 1) {
      onCellTapped?.call(BoardCell(1, kBoardRows));
    } else if (row >= 0 && row < kBoardRows) {
      onCellTapped?.call(BoardCell(col, row));
    } else {
      onCellTapped?.call(null);
    }
  }

  // ---- Layout ----

  static const double _marginX = 14;
  static const double _marginTop = 96;
  static const double _marginBottom = 110;

  Rect get _field {
    final maxW = size.x - _marginX * 2;
    final maxH = (size.y - _marginTop - _marginBottom).clamp(
      160.0,
      double.infinity,
    );

    // We have 4 rows in the pitch, plus 1 keeper row above and 1 keeper row below.
    // So the total grid height is effectively 6 rows.
    final ch = maxH / 6;

    final fw = maxW;
    final fh = ch * 4;

    final left = _marginX;
    // The top of the 4-row pitch starts after 1 keeper row.
    final top = _marginTop + ch;

    return Rect.fromLTWH(left, top, fw, fh);
  }

  Vector2 _cellCenter(Rect f, int col, int row) {
    final cw = f.width / kBoardCols;
    final ch = f.height / kBoardRows;
    return Vector2(f.left + (col + 0.5) * cw, f.bottom - (row + 0.5) * ch);
  }

  void _layout({bool animate = false}) {
    final f = _field;
    final cw = f.width / kBoardCols;
    final ch = f.height / kBoardRows;
    final r = (min(cw, ch) * 0.32).clamp(12.0, 30.0);

    for (final p in match.board.pieces) {
      final token = _tokens[p.id]!;
      token.size = Vector2.all(r * 2);
      token.active = p.id == match.selectedPieceId;
      token.yellow = p.yellow;
      token.benched = p.benched;
      final target = _cellCenter(f, p.cell.col, p.cell.row);
      _place(token, target, animate);
    }

    _ball.radius = (r * 0.32).clamp(5.0, 11.0);
    if (match.phase == ChessMatchPhase.toss && match.tossResult == null) {
      _place(_ball, Vector2(f.center.dx, f.center.dy), animate);
    } else {
      final ballCell = match.board.ballCell;
      final bx = ballCell.col;
      final by = ballCell.row;
      final Vector2 center = _cellCenter(f, bx, by);
      _place(_ball, center, animate);
    }

    // Highlights.
    final passCells = [
      for (final id in match.passTargetIds)
        if (match.board.pieceById(id) case final p?) p.cell,
    ];
    final carrier = match.board.carrier;
    // Danger-ring the carrier when a selected defender can tackle/slide it.
    final canDuel =
        match.selectedPieceId != null &&
        (match.availableActions.contains(BoardActionType.tackle) ||
            match.availableActions.contains(BoardActionType.slide));
    final lm = match.lastMove;
    _grid.configure(
      field: f,
      selectedCell: match.selectedPiece?.cell,
      moveCells: match.moveCells,
      isDribbleArmed: match.selectedAction == BoardActionType.dribble,
      passCells: passCells,
      dangerCell: canDuel ? carrier?.cell : null,
      lastFrom: lm?.from,
      lastTo: lm?.to,
      lastMoveSide: lm?.side,
      lastVerb: lm?.verb,
      lastEvent: match.lastEvent,
      turnColor: match.turnSide == Side.player ? Cyber.cyan : Cyber.magenta,
    );
  }

  void _place(PositionComponent c, Vector2 target, bool animate) {
    for (final e in c.children.whereType<MoveEffect>().toList()) {
      e.removeFromParent();
    }
    if (animate && isMounted) {
      c.add(
        MoveEffect.to(
          target,
          EffectController(duration: 0.34, curve: Curves.easeOutCubic),
        ),
      );
    } else {
      c.position = target;
    }
  }

  // ---- Goal celebration ----

  void playGoal(Side scorer) {
    final f = _field;
    final at = Vector2(f.center.dx, scorer == Side.player ? f.top : f.bottom);
    add(_GoalFlashComponent(Cyber.gold)..size = size.clone());
    add(_goalBurst(at));
  }

  ParticleSystemComponent _goalBurst(Vector2 at) => ParticleSystemComponent(
    position: at,
    particle: Particle.generate(
      count: 28,
      lifespan: 0.9,
      generator: (_) {
        final angle = _rng.nextDouble() * pi * 2;
        final speed = 70 + _rng.nextDouble() * 210;
        return AcceleratedParticle(
          speed: Vector2(cos(angle), sin(angle)) * speed,
          acceleration: Vector2(0, 140),
          child: CircleParticle(
            radius: 2 + _rng.nextDouble() * 2.5,
            paint: Paint()..color = Cyber.gold,
          ),
        );
      },
    ),
  );
}

/// Draws the board: cells, halfway line, goals, and the selection highlights.
class GridComponent extends PositionComponent {
  Rect field = Rect.zero;
  BoardCell? selectedCell;
  List<BoardCell> moveCells = const [];
  bool isDribbleArmed = false;
  List<BoardCell> passCells = const [];
  BoardCell? dangerCell;
  BoardCell? lastFrom;
  BoardCell? lastTo;
  Side? lastMoveSide;
  BoardActionType? lastVerb;
  BoardEvent? lastEvent;
  Color turnColor = Cyber.cyan;

  void configure({
    required Rect field,
    required BoardCell? selectedCell,
    required List<BoardCell> moveCells,
    required bool isDribbleArmed,
    required List<BoardCell> passCells,
    required BoardCell? dangerCell,
    required BoardCell? lastFrom,
    required BoardCell? lastTo,
    required Side? lastMoveSide,
    required BoardActionType? lastVerb,
    required BoardEvent? lastEvent,
    required Color turnColor,
  }) {
    this.field = field;
    this.selectedCell = selectedCell;
    this.moveCells = moveCells;
    this.isDribbleArmed = isDribbleArmed;
    this.passCells = passCells;
    this.dangerCell = dangerCell;
    this.lastFrom = lastFrom;
    this.lastTo = lastTo;
    this.lastMoveSide = lastMoveSide;
    this.lastVerb = lastVerb;
    this.lastEvent = lastEvent;
    this.turnColor = turnColor;
  }

  double get _cw => field.width / kBoardCols;
  double get _ch => field.height / kBoardRows;

  Offset _center(int col, int row) =>
      Offset(field.left + (col + 0.5) * _cw, field.bottom - (row + 0.5) * _ch);

  @override
  void render(Canvas canvas) {
    if (field.isEmpty) return;

    // 1. Pitch Gradient Background (from top keeper to bottom keeper)
    final pitchRect = Rect.fromLTWH(
      field.left, 
      field.top - _ch, 
      field.width, 
      field.height + _ch * 2,
    );
    final bgPaint = Paint()
      ..shader = Gradient.linear(
        pitchRect.topCenter,
        pitchRect.bottomCenter,
        [const Color(0xff073222), const Color(0xff061b22), const Color(0xff08111d)],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(pitchRect, bgPaint);

    // Cells.
    final cellBorder = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Cyber.cyan.withValues(alpha: 0.10);
    for (var col = 0; col < kBoardCols; col++) {
      for (var row = 0; row < kBoardRows; row++) {
        final rect = Rect.fromLTWH(
          field.left + col * _cw,
          field.bottom - (row + 1) * _ch,
          _cw,
          _ch,
        );
        canvas.drawRect(rect.deflate(1.5), cellBorder);
      }
    }

    // Keeper cells (col = 1, row = -1 and row = 4)
    canvas.drawRect(
      Rect.fromLTWH(field.left + 1 * _cw, field.bottom, _cw, _ch).deflate(1.5),
      cellBorder,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        field.left + 1 * _cw,
        field.top - _ch,
        _cw,
        _ch,
      ).deflate(1.5),
      cellBorder,
    );

    // Boundary + halfway.
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = Cyber.cyan.withValues(alpha: 0.22);
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(6)),
      line,
    );
    final midY = field.center.dy;
    canvas.drawLine(Offset(field.left, midY), Offset(field.right, midY), line);
    canvas.drawCircle(field.center, _cw * 0.42, line);

    // Goals: opponent net at the top (magenta), player net at the bottom (cyan).
    final goalW = _cw * 0.9;
    final goalH = field.height * 0.016;
    final goalLeft = field.center.dx - goalW / 2;
    canvas.drawRect(
      Rect.fromLTWH(goalLeft, field.top - goalH, goalW, goalH),
      Paint()..color = Cyber.magenta.withValues(alpha: 0.55),
    );
    canvas.drawRect(
      Rect.fromLTWH(goalLeft, field.bottom, goalW, goalH),
      Paint()..color = Cyber.cyan.withValues(alpha: 0.55),
    );

    final r = min(_cw, _ch) * 0.32;

    // Last move — chess.com-style tint on the from/to cells (under the pieces).
    final fill = Paint()..color = Cyber.gold.withValues(alpha: 0.16);
    for (final c in [lastFrom, lastTo]) {
      if (c == null) continue;
      canvas.drawRect(
        Rect.fromLTWH(
          field.left + c.col * _cw,
          field.bottom - (c.row + 1) * _ch,
          _cw,
          _ch,
        ).deflate(1.5),
        fill,
      );
    }

    // Arrow between last move cells
    if (lastFrom != null && lastTo != null && (lastFrom != lastTo)) {
      final start = _center(lastFrom!.col, lastFrom!.row);
      final end = _center(lastTo!.col, lastTo!.row);

      bool isTackle =
          lastVerb == BoardActionType.tackle ||
          lastVerb == BoardActionType.slide;
      bool isSuccessfulTackle = isTackle && lastEvent == BoardEvent.turnover;

      Color arrowColor = lastMoveSide == Side.player
          ? Cyber.cyan
          : Cyber.magenta;
      if (isTackle) {
        arrowColor = isSuccessfulTackle ? Colors.green : Colors.red;
      }

      final arrowPaint = Paint()
        ..color = arrowColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      // Draw line
      canvas.drawLine(start, end, arrowPaint);

      // Draw arrowhead at end
      final dx = end.dx - start.dx;
      final dy = end.dy - start.dy;
      final angle = atan2(dy, dx);
      final arrowSize = 12.0;

      final p1 = Offset(
        end.dx - arrowSize * cos(angle - pi / 6),
        end.dy - arrowSize * sin(angle - pi / 6),
      );
      final p2 = Offset(
        end.dx - arrowSize * cos(angle + pi / 6),
        end.dy - arrowSize * sin(angle + pi / 6),
      );

      final headPaint = Paint()
        ..color = arrowColor.withValues(alpha: 0.6)
        ..style = PaintingStyle.fill;

      final path = Path()
        ..moveTo(end.dx, end.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..close();

      canvas.drawPath(path, headPaint);

      // Draw arrowhead at start for tackle (both sides pointing)
      if (isTackle) {
        final startAngle = atan2(-dy, -dx);
        final sp1 = Offset(
          start.dx - arrowSize * cos(startAngle - pi / 6),
          start.dy - arrowSize * sin(startAngle - pi / 6),
        );
        final sp2 = Offset(
          start.dx - arrowSize * cos(startAngle + pi / 6),
          start.dy - arrowSize * sin(startAngle + pi / 6),
        );

        final startPath = Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(sp1.dx, sp1.dy)
          ..lineTo(sp2.dx, sp2.dy)
          ..close();

        canvas.drawPath(startPath, headPaint);
      }

      // Draw icon in the middle if tackle or dribble
      if (isTackle || lastVerb == BoardActionType.dribble) {
        final mid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);

        // Draw a small background circle for the icon
        canvas.drawCircle(
          mid,
          12,
          Paint()..color = Cyber.bg.withValues(alpha: 0.8),
        );

        final iconData = (lastVerb == BoardActionType.dribble)
            ? Icons.directions_run_sharp
            : Icons.shield_sharp;

        final textPaint = TextPaint(
          style: TextStyle(
            fontFamily: iconData.fontFamily,
            fontSize: 16,
            color: arrowColor,
            package: iconData.fontPackage,
          ),
        );

        textPaint.render(
          canvas,
          String.fromCharCode(iconData.codePoint),
          Vector2(mid.dx, mid.dy),
          anchor: Anchor.center,
        );
      }
    }

    // Selected cell — a soft accent plate behind the piece.
    if (selectedCell case final c?) {
      canvas.drawCircle(
        _center(c.col, c.row),
        r * 1.25,
        Paint()..color = turnColor.withValues(alpha: 0.20),
      );
    }
    // Move destinations — dots; DRIBBLE targets (opponents) — danger rings.
    for (final c in moveCells) {
      if (isDribbleArmed) {
        canvas.drawCircle(
          _center(c.col, c.row),
          r * 1.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Cyber.danger,
        );
      } else {
        canvas.drawCircle(
          _center(c.col, c.row),
          r * 0.34,
          Paint()..color = Cyber.cyan.withValues(alpha: 0.7),
        );
      }
    }
    // Pass targets — cyan ring around the teammate.
    for (final c in passCells) {
      canvas.drawCircle(
        _center(c.col, c.row),
        r * 1.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Cyber.cyan.withValues(alpha: 0.85),
      );
    }
    // Tackle/slide target (opponent carrier) — danger ring.
    if (dangerCell case final c?) {
      canvas.drawCircle(
        _center(c.col, c.row),
        r * 1.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Cyber.danger,
      );
    }
  }
}

/// Full-area tap catcher; converts a tap to a board position for the game.
class _BoardTapLayer extends PositionComponent
    with TapCallbacks, HasGameReference<FootballChessGame> {
  _BoardTapLayer({required this.onTap});

  final void Function(Vector2 pos) onTap;

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    this.size = size;
  }

  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapDown(TapDownEvent event) => onTap(event.localPosition);
}

/// A small player chip: dark fill, team-coloured ring, rating + a short-name
/// plate. Glows while selected.
class PlayerTokenComponent extends PositionComponent {
  PlayerTokenComponent({
    required this.card,
    required this.teamColor,
    required this.isKeeper,
  }) {
    anchor = Anchor.center;
  }

  final PlayerCard card;
  final Color teamColor;
  final bool isKeeper;
  bool active = false;
  bool yellow = false;
  bool benched = false;

  @override
  void render(Canvas canvas) {
    final r = size.x / 2;
    final center = Offset(r, r);
    // A benched (sent-off) player is greyed and dimmed.
    final ring = benched ? Cyber.muted : teamColor;

    if (active && !benched) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = teamColor.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    canvas.drawCircle(
      center,
      r * 0.86,
      Paint()..color = Cyber.panel.withValues(alpha: benched ? 0.55 : 1),
    );
    canvas.drawCircle(
      center,
      r * 0.86,
      Paint()
        ..color = ring.withValues(alpha: active ? 1 : 0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = active ? 3 : 2,
    );

    // Booking chip (corner): yellow, or red while benched.
    if (yellow || benched) {
      canvas.drawRect(
        Rect.fromLTWH(r * 1.35, r * 0.2, r * 0.34, r * 0.5),
        Paint()..color = benched ? Cyber.danger : Cyber.gold,
      );
    }

    TextPaint(
      style: TextStyle(
        fontFamily: Cyber.displayFont,
        fontSize: r * 0.74,
        fontWeight: FontWeight.w700,
        color: teamColor,
      ),
    ).render(
      canvas,
      '${card.rating}',
      Vector2(center.dx, center.dy),
      anchor: Anchor.center,
    );

    TextPaint(
      style: TextStyle(
        fontFamily: Cyber.displayFont,
        fontSize: (r * 0.34).clamp(7.0, 11.0),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Colors.white.withValues(alpha: 0.82),
      ),
    ).render(
      canvas,
      _shortLabel,
      Vector2(r, r * 2 + 2),
      anchor: Anchor.topCenter,
    );
  }

  String get _shortLabel {
    final n = card.shortName;
    return n.length > 9 ? n.substring(0, 9) : n;
  }
}

/// The ball — a small glowing dot.
class BallComponent extends PositionComponent {
  BallComponent() {
    anchor = Anchor.center;
  }

  double radius = 8;

  @override
  void render(Canvas canvas) {
    canvas.drawCircle(
      Offset.zero,
      radius * 2.1,
      Paint()
        ..color = Cyber.gold.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(Offset.zero, radius, Paint()..color = Colors.white);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = Cyber.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

/// A full-field colour wash that flashes on a goal, then fades + removes itself.
class _GoalFlashComponent extends PositionComponent {
  _GoalFlashComponent(this.color);

  final Color color;
  double _opacity = 0.5;

  @override
  void update(double dt) {
    _opacity -= dt * 1.7;
    if (_opacity <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Offset.zero & Size(size.x, size.y),
      Paint()..color = color.withValues(alpha: _opacity.clamp(0.0, 1.0)),
    );
  }
}
