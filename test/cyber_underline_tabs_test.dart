import 'package:card_game/config/sport_modules.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/cyber/cyber_underline_tabs.dart';
import 'package:card_game/widgets/cyber/sport_underline_tabs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers.global'),
          (_) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('xyz.luan/audioplayers'),
          (_) async => null,
        );
    AudioController.instance.muted.value = true;
  });

  testWidgets('sport icons retain identity colors and active underline moves', (
    tester,
  ) async {
    var activeIndex = 0;
    const accents = [Cyber.cyan, AppTheme.whiteColor];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CyberUnderlineTabs(
              labels: const ['FOOTBALL', 'CRICKET'],
              icons: const [Icons.sports_soccer, Icons.sports_cricket],
              iconColors: accents,
              activeIndex: activeIndex,
              accent: accents[activeIndex],
              onTap: (index) => setState(() => activeIndex = index),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<Icon>(find.byIcon(Icons.sports_soccer)).color,
      Cyber.cyan,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.sports_cricket)).color,
      AppTheme.whiteColor.withValues(alpha: 0.58),
    );
    final initialIndicator = tester.widget<AnimatedPositioned>(
      find.byType(AnimatedPositioned),
    );
    final initialLeft = initialIndicator.left;

    await tester.tap(find.byIcon(Icons.sports_cricket));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Icon>(find.byIcon(Icons.sports_soccer)).color,
      Cyber.cyan.withValues(alpha: 0.58),
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.sports_cricket)).color,
      AppTheme.whiteColor,
    );
    final movedIndicator = tester.widget<AnimatedPositioned>(
      find.byType(AnimatedPositioned),
    );
    expect(movedIndicator.left, greaterThan(initialLeft!));
    final indicatorBox = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AnimatedPositioned),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect(
      (indicatorBox.decoration as BoxDecoration).color,
      AppTheme.whiteColor,
    );
  });

  testWidgets(
    'hub exposes canonical colors without making inactive tabs glow',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SportHubTabs(
              activeIndex: hubTrendingTabIndex,
              onTap: (_) {},
              onMore: () {},
            ),
          ),
        ),
      );

      expect(
        tester
            .widget<Icon>(find.byIcon(Icons.local_fire_department_rounded))
            .color,
        Cyber.cyan,
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.sports_soccer)).color,
        Cyber.cyan.withValues(alpha: 0.58),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.sports_cricket)).color,
        AppTheme.whiteColor.withValues(alpha: 0.58),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.sports_basketball)).color,
        Cyber.gold.withValues(alpha: 0.58),
      );
      expect(
        tester.widget<Icon>(find.byIcon(Icons.sports_tennis)).color,
        Cyber.lime.withValues(alpha: 0.58),
      );
      expect(find.byIcon(Icons.sports_motorsports), findsNothing);

      final indicator = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AnimatedPositioned),
          matching: find.byType(DecoratedBox),
        ),
      );
      final decoration = indicator.decoration as BoxDecoration;
      expect(decoration.color, Cyber.cyan);
      expect(decoration.boxShadow, hasLength(1));
    },
  );
}
