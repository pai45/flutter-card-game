import 'dart:ui' as ui;

import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_game/data/final_over_kits.dart';
import 'package:card_game/games/final_over/final_over_game.dart';
import 'package:card_game/screens/final_over/widgets/final_over_controls.dart';
import 'package:card_game/widgets/cyber/cyber_cta_button.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';

void main() {
  testWidgets('countdown locks selections and HIT opens at ball release', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MatchController();
    addTearDown(controller.dispose);
    final game = FinalOverGame(
      controller: controller,
      kit: finalOverKitById('voltage'),
      opponentKit: finalOverOpponentKit('voltage'),
      onEvents: (_) {},
      reducedMotion: true,
    );

    controller.startMatch(seed: 77, target: 10);
    controller.dispatch(const StartCommand());
    game.update(1 / 60);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 800,
            child: FinalOverControls(
              game: game,
              showHints: true,
              rookieAssist: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('NEXT BALL'), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('GROUND'), findsOneWidget);
    expect(find.text('LOFT'), findsOneWidget);
    expect(find.text('OFF'), findsWidgets);
    expect(find.text('STRAIGHT'), findsOneWidget);
    expect(find.text('LEG'), findsWidgets);
    expect(find.text('WAIT'), findsOneWidget);
    expect(
      tester.widget<HudHoldCtaButton>(find.byType(HudHoldCtaButton)).enabled,
      isFalse,
    );

    controller.dispatch(const SelectDirectionCommand(ShotDirection.legSide));
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedDirection, ShotDirection.legSide);

    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.bowlerRunUp,
    );
    game.update(0.001);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('LOCKED'), findsOneWidget);
    controller.dispatch(const SelectDirectionCommand(ShotDirection.offSide));
    expect(controller.state.selectedDirection, ShotDirection.legSide);

    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.incomingBall,
    );
    game.update(0.001);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('HIT'), findsOneWidget);
    expect(
      tester.widget<HudHoldCtaButton>(find.byType(HudHoldCtaButton)).enabled,
      isTrue,
    );

    final cancelled = await tester.startGesture(
      tester.getCenter(find.text('HIT')),
    );
    await cancelled.cancel();
    expect(controller.state.swingIntent, isNull);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('HIT')),
    );
    final expectedContact =
        controller.state.currentDelivery!.expectedContactMicros;
    _advanceUntil(
      controller,
      () => controller.state.simulationMicros >= expectedContact,
    );
    await gesture.up();

    expect(controller.state.swingIntent, isNotNull);
    expect(controller.state.swingIntent!.direction, ShotDirection.legSide);
    expect(controller.state.swingIntent!.charge, closeTo(0.8, 0.03));
  });

  test('bounce progress and marker visibility follow delivery length', () {
    expect(finalOverBounceProgress(DeliveryLength.short), 0.42);
    expect(finalOverBounceProgress(DeliveryLength.good), 0.56);
    expect(finalOverBounceProgress(DeliveryLength.full), 0.70);
    expect(finalOverBounceProgress(DeliveryLength.yorker), 0.82);

    expect(
      finalOverShouldShowBounceMarker(
        phase: MatchPhase.deliveryPreparation,
        suspendedPhase: null,
        length: DeliveryLength.short,
        incomingProgress: 0,
      ),
      isTrue,
    );
    expect(
      finalOverShouldShowBounceMarker(
        phase: MatchPhase.paused,
        suspendedPhase: MatchPhase.incomingBall,
        length: DeliveryLength.full,
        incomingProgress: 0.69,
      ),
      isTrue,
    );
    expect(
      finalOverShouldShowBounceMarker(
        phase: MatchPhase.incomingBall,
        suspendedPhase: null,
        length: DeliveryLength.full,
        incomingProgress: 0.70,
      ),
      isFalse,
    );
    expect(
      finalOverShouldShowBounceMarker(
        phase: MatchPhase.contact,
        suspendedPhase: null,
        length: DeliveryLength.yorker,
        incomingProgress: 0,
      ),
      isFalse,
    );
  });

  test(
    'batting projection respects the control deck and delivery movement',
    () {
      const size = Size(360, 800);
      final projection = FinalOverBattingProjection.forViewport(
        size,
        controlDeckTop: 600,
      );
      expect(projection.nearY, 588);
      expect(projection.nearHalfWidth, closeTo(360 * 0.21 * 0.82, 0.001));

      const straight = DeliverySpec(
        ordinal: 1,
        seed: 9,
        line: DeliveryLine.middle,
        length: DeliveryLength.good,
        speed: 1,
        movement: 0,
        extra: ExtraType.none,
        lineX: 0,
        expectedContactMicros: 650000,
      );
      const movingOff = DeliverySpec(
        ordinal: 1,
        seed: 9,
        line: DeliveryLine.off,
        length: DeliveryLength.good,
        speed: 1,
        movement: -0.01,
        extra: ExtraType.none,
        lineX: -0.035,
        expectedContactMicros: 650000,
      );
      expect(projection.bouncePoint(straight).dx, projection.centerX);
      expect(
        projection.bouncePoint(movingOff).dx,
        lessThan(projection.bouncePoint(straight).dx),
      );

      final compact = FinalOverBattingProjection.forViewport(
        const Size(320, 568),
        controlDeckTop: 360,
      );
      expect(compact.nearY, lessThanOrEqualTo(348));
    },
  );

  test('chamfered action border paints the diagonal edge', () async {
    const size = Size(100, 50);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const ChamferedActionBorderPainter(
      clipper: HudChamferClipper(bigCut: 10, smallCut: 3),
      color: Colors.red,
      width: 2,
    ).paint(canvas, size);
    final image = await recorder.endRecording().toImage(100, 50);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect(data, isNotNull);

    int alphaAt(int x, int y) => data!.getUint8((y * 100 + x) * 4 + 3);
    var diagonalAlpha = 0;
    for (var y = 3; y <= 7; y++) {
      for (var x = 3; x <= 7; x++) {
        final alpha = alphaAt(x, y);
        if (alpha > diagonalAlpha) diagonalAlpha = alpha;
      }
    }
    expect(diagonalAlpha, greaterThan(0));
    expect(alphaAt(0, 0), 0);
  });
}

void _advanceUntil(MatchController controller, bool Function() predicate) {
  for (var tick = 0; tick < 1000 && !predicate(); tick++) {
    controller.step(const Duration(microseconds: 16667));
  }
  expect(predicate(), isTrue);
}
