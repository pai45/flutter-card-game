import 'dart:math';

import 'package:flutter/material.dart';

import '../config/theme.dart';

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
