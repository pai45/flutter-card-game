import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'final_over_palette.dart';

/// All batter actions are explicit so gameplay can render a pose from a fixed
/// simulation time without owning an AnimationController.
enum BatterPose {
  idle,
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
}

class FinalOverBatterRig extends StatelessWidget {
  const FinalOverBatterRig({
    super.key,
    this.pose = BatterPose.idle,
    this.progress = 0,
    this.jerseyNumber = '06',
    this.facingRight = true,
    this.accentColor = FinalOverPalette.orange,
  });

  final BatterPose pose;
  final double progress;
  final String jerseyNumber;
  final bool facingRight;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BatterRigPainter(
        pose: pose,
        progress: progress,
        jerseyNumber: jerseyNumber,
        facingRight: facingRight,
        accentColor: accentColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Convenience rig for the alternate non-striker specified by the art bible.
class FinalOverRunnerRig extends StatelessWidget {
  const FinalOverRunnerRig({
    super.key,
    this.progress = 0,
    this.sliding = false,
    this.facingRight = true,
  });

  final double progress;
  final bool sliding;
  final bool facingRight;

  @override
  Widget build(BuildContext context) {
    return FinalOverBatterRig(
      pose: sliding ? BatterPose.slide : BatterPose.running,
      progress: progress,
      jerseyNumber: '12',
      facingRight: facingRight,
      accentColor: FinalOverPalette.cyan,
    );
  }
}

class BatterRigPainter extends CustomPainter {
  const BatterRigPainter({
    this.pose = BatterPose.idle,
    this.progress = 0,
    this.jerseyNumber = '06',
    this.facingRight = true,
    this.accentColor = FinalOverPalette.orange,
  });

  final BatterPose pose;
  final double progress;
  final String jerseyNumber;
  final bool facingRight;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = math.min(size.width, size.height);
    final p = visualClamp01(progress);
    final geometry = _batterGeometry(pose, p);
    canvas.save();
    canvas.translate(size.width / 2, (size.height - unit) / 2);
    canvas.scale(facingRight ? unit : -unit, unit);

    _paintShadow(canvas, geometry);
    _paintLeg(
      canvas,
      geometry.hip,
      geometry.backKnee,
      geometry.backFoot,
      false,
    );
    _paintLeg(
      canvas,
      geometry.hip,
      geometry.frontKnee,
      geometry.frontFoot,
      true,
    );
    _paintTorso(canvas, geometry);
    _paintHead(canvas, geometry);
    _paintArmsAndBat(canvas, geometry);
    canvas.restore();
  }

  void _paintShadow(Canvas canvas, _BatterGeometry geometry) {
    final midpoint = Offset(
      (geometry.frontFoot.dx + geometry.backFoot.dx) / 2,
      math.max(geometry.frontFoot.dy, geometry.backFoot.dy) + .018,
    );
    canvas.drawOval(
      Rect.fromCenter(center: midpoint, width: .48, height: .065),
      Paint()
        ..color = FinalOverPalette.black.withValues(alpha: .42)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .018),
    );
  }

  void _paintLeg(
    Canvas canvas,
    Offset hip,
    Offset knee,
    Offset foot,
    bool foreground,
  ) {
    final outline = Paint()
      ..color = FinalOverPalette.navy
      ..strokeWidth = foreground ? .098 : .09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final trouser = Paint()
      ..color = foreground
          ? FinalOverPalette.royalBlue
          : const Color(0xFF0D3C91)
      ..strokeWidth = foreground ? .075 : .068
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(hip.dx, hip.dy)
      ..lineTo(knee.dx, knee.dy)
      ..lineTo(foot.dx, foot.dy);
    canvas.drawPath(path, outline);
    canvas.drawPath(path, trouser);
    canvas.drawLine(
      foot + const Offset(-.015, 0),
      foot + const Offset(.075, .005),
      Paint()
        ..color = FinalOverPalette.white
        ..strokeWidth = .04
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      knee + const Offset(-.025, .018),
      knee + const Offset(.02, .1),
      Paint()
        ..color = FinalOverPalette.white.withValues(alpha: .9)
        ..strokeWidth = .045
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintTorso(Canvas canvas, _BatterGeometry geometry) {
    final topLeft = geometry.shoulder + const Offset(-.115, -.02);
    final hipRight = geometry.hip + const Offset(.09, .02);
    final hipLeft = geometry.hip + const Offset(-.09, .018);
    final torso = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..quadraticBezierTo(
        geometry.shoulder.dx,
        geometry.shoulder.dy - .055,
        geometry.shoulder.dx + .12,
        geometry.shoulder.dy + .002,
      )
      ..lineTo(hipRight.dx, hipRight.dy)
      ..quadraticBezierTo(
        geometry.hip.dx,
        geometry.hip.dy + .055,
        hipLeft.dx,
        hipLeft.dy,
      )
      ..close();
    canvas.drawPath(
      torso,
      Paint()
        ..color = FinalOverPalette.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = .035
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      torso,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                FinalOverPalette.royalBlue,
                FinalOverPalette.deepBlue,
              ],
            ).createShader(
              Rect.fromCenter(
                center: geometry.shoulder,
                width: .34,
                height: .42,
              ),
            ),
    );
    final sashPoints = <Offset>[
      geometry.shoulder + const Offset(-.1, .03),
      geometry.shoulder + const Offset(.1, .11),
      geometry.hip + const Offset(.075, -.02),
      geometry.hip + const Offset(.015, -.045),
    ];
    final sash = Path()..addPolygon(sashPoints, true);
    canvas.drawPath(sash, Paint()..color = accentColor.withValues(alpha: .92));

    final numberPainter = TextPainter(
      text: TextSpan(
        text: jerseyNumber,
        style: const TextStyle(
          color: FinalOverPalette.white,
          fontSize: .085,
          fontWeight: FontWeight.w900,
          height: 1,
          letterSpacing: -.01,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    canvas.save();
    if (!facingRight) canvas.scale(-1, 1);
    final numberCenterX = facingRight
        ? geometry.shoulder.dx
        : -geometry.shoulder.dx;
    numberPainter.paint(
      canvas,
      Offset(
        numberCenterX - numberPainter.width / 2,
        geometry.shoulder.dy + .055,
      ),
    );
    canvas.restore();
  }

  void _paintHead(Canvas canvas, _BatterGeometry geometry) {
    final head = geometry.head;
    canvas.drawCircle(
      head,
      .096,
      Paint()
        ..color = const Color(0xFF9A552F)
        ..style = PaintingStyle.fill,
    );
    final helmet = Path()
      ..addArc(Rect.fromCircle(center: head, radius: .112), math.pi, math.pi)
      ..lineTo(head.dx + .112, head.dy + .01)
      ..quadraticBezierTo(
        head.dx,
        head.dy - .015,
        head.dx - .112,
        head.dy + .02,
      )
      ..close();
    canvas.drawPath(helmet, Paint()..color = FinalOverPalette.deepBlue);
    canvas.drawArc(
      Rect.fromCenter(
        center: head + const Offset(.062, .025),
        width: .12,
        height: .13,
      ),
      -1.45,
      1.95,
      false,
      Paint()
        ..color = FinalOverPalette.cyan.withValues(alpha: .78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .014,
    );
    canvas.drawLine(
      head + const Offset(.04, -.095),
      head + const Offset(.145, -.065),
      Paint()
        ..color = FinalOverPalette.cyan
        ..strokeWidth = .025
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintArmsAndBat(Canvas canvas, _BatterGeometry geometry) {
    final armOutline = Paint()
      ..color = FinalOverPalette.navy
      ..strokeWidth = .07
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final sleeve = Paint()
      ..color = FinalOverPalette.royalBlue
      ..strokeWidth = .052
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final elbow in <Offset>[geometry.backElbow, geometry.frontElbow]) {
      final path = Path()
        ..moveTo(geometry.shoulder.dx, geometry.shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(geometry.hands.dx, geometry.hands.dy);
      canvas.drawPath(path, armOutline);
      canvas.drawPath(path, sleeve);
    }
    canvas.drawCircle(
      geometry.hands,
      .045,
      Paint()..color = FinalOverPalette.white,
    );

    final batTip = geometry.batTip;
    canvas.drawLine(
      geometry.hands,
      batTip,
      Paint()
        ..color = FinalOverPalette.navy
        ..strokeWidth = .065
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      geometry.hands,
      Offset.lerp(geometry.hands, batTip, .34)!,
      Paint()
        ..color = FinalOverPalette.orange
        ..strokeWidth = .035
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset.lerp(geometry.hands, batTip, .35)!,
      batTip,
      Paint()
        ..shader = const LinearGradient(
          colors: <Color>[FinalOverPalette.pitchLight, FinalOverPalette.white],
        ).createShader(Rect.fromPoints(geometry.hands, batTip))
        ..strokeWidth = .045
        ..strokeCap = StrokeCap.square,
    );
    canvas.drawLine(
      Offset.lerp(geometry.hands, batTip, .43)!,
      batTip,
      Paint()
        ..color = FinalOverPalette.deepBlue.withValues(alpha: .45)
        ..strokeWidth = .009
        ..strokeCap = StrokeCap.square,
    );
  }

  @override
  bool shouldRepaint(covariant BatterRigPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.progress != progress ||
        oldDelegate.jerseyNumber != jerseyNumber ||
        oldDelegate.facingRight != facingRight ||
        oldDelegate.accentColor != accentColor;
  }
}

_BatterGeometry _batterGeometry(BatterPose pose, double progress) {
  var hip = const Offset(-.02, .59);
  var shoulder = const Offset(-.015, .34);
  var head = const Offset(.01, .17);
  var frontKnee = const Offset(.12, .73);
  var frontFoot = const Offset(.2, .9);
  var backKnee = const Offset(-.12, .74);
  var backFoot = const Offset(-.18, .9);
  var frontElbow = const Offset(.14, .43);
  var backElbow = const Offset(-.12, .42);
  var hands = const Offset(.12, .52);
  var batAngle = -1.35;
  var batLength = .43;

  final cycle = math.sin(progress * math.pi * 2);
  switch (pose) {
    case BatterPose.idle:
      final breathe = math.sin(progress * math.pi * 2) * .008;
      shoulder += Offset(0, breathe);
      head += Offset(0, breathe);
      hands += Offset(0, breathe);
    case BatterPose.groundOff:
    case BatterPose.groundStraight:
    case BatterPose.groundLeg:
    case BatterPose.loftOff:
    case BatterPose.loftStraight:
    case BatterPose.loftLeg:
    case BatterPose.miss:
      final swing = Curves.easeInOutCubic.transform(progress);
      final (startAngle, finishAngle) = switch (pose) {
        BatterPose.groundOff => (-1.5, .18),
        BatterPose.groundStraight => (-1.45, .7),
        BatterPose.groundLeg => (-1.4, 1.18),
        BatterPose.loftOff => (-1.55, -.18),
        BatterPose.loftStraight => (-1.48, -.62),
        BatterPose.loftLeg => (-1.38, -1.02),
        BatterPose.miss => (-1.45, -.92),
        _ => (-1.4, .5),
      };
      batAngle = startAngle + (finishAngle - startAngle) * swing;
      final rotation = math.sin(swing * math.pi) * .08;
      hip += Offset(rotation, 0);
      shoulder += Offset(rotation * 1.35, -.025 * math.sin(swing * math.pi));
      head += Offset(rotation * .8, 0);
      frontKnee += Offset(.08 * swing, -.025 * swing);
      frontFoot += Offset(.1 * swing, 0);
      hands = shoulder + Offset(.13 + .13 * swing, .13 - .1 * swing);
      frontElbow = Offset.lerp(shoulder, hands, .48)! + const Offset(.08, -.04);
      backElbow =
          Offset.lerp(shoulder, hands, .42)! + const Offset(-.075, .025);
      if (pose == BatterPose.miss) {
        hands += const Offset(.03, -.1);
        head += const Offset(-.02, .025);
      }
    case BatterPose.bowled:
      final slump = Curves.easeInCubic.transform(progress);
      shoulder += Offset(.11 * slump, .13 * slump);
      head += Offset(.16 * slump, .17 * slump);
      hip += Offset(.04 * slump, 0);
      hands = Offset(.2, .55 + .17 * slump);
      frontElbow = Offset.lerp(shoulder, hands, .5)! + const Offset(.08, 0);
      backElbow = Offset.lerp(shoulder, hands, .5)! + const Offset(-.06, .04);
      batAngle = -.2 + .65 * slump;
    case BatterPose.running:
      final lean = .08;
      shoulder += Offset(lean, cycle * .012);
      head += Offset(lean * .7, cycle * .01);
      hip += Offset(lean * .45, -cycle.abs() * .018);
      frontKnee = hip + Offset(.17 * cycle, .18);
      frontFoot = frontKnee + Offset(.16 * cycle, .17);
      backKnee = hip - Offset(.17 * cycle, -.18);
      backFoot = backKnee - Offset(.16 * cycle, -.17);
      hands = shoulder + Offset(-.06 * cycle, .16);
      frontElbow = shoulder + Offset(.14 * cycle, .09);
      backElbow = shoulder - Offset(.14 * cycle, -.09);
      batAngle = 2.25 + .2 * cycle;
      batLength = .36;
    case BatterPose.slide:
      final slide = Curves.easeOutCubic.transform(progress);
      hip = Offset(-.03 + .18 * slide, .72);
      shoulder = Offset(.16 + .14 * slide, .61);
      head = Offset(.31 + .14 * slide, .56);
      frontKnee = const Offset(.12, .78);
      frontFoot = const Offset(.39, .87);
      backKnee = const Offset(-.17, .79);
      backFoot = const Offset(-.35, .86);
      hands = Offset(.43 + .17 * slide, .78);
      frontElbow = Offset.lerp(shoulder, hands, .45)! + const Offset(.02, -.07);
      backElbow = Offset.lerp(shoulder, hands, .5)! + const Offset(-.05, .06);
      batAngle = .04;
      batLength = .38;
  }
  final batTip =
      hands + Offset(math.cos(batAngle), math.sin(batAngle)) * batLength;
  return _BatterGeometry(
    hip: hip,
    shoulder: shoulder,
    head: head,
    frontKnee: frontKnee,
    frontFoot: frontFoot,
    backKnee: backKnee,
    backFoot: backFoot,
    frontElbow: frontElbow,
    backElbow: backElbow,
    hands: hands,
    batTip: batTip,
  );
}

class _BatterGeometry {
  const _BatterGeometry({
    required this.hip,
    required this.shoulder,
    required this.head,
    required this.frontKnee,
    required this.frontFoot,
    required this.backKnee,
    required this.backFoot,
    required this.frontElbow,
    required this.backElbow,
    required this.hands,
    required this.batTip,
  });

  final Offset hip;
  final Offset shoulder;
  final Offset head;
  final Offset frontKnee;
  final Offset frontFoot;
  final Offset backKnee;
  final Offset backFoot;
  final Offset frontElbow;
  final Offset backElbow;
  final Offset hands;
  final Offset batTip;
}

enum BowlerPose { ready, runUp, gather, release, followThrough }

class FinalOverBowlerRig extends StatelessWidget {
  const FinalOverBowlerRig({
    super.key,
    this.pose = BowlerPose.ready,
    this.progress = 0,
    this.facingRight = true,
  });

  final BowlerPose pose;
  final double progress;
  final bool facingRight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BowlerRigPainter(
        pose: pose,
        progress: progress,
        facingRight: facingRight,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class BowlerRigPainter extends CustomPainter {
  const BowlerRigPainter({
    this.pose = BowlerPose.ready,
    this.progress = 0,
    this.facingRight = true,
  });

  final BowlerPose pose;
  final double progress;
  final bool facingRight;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = math.min(size.width, size.height);
    final p = visualClamp01(progress);
    final cycle = math.sin(p * math.pi * 2);
    var hip = const Offset(0, .58);
    var shoulder = const Offset(.01, .34);
    var head = const Offset(.015, .17);
    var frontKnee = const Offset(.12, .73);
    var frontFoot = const Offset(.18, .9);
    var backKnee = const Offset(-.12, .73);
    var backFoot = const Offset(-.18, .9);
    var bowlingElbow = const Offset(.12, .42);
    var bowlingHand = const Offset(.18, .54);
    var otherElbow = const Offset(-.13, .43);
    var otherHand = const Offset(-.18, .55);
    var ballVisible = true;

    switch (pose) {
      case BowlerPose.ready:
        shoulder += Offset(0, math.sin(p * math.pi * 2) * .006);
      case BowlerPose.runUp:
        shoulder += const Offset(.075, 0);
        head += const Offset(.055, 0);
        hip += Offset(.04, -cycle.abs() * .018);
        frontKnee = hip + Offset(.19 * cycle, .17);
        frontFoot = frontKnee + Offset(.15 * cycle, .18);
        backKnee = hip - Offset(.19 * cycle, -.17);
        backFoot = backKnee - Offset(.15 * cycle, -.18);
        bowlingElbow = shoulder - Offset(.13 * cycle, -.1);
        bowlingHand = bowlingElbow - Offset(.11 * cycle, -.12);
        otherElbow = shoulder + Offset(.13 * cycle, .1);
        otherHand = otherElbow + Offset(.11 * cycle, .12);
      case BowlerPose.gather:
        final lift = Curves.easeOut.transform(p);
        shoulder += Offset(.04 * lift, -.04 * lift);
        head += Offset(.025 * lift, -.025 * lift);
        frontKnee = hip + Offset(.17, .12 - .12 * lift);
        frontFoot = frontKnee + Offset(.08, .18);
        backKnee = hip + Offset(-.11, .18);
        backFoot = backKnee + const Offset(-.08, .17);
        bowlingElbow = shoulder + Offset(-.1 - .06 * lift, -.04 - .11 * lift);
        bowlingHand = bowlingElbow + Offset(-.08, .11 - .2 * lift);
        otherElbow = shoulder + const Offset(.14, .08);
        otherHand = otherElbow + const Offset(.08, .1);
      case BowlerPose.release:
        final snap = Curves.easeInOutCubic.transform(p);
        hip += Offset(.05 * snap, 0);
        shoulder += Offset(.08 * snap, -.03 * math.sin(snap * math.pi));
        head += Offset(.05 * snap, 0);
        frontKnee = hip + const Offset(.16, .2);
        frontFoot = frontKnee + const Offset(.1, .16);
        backKnee = hip + const Offset(-.13, .2);
        backFoot = backKnee + const Offset(-.12, .12);
        final armAngle = -2.25 + 2.75 * snap;
        bowlingElbow =
            shoulder + Offset(math.cos(armAngle), math.sin(armAngle)) * .17;
        bowlingHand =
            bowlingElbow + Offset(math.cos(armAngle), math.sin(armAngle)) * .15;
        otherElbow = shoulder + const Offset(.16, .07);
        otherHand = otherElbow + const Offset(.07, .12);
        ballVisible = snap < .72;
      case BowlerPose.followThrough:
        final follow = Curves.easeOutCubic.transform(p);
        hip += Offset(.09 * follow, .015 * follow);
        shoulder += Offset(.14 * follow, .09 * follow);
        head += Offset(.12 * follow, .08 * follow);
        frontKnee = hip + const Offset(.16, .19);
        frontFoot = frontKnee + const Offset(.13, .15);
        backKnee = hip + Offset(-.1 + .12 * follow, .2);
        backFoot = backKnee + const Offset(-.05, .16);
        bowlingElbow = shoulder + Offset(.14, .08 + .09 * follow);
        bowlingHand = bowlingElbow + const Offset(.09, .13);
        otherElbow = shoulder + const Offset(-.12, .1);
        otherHand = otherElbow + const Offset(-.06, .13);
        ballVisible = false;
    }

    canvas.save();
    canvas.translate(size.width / 2, (size.height - unit) / 2);
    canvas.scale(facingRight ? unit : -unit, unit);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset((frontFoot.dx + backFoot.dx) / 2, .925),
        width: .45,
        height: .06,
      ),
      Paint()..color = FinalOverPalette.black.withValues(alpha: .4),
    );
    _drawLimb(canvas, hip, backKnee, backFoot, const Color(0xFF092C69), .075);
    _drawLimb(
      canvas,
      hip,
      frontKnee,
      frontFoot,
      FinalOverPalette.deepBlue,
      .082,
    );

    final torsoTopLeft = shoulder + const Offset(-.12, -.01);
    final torsoHipRight = hip + const Offset(.09, .025);
    final torsoHipLeft = hip + const Offset(-.09, .025);
    final torso = Path()
      ..moveTo(torsoTopLeft.dx, torsoTopLeft.dy)
      ..quadraticBezierTo(
        shoulder.dx,
        shoulder.dy - .05,
        shoulder.dx + .12,
        shoulder.dy,
      )
      ..lineTo(torsoHipRight.dx, torsoHipRight.dy)
      ..lineTo(torsoHipLeft.dx, torsoHipLeft.dy)
      ..close();
    canvas.drawPath(torso, Paint()..color = FinalOverPalette.deepBlue);
    final bowlerSash = <Offset>[
      shoulder + const Offset(-.09, .03),
      shoulder + const Offset(.1, .08),
      hip + const Offset(.075, 0),
      hip + const Offset(.01, -.035),
    ];
    canvas.drawPath(
      Path()..addPolygon(bowlerSash, true),
      Paint()..color = FinalOverPalette.cyan.withValues(alpha: .85),
    );
    _drawArm(canvas, shoulder, otherElbow, otherHand, false);
    _drawArm(canvas, shoulder, bowlingElbow, bowlingHand, true);
    canvas.drawCircle(head, .09, Paint()..color = const Color(0xFF754126));
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: .102),
      math.pi,
      math.pi,
      true,
      Paint()..color = FinalOverPalette.deepBlue,
    );
    canvas.drawLine(
      head + const Offset(-.045, -.085),
      head + const Offset(.12, -.065),
      Paint()
        ..color = FinalOverPalette.cyan
        ..strokeWidth = .025
        ..strokeCap = StrokeCap.round,
    );
    if (ballVisible) {
      canvas.drawCircle(
        bowlingHand + const Offset(.012, .005),
        .034,
        Paint()..color = FinalOverPalette.red,
      );
      canvas.drawArc(
        Rect.fromCircle(
          center: bowlingHand + const Offset(.012, .005),
          radius: .022,
        ),
        -.8,
        1.6,
        false,
        Paint()
          ..color = FinalOverPalette.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = .006,
      );
    }
    canvas.restore();
  }

  void _drawLimb(
    Canvas canvas,
    Offset start,
    Offset joint,
    Offset end,
    Color colour,
    double width,
  ) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(joint.dx, joint.dy)
      ..lineTo(end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = FinalOverPalette.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = width + .025
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      end,
      end + const Offset(.075, .005),
      Paint()
        ..color = FinalOverPalette.white
        ..strokeWidth = .038
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawArm(
    Canvas canvas,
    Offset shoulder,
    Offset elbow,
    Offset hand,
    bool foreground,
  ) {
    final path = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(hand.dx, hand.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = foreground
            ? FinalOverPalette.cyanDeep
            : FinalOverPalette.deepBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = foreground ? .058 : .052
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(hand, .029, Paint()..color = const Color(0xFF754126));
  }

  @override
  bool shouldRepaint(covariant BowlerRigPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.progress != progress ||
        oldDelegate.facingRight != facingRight;
  }
}

enum UmpireSignal { idle, four, six, out, safe }

class FinalOverUmpireRig extends StatelessWidget {
  const FinalOverUmpireRig({
    super.key,
    this.signal = UmpireSignal.idle,
    this.progress = 1,
  });

  final UmpireSignal signal;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: UmpireRigPainter(signal: signal, progress: progress),
      child: const SizedBox.expand(),
    );
  }
}

class UmpireRigPainter extends CustomPainter {
  const UmpireRigPainter({this.signal = UmpireSignal.idle, this.progress = 1});

  final UmpireSignal signal;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = math.min(size.width, size.height);
    final p = Curves.easeOutCubic.transform(visualClamp01(progress));
    final shoulder = const Offset(0, .36);
    var leftElbow = const Offset(-.12, .5);
    var leftHand = const Offset(-.11, .62);
    var rightElbow = const Offset(.12, .5);
    var rightHand = const Offset(.11, .62);
    switch (signal) {
      case UmpireSignal.idle:
        break;
      case UmpireSignal.four:
        rightElbow = Offset(.18 * p, .42 - .1 * p);
        rightHand = Offset(.3 * p, .32 - .08 * math.sin(p * math.pi * 2));
      case UmpireSignal.six:
        leftElbow = Offset(-.09, .43 - .2 * p);
        leftHand = Offset(-.08, .61 - .48 * p);
        rightElbow = Offset(.09, .43 - .2 * p);
        rightHand = Offset(.08, .61 - .48 * p);
      case UmpireSignal.out:
        rightElbow = Offset(.04, .42 - .18 * p);
        rightHand = Offset(.04, .6 - .48 * p);
      case UmpireSignal.safe:
        leftElbow = Offset(-.14 * p, .41);
        leftHand = Offset(-.33 * p, .4);
        rightElbow = Offset(.14 * p, .41);
        rightHand = Offset(.33 * p, .4);
    }

    canvas.save();
    canvas.translate(size.width / 2, (size.height - unit) / 2);
    canvas.scale(unit, unit);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, .92), width: .36, height: .055),
      Paint()..color = FinalOverPalette.black.withValues(alpha: .38),
    );
    final legPaint = Paint()
      ..color = FinalOverPalette.black
      ..strokeWidth = .07
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(-.055, .63), const Offset(-.09, .9), legPaint);
    canvas.drawLine(const Offset(.055, .63), const Offset(.09, .9), legPaint);
    final torso = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-.13, .32, .26, .36),
      const Radius.circular(.06),
    );
    canvas.drawRRect(torso, Paint()..color = FinalOverPalette.charcoal);
    canvas.drawRect(
      const Rect.fromLTWH(-.13, .5, .26, .055),
      Paint()..color = FinalOverPalette.white.withValues(alpha: .17),
    );
    _paintUmpireArm(canvas, shoulder, leftElbow, leftHand);
    _paintUmpireArm(canvas, shoulder, rightElbow, rightHand);
    canvas.drawCircle(
      const Offset(0, .2),
      .09,
      Paint()..color = const Color(0xFF8C5739),
    );
    canvas.drawArc(
      const Rect.fromLTWH(-.105, .09, .21, .18),
      math.pi,
      math.pi,
      true,
      Paint()..color = FinalOverPalette.white,
    );
    canvas.drawLine(
      const Offset(-.12, .16),
      const Offset(.12, .16),
      Paint()
        ..color = FinalOverPalette.charcoal
        ..strokeWidth = .025
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  void _paintUmpireArm(
    Canvas canvas,
    Offset shoulder,
    Offset elbow,
    Offset hand,
  ) {
    final path = Path()
      ..moveTo(shoulder.dx, shoulder.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(hand.dx, hand.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = FinalOverPalette.charcoal
        ..style = PaintingStyle.stroke
        ..strokeWidth = .065
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(hand, .028, Paint()..color = const Color(0xFF8C5739));
  }

  @override
  bool shouldRepaint(covariant UmpireRigPainter oldDelegate) {
    return oldDelegate.signal != signal || oldDelegate.progress != progress;
  }
}
