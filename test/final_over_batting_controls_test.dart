import 'dart:ui' as ui;

import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_game/config/theme.dart';
import 'package:card_game/data/final_over_kits.dart';
import 'package:card_game/games/final_over/final_over_game.dart';
import 'package:card_game/screens/final_over/widgets/final_over_controls.dart';
import 'package:card_game/screens/final_over/widgets/final_over_hud.dart';
import 'package:card_game/screens/final_over/widgets/final_over_swing_surface.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';

void main() {
  group('classifyBattingGesture', () {
    test('a short press is a grounded straight tap', () {
      final gesture = classifyBattingGesture(delta: const Offset(6, -4));
      expect(gesture.isSwipe, isFalse);
      expect(gesture.direction, ShotDirection.straight);
      expect(gesture.elevation, Elevation.ground);
    });

    test('a leftward swipe aims off side along the ground', () {
      final gesture = classifyBattingGesture(delta: const Offset(-70, 0));
      expect(gesture.isSwipe, isTrue);
      expect(gesture.direction, ShotDirection.offSide);
      expect(gesture.elevation, Elevation.ground);
    });

    test('a rightward swipe aims leg side along the ground', () {
      final gesture = classifyBattingGesture(delta: const Offset(70, 0));
      expect(gesture.direction, ShotDirection.legSide);
      expect(gesture.elevation, Elevation.ground);
    });

    test('an upward swipe lofts it straight', () {
      final gesture = classifyBattingGesture(delta: const Offset(0, -70));
      expect(gesture.direction, ShotDirection.straight);
      expect(gesture.elevation, Elevation.loft);
    });

    test('an up-left swipe lofts it toward the off side', () {
      final gesture = classifyBattingGesture(delta: const Offset(-70, -70));
      expect(gesture.direction, ShotDirection.offSide);
      expect(gesture.elevation, Elevation.loft);
    });

    test('a fast flat flick still lofts', () {
      final gesture = classifyBattingGesture(
        delta: const Offset(60, -4),
        velocity: 1400,
      );
      expect(gesture.direction, ShotDirection.legSide);
      expect(gesture.elevation, Elevation.loft);
    });
  });

  testWidgets('the batting deck shows a status strip, not a CTA or pickers', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MatchController();
    addTearDown(controller.dispose);
    final game = _gameFor(controller);
    controller.startMatch(seed: 77, target: 10);
    controller.dispatch(const StartCommand());
    game.update(1 / 60);

    await tester.pumpWidget(
      _controlsApp(game: game, size: const Size(360, 800), showHints: true),
    );

    // No more HOLD TO SWING button, SHOT LOCKED strip, or GROUND/LOFT/aim
    // pickers — the swing moved onto the pitch.
    expect(find.text('HOLD TO SWING'), findsNothing);
    expect(find.text('RELEASE AT THE BAT'), findsNothing);
    expect(find.text('SHOT LOCKED'), findsNothing);
    expect(find.text('GROUND'), findsNothing);
    expect(find.text('LOFT'), findsNothing);
    expect(find.text('READ THE BALL'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(_controlStackKey)).height,
      lessThanOrEqualTo(140),
    );

    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.bowlerRunUp,
    );
    game.update(0.001);
    await _settle(tester);
    expect(find.text('WATCH THE RELEASE'), findsOneWidget);
    expect(find.text('HOLD TO SWING'), findsNothing);

    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.incomingBall,
    );
    game.update(0.001);
    await _settle(tester);
    expect(find.text('TAP TO HIT'), findsOneWidget);
    expect(find.text('HOLD TO SWING'), findsNothing);
  });

  testWidgets('a tap anywhere on the pitch plays a grounded straight drive', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MatchController();
    addTearDown(controller.dispose);
    final game = _gameFor(controller);
    controller.startMatch(seed: 77, target: 10);
    controller.dispatch(const StartCommand());
    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.incomingBall,
    );
    game.update(1 / 60);

    await tester.pumpWidget(_surfaceApp(game));
    await tester.pump();
    expect(game.canSwing.value, isTrue);

    final gesture = await tester.startGesture(const Offset(180, 400));
    final expectedContact =
        controller.state.currentDelivery!.expectedContactMicros;
    _advanceUntil(
      controller,
      () => controller.state.simulationMicros >= expectedContact,
    );
    await gesture.up();

    expect(controller.state.swingIntent, isNotNull);
    expect(controller.state.swingIntent!.direction, ShotDirection.straight);
    expect(controller.state.selectedElevation, Elevation.ground);
    expect(controller.state.contactOutcome, isNotNull);
  });

  testWidgets('a right-up swipe on the pitch lofts it to the leg side', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MatchController();
    addTearDown(controller.dispose);
    final game = _gameFor(controller);
    controller.startMatch(seed: 77, target: 10);
    controller.dispatch(const StartCommand());
    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.incomingBall,
    );
    game.update(1 / 60);

    await tester.pumpWidget(_surfaceApp(game));
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(140, 500));
    await gesture.moveBy(const Offset(80, -70));
    final expectedContact =
        controller.state.currentDelivery!.expectedContactMicros;
    _advanceUntil(
      controller,
      () => controller.state.simulationMicros >= expectedContact,
    );
    await gesture.up();

    expect(controller.state.swingIntent!.direction, ShotDirection.legSide);
    expect(controller.state.selectedElevation, Elevation.loft);
  });

  test('a swing command can aim and loft the shot mid-delivery', () {
    final controller = MatchController();
    addTearDown(controller.dispose);
    controller.startMatch(seed: 77, target: 10);
    controller.dispatch(const StartCommand());
    _advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.incomingBall,
    );
    final expectedContact =
        controller.state.currentDelivery!.expectedContactMicros;
    _advanceUntil(
      controller,
      () => controller.state.simulationMicros >= expectedContact,
    );
    expect(controller.state.canSwing, isTrue);

    controller.dispatch(
      const SwingCommand(ShotDirection.legSide, elevation: Elevation.loft),
    );

    expect(controller.state.swingIntent, isNotNull);
    expect(controller.state.swingIntent!.direction, ShotDirection.legSide);
    expect(controller.state.swingIntent!.charge, isNull);
    expect(controller.state.selectedElevation, Elevation.loft);
    expect(controller.state.contactOutcome, isNotNull);
  });

  for (final size in const [
    Size(360, 800),
    Size(393, 852),
    Size(412, 915),
    Size(480, 1040),
  ]) {
    testWidgets('batting deck stays compact at '
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
        lessThanOrEqualTo(140),
      );
      expect(tester.takeException(), isNull);

      _advanceUntil(
        controller,
        () => controller.state.phase == MatchPhase.bowlerRunUp,
      );
      game.update(0.001);
      await _settle(tester);
      expect(
        tester.getSize(find.byKey(_controlStackKey)).height,
        lessThanOrEqualTo(140),
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
    expect(find.text('OD'), findsNothing);
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

Widget _surfaceApp(FinalOverGame game) => MaterialApp(
  home: Scaffold(
    backgroundColor: Cyber.bg,
    body: SizedBox(
      width: 360,
      height: 800,
      child: FinalOverSwingSurface(game: game),
    ),
  ),
);

Future<void> _settle(WidgetTester tester) async {
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
