import 'dart:math';

import 'package:flutter/material.dart';

import '../../../config/theme.dart';

/// Penalty Shootout brand emblem — an esports-HUD targeting loop that replaces
/// Pitch Duel's spinning ball. A reticle sweeps to an upper goal corner and
/// locks, the ball fires into it on a curved strike, the net flashes on impact,
/// then it resets — alternating the left and right corner each cycle.
class ShootoutEmblem extends StatefulWidget {
  const ShootoutEmblem({this.size = 92, super.key});

  final double size;

  @override
  State<ShootoutEmblem> createState() => _ShootoutEmblemState();
}

class _ShootoutEmblemState extends State<ShootoutEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    // One loop = two strikes (left corner, then right corner).
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _ShootoutEmblemPainter(_c.value)),
      ),
    );
  }
}

class _ShootoutEmblemPainter extends CustomPainter {
  _ShootoutEmblemPainter(this.t);

  /// Whole-loop progress 0..1 (covers two strikes).
  final double t;

  static double _seg(double v, double a, double b, [Curve c = Curves.linear]) {
    if (v <= a) return 0;
    if (v >= b) return 1;
    return c.transform((v - a) / (b - a));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final aimRight = t >= 0.5; // first half left corner, second half right
    final lt = (t % 0.5) / 0.5; // local strike progress 0..1

    // Sub-phases within a single strike.
    final aim = _seg(lt, 0.0, 0.30, Curves.easeOutCubic);
    final flight = _seg(lt, 0.32, 0.56, Curves.easeIn);
    final impact = _seg(lt, 0.56, 0.74);
    final reset = _seg(lt, 0.80, 1.0, Curves.easeIn);
    final locked = lt >= 0.30 && lt < 0.80;

    // ── Goal-mouth geometry ──
    final left = s * 0.18;
    final right = s * 0.82;
    final crossbarY = s * 0.30;
    final groundY = s * 0.64;
    final mouthW = right - left;
    final mouthH = groundY - crossbarY;
    final spot = Offset(s * 0.5, s * 0.86);
    final target = Offset(
      aimRight ? right - mouthW * 0.16 : left + mouthW * 0.16,
      crossbarY + mouthH * 0.26,
    );

    _paintRing(canvas, size, s);
    _paintNet(canvas, left, right, crossbarY, groundY, impact, target);
    _paintFrame(canvas, left, right, crossbarY, groundY);

    // ── Reticle: rest at centre, sweeps to the corner, locks, returns. ──
    final centre = Offset(s * 0.5, crossbarY + mouthH * 0.45);
    final retPos = Offset.lerp(centre, target, aim - reset * aim)!;
    _paintReticle(canvas, retPos, s * 0.11, locked, impact);

    // ── Ball: waits on the spot, fires along an arc, fades after impact. ──
    if (lt < 0.56) {
      final control = Offset(
        (spot.dx + target.dx) / 2,
        crossbarY + mouthH * 0.1,
      );
      final pos = _bezier(spot, control, target, flight);
      // Motion-trail ghosts.
      if (flight > 0) {
        for (final (lag, a) in [(0.18, 0.10), (0.09, 0.22)]) {
          final u = (flight - lag).clamp(0.0, 1.0);
          if (u > 0) _paintBall(canvas, _bezier(spot, control, target, u), s, a);
        }
      }
      _paintBall(canvas, pos, s, 1);
    } else {
      // Ball nestled in the corner, fading as it resets.
      _paintBall(canvas, target, s, (1 - reset).clamp(0.0, 1.0));
    }

    // ── Impact flash ring at the corner. ──
    if (impact > 0 && impact < 1) {
      canvas.drawCircle(
        target,
        s * (0.04 + 0.12 * impact),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = Cyber.lime.withValues(alpha: 0.85 * (1 - impact)),
      );
    }
  }

  // Outer HUD ring + drifting tick, matching the home emblem language.
  void _paintRing(Canvas canvas, Size size, double s) {
    final c = size.center(Offset.zero);
    canvas.drawCircle(
      c,
      s * 0.46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.lime.withValues(alpha: 0.22),
    );
    // A short bright arc sweeping the ring as a "scanning" tick.
    final sweep = t * 2 * pi;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: s * 0.46),
      sweep,
      0.6,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = Cyber.lime.withValues(alpha: 0.6),
    );
  }

  void _paintNet(
    Canvas canvas,
    double left,
    double right,
    double top,
    double bottom,
    double impact,
    Offset rippleCentre,
  ) {
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.16)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    Offset displace(Offset p) {
      if (impact <= 0 || impact >= 1) return p;
      final d = (p - rippleCentre).distance;
      final amp = 4 * sin(impact * pi) * exp(-(d * d) / (2 * 16 * 16));
      if (d < 0.5) return p;
      return p + (p - rippleCentre) / d * amp;
    }

    const cols = 6;
    const rows = 4;
    for (var i = 1; i < cols; i++) {
      final x = left + (right - left) * i / cols;
      canvas.drawLine(displace(Offset(x, top)), displace(Offset(x, bottom)), paint);
    }
    for (var i = 1; i < rows; i++) {
      final y = top + (bottom - top) * i / rows;
      canvas.drawLine(displace(Offset(left, y)), displace(Offset(right, y)), paint);
    }
  }

  void _paintFrame(
    Canvas canvas,
    double left,
    double right,
    double top,
    double bottom,
  ) {
    final frame = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(left, bottom), Offset(left, top), frame);
    canvas.drawLine(Offset(right, bottom), Offset(right, top), frame);
    canvas.drawLine(Offset(left, top), Offset(right, top), frame);
  }

  void _paintReticle(
    Canvas canvas,
    Offset c,
    double r,
    bool locked,
    double impact,
  ) {
    final color = locked ? Cyber.lime : Colors.white.withValues(alpha: 0.8);
    final paint = Paint()
      ..color = color
      ..strokeWidth = locked ? 2 : 1.4
      ..style = PaintingStyle.stroke;
    // Corner ticks.
    const k = 0.55; // fraction of r the ticks span
    final d = r * k;
    for (final sx in [-1.0, 1.0]) {
      for (final sy in [-1.0, 1.0]) {
        final corner = c + Offset(sx * r, sy * r);
        canvas.drawLine(corner, corner + Offset(-sx * d, 0), paint);
        canvas.drawLine(corner, corner + Offset(0, -sy * d), paint);
      }
    }
    canvas.drawCircle(c, r * 0.42, paint);
    if (locked) {
      // Centre dot flares on impact.
      canvas.drawCircle(
        c,
        r * (0.12 + 0.16 * sin(impact * pi)),
        Paint()..color = Cyber.lime,
      );
    }
  }

  void _paintBall(Canvas canvas, Offset pos, double s, double alpha) {
    final r = s * 0.05;
    canvas.drawCircle(
      pos,
      r,
      Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha),
    );
    canvas.drawCircle(
      pos,
      r * 0.5,
      Paint()
        ..color = Cyber.bg2.withValues(alpha: 0.8 * alpha)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  Offset _bezier(Offset p0, Offset p1, Offset p2, double u) {
    final v = 1 - u;
    return p0 * (v * v) + p1 * (2 * v * u) + p2 * (u * u);
  }

  @override
  bool shouldRepaint(covariant _ShootoutEmblemPainter old) => old.t != t;
}
