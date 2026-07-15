import 'package:final_over/application/match_controller.dart';
import 'package:final_over/domain/domain.dart';

final class ScriptedDeliveryGenerator extends DeliveryGenerator {
  ScriptedDeliveryGenerator(this.script);

  final List<DeliverySpec> script;
  int _index = 0;

  @override
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
    final source = script[_index.clamp(0, script.length - 1)];
    _index++;
    return DeliverySpec(
      ordinal: physicalOrdinal,
      seed: SeedStreams.seedFor(
        matchSeed,
        physicalOrdinal,
        RandomStream.delivery,
      ),
      line: source.line,
      length: source.length,
      speed: source.speed,
      movement: source.movement,
      extra: source.extra,
      lineX: GameplayTuning.lineX[source.line]!,
      expectedContactMicros: expectedContactMicros,
      isFairFinalBall: source.isFairFinalBall,
    );
  }
}

DeliverySpec scripted({
  DeliveryLine line = DeliveryLine.middle,
  DeliveryLength length = DeliveryLength.full,
  ExtraType extra = ExtraType.none,
  double speed = 0.9,
  double movement = 0,
}) => DeliverySpec(
  ordinal: 0,
  seed: 0,
  line: line,
  length: length,
  speed: speed,
  movement: movement,
  extra: extra,
  lineX: GameplayTuning.lineX[line]!,
  expectedContactMicros: 0,
);

void advanceUntil(
  MatchController controller,
  bool Function() predicate, {
  int maximumTicks = 3000,
}) {
  for (var tick = 0; tick < maximumTicks && !predicate(); tick++) {
    controller.step(const Duration(microseconds: 16667));
  }
  if (!predicate()) {
    throw StateError('Condition was not reached within $maximumTicks ticks');
  }
}
