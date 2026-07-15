/// Procedural athlete rendering for Hoop Duel.
///
/// No sprite assets: each athlete is a code-drawn rig (limbs as thick
/// round-cap strokes, IK-lite elbows/knees) posed parametrically from the
/// engine's body state, in the app's stylized-silhouette tradition
/// (Football Chess tokens / Grand Prix cars). Team + look colors are content
/// colors; everything else pulls from `Cyber` tokens.
///
/// The pose type and the drawing primitives are shared with the other rigs —
/// see `games/rig/athlete_rig.dart`. This file only holds what is basketball:
/// the pose-per-[BodyState] switch and the jersey/hardwood draw pass.
library;

import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart' show Colors;

import 'package:flame/components.dart';

import '../../config/theme.dart';
import '../../data/basketball_athletes.dart';
import '../../data/basketball_teams.dart';
import '../rig/athlete_rig.dart';
import 'basketball_engine.dart';
import 'basketball_game.dart';
import 'basketball_tuning.dart';

/// Hoop Duel's pose is the shared [RigPose] — hip height, torso lean, foot
/// targets (relative to the point under the hip) and hand targets (relative to
/// the shoulder).
typedef BasketballPose = RigPose;

/// Computes the pose for the current engine body state. All motion in here is
/// a pure function of state + timers, so rendering stays deterministic.
BasketballPose poseFor(BasketballAthleteBody body, double runPhase, {double? dribbleBallY}) {
  final pose = _basePoseFor(body, runPhase);
  if (dribbleBallY != null && _isDribblingState(body.body)) {
    final scaleM = body.spec.heightM / 1.95;
    final shoulderY = pose.hip * scaleM + 0.52 * scaleM;
    final dy = (shoulderY - dribbleBallY) / scaleM;
    final dx = (0.32 - sin(pose.lean) * 0.3) / scaleM;
    return BasketballPose(
      hip: pose.hip,
      lean: pose.lean,
      footNear: pose.footNear,
      footFar: pose.footFar,
      handNear: Offset(dx, dy),
      handFar: pose.handFar,
      headBob: pose.headBob,
    );
  }
  return pose;
}

bool _isDribblingState(BodyState state) {
  switch (state) {
    case BodyState.idle:
    case BodyState.run:
    case BodyState.drive:
    case BodyState.crossover:
    case BodyState.stepback:
    case BodyState.stance:
    case BodyState.stagger:
      return true;
    default:
      return false;
  }
}

BasketballPose _basePoseFor(BasketballAthleteBody body, double runPhase) {
  final t = body.stateT;
  final jumpFrac = body.jumpDur > 0
      ? (body.jumpT / body.jumpDur).clamp(0.0, 1.0)
      : 0.0;
  final tired = body.stamina01 < 0.25;

  switch (body.body) {
    case BodyState.idle:
      final bob = sin(t * (tired ? 4.5 : 2.2)) * 0.02;
      return BasketballPose(
        hip: (tired ? 0.86 : 0.94) + bob,
        lean: tired ? 0.38 : 0.06,
        footNear: const Offset(0.16, 0),
        footFar: const Offset(-0.16, 0),
        handNear: tired ? const Offset(0.18, -0.62) : const Offset(0.1, -0.52),
        handFar: tired ? const Offset(-0.1, -0.62) : const Offset(-0.12, -0.5),
        headBob: bob,
      );
    case BodyState.run:
    case BodyState.drive:
      final speedy = body.body == BodyState.drive;
      final swing = sin(runPhase);
      final amp = speedy ? 0.42 : 0.3;
      return BasketballPose(
        hip: 0.9 + sin(runPhase * 2).abs() * 0.03,
        lean: speedy ? 0.34 : 0.18,
        footNear: Offset(swing * amp, max(0.0, sin(runPhase)) * 0.14),
        footFar: Offset(-swing * amp, max(0.0, -sin(runPhase)) * 0.14),
        handNear: Offset(-swing * 0.24 + 0.08, -0.42),
        handFar: Offset(swing * 0.24 - 0.08, -0.44),
      );
    case BodyState.crossover:
      final k = (t / 0.25).clamp(0.0, 1.0);
      return BasketballPose(
        hip: 0.78 - sin(k * pi) * 0.08,
        lean: 0.3,
        footNear: Offset(0.34 - k * 0.5, 0),
        footFar: const Offset(-0.3, 0),
        handNear: Offset(0.22 - k * 0.44, -0.16),
        handFar: const Offset(-0.2, -0.4),
      );
    case BodyState.stepback:
      return BasketballPose(
        hip: 0.86,
        lean: -0.22,
        footNear: const Offset(0.28, 0.06),
        footFar: const Offset(-0.24, 0),
        handNear: const Offset(0.1, -0.3),
        handFar: const Offset(-0.14, -0.34),
      );
    case BodyState.gather:
      return BasketballPose(
        hip: 0.78,
        lean: 0.12,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: const Offset(0.24, -0.28),
        handFar: const Offset(0.18, -0.32),
      );
    case BodyState.jump:
      return _jumpPose(body, jumpFrac);
    case BodyState.land:
      final k = (t / 0.18).clamp(0.0, 1.0);
      return BasketballPose(
        hip: 0.74 + k * 0.2,
        lean: 0.18 - k * 0.12,
        footNear: const Offset(0.2, 0),
        footFar: const Offset(-0.2, 0),
        handNear: const Offset(0.16, -0.2),
        handFar: const Offset(-0.16, -0.2),
      );
    case BodyState.stance:
      final sway = sin(t * 3) * 0.02;
      return BasketballPose(
        hip: 0.76 + sway,
        lean: 0.14,
        footNear: const Offset(0.34, 0),
        footFar: const Offset(-0.34, 0),
        handNear: const Offset(0.42, -0.18),
        handFar: const Offset(-0.4, -0.16),
      );
    case BodyState.lunge:
      final k = (t / 0.35).clamp(0.0, 1.0);
      return BasketballPose(
        hip: 0.7 - sin(k * pi) * 0.06,
        lean: 0.5,
        footNear: Offset(0.4 + k * 0.2, 0),
        footFar: const Offset(-0.34, 0),
        handNear: Offset(0.5 + sin(k * pi) * 0.16, -0.06),
        handFar: const Offset(-0.2, -0.3),
      );
    case BodyState.contest:
      return BasketballPose(
        hip: 0.92,
        lean: 0.04,
        footNear: const Offset(0.2, 0),
        footFar: const Offset(-0.2, 0),
        handNear: const Offset(0.1, -1.06),
        handFar: const Offset(-0.06, -1.02),
      );
    case BodyState.fake:
      final k = (t / 0.35).clamp(0.0, 1.0);
      final up = sin(min(1.0, k * 2) * pi) * 0.5;
      return BasketballPose(
        hip: 0.84 + up * 0.06,
        lean: 0.08,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: Offset(0.2, -0.3 - up),
        handFar: Offset(0.14, -0.34 - up),
      );
    case BodyState.stagger:
      final wob = sin(t * 16) * (1 - (t / 0.6).clamp(0.0, 1.0)) * 0.2;
      return BasketballPose(
        hip: 0.8,
        lean: -0.4 + wob,
        footNear: const Offset(0.36, 0),
        footFar: const Offset(-0.1, 0),
        handNear: Offset(0.3 + wob, -0.7),
        handFar: Offset(-0.34 - wob, -0.6),
        headBob: wob * 0.4,
      );
    case BodyState.celebrate:
      // Fist pump: arm punches the sky on a springy hop.
      final pump = sin(t * 10).abs();
      return BasketballPose(
        hip: 0.94 + pump * 0.05,
        lean: -0.12,
        footNear: const Offset(0.18, 0),
        footFar: const Offset(-0.18, 0),
        handNear: Offset(0.1, -1.08 - pump * 0.08),
        handFar: const Offset(-0.2, -0.55),
        headBob: pump * 0.03,
      );
    case BodyState.dejected:
      // Head down, shoulders slumped, hands hanging low.
      final sag = min(1.0, t * 3);
      return BasketballPose(
        hip: 0.9 - sag * 0.04,
        lean: 0.3 * sag,
        footNear: const Offset(0.14, 0),
        footFar: const Offset(-0.14, 0),
        handNear: Offset(0.08, -0.22 - sag * 0.02),
        handFar: const Offset(-0.1, -0.22),
        headBob: -0.05 * sag,
      );
    case BodyState.spin:
      // Sweeping low turn: the lean whips front-to-back through the spin
      // (reads as a body rotation side-on), ball arm wrapped in tight.
      final k = (t / kBbSpinDuration).clamp(0.0, 1.0);
      final whirl = sin(k * pi);
      return BasketballPose(
        hip: 0.72 + whirl * 0.06,
        lean: 0.45 - k * 0.9,
        footNear: Offset(0.3 - k * 0.5, 0.06 * whirl),
        footFar: Offset(-0.2 + k * 0.42, 0),
        handNear: Offset(-0.28 * whirl + 0.06, -0.5),
        handFar: Offset(0.34 * whirl, -0.66),
        headBob: whirl * 0.02,
      );
  }
}

BasketballPose _jumpPose(BasketballAthleteBody body, double frac) {
  final tuck = sin(frac * pi);
  switch (body.jumpPurpose) {
    case JumpPurpose.shot:
      // Ball overhead, wrist follow-through past the apex.
      final release = (frac - 0.4).clamp(0.0, 1.0) * 1.6;
      return BasketballPose(
        hip: 0.98,
        lean: 0.02,
        footNear: Offset(0.08, 0.2 * tuck),
        footFar: Offset(-0.1, 0.26 * tuck),
        handNear: Offset(0.18 + release * 0.12, -1.0 - release * 0.06),
        handFar: const Offset(0.06, -0.9),
      );
    case JumpPurpose.layup:
    case JumpPurpose.putback:
      return BasketballPose(
        hip: 0.98,
        lean: 0.12,
        footNear: Offset(0.16, 0.42 * tuck), // knee drive
        footFar: Offset(-0.12, 0.1 * tuck),
        handNear: Offset(0.3, -1.02 - tuck * 0.1),
        handFar: const Offset(-0.08, -0.5),
      );
    case JumpPurpose.dunk:
      // Windup behind the head → two-hand slam in front.
      final slam = (frac - 0.35).clamp(0.0, 1.0) / 0.65;
      final reach = -0.6 + slam * 1.1;
      return BasketballPose(
        hip: 0.98,
        lean: 0.2 + slam * 0.18,
        footNear: Offset(0.2, 0.4 * tuck),
        footFar: Offset(-0.16, 0.34 * tuck),
        handNear: Offset(reach * 0.5 + 0.3, -1.04 + slam * 0.2),
        handFar: Offset(reach * 0.5 + 0.14, -1.0 + slam * 0.2),
      );
    case JumpPurpose.block:
      return BasketballPose(
        hip: 0.98,
        lean: 0.04,
        footNear: Offset(0.1, 0.28 * tuck),
        footFar: Offset(-0.12, 0.2 * tuck),
        handNear: const Offset(0.16, -1.14),
        handFar: const Offset(-0.14, -0.4),
      );
    case JumpPurpose.rebound:
      return BasketballPose(
        hip: 0.98,
        lean: 0,
        footNear: Offset(0.1, 0.3 * tuck),
        footFar: Offset(-0.1, 0.3 * tuck),
        handNear: const Offset(0.14, -1.1),
        handFar: const Offset(-0.12, -1.08),
      );
    case null:
      return BasketballPose(
        hip: 0.96,
        footNear: const Offset(0.14, 0.1),
        footFar: const Offset(-0.14, 0.1),
        handNear: const Offset(0.12, -0.5),
        handFar: const Offset(-0.12, -0.5),
      );
  }
}

/// Renders one athlete from the live engine body. The ball-handler's heat
/// aura is the only glow on the court (THE GLOW RULE).
class AthleteComponent extends PositionComponent
    with HasGameReference<BasketballGame> {
  AthleteComponent({required this.team});

  final int team;
  double _runPhase = 0;
  double _lastX = 0;

  BasketballAthleteBody get body => game.engine.bodies[team];

  @override
  void update(double dt) {
    super.update(dt);
    final x = body.x;
    _runPhase += (x - _lastX).abs() * 6.5 + dt * 0.8;
    _lastX = x;
  }

  @override
  void render(Canvas canvas) {
    final gameRef = game;
    final engine = gameRef.engine;
    final b = body;
    final look = basketballLookFor(b.spec.id);
    final px = gameRef.pxPerUnit;
    final heightPx = b.spec.heightM * px;
    final ground = gameRef.worldToScreen(b.x, 0);
    final lift = b.jumpHeight * px;

    canvas.save();
    canvas.translate(ground.dx, ground.dy - lift);
    // Squash & stretch around the feet anchor.
    final squash = _squash(b);
    canvas.scale(squash.dx * b.facing.toDouble(), squash.dy);

    // Ground shadow (before body, unscaled-ish).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, lift),
        width: heightPx * 0.42 * (1 - b.jumpHeight * 0.4),
        height: heightPx * 0.07,
      ),
      Paint()..color = const Color(0x66000000),
    );

    // Heat aura — the one glow on court.
    if (engine.teams[team].heatActive) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -heightPx * 0.45),
          width: heightPx * 0.8,
          height: heightPx * 1.1,
        ),
        Paint()
          ..color = look.accent.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }

    double? dribbleBallY;
    if (engine.ball.holder == team && engine.ball.phase == BallPhase.held) {
      final guarded = (engine.bodies[1 - team].x - b.x).abs() <= kBbGuardedGap;
      final height = guarded ? 0.5 : 0.75;
      final bounce = sin(gameRef.dribblePhase * (guarded ? 1.6 : 1.0)).abs() * height;
      dribbleBallY = 0.14 + bounce + 0.12; // target near the top of the ball
    }

    final pose = poseFor(b, _runPhase, dribbleBallY: dribbleBallY);
    final livery = basketballTeamById(
      team == 0 ? gameRef.config.teamId : gameRef.config.cpuTeamId,
    );

    // Hardwood reflection: the same rig mirrored about the ground line,
    // squashed and faded. Skipped under reduced motion (also the perf guard).
    if (!gameRef.reducedMotion) {
      canvas.save();
      canvas.translate(0, lift * 2);
      canvas.scale(1, -kBbReflectSquash);
      final bounds = Rect.fromLTWH(
        -heightPx,
        -heightPx * 1.3,
        heightPx * 2,
        heightPx * 1.6,
      );
      canvas.saveLayer(
        bounds,
        Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: kBbReflectAlpha),
      );
      drawBasketballRig(
        canvas,
        b,
        pose,
        look,
        px,
        primary: livery.primary,
        secondary: livery.secondary,
        accent: livery.accent,
      );
      canvas.restore();
      canvas.restore();
    }

    drawBasketballRig(
      canvas,
      b,
      pose,
      look,
      px,
      primary: livery.primary,
      secondary: livery.secondary,
      accent: livery.accent,
    );
    canvas.restore();
  }

  Offset _squash(BasketballAthleteBody b) {
    if (b.body == BodyState.jump && b.jumpT < 0.08) {
      return const Offset(0.94, 1.08);
    }
    if (b.body == BodyState.land && b.stateT < 0.1) {
      return const Offset(1.07, 0.92);
    }
    return const Offset(1, 1);
  }

}

// -----------------------------------------------------------------------------
// Rig drawing — top-level so extra passes (floor reflections) can reuse it.
// -----------------------------------------------------------------------------

/// Draws one athlete rig in the given jersey livery colors. Called by
/// [AthleteComponent] for the main pass and again (flipped + faded) for the
/// hardwood reflection.
void drawBasketballRig(
  Canvas canvas,
  BasketballAthleteBody b,
  BasketballPose pose,
  BasketballAthleteLook look,
  double px, {
  required Color primary,
  required Color secondary,
  required Color accent,
}) {
    final primaryColor = primary;
    final secondaryColor = secondary;
    final accentColor = accent;

    final h = b.spec.heightM;
    final scaleM = h / 1.95; // proportions relative to a 1.95m frame

    // Anchor points (athlete-local px, y up → canvas y down).
    Offset pt(double xM, double yM) => Offset(xM * px, -yM * px);

    final hip = pt(0, pose.hip * scaleM);
    final shoulderY = pose.hip * scaleM + 0.52 * scaleM;
    final shoulder = pt(sin(pose.lean) * 0.3, shoulderY);
    final headCenter = pt(
      sin(pose.lean) * 0.42,
      shoulderY + 0.24 * scaleM + pose.headBob,
    );

    final strokeBody = Paint()
      ..color = primaryColor
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
    final strokeShorts = Paint()
      ..color = rigDarken(primaryColor, 0.15)
      ..strokeWidth = px * 0.15
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
      
    final padPaint = Paint()
      ..color = secondaryColor
      ..strokeWidth = px * 0.10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final sleevePaint = Paint()
      ..color = secondaryColor
      ..strokeWidth = px * 0.10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Legs (far first, darker).
    rigLimb(
      canvas,
      hip,
      pt(pose.footFar.dx * scaleM, pose.footFar.dy * scaleM),
      bend: -0.22 * px,
      upper: strokeShorts,
      lower: strokeSkinFar,
      lowerOverlay: rigDarken(padPaint.color, 0.25),
      shoe: rigDarken(accentColor, 0.2),
      shoeAccent: rigDarken(secondaryColor, 0.2),
      px: px,
    );
    rigLimb(
      canvas,
      hip,
      pt(pose.footNear.dx * scaleM, pose.footNear.dy * scaleM),
      bend: -0.26 * px,
      upper: strokeShorts,
      lower: strokeSkin,
      lowerOverlay: padPaint.color,
      shoe: accentColor,
      shoeAccent: secondaryColor,
      px: px,
    );

    // Far arm behind the torso. Hand offsets use canvas convention already
    // (negative dy = up), so they add to the shoulder directly.
    rigLimb(
      canvas,
      shoulder,
      shoulder + pose.handFar * (scaleM * px),
      bend: 0.2 * px,
      upper: strokeSkinFar,
      lower: strokeSkinFar,
      lowerOverlay: rigDarken(sleevePaint.color, 0.25),
      px: px,
    );

    // Torso (jersey) + trim + volume shading.
    canvas.drawLine(hip, shoulder, strokeBody);
    
    // Torso shading
    canvas.drawLine(
      Offset(hip.dx + px * 0.04, hip.dy), 
      Offset(shoulder.dx + px * 0.04, shoulder.dy), 
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..strokeWidth = px * 0.05
        ..strokeCap = StrokeCap.round
    );

    // Jersey Stripes
    canvas.drawLine(
      Offset.lerp(hip, shoulder, 0.1)!,
      Offset.lerp(hip, shoulder, 0.9)!,
      Paint()
        ..color = secondaryColor
        ..strokeWidth = px * 0.04
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset.lerp(hip, shoulder, 0.15)!,
      Offset.lerp(hip, shoulder, 0.4)!,
      Paint()
        ..color = accentColor
        ..strokeWidth = px * 0.05
        ..strokeCap = StrokeCap.round,
    );

    // Shoulder bar — widens the silhouette into a T at the top of the jersey.
    canvas.drawLine(
      shoulder + Offset(-0.15 * scaleM * px, 0),
      shoulder + Offset(0.15 * scaleM * px, 0),
      Paint()
        ..color = primaryColor
        ..strokeWidth = px * 0.15
        ..strokeCap = StrokeCap.round,
    );

    // Jersey number — the surrounding canvas is X-flipped by facing, so
    // un-flip locally to keep the digits readable in both directions.
    final numberPos = Offset.lerp(hip, shoulder, 0.55)!;
    canvas.save();
    canvas.translate(numberPos.dx, numberPos.dy);
    canvas.scale(b.facing.toDouble(), 1);
    rigNumberPaint(accentColor, px * 0.2).render(
      canvas,
      '${jerseyNumberFor(b.spec.id)}',
      Vector2.zero(),
      anchor: Anchor.center,
    );
    canvas.restore();

    // Head + hair + headband.
    final headR = 0.155 * scaleM * px;
    canvas.drawCircle(headCenter, headR, Paint()..color = look.skin);
    
    // Head shading
    canvas.drawArc(
       Rect.fromCircle(center: headCenter, radius: headR),
       -pi / 2,
       pi,
       false,
       Paint()
         ..color = Colors.black.withValues(alpha: 0.15)
         ..style = PaintingStyle.stroke
         ..strokeWidth = headR * 0.3
    );

    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headR * 1.06),
      pi,
      pi,
      false,
      Paint()
        ..color = look.hair
        ..style = PaintingStyle.stroke
        ..strokeWidth = headR * 0.62,
    );
    canvas.drawLine(
      headCenter + Offset(-headR, headR * 0.1),
      headCenter + Offset(headR, headR * 0.1),
      Paint()
        ..color = primaryColor
        ..strokeWidth = headR * 0.26,
    );

    // Visor face hint — a lit line across the front of the face. Flat color,
    // no blur: a lit line is not a glow (THE GLOW RULE stays intact).
    canvas.drawLine(
      headCenter + Offset(headR * 0.15, headR * 0.42),
      headCenter + Offset(headR * 0.95, headR * 0.42),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.85)
        ..strokeWidth = headR * 0.2
        ..strokeCap = StrokeCap.round,
    );

    // Near arm in front.
    rigLimb(
      canvas,
      shoulder,
      shoulder + pose.handNear * (scaleM * px),
      bend: 0.24 * px,
      upper: strokeSkin,
      lower: strokeSkin,
      lowerOverlay: sleevePaint.color,
      px: px,
    );
  }
