import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'final_over_palette.dart';

/// Responsive night-stadium backdrop with intentionally quiet top and bottom
/// zones so score HUDs and controls remain legible.
class StadiumBackdrop extends StatelessWidget {
  const StadiumBackdrop({
    super.key,
    this.animationProgress = 1,
    this.lightIntensity = 1,
    this.child,
  });

  final double animationProgress;
  final double lightIntensity;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StadiumBackdropPainter(
        animationProgress: animationProgress,
        lightIntensity: lightIntensity,
      ),
      child: child ?? const SizedBox.expand(),
    );
  }
}

class StadiumBackdropPainter extends CustomPainter {
  const StadiumBackdropPainter({
    this.animationProgress = 1,
    this.lightIntensity = 1,
  });

  final double animationProgress;
  final double lightIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final progress = Curves.easeOutCubic.transform(
      visualClamp01(animationProgress),
    );
    final intensity = visualClamp01(lightIntensity);
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF050812),
            FinalOverPalette.navy,
            Color(0xFF071C33),
            Color(0xFF0B2632),
          ],
          stops: <double>[0, .36, .69, 1],
        ).createShader(rect),
    );

    _paintAtmosphere(canvas, size, progress, intensity);
    _paintFloodlights(canvas, size, progress, intensity);
    _paintStands(canvas, size, progress);
    _paintOutfield(canvas, size);
    _paintSafeZoneShade(canvas, size);
  }

  void _paintAtmosphere(
    Canvas canvas,
    Size size,
    double progress,
    double intensity,
  ) {
    final glowRect = Rect.fromCircle(
      center: Offset(size.width * .5, size.height * .35),
      radius: size.width * .75,
    );
    canvas.drawCircle(
      Offset(size.width * .5, size.height * (.32 + .02 * (1 - progress))),
      size.width * .68,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            FinalOverPalette.deepBlue.withValues(alpha: .42 * intensity),
            FinalOverPalette.cyan.withValues(alpha: .08 * intensity),
            Colors.transparent,
          ],
          stops: const <double>[0, .52, 1],
        ).createShader(glowRect),
    );

    final starPaint = Paint()..color = FinalOverPalette.white;
    for (var i = 0; i < 24; i++) {
      final x = ((i * 47) % 101) / 101 * size.width;
      final y = (.045 + ((i * 31) % 41) / 100) * size.height;
      final twinkle = .18 + .28 * (1 + math.sin(i * 2.17 + progress * 5)) / 2;
      starPaint.color = FinalOverPalette.white.withValues(alpha: twinkle);
      canvas.drawCircle(Offset(x, y), i.isEven ? .7 : 1.05, starPaint);
    }
  }

  void _paintFloodlights(
    Canvas canvas,
    Size size,
    double progress,
    double intensity,
  ) {
    for (final left in <bool>[true, false]) {
      final sign = left ? 1.0 : -1.0;
      final mastX = left ? size.width * .08 : size.width * .92;
      final mastTop = size.height * .18;
      final mastBottom = size.height * .58;
      final revealBottom = mastTop + (mastBottom - mastTop) * progress;
      final mast = Paint()
        ..color = FinalOverPalette.charcoal.withValues(alpha: .92)
        ..strokeWidth = math.max(2, size.width * .008)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(mastX, revealBottom),
        Offset(mastX + sign * size.width * .025, mastTop),
        mast,
      );

      final headCenter = Offset(
        mastX + sign * size.width * .035,
        mastTop - size.height * .008,
      );
      final headRect = Rect.fromCenter(
        center: headCenter,
        width: size.width * .19,
        height: size.height * .035,
      );
      canvas.save();
      canvas.translate(headCenter.dx, headCenter.dy);
      canvas.rotate(sign * -.1);
      canvas.translate(-headCenter.dx, -headCenter.dy);
      canvas.drawRRect(
        RRect.fromRectAndRadius(headRect, const Radius.circular(4)),
        Paint()..color = FinalOverPalette.deepBlue,
      );
      for (var row = 0; row < 2; row++) {
        for (var column = 0; column < 6; column++) {
          final light = Offset(
            headRect.left + headRect.width * (.1 + column * .16),
            headRect.top + headRect.height * (.3 + row * .4),
          );
          final radius = math.max(1.4, size.width * .006);
          canvas.drawCircle(
            light,
            radius * 3.8,
            Paint()
              ..shader =
                  RadialGradient(
                    colors: <Color>[
                      FinalOverPalette.cyan.withValues(alpha: .34 * intensity),
                      Colors.transparent,
                    ],
                  ).createShader(
                    Rect.fromCircle(center: light, radius: radius * 4),
                  ),
          );
          canvas.drawCircle(
            light,
            radius,
            Paint()
              ..color = FinalOverPalette.white.withValues(
                alpha: (.48 + .52 * progress) * intensity,
              ),
          );
        }
      }
      canvas.restore();
    }
  }

  void _paintStands(Canvas canvas, Size size, double progress) {
    final horizon = size.height * .49;
    final stand = Path()
      ..moveTo(0, horizon * .86)
      ..quadraticBezierTo(
        size.width * .5,
        horizon * 1.18,
        size.width,
        horizon * .86,
      )
      ..lineTo(size.width, size.height * .7)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .82,
        0,
        size.height * .7,
      )
      ..close();
    canvas.drawPath(
      stand,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF122C48),
            Color(0xFF081827),
            FinalOverPalette.black,
          ],
        ).createShader(Offset.zero & size),
    );

    final railPaint = Paint()
      ..color = FinalOverPalette.cyan.withValues(alpha: .22 * progress)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width * .003);
    for (var row = 0; row < 4; row++) {
      final y = horizon + row * size.height * .047;
      final rail = Path()
        ..moveTo(0, y)
        ..quadraticBezierTo(
          size.width * .5,
          y + size.height * .065,
          size.width,
          y,
        );
      canvas.drawPath(rail, railPaint);
    }

    final crowdPaint = Paint();
    const crowdColours = <Color>[
      FinalOverPalette.cyan,
      FinalOverPalette.white,
      FinalOverPalette.yellow,
      FinalOverPalette.royalBlue,
    ];
    for (var i = 0; i < 96; i++) {
      final x = ((i * 73) % 997) / 997 * size.width;
      final arc = 1 - math.pow((x / size.width - .5) * 2, 2);
      final y =
          horizon +
          size.height * (.03 + ((i * 37) % 14) / 260) +
          arc * size.height * .04;
      crowdPaint.color = crowdColours[i % crowdColours.length].withValues(
        alpha: (.12 + (i % 3) * .06) * progress,
      );
      canvas.drawCircle(Offset(x, y), 1 + (i % 2) * .35, crowdPaint);
    }
  }

  void _paintOutfield(Canvas canvas, Size size) {
    final outfield = Path()
      ..moveTo(0, size.height * .67)
      ..quadraticBezierTo(
        size.width * .5,
        size.height * .78,
        size.width,
        size.height * .67,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      outfield,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF125A39), Color(0xFF092C27)],
        ).createShader(Offset.zero & size),
    );
  }

  void _paintSafeZoneShade(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            FinalOverPalette.black.withValues(alpha: .48),
            Colors.transparent,
            Colors.transparent,
            FinalOverPalette.black.withValues(alpha: .38),
          ],
          stops: const <double>[0, .18, .72, 1],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(covariant StadiumBackdropPainter oldDelegate) {
    return oldDelegate.animationProgress != animationProgress ||
        oldDelegate.lightIntensity != lightIntensity;
  }
}

/// Programmatic perspective pitch designed to sit over [StadiumBackdrop].
class PerspectivePitch extends StatelessWidget {
  const PerspectivePitch({
    super.key,
    this.revealProgress = 1,
    this.ballProgress = 0,
    this.showGuide = false,
  });

  final double revealProgress;
  final double ballProgress;
  final bool showGuide;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: PerspectivePitchPainter(
        revealProgress: revealProgress,
        ballProgress: ballProgress,
        showGuide: showGuide,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class PerspectivePitchPainter extends CustomPainter {
  const PerspectivePitchPainter({
    this.revealProgress = 1,
    this.ballProgress = 0,
    this.showGuide = false,
  });

  final double revealProgress;
  final double ballProgress;
  final bool showGuide;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final reveal = Curves.easeOutCubic.transform(visualClamp01(revealProgress));
    final topY = size.height * .2;
    final bottomY = size.height * (.96 + .04 * (1 - reveal));
    final pitch = Path()
      ..moveTo(size.width * .42, topY)
      ..lineTo(size.width * .58, topY)
      ..lineTo(size.width * .83, bottomY)
      ..lineTo(size.width * .17, bottomY)
      ..close();
    canvas.drawShadow(pitch, FinalOverPalette.black, 14, true);
    canvas.drawPath(
      pitch,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            FinalOverPalette.pitchBrown,
            FinalOverPalette.pitchLight,
            Color(0xFFC19454),
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.save();
    canvas.clipPath(pitch);
    final stripe = Paint()
      ..color = FinalOverPalette.white.withValues(alpha: .045);
    for (var i = 0; i < 9; i += 2) {
      final y0 = topY + (bottomY - topY) * i / 9;
      final y1 = topY + (bottomY - topY) * (i + 1) / 9;
      canvas.drawRect(Rect.fromLTRB(0, y0, size.width, y1), stripe);
    }
    canvas.restore();

    final line = Paint()
      ..color = FinalOverPalette.white.withValues(alpha: .92)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * .006)
      ..strokeCap = StrokeCap.square;
    _drawPerspectiveCrease(
      canvas,
      size,
      topY + size.height * .04,
      .38,
      .62,
      line,
    );
    _drawPerspectiveCrease(
      canvas,
      size,
      bottomY - size.height * .11,
      .23,
      .77,
      line,
    );

    if (showGuide) {
      final t = visualClamp01(ballProgress);
      final y = topY + (bottomY - topY) * t;
      final halfWidth = size.width * (.08 + .25 * t);
      final guidePaint = Paint()
        ..color = FinalOverPalette.cyan.withValues(alpha: .48)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.width * .5, y),
          width: halfWidth * 2,
          height: math.max(4, halfWidth * .18),
        ),
        guidePaint,
      );
    }
  }

  void _drawPerspectiveCrease(
    Canvas canvas,
    Size size,
    double y,
    double left,
    double right,
    Paint paint,
  ) {
    canvas.drawLine(
      Offset(size.width * left, y),
      Offset(size.width * right, y),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant PerspectivePitchPainter oldDelegate) {
    return oldDelegate.revealProgress != revealProgress ||
        oldDelegate.ballProgress != ballProgress ||
        oldDelegate.showGuide != showGuide;
  }
}

/// Square, top-down cricket field used during ball flight and running.
class TopDownField extends StatelessWidget {
  const TopDownField({
    super.key,
    this.rotation = 0,
    this.spotlight = 0,
    this.showFieldingRing = true,
  });

  final double rotation;
  final double spotlight;
  final bool showFieldingRing;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: TopDownFieldPainter(
          rotation: rotation,
          spotlight: spotlight,
          showFieldingRing: showFieldingRing,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class TopDownFieldPainter extends CustomPainter {
  const TopDownFieldPainter({
    this.rotation = 0,
    this.spotlight = 0,
    this.showFieldingRing = true,
  });

  final double rotation;
  final double spotlight;
  final bool showFieldingRing;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final square = Rect.fromCenter(center: center, width: side, height: side);
    canvas.drawRect(square, Paint()..color = FinalOverPalette.navy);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);
    final field = Rect.fromCircle(center: center, radius: side * .46);
    canvas.drawCircle(
      center,
      side * .47,
      Paint()..color = const Color(0xFF06151F),
    );
    canvas.drawCircle(
      center,
      side * .46,
      Paint()..color = FinalOverPalette.fieldDark,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(field));
    final stripePaint = Paint();
    const stripeCount = 12;
    for (var i = 0; i < stripeCount; i++) {
      stripePaint.color = i.isEven
          ? FinalOverPalette.fieldLight.withValues(alpha: .56)
          : FinalOverPalette.fieldDark.withValues(alpha: .24);
      canvas.drawRect(
        Rect.fromLTWH(
          field.left + field.width * i / stripeCount,
          field.top,
          field.width / stripeCount,
          field.height,
        ),
        stripePaint,
      );
    }
    final mowPaint = Paint()
      ..color = FinalOverPalette.white.withValues(alpha: .055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * .006;
    for (var ring = 1; ring <= 4; ring++) {
      canvas.drawCircle(center, side * (.1 + ring * .075), mowPaint);
    }
    canvas.restore();

    final boundary = Paint()
      ..color = FinalOverPalette.cyan.withValues(alpha: .82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2.2, side * .009);
    canvas.drawCircle(center, side * .445, boundary);
    canvas.drawCircle(
      center,
      side * .445,
      Paint()
        ..color = FinalOverPalette.cyan.withValues(alpha: .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * .025,
    );

    final pitchRect = Rect.fromCenter(
      center: center,
      width: side * .13,
      height: side * .49,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pitchRect, Radius.circular(side * .012)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFFA9783E),
            FinalOverPalette.pitchLight,
            Color(0xFFA9783E),
          ],
        ).createShader(pitchRect),
    );
    final creasePaint = Paint()
      ..color = FinalOverPalette.white
      ..strokeWidth = math.max(1.2, side * .004)
      ..strokeCap = StrokeCap.square;
    for (final dy in <double>[-.185, .185]) {
      final y = center.dy + side * dy;
      canvas.drawLine(
        Offset(center.dx - side * .085, y),
        Offset(center.dx + side * .085, y),
        creasePaint,
      );
      canvas.drawLine(
        Offset(center.dx - side * .052, y - side * .025),
        Offset(center.dx - side * .052, y + side * .025),
        creasePaint,
      );
      canvas.drawLine(
        Offset(center.dx + side * .052, y - side * .025),
        Offset(center.dx + side * .052, y + side * .025),
        creasePaint,
      );
    }

    if (showFieldingRing) {
      canvas.drawCircle(
        center,
        side * .27,
        Paint()
          ..color = FinalOverPalette.white.withValues(alpha: .13)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    canvas.restore();

    final focus = visualClamp01(spotlight);
    if (focus > 0) {
      canvas.drawRect(
        square,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              Colors.transparent,
              FinalOverPalette.black.withValues(alpha: focus * .62),
            ],
            stops: const <double>[.35, 1],
          ).createShader(square),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TopDownFieldPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.spotlight != spotlight ||
        oldDelegate.showFieldingRing != showFieldingRing;
  }
}
