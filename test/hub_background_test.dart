import 'package:card_game/widgets/cyber/cyber_hub_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget surface(
    HubBackgroundTheme theme, {
    bool reduce = false,
    double width = 412,
  }) => MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: Center(
        child: SizedBox(
          width: width,
          height: 800,
          child: CyberHubBackground(theme: theme),
        ),
      ),
    ),
  );

  testWidgets('every bundled world decodes at phone and wide sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 800.0]) {
      for (final theme in HubBackgroundTheme.values) {
        await tester.pumpWidget(surface(theme, width: width));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final visible = tester.widget<AnimatedOpacity>(
          find.byKey(ValueKey('hub-background-${theme.name}')),
        );
        expect(visible.opacity, 1);
        final format = width < 768 ? 'portrait' : 'wide';
        expect(
          find.byKey(ValueKey('hub-artwork-${theme.name}-$format')),
          findsOneWidget,
        );
      }
    }
  });

  testWidgets(
    'switches crossfade, rapid changes converge, reduced motion is immediate',
    (tester) async {
      await tester.pumpWidget(surface(HubBackgroundTheme.football));
      await tester.pumpAndSettle();
      await tester.pumpWidget(surface(HubBackgroundTheme.cricket));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpWidget(surface(HubBackgroundTheme.tennis));
      await tester.pumpAndSettle();
      for (final layer in tester.widgetList<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      )) {
        expect(
          layer.opacity,
          layer.key == const ValueKey('hub-background-tennis') ? 1 : 0,
        );
      }
      await tester.pumpWidget(
        surface(HubBackgroundTheme.trending, reduce: true),
      );
      await tester.pump();
      for (final layer in tester.widgetList<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      )) {
        expect(layer.duration, Duration.zero);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('backgrounds never intercept foreground taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps++,
              ),
            ),
            const Positioned.fill(
              child: CyberHubBackground(theme: HubBackgroundTheme.football),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(100, 100));
    expect(taps, 1);
    expect(find.byType(ExcludeSemantics), findsWidgets);
  });

  testWidgets('missing artwork leaves the navy fallback usable', (
    tester,
  ) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: _MissingArtworkBundle(),
        child: surface(HubBackgroundTheme.football),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CyberHubBackground), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MissingArtworkBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    if (key.endsWith('.svg')) throw FlutterError('Test: artwork unavailable');
    return rootBundle.load(key);
  }
}
