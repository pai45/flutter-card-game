import 'dart:ui' as ui;
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/spotlight_walkthrough.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<int> pixel(WidgetTester tester, GlobalKey scene, Offset point) async {
  return (await tester.runAsync(() async {
    final boundary =
        scene.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    final offset = (point.dy.toInt() * image.width + point.dx.toInt()) * 4;
    final rgba = bytes.buffer.asUint8List();
    final argb =
        (rgba[offset + 3] << 24) |
        (rgba[offset] << 16) |
        (rgba[offset + 1] << 8) |
        rgba[offset + 2];
    image.dispose();
    return argb;
  }))!;
}

Widget app(GameBloc bloc, GlobalKey scene, Widget child) => BlocProvider.value(
  value: bloc,
  child: RepaintBoundary(
    key: scene,
    child: MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(backgroundColor: Cyber.cyan, body: child),
    ),
  ),
);

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  testWidgets('scaled targets stay clear and surrounding pixels are dimmed', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    final scene = GlobalKey(), target = GlobalKey();
    await tester.pumpWidget(
      app(
        bloc,
        scene,
        Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 80,
              top: 160,
              child: Transform.scale(
                scale: 0.5,
                alignment: Alignment.topLeft,
                child: SpotlightTarget(
                  spotlightKey: target,
                  child: const SizedBox(
                    width: 200,
                    height: 100,
                    child: ColoredBox(color: Cyber.success),
                  ),
                ),
              ),
            ),
            SpotlightTutorial(
              keyName: 'scaled-test',
              cardAnchor: SpotlightCardAnchor.bottom,
              steps: [
                SpotlightStep(
                  targetKey: target,
                  title: 'Scaled card',
                  body: 'Keep the actual card visible.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      await pixel(tester, scene, const Offset(100, 180)),
      Cyber.success.toARGB32(),
    );
    expect(
      await pixel(tester, scene, const Offset(205, 180)),
      isNot(Cyber.cyan.toARGB32()),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('GOT IT >'));
    await tester.pump();
    expect(find.text('SCALED CARD'), findsNothing);
  });

  testWidgets(
    'overlapping clear regions stay bright and allow only target taps',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = GameBloc(SecureGameStorage());
      addTearDown(bloc.close);
      final scene = GlobalKey(), target = GlobalKey(), inner = GlobalKey();
      var targetTaps = 0, outsideTaps = 0, completed = 0;
      await tester.pumpWidget(
        app(
          bloc,
          scene,
          Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 20,
                top: 20,
                child: GestureDetector(
                  onTap: () => outsideTaps++,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: ColoredBox(color: Cyber.cyan),
                  ),
                ),
              ),
              Positioned(
                left: 80,
                top: 160,
                child: SpotlightTarget(
                  spotlightKey: target,
                  child: SizedBox(
                    width: 200,
                    height: 100,
                    child: ColoredBox(
                      color: Cyber.success,
                      child: Center(
                        child: SizedBox(
                          key: inner,
                          width: 80,
                          height: 40,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => targetTaps++,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SpotlightTutorial(
                keyName: 'overlap-test',
                onComplete: () => completed++,
                cardAnchor: SpotlightCardAnchor.bottom,
                steps: [
                  SpotlightStep(
                    targetKey: target,
                    interactiveKeys: [inner],
                    title: 'Clear overlap',
                    body: 'Try the highlighted region.',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        await pixel(tester, scene, const Offset(180, 210)),
        Cyber.success.toARGB32(),
      );
      await tester.tapAt(const Offset(180, 210));
      await tester.tapAt(const Offset(40, 40));
      expect(targetTaps, 1);
      expect(outsideTaps, 0);
      await tester.tap(find.text('GOT IT >'));
      await tester.pump();
      expect(completed, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'scroll target is revealed immediately and disposal removes the coach',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final bloc = GameBloc(SecureGameStorage());
      addTearDown(bloc.close);
      final scene = GlobalKey(), target = GlobalKey();
      await tester.pumpWidget(
        app(
          bloc,
          scene,
          Stack(
            fit: StackFit.expand,
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 900),
                    SpotlightTarget(
                      spotlightKey: target,
                      child: const SizedBox(
                        width: 100,
                        height: 80,
                        child: ColoredBox(color: Cyber.success),
                      ),
                    ),
                    const SizedBox(height: 900),
                  ],
                ),
              ),
              SpotlightTutorial(
                keyName: 'scroll-test',
                cardAnchor: SpotlightCardAnchor.bottom,
                steps: [
                  SpotlightStep(
                    targetKey: target,
                    title: 'Scrolled card',
                    body: 'This card is visible.',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(target)).top, inInclusiveRange(0, 650));
      expect(find.text('SCROLLED CARD'), findsOneWidget);
      await tester.pumpWidget(app(bloc, scene, const SizedBox.shrink()));
      await tester.pump();
      expect(find.text('SCROLLED CARD'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a reused phase coach replaces its old target and completion identity',
    (tester) async {
      final bloc = GameBloc(SecureGameStorage());
      addTearDown(bloc.close);
      final scene = GlobalKey(), target = GlobalKey();
      Widget guide(String name) => app(
        bloc,
        scene,
        Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: 40,
              top: 80,
              child: SizedBox(
                key: target,
                width: 100,
                height: 60,
                child: const ColoredBox(color: Cyber.success),
              ),
            ),
            SpotlightTutorial(
              keyName: name,
              steps: [
                SpotlightStep(
                  targetKey: target,
                  title: name,
                  body: 'The next phase needs its own guide.',
                ),
              ],
            ),
          ],
        ),
      );
      await tester.pumpWidget(guide('first'));
      await tester.pumpAndSettle();
      expect(find.text('FIRST'), findsOneWidget);
      await tester.pumpWidget(guide('second'));
      await tester.pumpAndSettle();
      expect(find.text('FIRST'), findsNothing);
      expect(find.text('SECOND'), findsOneWidget);
      await tester.tap(find.text('GOT IT >'));
      await tester.pumpAndSettle();
      expect(bloc.state.tutorialSeen, contains('second'));
      expect(bloc.state.tutorialSeen, isNot(contains('first')));
    },
  );
}
