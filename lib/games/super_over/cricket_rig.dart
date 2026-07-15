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

import 'package:flutter/material.dart' show Colors, Curves, CustomPainter;

import '../../config/theme.dart';
import '../../models/super_over.dart';

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
  CricketBattingStyle style = CricketBattingStyle.anchor,
  ShotStyle shotStyle = ShotStyle.ground,
}) {
  // Detect idle vs active swing.
  final isIdle = (swing - 0.55).abs() < 0.12;

  if (isIdle) {
    // Relaxed batting guard at the crease.
    final bob = sin(time * 2.2) * 0.02;
    final breathe = sin(time * 1.4) * 0.01;
    final stanceWidth = switch (style) {
      CricketBattingStyle.anchor => 0.0,
      CricketBattingStyle.powerHitter => 0.08,
      CricketBattingStyle.improviser => 0.04,
    };
    return CricketPose(
      hip: 0.90 + bob,
      lean:
          0.08 +
          breathe +
          (style == CricketBattingStyle.powerHitter ? -0.05 : 0),
      footNear: Offset(0.20 + stanceWidth, 0),
      footFar: Offset(-0.14 - stanceWidth, 0),
      handNear: const Offset(0.16, -0.38),
      handFar: const Offset(0.10, -0.42),
      headBob: bob,
    );
  }

  // Active swing — interpolate pose based on swing angle.
  if (swing < -0.5) {
    // Leg-side shot: weight shifting across, bat sweeping to leg.
    final t = ((swing + 0.95) / 0.45).clamp(0.0, 1.0);
    final lift = shotStyle == ShotStyle.loft ? -0.14 : 0.0;
    return CricketPose(
      hip: 0.82,
      lean: -0.28 + t * 0.1,
      footNear: Offset(0.32 - t * 0.08, 0),
      footFar: Offset(-0.22 + t * 0.06, 0),
      handNear: Offset(-0.08 - t * 0.14, -0.26 + lift),
      handFar: Offset(-0.14 - t * 0.08, -0.34 + lift),
    );
  } else if (swing < 0.3) {
    // V / straight drive: front foot forward, bat coming through straight.
    final t = ((swing + 0.20) / 0.50).clamp(0.0, 1.0);
    final lift = shotStyle == ShotStyle.loft ? -0.18 : 0.0;
    return CricketPose(
      hip: 0.84,
      lean: 0.22 + t * 0.06,
      footNear: Offset(0.30 + t * 0.06, 0),
      footFar: Offset(-0.18 - t * 0.04, 0),
      handNear: Offset(0.20 + t * 0.08, -0.32 + lift),
      handFar: Offset(0.12 + t * 0.06, -0.38 + lift),
    );
  } else {
    // Off-side drive: opening up body, bat driving through off.
    final t = ((swing - 0.3) / 0.55).clamp(0.0, 1.0);
    final lift = shotStyle == ShotStyle.loft ? -0.15 : 0.0;
    return CricketPose(
      hip: 0.84,
      lean: 0.18 + t * 0.12,
      footNear: Offset(0.28 + t * 0.10, 0),
      footFar: const Offset(-0.20, 0),
      handNear: Offset(0.28 + t * 0.16, -0.28 + t * 0.06 + lift),
      handFar: Offset(0.20 + t * 0.10, -0.36 + lift),
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
  bool spin = false,
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
    final phase = time * (spin ? 8.5 : 12.0);
    final swing = sin(phase);
    final amp = spin ? 0.24 : 0.34;
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
      handNear: spin
          ? Offset(-0.04 + k * 0.22, -0.44 - k * 0.30)
          : Offset(0.12 + k * 0.16, -0.48 - k * 0.38),
      handFar: spin
          ? Offset(0.18 - k * 0.18, -0.28 - k * 0.16)
          : Offset(-0.14 - k * 0.08, -0.36 + k * 0.10),
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
    handNear: spin
        ? Offset(0.10 + sin(k * pi) * 0.24, -0.78 - k * 0.18)
        : Offset(0.28 + sin(k * pi) * 0.18, -0.86 - sin(k * pi * 0.8) * 0.28),
    // Front arm pulls across body.
    handFar: spin
        ? Offset(-0.08 + k * 0.18, -0.34 - k * 0.04)
        : Offset(-0.22 + k * 0.30, -0.26 - k * 0.08),
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

    Offset pt(double xM, double yM) => anchor + Offset(xM * px, -yM * px);

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
      Rect.fromCenter(center: anchor, width: px * 0.42, height: px * 0.07),
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
    final handFar =
        shoulder +
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
    _drawTorsoShell(canvas, hip, shoulder, px, primary, accent);
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
        Rect.fromCenter(
          center: chestCenter,
          width: px * 0.12,
          height: px * 0.14,
        ),
        Radius.circular(px * 0.03),
      ),
      Paint()..color = Cyber.bg.withValues(alpha: 0.18),
    );

    // -- 8. Helmet ------------------------------------------------------------
    _drawHelmet(
      canvas,
      headCenter,
      px,
      scaleM,
      primary: primary,
      accent: accent,
      skin: skin,
    );

    // -- 9. Near arm ----------------------------------------------------------
    final handNear =
        shoulder +
        Offset(pose.handNear.dx * scaleM * px, pose.handNear.dy * scaleM * px);
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
    canvas.drawCircle(
      handFar,
      px * 0.055,
      Paint()..color = _darken(accent, 0.15),
    );
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

    Offset pt(double xM, double yM) => anchor + Offset(xM * px, -yM * px);

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

    // Near leg.
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

    // Far arm.
    final handFar =
        shoulder +
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
    _drawTorsoShell(canvas, hip, shoulder, px, primary, accent);
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
    _drawHelmet(
      canvas,
      headCenter,
      px,
      scaleM,
      primary: primary,
      accent: accent,
      skin: skin,
    );

    // Near arm.
    final handNear =
        shoulder +
        Offset(pose.handNear.dx * scaleM * px, pose.handNear.dy * scaleM * px);
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
      handFar,
      px * 0.055,
      Paint()..color = _darken(skin, 0.15),
    );
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
    canvas.drawRRect(visor, Paint()..color = Cyber.bg.withValues(alpha: 0.78));
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
      Rect.fromCenter(center: padCenter, width: px * 0.10, height: px * 0.22),
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

  static void _drawTorsoShell(
    Canvas canvas,
    Offset hip,
    Offset shoulder,
    double px,
    Color primary,
    Color accent,
  ) {
    final delta = shoulder - hip;
    final length = delta.distance;
    final normal = length > .001
        ? Offset(-delta.dy / length, delta.dx / length)
        : const Offset(1, 0);
    final topHalf = px * .12;
    final bottomHalf = px * .085;
    final path = Path()
      ..moveTo(
        (shoulder + normal * topHalf).dx,
        (shoulder + normal * topHalf).dy,
      )
      ..lineTo((hip + normal * bottomHalf).dx, (hip + normal * bottomHalf).dy)
      ..quadraticBezierTo(
        hip.dx,
        hip.dy + px * .055,
        (hip - normal * bottomHalf).dx,
        (hip - normal * bottomHalf).dy,
      )
      ..lineTo(
        (shoulder - normal * topHalf).dx,
        (shoulder - normal * topHalf).dy,
      )
      ..quadraticBezierTo(
        shoulder.dx,
        shoulder.dy - px * .035,
        (shoulder + normal * topHalf).dx,
        (shoulder + normal * topHalf).dy,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xff06101b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = px * .055
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(path, Paint()..color = primary);
    canvas.drawLine(
      Offset.lerp(hip, shoulder, .68)!,
      Offset.lerp(hip, shoulder, .82)!,
      Paint()
        ..color = accent.withValues(alpha: .82)
        ..strokeWidth = px * .035
        ..strokeCap = StrokeCap.round,
    );
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
    final outline = Paint()
      ..color = const Color(0xff06101b)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      from,
      joint,
      outline..strokeWidth = upper.strokeWidth + px * .035,
    );
    canvas.drawLine(
      joint,
      to,
      outline..strokeWidth = lower.strokeWidth + px * .035,
    );
    canvas.drawLine(from, joint, upper);
    canvas.drawLine(joint, to, lower);
    if (shoe != null) {
      canvas.drawCircle(to, px * 0.075, Paint()..color = shoe);
    }
  }

  static Color _darken(Color color, double amount) =>
      Color.lerp(color, const Color(0xFF05070B), amount)!;
}

// ---------------------------------------------------------------------------
// Perspective-scaled secondary actors
// ---------------------------------------------------------------------------

enum CricketActorRole { fielder, wicketkeeper, nonStriker, runner }

enum CricketActorMotion {
  ready,
  run,
  pickup,
  throwBall,
  catchBall,
  dive,
  celebrate,
  battingGuard,
}

/// Filled geometric actor used for fielders, the keeper, non-striker and
/// running batters. It deliberately avoids the thin-line silhouette used by
/// the former scene while staying cheap enough to draw many times per frame.
class CricketActorPainter {
  CricketActorPainter._();

  /// Hero batter matching the shared Super Over reference: a compact solid
  /// blue silhouette, simple helmet, pale gloves/pads and a thick gold bat.
  static void drawReferenceBatter(
    Canvas canvas,
    Offset feet, {
    required double scale,
    required double swingProgress,
    required ShotSector sector,
    required ShotStyle style,
    required double time,
    required Color primary,
    required Color accent,
    required Color skin,
  }) {
    final s = scale;
    final p = swingProgress.clamp(0.0, 1.0);
    final bob = p == 0 ? sin(time * 2.4) * .7 * s : 0.0;
    final base = feet.translate(0, bob);
    final hip = base.translate(-2 * s, -37 * s);
    final shoulder = hip.translate(2 * s, -31 * s);
    final head = shoulder.translate(-1 * s, -14 * s);
    final outline = const Color(0xff07111f);

    canvas.drawOval(
      Rect.fromCenter(
        center: feet.translate(1 * s, 2 * s),
        width: 34 * s,
        height: 7 * s,
      ),
      Paint()..color = const Color(0x77000000),
    );

    final frontStep = p * (sector == ShotSector.leg ? -4 : 7) * s;
    final backFoot = base.translate(-8 * s, 0);
    final frontFoot = base.translate(12 * s + frontStep, 0);
    _limb(
      canvas,
      hip.translate(-4 * s, 0),
      backFoot,
      10 * s,
      outline,
      _darken(primary, .10),
    );
    _limb(canvas, hip.translate(4 * s, 0), frontFoot, 11 * s, outline, primary);

    for (final foot in [backFoot, frontFoot]) {
      final pad = Rect.fromCenter(
        center: Offset.lerp(hip, foot, .65)!,
        width: 8 * s,
        height: 21 * s,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pad, Radius.circular(2.5 * s)),
        Paint()..color = const Color(0xffdcecff),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(pad, Radius.circular(2.5 * s)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * s
          ..color = primary,
      );
    }

    final torso = Path()
      ..moveTo(shoulder.dx - 10 * s, shoulder.dy)
      ..lineTo(shoulder.dx + 10 * s, shoulder.dy)
      ..lineTo(hip.dx + 8 * s, hip.dy + 3 * s)
      ..lineTo(hip.dx - 8 * s, hip.dy + 3 * s)
      ..close();
    canvas.drawPath(
      torso,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s
        ..strokeJoin = StrokeJoin.round
        ..color = outline,
    );
    canvas.drawPath(torso, Paint()..color = primary);
    canvas.drawLine(
      shoulder.translate(-7 * s, 8 * s),
      shoulder.translate(7 * s, 8 * s),
      Paint()
        ..color = accent.withValues(alpha: .72)
        ..strokeWidth = 3 * s
        ..strokeCap = StrokeCap.round,
    );

    final activeHands = switch (sector) {
      ShotSector.off => shoulder.translate(18 * s, (4 - p * 18) * s),
      ShotSector.leg => shoulder.translate(-16 * s, (5 - p * 17) * s),
      ShotSector.v => shoulder.translate(8 * s, (6 - p * 24) * s),
    };
    final idleHands = shoulder.translate(-2 * s, 18 * s);
    final hands = Offset.lerp(idleHands, activeHands, p)!;
    _limb(
      canvas,
      shoulder.translate(-7 * s, 3 * s),
      hands.translate(-2 * s, 1 * s),
      5.5 * s,
      outline,
      skin,
    );
    _limb(
      canvas,
      shoulder.translate(7 * s, 3 * s),
      hands.translate(2 * s, -1 * s),
      5.5 * s,
      outline,
      skin,
    );

    final idleBatEnd = base.translate(-28 * s, -2 * s);
    final activeBatEnd = switch (sector) {
      ShotSector.off => shoulder.translate(
        40 * s,
        style == ShotStyle.loft ? -40 * s : -10 * s,
      ),
      ShotSector.leg => shoulder.translate(
        -40 * s,
        style == ShotStyle.loft ? -40 * s : -8 * s,
      ),
      ShotSector.v => shoulder.translate(
        style == ShotStyle.loft ? 24 * s : 18 * s,
        style == ShotStyle.loft ? -55 * s : 38 * s,
      ),
    };
    final batEnd = Offset.lerp(idleBatEnd, activeBatEnd, p)!;
    canvas.drawLine(
      hands,
      batEnd,
      Paint()
        ..color = outline
        ..strokeWidth = 10 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      hands,
      batEnd,
      Paint()
        ..color = const Color(0xffffae19)
        ..strokeWidth = 6.5 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      hands.translate(-2 * s, 0),
      3.5 * s,
      Paint()..color = const Color(0xfff3f7ff),
    );
    canvas.drawCircle(
      hands.translate(2 * s, 0),
      3.5 * s,
      Paint()..color = const Color(0xfff3f7ff),
    );

    canvas.drawCircle(
      head,
      8.5 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * s
        ..color = outline,
    );
    canvas.drawCircle(head, 8.2 * s, Paint()..color = skin);
    canvas.drawArc(
      Rect.fromCircle(center: head.translate(0, -1 * s), radius: 8.7 * s),
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7 * s
        ..color = primary,
    );
    canvas.drawLine(
      head.translate(-1 * s, 1 * s),
      head.translate(10 * s, 1 * s),
      Paint()
        ..color = primary
        ..strokeWidth = 3 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Solid blue-and-orange bowler based on the shared reference frame.
  static void drawReferenceBowler(
    Canvas canvas,
    Offset feet, {
    required double scale,
    required double runProgress,
    required double time,
    required Color primary,
    required Color accent,
    required Color skin,
    required bool holdingBall,
  }) {
    final s = scale;
    final p = runProgress.clamp(0.0, 1.0);
    final stride = sin(time * 12) * (1 - p) * 7 * s;
    final hip = feet.translate(0, -34 * s);
    final shoulder = hip.translate(p * 4 * s, -30 * s);
    final head = shoulder.translate(-1 * s, -13 * s);
    final outline = const Color(0xff07111f);

    canvas.drawOval(
      Rect.fromCenter(
        center: feet.translate(0, 2 * s),
        width: 30 * s,
        height: 6 * s,
      ),
      Paint()..color = const Color(0x77000000),
    );
    _limb(
      canvas,
      hip.translate(-4 * s, 0),
      feet.translate(-8 * s + stride, 0),
      10 * s,
      outline,
      _darken(primary, .12),
    );
    _limb(
      canvas,
      hip.translate(4 * s, 0),
      feet.translate(9 * s - stride, 0),
      11 * s,
      outline,
      primary,
    );

    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.lerp(hip, shoulder, .5)!,
        width: 21 * s,
        height: 34 * s,
      ),
      Radius.circular(4 * s),
    );
    canvas.drawRRect(
      torso,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 * s
        ..color = outline,
    );
    canvas.drawRRect(torso, Paint()..color = primary);
    canvas.drawRect(
      Rect.fromCenter(
        center: torso.center.translate(0, -2 * s),
        width: 20 * s,
        height: 12 * s,
      ),
      Paint()..color = accent,
    );

    final bowlingHand = Offset.lerp(
      shoulder.translate(10 * s, 14 * s),
      head.translate(5 * s, -30 * s),
      Curves.easeOut.transform(p),
    )!;
    final guideHand = Offset.lerp(
      shoulder.translate(-9 * s, 13 * s),
      shoulder.translate(-12 * s, -5 * s),
      p,
    )!;
    _limb(
      canvas,
      shoulder.translate(7 * s, 3 * s),
      bowlingHand,
      5.5 * s,
      outline,
      skin,
    );
    _limb(
      canvas,
      shoulder.translate(-7 * s, 3 * s),
      guideHand,
      5.5 * s,
      outline,
      skin,
    );
    if (holdingBall) {
      canvas.drawCircle(
        bowlingHand.translate(1 * s, -2 * s),
        3 * s,
        Paint()..color = Cyber.danger,
      );
    }

    canvas.drawCircle(
      head,
      8 * s,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.7 * s
        ..color = outline,
    );
    canvas.drawCircle(head, 7.8 * s, Paint()..color = skin);
    canvas.drawArc(
      Rect.fromCircle(center: head.translate(0, -1 * s), radius: 8.2 * s),
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6 * s
        ..color = primary,
    );
    canvas.drawLine(
      head.translate(-1 * s, 0),
      head.translate(10 * s, 0),
      Paint()
        ..color = primary
        ..strokeWidth = 3 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  static void draw(
    Canvas canvas,
    Offset feet, {
    required double scale,
    required CricketActorRole role,
    required CricketActorMotion motion,
    required double time,
    required Color primary,
    required Color accent,
    required Color skin,
    bool facingLeft = false,
  }) {
    final s = scale;
    final direction = facingLeft ? -1.0 : 1.0;
    final running = motion == CricketActorMotion.run;
    final phase = time * 12;
    final stride = running ? sin(phase) * 6.5 * s : 0.0;
    final bob = running
        ? sin(phase * 2).abs() * 1.8 * s
        : sin(time * 2) * .5 * s;
    final crouch = switch (motion) {
      CricketActorMotion.ready =>
        role == CricketActorRole.wicketkeeper ? 6.0 : 2.0,
      CricketActorMotion.pickup => 8.0,
      CricketActorMotion.dive => 5.0,
      _ => 0.0,
    };
    final dive = motion == CricketActorMotion.dive ? direction * 10 * s : 0.0;
    final anchor = feet.translate(dive, bob + crouch * s);

    canvas.drawOval(
      Rect.fromCenter(
        center: feet.translate(dive * .45, 2 * s),
        width: (motion == CricketActorMotion.dive ? 34 : 22) * s,
        height: 5.5 * s,
      ),
      Paint()
        ..color = const Color(0xaa02060b)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.6 * s),
    );

    final hip = anchor.translate(0, -20 * s);
    final torsoLean = switch (motion) {
      CricketActorMotion.run => direction * 3.5 * s,
      CricketActorMotion.pickup => direction * 5 * s,
      CricketActorMotion.throwBall => -direction * 2 * s,
      CricketActorMotion.dive => direction * 8 * s,
      _ => 0.0,
    };
    final shoulder = hip.translate(torsoLean, -18 * s);
    final head = shoulder.translate(direction * 1.2 * s, -9 * s);

    final farFoot = anchor.translate(-6 * s - stride, 0);
    final nearFoot = anchor.translate(6 * s + stride, 0);
    _limb(
      canvas,
      hip.translate(-3 * s, 0),
      farFoot,
      6.2 * s,
      const Color(0xff111b2b),
      _darken(primary, .56),
    );
    _limb(
      canvas,
      hip.translate(3 * s, 0),
      nearFoot,
      6.8 * s,
      const Color(0xff111b2b),
      _darken(primary, .40),
    );

    final torso = Path()
      ..moveTo(shoulder.dx - 7 * s, shoulder.dy)
      ..quadraticBezierTo(
        shoulder.dx,
        shoulder.dy - 2 * s,
        shoulder.dx + 7 * s,
        shoulder.dy,
      )
      ..lineTo(hip.dx + 5.5 * s, hip.dy + 2 * s)
      ..quadraticBezierTo(
        hip.dx,
        hip.dy + 5 * s,
        hip.dx - 5.5 * s,
        hip.dy + 2 * s,
      )
      ..close();
    canvas.drawPath(
      torso,
      Paint()
        ..color = const Color(0xff06101b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * s
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(torso, Paint()..color = primary);
    canvas.drawPath(
      Path()
        ..moveTo(shoulder.dx - 5.5 * s, shoulder.dy + 3 * s)
        ..lineTo(shoulder.dx + 5.5 * s, shoulder.dy + 3 * s),
      Paint()
        ..color = accent.withValues(alpha: .92)
        ..strokeWidth = 2.3 * s
        ..strokeCap = StrokeCap.round,
    );

    final handTargets = _handsFor(
      role: role,
      motion: motion,
      shoulder: shoulder,
      scale: s,
      direction: direction,
      time: time,
    );
    _limb(
      canvas,
      shoulder.translate(-5 * s, 2 * s),
      handTargets.$1,
      4.8 * s,
      const Color(0xff06101b),
      skin,
    );
    _limb(
      canvas,
      shoulder.translate(5 * s, 2 * s),
      handTargets.$2,
      5.2 * s,
      const Color(0xff06101b),
      skin,
    );

    canvas.drawCircle(
      head,
      6.3 * s,
      Paint()
        ..color = const Color(0xff06101b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.8 * s,
    );
    canvas.drawCircle(head, 6.1 * s, Paint()..color = skin);
    canvas.drawArc(
      Rect.fromCircle(center: head.translate(0, -.5 * s), radius: 6.4 * s),
      pi,
      pi,
      false,
      Paint()
        ..color = _darken(primary, .32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2 * s,
    );

    if (role == CricketActorRole.wicketkeeper) {
      for (final hand in [handTargets.$1, handTargets.$2]) {
        canvas.drawOval(
          Rect.fromCenter(center: hand, width: 7.5 * s, height: 6 * s),
          Paint()..color = const Color(0xffffd187),
        );
      }
    }

    if (role == CricketActorRole.nonStriker ||
        role == CricketActorRole.runner) {
      _drawBat(
        canvas,
        handTargets.$2,
        direction,
        s,
        motion == CricketActorMotion.run,
      );
      _drawPads(canvas, hip, farFoot, nearFoot, s);
    }

    if (motion == CricketActorMotion.throwBall) {
      canvas.drawCircle(
        handTargets.$2.translate(direction * 2 * s, -2 * s),
        2.4 * s,
        Paint()..color = Cyber.danger,
      );
    }
  }

  static (Offset, Offset) _handsFor({
    required CricketActorRole role,
    required CricketActorMotion motion,
    required Offset shoulder,
    required double scale,
    required double direction,
    required double time,
  }) {
    final s = scale;
    return switch (motion) {
      CricketActorMotion.run => (
        shoulder.translate(-direction * 8 * s, 12 * s + sin(time * 12) * 5 * s),
        shoulder.translate(direction * 9 * s, 10 * s - sin(time * 12) * 5 * s),
      ),
      CricketActorMotion.pickup => (
        shoulder.translate(-direction * 7 * s, 18 * s),
        shoulder.translate(direction * 8 * s, 24 * s),
      ),
      CricketActorMotion.throwBall => (
        shoulder.translate(-direction * 10 * s, 11 * s),
        shoulder.translate(direction * 13 * s, -12 * s),
      ),
      CricketActorMotion.catchBall => (
        shoulder.translate(-7 * s, -10 * s),
        shoulder.translate(7 * s, -10 * s),
      ),
      CricketActorMotion.dive => (
        shoulder.translate(direction * 11 * s, -2 * s),
        shoulder.translate(direction * 18 * s, 2 * s),
      ),
      CricketActorMotion.celebrate => (
        shoulder.translate(-9 * s, -14 * s),
        shoulder.translate(9 * s, -14 * s),
      ),
      CricketActorMotion.battingGuard => (
        shoulder.translate(direction * 5 * s, 10 * s),
        shoulder.translate(direction * 9 * s, 13 * s),
      ),
      CricketActorMotion.ready =>
        role == CricketActorRole.wicketkeeper
            ? (
                shoulder.translate(-10 * s, 14 * s),
                shoulder.translate(10 * s, 14 * s),
              )
            : (
                shoulder.translate(-9 * s, 12 * s),
                shoulder.translate(9 * s, 12 * s),
              ),
    };
  }

  static void _limb(
    Canvas canvas,
    Offset from,
    Offset to,
    double width,
    Color outline,
    Color fill,
  ) {
    final mid = Offset.lerp(from, to, .53)!.translate(0, width * .3);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, to.dx, to.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = fill
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  static void _drawBat(
    Canvas canvas,
    Offset hand,
    double direction,
    double scale,
    bool running,
  ) {
    final s = scale;
    final end = hand.translate(
      direction * (running ? 12 : 8) * s,
      (running ? 18 : 24) * s,
    );
    canvas.drawLine(
      hand,
      end,
      Paint()
        ..color = const Color(0xff06101b)
        ..strokeWidth = 7 * s
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      hand,
      end,
      Paint()
        ..color = const Color(0xffd4ad62)
        ..strokeWidth = 4.2 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  static void _drawPads(
    Canvas canvas,
    Offset hip,
    Offset farFoot,
    Offset nearFoot,
    double scale,
  ) {
    for (final foot in [farFoot, nearFoot]) {
      final center = Offset.lerp(hip, foot, .65)!;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center,
            width: 6.5 * scale,
            height: 12 * scale,
          ),
          Radius.circular(2 * scale),
        ),
        Paint()..color = const Color(0xffdceef1),
      );
    }
  }

  static Color _darken(Color color, double amount) =>
      Color.lerp(color, const Color(0xff05090f), amount)!;
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
