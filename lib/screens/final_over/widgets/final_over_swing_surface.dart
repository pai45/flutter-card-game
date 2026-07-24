import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../games/final_over/final_over_game.dart';

/// The whole pitch is the bat.
///
/// There is no HOLD TO SWING button any more: the player taps or swipes
/// *anywhere* over the play area to hit the ball. A tap drives it straight along
/// the ground; a swipe places the shot (left = off, right = leg, matching the
/// aim taught elsewhere in the game) and an upward or fast flick lofts it. The
/// hit is timed by the release, exactly as the engine already grades.
///
/// The surface is only live during the engine's legal swing window
/// ([FinalOverGame.canSwing]); outside it the layer is inert so the HUD, the
/// bottom deck and the overlays keep their own taps.
class FinalOverSwingSurface extends StatefulWidget {
  const FinalOverSwingSurface({required this.game, super.key});

  final FinalOverGame game;

  @override
  State<FinalOverSwingSurface> createState() => _FinalOverSwingSurfaceState();
}

class _FinalOverSwingSurfaceState extends State<FinalOverSwingSurface> {
  Offset? _origin;
  Offset? _current;
  Duration? _downStamp;
  SwingGesture _preview = SwingGesture.tap;

  FinalOverGame get _game => widget.game;

  void _onDown(PointerDownEvent event) {
    // Starts the render-only backlift coil; the engine no-ops if the window has
    // already shut between the rebuild and this event.
    _game.beginSwing();
    setState(() {
      _origin = event.localPosition;
      _current = event.localPosition;
      _downStamp = event.timeStamp;
      _preview = SwingGesture.tap;
    });
  }

  void _onMove(PointerMoveEvent event) {
    final origin = _origin;
    if (origin == null) return;
    setState(() {
      _current = event.localPosition;
      _preview = classifyBattingGesture(delta: event.localPosition - origin);
    });
  }

  void _onUp(PointerUpEvent event) {
    final origin = _origin;
    if (origin == null) {
      _reset();
      return;
    }
    final delta = event.localPosition - origin;
    final gesture = classifyBattingGesture(
      delta: delta,
      velocity: _velocity(delta, event.timeStamp),
    );
    _game.releaseSwing(direction: gesture.direction, elevation: gesture.elevation);
    HapticFeedback.lightImpact();
    _reset();
  }

  void _onCancel(PointerCancelEvent event) {
    _game.cancelSwing();
    _reset();
  }

  double _velocity(Offset delta, Duration upStamp) {
    final downStamp = _downStamp;
    if (downStamp == null) return 0;
    final micros = (upStamp - downStamp).inMicroseconds;
    if (micros <= 0) return 0;
    return delta.distance / (micros / 1e6);
  }

  void _reset() {
    if (_origin == null && _current == null) return;
    setState(() {
      _origin = null;
      _current = null;
      _downStamp = null;
      _preview = SwingGesture.tap;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _game.canSwing,
      builder: (context, live, _) {
        final origin = _origin;
        final current = _current;
        return IgnorePointer(
          ignoring: !live,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onDown,
            onPointerMove: _onMove,
            onPointerUp: _onUp,
            onPointerCancel: _onCancel,
            child: CustomPaint(
              size: Size.infinite,
              painter: origin != null && current != null
                  ? _SwingAimPainter(
                      origin: origin,
                      current: current,
                      gesture: _preview,
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}

/// The shot a batting gesture resolves to. [direction] feeds `SwingCommand`;
/// [elevation] feeds it too (tap = grounded straight, swipe places + lofts).
@immutable
class SwingGesture {
  const SwingGesture(this.direction, this.elevation, {required this.isSwipe});

  final ShotDirection direction;
  final Elevation elevation;
  final bool isSwipe;

  /// The neutral resolution for a plain tap: a safe grounded drive.
  static const tap = SwingGesture(
    ShotDirection.straight,
    Elevation.ground,
    isSwipe: false,
  );

  @override
  bool operator ==(Object other) =>
      other is SwingGesture &&
      other.direction == direction &&
      other.elevation == elevation &&
      other.isSwipe == isSwipe;

  @override
  int get hashCode => Object.hash(direction, elevation, isSwipe);
}

/// Classify a batting gesture from its start→end displacement (and optional
/// release speed). Short travel is a tap → grounded straight drive. A longer
/// drag places the shot from its horizontal component — using the same
/// `dx < -.34·dist → off`, `dx > .34·dist → leg` split the retired aim-fan
/// taught — and lofts it when the swipe travels upward or is flicked fast.
SwingGesture classifyBattingGesture({
  required Offset delta,
  double velocity = 0,
}) {
  const tapSlop = 24.0;
  const loftRise = 26.0; // upward travel (px) that turns a drive into a loft
  const loftSpeed = 900.0; // flick speed (px/s) that lofts regardless of angle

  final distance = delta.distance;
  if (distance < tapSlop) return SwingGesture.tap;

  final direction = delta.dx < -distance * .34
      ? ShotDirection.offSide
      : delta.dx > distance * .34
      ? ShotDirection.legSide
      : ShotDirection.straight;
  final lofted = delta.dy < -loftRise || velocity >= loftSpeed;
  return SwingGesture(
    direction,
    lofted ? Elevation.loft : Elevation.ground,
    isSwipe: true,
  );
}

/// Draws the live aim feedback anchored at the finger: an origin pip, an arrow
/// toward the current point once the gesture qualifies as a swipe, and a
/// direction/elevation read-out. Loft tints violet to echo the LOFT accent.
class _SwingAimPainter extends CustomPainter {
  const _SwingAimPainter({
    required this.origin,
    required this.current,
    required this.gesture,
  });

  final Offset origin;
  final Offset current;
  final SwingGesture gesture;

  @override
  void paint(Canvas canvas, Size size) {
    final accent = gesture.elevation == Elevation.loft
        ? Cyber.violet
        : Cyber.cyan;

    // Origin pip — where the swing was anchored.
    canvas.drawCircle(origin, 4, Paint()..color = Cyber.gold);
    canvas.drawCircle(
      origin,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.gold.withValues(alpha: .45),
    );

    if (gesture.isSwipe) {
      canvas.drawLine(
        origin,
        current,
        Paint()
          ..color = accent.withValues(alpha: .92)
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      _drawArrowHead(canvas, origin, current, accent);
      _drawLabel(canvas, size, accent);
    }
  }

  void _drawArrowHead(Canvas canvas, Offset from, Offset to, Color color) {
    final delta = to - from;
    final length = delta.distance;
    if (length < 1) return;
    final unit = delta / length;
    final perpendicular = Offset(-unit.dy, unit.dx);
    final base = to - unit * 12;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo((base + perpendicular * 6).dx, (base + perpendicular * 6).dy)
      ..moveTo(to.dx, to.dy)
      ..lineTo((base - perpendicular * 6).dx, (base - perpendicular * 6).dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawLabel(Canvas canvas, Size size, Color accent) {
    final text =
        '${_directionLabel(gesture.direction)} · '
        '${gesture.elevation == Elevation.loft ? 'LOFT' : 'GROUND'}';
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: Cyber.label(9, color: accent, letterSpacing: 1.4),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Sit the read-out just above the finger, clamped on-screen.
    var dx = current.dx - painter.width / 2;
    dx = dx.clamp(8.0, size.width - painter.width - 8);
    var dy = current.dy - 30;
    if (dy < 8) dy = current.dy + 18;

    final bgRect = Rect.fromLTWH(
      dx - 8,
      dy - 4,
      painter.width + 16,
      painter.height + 8,
    );
    canvas.drawRect(
      bgRect,
      Paint()..color = Cyber.bg.withValues(alpha: .82),
    );
    canvas.drawRect(
      bgRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: .55),
    );
    painter.paint(canvas, Offset(dx, dy));
  }

  static String _directionLabel(ShotDirection direction) => switch (direction) {
    ShotDirection.offSide => 'OFF',
    ShotDirection.straight => 'STRAIGHT',
    ShotDirection.legSide => 'LEG',
  };

  @override
  bool shouldRepaint(covariant _SwingAimPainter oldDelegate) =>
      oldDelegate.origin != origin ||
      oldDelegate.current != current ||
      oldDelegate.gesture != gesture;
}
