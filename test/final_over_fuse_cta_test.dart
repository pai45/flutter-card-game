import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/final_over/widgets/final_over_fuse_cta.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/cyber/cyber_cta_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    AudioController.debugUseBackend(_SilentAudio());
    AudioController.instance.muted.value = true;
  });

  Future<void> mount(
    WidgetTester tester, {
    required VoidCallback? onTap,
    bool loading = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Scaffold(
            body: FinalOverFuseCta(
              label: 'TAKE GUARD',
              onTap: onTap,
              loading: loading,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'shared Fuse launch activates once by tap, Enter and Space without a timer',
    (tester) async {
      var calls = 0;
      await mount(tester, onTap: () => calls++);
      expect(
        tester.widget<CyberFuseCtaButton>(find.byType(CyberFuseCtaButton)).fuse,
        isNull,
      );
      await tester.tap(find.text('TAKE GUARD'));
      expect(calls, 1);
      Focus.of(tester.element(find.byType(CyberFuseCtaButton))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(calls, 3);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('disabled and loading Fuse actions protect match launch', (
    tester,
  ) async {
    var calls = 0;
    await mount(tester, onTap: null);
    await tester.tap(find.text('TAKE GUARD'));
    expect(calls, 0);
    await mount(tester, onTap: () => calls++, loading: true);
    expect(find.text('LOADING SQUAD'), findsOneWidget);
    expect(
      tester.widget<CyberFuseCtaButton>(find.byType(CyberFuseCtaButton)).onTap,
      isNull,
    );
    await tester.tap(find.text('LOADING SQUAD'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 0);
  });
}

class _SilentAudio implements AudioPlaybackBackend {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}
