import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

enum AudioCue {
  uiTap('ui_tap.wav', .5, 35),
  footstep('footstep.wav', .52, 55),
  release('release.wav', .65, 45),
  bounce('bounce.wav', .58, 55),
  cleanHit('clean_hit.wav', .84, 70),
  edge('edge.wav', .74, 70),
  roll('roll.wav', .46, 100),
  catchBall('catch.wav', .72, 90),
  stumps('stumps.wav', .92, 120),
  throwWhoosh('throw.wav', .62, 80),
  fourCrowd('four_crowd.wav', .82, 350),
  sixCrowd('six_crowd.wav', .9, 350),
  wicket('wicket.wav', .9, 250),
  victory('victory.wav', .95, 500),
  defeat('defeat.wav', .9, 500);

  const AudioCue(this.fileName, this.volume, this.cooldownMs);
  final String fileName;
  final double volume;
  final int cooldownMs;
}

abstract interface class AudioBackend {
  Future<void> playEffect(String assetPath, {required double volume});
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
    for (final effect in _effects) {
      effect.audioCache = _cache;
      unawaited(effect.setPlayerMode(PlayerMode.lowLatency));
    }
    _ambience.audioCache = _cache;
  }

  final String? assetPackage;
  final AudioCache _cache;
  final List<AudioPlayer> _effects = List.generate(4, (_) => AudioPlayer());
  final AudioPlayer _ambience = AudioPlayer();
  int _nextEffect = 0;

  String _resolve(String assetPath) => assetPackage == null
      ? assetPath
      : 'packages/$assetPackage/assets/$assetPath';

  @override
  Future<void> playEffect(String assetPath, {required double volume}) async {
    final effect = _effects[_nextEffect];
    _nextEffect = (_nextEffect + 1) % _effects.length;
    await effect.stop();
    await effect.play(AssetSource(_resolve(assetPath)), volume: volume);
  }

  @override
  Future<void> startLoop(String assetPath) async {
    await _ambience.setReleaseMode(ReleaseMode.loop);
    await _ambience.setVolume(0.18);
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
    await Future.wait([
      for (final effect in _effects) effect.stop(),
      _ambience.stop(),
    ]);
  }

  @override
  Future<void> dispose() async {
    await Future.wait([
      for (final effect in _effects) effect.dispose(),
      _ambience.dispose(),
    ]);
  }
}

class AudioService {
  AudioService({
    AudioBackend? backend,
    String? assetPackage,
    this.enabled = true,
  }) : _backend = backend ?? AudioplayersBackend(assetPackage: assetPackage);

  final AudioBackend _backend;
  final Map<AudioCue, DateTime> _lastPlayed = {};
  Timer? _duckTimer;
  bool enabled;

  Future<void> setEnabled(bool value) async {
    enabled = value;
    if (!value) await _safe(_backend.stopAll);
  }

  Future<void> play(AudioCue cue) async {
    if (!enabled) return;
    final now = DateTime.now();
    final previous = _lastPlayed[cue];
    if (previous != null &&
        now.difference(previous).inMilliseconds < cue.cooldownMs) {
      return;
    }
    _lastPlayed[cue] = now;
    await _safe(
      () => _backend.playEffect('audio/${cue.fileName}', volume: cue.volume),
    );
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
      if (enabled) unawaited(_safe(() => duckable.setAmbienceVolume(.18)));
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
