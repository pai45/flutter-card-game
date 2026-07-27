import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../domain/models.dart';

/// Returns the presentation-only ball position during the contact beat.
///
/// The endpoint is deliberately beyond the batting viewport so the ball exits
/// in the played direction before the top-down field camera takes over.
Offset contactBallFlightPoint({
  required Size viewport,
  required Offset origin,
  required ShotDirection direction,
  required Elevation elevation,
  required double power,
  required double progress,
}) {
  final flightProgress = progress.clamp(0.0, 1.0);
  final normalizedPower = power.clamp(0.0, 1.0);
  final directionVector = switch (direction) {
    ShotDirection.offSide => const Offset(-1, 0),
    ShotDirection.straight => const Offset(0, -1),
    ShotDirection.legSide => const Offset(1, 0),
    ShotDirection.behind => const Offset(0, 1),
  };
  final distanceToEdge = switch (direction) {
    ShotDirection.offSide => math.max(0.0, origin.dx),
    ShotDirection.straight => math.max(0.0, origin.dy),
    ShotDirection.legSide => math.max(0.0, viewport.width - origin.dx),
    ShotDirection.behind => math.max(0.0, viewport.height - origin.dy),
  };
  // Include a distance-relative lead so even the longest route (usually the
  // straight drive toward the top edge) clears the viewport on the last
  // fixed-step contact frame, before the controller starts the camera blend.
  final overshoot =
      distanceToEdge * 0.065 +
      viewport.shortestSide * (0.012 + normalizedPower * 0.020);
  final flatPoint =
      origin + directionVector * (distanceToEdge + overshoot) * flightProgress;
  final loftLift = elevation == Elevation.loft
      ? math.sin(math.pi * flightProgress) * viewport.height * 0.075
      : 0.0;
  return flatPoint.translate(0, -loftLift);
}
