import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'artifacts.dart';
import 'final_over_palette.dart';

/// Deterministic camera treatment driven by simulation progress.
class VisualShake extends StatelessWidget {
  const VisualShake({
    super.key,
    required this.child,
    this.progress = 0,
    this.intensity = 1,
    this.zoom = 0,
    this.seed = 0,
  });

  final Widget child;
  final double progress;
  final double intensity;
  final double zoom;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final p = visualClamp01(progress);
    final decay = (1 - p) * visualClamp01(intensity);
    final phase = seed * 1.731 + p * math.pi * 10;
    final offset =
        Offset(math.sin(phase) * 7, math.cos(phase * 1.37) * 5) * decay;
    return Transform.translate(
      offset: offset,
      child: Transform.scale(
        scale: 1 + visualClamp01(zoom) * Curves.easeInOut.transform(p) * .075,
        child: child,
      ),
    );
  }
}

class ImpactEffect extends StatelessWidget {
  const ImpactEffect({
    super.key,
    this.progress = 0,
    this.intensity = 1,
    this.color = FinalOverPalette.cyan,
    this.seed = 0,
  });

  final double progress;
  final double intensity;
  final Color color;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ImpactEffectPainter(
        progress: progress,
        intensity: intensity,
        color: color,
        seed: seed,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class ImpactEffectPainter extends CustomPainter {
  const ImpactEffectPainter({
    this.progress = 0,
    this.intensity = 1,
    this.color = FinalOverPalette.cyan,
    this.seed = 0,
  });

  final double progress;
  final double intensity;
  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = visualClamp01(progress);
    final strength = visualClamp01(intensity);
    final center = Offset(size.width / 2, size.height / 2);
    final unit = math.min(size.width, size.height);
    final fade = (1 - p) * strength;
    if (fade <= 0) return;
    final glowRadius = unit * (.05 + .24 * Curves.easeOut.transform(p));
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            FinalOverPalette.white.withValues(alpha: .82 * fade),
            color.withValues(alpha: .48 * fade),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
    );
    canvas.drawCircle(
      center,
      unit * (.03 + .16 * p),
      Paint()
        ..color = color.withValues(alpha: .75 * fade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, unit * .014 * fade),
    );
    for (var i = 0; i < 14; i++) {
      final angle = seed * .73 + i * math.pi * 2 / 14 + math.sin(i * 2.1) * .12;
      final inner = unit * (.035 + .05 * p);
      final outer =
          unit * (.08 + (.21 + (i % 4) * .018) * Curves.easeOut.transform(p));
      final a = center + Offset(math.cos(angle), math.sin(angle)) * inner;
      final b = center + Offset(math.cos(angle), math.sin(angle)) * outer;
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = (i.isEven ? color : FinalOverPalette.yellow).withValues(
            alpha: fade,
          )
          ..strokeWidth = math.max(1, unit * (i.isEven ? .012 : .007) * fade)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ImpactEffectPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity ||
        oldDelegate.color != color ||
        oldDelegate.seed != seed;
  }
}

enum BoundaryEffectKind { four, six }

class BoundaryPulse extends StatelessWidget {
  const BoundaryPulse({
    super.key,
    required this.kind,
    this.progress = 0,
    this.origin = const Offset(.5, .5),
  });

  final BoundaryEffectKind kind;
  final double progress;
  final Offset origin;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: BoundaryPulsePainter(
        kind: kind,
        progress: progress,
        origin: origin,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class BoundaryPulsePainter extends CustomPainter {
  const BoundaryPulsePainter({
    required this.kind,
    this.progress = 0,
    this.origin = const Offset(.5, .5),
  });

  final BoundaryEffectKind kind;
  final double progress;
  final Offset origin;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = visualClamp01(progress);
    final center = Offset(origin.dx * size.width, origin.dy * size.height);
    final unit = math.min(size.width, size.height);
    final color = kind == BoundaryEffectKind.six
        ? FinalOverPalette.yellow
        : FinalOverPalette.cyan;
    for (var i = 0; i < 3; i++) {
      final local = (p - i * .11).clamp(0.0, 1.0).toDouble();
      if (local <= 0) continue;
      final radius = unit * (.08 + .62 * Curves.easeOutCubic.transform(local));
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = color.withValues(alpha: (1 - local) * (.65 - i * .12))
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, unit * (.018 - i * .004)),
      );
    }
    final rayFade = math.sin(p * math.pi);
    for (var i = 0; i < (kind == BoundaryEffectKind.six ? 18 : 12); i++) {
      final angle =
          i * math.pi * 2 / (kind == BoundaryEffectKind.six ? 18 : 12);
      final start =
          center + Offset(math.cos(angle), math.sin(angle)) * unit * .12;
      final end =
          center +
          Offset(math.cos(angle), math.sin(angle)) * unit * (.2 + .32 * p);
      canvas.drawLine(
        start,
        end,
        Paint()
          ..color = color.withValues(alpha: rayFade * .44)
          ..strokeWidth = math.max(1, unit * .006)
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BoundaryPulsePainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.progress != progress ||
        oldDelegate.origin != origin;
  }
}

class WicketBurst extends StatelessWidget {
  const WicketBurst({super.key, this.progress = 0, this.seed = 0});

  final double progress;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        StumpsVisual(
          broken: progress > .08,
          progress: Curves.easeOut.transform(visualClamp01(progress)),
          glow: 1 - visualClamp01(progress),
        ),
        CustomPaint(
          painter: WicketBurstPainter(progress: progress, seed: seed),
          child: const SizedBox.expand(),
        ),
      ],
    );
  }
}

class WicketBurstPainter extends CustomPainter {
  const WicketBurstPainter({this.progress = 0, this.seed = 0});

  final double progress;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = visualClamp01(progress);
    final center = Offset(size.width / 2, size.height * .54);
    final unit = math.min(size.width, size.height);
    for (var i = 0; i < 16; i++) {
      final angle = -math.pi * .9 + i * math.pi * 1.8 / 15 + seed * .09;
      final speed = .2 + (i % 5) * .027;
      final distance = unit * speed * Curves.easeOutCubic.transform(p);
      final gravity = unit * .18 * p * p;
      final point =
          center +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance + gravity,
          );
      final radius = unit * (.008 + (i % 3) * .003) * (1 - p * .4);
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color =
              (i.isEven ? FinalOverPalette.red : FinalOverPalette.pitchLight)
                  .withValues(alpha: 1 - p),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WicketBurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.seed != seed;
  }
}

class CatchRing extends StatelessWidget {
  const CatchRing({
    super.key,
    this.progress = 0,
    this.success = false,
    this.drop = false,
  });

  final double progress;
  final bool success;
  final bool drop;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CatchRingPainter(
        progress: progress,
        success: success,
        drop: drop,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class CatchRingPainter extends CustomPainter {
  const CatchRingPainter({
    this.progress = 0,
    this.success = false,
    this.drop = false,
  });

  final double progress;
  final bool success;
  final bool drop;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = visualClamp01(progress);
    final center = Offset(size.width / 2, size.height / 2);
    final unit = math.min(size.width, size.height);
    final targetRadius = unit * .28;
    final approach = success ? (1 - p) : p;
    final radius = targetRadius * (.55 + .72 * approach);
    final color = drop
        ? FinalOverPalette.red
        : success
        ? FinalOverPalette.green
        : FinalOverPalette.yellow;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: .18 + .42 * (1 - p))
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: .9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, unit * .025),
    );
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final a =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (radius + unit * .025);
      final b =
          center +
          Offset(math.cos(angle), math.sin(angle)) * (radius + unit * .075);
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = color.withValues(alpha: .62)
          ..strokeWidth = math.max(1, unit * .012)
          ..strokeCap = StrokeCap.round,
      );
    }
    if (success && p > .45) {
      final reveal = ((p - .45) / .55).clamp(0.0, 1.0).toDouble();
      final check = Path()
        ..moveTo(center.dx - unit * .11, center.dy)
        ..lineTo(center.dx - unit * .025, center.dy + unit * .09)
        ..lineTo(center.dx + unit * .14, center.dy - unit * .11);
      final metric = check.computeMetrics().first;
      canvas.drawPath(
        metric.extractPath(0, metric.length * reveal),
        Paint()
          ..color = FinalOverPalette.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(2, unit * .035)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CatchRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.success != success ||
        oldDelegate.drop != drop;
  }
}

enum ResultCalloutVisual {
  out,
  safe,
  four,
  six,
  perfect,
  freeHit,
  victory,
  defeat,
}

class ResultCallout extends StatelessWidget {
  const ResultCallout({
    super.key,
    required this.callout,
    this.progress = 1,
    this.subtitle,
  });

  final ResultCalloutVisual callout;
  final double progress;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ResultCalloutPainter(
        callout: callout,
        progress: progress,
        subtitle: subtitle,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class ResultCalloutPainter extends CustomPainter {
  const ResultCalloutPainter({
    required this.callout,
    this.progress = 1,
    this.subtitle,
  });

  final ResultCalloutVisual callout;
  final double progress;
  final String? subtitle;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = Curves.easeOutBack.transform(visualClamp01(progress));
    if (p <= 0) return;
    final (label, color) = switch (callout) {
      ResultCalloutVisual.out => ('OUT', FinalOverPalette.red),
      ResultCalloutVisual.safe => ('SAFE', FinalOverPalette.green),
      ResultCalloutVisual.four => ('FOUR!', FinalOverPalette.cyan),
      ResultCalloutVisual.six => ('SIX!', FinalOverPalette.yellow),
      ResultCalloutVisual.perfect => ('PERFECT', FinalOverPalette.cyan),
      ResultCalloutVisual.freeHit => ('FREE HIT', FinalOverPalette.yellow),
      ResultCalloutVisual.victory => ('CHASED!', FinalOverPalette.green),
      ResultCalloutVisual.defeat => ('SO CLOSE', FinalOverPalette.red),
    };
    final center = Offset(size.width / 2, size.height / 2);
    final boxWidth =
        math.min(size.width * .9, math.max(120, size.height * 3.1)) * p;
    final boxHeight =
        math.min(size.height * .72, math.max(52, size.width * .22)) * p;
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: boxWidth, height: boxHeight),
      Radius.circular(boxHeight * .24),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..color = color.withValues(alpha: .23)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, boxHeight * .2),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..shader = LinearGradient(
          colors: <Color>[
            FinalOverPalette.navy.withValues(alpha: .95),
            Color.lerp(
              FinalOverPalette.deepBlue,
              color,
              .18,
            )!.withValues(alpha: .96),
            FinalOverPalette.navy.withValues(alpha: .95),
          ],
        ).createShader(box.outerRect),
    );
    canvas.drawRRect(
      box,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, boxHeight * .045),
    );
    final title = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: callout == ResultCalloutVisual.six
              ? FinalOverPalette.navy
              : FinalOverPalette.white,
          backgroundColor: callout == ResultCalloutVisual.six
              ? FinalOverPalette.yellow.withValues(alpha: .94)
              : null,
          fontSize: math.min(boxHeight * .47, boxWidth * .18),
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: math.min(5, boxWidth * .02),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: boxWidth * .9);
    final subtitlePainter = subtitle == null
        ? null
        : (TextPainter(
            text: TextSpan(
              text: subtitle!.toUpperCase(),
              style: TextStyle(
                color: FinalOverPalette.white.withValues(alpha: .68),
                fontSize: math.max(8, boxHeight * .14),
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          )..layout(maxWidth: boxWidth * .88));
    final contentHeight =
        title.height +
        (subtitlePainter == null
            ? 0
            : subtitlePainter.height + boxHeight * .07);
    final top = center.dy - contentHeight / 2;
    title.paint(canvas, Offset(center.dx - title.width / 2, top));
    subtitlePainter?.paint(
      canvas,
      Offset(
        center.dx - subtitlePainter.width / 2,
        top + title.height + boxHeight * .07,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant ResultCalloutPainter oldDelegate) {
    return oldDelegate.callout != callout ||
        oldDelegate.progress != progress ||
        oldDelegate.subtitle != subtitle;
  }
}

/// Darkens the edges and adds the cyan/yellow last-ball pressure treatment.
class FinalBallVignette extends StatelessWidget {
  const FinalBallVignette({super.key, this.intensity = 1, this.pulse = 0});

  final double intensity;
  final double pulse;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: FinalBallVignettePainter(intensity: intensity, pulse: pulse),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class FinalBallVignettePainter extends CustomPainter {
  const FinalBallVignettePainter({this.intensity = 1, this.pulse = 0});

  final double intensity;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final amount = visualClamp01(intensity);
    final beat = (1 + math.sin(pulse * math.pi * 2)) / 2;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          radius: .76,
          colors: <Color>[
            Colors.transparent,
            FinalOverPalette.navy.withValues(
              alpha: (.42 + .18 * beat) * amount,
            ),
            FinalOverPalette.black.withValues(alpha: .88 * amount),
          ],
          stops: const <double>[.42, .78, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect.deflate(math.max(2, size.shortestSide * .015)),
      Paint()
        ..color = Color.lerp(
          FinalOverPalette.cyan,
          FinalOverPalette.yellow,
          beat,
        )!.withValues(alpha: (.18 + .2 * beat) * amount)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, size.shortestSide * (.008 + .005 * beat)),
    );
  }

  @override
  bool shouldRepaint(covariant FinalBallVignettePainter oldDelegate) {
    return oldDelegate.intensity != intensity || oldDelegate.pulse != pulse;
  }
}
