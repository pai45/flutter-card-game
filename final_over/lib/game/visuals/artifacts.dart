import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'final_over_palette.dart';

class CricketBallIcon extends StatelessWidget {
  const CricketBallIcon({
    super.key,
    this.rotation = 0,
    this.glow = 0,
    this.color = FinalOverPalette.red,
  });

  final double rotation;
  final double glow;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CricketBallPainter(rotation: rotation, glow: glow, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class CricketBallPainter extends CustomPainter {
  const CricketBallPainter({
    this.rotation = 0,
    this.glow = 0,
    this.color = FinalOverPalette.red,
  });

  final double rotation;
  final double glow;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = math.min(size.width, size.height) * .42;
    final center = Offset(size.width / 2, size.height / 2);
    final glowAmount = visualClamp01(glow);
    if (glowAmount > 0) {
      canvas.drawCircle(
        center,
        radius * (1.35 + .15 * glowAmount),
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              FinalOverPalette.cyan.withValues(alpha: .36 * glowAmount),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 1.5)),
      );
    }
    canvas.drawCircle(
      center + Offset(0, radius * .12),
      radius,
      Paint()
        ..color = FinalOverPalette.black.withValues(alpha: .32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * .18),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.4),
          radius: .95,
          colors: <Color>[
            Color.lerp(color, FinalOverPalette.white, .26)!,
            color,
            Color.lerp(color, FinalOverPalette.black, .44)!,
          ],
          stops: const <double>[0, .48, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    final seam = Paint()
      ..color = FinalOverPalette.white.withValues(alpha: .95)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, radius * .085)
      ..strokeCap = StrokeCap.round;
    final seamRect = Rect.fromCenter(
      center: Offset.zero,
      width: radius * .9,
      height: radius * 1.65,
    );
    canvas.drawArc(seamRect, -.72, 1.44, false, seam);
    for (var i = -3; i <= 3; i++) {
      final t = i / 4;
      final y = t * radius * .7;
      final x = math.sqrt(math.max(0, 1 - t * t)) * radius * .36;
      canvas.drawLine(
        Offset(x - radius * .11, y - radius * .055),
        Offset(x + radius * .055, y + radius * .045),
        Paint()
          ..color = FinalOverPalette.white.withValues(alpha: .78)
          ..strokeWidth = math.max(.7, radius * .04)
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
    canvas.drawCircle(
      center - Offset(radius * .28, radius * .3),
      radius * .13,
      Paint()..color = FinalOverPalette.white.withValues(alpha: .32),
    );
  }

  @override
  bool shouldRepaint(covariant CricketBallPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.glow != glow ||
        oldDelegate.color != color;
  }
}

class CricketBatIcon extends StatelessWidget {
  const CricketBatIcon({
    super.key,
    this.rotation = 0,
    this.highlighted = false,
  });

  final double rotation;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: CricketBatPainter(rotation: rotation, highlighted: highlighted),
      child: const SizedBox.expand(),
    );
  }
}

class CricketBatPainter extends CustomPainter {
  const CricketBatPainter({this.rotation = 0, this.highlighted = false});

  final double rotation;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation - .65);
    canvas.scale(unit, unit);
    if (highlighted) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-.095, -.42, .19, .84),
          const Radius.circular(.09),
        ),
        Paint()
          ..color = FinalOverPalette.cyan.withValues(alpha: .28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .06),
      );
    }
    final blade = Path()
      ..moveTo(-.105, .38)
      ..quadraticBezierTo(-.13, .18, -.09, -.12)
      ..lineTo(-.04, -.22)
      ..lineTo(.04, -.22)
      ..lineTo(.09, -.12)
      ..quadraticBezierTo(.13, .18, .105, .38)
      ..quadraticBezierTo(0, .45, -.105, .38)
      ..close();
    canvas.drawShadow(blade, FinalOverPalette.black, .05, true);
    canvas.drawPath(
      blade,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: <Color>[
            Color(0xFF9B6934),
            FinalOverPalette.pitchLight,
            FinalOverPalette.white,
          ],
        ).createShader(const Rect.fromLTWH(-.13, -.22, .26, .67)),
    );
    canvas.drawLine(
      const Offset(0, -.2),
      const Offset(0, -.43),
      Paint()
        ..color = FinalOverPalette.orange
        ..strokeWidth = .052
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      const Offset(-.055, -.03),
      const Offset(.055, -.03),
      Paint()
        ..color = FinalOverPalette.deepBlue.withValues(alpha: .68)
        ..strokeWidth = .025,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CricketBatPainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.highlighted != highlighted;
  }
}

class StumpsVisual extends StatelessWidget {
  const StumpsVisual({
    super.key,
    this.broken = false,
    this.progress = 1,
    this.glow = 0,
  });

  final bool broken;
  final double progress;
  final double glow;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StumpsPainter(broken: broken, progress: progress, glow: glow),
      child: const SizedBox.expand(),
    );
  }
}

class StumpsPainter extends CustomPainter {
  const StumpsPainter({this.broken = false, this.progress = 1, this.glow = 0});

  final bool broken;
  final double progress;
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final unit = math.min(size.width, size.height);
    final p = Curves.easeOutBack.transform(visualClamp01(progress));
    final center = Offset(size.width / 2, size.height * .55);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(unit, unit);
    if (glow > 0) {
      canvas.drawOval(
        const Rect.fromLTWH(-.28, -.48, .56, 1.02),
        Paint()
          ..color = FinalOverPalette.red.withValues(
            alpha: .22 * visualClamp01(glow),
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, .08),
      );
    }
    final stumpPaint = Paint()
      ..shader = const LinearGradient(
        colors: <Color>[
          Color(0xFF9A6431),
          FinalOverPalette.pitchLight,
          FinalOverPalette.white,
        ],
      ).createShader(const Rect.fromLTWH(-.2, -.4, .4, .8))
      ..strokeWidth = .07
      ..strokeCap = StrokeCap.round;
    for (var i = -1; i <= 1; i++) {
      final x = i * .105;
      final angle = broken ? i * .18 * p + (i == 0 ? -.14 * p : 0) : 0.0;
      canvas.save();
      canvas.translate(x, .38);
      canvas.rotate(angle);
      canvas.drawLine(const Offset(0, 0), const Offset(0, -.68), stumpPaint);
      canvas.restore();
    }
    for (var i = 0; i < 2; i++) {
      final startX = -.105 + i * .105;
      final kick = broken ? p : 0.0;
      final bailCenter = Offset(
        startX + .052 + (i == 0 ? -.15 : .16) * kick,
        -.325 - (.16 + i * .06) * kick,
      );
      canvas.save();
      canvas.translate(bailCenter.dx, bailCenter.dy);
      canvas.rotate((i == 0 ? -.9 : .75) * kick);
      canvas.drawLine(
        const Offset(-.062, 0),
        const Offset(.062, 0),
        Paint()
          ..color = FinalOverPalette.pitchLight
          ..strokeWidth = .032
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StumpsPainter oldDelegate) {
    return oldDelegate.broken != broken ||
        oldDelegate.progress != progress ||
        oldDelegate.glow != glow;
  }
}

enum FielderVisualState {
  idle,
  tracking,
  catching,
  pickup,
  throwing,
  backingUp,
}

class FielderDot extends StatelessWidget {
  const FielderDot({
    super.key,
    this.state = FielderVisualState.idle,
    this.progress = 0,
    this.facingAngle = 0,
    this.isPrimary = false,
    this.jerseyColor = FinalOverPalette.deepBlue,
  });

  final FielderVisualState state;
  final double progress;
  final double facingAngle;
  final bool isPrimary;
  final Color jerseyColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: FielderDotPainter(
        state: state,
        progress: progress,
        facingAngle: facingAngle,
        isPrimary: isPrimary,
        jerseyColor: jerseyColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class FielderDotPainter extends CustomPainter {
  const FielderDotPainter({
    this.state = FielderVisualState.idle,
    this.progress = 0,
    this.facingAngle = 0,
    this.isPrimary = false,
    this.jerseyColor = FinalOverPalette.deepBlue,
  });

  final FielderVisualState state;
  final double progress;
  final double facingAngle;
  final bool isPrimary;
  final Color jerseyColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = math.min(size.width, size.height) * .2;
    final center = Offset(size.width / 2, size.height / 2);
    final p = visualClamp01(progress);
    final activeColor = switch (state) {
      FielderVisualState.idle => FinalOverPalette.white,
      FielderVisualState.tracking => FinalOverPalette.cyan,
      FielderVisualState.catching => FinalOverPalette.yellow,
      FielderVisualState.pickup => FinalOverPalette.green,
      FielderVisualState.throwing => FinalOverPalette.orange,
      FielderVisualState.backingUp => FinalOverPalette.cyanDeep,
    };
    if (isPrimary || state != FielderVisualState.idle) {
      canvas.drawCircle(
        center,
        radius * (1.55 + .22 * math.sin(p * math.pi * 2)),
        Paint()
          ..color = activeColor.withValues(alpha: .17 + .12 * p)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        center,
        radius * 1.5,
        Paint()
          ..color = activeColor.withValues(alpha: .82)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, radius * .14),
      );
    }
    canvas.drawCircle(
      center + Offset(0, radius * .18),
      radius * 1.12,
      Paint()..color = FinalOverPalette.black.withValues(alpha: .36),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.35),
          colors: <Color>[
            Color.lerp(jerseyColor, FinalOverPalette.white, .28)!,
            jerseyColor,
            FinalOverPalette.navy,
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center - Offset(0, radius * .9),
      radius * .36,
      Paint()..color = const Color(0xFF9A6040),
    );
    if (state == FielderVisualState.catching) {
      final handPaint = Paint()
        ..color = FinalOverPalette.white
        ..strokeWidth = math.max(1.3, radius * .18)
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center - Offset(radius * .35, radius * .25),
        center - Offset(radius * .75, radius * (1 + .25 * p)),
        handPaint,
      );
      canvas.drawLine(
        center + Offset(radius * .35, -radius * .25),
        center + Offset(radius * .75, -radius * (1 + .25 * p)),
        handPaint,
      );
    }
    if (state == FielderVisualState.pickup) {
      canvas.drawArc(
        Rect.fromCircle(
          center: center + Offset(0, radius * .8),
          radius: radius * .65,
        ),
        0,
        math.pi,
        false,
        Paint()
          ..color = FinalOverPalette.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, radius * .14),
      );
    }
    if (state == FielderVisualState.tracking ||
        state == FielderVisualState.throwing ||
        state == FielderVisualState.backingUp) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(facingAngle);
      final length =
          radius * (state == FielderVisualState.throwing ? 2.1 : 1.65);
      final arrow = Path()
        ..moveTo(radius * .75, 0)
        ..lineTo(length, 0)
        ..lineTo(length - radius * .38, -radius * .25)
        ..moveTo(length, 0)
        ..lineTo(length - radius * .38, radius * .25);
      canvas.drawPath(
        arrow,
        Paint()
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, radius * .13)
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant FielderDotPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.progress != progress ||
        oldDelegate.facingAngle != facingAngle ||
        oldDelegate.isPrimary != isPrimary ||
        oldDelegate.jerseyColor != jerseyColor;
  }
}

enum ShotElevationVisual { ground, loft }

class ShotElevationIcon extends StatelessWidget {
  const ShotElevationIcon({
    super.key,
    required this.elevation,
    this.selected = false,
    this.progress = 1,
  });

  final ShotElevationVisual elevation;
  final bool selected;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ShotElevationIconPainter(
        elevation: elevation,
        selected: selected,
        progress: progress,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class ShotElevationIconPainter extends CustomPainter {
  const ShotElevationIconPainter({
    required this.elevation,
    this.selected = false,
    this.progress = 1,
  });

  final ShotElevationVisual elevation;
  final bool selected;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = Curves.easeOutCubic.transform(visualClamp01(progress));
    final rect = Offset.zero & size;
    final color = selected ? FinalOverPalette.cyan : FinalOverPalette.white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(1),
        Radius.circular(size.shortestSide * .22),
      ),
      Paint()
        ..color = selected
            ? FinalOverPalette.deepBlue.withValues(alpha: .9)
            : FinalOverPalette.navyRaised.withValues(alpha: .9),
    );
    final start = Offset(size.width * .18, size.height * .7);
    final end = Offset(
      size.width * .8,
      size.height * (elevation == ShotElevationVisual.ground ? .68 : .25),
    );
    final path = Path()..moveTo(start.dx, start.dy);
    if (elevation == ShotElevationVisual.ground) {
      path.quadraticBezierTo(
        size.width * .48,
        size.height * .62,
        end.dx,
        end.dy,
      );
    } else {
      path.quadraticBezierTo(
        size.width * .48,
        size.height * .04,
        end.dx,
        end.dy,
      );
    }
    final metric = path.computeMetrics().first;
    final partial = metric.extractPath(0, metric.length * p);
    canvas.drawPath(
      partial,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, size.shortestSide * .07)
        ..strokeCap = StrokeCap.round,
    );
    if (p > .8) {
      canvas.drawCircle(
        end,
        size.shortestSide * .08,
        Paint()..color = FinalOverPalette.red,
      );
    }
    canvas.drawLine(
      Offset(size.width * .12, size.height * .76),
      Offset(size.width * .88, size.height * .76),
      Paint()
        ..color = FinalOverPalette.green.withValues(alpha: .75)
        ..strokeWidth = math.max(1, size.shortestSide * .035)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant ShotElevationIconPainter oldDelegate) {
    return oldDelegate.elevation != elevation ||
        oldDelegate.selected != selected ||
        oldDelegate.progress != progress;
  }
}

enum ShotDirectionVisual { off, straight, leg }

class ShotDirectionIcon extends StatelessWidget {
  const ShotDirectionIcon({
    super.key,
    required this.direction,
    this.selected = false,
    this.progress = 1,
  });

  final ShotDirectionVisual direction;
  final bool selected;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ShotDirectionIconPainter(
        direction: direction,
        selected: selected,
        progress: progress,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class ShotDirectionIconPainter extends CustomPainter {
  const ShotDirectionIconPainter({
    required this.direction,
    this.selected = false,
    this.progress = 1,
  });

  final ShotDirectionVisual direction;
  final bool selected;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = Curves.easeOutBack.transform(visualClamp01(progress));
    final center = Offset(size.width / 2, size.height * .68);
    final angle = switch (direction) {
      ShotDirectionVisual.off => -2.18,
      ShotDirectionVisual.straight => -math.pi / 2,
      ShotDirectionVisual.leg => -.96,
    };
    final length = size.shortestSide * .36 * p;
    final end = center + Offset(math.cos(angle), math.sin(angle)) * length;
    final color = selected ? FinalOverPalette.cyan : FinalOverPalette.white;
    canvas.drawCircle(
      center,
      size.shortestSide * .12,
      Paint()..color = FinalOverPalette.red,
    );
    canvas.drawLine(
      center,
      end,
      Paint()
        ..color = color
        ..strokeWidth = math.max(2, size.shortestSide * .065)
        ..strokeCap = StrokeCap.round,
    );
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(-size.shortestSide * .14, -size.shortestSide * .09)
        ..lineTo(-size.shortestSide * .14, size.shortestSide * .09)
        ..close(),
      Paint()..color = color,
    );
    canvas.restore();
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.shortestSide * .3),
      -2.35,
      1.55,
      false,
      Paint()
        ..color = FinalOverPalette.cyan.withValues(alpha: selected ? .45 : .12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.shortestSide * .025),
    );
  }

  @override
  bool shouldRepaint(covariant ShotDirectionIconPainter oldDelegate) {
    return oldDelegate.direction != direction ||
        oldDelegate.selected != selected ||
        oldDelegate.progress != progress;
  }
}

/// A normalized trajectory. Points are expected in the inclusive 0..1 canvas
/// coordinate range, keeping it independent from the game's vector type.
class TrajectoryTrail extends StatelessWidget {
  const TrajectoryTrail({
    super.key,
    required this.points,
    this.progress = 1,
    this.color = FinalOverPalette.cyan,
    this.showHead = true,
    this.throwTrail = false,
  });

  final List<Offset> points;
  final double progress;
  final Color color;
  final bool showHead;
  final bool throwTrail;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TrajectoryTrailPainter(
        points: points,
        progress: progress,
        color: color,
        showHead: showHead,
        throwTrail: throwTrail,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class TrajectoryTrailPainter extends CustomPainter {
  const TrajectoryTrailPainter({
    required this.points,
    this.progress = 1,
    this.color = FinalOverPalette.cyan,
    this.showHead = true,
    this.throwTrail = false,
  });

  final List<Offset> points;
  final double progress;
  final Color color;
  final bool showHead;
  final bool throwTrail;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || points.length < 2) return;
    final p = visualClamp01(progress);
    final scaled = points
        .map((point) => Offset(point.dx * size.width, point.dy * size.height))
        .toList(growable: false);
    final completeSegments = ((scaled.length - 1) * p).floor();
    final segmentRemainder = (scaled.length - 1) * p - completeSegments;
    final visible = <Offset>[scaled.first];
    for (var i = 1; i <= completeSegments && i < scaled.length; i++) {
      visible.add(scaled[i]);
    }
    if (completeSegments < scaled.length - 1 && segmentRemainder > 0) {
      visible.add(
        Offset.lerp(
          scaled[completeSegments],
          scaled[completeSegments + 1],
          segmentRemainder,
        )!,
      );
    }
    if (visible.length < 2) return;
    for (var i = 1; i < visible.length; i++) {
      final age = i / visible.length;
      final segmentPaint = Paint()
        ..color = color.withValues(alpha: .12 + .78 * age)
        ..strokeWidth = math.max(1.4, size.shortestSide * (.004 + .007 * age))
        ..strokeCap = StrokeCap.round;
      if (throwTrail && i.isOdd) {
        final a = Offset.lerp(visible[i - 1], visible[i], .25)!;
        final b = Offset.lerp(visible[i - 1], visible[i], .78)!;
        canvas.drawLine(a, b, segmentPaint);
      } else {
        canvas.drawLine(visible[i - 1], visible[i], segmentPaint);
      }
    }
    if (showHead) {
      final head = visible.last;
      final radius = math.max(3.5, size.shortestSide * .014);
      canvas.drawCircle(
        head,
        radius * 2.2,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[color.withValues(alpha: .4), Colors.transparent],
          ).createShader(Rect.fromCircle(center: head, radius: radius * 2.2)),
      );
      canvas.drawCircle(head, radius, Paint()..color = FinalOverPalette.red);
    }
  }

  @override
  bool shouldRepaint(covariant TrajectoryTrailPainter oldDelegate) {
    return !listEquals(oldDelegate.points, points) ||
        oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.showHead != showHead ||
        oldDelegate.throwTrail != throwTrail;
  }
}

enum TimingVisualGrade { perfect, good, earlyLate, poor, miss }

TimingVisualGrade timingVisualGradeForError(double milliseconds) {
  final magnitude = milliseconds.abs();
  if (magnitude <= 50) return TimingVisualGrade.perfect;
  if (magnitude <= 115) return TimingVisualGrade.good;
  if (magnitude <= 190) return TimingVisualGrade.earlyLate;
  if (magnitude <= 275) return TimingVisualGrade.poor;
  return TimingVisualGrade.miss;
}

class TimingMeter extends StatelessWidget {
  const TimingMeter({
    super.key,
    required this.errorMilliseconds,
    this.revealProgress = 1,
    this.showLabels = true,
    this.enabled = true,
  });

  final double errorMilliseconds;
  final double revealProgress;
  final bool showLabels;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: TimingMeterPainter(
        errorMilliseconds: errorMilliseconds,
        revealProgress: revealProgress,
        showLabels: showLabels,
        enabled: enabled,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class TimingMeterPainter extends CustomPainter {
  const TimingMeterPainter({
    required this.errorMilliseconds,
    this.revealProgress = 1,
    this.showLabels = true,
    this.enabled = true,
  });

  final double errorMilliseconds;
  final double revealProgress;
  final bool showLabels;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final p = Curves.easeOutCubic.transform(visualClamp01(revealProgress));
    final panel = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(math.min(18, size.height * .28)),
    );
    canvas.drawRRect(
      panel,
      Paint()..color = FinalOverPalette.navy.withValues(alpha: .9 * p),
    );
    canvas.drawRRect(
      panel.deflate(1),
      Paint()
        ..color = FinalOverPalette.white.withValues(alpha: .12 * p)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final labelHeight = showLabels ? math.min(20.0, size.height * .3) : 0.0;
    final bar = Rect.fromLTWH(
      size.width * .06,
      labelHeight + (size.height - labelHeight) * .28,
      size.width * .88 * p,
      math.max(8, (size.height - labelHeight) * .36),
    );
    if (bar.width <= 0) return;
    final bands = <(double, Color)>[
      (350, FinalOverPalette.red),
      (275, FinalOverPalette.orange),
      (190, FinalOverPalette.yellow),
      (115, FinalOverPalette.green),
      (50, FinalOverPalette.cyan),
    ];
    canvas.save();
    canvas.clipRRect(
      RRect.fromRectAndRadius(bar, Radius.circular(bar.height / 2)),
    );
    canvas.drawRect(
      bar,
      Paint()..color = FinalOverPalette.red.withValues(alpha: .75),
    );
    for (final (window, color) in bands) {
      final halfWidth = bar.width * (window / 350) / 2;
      canvas.drawRect(
        Rect.fromCenter(
          center: bar.center,
          width: halfWidth * 2,
          height: bar.height,
        ),
        Paint()..color = color.withValues(alpha: .86),
      );
    }
    canvas.restore();
    canvas.drawLine(
      Offset(bar.center.dx, bar.top - 3),
      Offset(bar.center.dx, bar.bottom + 3),
      Paint()
        ..color = FinalOverPalette.white
        ..strokeWidth = math.max(1.5, bar.height * .09),
    );

    if (enabled) {
      final normalized = (errorMilliseconds.clamp(-350.0, 350.0) + 350) / 700;
      final markerX = bar.left + bar.width * normalized;
      final markerColor = FinalOverPalette.timingColorForMagnitude(
        errorMilliseconds,
      );
      final marker = Path()
        ..moveTo(markerX, bar.top - bar.height * .46)
        ..lineTo(markerX - bar.height * .25, bar.top - 2)
        ..lineTo(markerX + bar.height * .25, bar.top - 2)
        ..close();
      canvas.drawShadow(marker, FinalOverPalette.black, 3, true);
      canvas.drawPath(marker, Paint()..color = markerColor);
      canvas.drawCircle(
        Offset(markerX, bar.center.dy),
        bar.height * .2,
        Paint()..color = FinalOverPalette.white,
      );
    }

    if (showLabels) {
      final early = TextPainter(
        text: TextSpan(
          text: 'EARLY',
          style: TextStyle(
            color: FinalOverPalette.white.withValues(alpha: .58 * p),
            fontSize: math.min(11, size.height * .18),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final late = TextPainter(
        text: TextSpan(
          text: 'LATE',
          style: TextStyle(
            color: FinalOverPalette.white.withValues(alpha: .58 * p),
            fontSize: math.min(11, size.height * .18),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      early.paint(canvas, Offset(bar.left, 3));
      late.paint(canvas, Offset(bar.right - late.width, 3));
    }
  }

  @override
  bool shouldRepaint(covariant TimingMeterPainter oldDelegate) {
    return oldDelegate.errorMilliseconds != errorMilliseconds ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.showLabels != showLabels ||
        oldDelegate.enabled != enabled;
  }
}
