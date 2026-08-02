import 'package:final_over/domain/domain.dart';
import 'package:final_over/game/contact_ball_flight.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const viewport = Size(393, 852);
  const origin = Offset(196.5, 650);

  test('every shot clears its edge before the camera handoff', () {
    const lastVisibleContactProgress = 0.95;
    final ballRadius = viewport.shortestSide * 0.014;

    for (final direction in ShotDirection.values) {
      final endpoint = contactBallFlightPoint(
        viewport: viewport,
        origin: origin,
        direction: direction,
        elevation: Elevation.ground,
        power: 0.65,
        progress: lastVisibleContactProgress,
      );

      switch (direction) {
        case ShotDirection.offSide:
          expect(endpoint.dx, lessThan(-ballRadius));
        case ShotDirection.straight:
          expect(endpoint.dy, lessThan(-ballRadius));
        case ShotDirection.legSide:
          expect(endpoint.dx, greaterThan(viewport.width + ballRadius));
        case ShotDirection.behind:
          expect(endpoint.dy, greaterThan(viewport.height + ballRadius));
      }
    }
  });

  test('flight advances continuously toward the chosen edge', () {
    for (final direction in ShotDirection.values) {
      final midpoint = contactBallFlightPoint(
        viewport: viewport,
        origin: origin,
        direction: direction,
        elevation: Elevation.ground,
        power: 0.65,
        progress: 0.5,
      );
      final endpoint = contactBallFlightPoint(
        viewport: viewport,
        origin: origin,
        direction: direction,
        elevation: Elevation.ground,
        power: 0.65,
        progress: 1,
      );

      expect(midpoint, isNot(origin));
      expect(
        (midpoint - origin).distance,
        lessThan((endpoint - origin).distance),
      );
    }
  });

  test('loft adds an arc but still exits through the selected edge', () {
    final groundMidpoint = contactBallFlightPoint(
      viewport: viewport,
      origin: origin,
      direction: ShotDirection.behind,
      elevation: Elevation.ground,
      power: 0.8,
      progress: 0.5,
    );
    final midpoint = contactBallFlightPoint(
      viewport: viewport,
      origin: origin,
      direction: ShotDirection.behind,
      elevation: Elevation.loft,
      power: 0.8,
      progress: 0.5,
    );
    final endpoint = contactBallFlightPoint(
      viewport: viewport,
      origin: origin,
      direction: ShotDirection.behind,
      elevation: Elevation.loft,
      power: 0.8,
      progress: 1,
    );

    expect(midpoint.dy, lessThan(groundMidpoint.dy));
    expect(midpoint.dy, greaterThan(origin.dy));
    expect(endpoint.dy, greaterThan(viewport.height));
  });
}
