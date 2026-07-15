import 'dart:math';

import 'package:flutter/widgets.dart';

import '../../data/grand_prix_liveries.dart';

/// Shared top-down F1 car drawing for Grand Prix Dash.
///
/// One procedural car, drawn twice: by the Flame `_CarComponent` on track and
/// by [GrandPrixCarPreviewPainter] on the lobby's livery picker, so the car
/// you pick is exactly the car you race. Proportions follow a modern F1 car —
/// multi-element front wing with endplates, slim nose, halo over the cockpit,
/// coke-bottle sidepods, engine-cover spine, diffuser and a DRS rear wing —
/// kept bold enough to read at ~26px wide.
///
/// Like the liveries themselves, the carbon/tyre/rim greys here are CONTENT
/// colors (the documented exception to the no-raw-hex rule): they belong to
/// the car, not the UI chrome.
class GrandPrixCarStyle {
  GrandPrixCarStyle(this.spec)
    : body = Paint()..color = spec.primary,
      bodyEdge = Paint()
        ..style = PaintingStyle.stroke
        ..color = Color.lerp(spec.primary, const Color(0xFF000000), 0.45)!,
      accent = Paint()..color = spec.accent,
      accentDark = Paint()
        ..color = Color.lerp(spec.accent, const Color(0xFF000000), 0.30)!,
      carbon = Paint()..color = const Color(0xFF060910),
      tyre = Paint()..color = const Color(0xFF05070B),
      rim = Paint()..color = const Color(0xFF4A5462),
      halo = Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0xFF39424F),
      suspension = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFF2A313C),
      shadow = Paint()..color = const Color(0xFF000000).withValues(alpha: 0.28),
      glint = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.45);

  final GrandPrixLiverySpec spec;
  final Paint body;
  final Paint bodyEdge;
  final Paint accent;
  final Paint accentDark;
  final Paint carbon;
  final Paint tyre;
  final Paint rim;
  final Paint halo;
  final Paint suspension;
  final Paint shadow;
  final Paint glint;
}

RRect _rr(double l, double t, double w, double h, double r) =>
    RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r));

/// Draws the car into a `w`×`h` box (nose up at y=0, rear wing at y=h).
/// Looks right around a 1:2 width:length box — [GrandPrixCarPreviewPainter]
/// letterboxes arbitrary canvases to that aspect.
void paintGrandPrixCar(Canvas canvas, double w, double h, GrandPrixCarStyle s) {
  final r = w * 0.05;
  final thin = max(1.0, w * 0.030);

  // Ground shadow.
  canvas.drawOval(Rect.fromLTWH(w * 0.01, h * 0.02, w * 0.98, h * 0.96), s.shadow);

  // Front wing (under the nose): endplates, upper flap, main plane.
  canvas.drawRRect(_rr(w * 0.005, h * 0.005, w * 0.060, h * 0.115, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.935, h * 0.005, w * 0.060, h * 0.115, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.09, h * 0.018, w * 0.82, h * 0.032, r), s.accentDark);
  canvas.drawRRect(_rr(w * 0.05, h * 0.055, w * 0.90, h * 0.048, r), s.accent);

  // Suspension wishbones (under the tyres).
  final susp = s.suspension..strokeWidth = thin;
  canvas.drawLine(Offset(w * 0.42, h * 0.200), Offset(w * 0.10, h * 0.185), susp);
  canvas.drawLine(Offset(w * 0.42, h * 0.245), Offset(w * 0.10, h * 0.240), susp);
  canvas.drawLine(Offset(w * 0.58, h * 0.200), Offset(w * 0.90, h * 0.185), susp);
  canvas.drawLine(Offset(w * 0.58, h * 0.245), Offset(w * 0.90, h * 0.240), susp);
  canvas.drawLine(Offset(w * 0.38, h * 0.725), Offset(w * 0.10, h * 0.715), susp);
  canvas.drawLine(Offset(w * 0.38, h * 0.785), Offset(w * 0.10, h * 0.780), susp);
  canvas.drawLine(Offset(w * 0.62, h * 0.725), Offset(w * 0.90, h * 0.715), susp);
  canvas.drawLine(Offset(w * 0.62, h * 0.785), Offset(w * 0.90, h * 0.780), susp);

  // Tyres — rears run wider, with a grey rim slot in each.
  void tyreAt(double l, double t, double tw, double th) {
    canvas.drawRRect(_rr(l, t, tw, th, w * 0.055), s.tyre);
    canvas.drawRRect(
      _rr(l + tw * 0.32, t + th * 0.24, tw * 0.36, th * 0.52, w * 0.03),
      s.rim,
    );
  }

  tyreAt(-w * 0.005, h * 0.145, w * 0.195, h * 0.135);
  tyreAt(w * 0.810, h * 0.145, w * 0.195, h * 0.135);
  tyreAt(-w * 0.015, h * 0.685, w * 0.215, h * 0.155);
  tyreAt(w * 0.800, h * 0.685, w * 0.215, h * 0.155);

  // Body: slim nose → chassis → sidepod flare → coke-bottle taper → rear.
  final body = Path()
    ..moveTo(w * 0.50, h * 0.010)
    ..quadraticBezierTo(w * 0.575, h * 0.045, w * 0.585, h * 0.16)
    ..lineTo(w * 0.615, h * 0.33)
    ..quadraticBezierTo(w * 0.830, h * 0.375, w * 0.835, h * 0.47)
    ..quadraticBezierTo(w * 0.815, h * 0.600, w * 0.660, h * 0.685)
    ..lineTo(w * 0.635, h * 0.86)
    ..lineTo(w * 0.365, h * 0.86)
    ..lineTo(w * 0.340, h * 0.685)
    ..quadraticBezierTo(w * 0.185, h * 0.600, w * 0.165, h * 0.47)
    ..quadraticBezierTo(w * 0.170, h * 0.375, w * 0.385, h * 0.33)
    ..lineTo(w * 0.415, h * 0.16)
    ..quadraticBezierTo(w * 0.425, h * 0.045, w * 0.50, h * 0.010)
    ..close();
  canvas.drawPath(body, s.body);
  canvas.drawPath(body, s.bodyEdge..strokeWidth = max(1.0, w * 0.022));

  // Sidepod radiator intakes.
  canvas.drawRRect(_rr(w * 0.205, h * 0.445, w * 0.115, h * 0.045, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.680, h * 0.445, w * 0.115, h * 0.045, r), s.carbon);

  // Accent nose stripe + engine-cover spine.
  canvas.drawRRect(_rr(w * 0.474, h * 0.045, w * 0.052, h * 0.135, r), s.accent);
  canvas.drawRRect(_rr(w * 0.468, h * 0.565, w * 0.064, h * 0.270, r), s.accent);

  // Wing mirrors.
  canvas.drawRRect(_rr(w * 0.335, h * 0.372, w * 0.048, h * 0.020, r), s.accent);
  canvas.drawRRect(_rr(w * 0.617, h * 0.372, w * 0.048, h * 0.020, r), s.accent);

  // Cockpit, halo and the driver's helmet.
  canvas.drawRRect(_rr(w * 0.415, h * 0.360, w * 0.170, h * 0.185, w * 0.07), s.carbon);
  final haloPaint = s.halo..strokeWidth = max(1.0, w * 0.028);
  canvas.drawOval(Rect.fromLTWH(w * 0.400, h * 0.350, w * 0.200, h * 0.205), haloPaint);
  canvas.drawLine(Offset(w * 0.50, h * 0.350), Offset(w * 0.50, h * 0.440), haloPaint);
  canvas.drawCircle(Offset(w * 0.50, h * 0.475), w * 0.062, s.accent);
  canvas.drawCircle(Offset(w * 0.478, h * 0.462), w * 0.020, s.glint);

  // Diffuser with vertical strakes.
  canvas.drawRRect(_rr(w * 0.28, h * 0.860, w * 0.44, h * 0.080, r), s.carbon);
  for (final x in [0.39, 0.50, 0.61]) {
    canvas.drawLine(
      Offset(w * x, h * 0.872),
      Offset(w * x, h * 0.928),
      s.rim..strokeWidth = max(1.0, w * 0.018),
    );
  }

  // Rear wing (topmost at the rear): endplates, main plane + DRS slot, flap.
  canvas.drawRRect(_rr(w * 0.060, h * 0.845, w * 0.055, h * 0.135, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.885, h * 0.845, w * 0.055, h * 0.135, r), s.carbon);
  canvas.drawRRect(_rr(w * 0.130, h * 0.845, w * 0.740, h * 0.028, r), s.accentDark);
  canvas.drawRRect(_rr(w * 0.100, h * 0.875, w * 0.800, h * 0.062, r), s.accent);
  canvas.drawLine(
    Offset(w * 0.12, h * 0.905),
    Offset(w * 0.88, h * 0.905),
    s.carbon..strokeWidth = max(1.0, w * 0.016),
  );
}

/// Letterboxed [paintGrandPrixCar] for regular widget trees (lobby livery
/// picker) — centres the car at its native 1:2 aspect inside any canvas.
class GrandPrixCarPreviewPainter extends CustomPainter {
  GrandPrixCarPreviewPainter(this.spec) : _style = GrandPrixCarStyle(spec);

  final GrandPrixLiverySpec spec;
  final GrandPrixCarStyle _style;

  /// Car width as a fraction of its length.
  static const double aspect = 0.52;

  @override
  void paint(Canvas canvas, Size size) {
    final carW = min(size.width, size.height * aspect);
    final carH = carW / aspect;
    canvas.save();
    canvas.translate((size.width - carW) / 2, (size.height - carH) / 2);
    paintGrandPrixCar(canvas, carW, carH, _style);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GrandPrixCarPreviewPainter oldDelegate) =>
      oldDelegate.spec != spec;
}
