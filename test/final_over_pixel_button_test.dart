import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/final_over/widgets/final_over_pixel_play_button.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AudioController.debugUseBackend(_SilentAudio());
    AudioController.instance.muted.value = true;
  });
  testWidgets(
    'pixel play action supports keyboard, pressed travel and disabled/loading protection',
    (tester) async {
      var calls = 0;
      Future<void> mount({bool enabled = true, bool loading = false}) =>
          tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.darkTheme,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: FinalOverPixelPlayButton(
                      label: 'TAKE GUARD',
                      onTap: enabled ? () => calls++ : null,
                      loading: loading,
                    ),
                  ),
                ),
              ),
            ),
          );
      await mount();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(calls, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(calls, 2);
      final label = find.text('TAKE GUARD');
      final initial = tester.getTopLeft(label);
      final press = await tester.startGesture(tester.getCenter(label));
      await tester.pump();
      expect(tester.getTopLeft(label).dy, initial.dy + 4);
      await press.up();
      await tester.pump();
      expect(calls, 3);
      expect(tester.getTopLeft(label).dy, initial.dy);
      await mount(enabled: false);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.tap(find.text('TAKE GUARD'));
      expect(calls, 3);
      await mount(loading: true);
      expect(find.text('LOADING SQUAD'), findsOneWidget);
      await tester.tap(find.text('LOADING SQUAD'));
      expect(calls, 3);
      expect(tester.takeException(), isNull);
    },
  );
}

class _SilentAudio implements AudioPlaybackBackend {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
