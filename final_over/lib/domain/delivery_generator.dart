import 'deterministic_random.dart';
import 'gameplay_tuning.dart';
import 'models.dart';

class DeliveryGenerator {
  const DeliveryGenerator({this.tuning = const GameplayTuning()});

  final GameplayTuning tuning;

  DeliverySpec generate({
    required int matchSeed,
    required int physicalOrdinal,
    required int legalBalls,
    required int score,
    required int target,
    required List<BallResult> history,
    required List<DeliverySpec> previousDeliveries,
    int expectedContactMicros = 0,
  }) {
    if (physicalOrdinal < 1) {
      throw ArgumentError.value(physicalOrdinal, 'physicalOrdinal');
    }
    final seed = SeedStreams.seedFor(
      matchSeed,
      physicalOrdinal,
      RandomStream.delivery,
    );
    final random = DeterministicRandom(seed);
    final noBalls = history.where((r) => r.extra == ExtraType.noBall).length;
    final wides = history.where((r) => r.extra == ExtraType.wide).length;
    final fairFinalBall =
        legalBalls == tuning.maximumLegalBalls - 1 && target - score <= 6;

    var extra = ExtraType.none;
    if (physicalOrdinal > 1 && !fairFinalBall) {
      // No-ball has explicit precedence, so a delivery can never be both.
      if (noBalls < tuning.maximumNoBalls &&
          random.nextBool(tuning.noBallProbability)) {
        extra = ExtraType.noBall;
      } else if (wides < tuning.maximumWides &&
          random.nextBool(tuning.wideProbability)) {
        extra = ExtraType.wide;
      }
    }

    final line = fairFinalBall
        ? random.choose(const [
            DeliveryLine.off,
            DeliveryLine.middle,
            DeliveryLine.leg,
          ])
        : extra == ExtraType.wide
        ? random.choose(const [DeliveryLine.wideOff, DeliveryLine.wideLeg])
        : _weighted<DeliveryLine>(random, const {
            DeliveryLine.off: 30,
            DeliveryLine.middle: 34,
            DeliveryLine.leg: 28,
          });

    var length = fairFinalBall
        ? random.choose(const [DeliveryLength.full, DeliveryLength.good])
        : _weighted<DeliveryLength>(random, const {
            DeliveryLength.yorker: 22,
            DeliveryLength.full: 28,
            DeliveryLength.good: 32,
            DeliveryLength.short: 18,
          });
    if (previousDeliveries.length >= 2) {
      final previous = previousDeliveries[previousDeliveries.length - 1].length;
      final beforePrevious =
          previousDeliveries[previousDeliveries.length - 2].length;
      if (previous == beforePrevious &&
          previous == length &&
          (length == DeliveryLength.yorker || length == DeliveryLength.short)) {
        length = random.choose(const [
          DeliveryLength.full,
          DeliveryLength.good,
        ]);
      }
    }

    var movement = random.range(
      -tuning.maximumMovement,
      tuning.maximumMovement,
    );
    var speed = random.range(0.82, 1.08);
    if (physicalOrdinal == 1) speed *= 0.95;
    if (fairFinalBall) {
      movement = movement.clamp(-0.006, 0.006);
      speed = speed.clamp(0.82, 0.92);
    }

    return DeliverySpec(
      ordinal: physicalOrdinal,
      seed: seed,
      line: line,
      length: length,
      speed: speed,
      movement: movement,
      extra: extra,
      lineX: GameplayTuning.lineX[line]!,
      expectedContactMicros: expectedContactMicros,
      isFairFinalBall: fairFinalBall,
    );
  }

  T _weighted<T>(DeterministicRandom random, Map<T, int> weights) {
    final total = weights.values.fold<int>(0, (sum, weight) => sum + weight);
    var roll = random.nextInt(total);
    for (final entry in weights.entries) {
      if (roll < entry.value) return entry.key;
      roll -= entry.value;
    }
    return weights.keys.last;
  }
}
