import 'package:final_over/application/application.dart';
import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('deterministic balance verification', () {
    test('replays the same seed range bit-for-bit', () async {
      final first = await _replayRange(seedStart: 7000, matches: 32);
      final replay = await _replayRange(seedStart: 7000, matches: 32);

      expect(replay, first);
      expect(first.maximumDurationMicros, lessThan(120000000));
      expect(first.physicalDeliveries, greaterThanOrEqualTo(first.legalBalls));
    });

    test('fixed bot sampler follows 20/50/22/6/2 timing weights', () {
      final counts = <String, int>{
        'perfect': 0,
        'good': 0,
        'earlyLate': 0,
        'poor': 0,
        'miss': 0,
      };
      const samples = 100000;
      for (var seed = 1; seed <= samples; seed++) {
        final bucket = _sampleTimingBucket(seed, 1);
        counts[bucket] = counts[bucket]! + 1;
      }

      expect(counts['perfect']! / samples, closeTo(0.20, 0.006));
      expect(counts['good']! / samples, closeTo(0.50, 0.006));
      expect(counts['earlyLate']! / samples, closeTo(0.22, 0.006));
      expect(counts['poor']! / samples, closeTo(0.06, 0.004));
      expect(counts['miss']! / samples, closeTo(0.02, 0.003));
    });

    test('release gate ranges match the approved MVP plan', () {
      expect(
        _gateFailures(
          winRate: 0.50,
          boundaryPerContactRate: 0.30,
          wicketPerLegalBallRate: 0.12,
          wideRate: 0.05,
          noBallRate: 0.02,
          maximumDurationSeconds: 119,
        ),
        isEmpty,
      );
      expect(
        _gateFailures(
          winRate: 0,
          boundaryPerContactRate: 0,
          wicketPerLegalBallRate: 0,
          wideRate: 0,
          noBallRate: 0,
          maximumDurationSeconds: 120,
        ),
        hasLength(6),
      );
    });
  });
}

final class _ReplaySummary {
  const _ReplaySummary({
    required this.fingerprint,
    required this.legalBalls,
    required this.physicalDeliveries,
    required this.maximumDurationMicros,
  });

  final int fingerprint;
  final int legalBalls;
  final int physicalDeliveries;
  final int maximumDurationMicros;

  @override
  bool operator ==(Object other) =>
      other is _ReplaySummary &&
      fingerprint == other.fingerprint &&
      legalBalls == other.legalBalls &&
      physicalDeliveries == other.physicalDeliveries &&
      maximumDurationMicros == other.maximumDurationMicros;

  @override
  int get hashCode => Object.hash(
    fingerprint,
    legalBalls,
    physicalDeliveries,
    maximumDurationMicros,
  );
}

Future<_ReplaySummary> _replayRange({
  required int seedStart,
  required int matches,
}) async {
  var fingerprint = 17;
  var legalBalls = 0;
  var physicalDeliveries = 0;
  var maximumDurationMicros = 0;
  for (var index = 0; index < matches; index++) {
    final controller = MatchController();
    try {
      controller.startMatch(seed: seedStart + index, target: 14);
      controller.dispatch(const GameCommand.start());
      var plannedOrdinal = 0;
      while (!controller.state.isTerminal &&
          controller.state.simulationMicros < 120000000) {
        final state = controller.state;
        final delivery = state.currentDelivery;
        if (delivery != null && delivery.ordinal != plannedOrdinal) {
          plannedOrdinal = delivery.ordinal;
          controller.dispatch(
            GameCommand.selectElevation(_bestElevation(delivery)),
          );
        }
        if (delivery != null &&
            state.phase == MatchPhase.incomingBall &&
            state.swingIntent == null &&
            state.simulationMicros >= delivery.expectedContactMicros) {
          controller.dispatch(GameCommand.swing(_bestDirection(delivery)));
        }
        if (_livePhase(state.phase) && state.canRun && !state.runner.active) {
          controller.dispatch(const GameCommand.holdBall());
        }
        controller.step(const Duration(microseconds: 16667));
      }
      final state = controller.state;
      expect(state.isTerminal, isTrue, reason: 'seed ${seedStart + index}');
      legalBalls += state.legalBalls;
      physicalDeliveries += state.history.length;
      if (state.simulationMicros > maximumDurationMicros) {
        maximumDurationMicros = state.simulationMicros;
      }
      fingerprint = Object.hash(
        fingerprint,
        state.matchSeed,
        state.phase,
        state.committedScore,
        state.legalBalls,
        state.wickets,
        Object.hashAll(
          state.history.map(
            (result) => Object.hash(
              result.deliveryOrdinal,
              result.historyToken,
              result.contactType,
              result.timing,
            ),
          ),
        ),
      );
    } finally {
      await controller.dispose();
    }
  }
  return _ReplaySummary(
    fingerprint: fingerprint,
    legalBalls: legalBalls,
    physicalDeliveries: physicalDeliveries,
    maximumDurationMicros: maximumDurationMicros,
  );
}

String _sampleTimingBucket(int matchSeed, int deliveryOrdinal) {
  final seed = DeterministicRandom.mix64(
    matchSeed ^ (deliveryOrdinal * 0xd1b54a32d192ed03) ^ 0x6a09e667f3bcc909,
  );
  final roll = DeterministicRandom(seed).nextInt(100);
  if (roll < 20) return 'perfect';
  if (roll < 70) return 'good';
  if (roll < 92) return 'earlyLate';
  if (roll < 98) return 'poor';
  return 'miss';
}

ShotDirection _bestDirection(DeliverySpec delivery) => switch (delivery.line) {
  DeliveryLine.wideOff || DeliveryLine.off => ShotDirection.offSide,
  DeliveryLine.middle => ShotDirection.straight,
  DeliveryLine.leg || DeliveryLine.wideLeg => ShotDirection.legSide,
};

Elevation _bestElevation(DeliverySpec delivery) => switch (delivery.length) {
  DeliveryLength.yorker || DeliveryLength.full => Elevation.ground,
  DeliveryLength.good || DeliveryLength.short => Elevation.loft,
};

bool _livePhase(MatchPhase phase) =>
    phase == MatchPhase.cameraTransition ||
    phase == MatchPhase.fieldPlay ||
    phase == MatchPhase.runDecision ||
    phase == MatchPhase.runnersMoving ||
    phase == MatchPhase.throwInProgress;

List<String> _gateFailures({
  required double winRate,
  required double boundaryPerContactRate,
  required double wicketPerLegalBallRate,
  required double wideRate,
  required double noBallRate,
  required double maximumDurationSeconds,
}) {
  final failures = <String>[];
  void check(double value, double minimum, double maximum, String label) {
    if (value < minimum || value > maximum) failures.add(label);
  }

  check(winRate, 0.35, 0.65, 'win rate');
  check(boundaryPerContactRate, 0.18, 0.38, 'boundary/contact rate');
  check(wicketPerLegalBallRate, 0.07, 0.18, 'wicket/legal-ball rate');
  check(wideRate, 0.02, 0.08, 'wide rate');
  check(noBallRate, 0.005, 0.04, 'no-ball rate');
  if (maximumDurationSeconds >= 120) failures.add('duration');
  return failures;
}
