import 'package:card_game/config/theme.dart';
import 'package:card_game/models/progression.dart';
import 'package:card_game/widgets/level_up_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required List<int> levels,
  required PlayerProgression progression,
  required int xpEarned,
  required VoidCallback onDismissed,
  bool reducedMotion = false,
}) {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: LevelUpCelebration(
          levels: levels,
          progression: progression,
          xpEarned: xpEarned,
          onDismissed: onDismissed,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('reveals a single promotion and waits for CONTINUE', (
    tester,
  ) async {
    var dismissals = 0;

    await tester.pumpWidget(
      _harness(
        levels: const [6],
        progression: const PlayerProgression(totalXP: 1515),
        xpEarned: 25,
        onDismissed: () => dismissals++,
      ),
    );
    await tester.pump();

    expect(find.text('PROMOTION CONFIRMED'), findsOneWidget);
    expect(find.byKey(const ValueKey('level-up-continue')), findsNothing);

    await tester.tapAt(const Offset(180, 320));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(dismissals, 0);
    expect(find.byKey(const ValueKey('level-up-continue')), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('LEVEL UP'), findsOneWidget);
    expect(find.text('LVL 05'), findsOneWidget);
    expect(find.text('LVL 06'), findsOneWidget);
    expect(find.text('+25'), findsOneWidget);
    expect(find.text('15 / 600 XP'), findsOneWidget);
    expect(find.text('NEXT // LVL 7'), findsOneWidget);
    expect(find.byKey(const ValueKey('level-up-continue')), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    expect(dismissals, 0);

    await tester.tap(find.byKey(const ValueKey('level-up-continue')));
    await tester.pump();
    expect(dismissals, 1);

    await tester.tap(find.byKey(const ValueKey('level-up-continue')));
    await tester.pump();
    expect(dismissals, 1);
  });

  testWidgets(
    'plays every queued promotion before settling on the final level',
    (tester) async {
      await tester.pumpWidget(
        _harness(
          levels: const [6, 7],
          progression: const PlayerProgression(totalXP: 2120),
          xpEarned: 630,
          onDismissed: () {},
        ),
      );
      await tester.pump();

      expect(find.text('01 // 02'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1800));
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('02 // 02'), findsOneWidget);
      expect(find.byKey(const ValueKey('level-up-continue')), findsNothing);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(find.text('LVL 06'), findsOneWidget);
      expect(find.text('LVL 07'), findsOneWidget);
      expect(find.text('20 / 700 XP'), findsOneWidget);
      expect(find.text('NEXT // LVL 8'), findsOneWidget);
      expect(find.byKey(const ValueKey('level-up-continue')), findsOneWidget);
    },
  );

  testWidgets(
    'reduced motion renders the settled accessible state immediately',
    (tester) async {
      final semantics = tester.ensureSemantics();
      var dismissed = false;

      await tester.pumpWidget(
        _harness(
          levels: const [6],
          progression: const PlayerProgression(totalXP: 1515),
          xpEarned: 25,
          reducedMotion: true,
          onDismissed: () => dismissed = true,
        ),
      );
      await tester.pump();

      expect(
        find.bySemanticsLabel('Level 6 reached. 15 of 600 XP toward level 7.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Continue'), findsOneWidget);
      expect(find.byKey(const ValueKey('level-up-continue')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('level-up-continue')));
      await tester.pump();
      expect(dismissed, isTrue);
      semantics.dispose();
    },
  );

  for (final size in [const Size(360, 640), const Size(430, 932)]) {
    testWidgets('fits without overflow at ${size.width}x${size.height}', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        _harness(
          levels: const [12],
          progression: const PlayerProgression(totalXP: 6650),
          xpEarned: 26,
          reducedMotion: true,
          onDismissed: () {},
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('level-up-celebration')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('level-up-progress-panel')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('level-up-continue')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
