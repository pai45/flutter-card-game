import 'dart:math';

import '../../models/grand_prix.dart';

double _smooth(double t) {
  final x = t.clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

/// Track-space centreline shared by physics, camera, scenery and route preview.
/// Chicanes ease at both ends, avoiding a heading snap at section boundaries.
double trackCenterlineX(
  GrandPrixCircuit circuit,
  List<double> starts,
  double s,
) {
  var x = 0.0;
  final clamped = s.clamp(0.0, circuit.lapLength);
  for (var i = 0; i < circuit.sections.length; i++) {
    final section = circuit.sections[i];
    if (clamped <= starts[i]) break;
    final t = ((clamped - starts[i]) / section.length).clamp(0.0, 1.0);
    switch (section.type) {
      case TrackSectionType.straight:
        break;
      case TrackSectionType.corner:
        x += section.signedBend * _smooth(t);
      case TrackSectionType.chicane:
        x += section.signedBend * sin(_smooth(t) * 2 * pi) * 0.5;
    }
  }
  return x;
}

class GrandPrixTrackSample {
  const GrandPrixTrackSample({
    required this.centerX,
    required this.slope,
    required this.sectionIndex,
  });

  final double centerX;
  final double slope;
  final int sectionIndex;
}

class GrandPrixCornerPreview {
  const GrandPrixCornerPreview({
    required this.distance,
    required this.safeSpeed,
    required this.direction,
    required this.chicane,
  });

  final double distance;
  final double safeSpeed;
  final CornerDirection direction;
  final bool chicane;
}

/// Cached two-metre samples. Total distance stays authoritative for ranking;
/// local distance identifies the repeated lap. Centreline offsets accumulate
/// across laps, so neither the road nor traffic teleports at the start line.
class GrandPrixTrackGeometry {
  GrandPrixTrackGeometry(this.circuit, this.starts) {
    final count = (circuit.lapLength / sampleStep).ceil();
    for (var i = 0; i <= count; i++) {
      _x.add(
        trackCenterlineX(
          circuit,
          starts,
          min(i * sampleStep, circuit.lapLength),
        ),
      );
    }
    lapShift = _x.last;
  }

  static const sampleStep = 2.0;
  final GrandPrixCircuit circuit;
  final List<double> starts;
  final List<double> _x = [];
  late final double lapShift;

  GrandPrixTrackSample sample(double distance) {
    if (distance <= 0) {
      return const GrandPrixTrackSample(centerX: 0, slope: 0, sectionIndex: 0);
    }
    final lap = distance ~/ circuit.lapLength;
    final local = distance - lap * circuit.lapLength;
    final index = min(_x.length - 2, (local / sampleStep).floor());
    final a = index * sampleStep;
    final b = min(a + sampleStep, circuit.lapLength);
    final t = ((local - a) / (b - a)).clamp(0.0, 1.0);
    var section = 0;
    for (var i = starts.length - 1; i >= 0; i--) {
      if (local >= starts[i]) {
        section = i;
        break;
      }
    }
    return GrandPrixTrackSample(
      centerX: lap * lapShift + _x[index] + (_x[index + 1] - _x[index]) * t,
      slope: (_x[index + 1] - _x[index]) / (b - a),
      sectionIndex: section,
    );
  }

  GrandPrixCornerPreview? cornerAhead(double distance, double raceLength) {
    final local = distance <= 0 ? distance : distance % circuit.lapLength;
    final lapBase = distance <= 0 ? 0.0 : distance - local;
    final current = sample(distance).sectionIndex;
    for (var step = 0; step < circuit.sections.length; step++) {
      final i = (current + step) % circuit.sections.length;
      final section = circuit.sections[i];
      if (section.isStraight) continue;
      final start = starts[i] + (i < current ? circuit.lapLength : 0);
      if (lapBase + start >= raceLength) return null;
      return GrandPrixCornerPreview(
        distance: max(0, start - local),
        safeSpeed: section.safeSpeed!,
        direction: section.direction!,
        chicane: section.type == TrackSectionType.chicane,
      );
    }
    return null;
  }

  double racingLine(double distance, double halfWidth) {
    final local = distance <= 0 ? distance : distance % circuit.lapLength;
    final index = sample(distance).sectionIndex;
    final section = circuit.sections[index];
    if (section.isStraight) {
      final upcoming = cornerAhead(distance, double.infinity);
      if (upcoming == null || upcoming.distance > 100) return 0;
      final inside = upcoming.direction == CornerDirection.left ? -1.0 : 1.0;
      return -inside * halfWidth * 0.4 * (1 - upcoming.distance / 100);
    }
    final t = ((local - starts[index]) / section.length).clamp(0.0, 1.0);
    final inside = section.direction == CornerDirection.left ? -1.0 : 1.0;
    if (section.type == TrackSectionType.chicane) {
      return inside * sin(t * 2 * pi) * halfWidth * 0.45;
    }
    return inside * halfWidth * (sin(t * pi) * 0.85 - 0.3);
  }
}
