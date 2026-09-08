import 'dart:math';

import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Where the posts, crossbar and ground sit for a goal drawn face-on.
///
/// Extracted from the penalty shootout so the shootout scene, its emblem and the
/// football shot map all agree on one goal mouth instead of each re-deriving it.
class GoalMouthFrame {
  const GoalMouthFrame({
    required this.left,
    required this.right,
    required this.crossbarY,
    required this.groundY,
  });

  /// A mouth for an inline diagram.
  ///
  /// The margins are not decorative: attempts that missed are placed *outside*
  /// the frame, so the goal is sized to leave room for them. A miss at x 1.12
  /// or y -0.14 still lands inside the canvas at these proportions.
  factory GoalMouthFrame.diagram(Size size) => GoalMouthFrame(
    left: size.width * 0.13,
    right: size.width * 0.87,
    crossbarY: size.height * 0.22,
    groundY: size.height * 0.92,
  );

  final double left;
  final double right;
  final double crossbarY;
  final double groundY;

  double get width => right - left;
  double get mouthH => groundY - crossbarY;

  /// A point in mouth space: [x] 0 at the left post and 1 at the right, [y] 0 at
  /// the crossbar and 1 at the ground. Values outside 0..1 fall outside the
  /// frame, which is how attempts that missed are placed.
  Offset at(double x, double y) =>
      Offset(left + width * x, crossbarY + mouthH * y);
}

/// Posts, crossbar and net grid. On a goal the net bulges outward around
/// [rippleCenter] while [rippleT] runs 0→1.
///
/// Defaults reproduce the penalty shootout's frame exactly; the inline diagram
/// overrides the mesh density and stroke weights for its smaller size.
void paintGoalMouth(
  Canvas canvas,
  GoalMouthFrame g, {
  int cols = 9,
  int rows = 5,
  double meshAlpha = 0.20,
  double meshStroke = 1,
  double frameStroke = 4,
  double rippleT = 0,
  Offset? rippleCenter,
  double rippleAmplitude = 11,
  double rippleFalloff = 42,
  bool impactRing = true,
  bool groundLine = true,
  double groundWidth = double.infinity,
  Offset? spot,
}) {
  final netPaint = Paint()
    ..color = Cyber.cyan.withValues(alpha: meshAlpha)
    ..strokeWidth = meshStroke
    ..style = PaintingStyle.stroke;

  Offset displace(Offset p) {
    final c = rippleCenter;
    if (c == null || rippleT <= 0 || rippleT >= 1) return p;
    final d = (p - c).distance;
    if (d < 1) return p;
    final amp =
        rippleAmplitude *
        sin(rippleT * pi) *
        exp(-(d * d) / (2 * rippleFalloff * rippleFalloff));
    return p + (p - c) / d * amp;
  }

  Path netLine(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  List<Offset> sample(Offset a, Offset b) => [
    for (var i = 0; i <= 10; i++) displace(Offset.lerp(a, b, i / 10)!),
  ];

  for (var i = 1; i < cols; i++) {
    final x = g.left + g.width * i / cols;
    canvas.drawPath(
      netLine(sample(Offset(x, g.crossbarY), Offset(x, g.groundY))),
      netPaint,
    );
  }
  for (var i = 1; i < rows; i++) {
    final y = g.crossbarY + g.mouthH * i / rows;
    canvas.drawPath(
      netLine(sample(Offset(g.left, y), Offset(g.right, y))),
      netPaint,
    );
  }

  final c = rippleCenter;
  if (impactRing && c != null && rippleT > 0 && rippleT < 1) {
    canvas.drawCircle(
      c,
      8 + 34 * rippleT,
      Paint()
        ..color = Cyber.lime.withValues(alpha: 0.5 * (1 - rippleT))
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  final framePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.92)
    ..strokeWidth = frameStroke
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(
    Offset(g.left, g.groundY),
    Offset(g.left, g.crossbarY),
    framePaint,
  );
  canvas.drawLine(
    Offset(g.right, g.groundY),
    Offset(g.right, g.crossbarY),
    framePaint,
  );
  canvas.drawLine(
    Offset(g.left, g.crossbarY),
    Offset(g.right, g.crossbarY),
    framePaint,
  );

  if (groundLine) {
    canvas.drawLine(
      Offset(0, g.groundY),
      Offset(
        groundWidth.isFinite ? groundWidth : g.left * 2 + g.width,
        g.groundY,
      ),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.35)
        ..strokeWidth = 1.5,
    );
  }

  if (spot != null) {
    canvas.drawCircle(
      spot,
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }
}

/// The match ball, shared by the shootout scene and the shot-map net diagram.
void paintGoalBall(
  Canvas canvas,
  Offset pos,
  double scale, {
  double alpha = 1,
}) {
  final r = 8.0 * scale;
  canvas.drawCircle(
    pos,
    r,
    Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha),
  );
  final seam = Paint()
    ..color = Cyber.bg2.withValues(alpha: 0.85 * alpha)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;
  canvas.drawCircle(pos, r * 0.45, seam);
  canvas.drawArc(
    Rect.fromCircle(center: pos, radius: r * 0.85),
    0.6,
    1.6,
    false,
    seam,
  );
}
