import 'dart:ui';

import 'package:card_game/blocs/super_over/super_over_state.dart';
import 'package:card_game/games/super_over/super_over_game.dart';
import 'package:card_game/models/super_over.dart';
import 'package:card_game/screens/super_over/widgets/final_stand_match_hud.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await (FontLoader('Orbitron')..addFont(
          rootBundle.load('assets/fonts/Orbitron-VariableFont_wght.ttf'),
        ))
        .load();
    await (FontLoader(
          'Onest',
        )..addFont(rootBundle.load('assets/fonts/Onest-VariableFont_wght.ttf')))
        .load();
  });

  test('every outcome stays in the elevated batting-end camera', () {
    for (final outcome in ShotOutcome.values) {
      final state = _outcomeState(
        outcome: outcome,
        contactType: outcome == ShotOutcome.dot
            ? SuperOverContactType.leave
            : SuperOverContactType.played,
      );
      final game = _game(state)..syncState(state);
      game.update(.35);

      expect(game.debugTopViewActive, isFalse, reason: outcome.name);
      expect(game.debugCameraMode, 'batting-end', reason: outcome.name);
      _expectRenders(game, const Size(393, 852));
    }
  });

  test(
    'delivery, contact and reduced-motion frames render deterministically',
    () {
      final delivery = const SuperOverState(
        phase: SuperOverPhase.ballSetup,
        playPhase: SuperOverPlayPhase.runUp,
        fieldSectors: [2, 4, 3],
        selectedSector: ShotSector.v,
        selectedShotStyle: ShotStyle.ground,
        deliveryPlan: DeliveryPlan(type: DeliveryType.pace),
      );
      final game = _game(delivery)..startDelivery(delivery);
      game.update(1.30);
      _expectRenders(game, const Size(393, 852));

      game.tapBat(sector: ShotSector.v, style: ShotStyle.ground);
      game.update(.08);
      _expectRenders(game, const Size(393, 852));

      for (final type in DeliveryType.values) {
        final variant = SuperOverState(
          phase: SuperOverPhase.runUp,
          playPhase: SuperOverPlayPhase.runUp,
          fieldSectors: const [2, 4, 3],
          deliveryPlan: DeliveryPlan(
            type: type,
            length: type == DeliveryType.yorker
                ? DeliveryLength.yorker
                : type == DeliveryType.spin
                ? DeliveryLength.full
                : DeliveryLength.good,
          ),
        );
        final variantGame = _game(variant)..startDelivery(variant);
        variantGame.update(.92);
        _expectRenders(variantGame, const Size(393, 852));
      }

      final reducedState = _outcomeState(
        outcome: ShotOutcome.six,
        contactType: SuperOverContactType.played,
        settings: const SuperOverSettings(reducedMotion: true),
      );
      final reduced = _game(reducedState)
        ..reducedMotion = true
        ..syncState(reducedState)
        ..update(.55);
      _expectRenders(reduced, const Size(393, 852));
    },
  );

  test('the perspective scene renders across supported portrait sizes', () {
    final state = _outcomeState(
      outcome: ShotOutcome.two,
      contactType: SuperOverContactType.played,
    );
    for (final size in const [Size(360, 800), Size(393, 852), Size(430, 932)]) {
      final game = _game(state)..syncState(state);
      game.update(.62);
      _expectRenders(game, size);
    }
  });

  testWidgets('representative gameplay-world golden frames', (tester) async {
    final cases = <(String, SuperOverGame)>[
      (
        'four-ground',
        _outcomeGame(ShotOutcome.four, style: ShotStyle.ground, elapsed: .72),
      ),
      (
        'six-loft',
        _outcomeGame(ShotOutcome.six, style: ShotStyle.loft, elapsed: .72),
      ),
      (
        'caught',
        _outcomeGame(ShotOutcome.caught, style: ShotStyle.loft, elapsed: .82),
      ),
      (
        'bowled',
        _outcomeGame(ShotOutcome.bowled, style: ShotStyle.ground, elapsed: .32),
      ),
    ];

    for (final entry in cases) {
      final image = await _renderImage(entry.$2, const Size(393, 852));
      await expectLater(
        image,
        matchesGoldenFile('goldens/super_over_world_${entry.$1}.png'),
      );
    }
  });

  testWidgets('live HUD leaves the delivery lane and striker readable', (
    tester,
  ) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (_) async => null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const state = SuperOverState(
      phase: SuperOverPhase.runUp,
      playPhase: SuperOverPlayPhase.runUp,
      mode: SuperOverMode.chase,
      cpuTarget: 9,
      fieldSectors: [2, 4, 3],
      selectedSector: ShotSector.v,
      selectedShotStyle: ShotStyle.ground,
      deliveryPlan: DeliveryPlan(type: DeliveryType.pace),
    );
    final game = _game(state)..startDelivery(state);
    game.update(1.30);

    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: const ValueKey('super-over-live-composition'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _GamePainter(game)),
              FinalStandMatchHud(
                state: state,
                onBatTap: _noop,
                onExit: _noop,
                onPause: _noop,
                onSectorSelected: _ignoreSector,
                onShotStyleSelected: _ignoreStyle,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await expectLater(
      find.byKey(const ValueKey('super-over-live-composition')),
      matchesGoldenFile('goldens/super_over_live_composition.png'),
    );
  });
}

void _noop() {}
void _ignoreSector(ShotSector _) {}
void _ignoreStyle(ShotStyle _) {}

class _GamePainter extends CustomPainter {
  const _GamePainter(this.game);

  final SuperOverGame game;

  @override
  void paint(Canvas canvas, Size size) {
    game.onGameResize(Vector2(size.width, size.height));
    game.render(canvas);
  }

  @override
  bool shouldRepaint(covariant _GamePainter oldDelegate) => false;
}

void _expectRenders(SuperOverGame game, Size size) {
  game.onGameResize(Vector2(size.width, size.height));
  final recorder = PictureRecorder();
  game.render(Canvas(recorder));
  expect(recorder.endRecording(), isNotNull);
}

Future<Image> _renderImage(SuperOverGame game, Size size) {
  game.onGameResize(Vector2(size.width, size.height));
  final recorder = PictureRecorder();
  game.render(Canvas(recorder));
  return recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
}

SuperOverGame _outcomeGame(
  ShotOutcome outcome, {
  required ShotStyle style,
  required double elapsed,
}) {
  final state = _outcomeState(
    outcome: outcome,
    contactType: SuperOverContactType.played,
    style: style,
  );
  return _game(state)
    ..syncState(state)
    ..update(elapsed);
}

SuperOverGame _game(SuperOverState state) => SuperOverGame(
  initialState: state,
  onPhaseChanged: (_) {},
  onInputArmed: () {},
  onBallBounce: () {},
  onSwingLocked: () {},
  onShotResolved: (_) {},
  onNoInput: () {},
  onOutcomeAnimationComplete: () {},
);

SuperOverState _outcomeState({
  required ShotOutcome outcome,
  required SuperOverContactType contactType,
  ShotStyle style = ShotStyle.loft,
  SuperOverSettings settings = const SuperOverSettings(),
}) {
  final committed = SuperOverCommittedBall(
    ballNumber: 1,
    planningSeed: 9,
    fieldPlan: SuperOverFieldPlan.fromCounts(const [2, 4, 3]),
    delivery: const DeliveryPlan(),
  );
  final record = SuperOverBallRecord(
    ballNumber: 1,
    strikerCardId: 'one',
    nonStrikerCardId: 'two',
    committedBall: committed,
    intent: ShotIntent(sector: ShotSector.v, style: style, timingErrorMs: 0),
    contactType: contactType,
    timingErrorMs: 0,
    normalizedTimingError: 0,
    timingTier: TimingTier.perfect,
    drift: TimingDrift.none,
    resolvedSector: ShotSector.v,
    outcome: outcome,
    runs: SuperOverResolution.runsForOutcome(outcome),
    usedFinisherMode: false,
    rhythmBefore: 0,
    rhythmAfter: 20,
    scoreAfter: SuperOverResolution.runsForOutcome(outcome),
    wicketsAfter: outcome == ShotOutcome.bowled ? 1 : 0,
  );
  return SuperOverState(
    phase: SuperOverPhase.outcome,
    playPhase: SuperOverPlayPhase.outcome,
    settings: settings,
    lastOutcome: outcome,
    shotSector: ShotSector.v,
    selectedShotStyle: style,
    fieldSectors: const [2, 4, 3],
    fieldPlan: committed.fieldPlan,
    committedBall: committed,
    swingLocked: true,
    timingTier: TimingTier.perfect,
    ballRecords: [record],
    wagonWheel: [outcome],
    ballsFaced: 1,
  );
}
