/// Procedural athlete rendering for Final Over.
///
/// Same language as Hoop Duel (see `games/rig/athlete_rig.dart`): no sprites,
/// limbs are thick round-cap strokes with IK-lite elbows and knees, only the
/// hip/shoulder/head are ever stored, and every pose is a *pure function* of
/// the engine's state — so what you see is a projection of `MatchState`, never
/// an animation the renderer invented.
///
/// Cricket adds four things basketball has no word for: a bat, a helmet with a
/// grille, leg pads, and batting gloves. All of them are built from the same
/// primitives so a batter reads as the same species as a Hoop Duel guard.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart' show Anchor, Vector2;
import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/material.dart' show Colors;

import '../../config/theme.dart';
import '../../data/final_over_kits.dart';
import '../rig/athlete_rig.dart';

/// The frame of reference every dimension scales against.
const double kFoReferenceHeightM = 1.8;

// ─── Poses ────────────────────────────────────────────────────────────────────

enum FoBatterPose {
  stance,
  backlift,
  groundOff,
  groundStraight,
  groundLeg,
  loftOff,
  loftStraight,
  loftLeg,
  miss,
  bowled,
  running,
  slide,
  celebrate,
}

enum FoBowlerPose { ready, runUp, gather, release, followThrough }

enum FoUmpireSignal { idle, four, six, out }

/// A batter is a [RigPose] plus the one thing a basketball player never has:
/// a bat angle, in radians from the +x axis (canvas convention — y grows down,
/// so a negative angle points up-and-forward).
class FoBatterFrame {
  const FoBatterFrame(this.pose, this.batAngle);
  final RigPose pose;
  final double batAngle;
}

double _swing(double a, double b, double t) =>
    a + (b - a) * Curves.easeInOutCubic.transform(t.clamp(0.0, 1.0));

/// Batter pose for the given shot. [t] is 0→1 through the stroke (for the
/// swing poses) or free-running seconds (for stance/celebrate); [runPhase]
/// drives the run cycle and advances with *distance travelled*, not time, so
/// the feet never skate.
FoBatterFrame foBatterFrame(FoBatterPose kind, double t, {double runPhase = 0}) {
  switch (kind) {
    case FoBatterPose.stance:
      // Front-foot-forward guard: crouched, weight forward, hands low and
      // together near the front pad, bat toe down-and-forward rather than
      // tucked behind the back foot. This is also the k=0 baseline
      // `backlift` animates FROM, so pressing HIT never jumps silhouettes.
      final breathe = sin(t * 2.4) * 0.015;
      return FoBatterFrame(
        RigPose(
          hip: 0.80 + breathe,
          lean: 0.30,
          footNear: const Offset(0.28, 0),
          footFar: const Offset(-0.20, 0),
          handNear: const Offset(0.10, 0.22),
          handFar: const Offset(0.05, 0.26),
          headBob: breathe,
        ),
        1.25, // toe down and forward, near the front pad
      );

    case FoBatterPose.backlift:
      final k = t.clamp(0.0, 1.0);
      // `t` grows past 1.0 for as long as the hold continues — `overflow` is
      // real elapsed hold-time past full cock, used only for the idle coil
      // below so a long hold reads as tense, not frozen.
      final overflow = (t - 1.0).clamp(0.0, 1000.0);
      final coil = sin(overflow * 5.0) * 0.014;
      return FoBatterFrame(
        RigPose(
          hip: 0.80 + coil, // == stance
          lean: 0.30 - k * 0.10 + coil * 0.6, // == stance @ k=0
          footNear: const Offset(0.28, 0), // == stance
          footFar: const Offset(-0.20, 0), // == stance
          handNear: Offset(0.10 - k * 0.06, 0.22 - k * 0.88),
          handFar: Offset(0.05 - k * 0.05, 0.26 - k * 0.98),
          headBob: coil * 0.7,
        ),
        _swing(1.25, -2.35, k), // starts at stance's angle, cocks up behind
      );

    case FoBatterPose.groundOff:
    case FoBatterPose.groundStraight:
    case FoBatterPose.groundLeg:
      final k = t.clamp(0.0, 1.0);
      final lateral = switch (kind) {
        FoBatterPose.groundOff => -0.14, // opens the face, across the line
        FoBatterPose.groundLeg => 0.16, // whips it away to leg
        _ => 0.0,
      };
      return FoBatterFrame(
        RigPose(
          hip: _swing(0.86, 0.80, k),
          lean: _swing(0.12, 0.46, k), // drives over the ball
          footNear: Offset(_swing(0.18, 0.34, k), 0),
          footFar: const Offset(-0.24, 0),
          handNear: Offset(_swing(-0.02, 0.44 + lateral, k), _swing(-0.62, -0.24, k)),
          handFar: Offset(_swing(-0.06, 0.36 + lateral, k), _swing(-0.68, -0.32, k)),
        ),
        _swing(-2.35, 0.35, k), // through the line, finishing low
      );

    case FoBatterPose.loftOff:
    case FoBatterPose.loftStraight:
    case FoBatterPose.loftLeg:
      final k = t.clamp(0.0, 1.0);
      final lateral = switch (kind) {
        FoBatterPose.loftOff => -0.16,
        FoBatterPose.loftLeg => 0.20,
        _ => 0.0,
      };
      // Front leg braces, torso opens up, hands finish high over the shoulder.
      return FoBatterFrame(
        RigPose(
          hip: _swing(0.86, 0.94, k),
          lean: _swing(0.14, -0.30, k), // leans back to get under it
          footNear: Offset(_swing(0.18, 0.38, k), _swing(0, 0.10, k)),
          footFar: const Offset(-0.26, 0),
          handNear: Offset(_swing(-0.02, 0.30 + lateral, k), _swing(-0.60, -0.96, k)),
          handFar: Offset(_swing(-0.06, 0.22 + lateral, k), _swing(-0.66, -1.00, k)),
          headBob: k * 0.02,
        ),
        _swing(-2.35, -1.15, k), // finishes high
      );

    case FoBatterPose.miss:
      // Swung through thin air — bat past the body, head chasing it.
      final k = t.clamp(0.0, 1.0);
      return FoBatterFrame(
        RigPose(
          hip: _swing(0.86, 0.84, k),
          lean: _swing(0.10, 0.30, k),
          footNear: const Offset(0.22, 0),
          footFar: const Offset(-0.24, 0),
          handNear: Offset(_swing(-0.02, 0.20, k), _swing(-0.60, -0.50, k)),
          handFar: Offset(_swing(-0.06, 0.12, k), _swing(-0.66, -0.56, k)),
          headBob: -0.02 * k,
        ),
        _swing(-2.35, -0.10, k),
      );

    case FoBatterPose.bowled:
      // The slump. Everything sags toward the stumps behind.
      final sag = min(1.0, t * 2.4);
      return FoBatterFrame(
        RigPose(
          hip: 0.86 - sag * 0.10,
          lean: 0.10 + sag * 0.34,
          footNear: const Offset(0.20, 0),
          footFar: const Offset(-0.20, 0),
          handNear: Offset(0.16, -0.26 + sag * 0.08),
          handFar: Offset(0.10, -0.30 + sag * 0.08),
          headBob: -0.07 * sag,
        ),
        _swing(-0.4, 1.6, sag), // bat drops
      );

    case FoBatterPose.running:
      final s = sin(runPhase);
      return FoBatterFrame(
        RigPose(
          hip: 0.90 + sin(runPhase * 2).abs() * 0.03,
          lean: 0.36,
          footNear: Offset(s * 0.40, max(0.0, sin(runPhase)) * 0.14),
          footFar: Offset(-s * 0.40, max(0.0, -sin(runPhase)) * 0.14),
          handNear: Offset(-s * 0.20 + 0.10, -0.44),
          handFar: Offset(s * 0.24 - 0.08, -0.46),
        ),
        -0.6, // bat carried back, tip trailing
      );

    case FoBatterPose.slide:
      // Bat stretched out for the crease.
      final k = t.clamp(0.0, 1.0);
      return FoBatterFrame(
        RigPose(
          hip: _swing(0.80, 0.44, k),
          lean: _swing(0.5, 0.95, k),
          footNear: Offset(_swing(0.30, -0.28, k), 0),
          footFar: Offset(_swing(-0.20, -0.52, k), 0.04),
          handNear: Offset(_swing(0.34, 0.62, k), _swing(-0.30, 0.02, k)),
          handFar: Offset(0.10, -0.34),
        ),
        0.2, // reaching for the line
      );

    case FoBatterPose.celebrate:
      final pump = sin(t * 9).abs();
      return FoBatterFrame(
        RigPose(
          hip: 0.94 + pump * 0.05,
          lean: -0.14,
          footNear: const Offset(0.18, 0),
          footFar: const Offset(-0.18, 0),
          handNear: Offset(0.12, -1.08 - pump * 0.08),
          handFar: const Offset(-0.18, -0.58),
          headBob: pump * 0.03,
        ),
        -1.7, // bat aloft
      );
  }
}

/// Bowler pose. [t] is 0→1 through the phase.
RigPose foBowlerPose(FoBowlerPose kind, double t, {double runPhase = 0}) {
  switch (kind) {
    case FoBowlerPose.ready:
      final breathe = sin(t * 2.0) * 0.015;
      return RigPose(
        hip: 0.92 + breathe,
        lean: 0.06,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: const Offset(0.14, -0.44),
        handFar: const Offset(-0.02, -0.48), // ball cupped at the chest
        headBob: breathe,
      );

    case FoBowlerPose.runUp:
      final s = sin(runPhase);
      return RigPose(
        hip: 0.90 + sin(runPhase * 2).abs() * 0.03,
        lean: 0.30,
        footNear: Offset(s * 0.44, max(0.0, sin(runPhase)) * 0.16),
        footFar: Offset(-s * 0.44, max(0.0, -sin(runPhase)) * 0.16),
        handNear: Offset(-s * 0.22 + 0.10, -0.46),
        handFar: Offset(s * 0.18 - 0.04, -0.50),
      );

    case FoBowlerPose.gather:
      // Coil: front knee up, bowling arm cocked back and low.
      final k = t.clamp(0.0, 1.0);
      return RigPose(
        hip: _swing(0.90, 0.98, k),
        lean: _swing(0.30, -0.16, k),
        footNear: Offset(_swing(0.30, 0.16, k), _swing(0.02, 0.40, k)),
        footFar: Offset(_swing(-0.30, -0.34, k), 0),
        handNear: Offset(_swing(0.10, 0.26, k), _swing(-0.46, -0.72, k)),
        handFar: Offset(_swing(-0.04, -0.34, k), _swing(-0.50, -0.10, k)),
      );

    case FoBowlerPose.release:
      // The arm comes over the top. `snap` is the whole point of the pose.
      final snap = t.clamp(0.0, 1.0);
      final armAngle = -2.25 + 2.75 * Curves.easeInCubic.transform(snap);
      return RigPose(
        hip: _swing(0.98, 0.88, snap),
        lean: _swing(-0.16, 0.42, snap),
        footNear: Offset(_swing(0.16, 0.40, snap), _swing(0.40, 0, snap)),
        footFar: Offset(_swing(-0.34, -0.30, snap), 0),
        handNear: Offset(cos(armAngle) * 0.52, sin(armAngle) * 0.52 - 0.36),
        handFar: Offset(_swing(-0.34, 0.18, snap), _swing(-0.10, -0.52, snap)),
      );

    case FoBowlerPose.followThrough:
      final k = t.clamp(0.0, 1.0);
      return RigPose(
        hip: _swing(0.88, 0.90, k),
        lean: _swing(0.42, 0.26, k),
        footNear: Offset(_swing(0.40, 0.20, k), 0),
        footFar: Offset(_swing(-0.30, -0.36, k), _swing(0, 0.14, k)),
        handNear: Offset(_swing(0.30, 0.06, k), _swing(0.10, -0.40, k)),
        handFar: Offset(_swing(0.18, -0.16, k), _swing(-0.52, -0.44, k)),
      );
  }
}

/// Umpire pose. The signals are the cheapest, loudest feedback in cricket —
/// the crowd knows it's a six because a man in a hat raised both arms.
RigPose foUmpirePose(FoUmpireSignal signal, double t) {
  switch (signal) {
    case FoUmpireSignal.idle:
      final breathe = sin(t * 1.8) * 0.012;
      return RigPose(
        hip: 0.92 + breathe,
        lean: 0.02,
        footNear: const Offset(0.12, 0),
        footFar: const Offset(-0.12, 0),
        handNear: const Offset(0.10, -0.20),
        handFar: const Offset(-0.10, -0.20),
        headBob: breathe,
      );
    case FoUmpireSignal.four:
      // One arm sweeping across the body.
      final k = min(1.0, t * 3);
      final wave = sin(t * 7) * 0.10 * k;
      return RigPose(
        hip: 0.92,
        lean: 0.04,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: Offset(_swing(0.10, -0.44, k) + wave, _swing(-0.20, -0.52, k)),
        handFar: const Offset(-0.12, -0.20),
      );
    case FoUmpireSignal.six:
      // Both arms straight up. Unmistakable.
      final k = min(1.0, t * 3.4);
      return RigPose(
        hip: 0.92 + k * 0.03,
        lean: 0,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: Offset(0.12, _swing(-0.20, -1.14, k)),
        handFar: Offset(-0.12, _swing(-0.20, -1.12, k)),
      );
    case FoUmpireSignal.out:
      // The finger.
      final k = min(1.0, t * 3.2);
      return RigPose(
        hip: 0.92,
        lean: 0.02,
        footNear: const Offset(0.12, 0),
        footFar: const Offset(-0.12, 0),
        handNear: Offset(_swing(0.10, 0.16, k), _swing(-0.20, -1.10, k)),
        handFar: const Offset(-0.10, -0.20),
      );
  }
}

// ─── Drawing ──────────────────────────────────────────────────────────────────

/// What sits on the head. A helmet is a batter, a cap is a fielder, a hat is
/// the umpire.
enum FoHeadGear { helmet, cap, hat }

/// Draws a batter: the rig, then the bat over the top of the near arm.
///
/// [trailBatAngles] are recent past bat angles (oldest first) drawn as
/// fading ghosts behind the live bat — a cheap motion trail for the fast
/// part of a committed swing. Empty by default (stance/backlift/preview
/// renders never pass any).
void drawFoBatter(
  Canvas canvas,
  FoBatterFrame frame, {
  required FinalOverKit kit,
  required FinalOverLook look,
  required double px,
  required double heightM,
  required int number,
  int facing = 1,
  List<double> trailBatAngles = const [],
}) {
  drawFoRig(
    canvas,
    frame.pose,
    kit: kit,
    look: look,
    px: px,
    heightM: heightM,
    number: number,
    facing: facing,
    gear: FoHeadGear.helmet,
    pads: true,
    gloves: true,
  );

  // Bat last, so it reads in front of the near arm.
  final scaleM = heightM / kFoReferenceHeightM;
  final shoulderY = frame.pose.hip * scaleM + 0.50 * scaleM;
  final shoulder = Offset(sin(frame.pose.lean) * 0.3 * px, -shoulderY * px);
  final grip = shoulder + frame.pose.handNear * (scaleM * px);
  for (var i = 0; i < trailBatAngles.length; i++) {
    final fade = 0.12 + 0.16 * i; // oldest faintest, newest brightest
    _drawBat(canvas, grip, trailBatAngles[i], px, scaleM, kit, alpha: fade);
  }
  _drawBat(canvas, grip, frame.batAngle, px, scaleM, kit);
}

/// Draws the bowler. [ballInHand] paints the ball at the bowling hand until it
/// leaves it.
void drawFoBowler(
  Canvas canvas,
  RigPose pose, {
  required FinalOverKit kit,
  required FinalOverLook look,
  required double px,
  required double heightM,
  required int number,
  int facing = 1,
  bool ballInHand = false,
}) {
  drawFoRig(
    canvas,
    pose,
    kit: kit,
    look: look,
    px: px,
    heightM: heightM,
    number: number,
    facing: facing,
    gear: FoHeadGear.cap,
    pads: false,
    gloves: false,
  );

  if (!ballInHand) return;
  final scaleM = heightM / kFoReferenceHeightM;
  final shoulderY = pose.hip * scaleM + 0.50 * scaleM;
  final shoulder = Offset(sin(pose.lean) * 0.3 * px, -shoulderY * px);
  final hand = shoulder + pose.handNear * (scaleM * px);
  canvas.drawCircle(hand, px * 0.055, Paint()..color = _ballRed);
  canvas.drawArc(
    Rect.fromCircle(center: hand, radius: px * 0.055),
    -pi * 0.8,
    pi * 0.7,
    false,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = px * 0.012,
  );
}

/// Draws the umpire — white coat, black hat, no number.
void drawFoUmpire(
  Canvas canvas,
  RigPose pose, {
  required double px,
  required double heightM,
  int facing = 1,
}) {
  drawFoRig(
    canvas,
    pose,
    kit: _umpireKit,
    look: const FinalOverLook(skin: Color(0xFFC68642), hair: Color(0xFF1C1310)),
    px: px,
    heightM: heightM,
    number: -1, // suppressed
    facing: facing,
    gear: FoHeadGear.hat,
    pads: false,
    gloves: false,
  );
}

const _umpireKit = FinalOverKit(
  id: '_umpire',
  name: 'UMPIRE',
  primary: Color(0xFFE8ECF3),
  secondary: Color(0xFF9AA8C7),
  accent: Color(0xFF2A3550),
);

const _ballRed = Color(0xFFC4342B);

/// The core rig — everything a Final Over actor has in common. Kept top-level
/// so both the batter and the bowler can build on it.
void drawFoRig(
  Canvas canvas,
  RigPose pose, {
  required FinalOverKit kit,
  required FinalOverLook look,
  required double px,
  required double heightM,
  required int number,
  required FoHeadGear gear,
  required bool pads,
  required bool gloves,
  int facing = 1,
}) {
  final scaleM = heightM / kFoReferenceHeightM;

  // Athlete-local px, y up → canvas y down. Feet anchored at the origin.
  Offset pt(double xM, double yM) => Offset(xM * px, -yM * px);

  final hip = pt(0, pose.hip * scaleM);
  final shoulderY = pose.hip * scaleM + 0.50 * scaleM;
  final shoulder = pt(sin(pose.lean) * 0.3, shoulderY);
  final headCenter = pt(
    sin(pose.lean) * 0.42,
    shoulderY + 0.23 * scaleM + pose.headBob,
  );

  final strokeBody = Paint()
    ..color = kit.primary
    ..strokeWidth = px * 0.19
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final strokeSkin = Paint()
    ..color = look.skin
    ..strokeWidth = px * 0.095
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  final strokeSkinFar = Paint()
    ..color = rigDarken(look.skin, 0.25)
    ..strokeWidth = px * 0.095
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  // Cricket whites are trousers, not shorts — the leg stroke runs full length.
  final strokeTrouser = Paint()
    ..color = rigDarken(kit.primary, 0.15)
    ..strokeWidth = px * 0.15
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;

  // Legs (far first, darker — painter's algorithm gives depth for free).
  rigLimb(
    canvas,
    hip,
    pt(pose.footFar.dx * scaleM, pose.footFar.dy * scaleM),
    bend: -0.22 * px,
    upper: strokeTrouser,
    lower: pads ? _padPaint(rigDarken(kit.secondary, 0.25), px) : strokeTrouser,
    lowerOverlay: pads ? rigDarken(kit.secondary, 0.32) : null,
    shoe: rigDarken(kit.accent, 0.2),
    shoeAccent: rigDarken(kit.secondary, 0.2),
    px: px,
  );
  rigLimb(
    canvas,
    hip,
    pt(pose.footNear.dx * scaleM, pose.footNear.dy * scaleM),
    bend: -0.26 * px,
    upper: strokeTrouser,
    lower: pads ? _padPaint(kit.secondary, px) : strokeTrouser,
    lowerOverlay: pads ? kit.secondary : null,
    shoe: kit.accent,
    shoeAccent: kit.secondary,
    px: px,
  );

  // Far arm, behind the torso.
  rigLimb(
    canvas,
    shoulder,
    shoulder + pose.handFar * (scaleM * px),
    bend: 0.2 * px,
    upper: strokeSkinFar,
    lower: strokeSkinFar,
    lowerOverlay: rigDarken(kit.secondary, 0.25),
    px: px,
  );

  // Torso.
  canvas.drawLine(hip, shoulder, strokeBody);
  canvas.drawLine(
    Offset(hip.dx + px * 0.04, hip.dy),
    Offset(shoulder.dx + px * 0.04, shoulder.dy),
    Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = px * 0.05
      ..strokeCap = StrokeCap.round,
  );

  // Shirt trim.
  canvas.drawLine(
    Offset.lerp(hip, shoulder, 0.1)!,
    Offset.lerp(hip, shoulder, 0.9)!,
    Paint()
      ..color = kit.secondary
      ..strokeWidth = px * 0.04
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawLine(
    Offset.lerp(hip, shoulder, 0.15)!,
    Offset.lerp(hip, shoulder, 0.4)!,
    Paint()
      ..color = kit.accent
      ..strokeWidth = px * 0.05
      ..strokeCap = StrokeCap.round,
  );

  // Shoulder bar — widens the silhouette into a T.
  canvas.drawLine(
    shoulder + Offset(-0.15 * scaleM * px, 0),
    shoulder + Offset(0.15 * scaleM * px, 0),
    Paint()
      ..color = kit.primary
      ..strokeWidth = px * 0.15
      ..strokeCap = StrokeCap.round,
  );

  // Shirt number. The canvas is X-flipped by facing, so un-flip locally to keep
  // the digits readable in both directions.
  if (number >= 0) {
    final numberPos = Offset.lerp(hip, shoulder, 0.55)!;
    canvas.save();
    canvas.translate(numberPos.dx, numberPos.dy);
    canvas.scale(facing.toDouble(), 1);
    rigNumberPaint(kit.accent, px * 0.2).render(
      canvas,
      '$number',
      Vector2.zero(),
      anchor: Anchor.center,
    );
    canvas.restore();
  }

  _drawHead(canvas, headCenter, scaleM * px, gear, kit, look);

  // Near arm, in front.
  rigLimb(
    canvas,
    shoulder,
    shoulder + pose.handNear * (scaleM * px),
    bend: 0.24 * px,
    upper: strokeSkin,
    lower: strokeSkin,
    lowerOverlay: gloves ? kit.secondary : rigDarken(kit.secondary, 0.1),
    px: px,
  );
}

Paint _padPaint(Color color, double px) => Paint()
  ..color = color
  ..strokeWidth = px * 0.13
  ..strokeCap = StrokeCap.round
  ..style = PaintingStyle.stroke;

void _drawHead(
  Canvas canvas,
  Offset center,
  double unit,
  FoHeadGear gear,
  FinalOverKit kit,
  FinalOverLook look,
) {
  final r = 0.150 * unit;

  canvas.drawCircle(center, r, Paint()..color = look.skin);
  // Volume: a dark arc over the crown.
  canvas.drawArc(
    Rect.fromCircle(center: center, radius: r),
    -pi / 2,
    pi,
    false,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.3,
  );

  switch (gear) {
    case FoHeadGear.helmet:
      // Dome in the kit colour…
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 1.08),
        pi,
        pi,
        false,
        Paint()
          ..color = kit.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.70,
      );
      // …a peak over the brow…
      canvas.drawLine(
        center + Offset(r * 0.1, -r * 0.42),
        center + Offset(r * 1.15, -r * 0.30),
        Paint()
          ..color = rigDarken(kit.primary, 0.3)
          ..strokeWidth = r * 0.20
          ..strokeCap = StrokeCap.round,
      );
      // …and the grille. A flat lit line, never a blur — THE GLOW RULE holds
      // even on the one thing the player stares at all match.
      canvas.drawLine(
        center + Offset(r * 0.20, r * 0.05),
        center + Offset(r * 1.02, r * 0.05),
        Paint()
          ..color = kit.secondary
          ..strokeWidth = r * 0.16
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        center + Offset(r * 0.24, r * 0.46),
        center + Offset(r * 0.96, r * 0.46),
        Paint()
          ..color = kit.secondary
          ..strokeWidth = r * 0.16
          ..strokeCap = StrokeCap.round,
      );
    case FoHeadGear.cap:
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 1.06),
        pi,
        pi,
        false,
        Paint()
          ..color = look.hair
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.62,
      );
      canvas.drawLine(
        center + Offset(-r * 0.9, -r * 0.35),
        center + Offset(r * 0.9, -r * 0.35),
        Paint()
          ..color = kit.primary
          ..strokeWidth = r * 0.34
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        center + Offset(r * 0.5, -r * 0.42),
        center + Offset(r * 1.35, -r * 0.42),
        Paint()
          ..color = rigDarken(kit.primary, 0.25)
          ..strokeWidth = r * 0.18
          ..strokeCap = StrokeCap.round,
      );
    case FoHeadGear.hat:
      // Wide-brim umpire hat.
      canvas.drawLine(
        center + Offset(-r * 1.3, -r * 0.30),
        center + Offset(r * 1.3, -r * 0.30),
        Paint()
          ..color = const Color(0xFF141B2B)
          ..strokeWidth = r * 0.18
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawArc(
        Rect.fromCircle(center: center.translate(0, -r * 0.22), radius: r * 0.9),
        pi,
        pi,
        false,
        Paint()
          ..color = const Color(0xFF141B2B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.55,
      );
  }
}

/// The bat: three tones — a dark edge, a grip, and a blade that catches the
/// light. Drawn in its own rotated space so the shot poses only have to think
/// about one angle.
void _drawBat(
  Canvas canvas,
  Offset grip,
  double angle,
  double px,
  double scaleM,
  FinalOverKit kit, {
  double alpha = 1.0,
}) {
  final len = 0.62 * scaleM * px;
  final width = 0.115 * scaleM * px;

  canvas.save();
  canvas.translate(grip.dx, grip.dy);
  canvas.rotate(angle);

  // Handle.
  canvas.drawLine(
    Offset(-len * 0.16, 0),
    Offset(len * 0.30, 0),
    Paint()
      ..color = const Color(0xFF23282F).withValues(alpha: alpha)
      ..strokeWidth = width * 0.38
      ..strokeCap = StrokeCap.round,
  );
  // Grip band, in the kit accent so the bat belongs to the team.
  canvas.drawLine(
    Offset(-len * 0.10, 0),
    Offset(len * 0.14, 0),
    Paint()
      ..color = kit.accent.withValues(alpha: alpha)
      ..strokeWidth = width * 0.46
      ..strokeCap = StrokeCap.round,
  );

  // Blade. Bleached willow, deliberately far lighter than any skin tone in
  // [FinalOverLook] — at this size a mid-tan blade reads as a forearm.
  final blade = RRect.fromRectAndRadius(
    Rect.fromLTWH(len * 0.30, -width / 2, len * 0.70, width),
    Radius.circular(width * 0.22),
  );
  canvas.drawRRect(
    blade.shift(Offset(0, width * 0.18)),
    Paint()
      ..color = const Color(
        0xFF6B4A22,
      ).withValues(alpha: alpha), // dark edge behind, for volume
  );
  canvas.drawRRect(
    blade,
    Paint()..color = const Color(0xFFF3E6C8).withValues(alpha: alpha),
  );
  // Spine + the dark outline that keeps the bat off the batter's arms.
  canvas.drawLine(
    Offset(len * 0.34, -width * 0.06),
    Offset(len * 0.94, -width * 0.06),
    Paint()
      ..color = const Color(0xFFFFF9EA).withValues(alpha: alpha)
      ..strokeWidth = width * 0.18
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawRRect(
    blade,
    Paint()
      ..color = const Color(0xFF5A3E1C).withValues(alpha: alpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width * 0.10,
  );

  canvas.restore();
}

// ─── Top-down field view ──────────────────────────────────────────────────────

/// A fielder seen from directly above — a rig makes no sense from up here, so
/// they're kit-coloured markers with a facing wedge. Same colour rules.
void drawFoFielderMark(
  Canvas canvas,
  Offset at,
  double radius, {
  required FinalOverKit kit,
  required bool active,
  Offset facing = Offset.zero,
}) {
  canvas.drawOval(
    Rect.fromCenter(
      center: at.translate(0, radius * 0.5),
      width: radius * 2.1,
      height: radius * 0.9,
    ),
    Paint()..color = const Color(0x55000000),
  );

  if (facing.distance > 0.01) {
    final dir = facing / facing.distance;
    final path = Path()
      ..moveTo(at.dx + dir.dx * radius * 2.2, at.dy + dir.dy * radius * 2.2)
      ..lineTo(at.dx - dir.dy * radius * 0.8, at.dy + dir.dx * radius * 0.8)
      ..lineTo(at.dx + dir.dy * radius * 0.8, at.dy - dir.dx * radius * 0.8)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = kit.primary.withValues(alpha: active ? 0.55 : 0.25),
    );
  }

  canvas.drawCircle(at, radius, Paint()..color = kit.primary);
  canvas.drawCircle(
    at,
    radius,
    Paint()
      ..color = active ? kit.accent : rigDarken(kit.primary, 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.34,
  );
  canvas.drawCircle(at, radius * 0.42, Paint()..color = kit.secondary);
}

/// A runner seen from above. The active batter is the one thing on the field
/// worth a glow — everything else is flat (THE GLOW RULE).
void drawFoRunnerMark(
  Canvas canvas,
  Offset at,
  double radius, {
  required FinalOverKit kit,
  required int number,
  required bool striker,
  bool danger = false,
}) {
  if (striker) {
    canvas.drawCircle(
      at,
      radius * 2.0,
      Paint()
        ..color = (danger ? Cyber.danger : Cyber.cyan).withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }
  canvas.drawCircle(at, radius, Paint()..color = kit.primary);
  canvas.drawCircle(
    at,
    radius,
    Paint()
      ..color = kit.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.3,
  );
  rigNumberPaint(kit.secondary, radius * 1.1).render(
    canvas,
    '$number',
    Vector2(at.dx, at.dy),
    anchor: Anchor.center,
  );
}
