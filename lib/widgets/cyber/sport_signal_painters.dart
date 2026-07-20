import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Shared court telemetry promoted from the Games hub tennis card.
class TennisMysterySignalPainter extends CustomPainter {
  const TennisMysterySignalPainter({this.accent = Cyber.lime});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Cyber.bg.withValues(alpha: 0),
            Color.alphaBlend(Cyber.cyan.withValues(alpha: 0.24), Cyber.bg2),
          ],
          stops: const [0.36, 1],
        ).createShader(bounds),
    );

    final court = Path()
      ..moveTo(size.width * 0.67, size.height * 0.12)
      ..lineTo(size.width * 0.94, size.height * 0.12)
      ..lineTo(size.width * 1.08, size.height * 1.03)
      ..lineTo(size.width * 0.48, size.height * 1.03)
      ..close();
    canvas.drawPath(
      court,
      Paint()
        ..color = Color.alphaBlend(
          Cyber.cyan.withValues(alpha: 0.28),
          Cyber.bg2,
        ),
    );
    final line = Paint()
      ..color = AppTheme.textPrimary.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(court, line);
    canvas.drawLine(
      Offset(size.width * 0.57, size.height * 0.57),
      Offset(size.width, size.height * 0.57),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.12),
      Offset(size.width * 0.67, size.height),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.39),
      6,
      Paint()..color = accent,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.83, size.height * 0.78),
        width: 27,
        height: 9,
      ),
      Paint()
        ..color = accent.withValues(alpha: 0.36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant TennisMysterySignalPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

/// Shared circuit telemetry promoted from the Games hub Grand Prix card.
class F1MysterySignalPainter extends CustomPainter {
  const F1MysterySignalPainter({this.accent = Cyber.f1Red});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Cyber.bg.withValues(alpha: 0),
            Color.alphaBlend(accent.withValues(alpha: 0.2), Cyber.bg2),
          ],
          stops: const [0.36, 1],
        ).createShader(bounds),
    );

    final track = Path()
      ..moveTo(size.width * 0.70, -12)
      ..cubicTo(
        size.width * 1.01,
        size.height * 0.10,
        size.width * 0.68,
        size.height * 0.43,
        size.width * 0.84,
        size.height * 0.61,
      )
      ..cubicTo(
        size.width * 0.98,
        size.height * 0.78,
        size.width * 0.72,
        size.height * 0.87,
        size.width * 0.96,
        size.height * 1.08,
      );
    canvas.drawPath(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 42
        ..strokeCap = StrokeCap.round
        ..color = Cyber.border,
    );
    canvas.drawPath(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 46
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = AppTheme.textPrimary.withValues(alpha: 0.34),
    );

    final carCenter = Offset(size.width * 0.82, size.height * 0.60);
    final carBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: carCenter, width: 48, height: 18),
      const Radius.circular(5),
    );
    canvas.save();
    canvas.translate(carCenter.dx, carCenter.dy);
    canvas.rotate(-0.22);
    canvas.translate(-carCenter.dx, -carCenter.dy);
    canvas.drawRRect(carBody, Paint()..color = accent);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: carCenter.translate(2, 0),
          width: 17,
          height: 12,
        ),
        const Radius.circular(5),
      ),
      Paint()..color = Cyber.bg,
    );
    for (final dy in [-10.0, 10.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: carCenter.translate(-12, dy),
            width: 13,
            height: 5,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Cyber.bg,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: carCenter.translate(14, dy),
            width: 13,
            height: 5,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Cyber.bg,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant F1MysterySignalPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}
