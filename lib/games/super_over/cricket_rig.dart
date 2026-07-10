/// Procedural cricket athlete rendering for Super Over.
///
/// No sprite assets: each cricketer is a code-drawn rig (limbs as thick
/// round-cap strokes, IK-lite elbows/knees) posed parametrically, in the
/// app's stylized-silhouette tradition (Basketball athletes / Grand Prix
/// cars). Team jersey colors are content colors; everything else pulls
/// from `Cyber` tokens.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart' show Colors, CustomPainter;

import '../../config/theme.dart';

// ---------------------------------------------------------------------------
// Pose
// ---------------------------------------------------------------------------

/// A pose in athlete-local units: hip height, torso lean, foot targets
/// (relative to the point under the hip) and hand targets (relative to the
/// shoulder). x is forward (facing direction), y is up.
class CricketPose {
  const CricketPose({
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

// ---------------------------------------------------------------------------
// Batsman poses
// ---------------------------------------------------------------------------

/// Computes the batsman pose from the swing parameter and current time.
///
/// [swing] ranges from ~0.55 (idle stance) to -0.95 (leg), -0.20 (V),
/// 0.85 (off) when the swing is locked.
/// [time] drives subtle idle animation.
/// [onFire] slightly intensifies the stance.
CricketPose batsmanPose({
  required double swing,
  required double time,
  required bool onFire,
}) {
  // Detect idle vs active swing.
  final isIdle = (swing - 0.55).abs() < 0.12;

  if (isIdle) {
    // Relaxed batting guard at the crease.
    final bob = sin(time * 2.2) * 0.02;
    final breathe = sin(time * 1.4) * 0.01;
    return CricketPose(
      hip: 0.90 + bob,
      lean: 0.08 + breathe,
      footNear: const Offset(0.20, 0),
      footFar: const Offset(-0.14, 0),
      handNear: const Offset(0.16, -0.38),
      handFar: const Offset(0.10, -0.42),
      headBob: bob,
    );
  }

  // Active swing — interpolate pose based on swing angle.
  if (swing < -0.5) {
    // Leg-side shot: weight shifting across, bat sweeping to leg.
    final t = ((swing + 0.95) / 0.45).clamp(0.0, 1.0);
    return CricketPose(
      hip: 0.82,
      lean: -0.28 + t * 0.1,
      footNear: Offset(0.32 - t * 0.08, 0),
      footFar: Offset(-0.22 + t * 0.06, 0),
      handNear: Offset(-0.08 - t * 0.14, -0.26),
      handFar: Offset(-0.14 - t * 0.08, -0.34),
    );
  } else if (swing < 0.3) {
    // V / straight drive: front foot forward, bat coming through straight.
    final t = ((swing + 0.20) / 0.50).clamp(0.0, 1.0);
    return CricketPose(
      hip: 0.84,
      lean: 0.22 + t * 0.06,
      footNear: Offset(0.30 + t * 0.06, 0),
      footFar: Offset(-0.18 - t * 0.04, 0),
      handNear: Offset(0.20 + t * 0.08, -0.32),
      handFar: Offset(0.12 + t * 0.06, -0.38),
    );
  } else {
    // Off-side drive: opening up body, bat driving through off.
    final t = ((swing - 0.3) / 0.55).clamp(0.0, 1.0);
    return CricketPose(
      hip: 0.84,
      lean: 0.18 + t * 0.12,
      footNear: Offset(0.28 + t * 0.10, 0),
      footFar: const Offset(-0.20, 0),
      handNear: Offset(0.28 + t * 0.16, -0.28 + t * 0.06),
      handFar: Offset(0.20 + t * 0.10, -0.36),
    );
  }
}

// ---------------------------------------------------------------------------
// Bowler poses
// ---------------------------------------------------------------------------

/// Computes the bowler pose from run-up progress and time.
///
/// [runProgress] 0→1: idle → run-up → gather → release.
/// [time] drives stride cycling.
/// [isDeliveryActive] enables dynamic run-up motion.
CricketPose bowlerPose({
  required double runProgress,
  required double time,
  required bool isDeliveryActive,
}) {
  if (!isDeliveryActive || runProgress < 0.01) {
    // Static idle at the top of the mark.
    final bob = sin(time * 2.0) * 0.015;
    return CricketPose(
      hip: 0.92 + bob,
      lean: 0.04,
      footNear: const Offset(0.14, 0),
      footFar: const Offset(-0.14, 0),
      handNear: const Offset(0.08, -0.44),
      handFar: const Offset(-0.10, -0.42),
      headBob: bob,
    );
  }

  if (runProgress < 0.60) {
    // Running in — cyclic stride.
    final phase = time * 12.0;
    final swing = sin(phase);
    final amp = 0.34;
    return CricketPose(
      hip: 0.88 + sin(phase * 2).abs() * 0.03,
      lean: 0.22,
      footNear: Offset(swing * amp, max(0.0, sin(phase)) * 0.12),
      footFar: Offset(-swing * amp, max(0.0, -sin(phase)) * 0.12),
      handNear: Offset(-swing * 0.20 + 0.06, -0.40),
      handFar: Offset(swing * 0.20 - 0.06, -0.42),
    );
  }

  if (runProgress < 0.85) {
    // Gather / load — front arm rising, bowling arm going back.
    final k = ((runProgress - 0.60) / 0.25).clamp(0.0, 1.0);
    return CricketPose(
      hip: 0.86 - k * 0.04,
      lean: 0.16 - k * 0.10,
      footNear: Offset(0.22 + k * 0.10, 0),
      footFar: Offset(-0.20 - k * 0.06, 0),
      handNear: Offset(0.12 + k * 0.16, -0.48 - k * 0.38),
      handFar: Offset(-0.14 - k * 0.08, -0.36 + k * 0.10),
    );
  }

  // Release — bowling arm overhead, front arm pulling across, front foot
  // bracing.
  final k = ((runProgress - 0.85) / 0.15).clamp(0.0, 1.0);
  return CricketPose(
    hip: 0.82 + k * 0.06,
    lean: 0.06 + k * 0.30,
    footNear: Offset(0.34 + k * 0.04, 0),
    footFar: Offset(-0.26 + k * 0.10, 0.06 * k),
    // Bowling arm: reaches peak then comes forward.
    handNear: Offset(
      0.28 + sin(k * pi) * 0.18,
      -0.86 - sin(k * pi * 0.8) * 0.28,
    ),
    // Front arm pulls across body.
    handFar: Offset(-0.22 + k * 0.30, -0.26 - k * 0.08),
  );
}

// ---------------------------------------------------------------------------
// Rig painter
// ---------------------------------------------------------------------------

class CricketRigPainter {
  CricketRigPainter._();

  /// Draws a batsman rig at [anchor] (ground-level center).
  static void drawBatsmanRig(
    Canvas canvas,
    Offset anchor,
    CricketPose pose, {
    required Color primary,
    required Color accent,
    required Color skin,
    required double scale,
    required bool onFire,
  }) {
    final px = scale;
    final scaleM = 1.0; // proportions already tuned

    Offset pt(double xM, double yM) =>
        anchor + Offset(xM * px, -yM * px);

    final hip = pt(0, pose.hip * scaleM);
    final shoulderY = pose.hip * scaleM + 0.52 * scaleM;
    final shoulder = pt(sin(pose.lean) * 0.3, shoulderY);
    final headCenter = pt(
      sin(pose.lean) * 0.42,
      shoulderY + 0.24 * scaleM + pose.headBob,
    );

    // -- Paints ---------------------------------------------------------------
    final strokeBody = Paint()
      ..color = primary
      ..strokeWidth = px * 0.17
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final strokeSkin = Paint()
      ..color = skin
      ..strokeWidth = px * 0.095
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final strokeSkinFar = Paint()
      ..color = _darken(skin, 0.25)
      ..strokeWidth = px * 0.095
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final strokeWhites = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = px * 0.15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final strokeWhitesFar = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..strokeWidth = px * 0.15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // -- 1. Ground shadow -----------------------------------------------------
    canvas.drawOval(
      Rect.fromCenter(
        center: anchor,
        width: px * 0.42,
        height: px * 0.07,
      ),
      Paint()..color = const Color(0x66000000),
    );

    // -- 2. Fire aura ---------------------------------------------------------
    if (onFire) {
      canvas.drawOval(
        Rect.fromCenter(
          center: anchor + Offset(0, -px * 0.45),
          width: px * 0.8,
          height: px * 1.1,
        ),
        Paint()
          ..color = Cyber.gold.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    // -- 3. Far leg -----------------------------------------------------------
    final footFar = pt(pose.footFar.dx * scaleM, pose.footFar.dy * scaleM);
    _limb(
      canvas,
      hip,
      footFar,
      bend: -0.22 * px,
      upper: strokeWhitesFar,
      lower: strokeSkinFar,
      shoe: _darken(accent, 0.2),
      px: px,
    );

    // -- 4. Near leg ----------------------------------------------------------
    final footNear = pt(pose.footNear.dx * scaleM, pose.footNear.dy * scaleM);
    _limb(
      canvas,
      hip,
      footNear,
      bend: -0.26 * px,
      upper: strokeWhites,
      lower: strokeSkin,
      shoe: accent,
      px: px,
    );

    // -- 5. Batting pads (far then near) --------------------------------------
    _drawPad(canvas, hip, footFar, px, alpha: 0.72);
    _drawPad(canvas, hip, footNear, px, alpha: 0.90);

    // -- 6. Far arm -----------------------------------------------------------
    final handFar = shoulder +
        Offset(pose.handFar.dx * scaleM * px, pose.handFar.dy * scaleM * px);
    _limb(
      canvas,
      shoulder,
      handFar,
      bend: 0.2 * px,
      upper: Paint()
        ..color = _darken(primary, 0.3)
        ..strokeWidth = px * 0.085
        ..strokeCap = StrokeCap.round,
      lower: strokeSkinFar,
      px: px,
    );

    // -- 7. Torso (jersey) + accent trim --------------------------------------
    canvas.drawLine(hip, shoulder, strokeBody);
    canvas.drawLine(
      Offset.lerp(hip, shoulder, 0.12)!,
      Offset.lerp(hip, shoulder, 0.38)!,
      Paint()
        ..color = accent
        ..strokeWidth = px * 0.05
        ..strokeCap = StrokeCap.round,
    );

    // Chest guard — subtle dark overlay.
    final chestCenter = Offset.lerp(hip, shoulder, 0.72)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: chestCenter, width: px * 0.12, height: px * 0.14),
        Radius.circular(px * 0.03),
      ),
      Paint()..color = Cyber.bg.withValues(alpha: 0.18),
    );

    // -- 8. Helmet ------------------------------------------------------------
    _drawHelmet(canvas, headCenter, px, scaleM,
        primary: primary, accent: accent, skin: skin);

    // -- 9. Near arm ----------------------------------------------------------
    final handNear = shoulder +
        Offset(
          pose.handNear.dx * scaleM * px,
          pose.handNear.dy * scaleM * px,
        );
    _limb(
      canvas,
      shoulder,
      handNear,
      bend: 0.24 * px,
      upper: Paint()
        ..color = primary.withValues(alpha: 0.88)
        ..strokeWidth = px * 0.085
        ..strokeCap = StrokeCap.round,
      lower: strokeSkin,
      px: px,
    );

    // -- 10. Gloves -----------------------------------------------------------
    canvas.drawCircle(handFar, px * 0.055, Paint()..color = _darken(accent, 0.15));
    canvas.drawCircle(handNear, px * 0.06, Paint()..color = accent);
  }

  /// Draws a bowler rig at [anchor] (ground-level center).
  static void drawBowlerRig(
    Canvas canvas,
    Offset anchor,
    CricketPose pose, {
    required Color primary,
    required Color accent,
    required Color skin,
    required double scale,
    required bool holdingBall,
  }) {
    final px = scale;
    const scaleM = 1.0;

    Offset pt(double xM, double yM) =>
        anchor + Offset(xM * px, -yM * px);

    final hip = pt(0, pose.hip * scaleM);
    final shoulderY = pose.hip * scaleM + 0.52 * scaleM;
    final shoulder = pt(sin(pose.lean) * 0.3, shoulderY);
    final headCenter = pt(
      sin(pose.lean) * 0.42,
      shoulderY + 0.24 * scaleM + pose.headBob,
    );

    // Paints.
    final strokeBody = Paint()
      ..color = primary
      ..strokeWidth = px * 0.17
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final strokeSkin = Paint()
      ..color = skin
      ..strokeWidth = px * 0.095
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final strokeSkinFar = Paint()
      ..color = _darken(skin, 0.25)
      ..strokeWidth = px * 0.095
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final strokeWhites = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = px * 0.15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final strokeWhitesFar = Paint()
      ..color = Colors.white.withValues(alpha: 0.72)
      ..strokeWidth = px * 0.15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Ground shadow.
    canvas.drawOval(
      Rect.fromCenter(center: anchor, width: px * 0.42, height: px * 0.07),
      Paint()..color = const Color(0x66000000),
    );

    // Far leg.
    final footFar = pt(pose.footFar.dx * scaleM, pose.footFar.dy * scaleM);
    _limb(canvas, hip, footFar,
        bend: -0.22 * px,
        upper: strokeWhitesFar,
        lower: strokeSkinFar,
        shoe: _darken(accent, 0.2),
        px: px);

    // Near leg.
    final footNear = pt(pose.footNear.dx * scaleM, pose.footNear.dy * scaleM);
    _limb(canvas, hip, footNear,
        bend: -0.26 * px,
        upper: strokeWhites,
        lower: strokeSkin,
        shoe: accent,
        px: px);

    // Far arm.
    final handFar = shoulder +
        Offset(pose.handFar.dx * scaleM * px, pose.handFar.dy * scaleM * px);
    _limb(
      canvas,
      shoulder,
      handFar,
      bend: 0.2 * px,
      upper: Paint()
        ..color = _darken(primary, 0.3)
        ..strokeWidth = px * 0.085
        ..strokeCap = StrokeCap.round,
      lower: strokeSkinFar,
      px: px,
    );

    // Torso + trim.
    canvas.drawLine(hip, shoulder, strokeBody);
    canvas.drawLine(
      Offset.lerp(hip, shoulder, 0.12)!,
      Offset.lerp(hip, shoulder, 0.38)!,
      Paint()
        ..color = accent
        ..strokeWidth = px * 0.05
        ..strokeCap = StrokeCap.round,
    );

    // Helmet.
    _drawHelmet(canvas, headCenter, px, scaleM,
        primary: primary, accent: accent, skin: skin);

    // Near arm.
    final handNear = shoulder +
        Offset(
          pose.handNear.dx * scaleM * px,
          pose.handNear.dy * scaleM * px,
        );
    _limb(
      canvas,
      shoulder,
      handNear,
      bend: 0.24 * px,
      upper: Paint()
        ..color = primary.withValues(alpha: 0.88)
        ..strokeWidth = px * 0.085
        ..strokeCap = StrokeCap.round,
      lower: strokeSkin,
      px: px,
    );

    // Hands.
    canvas.drawCircle(
        handFar, px * 0.055, Paint()..color = _darken(skin, 0.15));
    canvas.drawCircle(handNear, px * 0.06, Paint()..color = skin);

    // Ball in bowling hand.
    if (holdingBall) {
      canvas.drawCircle(
        handNear + Offset(px * 0.02, -px * 0.02),
        px * 0.045,
        Paint()..color = Cyber.danger,
      );
    }
  }

  // -- Shared helpers ---------------------------------------------------------

  static void _drawHelmet(
    Canvas canvas,
    Offset headCenter,
    double px,
    double scaleM, {
    required Color primary,
    required Color accent,
    required Color skin,
  }) {
    final headR = 0.155 * scaleM * px;

    // Face.
    canvas.drawCircle(headCenter, headR, Paint()..color = skin);

    // Helmet dome (like basketball hair arc but thicker).
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headR * 1.08),
      pi * 0.90,
      pi * 1.20,
      false,
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.72,
    );

    // Visor grille.
    final visor = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: headCenter + Offset(headR * 0.1, headR * 0.18),
        width: headR * 1.7,
        height: headR * 0.52,
      ),
      Radius.circular(headR * 0.18),
    );
    canvas.drawRRect(
        visor, Paint()..color = Cyber.bg.withValues(alpha: 0.78));
    // Grille lines.
    for (var i = 0; i < 4; i++) {
      final x = visor.left + headR * 0.28 + i * headR * 0.34;
      canvas.drawLine(
        Offset(x, visor.top + headR * 0.04),
        Offset(x + headR * 0.06, visor.bottom - headR * 0.04),
        Paint()
          ..color = accent.withValues(alpha: 0.52)
          ..strokeWidth = headR * 0.06,
      );
    }
  }

  /// Draws a small white batting pad on the shin area of a leg.
  static void _drawPad(
    Canvas canvas,
    Offset hip,
    Offset foot,
    double px, {
    required double alpha,
  }) {
    // Pad sits on the lower-middle of the leg (knee → foot zone).
    final padCenter = Offset.lerp(hip, foot, 0.62)!;
    final padRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: padCenter,
        width: px * 0.10,
        height: px * 0.22,
      ),
      Radius.circular(px * 0.03),
    );
    canvas.drawRRect(
      padRect,
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    canvas.drawRRect(
      padRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = px * 0.012
        ..color = Cyber.cyan.withValues(alpha: 0.40),
    );
    // Horizontal lines on pad.
    for (var i = -1; i <= 1; i++) {
      canvas.drawLine(
        padCenter + Offset(-px * 0.035, i * px * 0.05),
        padCenter + Offset(px * 0.035, i * px * 0.05),
        Paint()
          ..color = Cyber.bg.withValues(alpha: 0.18)
          ..strokeWidth = px * 0.008,
      );
    }
  }

  /// Two-segment IK limb: joint solved as midpoint pushed along the normal.
  static void _limb(
    Canvas canvas,
    Offset from,
    Offset to, {
    required double bend,
    required Paint upper,
    required Paint lower,
    required double px,
    Color? shoe,
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
    if (shoe != null) {
      canvas.drawCircle(to, px * 0.075, Paint()..color = shoe);
    }
  }

  static Color _darken(Color color, double amount) => Color.lerp(
        color,
        const Color(0xFF05070B),
        amount,
      )!;
}

// ---------------------------------------------------------------------------
// Preview painter for lobby jersey picker tiles
// ---------------------------------------------------------------------------

/// Letterboxed batsman rig for the lobby jersey picker. Draws a small
/// batsman in idle pose with the given team colors.
class CricketJerseyPreviewPainter extends CustomPainter {
  CricketJerseyPreviewPainter(this.primary, this.accent);

  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final pose = batsmanPose(swing: 0.55, time: 0, onFire: false);
    CricketRigPainter.drawBatsmanRig(
      canvas,
      Offset(size.width / 2, size.height * 0.88),
      pose,
      primary: primary,
      accent: accent,
      skin: const Color(0xFFD4A373),
      scale: size.height * 0.52,
      onFire: false,
    );
  }

  @override
  bool shouldRepaint(CricketJerseyPreviewPainter old) =>
      primary != old.primary || accent != old.accent;
}
