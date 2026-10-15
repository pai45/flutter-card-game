import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/widgets/cyber/match_discovery.dart';

void main() {
  Widget host(
    Widget child, {
    bool reduced = false,
    PageStorageBucket? bucket,
  }) => MaterialApp(
    theme: AppTheme.darkTheme,
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 600),
        disableAnimations: reduced,
      ),
      child: Scaffold(
        body: PageStorage(bucket: bucket ?? PageStorageBucket(), child: child),
      ),
    ),
  );
  double opacity(WidgetTester tester, Key key) => tester
      .widget<Opacity>(
        find
            .descendant(of: find.byKey(key), matching: find.byType(Opacity))
            .first,
      )
      .opacity;
  testWidgets('reduced motion exposes the composed card immediately', (
    tester,
  ) async {
    const key = ValueKey('reduced');
    await tester.pumpWidget(
      host(
        const EditorialPlate(
          key: key,
          motionId: 'reduced',
          child: Text('Instant card'),
        ),
        reduced: true,
      ),
    );
    expect(opacity(tester, key), 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'entrance waits for visibility, pauses in background and does not replay',
    (tester) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final scroll = ScrollController(), bucket = PageStorageBucket();
      const key = ValueKey('visible');
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            controller: scroll,
            child: const Column(
              children: [
                SizedBox(height: 900),
                EditorialPlate(
                  key: key,
                  motionId: 'visible',
                  child: SizedBox(height: 100, child: Text('Viewport card')),
                ),
                SizedBox(height: 500),
              ],
            ),
          ),
          bucket: bucket,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(opacity(tester, key), 0);
      scroll.jumpTo(750);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 100));
      final midway = opacity(tester, key);
      expect(midway, greaterThan(0));
      expect(midway, lessThan(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(milliseconds: 200));
      expect(opacity(tester, key), midway);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(tester, key), 1);
      scroll.jumpTo(0);
      await tester.pump();
      scroll.jumpTo(750);
      await tester.pump();
      expect(opacity(tester, key), 1);
      const returned = ValueKey('returned');
      await tester.pumpWidget(
        host(
          const EditorialPlate(
            key: returned,
            motionId: 'visible',
            child: Text('Returning card'),
          ),
          bucket: bucket,
        ),
      );
      expect(opacity(tester, returned), 1);
      expect(tester.takeException(), isNull);
      scroll.dispose();
    },
  );
  testWidgets('activation stays immediate during entrance', (tester) async {
    var taps = 0;
    const key = ValueKey('activate');
    await tester.pumpWidget(
      host(
        EditorialPlate(
          key: key,
          motionId: 'activate',
          onTap: () => taps++,
          child: const Text('Open now'),
        ),
      ),
    );
    await tester.tap(find.text('Open now'));
    expect(taps, 1);
    await tester.pump();
    expect(opacity(tester, key), 1);
    expect(tester.takeException(), isNull);
  });
  test('event percentage ink retains its hue with readable contrast', () {
    final ink = editorialEventInk(AppTheme.darkInk);
    expect(
      (ink.computeLuminance() + .05) /
          (const Color(0xff0f1826).computeLuminance() + .05),
      greaterThanOrEqualTo(4.5),
    );
    expect(editorialEventInk(Colors.white), Colors.white);
  });
}
