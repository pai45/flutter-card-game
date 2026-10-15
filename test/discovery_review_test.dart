// Opt-in actual Flutter card captures, outside the source tree.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/config/theme.dart';
import 'package:card_game/widgets/cyber/cyber_game_launch_card.dart';
import 'package:card_game/widgets/cyber/game_discovery.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final output = Platform.environment['DISCOVERY_REVIEW_DIR'];
  testWidgets(
    'capture all real discovery cards in narrow and wide layouts',
    (tester) async {
      await tester.runAsync(() async {
        for (final font in [
          ['Orbitron', 'assets/fonts/Orbitron-VariableFont_wght.ttf'],
          ['Space Grotesk', 'assets/fonts/SpaceGrotesk-VariableFont_wght.ttf'],
          ['MaterialIcons', 'fonts/MaterialIcons-Regular.otf'],
        ]) {
          final loader = FontLoader(font[0])..addFont(rootBundle.load(font[1]));
          await loader.load();
        }
      });
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final games = gameDiscoveryData['games'] as Map<String, dynamic>;
      for (final entry in games.entries) {
        final data = entry.value as Map<String, dynamic>;
        final game = ArcadeGame.values.firstWhere(
          (game) => game.name == data['flutter'],
        );
        final accent = Color(
          int.parse(
            (data['accent'] as String).replaceFirst('#', 'FF'),
            radix: 16,
          ),
        );
        for (final layout in ['narrow', 'wide', 'enlarged']) {
          final key = GlobalKey();
          final wide = layout == 'wide';
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(1000, 800),
                  disableAnimations: true,
                  textScaler: TextScaler.linear(layout == 'enlarged' ? 1.4 : 1),
                ),
                child: Center(
                  child: RepaintBoundary(
                    key: key,
                    child: SizedBox(
                      width: wide ? 420 : 210,
                      height: wide ? 240 : 330,
                      child: CyberGameLaunchCard(
                        title: data['title'] as String,
                        subtitle:
                            '${(data['sport'] as String).toUpperCase()} // ${data['kind']}',
                        badge: 'STATOZ // ${data['sport']}',
                        action: 'ENTER THE GAME',
                        art: CyberGameArt.tactics,
                        game: game,
                        accent: accent,
                        onTap: () {},
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} $layout',
          );
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(output!).create(recursive: true);
            await File(
              '$output/${entry.key}-$layout.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      }
    },
    skip: output == null,
  );
}
