import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

BallResult resultFor(ExtraType extra) => BallResult(
  deliveryOrdinal: 1,
  legalBallsBefore: 0,
  legal: extra == ExtraType.none,
  extra: extra,
  extraRuns: extra == ExtraType.none ? 0 : 1,
  runsOffBat: 0,
  completedRunningRuns: 0,
  boundary: 0,
  dismissal: DismissalType.none,
  contactType: ContactType.none,
  timing: TimingGrade.miss,
  freeHitDelivery: false,
  historyToken: '0',
);

void main() {
  const generator = DeliveryGenerator();

  test('same match seed and physical ordinal repeat exactly', () {
    DeliverySpec make() => generator.generate(
      matchSeed: 99,
      physicalOrdinal: 3,
      legalBalls: 1,
      score: 2,
      target: 14,
      history: const [],
      previousDeliveries: const [],
    );

    final first = make();
    final second = make();
    expect(second.seed, first.seed);
    expect(second.line, first.line);
    expect(second.length, first.length);
    expect(second.speed, first.speed);
    expect(second.movement, first.movement);
    expect(second.extra, first.extra);
  });

  test('first physical ball is legal, reachable, and slowed', () {
    for (var seed = 0; seed < 200; seed++) {
      final ball = generator.generate(
        matchSeed: seed,
        physicalOrdinal: 1,
        legalBalls: 0,
        score: 0,
        target: 14,
        history: const [],
        previousDeliveries: const [],
      );
      expect(ball.extra, ExtraType.none);
      expect(
        ball.line,
        isNot(anyOf(DeliveryLine.wideOff, DeliveryLine.wideLeg)),
      );
      expect(ball.speed, lessThanOrEqualTo(1.08 * 0.95));
    }
  });

  test('extra caps are enforced', () {
    final history = [
      resultFor(ExtraType.noBall),
      resultFor(ExtraType.wide),
      resultFor(ExtraType.wide),
    ];
    for (var seed = 0; seed < 2000; seed++) {
      final ball = generator.generate(
        matchSeed: seed,
        physicalOrdinal: 5,
        legalBalls: 2,
        score: 4,
        target: 14,
        history: history,
        previousDeliveries: const [],
      );
      expect(ball.extra, ExtraType.none);
    }
  });

  test('a third consecutive yorker or short ball is prevented', () {
    DeliverySpec previous(DeliveryLength length, int ordinal) => DeliverySpec(
      ordinal: ordinal,
      seed: ordinal,
      line: DeliveryLine.middle,
      length: length,
      speed: 0.9,
      movement: 0,
      extra: ExtraType.none,
      lineX: 0,
      expectedContactMicros: 0,
    );

    for (final length in [DeliveryLength.yorker, DeliveryLength.short]) {
      final prior = [previous(length, 1), previous(length, 2)];
      for (var seed = 0; seed < 500; seed++) {
        final ball = generator.generate(
          matchSeed: seed,
          physicalOrdinal: 3,
          legalBalls: 2,
          score: 0,
          target: 14,
          history: const [],
          previousDeliveries: prior,
        );
        expect(ball.length, isNot(length));
      }
    }
  });

  test('final legal delivery is fair when six or fewer are needed', () {
    for (var seed = 0; seed < 500; seed++) {
      final ball = generator.generate(
        matchSeed: seed,
        physicalOrdinal: 7,
        legalBalls: 5,
        score: 8,
        target: 14,
        history: const [],
        previousDeliveries: const [],
      );
      expect(ball.isFairFinalBall, isTrue);
      expect(ball.extra, ExtraType.none);
      expect(ball.length, anyOf(DeliveryLength.full, DeliveryLength.good));
      expect(
        ball.line,
        anyOf(DeliveryLine.off, DeliveryLine.middle, DeliveryLine.leg),
      );
      expect(ball.movement.abs(), lessThanOrEqualTo(0.006));
      expect(ball.speed, lessThanOrEqualTo(0.92));
    }
  });

  test('uncapped generation stays near intended extra rates', () {
    var wides = 0;
    var noBalls = 0;
    const count = 10000;
    for (var seed = 0; seed < count; seed++) {
      final ball = generator.generate(
        matchSeed: seed,
        physicalOrdinal: 2,
        legalBalls: 1,
        score: 0,
        target: 14,
        history: const [],
        previousDeliveries: const [],
      );
      if (ball.extra == ExtraType.wide) wides++;
      if (ball.extra == ExtraType.noBall) noBalls++;
    }
    expect(wides / count, inInclusiveRange(0.035, 0.065));
    expect(noBalls / count, inInclusiveRange(0.012, 0.030));
  });
}
