import 'dart:async';

import 'package:card_game/config/theme.dart';
import 'package:card_game/screens/onboarding/login_signup_screen.dart';
import 'package:card_game/screens/onboarding/profile_setup_screen.dart';
import 'package:card_game/utils/sound_effects.dart';
import 'package:card_game/widgets/cyber/cyber_cta_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _VideoPlatform platform;
  setUp(() {
    for (final name in [
      'xyz.luan/audioplayers.global',
      'xyz.luan/audioplayers',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(name), (_) async => null);
    }
    platform = _VideoPlatform();
    VideoPlayerPlatform.instance = platform;
    AudioController.instance.muted.value = true;
  });

  Future<void> pump(
    WidgetTester tester, {
    VoidCallback? onContinue,
    bool reduceMotion = false,
    double scale = 1,
  }) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            disableAnimations: reduceMotion,
            textScaler: TextScaler.linear(scale),
          ),
          child: LoginSignupScreen(onContinue: onContinue ?? () {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets(
    'validates email and continues only once without authentication',
    (tester) async {
      var calls = 0;
      await pump(tester, onContinue: () => calls++);
      final cta = find.byKey(const ValueKey('onboarding-continue'));
      expect(tester.widget<HudCtaButton>(cta).enabled, isFalse);
      await tester.enterText(find.byType(TextField), 'invalid');
      await tester.pump();
      expect(find.text('Enter a valid email to continue.'), findsOneWidget);
      await tester.enterText(find.byType(TextField), ' champion@arena.com ');
      await tester.pump();
      expect(tester.widget<HudCtaButton>(cta).enabled, isTrue);
      await tester.ensureVisible(cta);
      await tester.tap(cta);
      await tester.pump();
      await tester.tap(cta);
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Google preview works with empty email and policies are explicit',
    (tester) async {
      var calls = 0;
      await pump(tester, onContinue: () => calls++);
      await tester.ensureVisible(find.text('Privacy Policy'));
      await tester.tap(find.text('Privacy Policy'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.textContaining('unavailable in this prototype'),
        findsOneWidget,
      );
      await tester.tap(find.text('GOT IT >'));
      await tester.pump(const Duration(milliseconds: 300));
      final google = find.byKey(const ValueKey('onboarding-google'));
      await tester.ensureVisible(google);
      await tester.tap(google);
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final skip in [false, true]) {
    testWidgets(
      'welcome ${skip ? 'skip' : 'completion'} opens account before avatar',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(home: ProfileSetupScreen(onComplete: (_) {})),
        );
        if (skip) {
          await tester.tapAt(const Offset(300, 300));
        } else {
          await tester.pump(const Duration(seconds: 4));
        }
        await tester.pump();
        expect(find.byType(LoginSignupScreen), findsOneWidget);
        expect(find.text('NEXT'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('video is silent, loops, pauses, resumes and disposes', (
    tester,
  ) async {
    await pump(tester);
    expect(platform.calls, containsAll(['volume:0.0', 'loop:true', 'play']));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(platform.calls.last, 'pause');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.calls.last, 'play');
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    expect(platform.calls, contains('dispose'));
  });

  testWidgets('failure keeps poster and form usable', (tester) async {
    platform.fail = true;
    await pump(tester);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-video')), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduced motion and large text use poster without overflow', (
    tester,
  ) async {
    await pump(tester, reduceMotion: true, scale: 1.8);
    expect(platform.calls, isNot(contains('create')));
    await tester.ensureVisible(
      find.byKey(const ValueKey('onboarding-continue')),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('keyboard inset leaves the form and continuation reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 740));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 740),
            viewInsets: EdgeInsets.only(bottom: 300),
            disableAnimations: true,
          ),
          child: LoginSignupScreen(onContinue: () {}),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'player@example.com');
    await tester.pump();
    final cta = find.byKey(const ValueKey('onboarding-continue'));
    await tester.ensureVisible(cta);
    expect(tester.getRect(cta).bottom, lessThanOrEqualTo(440));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

class _VideoPlatform extends VideoPlayerPlatform {
  final calls = <String>[];
  final stream = StreamController<VideoEvent>();
  bool fail = false;
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    calls.add('create');
    if (fail) {
      stream.addError(
        PlatformException(code: 'unavailable', message: 'Unavailable'),
      );
    } else {
      stream.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 6),
          size: const Size(900, 720),
        ),
      );
    }
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => stream.stream;
  @override
  Future<void> dispose(int playerId) async {
    calls.add('dispose');
    await stream.close();
  }

  @override
  Future<void> play(int playerId) async {
    calls.add('play');
  }

  @override
  Future<void> pause(int playerId) async {
    calls.add('pause');
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {
    calls.add('volume:$volume');
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    calls.add('loop:$looping');
  }

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildView(int playerId) => const SizedBox(key: ValueKey('fake-video'));
}
