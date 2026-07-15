import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

enum AudioCue {
  uiTap('ui_tap.wav'),
  footstep('footstep.wav'),
  release('release.wav'),
  bounce('bounce.wav'),
  cleanHit('clean_hit.wav'),
  edge('edge.wav'),
  roll('roll.wav'),
  catchBall('catch.wav'),
  stumps('stumps.wav'),
  throwWhoosh('throw.wav'),
  fourCrowd('four_crowd.wav'),
  sixCrowd('six_crowd.wav'),
  wicket('wicket.wav'),
  victory('victory.wav'),
  defeat('defeat.wav');

  const AudioCue(this.fileName);
  final String fileName;
}

abstract interface class AudioBackend {
  Future<void> playEffect(String assetPath);
  Future<void> startLoop(String assetPath);
  Future<void> stopAll();
  Future<void> dispose();
}

/// Optional capability used for short impact/crowd ducking. Test and silent
/// backends do not need to implement it.
abstract interface class DuckableAudioBackend {
  Future<void> setAmbienceVolume(double volume);
}

abstract interface class PreloadableAudioBackend {
  Future<void> preload(List<String> assetPaths);
}

class AudioplayersBackend
    implements AudioBackend, DuckableAudioBackend, PreloadableAudioBackend {
  AudioplayersBackend({this.assetPackage})
    : _cache = AudioCache(prefix: assetPackage == null ? 'assets/' : '') {
    _effects.audioCache = _cache;
    _ambience.audioCache = _cache;
  }

  final String? assetPackage;
  final AudioCache _cache;
  final AudioPlayer _effects = AudioPlayer();
  final AudioPlayer _ambience = AudioPlayer();

  String _resolve(String assetPath) => assetPackage == null
      ? assetPath
      : 'packages/$assetPackage/assets/$assetPath';

  @override
  Future<void> playEffect(String assetPath) async {
    await _effects.play(AssetSource(_resolve(assetPath)));
  }

  @override
  Future<void> startLoop(String assetPath) async {
    await _ambience.setReleaseMode(ReleaseMode.loop);
    await _ambience.setVolume(0.22);
    await _ambience.play(AssetSource(_resolve(assetPath)));
  }

  @override
  Future<void> setAmbienceVolume(double volume) =>
      _ambience.setVolume(volume.clamp(0.0, 1.0));

  @override
  Future<void> preload(List<String> assetPaths) async {
    await _cache.loadAll(assetPaths.map(_resolve).toList(growable: false));
  }

  @override
  Future<void> stopAll() async {
    await Future.wait([_effects.stop(), _ambience.stop()]);
  }

  @override
  Future<void> dispose() async {
    await Future.wait([_effects.dispose(), _ambience.dispose()]);
  }
}

class AudioService {
  AudioService({
    AudioBackend? backend,
    String? assetPackage,
    this.enabled = true,
  }) : _backend = backend ?? AudioplayersBackend(assetPackage: assetPackage);

  final AudioBackend _backend;
  Timer? _duckTimer;
  bool enabled;

  Future<void> setEnabled(bool value) async {
    enabled = value;
    if (!value) await _safe(_backend.stopAll);
  }

  Future<void> play(AudioCue cue) async {
    if (!enabled) return;
    await _safe(() => _backend.playEffect('audio/${cue.fileName}'));
  }

  Future<void> startAmbience() async {
    if (!enabled) return;
    await _safe(() => _backend.startLoop('audio/ambience.wav'));
  }

  /// Extracts all bundled WAV files into the platform cache during splash so
  /// the first delivery does not pay decoder/asset setup cost.
  Future<void> preload() async {
    if (_backend is! PreloadableAudioBackend) return;
    final preloadable = _backend as PreloadableAudioBackend;
    await _safe(
      () => preloadable.preload(<String>[
        for (final cue in AudioCue.values) 'audio/${cue.fileName}',
        'audio/ambience.wav',
      ]),
    );
  }

  Future<void> duckFor([
    Duration duration = const Duration(milliseconds: 420),
  ]) async {
    if (!enabled || _backend is! DuckableAudioBackend) return;
    _duckTimer?.cancel();
    final duckable = _backend as DuckableAudioBackend;
    await _safe(() => duckable.setAmbienceVolume(.08));
    _duckTimer = Timer(duration, () {
      if (enabled) unawaited(_safe(() => duckable.setAmbienceVolume(.22)));
    });
  }

  Future<void> stop() => _safe(_backend.stopAll);

  Future<void> dispose() {
    _duckTimer?.cancel();
    return _safe(_backend.dispose);
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Audio is optional polish. A missing decoder or asset must not stop play.
    }
  }
}
