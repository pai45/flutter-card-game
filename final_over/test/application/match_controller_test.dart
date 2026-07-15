import 'package:final_over/application/application.dart';
import 'package:final_over/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  group('match setup and authority', () {
    test(
      'three-second preparation reveals delivery and locks shot choices',
      () {
        final controller = MatchController();
        controller.startMatch(seed: 41, target: 10);
        controller.dispatch(const GameCommand.start());

        final preparedAt = controller.state.simulationMicros;
        final delivery = controller.state.currentDelivery!;
        expect(controller.state.phase, MatchPhase.deliveryPreparation);
        expect(controller.state.canConfigureShot, isTrue);
        expect(controller.state.selectedElevation, Elevation.ground);
        expect(controller.state.selectedDirection, ShotDirection.straight);
        expect(
          delivery.expectedContactMicros - preparedAt,
          3000000 + 900000 + 650000,
        );

        controller.dispatch(const GameCommand.selectElevation(Elevation.loft));
        controller.dispatch(
          const GameCommand.selectDirection(ShotDirection.legSide),
        );
        expect(controller.state.selectedElevation, Elevation.loft);
        expect(controller.state.selectedDirection, ShotDirection.legSide);

        for (var tick = 0; tick < 179; tick++) {
          controller.step(const Duration(microseconds: 16667));
        }
        expect(controller.state.phase, MatchPhase.deliveryPreparation);
        controller.step(const Duration(microseconds: 16667));
        expect(controller.state.phase, MatchPhase.bowlerRunUp);
        expect(controller.state.canConfigureShot, isFalse);

        controller.dispatch(
          const GameCommand.selectElevation(Elevation.ground),
        );
        controller.dispatch(
          const GameCommand.selectDirection(ShotDirection.offSide),
        );
        expect(controller.state.selectedElevation, Elevation.loft);
        expect(controller.state.selectedDirection, ShotDirection.legSide);
      },
    );

    test('pause freezes preparation and swing only opens at ball release', () {
      final controller = MatchController();
      controller.startMatch(seed: 42, target: 10);
      controller.dispatch(const GameCommand.start());
      for (var tick = 0; tick < 60; tick++) {
        controller.step(const Duration(microseconds: 16667));
      }
      final beforePause = controller.state.simulationMicros;
      controller.dispatch(const GameCommand.pause());
      for (var tick = 0; tick < 60; tick++) {
        controller.step(const Duration(microseconds: 16667));
      }
      expect(controller.state.simulationMicros, beforePause);

      controller.dispatch(const GameCommand.resume());
      controller.dispatch(
        const GameCommand.swing(ShotDirection.straight, charge: 0.8),
      );
      expect(controller.state.swingIntent, isNull);
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );
      expect(controller.state.canSwing, isTrue);
      controller.dispatch(
        const GameCommand.swing(ShotDirection.straight, charge: 0.8),
      );
      expect(controller.state.swingIntent, isNotNull);
      expect(controller.state.swingIntent!.charge, closeTo(0.8, 0.0001));
      expect(controller.state.canSwing, isFalse);
    });

    test('release-to-contact hold duration reaches ideal charge', () {
      const tuning = GameplayTuning();
      final heldSeconds =
          tuning.incomingToContactMicros / Duration.microsecondsPerSecond;
      expect(heldSeconds / tuning.chargeSeconds, closeTo(0.8, 0.0001));
    });

    test(
      'seeded start selects only approved targets and an eligible objective',
      () {
        final controller = MatchController();
        for (var seed = 0; seed < 100; seed++) {
          controller.startMatch(seed: seed);
          expect(
            GameplayTuning.targetOptions,
            contains(controller.state.target),
          );
          expect(controller.state.phase, MatchPhase.matchIntro);
          if (controller.state.objective == ObjectiveType.twoBoundaries) {
            expect(controller.state.target, greaterThanOrEqualTo(8));
          }
        }
      },
    );

    test('same seed and commands produce identical delivery state', () {
      final first = MatchController();
      final second = MatchController();
      first.startMatch(seed: 124, target: 14);
      second.startMatch(seed: 124, target: 14);
      first.dispatch(const GameCommand.start());
      second.dispatch(const GameCommand.start());

      for (var i = 0; i < 130; i++) {
        first.step(const Duration(microseconds: 16667));
        second.step(const Duration(microseconds: 16667));
      }

      expect(second.state.phase, first.state.phase);
      expect(second.state.simulationMicros, first.state.simulationMicros);
      expect(
        second.state.currentDelivery?.seed,
        first.state.currentDelivery?.seed,
      );
      expect(
        second.state.currentDelivery?.line,
        first.state.currentDelivery?.line,
      );
      expect(
        second.state.currentDelivery?.length,
        first.state.currentDelivery?.length,
      );
      expect(second.state.history.length, first.state.history.length);
    });

    test('duplicate swing is ignored', () {
      final generator = ScriptedDeliveryGenerator([scripted()]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 4, target: 14);
      controller.dispatch(const GameCommand.start());
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );

      controller.dispatch(const GameCommand.swing(ShotDirection.offSide));
      controller.dispatch(const GameCommand.swing(ShotDirection.legSide));

      expect(controller.state.swingIntent?.direction, ShotDirection.offSide);
    });

    test('state and gameplay streams expose authoritative updates', () {
      final controller = MatchController();
      final states = <MatchState>[];
      final events = <GameplayEvent>[];
      controller.stateStream.listen(states.add);
      controller.eventStream.listen(events.add);

      controller.startMatch(seed: 9, target: 14);
      controller.dispatch(const GameCommand.start());

      expect(states, isNotEmpty);
      expect(events.first.type, GameplayEventType.matchStarted);
      expect(
        events.any((event) => event.type == GameplayEventType.deliveryPrepared),
        isTrue,
      );
    });
  });

  group('pause and lifecycle', () {
    test('pause and background freeze simulation and restore exact phase', () {
      final controller = MatchController();
      controller.startMatch(seed: 3, target: 14);
      controller.dispatch(const GameCommand.start());
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );
      final phase = controller.state.phase;
      final elapsed = controller.state.phaseElapsedMicros;
      final simulation = controller.state.simulationMicros;

      controller.dispatch(const GameCommand.appBackgrounded());
      expect(controller.state.phase, MatchPhase.paused);
      expect(controller.state.suspendedPhase, phase);
      controller.step(const Duration(seconds: 5));
      expect(controller.state.simulationMicros, simulation);
      expect(controller.state.phaseElapsedMicros, elapsed);

      controller.dispatch(const GameCommand.resume());
      expect(controller.state.phase, phase);
      expect(controller.state.suspendedPhase, isNull);
      controller.step(const Duration(microseconds: 16667));
      expect(controller.state.simulationMicros, simulation + 16667);
    });
  });

  group('extras and Free Hit', () {
    test(
      'no-ball establishes Free Hit, wide preserves it, legal ball consumes it',
      () {
        final generator = ScriptedDeliveryGenerator([
          scripted(extra: ExtraType.noBall),
          scripted(line: DeliveryLine.wideOff, extra: ExtraType.wide),
          scripted(),
        ]);
        final controller = MatchController(deliveryGenerator: generator);
        controller.startMatch(seed: 1, target: 14);
        controller.dispatch(const GameCommand.start());

        advanceUntil(controller, () => controller.state.history.length == 1);
        expect(controller.state.freeHit, isTrue);
        expect(controller.state.legalBalls, 0);
        expect(controller.state.score, 1);

        advanceUntil(controller, () => controller.state.history.length == 2);
        expect(controller.state.freeHit, isTrue);
        expect(controller.state.legalBalls, 0);
        expect(controller.state.score, 2);

        advanceUntil(controller, () => controller.state.history.length == 3);
        expect(controller.state.freeHit, isFalse);
        expect(controller.state.legalBalls, 1);
        expect(controller.state.wickets, 0);
        expect(controller.state.history.last.freeHitDelivery, isTrue);
      },
    );

    test('target-winning no-ball extra finalizes before contact', () {
      final generator = ScriptedDeliveryGenerator([
        for (var i = 0; i < 5; i++)
          scripted(line: DeliveryLine.wideOff, extra: ExtraType.wide),
        scripted(extra: ExtraType.noBall),
      ]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 2, target: 6);
      controller.dispatch(const GameCommand.start());

      advanceUntil(controller, () => controller.state.isTerminal);

      expect(controller.state.phase, MatchPhase.won);
      expect(controller.state.score, 6);
      expect(controller.state.legalBalls, 0);
      expect(controller.state.physicalDeliveries, 6);
      expect(controller.state.history, hasLength(6));
      expect(controller.state.history.last.extra, ExtraType.noBall);
      expect(controller.state.history.last.contactType, ContactType.none);
      expect(controller.state.contactOutcome, isNull);
    });
  });

  group('terminal ordering and exact-once ledger', () {
    test('six legal dots are recorded before balls-exhausted loss', () {
      final generator = ScriptedDeliveryGenerator([
        for (var i = 0; i < 6; i++)
          scripted(line: DeliveryLine.wideOff, length: DeliveryLength.short),
      ]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 5, target: 14);
      controller.dispatch(const GameCommand.start());

      advanceUntil(controller, () => controller.state.isTerminal);

      expect(controller.state.phase, MatchPhase.lost);
      expect(controller.state.endReason, MatchEndReason.ballsExhausted);
      expect(controller.state.legalBalls, 6);
      expect(controller.state.history, hasLength(6));
      expect(controller.state.history.last.legalBallsBefore, 5);
    });

    test('two valid bowled wickets end the match', () {
      final generator = ScriptedDeliveryGenerator([scripted(), scripted()]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 7, target: 14);
      controller.dispatch(const GameCommand.start());

      advanceUntil(controller, () => controller.state.isTerminal);

      expect(controller.state.phase, MatchPhase.lost);
      expect(controller.state.endReason, MatchEndReason.wicketsLost);
      expect(controller.state.wickets, 2);
      expect(controller.state.legalBalls, 2);
      expect(
        controller.state.history.map((result) => result.dismissal),
        everyElement(DismissalType.bowled),
      );

      controller.step(const Duration(seconds: 10));
      expect(controller.state.history, hasLength(2));
      expect(controller.state.wickets, 2);
    });

    test('winning legal boundary commits once and records ball used', () {
      final generator = ScriptedDeliveryGenerator([
        scripted(line: DeliveryLine.off, length: DeliveryLength.full),
      ]);
      final controller = MatchController(
        tuning: const GameplayTuning(
          fielderSpeed: 0.01,
          catchRadius: 0.001,
          ballPickupRadius: 0.001,
        ),
        deliveryGenerator: generator,
      );
      controller.startMatch(seed: 5, target: 6);
      controller.dispatch(const GameCommand.start());
      controller.dispatch(const GameCommand.selectElevation(Elevation.loft));
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );
      final contactAt = controller.state.currentDelivery!.expectedContactMicros;
      advanceUntil(
        controller,
        () => controller.state.simulationMicros >= contactAt - 30000,
      );
      controller.dispatch(const GameCommand.swing(ShotDirection.offSide));

      advanceUntil(controller, () => controller.state.isTerminal);

      expect(controller.state.phase, MatchPhase.won);
      expect(controller.state.committedScore, 6);
      expect(controller.state.pendingBatRuns, 0);
      expect(controller.state.legalBalls, 1);
      expect(controller.state.history, hasLength(1));
      expect(controller.state.history.single.boundary, 6);
      expect(controller.state.history.single.legalBallsBefore, 0);
      expect(controller.state.stars, greaterThanOrEqualTo(2));
    });
  });

  group('running commands', () {
    test('Turn Back is accepted through 45 percent and scores no run', () {
      final generator = ScriptedDeliveryGenerator([
        scripted(line: DeliveryLine.off, length: DeliveryLength.full),
      ]);
      final controller = MatchController(deliveryGenerator: generator);
      controller.startMatch(seed: 17, target: 14);
      controller.dispatch(const GameCommand.start());
      controller.dispatch(const GameCommand.selectElevation(Elevation.ground));
      advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.incomingBall,
      );
      final contactAt = controller.state.currentDelivery!.expectedContactMicros;
      advanceUntil(
        controller,
        () => controller.state.simulationMicros >= contactAt - 30000,
      );
      controller.dispatch(const GameCommand.swing(ShotDirection.offSide));
      advanceUntil(controller, () => controller.state.canRun);
      controller.dispatch(const GameCommand.startRun());
      for (var i = 0; i < 15; i++) {
        controller.step(const Duration(microseconds: 16667));
      }
      expect(controller.state.runner.progress, lessThanOrEqualTo(0.45));
      controller.dispatch(const GameCommand.turnBack());
      expect(controller.state.runner.returning, isTrue);

      advanceUntil(controller, () => !controller.state.runner.active);
      expect(controller.state.pendingRuns, 0);
      expect(controller.state.runner.completedRuns, 0);
    });
  });
}
