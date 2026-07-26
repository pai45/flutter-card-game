import 'dart:math';

import 'package:flutter/material.dart';

import '../config/theme.dart';

/// A complete portrait football pitch for the persistent Pitch Duel board.
///
/// The field is deliberately restrained: its job is to establish the arena,
/// not compete with the live card selection or commit CTA. Stadium art may sit
/// beneath it; the tinted fill and HUD line work keep the pitch legible across
/// every round beat.
class FullPitchBackground extends StatelessWidget {
  const FullPitchBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final pitchColor = Color.alphaBlend(
      Cyber.success.withValues(alpha: 0.12),
      Cyber.bg,
    );
    return RepaintBoundary(
      child: ColoredBox(
        color: pitchColor.withValues(alpha: 0.94),
        child: const CustomPaint(
          painter: FullPitchPainter(),
          child: SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Full-pitch line work aligned to the round board's upper/lower halves.
class FullPitchPainter extends CustomPainter {
  const FullPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final stripePaint = Paint()
      ..color = Cyber.success.withValues(alpha: 0.03)
      ..style = PaintingStyle.fill;
    final stripeHeight = size.height / 12;
    for (var index = 0; index < 12; index += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, index * stripeHeight, size.width, stripeHeight),
        stripePaint,
      );
    }

    final line = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final faint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.11)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final spot = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.42)
      ..style = PaintingStyle.fill;

    const sideInset = 14.0;
    const endInset = 12.0;
    final field = Rect.fromLTRB(
      sideInset,
      endInset,
      size.width - sideInset,
      size.height - endInset,
    );
    final halfwayY = field.center.dy;
    final centreRadius = min(46.0, field.width * 0.13);

    canvas.drawRect(field, line);
    canvas.drawLine(
      Offset(field.left, halfwayY),
      Offset(field.right, halfwayY),
      line,
    );
    canvas.drawCircle(Offset(field.center.dx, halfwayY), centreRadius, line);
    canvas.drawCircle(Offset(field.center.dx, halfwayY), 2.2, spot);

    final penaltyWidth = field.width * 0.62;
    final penaltyDepth = min(104.0, field.height * 0.15);
    final goalAreaWidth = field.width * 0.32;
    final goalAreaDepth = min(42.0, field.height * 0.065);
    final penaltyLeft = field.center.dx - penaltyWidth / 2;
    final goalAreaLeft = field.center.dx - goalAreaWidth / 2;

    canvas.drawRect(
      Rect.fromLTWH(penaltyLeft, field.top, penaltyWidth, penaltyDepth),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(goalAreaLeft, field.top, goalAreaWidth, goalAreaDepth),
      faint,
    );
    canvas.drawCircle(
      Offset(field.center.dx, field.top + penaltyDepth * 0.7),
      1.8,
      spot,
    );

    canvas.drawRect(
      Rect.fromLTWH(
        penaltyLeft,
        field.bottom - penaltyDepth,
        penaltyWidth,
        penaltyDepth,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        goalAreaLeft,
        field.bottom - goalAreaDepth,
        goalAreaWidth,
        goalAreaDepth,
      ),
      faint,
    );
    canvas.drawCircle(
      Offset(field.center.dx, field.bottom - penaltyDepth * 0.7),
      1.8,
      spot,
    );

    final goalWidth = field.width * 0.22;
    final goalLeft = field.center.dx - goalWidth / 2;
    canvas.drawRect(Rect.fromLTWH(goalLeft, field.top, goalWidth, 7), faint);
    canvas.drawRect(
      Rect.fromLTWH(goalLeft, field.bottom - 7, goalWidth, 7),
      faint,
    );
  }

  @override
  bool shouldRepaint(covariant FullPitchPainter oldDelegate) => false;
}

/// Which vertical slice of a full pitch to show (attacking = top half).
enum PitchHalf { top, bottom }

/// Green pitch fill + line art at [opacity] (default 50%).
class PitchHalfBackground extends StatelessWidget {
  const PitchHalfBackground({
    required this.half,
    this.opacity = 0.5,
    super.key,
  });

  final PitchHalf half;
  final double opacity;

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xff073222), Color(0xff061b22), Color(0xff08111d)],
  );

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: _gradient),
        child: CustomPaint(
          painter: PitchHalfPainter(half: half),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// One half of a pitch, fitted inside [size] (top = opponent end, bottom = yours).
class PitchHalfPainter extends CustomPainter {
  const PitchHalfPainter({required this.half});

  final PitchHalf half;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final w = size.width;
    final h = size.height;
    const pad = 14.0;
    final innerW = w - pad * 2;
    final innerH = h - pad * 2;
    final boxH = innerH * 0.32;
    final boxW = innerW * 0.62;
    final boxLeft = (w - boxW) / 2;
    final circleR = min(36.0, innerW * 0.11);

    canvas.drawRect(Rect.fromLTWH(pad, pad, innerW, innerH), line);

    if (half == PitchHalf.top) {
      final halfLineY = h - pad;
      canvas.drawLine(Offset(pad, halfLineY), Offset(w - pad, halfLineY), line);
      canvas.drawCircle(Offset(w / 2, halfLineY), circleR, line);
      canvas.drawRect(Rect.fromLTWH(boxLeft, pad, boxW, boxH), line);
    } else {
      final halfLineY = pad;
      canvas.drawLine(Offset(pad, halfLineY), Offset(w - pad, halfLineY), line);
      canvas.drawCircle(Offset(w / 2, halfLineY), circleR, line);
      canvas.drawRect(Rect.fromLTWH(boxLeft, h - pad - boxH, boxW, boxH), line);
    }
  }

  @override
  bool shouldRepaint(covariant PitchHalfPainter oldDelegate) =>
      oldDelegate.half != half;
}

/// Full five-a-side pitch lines used on the deck builder formation view.
class PitchPainter extends CustomPainter {
  const PitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Cyber.cyan.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(
      Offset(16, size.height * 0.26),
      Offset(size.width - 16, size.height * 0.26),
      paint,
    );
    canvas.drawLine(
      Offset(16, size.height * 0.54),
      Offset(size.width - 16, size.height * 0.54),
      paint,
    );
    canvas.drawCircle(Offset(size.width / 2, size.height * 0.54), 40, paint);
    canvas.drawRect(
      Rect.fromLTWH(14, 14, size.width - 28, size.height - 28),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
