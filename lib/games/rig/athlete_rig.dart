/// Shared primitives for the app's code-drawn athlete rigs.
///
/// No sprite assets anywhere: an athlete is limbs drawn as thick round-cap
/// strokes with IK-lite elbows/knees, posed parametrically from an engine's
/// body state. Hoop Duel established the language; Final Over speaks it too, so
/// the pose type and the drawing primitives live here rather than in either
/// game.
///
/// Rules of the language (keep them if you add a third rig):
///   • only three joints are ever stored — hip, shoulder, head. Elbows and
///     knees are *solved* by [rigLimb], never authored.
///   • every dimension scales by `heightM / referenceHeight`, every stroke
///     width is a fraction of `px` (pixels per world metre).
///   • two colour sources: a *livery* (primary/secondary/accent) dresses the
///     athlete, a *look* (skin/hair) is the person. Far limbs are the near
///     colour run through [rigDarken].
///   • volume is free: repeat a stroke offset along its normal in black @ 0.15.
///   • THE GLOW RULE — a rig never blurs. Lit lines (a visor, a helmet grille)
///     are flat strokes. The only blurred thing on a playfield is the one
///     "this is live" aura, and that belongs to the game, not the rig.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/text.dart';
import 'package:flutter/material.dart' show Colors;

import '../../config/theme.dart';

/// A pose in athlete-local metres: hip height, torso lean, foot targets
/// (relative to the point under the hip) and hand targets (relative to the
/// shoulder). x is forward (facing direction), y is up.
///
/// Hand offsets already use the canvas convention (negative dy = up) so they
/// add to the shoulder directly; foot offsets do not.
class RigPose {
  const RigPose({
    required this.hip,
    this.lean = 0,
    required this.footNear,
    required this.footFar,
    required this.handNear,
    required this.handFar,
    this.headBob = 0,
  });

  final double hip;
  final double lean;
  final Offset footNear;
  final Offset footFar;
  final Offset handNear;
  final Offset handFar;
  final double headBob;
}

final Map<String, TextPaint> _numberPaints = {};

/// Memoised Orbitron paint for a jersey number. Tabular so digits never jitter.
TextPaint rigNumberPaint(Color color, double fontSize) =>
    _numberPaints.putIfAbsent(
      '${color.toARGB32()}-${fontSize.toStringAsFixed(1)}',
      () => TextPaint(
        style: TextStyle(
          fontFamily: Cyber.displayFont,
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: color,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );

/// Pushes a colour toward the app's near-black background — never toward pure
/// black, which reads as a hole rather than shadow.
Color rigDarken(Color color, double amount) =>
    Color.lerp(color, const Color(0xFF05070B), amount)!;

/// Two-segment limb: the joint is solved as the midpoint pushed along the
/// segment normal. [bend] sign picks which way it buckles — negative for knees
/// (forward), positive for elbows (back).
///
/// Passing [shoe] draws a rotated sneaker/boot at the end instead of the small
/// wrist dot a hand gets. [lowerOverlay] paints a sleeve/pad over the top half
/// of the lower segment.
void rigLimb(
  Canvas canvas,
  Offset from,
  Offset to, {
  required double bend,
  required Paint upper,
  required Paint lower,
  required double px,
  Color? lowerOverlay,
  Color? shoe,
  Color? shoeAccent,
}) {
  final mid = Offset.lerp(from, to, 0.5)!;
  final dir = to - from;
  final len = dir.distance;
  final normal = len > 0.001
      ? Offset(-dir.dy / len, dir.dx / len)
      : const Offset(1, 0);
  final joint = mid + normal * bend;

  canvas.drawLine(from, joint, upper);
  canvas.drawLine(joint, to, lower);

  // Shadow pass for volume.
  final shadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.15)
    ..strokeWidth = upper.strokeWidth * 0.25
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(
    from - normal * (upper.strokeWidth * 0.2),
    joint - normal * (upper.strokeWidth * 0.2),
    shadow,
  );
  canvas.drawLine(
    joint - normal * (lower.strokeWidth * 0.2),
    to - normal * (lower.strokeWidth * 0.2),
    shadow,
  );

  // Overlay (arm sleeve / knee pad).
  if (lowerOverlay != null) {
    canvas.drawLine(
      joint,
      Offset.lerp(joint, to, 0.5)!,
      Paint()
        ..color = lowerOverlay
        ..strokeWidth = lower.strokeWidth * 1.05
        ..strokeCap = StrokeCap.round,
    );
  }

  // Hands — a small dot at the wrist end (legs pass a shoe instead).
  if (shoe == null) {
    canvas.drawCircle(to, px * 0.05, Paint()..color = lower.color);
    return;
  }

  final shoeDir = len > 0.001 ? dir / len : const Offset(0, 1);
  final shoeR = px * 0.085;
  canvas.save();
  canvas.translate(to.dx, to.dy);
  canvas.rotate(atan2(shoeDir.dy, shoeDir.dx));
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(shoeR * 0.3, 0),
      width: shoeR * 2.2,
      height: shoeR * 1.4,
    ),
    Paint()..color = shoe,
  );
  if (shoeAccent != null) {
    // Sole highlight.
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(shoeR * 0.3, shoeR * 0.3),
        width: shoeR * 2.0,
        height: shoeR * 0.8,
      ),
      0,
      pi,
      false,
      Paint()
        ..color = shoeAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = px * 0.03,
    );
  }
  canvas.restore();
}
