import 'package:card_game/config/theme.dart';
import 'package:card_game/widgets/cyber/cyber_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _card({
  bool reduced = false,
  bool ticking = true,
  bool locked = false,
  double width = 361,
  double height = 208,
  double textScale = 1,
  CyberGameArt art = CyberGameArt.penalty,
  VoidCallback? onTap,
}) => MaterialApp(
  theme: AppTheme.darkTheme,
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reduced,
      textScaler: TextScaler.linear(textScale),
    ),
    child: TickerMode(
      enabled: ticking,
      child: Center(
        child: SizedBox(
          width: width,
          height: height,
          child: CyberGameLaunchCard(
            title: 'PENALTY SHOOTOUT',
            titleLines: const ['PENALTY', 'SHOOTOUT'],
            subtitle: 'SUDDEN-DEATH SPOT KICKS',
            badge: 'FEATURED // SUDDEN DEATH',
            action: 'TAKE THE SHOT',
            art: art,
            accent: Cyber.cyan,
            locked: locked,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('scene loops stop for reduced motion, covered routes and locks', (
    tester,
  ) async {
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);

    await tester.pumpWidget(_card(reduced: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.text('TAKE THE SHOT'), findsOneWidget);
    expect(find.byType(CyberGameIllustration), findsOneWidget);

    await tester.pumpWidget(_card());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(_card(ticking: false));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);

    await tester.pumpWidget(_card(locked: true));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('body, launch rail, keyboard and semantics activate one target', (
    tester,
  ) async {
    var launches = 0;
    await tester.pumpWidget(_card(reduced: true, onTap: () => launches++));
    await tester.tap(find.text('PENALTY'));
    expect(launches, 1);
    await tester.tap(find.text('TAKE THE SHOT'));
    expect(launches, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(launches, 3);
    expect(
      find.bySemanticsLabel('PENALTY SHOOTOUT, TAKE THE SHOT'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('all wireframe scenes paint in narrow and enlarged layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final art in CyberGameArt.values) {
      await tester.pumpWidget(
        _card(art: art, reduced: true, width: 138, height: 264, textScale: 1.4),
      );
      await tester.pumpAndSettle();
      expect(find.text('PENALTY'), findsOneWidget);
      expect(find.text('TAKE THE SHOT'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$art compact');
    }
    await tester.pumpWidget(
      _card(reduced: true, width: 288, height: 240, textScale: 1.4),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Enlarged landscape');
  });
}
