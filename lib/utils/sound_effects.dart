import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

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
  cardSlam, // round result reveal / card lands
  cardReveal, // a single card flips face-up
  packOpen, // a pack bursts open
  goal, // goal outcome
  save, // keeper save / blocked shot
  redCard, // red card event
  coinFlip, // toss animation
  coins, // coins earned / purchase
  levelUp, // player level up
  matchWin, // victory screen
  matchLose, // defeat screen
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
    SoundEffect.cardSlam => 'card_slam',
    SoundEffect.cardReveal => 'card_reveal',
    SoundEffect.packOpen => 'pack_open',
    SoundEffect.goal => 'goal',
    SoundEffect.save => 'save',
    SoundEffect.redCard => 'red_card',
    SoundEffect.coinFlip => 'coin_flip',
    SoundEffect.coins => 'coins',
    SoundEffect.levelUp => 'level_up',
    SoundEffect.matchWin => 'match_win',
    SoundEffect.matchLose => 'match_lose',
  }}.wav';

  /// Per-effect mix level so loud/percussive cues don't overpower subtle ones.
  double get volume => switch (this) {
    SoundEffect.uiTap => 0.35,
    SoundEffect.cardSelect => 0.45,
    SoundEffect.playMatch => 0.9,
    SoundEffect.attack => 0.8,
    SoundEffect.defense => 0.8,
    SoundEffect.special => 0.8,
    SoundEffect.cardSlam => 0.7,
    SoundEffect.cardReveal => 0.7,
    SoundEffect.packOpen => 0.85,
    SoundEffect.goal => 0.95,
    SoundEffect.save => 0.7,
    SoundEffect.redCard => 0.8,
    SoundEffect.coinFlip => 0.6,
    SoundEffect.coins => 0.7,
    SoundEffect.levelUp => 0.9,
    SoundEffect.matchWin => 0.95,
    SoundEffect.matchLose => 0.85,
  };
}

/// Plays short UI/gameplay sound effects.
///
/// Uses a small round-robin pool of [AudioPlayer]s so a few cues can overlap
/// (e.g. a card slam under a goal sting). Missing assets or an unavailable audio
/// backend fail silently — sound is never allowed to crash the UI.
class AudioController {
  AudioController._();
  static final AudioController instance = AudioController._();

  static const int _poolSize = 4;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  bool _ready = false;

  /// Global mute toggle. Flip via [toggleMute]; observe to drive a UI switch.
  final ValueNotifier<bool> muted = ValueNotifier<bool>(false);

  void _ensureReady() {
    if (_ready) return;
    _ready = true;
    for (var i = 0; i < _poolSize; i++) {
      _pool.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
    }
  }

  Future<void> play(SoundEffect effect) async {
    if (muted.value) return;
    _ensureReady();
    final player = _pool[_next];
    _next = (_next + 1) % _pool.length;
    try {
      await player.play(AssetSource(effect.asset), volume: effect.volume);
    } catch (e) {
      // Missing clip or unsupported platform — stay silent, never crash.
      debugPrint('playSound($effect) failed: $e');
    }
  }

  void toggleMute() => muted.value = !muted.value;

  Future<void> disposeAll() async {
    for (final player in _pool) {
      await player.dispose();
    }
    _pool.clear();
    _ready = false;
  }
}

/// Fire-and-forget sound hook used throughout the UI and gameplay code.
void playSound(SoundEffect effect) {
  // Intentionally not awaited; playback should never block the caller.
  AudioController.instance.play(effect);
}
