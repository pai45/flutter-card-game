import 'package:flutter/material.dart';

import '../../config/enums.dart';
import '../../config/theme.dart';

/// Batting-order telemetry shared by cricket deck surfaces.
class CricketCreaseSignalPainter extends CustomPainter {
  const CricketCreaseSignalPainter({this.accent = Cyber.lime});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppTheme.textPrimary.withValues(alpha: 0.24)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final pitch = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.08,
        size.height * 0.10,
        size.width * 0.84,
        size.height * 0.80,
      ),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      pitch,
      Paint()..color = accent.withValues(alpha: 0.045),
    );
    canvas.drawRRect(pitch, line);

    for (final y in [0.24, 0.76]) {
      canvas.drawLine(
        Offset(size.width * 0.04, size.height * y),
        Offset(size.width * 0.96, size.height * y),
        line,
      );
    }
    for (final x in [0.46, 0.50, 0.54]) {
      canvas.drawLine(
        Offset(size.width * x, size.height * 0.13),
        Offset(size.width * x, size.height * 0.23),
        Paint()
          ..color = accent.withValues(alpha: 0.55)
          ..strokeWidth = 1.4,
      );
      canvas.drawLine(
        Offset(size.width * x, size.height * 0.77),
        Offset(size.width * x, size.height * 0.87),
        Paint()
          ..color = accent.withValues(alpha: 0.55)
          ..strokeWidth = 1.4,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CricketCreaseSignalPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Half-court linework shared by basketball roster surfaces.
class BasketballHalfCourtSignalPainter extends CustomPainter {
  const BasketballHalfCourtSignalPainter({this.accent = Cyber.gold});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppTheme.textPrimary.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final bounds = Rect.fromLTWH(
      size.width * 0.04,
      size.height * 0.03,
      size.width * 0.92,
      size.height * 0.94,
    );
    canvas.drawRect(bounds, Paint()..color = accent.withValues(alpha: 0.035));
    canvas.drawRect(bounds, line);
    final center = Offset(size.width / 2, size.height * 0.03);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.18),
      0,
      3.14159,
      false,
      line,
    );
    final key = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.22),
      width: size.width * 0.30,
      height: size.height * 0.38,
    );
    canvas.drawRect(key, line);
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(size.width / 2, size.height * 0.39),
        radius: size.width * 0.15,
      ),
      0,
      6.28318,
      false,
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.43, size.height * 0.08),
      Offset(size.width * 0.57, size.height * 0.08),
      Paint()
        ..color = accent.withValues(alpha: 0.58)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(size.width / 2, size.height * 0.10),
      5,
      line,
    );
  }

  @override
  bool shouldRepaint(covariant BasketballHalfCourtSignalPainter oldDelegate) =>
      oldDelegate.accent != accent;
}

/// Compact sport markings laid over collectible art. This keeps the shared
/// rarity frame intact while making non-football cards read at a glance.
class SportCardSignalPainter extends CustomPainter {
  const SportCardSignalPainter({required this.role, required this.accent});

  final PlayerRole role;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = accent.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    switch (role) {
      case PlayerRole.batsman:
      case PlayerRole.bowler:
        canvas.drawLine(
          Offset(0, size.height * 0.74),
          Offset(size.width, size.height * 0.74),
          line,
        );
        for (final x in [0.44, 0.50, 0.56]) {
          canvas.drawLine(
            Offset(size.width * x, size.height * 0.61),
            Offset(size.width * x, size.height * 0.74),
            line,
          );
        }
      case PlayerRole.basketballGuard:
      case PlayerRole.basketballWing:
      case PlayerRole.basketballBig:
        canvas.drawArc(
          Rect.fromCircle(
            center: Offset(size.width / 2, size.height * 0.18),
            radius: size.width * 0.36,
          ),
          0,
          3.14159,
          false,
          line,
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.16),
            width: size.width * 0.30,
            height: size.height * 0.30,
          ),
          line,
        );
      case PlayerRole.tennisSingles:
        canvas.drawRect(
          Rect.fromLTWH(
            size.width * 0.10,
            size.height * 0.10,
            size.width * 0.80,
            size.height * 0.70,
          ),
          line,
        );
        canvas.drawLine(
          Offset(size.width * 0.10, size.height * 0.45),
          Offset(size.width * 0.90, size.height * 0.45),
          line,
        );
      case PlayerRole.f1Driver:
      case PlayerRole.f2Driver:
      case PlayerRole.nascarDriver:
      case PlayerRole.indycarDriver:
        final track = Path()
          ..moveTo(size.width * 0.22, 0)
          ..cubicTo(
            size.width * 0.85,
            size.height * 0.20,
            size.width * 0.18,
            size.height * 0.58,
            size.width * 0.82,
            size.height,
          );
        canvas.drawPath(track, line..strokeWidth = 3);
      case PlayerRole.attacker:
      case PlayerRole.defender:
      case PlayerRole.goalkeeper:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant SportCardSignalPainter oldDelegate) =>
      oldDelegate.role != role || oldDelegate.accent != accent;
}

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
