import 'package:final_over/presentation/gameplay_screen.dart';
import 'package:final_over/presentation/result_screen.dart';
import 'package:final_over/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_support.dart';

void main() {
  const portraitSizes = <Size>[
    Size(360, 800),
    Size(393, 852),
    Size(412, 915),
    Size(480, 1040),
  ];

  for (final size in portraitSizes) {
    testWidgets(
      'match intro and Flame view fit ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        useTestViewport(tester, size);
        final audioBackend = RecordingAudioBackend();
        final hapticDriver = RecordingHapticDriver();

        await tester.pumpWidget(
          finalOverTestApp(
            home: GameplayScreen(
              seed: 2406,
              settings: const FinalOverSettings(),
              audio: AudioService(backend: audioBackend),
              haptics: HapticsService(driver: hapticDriver),
              onSoundChanged: (_) {},
              onVibrationChanged: (_) {},
              onResult: (_) async {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text('THE CHASE'), findsOneWidget);
        expect(find.text('CHASE NOW'), findsOneWidget);
        expect(find.text('BACK HOME'), findsOneWidget);
        expect(audioBackend.loops, <String>['audio/ambience.wav']);
        expectNoBuildException(tester);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  }

  testWidgets(
    'intro, pause, lifecycle, system back, restart, and quit route correctly',
    (tester) async {
      useTestViewport(tester, const Size(393, 852));
      final audioBackend = RecordingAudioBackend();
      final hapticDriver = RecordingHapticDriver();
      GameResultSummary? routedResult;

      await tester.pumpWidget(
        finalOverTestApp(
          home: _GameplayRouteHarness(
            audio: AudioService(backend: audioBackend),
            haptics: HapticsService(driver: hapticDriver),
            onResult: (summary) async => routedResult = summary,
          ),
        ),
      );

      await tester.tap(find.text('OPEN MATCH'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('THE CHASE'), findsOneWidget);
      expect(find.text('CHASE NOW'), findsOneWidget);

      await tester.tap(find.text('CHASE NOW'));
      await tester.pump();
      expect(find.text('THE CHASE'), findsNothing);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);
      expect(find.text('RESUME'), findsOneWidget);
      expect(find.text('RESTART SAME CHASE'), findsOneWidget);

      await tester.tap(find.text('RESUME'));
      await tester.pump();
      expect(find.text('PAUSED'), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.tap(find.text('RESUME'));
      await tester.pump();
      expect(find.text('PAUSED'), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('PAUSED'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('PAUSED'), findsNothing);
      expect(find.byTooltip('Pause'), findsOneWidget);

      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.tap(find.text('RESTART SAME CHASE'));
      await tester.pump();
      expect(find.text('THE CHASE'), findsOneWidget);
      expect(find.text('CHASE NOW'), findsOneWidget);

      await tester.tap(find.text('CHASE NOW'));
      await tester.pump();
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.tap(find.text('QUIT TO HOME'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('OPEN MATCH'), findsOneWidget);
      expect(routedResult, isNull);
      expect(audioBackend.effects, isNotEmpty);
      expect(hapticDriver.lightCount, greaterThan(0));
      expectNoBuildException(tester);
    },
  );
}

class _GameplayRouteHarness extends StatelessWidget {
  const _GameplayRouteHarness({
    required this.audio,
    required this.haptics,
    required this.onResult,
  });

  final AudioService audio;
  final HapticsService haptics;
  final Future<void> Function(GameResultSummary) onResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: FilledButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GameplayScreen(
                  seed: 2406,
                  settings: const FinalOverSettings(),
                  audio: audio,
                  haptics: haptics,
                  onSoundChanged: (_) {},
                  onVibrationChanged: (_) {},
                  onResult: onResult,
                ),
              ),
            );
          },
          child: const Text('OPEN MATCH'),
        ),
      ),
    );
  }
}
