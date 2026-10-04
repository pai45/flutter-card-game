import 'dart:io';

import 'package:card_game/utils/sound_effects.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _EffectCall {
  const _EffectCall(this.path, this.bus, this.volume);

  final String path;
  final AudioBus bus;
  final double volume;
}

class _FakeAudioBackend implements AudioPlaybackBackend {
  final preloads = <List<String>>[];
  final effects = <_EffectCall>[];
  final ambienceStarts = <String>[];
  final ambienceVolumes = <double>[];
  final dynamicStarts = <String>[];
  final dynamicUpdates = <({double volume, double rate})>[];
  var ambienceStops = 0;
  var dynamicStops = 0;
  var stopAllCalls = 0;
  var disposeCalls = 0;

  @override
  Future<void> dispose() async => disposeCalls++;

  @override
  Future<void> playEffect(
    String assetPath, {
    required AudioBus bus,
    required double volume,
  }) async => effects.add(_EffectCall(assetPath, bus, volume));

  @override
  Future<void> preload(List<String> assetPaths) async =>
      preloads.add(List.of(assetPaths));

  @override
  Future<void> setAmbienceVolume(double volume) async =>
      ambienceVolumes.add(volume);

  @override
  Future<void> setDynamicLoop({
    required double volume,
    required double rate,
  }) async => dynamicUpdates.add((volume: volume, rate: rate));

  @override
  Future<void> startAmbience(
    String assetPath, {
    required double volume,
  }) async => ambienceStarts.add(assetPath);

  @override
  Future<void> startDynamicLoop(
    String assetPath, {
    required double volume,
  }) async => dynamicStarts.add(assetPath);

  @override
  Future<void> stopAll() async => stopAllCalls++;

  @override
  Future<void> stopAmbience() async => ambienceStops++;

  @override
  Future<void> stopDynamicLoop() async => dynamicStops++;
}

class _LayeredBackend extends _FakeAudioBackend
    implements GrandPrixAudioPlaybackBackend {
  var starts = 0;
  var stops = 0;
  final mixes = <({double rpm, double load, double speed, double scrub})>[];
  @override
  Future<void> startGrandPrixLayers() async => starts++;
  @override
  Future<void> stopGrandPrixLayers() async => stops++;
  @override
  Future<void> updateGrandPrixLayers({
    required double rpm,
    required double load,
    required double speed,
    required double scrub,
  }) async {
    mixes.add((rpm: rpm, load: load, speed: speed, scrub: scrub));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'race audio is owned by the active route and respects pause and mute',
    (tester) async {
      final backend = _LayeredBackend();
      final controller = AudioController(backend: backend);
      await controller.enterGrandPrixScene('first');
      await controller.startGrandPrixAudio('first');
      await controller.updateGrandPrixAudio(
        'first',
        rpm: .7,
        load: 1,
        speed: .8,
        scrub: .2,
      );
      expect(backend.mixes.last.rpm, .7);
      await controller.stopGrandPrixAudio('first');
      final stopped = backend.mixes.length;
      await controller.updateGrandPrixAudio(
        'first',
        rpm: 1,
        load: 1,
        speed: 1,
        scrub: 1,
      );
      expect(backend.mixes.length, stopped);
      final beforeRetry = backend.stops;
      await controller.enterGrandPrixScene('retry');
      // Retry grid does not retain old engine layers.
      expect(backend.stops, greaterThan(beforeRetry));
      await controller.startGrandPrixAudio('retry');
      final stops = backend.stops;
      await controller.leaveGrandPrixScene('first');
      await controller.stopGrandPrixAudio('first');
      expect(backend.stops, stops);
      await controller.setMuted(true, persist: false);
      final starts = backend.starts;
      await controller.startGrandPrixAudio('retry');
      expect(backend.starts, starts);
      await controller.setMuted(false, persist: false);
      expect(backend.starts, starts + 1);
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();
      await controller.stopGrandPrixAudio('retry');
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(backend.starts, starts + 1);
      await controller.leaveGrandPrixScene('retry');
      expect(controller.currentScene, isNull);
      await controller.disposeAll();
    },
  );

  test('all runtime cue paths are unique and shipped', () {
    final cuePaths = SoundEffect.values.map((cue) => cue.spec.asset).toList();
    expect(cuePaths.toSet(), hasLength(SoundEffect.values.length));
    for (final path in cuePaths) {
      expect(File('assets/$path').existsSync(), isTrue, reason: path);
    }
    for (final track in MusicTrack.values) {
      expect(
        File('assets/${track.spec.asset}').existsSync(),
        isTrue,
        reason: track.spec.asset,
      );
    }
    expect(File('assets/audio/gp_engine.wav').existsSync(), isTrue);

    final shippedBytes =
        Directory('assets/audio').listSync().whereType<File>().fold<int>(
          0,
          (sum, file) => sum + file.lengthSync(),
        ) +
        Directory('final_over/assets/audio')
            .listSync()
            .whereType<File>()
            .fold<int>(0, (sum, file) => sum + file.lengthSync());
    expect(shippedBytes, lessThanOrEqualTo(15 * 1024 * 1024));
  });

  testWidgets('scene preloading, buses, cooldowns and mute are independent', (
    tester,
  ) async {
    final backend = _FakeAudioBackend();
    final controller = AudioController(backend: backend);
    addTearDown(controller.disposeAll);

    await controller.enterScene(AudioScene.finalOver);
    expect(backend.preloads.single, contains('audio/cricket_stadium.wav'));
    expect(backend.preloads.single, contains('audio/cricket_run_out.wav'));
    expect(backend.ambienceStarts.last, 'audio/cricket_stadium.wav');

    await controller.play(SoundEffect.uiTap);
    await controller.play(SoundEffect.cricketBounce);
    await controller.play(SoundEffect.cricketBounce);
    await controller.play(SoundEffect.cricketSix);
    expect(backend.effects.map((call) => call.bus), [
      AudioBus.ui,
      AudioBus.gameplay,
      AudioBus.reward,
    ]);

    await controller.setMuted(true, persist: false);
    await controller.play(SoundEffect.cricketVictory);
    expect(backend.stopAllCalls, 1);
    expect(backend.effects, hasLength(3));
  });

  testWidgets('Tennis music switch and reward ducking restore ambience', (
    tester,
  ) async {
    final backend = _FakeAudioBackend();
    final controller = AudioController(backend: backend);
    addTearDown(controller.disposeAll);

    await controller.enterScene(AudioScene.tennis, musicEnabled: false);
    expect(backend.ambienceStarts, isEmpty);
    await controller.setSceneMusicEnabled(true);
    expect(backend.ambienceStarts.single, 'audio/tennis_court.wav');

    await controller.play(SoundEffect.tennisAce);
    expect(backend.ambienceVolumes.single, closeTo(.16 * .24, .0001));
    await tester.pump(const Duration(milliseconds: 851));
    expect(backend.ambienceVolumes.last, .16);
  });

  testWidgets('dynamic engine and lifecycle pause/resume are restored', (
    tester,
  ) async {
    final backend = _FakeAudioBackend();
    final controller = AudioController(backend: backend);
    addTearDown(controller.disposeAll);

    await controller.enterScene(AudioScene.grandPrix);
    await controller.startDynamicLoop();
    await controller.updateDynamicLoop(.5);
    expect(backend.dynamicStarts.single, 'audio/gp_engine.wav');
    expect(backend.dynamicUpdates.last.rate, closeTo(1.1, .0001));

    controller.didChangeAppLifecycleState(AppLifecycleState.paused);
    await tester.pump();
    expect(backend.ambienceStops, greaterThan(0));
    expect(backend.dynamicStops, greaterThan(0));

    controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(backend.dynamicStarts, hasLength(2));
    expect(backend.ambienceStarts, hasLength(2));
  });
}
