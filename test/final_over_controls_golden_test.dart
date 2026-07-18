import 'package:final_over/final_over.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_game/config/theme.dart';
import 'package:card_game/data/final_over_kits.dart';
import 'package:card_game/games/final_over/final_over_game.dart';
import 'package:card_game/screens/final_over/widgets/final_over_controls.dart';
import 'package:card_game/screens/final_over/widgets/final_over_hud.dart';

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
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final state in const ['setup', 'live']) {
    testWidgets('Final Over $state control deck golden at 393x852', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (_) async => null,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final controller = MatchController(tuning: GameplayTuning.rookie);
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
      if (state == 'live') {
        _advanceUntil(controller, () => controller.state.canSwing);
      }
      game.update(0.001);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: RepaintBoundary(
            key: const ValueKey('final-over-controls-golden'),
            child: Material(
              color: Cyber.bg,
              child: TickerMode(
                enabled: false,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FinalOverOverdriveRail(game: game),
                      const SizedBox(height: 6),
                      FinalOverControls(
                        game: game,
                        showHints: state == 'setup',
                        rookieAssist: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await expectLater(
        find.byKey(const ValueKey('final-over-controls-golden')),
        matchesGoldenFile('goldens/final_over_controls_$state.png'),
      );
    });
  }
}

void _advanceUntil(MatchController controller, bool Function() predicate) {
  for (var tick = 0; tick < 1000 && !predicate(); tick++) {
    controller.step(const Duration(microseconds: 16667));
  }
  expect(predicate(), isTrue);
}
