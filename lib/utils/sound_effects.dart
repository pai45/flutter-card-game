import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sound effect identifiers for the game.
///
/// Each maps to a short clip in `assets/audio/`. Playback goes through
/// [AudioController]; call sites just use [playSound]. The bundled clips are
/// license-free placeholders — drop in your own CC0 / royalty-free files of the
/// same name (e.g. from kenney.nl or mixkit.co) to upgrade the feel.
enum SoundEffect {
  uiTap, // generic button / nav tap
  cardSelect, // selecting a card in a deck/grid
  playMatch, // the "cool" Play Match CTA whoosh
  attack, // committing an attack action
  defense, // committing a defense action
  special, // committing a special action
  commit, // locking in the round's move (the decisive tap)
  cardSlam, // round result reveal / card lands
  cardReveal, // a single card flips face-up
  packOpen, // a pack bursts open
  whoosh, // soft phase transition / shockwave swish
  riser, // rising tension cue (shot meter, penalty countdown)
  goal, // goal outcome
  save, // keeper save / blocked shot
  redCard, // red card event
  coinFlip, // toss spin
  coinLand, // toss resolves — the coin lands
  countdownTick, // per-second tick during a kickoff/match countdown
  bannerSlam, // full-time result banner punches in
  coins, // coins earned / purchase
  levelUp, // player level up
  rarityBronze, // pack reveal payoff — common
  raritySilver, // pack reveal payoff — uncommon
  rarityGold, // pack reveal payoff — rare
  rarityPlatinum, // pack reveal payoff — top tier (walkout sting)
  matchWin, // victory screen
  matchLose, // defeat screen
  cheering, // crowd cheering for 4, 6, or out
}

extension _SoundEffectAsset on SoundEffect {
  /// Asset path relative to `assets/` (audioplayers' default prefix).
  String get asset => 'audio/${switch (this) {
    SoundEffect.uiTap => 'ui_tap',
    SoundEffect.cardSelect => 'card_select',
    SoundEffect.playMatch => 'play_match',
    SoundEffect.attack => 'attack',
    SoundEffect.defense => 'defense',
    SoundEffect.special => 'special',
    SoundEffect.commit => 'commit',
    SoundEffect.cardSlam => 'card_slam',
    SoundEffect.cardReveal => 'card_reveal',
    SoundEffect.packOpen => 'pack_open',
    SoundEffect.whoosh => 'whoosh',
    SoundEffect.riser => 'riser',
    SoundEffect.goal => 'goal',
    SoundEffect.save => 'save',
    SoundEffect.redCard => 'red_card',
    SoundEffect.coinFlip => 'coin_flip',
    SoundEffect.coinLand => 'coin_land',
    SoundEffect.countdownTick => 'tick',
    SoundEffect.bannerSlam => 'banner_slam',
    SoundEffect.coins => 'coins',
    SoundEffect.levelUp => 'level_up',
    SoundEffect.rarityBronze => 'rarity_bronze',
    SoundEffect.raritySilver => 'rarity_silver',
    SoundEffect.rarityGold => 'rarity_gold',
    SoundEffect.rarityPlatinum => 'rarity_platinum',
    SoundEffect.matchWin => 'match_win',
    SoundEffect.matchLose => 'match_lose',
    SoundEffect.cheering => 'cheering',
  }}.wav';

  /// Per-effect mix level so loud/percussive cues don't overpower subtle ones.
  double get volume => switch (this) {
    SoundEffect.uiTap => 0.35,
    SoundEffect.cardSelect => 0.45,
    SoundEffect.playMatch => 0.9,
    SoundEffect.attack => 0.8,
    SoundEffect.defense => 0.8,
    SoundEffect.special => 0.8,
    SoundEffect.commit => 0.6,
    SoundEffect.cardSlam => 0.7,
    SoundEffect.cardReveal => 0.7,
    SoundEffect.packOpen => 0.85,
    SoundEffect.whoosh => 0.45,
    SoundEffect.riser => 0.5,
    SoundEffect.goal => 0.95,
    SoundEffect.save => 0.7,
    SoundEffect.redCard => 0.8,
    SoundEffect.coinFlip => 0.6,
    SoundEffect.coinLand => 0.6,
    SoundEffect.countdownTick => 0.6,
    SoundEffect.bannerSlam => 0.8,
    SoundEffect.coins => 0.7,
    SoundEffect.levelUp => 0.9,
    SoundEffect.rarityBronze => 0.6,
    SoundEffect.raritySilver => 0.7,
    SoundEffect.rarityGold => 0.85,
    SoundEffect.rarityPlatinum => 0.95,
    SoundEffect.matchWin => 0.95,
    SoundEffect.matchLose => 0.85,
    SoundEffect.cheering => 0.8,
  };
}

/// Looping background tracks (ambient bed). Played on a dedicated channel that
/// is independent of the one-shot SFX pool so effects never evict the loop.
enum MusicTrack { matchAmbient }

extension _MusicTrackAsset on MusicTrack {
  String get asset => 'audio/${switch (this) {
    MusicTrack.matchAmbient => 'match_ambient',
  }}.wav';

  /// Resting volume — sits low under everything by design.
  double get baseVolume => switch (this) {
    MusicTrack.matchAmbient => 0.25,
  };
}

/// Maps a rarity rank (0 bronze → 3 platinum) to its reveal payoff sting so the
/// pull *sounds* as rare as it looks (variable-reward escalation).
SoundEffect rarityRevealSound(int rank) => switch (rank) {
  >= 3 => SoundEffect.rarityPlatinum,
  2 => SoundEffect.rarityGold,
  1 => SoundEffect.raritySilver,
  _ => SoundEffect.rarityBronze,
};

/// Plays short UI/gameplay sound effects plus an optional looping ambient bed.
///
/// SFX use a small round-robin pool of [AudioPlayer]s so a few cues can overlap
/// (e.g. a card slam under a goal sting). A separate [_music] player owns the
/// ambient loop and is briefly ducked when a big payoff sting fires. Missing
/// assets or an unavailable audio backend fail silently — sound is never
/// allowed to crash the UI.
class AudioController {
  AudioController._();
  static final AudioController instance = AudioController._();

  static const int _poolSize = 6;
  static const String _muteKey = 'audio_muted';

  /// Payoff stings that briefly duck the ambient bed so they cut through.
  static const Set<SoundEffect> _duckers = {
    SoundEffect.goal,
    SoundEffect.bannerSlam,
    SoundEffect.levelUp,
    SoundEffect.rarityGold,
    SoundEffect.rarityPlatinum,
    SoundEffect.matchWin,
    SoundEffect.matchLose,
  };

  final List<AudioPlayer> _pool = [];
  int _next = 0;
  bool _ready = false;

  // Ambient / music channel.
  AudioPlayer? _music;
  MusicTrack? _currentTrack;
  double _musicBase = 0;
  double _musicVol = 0;
  Timer? _fadeTimer;
  Timer? _duckTimer;

  /// Global mute toggle. Flip via [toggleMute]; observe to drive a UI switch.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  void _ensureReady() {
    if (_ready) return;
    _ready = true;
    for (var i = 0; i < _poolSize; i++) {
      _pool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
    }
  }

  /// Restores the persisted mute preference. Fire-and-forget from app start.
  Future<void> loadMutePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      muted.value = prefs.getBool(_muteKey) ?? false;
    } catch (_) {
      // Storage unavailable — default to unmuted.
    }
  }

  Future<void> _persistMuted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_muteKey, muted.value);
    } catch (_) {
      // Best effort; a failed write just won't persist.
    }
  }

  Future<void> play(SoundEffect effect) async {
    if (muted.value) return;
    _ensureReady();
    if (_duckers.contains(effect)) _duck();
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await player.play(AssetSource(effect.asset), volume: effect.volume);
    } catch (e) {
      // Missing clip or unsupported platform — stay silent, never crash.
      debugPrint('playSound($effect) failed: $e');
    }
  }

  /// Starts (or restarts) the ambient loop. Safe to call when muted — the track
  /// is remembered and begins once unmuted.
  Future<void> playLoop(MusicTrack track) async {
    // Cancel any in-flight fade/duck so a restart isn't pulled back to silence.
    _fadeTimer?.cancel();
    _duckTimer?.cancel();
    _currentTrack = track;
    _musicBase = track.baseVolume;
    if (muted.value) return;
    _musicVol = _musicBase;
    try {
      final player = _music ??= AudioPlayer()
        ..setReleaseMode(ReleaseMode.loop);
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource(track.asset), volume: _musicBase);
    } catch (e) {
      debugPrint('playLoop($track) failed: $e');
    }
  }

  /// Fades out and stops the ambient loop.
  Future<void> stopLoop({int fadeMs = 400}) async {
    _currentTrack = null;
    _duckTimer?.cancel();
    final player = _music;
    if (player == null) return;
    _fadeMusicTo(0, fadeMs, onDone: () => player.stop());
  }

  void _duck() {
    if (_music == null || _currentTrack == null || muted.value) return;
    _duckTimer?.cancel();
    _fadeMusicTo(_musicBase * 0.3, 180);
    _duckTimer = Timer(const Duration(milliseconds: 1100), () {
      _fadeMusicTo(_musicBase, 450);
    });
  }

  void _fadeMusicTo(double target, int ms, {VoidCallback? onDone}) {
    _fadeTimer?.cancel();
    final player = _music;
    if (player == null) {
      onDone?.call();
      return;
    }
    const stepMs = 40;
    final steps = (ms / stepMs).ceil().clamp(1, 1000);
    final start = _musicVol;
    var i = 0;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: stepMs), (t) {
      i++;
      _musicVol = (start + (target - start) * (i / steps)).clamp(0.0, 1.0);
      player.setVolume(_musicVol);
      if (i >= steps) {
        t.cancel();
        onDone?.call();
      }
    });
  }

  void toggleMute() {
    muted.value = !muted.value;
    _persistMuted();
    if (muted.value) {
      _music?.stop();
    } else if (_currentTrack != null) {
      playLoop(_currentTrack!);
    }
  }

  Future<void> disposeAll() async {
    _fadeTimer?.cancel();
    _duckTimer?.cancel();
    for (final player in _pool) {
      await player.dispose();
    }
    _pool.clear();
    await _music?.dispose();
    _music = null;
    _ready = false;
  }
}

/// Fire-and-forget sound hook used throughout the UI and gameplay code.
void playSound(SoundEffect effect) {
  // Intentionally not awaited; playback should never block the caller.
  AudioController.instance.play(effect);
}
