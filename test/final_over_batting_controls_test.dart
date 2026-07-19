import 'dart:ui' as ui;

import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_game/config/theme.dart';
import 'package:card_game/data/final_over_kits.dart';
import 'package:card_game/games/final_over/final_over_game.dart';
import 'package:card_game/screens/final_over/widgets/final_over_controls.dart';
import 'package:card_game/screens/final_over/widgets/final_over_hud.dart';
import 'package:card_game/widgets/cyber/cyber_cta_button.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';

void main() {
  testWidgets('gesture setup collapses into a clear hold and release CTA', (
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
      _controlsApp(game: game, size: const Size(360, 800), showHints: true),
    );

    expect(find.text('NEXT BALL'), findsNothing);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('GROUND'), findsOneWidget);
    expect(find.text('LOFT'), findsOneWidget);
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('STRAIGHT'), findsOneWidget);
    expect(find.text('LEG'), findsOneWidget);
    expect(find.text('WAIT'), findsNothing);
    expect(find.text('OVERDRIVE'), findsOneWidget);
    expect(find.byType(HudHoldCtaButton), findsNothing);
    expect(
      tester.getSize(find.byKey(_controlStackKey)).height,
      lessThanOrEqualTo(184),
    );
    await tester.tap(find.text('OVERDRIVE'));
    game.update(0.001);
    await tester.pump();
    expect(controller.state.powerShotArmed, isFalse);

    await tester.tap(find.byKey(const ValueKey('shot-type-loft')));
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedElevation, Elevation.loft);

    await _dragAim(tester, const Offset(-38, -34));
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedDirection, ShotDirection.offSide);

    await _dragAim(tester, const Offset(0, -38));
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedDirection, ShotDirection.straight);

    await _dragAim(tester, const Offset(38, -34));
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedDirection, ShotDirection.legSide);

    final aimRect = tester.getRect(find.byKey(_aimFanKey));
    final cancelled = await tester.startGesture(
      Offset(aimRect.center.dx, aimRect.bottom - 8),
    );
    await cancelled.moveBy(const Offset(-38, -34));
    await cancelled.cancel();
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedDirection, ShotDirection.legSide);

    final semantics = tester.ensureSemantics();
    await tester.tap(find.text('OFF'));
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedDirection, ShotDirection.offSide);

    final aimNode = tester.getSemantics(find.byKey(_aimFanKey));
    final aimSemantics = find.semantics.byLabel('Shot direction');
    expect(
      aimNode.getSemanticsData().hasAction(ui.SemanticsAction.increase),
      isTrue,
    );
    tester.semantics.increase(aimSemantics);
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedDirection, ShotDirection.straight);

    final updatedAimNode = tester.getSemantics(find.byKey(_aimFanKey));
    expect(
      updatedAimNode.getSemanticsData().hasAction(ui.SemanticsAction.decrease),
      isTrue,
    );
    tester.semantics.decrease(aimSemantics);
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedDirection, ShotDirection.offSide);
    semantics.dispose();

    await tester.tap(find.text('LEG'));
    game.update(0.001);
    await tester.pump();
    expect(controller.state.selectedDirection, ShotDirection.legSide);

    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.bowlerRunUp,
    );
    game.update(0.001);
    await _settleLockTransition(tester);
    expect(find.text('SHOT LOCKED'), findsOneWidget);
    expect(find.text('LOFT  •  LEG'), findsOneWidget);
    expect(find.text('WATCH THE RELEASE'), findsOneWidget);
    expect(find.byKey(_aimFanKey), findsNothing);
    expect(find.byType(HudHoldCtaButton), findsNothing);
    expect(
      tester.getSize(find.byKey(_controlStackKey)).height,
      lessThanOrEqualTo(124),
    );
    controller.dispatch(const SelectDirectionCommand(ShotDirection.offSide));
    expect(controller.state.selectedDirection, ShotDirection.legSide);

    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.incomingBall,
    );
    game.update(0.001);
    await tester.pump(const Duration(milliseconds: 220));
    expect(find.text('HOLD TO SWING'), findsOneWidget);
    expect(find.text('RELEASE AT THE BAT'), findsOneWidget);
    expect(
      tester.widget<HudHoldCtaButton>(find.byType(HudHoldCtaButton)).enabled,
      isTrue,
    );

    final cancelledSwing = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO SWING')),
    );
    await tester.pump();
    expect(find.text('RELEASE TO SWING'), findsOneWidget);
    expect(find.text('TIME THE RELEASE'), findsOneWidget);
    await cancelledSwing.cancel();
    await tester.pump();
    expect(controller.state.swingIntent, isNull);
    expect(find.text('HOLD TO SWING'), findsOneWidget);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO SWING')),
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
    expect(controller.state.swingIntent!.charge, isNull);
  });

  for (final size in const [
    Size(360, 800),
    Size(393, 852),
    Size(412, 915),
    Size(480, 1040),
  ]) {
    testWidgets('compact deck fits setup and locked states at '
        '${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = MatchController(tuning: GameplayTuning.rookie);
      addTearDown(controller.dispose);
      final game = _gameFor(controller);
      controller.startMatch(seed: 77, target: 10);
      controller.dispatch(const StartCommand());
      game.update(1 / 60);

      await tester.pumpWidget(_controlsApp(game: game, size: size));
      expect(
        tester.getSize(find.byKey(_controlStackKey)).height,
        lessThanOrEqualTo(184),
      );
      expect(tester.takeException(), isNull);

      _advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.bowlerRunUp,
      );
      game.update(0.001);
      await _settleLockTransition(tester);
      expect(
        tester.getSize(find.byKey(_controlStackKey)).height,
        lessThanOrEqualTo(124),
      );
      expect(find.text('WATCH THE RELEASE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Overdrive rail is the sole manual charged action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const tuning = GameplayTuning(powerShotSegments: 0);
    final controller = MatchController(tuning: tuning);
    addTearDown(controller.dispose);
    final game = _gameFor(controller);
    controller.startMatch(seed: 77, target: 10);
    controller.dispatch(const StartCommand());
    game.update(1 / 60);

    await tester.pumpWidget(
      _controlsApp(game: game, size: const Size(393, 852)),
    );
    expect(find.text('OVERDRIVE READY • TAP TO ARM'), findsOneWidget);
    expect(tester.getSize(find.byType(FinalOverOverdriveRail)).height, 44);
    expect(controller.state.powerShotArmed, isFalse);

    await tester.tap(find.text('OVERDRIVE READY • TAP TO ARM'));
    game.update(0.001);
    await tester.pump();
    expect(controller.state.powerShotArmed, isTrue);
    expect(find.text('OVERDRIVE ARMED'), findsOneWidget);

    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.bowlerRunUp,
    );
    game.update(0.001);
    await tester.pump(const Duration(milliseconds: 180));
    expect(find.text('OVERDRIVE ARMED'), findsNothing);
    expect(find.text('OD'), findsOneWidget);
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

const _controlStackKey = ValueKey<String>('final-over-control-stack');
const _aimFanKey = ValueKey<String>('final-over-shot-aim');

FinalOverGame _gameFor(MatchController controller) => FinalOverGame(
  controller: controller,
  kit: finalOverKitById('voltage'),
  opponentKit: finalOverOpponentKit('voltage'),
  onEvents: (_) {},
  reducedMotion: true,
);

Widget _controlsApp({
  required FinalOverGame game,
  required Size size,
  bool showHints = false,
}) {
  return MaterialApp(
    home: Scaffold(
      backgroundColor: Cyber.bg,
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            key: _controlStackKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FinalOverOverdriveRail(game: game),
                const SizedBox(height: 6),
                FinalOverControls(
                  game: game,
                  showHints: showHints,
                  rookieAssist: true,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _dragAim(WidgetTester tester, Offset delta) async {
  final rect = tester.getRect(find.byKey(_aimFanKey));
  final gesture = await tester.startGesture(
    Offset(rect.center.dx, rect.bottom - 8),
  );
  await gesture.moveBy(delta);
  await gesture.up();
}

Future<void> _settleLockTransition(WidgetTester tester) async {
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void _advanceUntil(MatchController controller, bool Function() predicate) {
  for (var tick = 0; tick < 1000 && !predicate(); tick++) {
    controller.step(const Duration(microseconds: 16667));
  }
  expect(predicate(), isTrue);
}
