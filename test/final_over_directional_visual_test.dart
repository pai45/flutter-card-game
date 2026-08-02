import 'package:card_game/data/final_over_kits.dart';
import 'package:card_game/games/final_over/final_over_game.dart';
import 'package:final_over/final_over.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../final_over/test/application/test_support.dart';

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

  testWidgets('behind shot holds the directional contact frame', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = MatchController(
      deliveryGenerator: ScriptedDeliveryGenerator([
        scripted(line: DeliveryLine.leg, length: DeliveryLength.full),
      ]),
    );
    addTearDown(controller.dispose);
    controller.startMatch(seed: 11, target: 48);
    controller.dispatch(const GameCommand.start());
    advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.incomingBall,
    );
    final contactAt = controller.state.currentDelivery!.expectedContactMicros;
    advanceUntil(
      controller,
      () => controller.state.simulationMicros >= contactAt - 20000,
    );
    controller.dispatch(
      const GameCommand.swing(
        ShotDirection.behind,
        elevation: Elevation.ground,
      ),
    );
    advanceUntil(
      controller,
      () => controller.state.phase == MatchPhase.contact,
    );
    for (var frame = 0; frame < 13; frame++) {
      controller.step(const Duration(microseconds: 16667));
    }

    final game = FinalOverGame(
      controller: controller,
      kit: finalOverKitById('voltage'),
      opponentKit: finalOverOpponentKit('voltage'),
      onEvents: (_) {},
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('final-over-behind-contact'),
        child: SizedBox(width: 393, height: 852, child: GameWidget(game: game)),
      ),
    );
    await tester.pump();

    expect(controller.state.phase, MatchPhase.contact);
    expect(controller.state.contactOutcome?.direction, ShotDirection.behind);
    await expectLater(
      find.byKey(const ValueKey('final-over-behind-contact')),
      matchesGoldenFile('goldens/final_over_behind_contact.png'),
    );
  });
}
