import 'dart:io';

import 'package:final_over/services/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBackend implements AudioBackend {
  final calls = <String>[];

  @override
  Future<void> dispose() async => calls.add('dispose');

  @override
  Future<void> playEffect(String assetPath) async => calls.add(assetPath);

  @override
  Future<void> startLoop(String assetPath) async =>
      calls.add('loop:$assetPath');

  @override
  Future<void> stopAll() async => calls.add('stop');
}

class _DuckableFakeBackend extends _FakeBackend
    implements DuckableAudioBackend {
  final volumes = <double>[];

  @override
  Future<void> setAmbienceVolume(double volume) async => volumes.add(volume);
}

class _PreloadableFakeBackend extends _FakeBackend
    implements PreloadableAudioBackend {
  final loaded = <String>[];

  @override
  Future<void> preload(List<String> assetPaths) async =>
      loaded.addAll(assetPaths);
}

void main() {
  test('audio service respects enabled state', () async {
    final backend = _FakeBackend();
    final service = AudioService(backend: backend);
    await service.play(AudioCue.cleanHit);
    await service.startAmbience();
    await service.setEnabled(false);
    await service.play(AudioCue.wicket);

    expect(backend.calls, [
      'audio/clean_hit.wav',
      'loop:audio/ambience.wav',
      'stop',
    ]);
  });

  test('generated audio pack contains valid PCM WAV files', () {
    final directory = Directory('assets/audio');
    final files = directory.listSync().whereType<File>().toList();
    expect(files.length, 16);
    for (final file in files) {
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(44), reason: file.path);
      expect(String.fromCharCodes(bytes.take(4)), 'RIFF');
      expect(String.fromCharCodes(bytes.skip(8).take(4)), 'WAVE');
    }
  });

  test('impact ducking lowers and restores optional ambience', () async {
    final backend = _DuckableFakeBackend();
    final service = AudioService(backend: backend);

    await service.duckFor(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(backend.volumes, <double>[.08, .22]);
    await service.dispose();
  });

  test('preload warms every effect and ambience exactly once', () async {
    final backend = _PreloadableFakeBackend();
    final service = AudioService(backend: backend);

    await service.preload();

    expect(backend.loaded, hasLength(AudioCue.values.length + 1));
    expect(backend.loaded.toSet(), hasLength(backend.loaded.length));
    expect(backend.loaded, contains('audio/ambience.wav'));
  });
}
