import 'package:final_over/services/local_settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('settings use isolated keys and preserve best values', () async {
    SharedPreferences.setMockInitialValues({});
    final service = await LocalSettingsService.create();
    expect(service.load().soundEnabled, isTrue);
    expect(service.load().vibrationEnabled, isTrue);

    await service.setSoundEnabled(false);
    await service.setVibrationEnabled(false);
    await service.updateBest(score: 800, stars: 2);
    await service.updateBest(score: 200, stars: 1);

    final settings = service.load();
    expect(settings.soundEnabled, isFalse);
    expect(settings.vibrationEnabled, isFalse);
    expect(settings.bestScore, 800);
    expect(settings.bestStars, 2);
  });
}
