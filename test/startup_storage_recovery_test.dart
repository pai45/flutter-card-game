import 'package:card_game/main.dart' as game;
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a failed profile-slot write does not block launch or erase a career',
    () async {
      FlutterSecureStorage.setMockInitialValues({
        'pd_onboarding_complete_v1': 'true',
        'pd_display_name_v1': 'OLD PLAYER',
      });
      SharedPreferences.setMockInitialValues({});
      final storage = SecureGameStorage(storage: _FullProfileStorage());
      final previousHandler = FlutterError.onError;
      final reported = <FlutterErrorDetails>[];
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previousHandler);

      await game.prepareLocalProfilesForLaunch(storage: storage);

      expect(reported, hasLength(1));
      expect(await storage.loadOnboardingComplete(), isTrue);
      expect(await storage.loadDisplayName(), 'OLD PLAYER');
    },
  );
}

class _FullProfileStorage extends FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (key == 'pd_local_profile_slots_v1') {
      throw StateError('QuotaExceededError');
    }
    return super.write(key: key, value: value);
  }
}
