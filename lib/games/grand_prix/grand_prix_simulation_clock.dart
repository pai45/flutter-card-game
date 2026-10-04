import 'dart:math';

/// 120 Hz simulation with render interpolation and bounded hitch catch-up.
/// 20/30/60/120 Hz renderers advance the same simulated time. Background time
/// is deliberately discarded by pause(), rather than fast-forwarding a race.
class GrandPrixSimulationClock {
  static const step = 1 / 120;
  static const maxCatchUpSteps = 24;
  double _accumulator = 0;

  double get interpolation => (_accumulator / step).clamp(0.0, 1.0);

  int advance(double dt, bool Function(double dt) tick) {
    if (!dt.isFinite || dt <= 0) return 0;
    _accumulator += min(dt, step * maxCatchUpSteps);
    var steps = 0;
    while (_accumulator + 1e-10 >= step && steps < maxCatchUpSteps) {
      _accumulator = max(0, _accumulator - step);
      steps++;
      if (!tick(step)) {
        reset();
        break;
      }
    }
    return steps;
  }

  void reset() => _accumulator = 0;
}
