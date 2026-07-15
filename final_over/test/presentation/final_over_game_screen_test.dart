import 'package:final_over/final_over.dart';
import 'package:final_over/services/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_support.dart';

void main() {
  testWidgets('embedded entry opens home, how-to, and match intro', (
    tester,
  ) async {
    useTestViewport(tester, const Size(393, 852));
    SharedPreferences.setMockInitialValues(<String, Object>{
      LocalSettingsService.soundKey: true,
      LocalSettingsService.vibrationKey: true,
    });
    final settingsService = LocalSettingsService(
      await SharedPreferences.getInstance(),
    );
    final audioBackend = RecordingAudioBackend();
    final hapticDriver = RecordingHapticDriver();

    await tester.pumpWidget(
      MaterialApp(
        home: FinalOverGameScreen(
          initialSeed: 2406,
          settingsService: settingsService,
          audioBackend: audioBackend,
          hapticDriver: hapticDriver,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FINAL'), findsOneWidget);
    expect(find.text('OVER'), findsOneWidget);
    expect(find.text('PLAY FINAL OVER'), findsOneWidget);

    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'HOW TO PLAY'), findsOneWidget);
    expect(find.text('GOT IT'), findsOneWidget);

    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PLAY FINAL OVER'));
    await tester.pump();

    expect(find.text('THE CHASE'), findsOneWidget);
    expect(find.text('CHASE NOW'), findsOneWidget);
    expect(audioBackend.loops, <String>['audio/ambience.wav']);
    expectNoBuildException(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(audioBackend.disposeCount, 1);
  });
}
