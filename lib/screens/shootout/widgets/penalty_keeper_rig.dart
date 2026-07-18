import 'dart:math';
import 'dart:ui';

import '../../../config/enums.dart';
import '../../../config/theme.dart';
import '../../../games/rig/athlete_rig.dart';
import '../../../models/cards.dart';

/// Readable states for the procedural goalkeeper. The goal scene blends
/// between these poses by passing a 0-1 [progress] value to
/// [paintPenaltyKeeper].
enum KeeperPose { ready, anticipate, dive, smother, catching, beaten }

/// Stable visual identity derived from a card. It intentionally suggests a
/// character rather than attempting a real-player likeness at this scale.
class KeeperVisualSpec {
  const KeeperVisualSpec({
    required this.primary,
    required this.secondary,
    required this.skin,
    required this.hair,
    required this.gloves,
  });

  factory KeeperVisualSpec.fromCard(
    PlayerCard? card, {
    required bool userSide,
  }) {
    final id = card?.id ?? 'keeper';
    final hash = id.codeUnits.fold<int>(17, (value, unit) => value * 31 + unit);
    const skinTones = <Color>[
      Color(0xFFF2C6A0),
      Color(0xFFD99A72),
      Color(0xFFB96F4F),
      Color(0xFF7B432F),
      Color(0xFF4A2B23),
    ];
    const hairTones = <Color>[
      Color(0xFF171B24),
      Color(0xFF33241E),
      Color(0xFF5A3828),
      Color(0xFFD4A45D),
    ];
    final tierAccent = switch (card?.tier ?? CardTier.bronze) {
      CardTier.bronze => const Color(0xFFB97850),
      CardTier.silver => const Color(0xFFC9D4E3),
      CardTier.gold => Cyber.gold,
      CardTier.platinum => Cyber.violet,
    };
    return KeeperVisualSpec(
      primary: userSide ? Cyber.cyan : Cyber.amber,
      secondary: tierAccent,
      skin: skinTones[hash.abs() % skinTones.length],
      hair: hairTones[(hash ~/ 7).abs() % hairTones.length],
      gloves: userSide ? const Color(0xFFE7FBFF) : const Color(0xFFFFF2D8),
    );
  }

  final Color primary;
  final Color secondary;
  final Color skin;
  final Color hair;
  final Color gloves;
}

double _sign(PenaltyDirection direction) => switch (direction) {
  PenaltyDirection.left => -1,
  PenaltyDirection.center => 0,
  PenaltyDirection.right => 1,
};

/// Paints a frontal cyber-football goalkeeper with a broad jersey, articulated
/// limbs, boots and high-contrast gloves. [anchor] is the midpoint between the
/// keeper's boots when standing on the goal line.
void paintPenaltyKeeper(
  Canvas canvas, {
  required Offset anchor,
  required double height,
  required KeeperVisualSpec visual,
  required KeeperPose pose,
  required PenaltyDirection direction,
  double progress = 1,
  double idlePhase = 0,
  Offset? intercept,
}) {
  final p = progress.clamp(0.0, 1.0);
  final s = height / 150;
  final sign = _sign(direction);
  final diving =
      pose == KeeperPose.dive ||
      pose == KeeperPose.catching ||
      pose == KeeperPose.beaten;
  final centerAction =
      direction == PenaltyDirection.center &&
      (pose == KeeperPose.smother || pose == KeeperPose.catching);
  final anticipating = pose == KeeperPose.anticipate;
  final idle = pose == KeeperPose.ready ? sin(idlePhase * pi * 2) : 0.0;

  final travel = diving ? 43 * s * p : (anticipating ? 9 * s * p : 0.0);
  final crouch = centerAction ? 16 * s * p : 0.0;
  final rotation = diving ? sign * 0.92 * p : sign * 0.08 * p;

  canvas.save();
  canvas.translate(anchor.dx + sign * travel, anchor.dy - crouch + idle * s);
  canvas.rotate(rotation);

  final outline = Paint()
    ..color = const Color(0xFF05070B)
    ..strokeWidth = 12 * s
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final farKit = Paint()
    ..color = rigDarken(visual.primary, 0.34)
    ..strokeWidth = 9 * s
    ..strokeCap = StrokeCap.round;
  final nearKit = Paint()
    ..color = visual.primary
    ..strokeWidth = 10 * s
    ..strokeCap = StrokeCap.round;
  final skin = Paint()
    ..color = visual.skin
    ..strokeWidth = 7 * s
    ..strokeCap = StrokeCap.round;
  final socks = Paint()
    ..color = rigDarken(visual.primary, 0.18)
    ..strokeWidth = 7 * s
    ..strokeCap = StrokeCap.round;

  final hip = Offset(0, -48 * s);
  final shoulder = Offset((diving ? sign * 5 * p : sign * 2 * p) * s, -91 * s);
  final head = shoulder + Offset(sign * 2 * s, -21 * s);
  final leftFoot = Offset(-18 * s, 0);
  final rightFoot = Offset(18 * s, 0);

  var leftHand = shoulder + Offset(-35 * s, -5 * s);
  var rightHand = shoulder + Offset(35 * s, -5 * s);
  if (anticipating) {
    leftHand += Offset(sign * 7 * s, -4 * s * p);
    rightHand += Offset(sign * 7 * s, -4 * s * p);
  }
  if (diving) {
    final reach = 23 * s * p;
    leftHand += Offset(sign * reach, -18 * s * p);
    rightHand += Offset(sign * reach, -18 * s * p);
  }
  if (centerAction) {
    leftHand = shoulder + Offset(-15 * s, 20 * s * p);
    rightHand = shoulder + Offset(15 * s, 20 * s * p);
  }

  // When a save reaches impact, converge the gloves around the real ball
  // position. Convert the canvas-space target into this transformed rig's
  // local coordinates before blending the hands toward it.
  if (intercept != null &&
      (pose == KeeperPose.catching || pose == KeeperPose.smother)) {
    final globalAnchor = anchor + Offset(sign * travel, -crouch + idle * s);
    final delta = intercept - globalAnchor;
    final cosR = cos(-rotation);
    final sinR = sin(-rotation);
    final localIntercept = Offset(
      delta.dx * cosR - delta.dy * sinR,
      delta.dx * sinR + delta.dy * cosR,
    );
    final lock = ((p - 0.55) / 0.45).clamp(0.0, 1.0);
    leftHand = Offset.lerp(leftHand, localIntercept + Offset(-6 * s, 0), lock)!;
    rightHand = Offset.lerp(
      rightHand,
      localIntercept + Offset(6 * s, 0),
      lock,
    )!;
  }

  // Legs, far side first. The shared IK-lite limb helper gives the keeper
  // readable knees and volume without sprite assets.
  rigLimb(
    canvas,
    hip + Offset(-5 * s, 0),
    leftFoot,
    bend: -10 * s,
    upper: farKit,
    lower: socks,
    px: 36 * s,
    lowerOverlay: visual.secondary,
    shoe: const Color(0xFF101722),
    shoeAccent: visual.secondary,
  );
  rigLimb(
    canvas,
    hip + Offset(5 * s, 0),
    rightFoot,
    bend: 10 * s,
    upper: nearKit,
    lower: socks,
    px: 36 * s,
    lowerOverlay: visual.secondary,
    shoe: const Color(0xFF101722),
    shoeAccent: visual.secondary,
  );

  // Arms receive a dark outline pass before the colored articulated pass.
  canvas.drawLine(shoulder + Offset(-13 * s, 0), leftHand, outline);
  canvas.drawLine(shoulder + Offset(13 * s, 0), rightHand, outline);
  rigLimb(
    canvas,
    shoulder + Offset(-13 * s, 0),
    leftHand,
    bend: -8 * s,
    upper: farKit,
    lower: skin,
    px: 36 * s,
    lowerOverlay: visual.secondary,
  );
  rigLimb(
    canvas,
    shoulder + Offset(13 * s, 0),
    rightHand,
    bend: 8 * s,
    upper: nearKit,
    lower: skin,
    px: 36 * s,
    lowerOverlay: visual.secondary,
  );

  // Broad angular jersey and padded shorts.
  final torso = Path()
    ..moveTo(shoulder.dx - 18 * s, shoulder.dy - 3 * s)
    ..lineTo(shoulder.dx + 18 * s, shoulder.dy - 3 * s)
    ..lineTo(hip.dx + 14 * s, hip.dy + 5 * s)
    ..lineTo(hip.dx - 14 * s, hip.dy + 5 * s)
    ..close();
  canvas.drawPath(
    torso,
    Paint()
      ..color = const Color(0xFF05070B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * s
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(torso, Paint()..color = visual.primary);
  canvas.drawLine(
    shoulder + Offset(-13 * s, 8 * s),
    shoulder + Offset(13 * s, 8 * s),
    Paint()
      ..color = visual.secondary
      ..strokeWidth = 3 * s
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: hip + Offset(0, 5 * s),
        width: 31 * s,
        height: 18 * s,
      ),
      Radius.circular(5 * s),
    ),
    Paint()..color = rigDarken(visual.primary, 0.28),
  );

  // Head, hair and a small visor-like eye line for expression at game scale.
  canvas.drawCircle(head, 12 * s, Paint()..color = const Color(0xFF05070B));
  canvas.drawCircle(head, 9.5 * s, Paint()..color = visual.skin);
  canvas.drawArc(
    Rect.fromCircle(center: head + Offset(0, -2 * s), radius: 9.5 * s),
    pi,
    pi,
    true,
    Paint()..color = visual.hair,
  );
  canvas.drawLine(
    head + Offset(-4 * s, 1 * s),
    head + Offset(4 * s, 1 * s),
    Paint()
      ..color = rigDarken(visual.hair, 0.1)
      ..strokeWidth = 1.4 * s
      ..strokeCap = StrokeCap.round,
  );

  // Oversized gloves are the visual focus of the character.
  for (final hand in [leftHand, rightHand]) {
    canvas.drawCircle(hand, 8.2 * s, Paint()..color = const Color(0xFF05070B));
    canvas.drawCircle(hand, 6.1 * s, Paint()..color = visual.gloves);
    canvas.drawLine(
      hand + Offset(-3 * s, 0),
      hand + Offset(3 * s, 0),
      Paint()
        ..color = visual.secondary
        ..strokeWidth = 1.6 * s
        ..strokeCap = StrokeCap.round,
    );
  }

  canvas.restore();
}
