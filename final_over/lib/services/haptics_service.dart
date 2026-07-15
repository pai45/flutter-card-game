import 'package:flutter/services.dart';

enum HapticCue {
  tap,
  goodContact,
  perfectContact,
  four,
  six,
  wicket,
  closeCall,
}

abstract interface class HapticDriver {
  Future<void> light();
  Future<void> medium();
  Future<void> heavy();
}

class SystemHapticDriver implements HapticDriver {
  @override
  Future<void> light() => HapticFeedback.lightImpact();

  @override
  Future<void> medium() => HapticFeedback.mediumImpact();

  @override
  Future<void> heavy() => HapticFeedback.heavyImpact();
}

class HapticsService {
  HapticsService({HapticDriver? driver, this.enabled = true})
    : _driver = driver ?? SystemHapticDriver();

  final HapticDriver _driver;
  bool enabled;
  void setEnabled(bool value) => enabled = value;

  Future<void> play(HapticCue cue) async {
    if (!enabled) return;
    try {
      switch (cue) {
        case HapticCue.tap:
        case HapticCue.goodContact:
          await _driver.light();
        case HapticCue.perfectContact:
        case HapticCue.four:
          await _driver.medium();
        case HapticCue.six:
        case HapticCue.wicket:
          await _driver.heavy();
        case HapticCue.closeCall:
          await _driver.light();
          await Future<void>.delayed(const Duration(milliseconds: 80));
          if (enabled) await _driver.light();
      }
    } catch (_) {
      // Haptics are optional polish and never participate in game state.
    }
  }
}
