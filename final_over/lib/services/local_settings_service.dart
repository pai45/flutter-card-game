import 'package:shared_preferences/shared_preferences.dart';

class FinalOverSettings {
  const FinalOverSettings({
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.bestScore = 0,
    this.bestStars = 0,
  });

  final bool soundEnabled;
  final bool vibrationEnabled;
  final int bestScore;
  final int bestStars;

  FinalOverSettings copyWith({
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? bestScore,
    int? bestStars,
  }) {
    return FinalOverSettings(
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      bestScore: bestScore ?? this.bestScore,
      bestStars: bestStars ?? this.bestStars,
    );
  }
}

class LocalSettingsService {
  LocalSettingsService(this._preferences);

  static const soundKey = 'final_over.sound_enabled';
  static const vibrationKey = 'final_over.vibration_enabled';
  static const bestScoreKey = 'final_over.best_score';
  static const bestStarsKey = 'final_over.best_stars';

  final SharedPreferences _preferences;

  static Future<LocalSettingsService> create() async {
    return LocalSettingsService(await SharedPreferences.getInstance());
  }

  FinalOverSettings load() {
    return FinalOverSettings(
      soundEnabled: _preferences.getBool(soundKey) ?? true,
      vibrationEnabled: _preferences.getBool(vibrationKey) ?? true,
      bestScore: _preferences.getInt(bestScoreKey) ?? 0,
      bestStars: _preferences.getInt(bestStarsKey) ?? 0,
    );
  }

  Future<void> setSoundEnabled(bool value) async {
    await _preferences.setBool(soundKey, value);
  }

  Future<void> setVibrationEnabled(bool value) async {
    await _preferences.setBool(vibrationKey, value);
  }

  Future<void> updateBest({required int score, required int stars}) async {
    final current = load();
    if (score > current.bestScore) {
      await _preferences.setInt(bestScoreKey, score);
    }
    if (stars > current.bestStars) {
      await _preferences.setInt(bestStarsKey, stars.clamp(0, 3));
    }
  }
}
