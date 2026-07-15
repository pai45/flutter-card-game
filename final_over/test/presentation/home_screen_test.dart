import 'package:final_over/presentation/home_screen.dart';
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
      'home renders without overflow at ${size.width.toInt()}x${size.height.toInt()}',
      (tester) async {
        useTestViewport(tester, size);

        await tester.pumpWidget(
          finalOverTestApp(
            home: HomeScreen(
              settings: const FinalOverSettings(),
              onPlay: () {},
              onSoundChanged: (_) {},
              onVibrationChanged: (_) {},
            ),
          ),
        );
        await tester.pump();

        expect(find.text('FINAL'), findsOneWidget);
        expect(find.text('OVER'), findsOneWidget);
        expect(find.text('PLAY FINAL OVER'), findsOneWidget);
        expect(find.text('HOW TO PLAY'), findsOneWidget);
        expectNoBuildException(tester);
      },
    );
  }

  testWidgets('how-to dialog and home controls are interactive', (
    tester,
  ) async {
    useTestViewport(tester, const Size(393, 852));
    bool? sound;
    bool? vibration;
    var playCount = 0;

    await tester.pumpWidget(
      finalOverTestApp(
        home: HomeScreen(
          settings: const FinalOverSettings(),
          onPlay: () => playCount++,
          onSoundChanged: (value) => sound = value,
          onVibrationChanged: (value) => vibration = value,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Sound on'));
    await tester.tap(find.byTooltip('Vibration on'));
    expect(sound, isFalse);
    expect(vibration, isFalse);

    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, 'HOW TO PLAY'), findsOneWidget);
    expect(
      find.text('Choose GROUND for safety or LOFT for aerial power.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Reach the target before six legal balls or two wickets are used.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('GOT IT'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);

    await tester.tap(find.text('PLAY FINAL OVER'));
    expect(playCount, 1);
    expectNoBuildException(tester);
  });
}
