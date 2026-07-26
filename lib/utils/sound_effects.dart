import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AudioBus { ui, gameplay, reward }

enum AudioScene {
  pitchDuel,
  shootout,
  footballChess,
  finalOver,
  basketball,
  tennis,
  grandPrix,
  bingo,
  quiz,
  mystery,
}

enum SoundEffect {
  uiTap,
  uiConfirm,
  uiInvalid,
  cardSelect,
  playMatch,
  attack,
  defense,
  special,
  commit,
  cardSlam,
  cardReveal,
  packOpen,
  whoosh,
  riser,
  goal,
  save,
  block,
  miss,
  foul,
  redCard,
  coinFlip,
  coinLand,
  countdownTick,
  bannerSlam,
  coins,
  coinSpend,
  levelUp,
  achievement,
  streak,
  rarityBronze,
  raritySilver,
  rarityGold,
  rarityPlatinum,
  matchWin,
  matchDraw,
  matchLose,
  cheering,
  cricketFootstep,
  cricketRelease,
  cricketBounce,
  cricketPerfect,
  cricketGreat,
  cricketGood,
  cricketEdge,
  cricketKeeper,
  cricketCatch,
  cricketDrop,
  cricketStumps,
  cricketRunOut,
  cricketRun,
  cricketThrow,
  cricketRoll,
  cricketExtra,
  cricketPower,
  cricketBoundary,
  cricketSix,
  cricketCrowdPressure,
  cricketVictory,
  cricketDefeat,
  tennisServe,
  tennisContact,
  tennisPerfect,
  tennisBounce,
  tennisNet,
  tennisLet,
  tennisFault,
  tennisDoubleFault,
  tennisOut,
  tennisAce,
  tennisWinner,
  tennisPoint,
  tennisGame,
  tennisTiebreak,
  tennisEndChange,
  tennisSet,
  tennisLesson,
  tennisVictory,
  tennisDefeat,
  bbDribble,
  bbRebound,
  bbRelease,
  bbPerfectRelease,
  bbSwish,
  bbRimRattle,
  bbBackboard,
  bbBlock,
  bbSteal,
  bbDunkSlam,
  bbPoster,
  bbBuzzer,
  bbShotClock,
  bbCrowdRoar,
  bbHeatEnd,
  bbSneakerSqueak,
  bbSubstitution,
  bbVictory,
  bbDefeat,
  gpLightOn,
  gpLightsOut,
  gpJumpStart,
  gpOvertake,
  gpTireScrub,
  gpWallImpact,
  gpCarImpact,
  gpLap,
  gpFinish,
  gpPodium,
  gpPoints,
  gpDnf,
  chessMove,
  chessDribble,
  chessPass,
  chessShoot,
  chessPress,
  chessTackle,
  chessSlide,
  chessTurnover,
  chessAdvanced,
  chessFullTime,
  penaltyTarget,
  penaltyKick,
  penaltyDive,
  penaltyGoal,
  penaltySave,
  penaltySuddenDeath,
  bingoCorrect,
  bingoWrong,
  bingoLine,
  bingoComplete,
  lifeline,
  quizSubmit,
  quizCorrect,
  quizWrong,
  quizPass,
  quizFail,
  quizPerfect,
  quizUnlock,
  mysteryLock,
  mysteryWrong,
  mysteryDuplicate,
  mysteryHint,
  mysteryCorrect,
  mysteryLost,
  driverStatic,
  footballDossierWrong,
  cricketDossierWrong,
  basketballDossierWrong,
  tennisDossierWrong,
}

enum MusicTrack {
  footballStadium,
  cricketStadium,
  basketballArena,
  tennisCourt,
  raceGrid,
}

@immutable
class AudioCueSpec {
  const AudioCueSpec({
    required this.asset,
    required this.bus,
    required this.volume,
    required this.priority,
    required this.cooldown,
    required this.ducking,
    this.scene,
  });

  final String asset;
  final AudioBus bus;
  final double volume;
  final int priority;
  final Duration cooldown;
  final bool ducking;
  final AudioScene? scene;
}

@immutable
class MusicTrackSpec {
  const MusicTrackSpec({required this.asset, required this.volume});

  final String asset;
  final double volume;
}

@immutable
class DailyMysteryAudioProfile {
  const DailyMysteryAudioProfile({
    this.select = SoundEffect.cardSelect,
    this.lock = SoundEffect.mysteryLock,
    this.wrong = SoundEffect.mysteryWrong,
    this.duplicate = SoundEffect.mysteryDuplicate,
    this.hint = SoundEffect.mysteryHint,
    this.win = SoundEffect.mysteryCorrect,
    this.loss = SoundEffect.mysteryLost,
  });

  final SoundEffect select;
  final SoundEffect lock;
  final SoundEffect wrong;
  final SoundEffect duplicate;
  final SoundEffect hint;
  final SoundEffect win;
  final SoundEffect loss;

  static const football = DailyMysteryAudioProfile(
    wrong: SoundEffect.footballDossierWrong,
  );
  static const cricket = DailyMysteryAudioProfile(
    wrong: SoundEffect.cricketDossierWrong,
  );
  static const basketball = DailyMysteryAudioProfile(
    wrong: SoundEffect.basketballDossierWrong,
  );
  static const driver = DailyMysteryAudioProfile(
    wrong: SoundEffect.driverStatic,
  );
  static const tennis = DailyMysteryAudioProfile(
    wrong: SoundEffect.tennisDossierWrong,
  );
}

extension SoundEffectSpec on SoundEffect {
  AudioCueSpec get spec {
    final bus = _rewardEffects.contains(this)
        ? AudioBus.reward
        : _uiEffects.contains(this)
        ? AudioBus.ui
        : AudioBus.gameplay;
    return AudioCueSpec(
      asset: 'audio/${_snakeCase(name)}.wav',
      bus: bus,
      volume: _volumeFor(this, bus),
      priority: switch (bus) {
        AudioBus.ui => 1,
        AudioBus.gameplay => 2,
        AudioBus.reward => 3,
      },
      cooldown: _cooldownFor(this),
      ducking: bus == AudioBus.reward,
      scene: _sceneFor(this),
    );
  }
}

extension MusicTrackAudioSpec on MusicTrack {
  MusicTrackSpec get spec => switch (this) {
    MusicTrack.footballStadium => const MusicTrackSpec(
      asset: 'audio/football_stadium.wav',
      volume: .2,
    ),
    MusicTrack.cricketStadium => const MusicTrackSpec(
      asset: 'audio/cricket_stadium.wav',
      volume: .19,
    ),
    MusicTrack.basketballArena => const MusicTrackSpec(
      asset: 'audio/basketball_arena.wav',
      volume: .18,
    ),
    MusicTrack.tennisCourt => const MusicTrackSpec(
      asset: 'audio/tennis_court.wav',
      volume: .16,
    ),
    MusicTrack.raceGrid => const MusicTrackSpec(
      asset: 'audio/race_grid.wav',
      volume: .18,
    ),
  };
}

extension AudioSceneSpec on AudioScene {
  MusicTrack? get ambience => switch (this) {
    AudioScene.pitchDuel ||
    AudioScene.shootout ||
    AudioScene.footballChess => MusicTrack.footballStadium,
    AudioScene.finalOver => MusicTrack.cricketStadium,
    AudioScene.basketball => MusicTrack.basketballArena,
    AudioScene.tennis => MusicTrack.tennisCourt,
    AudioScene.grandPrix => MusicTrack.raceGrid,
    AudioScene.bingo || AudioScene.quiz || AudioScene.mystery => null,
  };

  List<String> get preloadAssets {
    final assets = SoundEffect.values
        .where((cue) => cue.spec.scene == null || cue.spec.scene == this)
        .map((cue) => cue.spec.asset)
        .toSet();
    final track = ambience;
    if (track != null) assets.add(track.spec.asset);
    if (this == AudioScene.grandPrix) assets.add('audio/gp_engine.wav');
    return assets.toList(growable: false);
  }
}

const _uiEffects = <SoundEffect>{
  SoundEffect.uiTap,
  SoundEffect.uiConfirm,
  SoundEffect.uiInvalid,
  SoundEffect.cardSelect,
  SoundEffect.countdownTick,
  SoundEffect.tennisPoint,
  SoundEffect.tennisEndChange,
  SoundEffect.bbSubstitution,
  SoundEffect.gpLightOn,
  SoundEffect.chessMove,
  SoundEffect.penaltyTarget,
  SoundEffect.mysteryDuplicate,
};

const _rewardEffects = <SoundEffect>{
  SoundEffect.playMatch,
  SoundEffect.packOpen,
  SoundEffect.goal,
  SoundEffect.redCard,
  SoundEffect.bannerSlam,
  SoundEffect.coins,
  SoundEffect.levelUp,
  SoundEffect.achievement,
  SoundEffect.streak,
  SoundEffect.rarityBronze,
  SoundEffect.raritySilver,
  SoundEffect.rarityGold,
  SoundEffect.rarityPlatinum,
  SoundEffect.matchWin,
  SoundEffect.matchDraw,
  SoundEffect.matchLose,
  SoundEffect.cheering,
  SoundEffect.cricketStumps,
  SoundEffect.cricketRunOut,
  SoundEffect.cricketPower,
  SoundEffect.cricketBoundary,
  SoundEffect.cricketSix,
  SoundEffect.cricketVictory,
  SoundEffect.cricketDefeat,
  SoundEffect.tennisDoubleFault,
  SoundEffect.tennisAce,
  SoundEffect.tennisWinner,
  SoundEffect.tennisGame,
  SoundEffect.tennisTiebreak,
  SoundEffect.tennisSet,
  SoundEffect.tennisLesson,
  SoundEffect.tennisVictory,
  SoundEffect.tennisDefeat,
  SoundEffect.bbDunkSlam,
  SoundEffect.bbPoster,
  SoundEffect.bbBuzzer,
  SoundEffect.bbCrowdRoar,
  SoundEffect.bbVictory,
  SoundEffect.bbDefeat,
  SoundEffect.gpLightsOut,
  SoundEffect.gpJumpStart,
  SoundEffect.gpLap,
  SoundEffect.gpFinish,
  SoundEffect.gpPodium,
  SoundEffect.gpPoints,
  SoundEffect.gpDnf,
  SoundEffect.chessTurnover,
  SoundEffect.chessFullTime,
  SoundEffect.penaltyGoal,
  SoundEffect.penaltySave,
  SoundEffect.penaltySuddenDeath,
  SoundEffect.bingoLine,
  SoundEffect.bingoComplete,
  SoundEffect.lifeline,
  SoundEffect.quizPass,
  SoundEffect.quizFail,
  SoundEffect.quizPerfect,
  SoundEffect.quizUnlock,
  SoundEffect.mysteryHint,
  SoundEffect.mysteryCorrect,
  SoundEffect.mysteryLost,
};

double _volumeFor(SoundEffect effect, AudioBus bus) {
  if ({
    SoundEffect.uiTap,
    SoundEffect.cardSelect,
    SoundEffect.countdownTick,
  }.contains(effect)) {
    return .48;
  }
  if ({
    SoundEffect.cricketBounce,
    SoundEffect.tennisBounce,
    SoundEffect.bbDribble,
    SoundEffect.bbSneakerSqueak,
  }.contains(effect)) {
    return .58;
  }
  if ({
    SoundEffect.cricketCrowdPressure,
    SoundEffect.bbCrowdRoar,
    SoundEffect.cheering,
  }.contains(effect)) {
    return .72;
  }
  return switch (bus) {
    AudioBus.ui => .56,
    AudioBus.gameplay => .76,
    AudioBus.reward => .92,
  };
}

Duration _cooldownFor(SoundEffect effect) {
  if (effect == SoundEffect.uiTap) return const Duration(milliseconds: 35);
  if ({
    SoundEffect.cricketBounce,
    SoundEffect.tennisBounce,
    SoundEffect.bbDribble,
    SoundEffect.bbSneakerSqueak,
  }.contains(effect)) {
    return const Duration(milliseconds: 55);
  }
  if ({
    SoundEffect.gpWallImpact,
    SoundEffect.gpCarImpact,
    SoundEffect.gpTireScrub,
  }.contains(effect)) {
    return const Duration(milliseconds: 110);
  }
  if ({
    SoundEffect.cheering,
    SoundEffect.bbCrowdRoar,
    SoundEffect.cricketCrowdPressure,
  }.contains(effect)) {
    return const Duration(milliseconds: 350);
  }
  return Duration.zero;
}

AudioScene? _sceneFor(SoundEffect effect) {
  final name = effect.name;
  if (name.startsWith('cricket')) return AudioScene.finalOver;
  if (name.startsWith('tennis')) {
    return effect == SoundEffect.tennisDossierWrong
        ? AudioScene.mystery
        : AudioScene.tennis;
  }
  if (name.startsWith('bb')) return AudioScene.basketball;
  if (name.startsWith('gp')) return AudioScene.grandPrix;
  if (name.startsWith('chess')) return AudioScene.footballChess;
  if (name.startsWith('penalty')) return AudioScene.shootout;
  if (name.startsWith('bingo')) return AudioScene.bingo;
  if (name.startsWith('quiz')) return AudioScene.quiz;
  if (name.startsWith('mystery') ||
      name == 'driverStatic' ||
      name.endsWith('DossierWrong')) {
    return AudioScene.mystery;
  }
  return null;
}

String _snakeCase(String value) {
  return value.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
  );
}

abstract interface class AudioPlaybackBackend {
  Future<void> preload(List<String> assetPaths);

  Future<void> playEffect(
    String assetPath, {
    required AudioBus bus,
    required double volume,
  });

  Future<void> startAmbience(String assetPath, {required double volume});

  Future<void> setAmbienceVolume(double volume);

  Future<void> stopAmbience();

  Future<void> startDynamicLoop(String assetPath, {required double volume});

  Future<void> setDynamicLoop({required double volume, required double rate});

  Future<void> stopDynamicLoop();

  Future<void> stopAll();

  Future<void> dispose();
}

class AudioplayersAudioBackend implements AudioPlaybackBackend {
  AudioplayersAudioBackend() {
    for (final players in _effectPlayers.values) {
      for (final player in players) {
        player.audioCache = _cache;
        unawaited(player.setPlayerMode(PlayerMode.lowLatency));
      }
    }
    _ambience.audioCache = _cache;
    _dynamic.audioCache = _cache;
  }

  final AudioCache _cache = AudioCache(prefix: 'assets/');
  final Map<AudioBus, List<AudioPlayer>> _effectPlayers = {
    AudioBus.ui: List.generate(2, (_) => AudioPlayer()),
    AudioBus.gameplay: List.generate(6, (_) => AudioPlayer()),
    AudioBus.reward: List.generate(2, (_) => AudioPlayer()),
  };
  final Map<AudioBus, int> _nextPlayer = {
    AudioBus.ui: 0,
    AudioBus.gameplay: 0,
    AudioBus.reward: 0,
  };
  final AudioPlayer _ambience = AudioPlayer();
  final AudioPlayer _dynamic = AudioPlayer();

  @override
  Future<void> preload(List<String> assetPaths) async {
    await _cache.loadAll(assetPaths);
  }

  @override
  Future<void> playEffect(
    String assetPath, {
    required AudioBus bus,
    required double volume,
  }) async {
    final players = _effectPlayers[bus]!;
    final index = _nextPlayer[bus]!;
    _nextPlayer[bus] = (index + 1) % players.length;
    final player = players[index];
    await player.stop();
    await player.play(AssetSource(assetPath), volume: volume);
  }

  @override
  Future<void> startAmbience(String assetPath, {required double volume}) async {
    await _ambience.stop();
    await _ambience.setReleaseMode(ReleaseMode.loop);
    await _ambience.play(AssetSource(assetPath), volume: volume);
  }

  @override
  Future<void> setAmbienceVolume(double volume) {
    return _ambience.setVolume(volume);
  }

  @override
  Future<void> stopAmbience() => _ambience.stop();

  @override
  Future<void> startDynamicLoop(
    String assetPath, {
    required double volume,
  }) async {
    await _dynamic.stop();
    await _dynamic.setReleaseMode(ReleaseMode.loop);
    await _dynamic.play(AssetSource(assetPath), volume: volume);
  }

  @override
  Future<void> setDynamicLoop({
    required double volume,
    required double rate,
  }) async {
    await _dynamic.setVolume(volume);
    await _dynamic.setPlaybackRate(rate);
  }

  @override
  Future<void> stopDynamicLoop() => _dynamic.stop();

  @override
  Future<void> stopAll() async {
    await Future.wait([
      for (final players in _effectPlayers.values)
        for (final player in players) player.stop(),
      _ambience.stop(),
      _dynamic.stop(),
    ]);
  }

  @override
  Future<void> dispose() async {
    await Future.wait([
      for (final players in _effectPlayers.values)
        for (final player in players) player.dispose(),
      _ambience.dispose(),
      _dynamic.dispose(),
    ]);
  }
}

class AudioController with WidgetsBindingObserver {
  AudioController({AudioPlaybackBackend? backend})
    : _backend = backend ?? AudioplayersAudioBackend() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final AudioController instance = AudioController();
  static const _mutePreferenceKey = 'audio_muted';

  final AudioPlaybackBackend _backend;
  final ValueNotifier<bool> muted = ValueNotifier(false);
  final Map<SoundEffect, DateTime> _lastPlayed = {};
  final Set<AudioScene> _preloadedScenes = {};

  AudioScene? _scene;
  MusicTrack? _legacyTrack;
  bool _sceneMusicEnabled = true;
  bool _dynamicLoopRequested = false;
  double _dynamicVolume = .18;
  double _dynamicRate = 1;
  Timer? _duckTimer;
  bool _isBackgrounded = false;

  AudioScene? get currentScene => _scene;

  Future<void> loadMutePreference() async {
    final preferences = await SharedPreferences.getInstance();
    muted.value = preferences.getBool(_mutePreferenceKey) ?? false;
  }

  Future<void> setMuted(bool value, {bool persist = true}) async {
    if (muted.value == value) return;
    muted.value = value;
    if (value) {
      _duckTimer?.cancel();
      await _backend.stopAll();
    } else {
      await _restoreSceneAudio();
    }
    if (persist) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_mutePreferenceKey, value);
    }
  }

  Future<void> toggleMute() => setMuted(!muted.value);

  Future<void> play(SoundEffect effect) async {
    if (muted.value || _isBackgrounded) return;
    final spec = effect.spec;
    final now = DateTime.now();
    final previous = _lastPlayed[effect];
    if (previous != null && now.difference(previous) < spec.cooldown) return;
    _lastPlayed[effect] = now;
    if (spec.ducking) _duckAmbience();
    try {
      await _backend.playEffect(spec.asset, bus: spec.bus, volume: spec.volume);
    } catch (error, stackTrace) {
      debugPrint('Audio cue failed (${spec.asset}): $error\n$stackTrace');
    }
  }

  Future<void> enterScene(AudioScene scene, {bool musicEnabled = true}) async {
    if (_scene != scene) {
      await leaveScene();
      _scene = scene;
    }
    _sceneMusicEnabled = musicEnabled;
    if (_preloadedScenes.add(scene)) {
      try {
        await _backend.preload(scene.preloadAssets);
      } catch (error) {
        debugPrint('Audio scene preload failed ($scene): $error');
      }
    }
    await _restoreSceneAudio();
  }

  Future<void> leaveScene([AudioScene? scene]) async {
    if (scene != null && scene != _scene) return;
    _duckTimer?.cancel();
    _scene = null;
    _legacyTrack = null;
    _dynamicLoopRequested = false;
    await Future.wait([_backend.stopAmbience(), _backend.stopDynamicLoop()]);
  }

  Future<void> setSceneMusicEnabled(bool enabled) async {
    _sceneMusicEnabled = enabled;
    if (muted.value || _isBackgrounded) return;
    if (enabled) {
      await _startCurrentAmbience();
    } else {
      await _backend.stopAmbience();
    }
  }

  Future<void> playLoop(MusicTrack track) async {
    _legacyTrack = track;
    if (muted.value || _isBackgrounded) return;
    await _backend.startAmbience(track.spec.asset, volume: track.spec.volume);
  }

  Future<void> stopLoop() async {
    _legacyTrack = null;
    await _backend.stopAmbience();
  }

  Future<void> startDynamicLoop() async {
    _dynamicLoopRequested = true;
    if (muted.value || _isBackgrounded) return;
    await _backend.startDynamicLoop(
      'audio/gp_engine.wav',
      volume: _dynamicVolume,
    );
    await _backend.setDynamicLoop(volume: _dynamicVolume, rate: _dynamicRate);
  }

  Future<void> updateDynamicLoop(double speedFraction) async {
    final speed = speedFraction.clamp(0.0, 1.0);
    _dynamicVolume = .12 + speed * .33;
    _dynamicRate = .75 + speed * .7;
    if (muted.value || _isBackgrounded || !_dynamicLoopRequested) return;
    await _backend.setDynamicLoop(volume: _dynamicVolume, rate: _dynamicRate);
  }

  Future<void> stopDynamicLoop() async {
    _dynamicLoopRequested = false;
    await _backend.stopDynamicLoop();
  }

  void _duckAmbience() {
    final track = _activeTrack;
    if (track == null || !_sceneMusicEnabled) return;
    _duckTimer?.cancel();
    unawaited(_backend.setAmbienceVolume(track.spec.volume * .24));
    _duckTimer = Timer(const Duration(milliseconds: 850), () {
      if (!muted.value && !_isBackgrounded && _sceneMusicEnabled) {
        unawaited(_backend.setAmbienceVolume(track.spec.volume));
      }
    });
  }

  MusicTrack? get _activeTrack => _scene?.ambience ?? _legacyTrack;

  Future<void> _startCurrentAmbience() async {
    final track = _activeTrack;
    if (track == null || !_sceneMusicEnabled) return;
    await _backend.startAmbience(track.spec.asset, volume: track.spec.volume);
  }

  Future<void> _restoreSceneAudio() async {
    if (muted.value || _isBackgrounded) return;
    await _startCurrentAmbience();
    if (_dynamicLoopRequested) {
      await _backend.startDynamicLoop(
        'audio/gp_engine.wav',
        volume: _dynamicVolume,
      );
      await _backend.setDynamicLoop(volume: _dynamicVolume, rate: _dynamicRate);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final backgrounded = state != AppLifecycleState.resumed;
    if (backgrounded == _isBackgrounded) return;
    _isBackgrounded = backgrounded;
    if (backgrounded) {
      unawaited(_backend.stopAmbience());
      unawaited(_backend.stopDynamicLoop());
    } else {
      unawaited(_restoreSceneAudio());
    }
  }

  Future<void> disposeAll() async {
    WidgetsBinding.instance.removeObserver(this);
    _duckTimer?.cancel();
    await _backend.dispose();
    muted.dispose();
  }
}

void playSound(SoundEffect effect) {
  unawaited(AudioController.instance.play(effect));
}

SoundEffect rarityRevealSound(int rank) => switch (rank.clamp(0, 3)) {
  0 => SoundEffect.rarityBronze,
  1 => SoundEffect.raritySilver,
  2 => SoundEffect.rarityGold,
  _ => SoundEffect.rarityPlatinum,
};
