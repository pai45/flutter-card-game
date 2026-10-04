import 'dart:math';
import 'dart:ui';

import '../../config/theme.dart';
import '../../models/grand_prix.dart';

typedef GrandPrixProjection = Offset Function(double distance, double lateral);

/// Deterministic, cached trackside art. At most sixteen prop pictures are
/// retained per circuit, independent of race length; only visible cells draw.
class GrandPrixScenery {
  GrandPrixScenery(this.circuit);
  final GrandPrixCircuitId circuit;
  final Map<int, Picture> _props = {};
  Picture? _asphalt;

  Color get terrain => switch (circuit) {
    GrandPrixCircuitId.harbourStreet => Cyber.arenaVioletHorizon,
    GrandPrixCircuitId.desertMile => Color.lerp(Cyber.amber, Cyber.bg, 0.8)!,
    GrandPrixCircuitId.emeraldPark => AppTheme.lime950,
    GrandPrixCircuitId.mountainPass => AppTheme.futureLost,
    GrandPrixCircuitId.coastalSprint => Color.lerp(
      AppTheme.primary950,
      Cyber.bg,
      0.45,
    )!,
  };

  Color get runoff => switch (circuit) {
    GrandPrixCircuitId.harbourStreet => AppTheme.slate800,
    GrandPrixCircuitId.desertMile => Color.lerp(Cyber.amber, Cyber.bg, 0.7)!,
    GrandPrixCircuitId.emeraldPark => Color.lerp(
      AppTheme.lime900,
      Cyber.bg,
      0.35,
    )!,
    GrandPrixCircuitId.mountainPass => AppTheme.grey900,
    GrandPrixCircuitId.coastalSprint => Color.lerp(
      AppTheme.emerland950,
      Cyber.bg,
      0.3,
    )!,
  };

  void paint(
    Canvas canvas,
    Size size,
    GrandPrixProjection project,
    double from,
    double to,
    double pixelsPerMetre,
  ) {
    canvas.drawRect(Offset.zero & size, Paint()..color = terrain);
    final scale = (pixelsPerMetre / 24).clamp(0.6, 1.8);
    for (
      var cell = (from / 32).floor() - 1;
      cell <= (to / 32).ceil() + 1;
      cell++
    ) {
      final s = cell * 32.0;
      for (final side in const [-1, 1]) {
        final variant = (cell.abs() * 7 + (side > 0 ? 3 : 0)) % 8;
        // Keep silhouettes in the phone's narrow trackside strips. The road
        // paints over their inner edge, so props cannot obstruct driving.
        final at = project(s, side * (6.1 + variant % 3 * 0.35));
        final key = variant * 2 + (side > 0 ? 1 : 0);
        final picture = _props.putIfAbsent(
          key,
          () => _buildProp(variant, side),
        );
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.scale(side * scale, scale);
        canvas.drawPicture(picture);
        canvas.restore();
      }
    }
    // Distinct waterfront/coast bed, attached to track space rather than HUD.
    if (circuit == GrandPrixCircuitId.harbourStreet ||
        circuit == GrandPrixCircuitId.coastalSprint) {
      final stroke = Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (var cell = (from / 12).floor(); cell <= (to / 12).ceil(); cell++) {
        final at = project(
          cell * 12.0,
          circuit == GrandPrixCircuitId.coastalSprint ? 7.9 : -7.9,
        );
        canvas.drawArc(
          Rect.fromCenter(center: at, width: 78, height: 12),
          0.15,
          2.2,
          false,
          stroke,
        );
      }
    }
  }

  Picture _buildProp(int variant, int side) {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final shade = Paint()..color = Cyber.arenaFloor.withValues(alpha: 0.55);
    final edge = Paint()
      ..color = Cyber.muted.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final w = 44.0 + variant * 5;
    final h = 65.0 + variant * 7;
    canvas.drawRect(Rect.fromLTWH(5, 8, w, h), shade);
    switch (circuit) {
      case GrandPrixCircuitId.harbourStreet:
        canvas.drawRect(
          Rect.fromLTWH(0, 0, w, h),
          Paint()..color = variant.isEven ? Cyber.panel : Cyber.bg2,
        );
        canvas.drawRect(Rect.fromLTWH(4, 4, w - 8, h - 8), edge);
        canvas.drawRect(
          Rect.fromLTWH(7, 7, w * 0.4, 14),
          Paint()..color = Cyber.arenaFloor,
        );
        for (var row = 0; row < 4; row++) {
          for (var col = 0; col < 3; col++) {
            canvas.drawRect(
              Rect.fromLTWH(7 + col * 12, 31 + row * 10, 6, 3),
              Paint()
                ..color = (row + col + variant).isEven
                    ? Cyber.amber.withValues(alpha: 0.55)
                    : Cyber.border,
            );
          }
        }
        canvas.drawLine(
          Offset(-9, -15),
          Offset(-9, h + 20),
          Paint()
            ..color = Cyber.border
            ..strokeWidth = 2,
        );
        canvas.drawCircle(
          const Offset(-9, 0),
          3,
          Paint()..color = Cyber.amber.withValues(alpha: 0.6),
        );
      case GrandPrixCircuitId.desertMile:
        final dune = Path()
          ..moveTo(-15, h)
          ..quadraticBezierTo(w * 0.5, -35, w + 40, h * 0.4)
          ..lineTo(w + 50, h + 40)
          ..close();
        canvas.drawPath(
          dune,
          Paint()..color = Color.lerp(Cyber.amber, terrain, 0.85)!,
        );
        canvas.drawPath(dune, edge);
        _rock(canvas, const Offset(12, 20), 14 + variant.toDouble());
        if (variant % 3 == 0) {
          canvas.drawRect(
            Rect.fromLTWH(-12, -12, 6, 44),
            Paint()..color = Cyber.border,
          );
          canvas.drawRect(
            Rect.fromLTWH(-18, -18, 29, 12),
            Paint()..color = Cyber.arenaFloor,
          );
          canvas.drawLine(
            const Offset(-16, -15),
            const Offset(7, -15),
            Paint()
              ..color = Cyber.amber
              ..strokeWidth = 2,
          );
        }
      case GrandPrixCircuitId.emeraldPark:
        if (variant == 0 || variant == 5) {
          canvas.drawRect(
            Rect.fromLTWH(0, 0, 66, 88),
            Paint()..color = Cyber.panel,
          );
          for (var row = 0; row < 8; row++) {
            canvas.drawLine(
              Offset(5, 6 + row * 10),
              Offset(61, 6 + row * 10),
              Paint()
                ..color = row.isEven
                    ? Cyber.border
                    : Cyber.f1Red.withValues(alpha: 0.38)
                ..strokeWidth = 5,
            );
          }
          canvas.drawRect(
            const Rect.fromLTWH(0, -8, 66, 8),
            Paint()..color = AppTheme.whiteColor.withValues(alpha: 0.3),
          );
        } else {
          _tree(canvas, const Offset(15, 22), 18 + variant * 1.5);
          _tree(canvas, Offset(45, h - 15), 15 + variant.toDouble());
        }
      case GrandPrixCircuitId.mountainPass:
        _rock(canvas, Offset(w * 0.4, h * 0.35), 34 + variant * 2.0);
        _rock(canvas, Offset(w, h), 24 + variant.toDouble());
        canvas.drawLine(
          const Offset(-12, -20),
          Offset(-12, h + 20),
          Paint()
            ..color = Cyber.muted.withValues(alpha: 0.4)
            ..strokeWidth = 4,
        );
        for (var i = 0; i < 5; i++) {
          canvas.drawLine(Offset(-15, i * 18.0), Offset(-7, i * 18.0), edge);
        }
      case GrandPrixCircuitId.coastalSprint:
        if (side < 0) {
          _rock(canvas, Offset(w * 0.6, h * 0.45), 30);
          _tree(canvas, const Offset(10, 8), 16, palm: true);
        } else {
          canvas.drawRect(
            Rect.fromLTWH(-12, -35, 10, h + 55),
            Paint()..color = Color.lerp(Cyber.amber, Cyber.bg, 0.6)!,
          );
          if (variant % 3 == 0) {
            final boat = Path()
              ..moveTo(25, 0)
              ..quadraticBezierTo(57, 15, 45, 48)
              ..lineTo(29, 52)
              ..quadraticBezierTo(10, 22, 25, 0)
              ..close();
            canvas.drawPath(
              boat,
              Paint()..color = AppTheme.whiteColor.withValues(alpha: 0.55),
            );
            canvas.drawRect(
              const Rect.fromLTWH(27, 14, 11, 20),
              Paint()..color = Cyber.panel,
            );
          }
        }
    }
    return recorder.endRecording();
  }

  void _tree(Canvas canvas, Offset at, double radius, {bool palm = false}) {
    canvas.drawCircle(
      at + const Offset(6, 8),
      radius,
      Paint()..color = Cyber.arenaFloor.withValues(alpha: 0.45),
    );
    if (palm) {
      for (var i = 0; i < 6; i++) {
        final angle = i * pi / 3;
        canvas.drawLine(
          at,
          at + Offset(cos(angle), sin(angle)) * radius,
          Paint()
            ..color = AppTheme.emerland900
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      }
    } else {
      canvas.drawCircle(at, radius, Paint()..color = AppTheme.lime950);
      canvas.drawCircle(
        at - const Offset(3, 4),
        radius * 0.75,
        Paint()..color = AppTheme.lime900.withValues(alpha: 0.6),
      );
      canvas.drawCircle(
        at - const Offset(5, 6),
        radius * 0.3,
        Paint()..color = Cyber.success.withValues(alpha: 0.09),
      );
    }
  }

  void _rock(Canvas canvas, Offset at, double radius) {
    final path = Path()
      ..moveTo(at.dx - radius, at.dy)
      ..lineTo(at.dx - radius * 0.3, at.dy - radius)
      ..lineTo(at.dx + radius * 0.6, at.dy - radius * 0.8)
      ..lineTo(at.dx + radius, at.dy + radius * 0.5)
      ..lineTo(at.dx, at.dy + radius)
      ..close();
    canvas.drawPath(path, Paint()..color = Cyber.border);
    final facet = Path()
      ..moveTo(at.dx - radius, at.dy)
      ..lineTo(at.dx - radius * 0.3, at.dy - radius)
      ..lineTo(at.dx, at.dy + radius * 0.2)
      ..close();
    canvas.drawPath(
      facet,
      Paint()..color = Cyber.muted.withValues(alpha: 0.35),
    );
    canvas.drawLine(
      at + Offset(-radius * 0.3, -radius),
      at + Offset(0, radius * 0.2),
      Paint()
        ..color = Cyber.arenaFloor.withValues(alpha: 0.3)
        ..strokeWidth = 2,
    );
  }

  void paintAsphalt(
    Canvas canvas,
    Path road,
    GrandPrixProjection project,
    double from,
    double to,
  ) {
    _asphalt ??= _buildAsphalt();
    canvas.save();
    canvas.clipPath(road);
    for (
      var cell = (from / 25).floor() - 1;
      cell <= (to / 25).ceil() + 1;
      cell++
    ) {
      final at = project(cell * 25.0, 0);
      canvas.save();
      canvas.translate(at.dx - 256, at.dy);
      canvas.drawPicture(_asphalt!);
      canvas.restore();
    }
    canvas.restore();
  }

  Picture _buildAsphalt() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final random = Random(143);
    final paint = Paint()..color = AppTheme.whiteColor.withValues(alpha: 0.045);
    for (var i = 0; i < 96; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          random.nextDouble() * 512,
          random.nextDouble() * 150,
          1.5,
          3,
        ),
        paint,
      );
    }
    return recorder.endRecording();
  }

  void dispose() {
    for (final picture in _props.values) {
      picture.dispose();
    }
    _asphalt?.dispose();
  }
}
