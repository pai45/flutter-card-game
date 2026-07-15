import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'final_over_palette.dart';

/// Original Final Over lockup: a sixth-ball dial, wicket notch and fast-ball
/// seam form the emblem, paired with a custom stacked word treatment.
class FinalOverWordmark extends StatelessWidget {
  const FinalOverWordmark({
    super.key,
    this.progress = 1,
    this.glow = 1,
    this.compact = false,
    this.showTagline = true,
  });

  final double progress;
  final double glow;
  final bool compact;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FinalOverWordmarkPainter(
        progress: progress,
        glow: glow,
        compact: compact,
        showTagline: showTagline,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class FinalOverBrandMark extends StatelessWidget {
  const FinalOverBrandMark({super.key, this.progress = 1, this.glow = 1});

  final double progress;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FinalOverBrandMarkPainter(progress: progress, glow: glow),
      child: const SizedBox.expand(),
    );
  }
}

class FinalOverBrandMarkPainter extends CustomPainter {
  const FinalOverBrandMarkPainter({this.progress = 1, this.glow = 1});

  final double progress;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = Curves.easeOutBack.transform(visualClamp01(progress));
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * .39 * p;
    if (radius <= 0) return;
    _paintBrandMark(canvas, center, radius, visualClamp01(glow));
  }

  @override
  bool shouldRepaint(covariant FinalOverBrandMarkPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.glow != glow;
  }
}

class FinalOverWordmarkPainter extends CustomPainter {
  const FinalOverWordmarkPainter({
    this.progress = 1,
    this.glow = 1,
    this.compact = false,
    this.showTagline = true,
  });

  final double progress;
  final double glow;
  final bool compact;
  final bool showTagline;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rawProgress = visualClamp01(progress);
    final emblemProgress = Curves.easeOutBack.transform(
      (rawProgress / .62).clamp(0.0, 1.0),
    );
    final textProgress = Curves.easeOutCubic.transform(
      ((rawProgress - .22) / .78).clamp(0.0, 1.0),
    );
    final horizontal = compact || size.width > size.height * 2.15;
    final radius = horizontal
        ? math.min(size.height * .36, size.width * .15)
        : math.min(size.width * .2, size.height * .15);
    final emblemCenter = horizontal
        ? Offset(size.width * .18, size.height * .5)
        : Offset(size.width * .5, size.height * .26);
    _paintBrandMark(
      canvas,
      emblemCenter,
      radius * emblemProgress,
      visualClamp01(glow) * rawProgress,
    );

    final textArea = horizontal
        ? Rect.fromLTWH(size.width * .34, 0, size.width * .62, size.height)
        : Rect.fromLTWH(0, size.height * .43, size.width, size.height * .55);
    _paintWordmarkText(canvas, textArea, textProgress, horizontal);
  }

  void _paintWordmarkText(
    Canvas canvas,
    Rect area,
    double textProgress,
    bool horizontal,
  ) {
    if (textProgress <= 0) return;
    final titleSize = math.min(
      horizontal ? area.height * .35 : area.width * .17,
      horizontal ? area.width * .16 : area.height * .34,
    );
    final lineOne = TextPainter(
      text: TextSpan(
        text: 'FINAL',
        style: TextStyle(
          color: FinalOverPalette.white.withValues(alpha: textProgress),
          fontSize: titleSize * .63,
          fontWeight: FontWeight.w800,
          fontStyle: FontStyle.italic,
          letterSpacing: titleSize * .12,
          height: .88,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final lineTwo = TextPainter(
      text: TextSpan(
        text: 'OVER',
        style: TextStyle(
          foreground: Paint()
            ..shader = const LinearGradient(
              colors: <Color>[
                FinalOverPalette.cyan,
                FinalOverPalette.white,
                FinalOverPalette.cyan,
              ],
            ).createShader(area),
          fontSize: titleSize,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: titleSize * .025,
          height: .86,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    final stackHeight = lineOne.height + lineTwo.height * .84;
    final top = area.center.dy - stackHeight / 2;
    final leftOne =
        area.center.dx -
        lineOne.width / 2 -
        area.width * .01 * (1 - textProgress);
    final leftTwo =
        area.center.dx -
        lineTwo.width / 2 +
        area.width * .01 * (1 - textProgress);
    lineOne.paint(canvas, Offset(leftOne, top));
    lineTwo.paint(canvas, Offset(leftTwo, top + lineOne.height * .8));

    final underlineY = top + stackHeight + titleSize * .08;
    final underlineHalf =
        math.min(lineTwo.width * .44, area.width * .35) * textProgress;
    canvas.drawLine(
      Offset(area.center.dx - underlineHalf, underlineY),
      Offset(area.center.dx + underlineHalf, underlineY),
      Paint()
        ..shader =
            const LinearGradient(
              colors: <Color>[
                Colors.transparent,
                FinalOverPalette.cyan,
                FinalOverPalette.yellow,
                Colors.transparent,
              ],
            ).createShader(
              Rect.fromCenter(
                center: Offset(area.center.dx, underlineY),
                width: underlineHalf * 2,
                height: 3,
              ),
            )
        ..strokeWidth = math.max(1.5, titleSize * .04)
        ..strokeCap = StrokeCap.round,
    );
    if (showTagline && area.height > 50) {
      final tagline = TextPainter(
        text: TextSpan(
          text: 'SIX BALLS. ONE MOMENT.',
          style: TextStyle(
            color: FinalOverPalette.white.withValues(alpha: .58 * textProgress),
            fontSize: math.max(7, titleSize * .17),
            fontWeight: FontWeight.w700,
            letterSpacing: math.max(.5, titleSize * .025),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: area.width * .95);
      tagline.paint(
        canvas,
        Offset(
          area.center.dx - tagline.width / 2,
          underlineY + titleSize * .16,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant FinalOverWordmarkPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.glow != glow ||
        oldDelegate.compact != compact ||
        oldDelegate.showTagline != showTagline;
  }
}

void _paintBrandMark(Canvas canvas, Offset center, double radius, double glow) {
  if (radius <= 0) return;
  if (glow > 0) {
    canvas.drawCircle(
      center,
      radius * 1.45,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            FinalOverPalette.cyan.withValues(alpha: .3 * glow),
            FinalOverPalette.deepBlue.withValues(alpha: .16 * glow),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 1.45)),
    );
  }
  canvas.drawCircle(
    center,
    radius * 1.05,
    Paint()
      ..color = FinalOverPalette.black.withValues(alpha: .45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .16),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-.35, -.4),
        colors: <Color>[
          Color(0xFF164A85),
          FinalOverPalette.deepBlue,
          FinalOverPalette.navy,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius)),
  );
  canvas.drawCircle(
    center,
    radius,
    Paint()
      ..color = FinalOverPalette.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, radius * .075),
  );

  // Six dial markers: the final marker is the live yellow moment.
  for (var i = 0; i < 6; i++) {
    final angle = -math.pi * .88 + i * math.pi * .352;
    final marker =
        center + Offset(math.cos(angle), math.sin(angle)) * radius * .78;
    canvas.drawCircle(
      marker,
      radius * (i == 5 ? .085 : .048),
      Paint()
        ..color = i == 5
            ? FinalOverPalette.yellow
            : FinalOverPalette.cyan.withValues(alpha: .72),
    );
  }

  // A fast ball cutting through an angular F/O monogram.
  final monogram = Path()
    ..moveTo(center.dx - radius * .43, center.dy + radius * .38)
    ..lineTo(center.dx - radius * .43, center.dy - radius * .42)
    ..lineTo(center.dx + radius * .04, center.dy - radius * .42)
    ..lineTo(center.dx + radius * .04, center.dy - radius * .21)
    ..lineTo(center.dx - radius * .18, center.dy - radius * .21)
    ..lineTo(center.dx - radius * .18, center.dy + radius * .38)
    ..close();
  canvas.drawPath(monogram, Paint()..color = FinalOverPalette.white);
  canvas.drawCircle(
    center + Offset(radius * .25, radius * .06),
    radius * .28,
    Paint()
      ..color = FinalOverPalette.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * .13,
  );
  final ballCenter = center + Offset(radius * .23, -radius * .38);
  canvas.drawLine(
    ballCenter - Offset(radius * .58, radius * .2),
    ballCenter - Offset(radius * .14, radius * .05),
    Paint()
      ..color = FinalOverPalette.cyan.withValues(alpha: .72)
      ..strokeWidth = radius * .07
      ..strokeCap = StrokeCap.round,
  );
  canvas.drawCircle(
    ballCenter,
    radius * .15,
    Paint()..color = FinalOverPalette.red,
  );
  canvas.drawArc(
    Rect.fromCircle(center: ballCenter, radius: radius * .1),
    -.7,
    1.4,
    false,
    Paint()
      ..color = FinalOverPalette.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * .025,
  );

  // Wicket notch grounds the circular badge in cricket without copying a
  // traditional crest silhouette.
  final wicketPaint = Paint()
    ..color = FinalOverPalette.pitchLight
    ..strokeWidth = radius * .055
    ..strokeCap = StrokeCap.round;
  for (var i = -1; i <= 1; i++) {
    canvas.drawLine(
      center + Offset(i * radius * .1, radius * .5),
      center + Offset(i * radius * .1, radius * .78),
      wicketPaint,
    );
  }
  canvas.drawLine(
    center + Offset(-radius * .13, radius * .49),
    center + Offset(radius * .13, radius * .49),
    wicketPaint,
  );
}
