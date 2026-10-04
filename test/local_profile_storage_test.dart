import 'dart:convert';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/models/progression.dart';
import 'package:card_game/models/streak.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'pd_onboarding_complete_v1': 'true',
      'pd_progression_v1': jsonEncode(PlayerProgression(totalXP: 850).toJson()),
      'pd_daily_streak_v1': jsonEncode(
        StreakSnapshot.fromJson({
          'activeDays': {
            'overall': ['2026-09-17', '2026-09-18', '2026-09-19'],
          },
        }).toJson(),
      ),
    });
    SharedPreferences.setMockInitialValues({
      'pitch_duel_wallet': jsonEncode({
        'coins': 725,
        'ownedCardIds': const <String>[],
        'ownedActionCardIds': const <String>[],
        'ownedCardBackIds': const ['default'],
        'equippedCardBackId': 'default',
      }),
    });
  });

  test('an undecryptable profile-slot entry no longer blocks logout', () async {
    // The web backend's first-boot key race left the slots entry encrypted
    // under a lost key: every read of it threw, so logout never opened.
    final storage = SecureGameStorage(
      storage: _UndecryptableStorage('pd_local_profile_slots_v1'),
    );
    await const FlutterSecureStorage().write(
      key: 'pd_local_profile_slots_v1',
      value: 'garbage',
    );

    expect(await storage.loadActiveLocalProfile(), LocalProfileSlot.returning);
    expect(
      await storage.isLocalProfileReady(LocalProfileSlot.returning),
      isTrue,
    );

    await storage.switchLocalProfile(LocalProfileSlot.firstTime);
    expect(await storage.loadOnboardingComplete(), isFalse);
    expect((await storage.loadProgression()).totalXP, 0);

    await storage.switchLocalProfile(LocalProfileSlot.returning);
    expect(await storage.loadOnboardingComplete(), isTrue);
    expect((await storage.loadProgression()).totalXP, 850);
  });

  test(
    'first-time and returning careers keep progression and streak isolated',
    () async {
      final storage = SecureGameStorage();
      await storage.ensureLocalProfiles();

      expect(
        await storage.loadActiveLocalProfile(),
        LocalProfileSlot.returning,
      );
      expect(
        await storage.isLocalProfileReady(LocalProfileSlot.returning),
        isTrue,
      );

      await storage.switchLocalProfile(LocalProfileSlot.firstTime);

      expect(await storage.loadOnboardingComplete(), isFalse);
      expect((await storage.loadProgression()).totalXP, 0);
      expect(await storage.loadStreak(), isNull);
      expect((await storage.loadWallet()).coins, 0);

      await storage.saveOnboardingComplete(true);
      await storage.saveProgression(PlayerProgression(totalXP: 125));
      await storage.saveStreak(
        StreakSnapshot.fromJson({
          'activeDays': {
            'overall': ['2026-09-19'],
          },
        }),
      );

      await storage.switchLocalProfile(LocalProfileSlot.returning);

      expect((await storage.loadProgression()).totalXP, 850);
      expect(
        (await storage.loadStreak())
            ?.activeDays[StreakCategory.overall]
            ?.length,
        3,
      );
      expect((await storage.loadWallet()).coins, 725);

      await storage.switchLocalProfile(LocalProfileSlot.firstTime);

      expect((await storage.loadProgression()).totalXP, 125);
      expect(
        (await storage.loadStreak())
            ?.activeDays[StreakCategory.overall]
            ?.length,
        1,
      );
    },
  );

  test('profile swap persists only the inactive career snapshot', () async {
    final storage = SecureGameStorage();
    await storage.ensureLocalProfiles();

    expect(await _storedSlotNames(), {LocalProfileSlot.firstTime.name});

    await storage.switchLocalProfile(LocalProfileSlot.firstTime);
    expect(await _storedSlotNames(), {LocalProfileSlot.returning.name});

    await storage.switchLocalProfile(LocalProfileSlot.returning);
    expect(await _storedSlotNames(), {LocalProfileSlot.firstTime.name});
    expect((await storage.loadProgression()).totalXP, 850);
  });

  test('secure mutations are serialized during a profile swap', () async {
    final storage = SecureGameStorage(storage: _SerialMutationStorage());
    await storage.ensureLocalProfiles();

    await storage.switchLocalProfile(LocalProfileSlot.firstTime);
    await storage.switchLocalProfile(LocalProfileSlot.returning);

    expect(await storage.loadActiveLocalProfile(), LocalProfileSlot.returning);
    expect((await storage.loadProgression()).totalXP, 850);
  });

  test('a failed activation restores the outgoing career for retry', () async {
    final guardedStorage = _FailingActivationStorage();
    final storage = SecureGameStorage(storage: guardedStorage);
    await storage.ensureLocalProfiles();
    guardedStorage.failNextActivation(LocalProfileSlot.firstTime);

    await expectLater(
      storage.switchLocalProfile(LocalProfileSlot.firstTime),
      throwsStateError,
    );

    expect(await storage.loadActiveLocalProfile(), LocalProfileSlot.returning);
    expect(await storage.loadOnboardingComplete(), isTrue);
    expect((await storage.loadProgression()).totalXP, 850);
    expect(await _storedSlotNames(), {LocalProfileSlot.firstTime.name});

    await storage.switchLocalProfile(LocalProfileSlot.firstTime);
    expect(await storage.loadActiveLocalProfile(), LocalProfileSlot.firstTime);
  });

  test(
    'a clean first-time slot boots at level 1 with no active streak',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      final storage = SecureGameStorage();
      await storage.ensureLocalProfiles();
      expect(
        await storage.loadActiveLocalProfile(),
        LocalProfileSlot.firstTime,
      );

      final bloc = GameBloc(storage)..add(GameLoaded());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((state) => !state.loading);

      expect(bloc.state.progression.playerLevel, 1);
      expect(bloc.state.progression.totalXP, 0);
      expect(
        bloc.state.streak.activeDays.values.every((days) => days.isEmpty),
        isTrue,
      );
    },
  );
}

Future<Set<String>> _storedSlotNames() async {
  final raw = await const FlutterSecureStorage().read(
    key: 'pd_local_profile_slots_v1',
  );
  return Map<String, dynamic>.from(jsonDecode(raw!) as Map).keys.toSet();
}

class _SerialMutationStorage extends FlutterSecureStorage {
  bool _mutationInFlight = false;

  Future<T> _mutate<T>(Future<T> Function() operation) async {
    if (_mutationInFlight) {
      throw StateError('concurrent secure-storage mutation');
    }
    _mutationInFlight = true;
    try {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      return await operation();
    } finally {
      _mutationInFlight = false;
    }
  }

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
  }) => _mutate(
    () => super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) => _mutate(
    () => super.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    ),
  );
}

class _FailingActivationStorage extends FlutterSecureStorage {
  String? _activationToFail;

  void failNextActivation(LocalProfileSlot slot) {
    _activationToFail = slot.name;
  }

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
    if (key == 'pd_active_local_profile_v1' && value == _activationToFail) {
      _activationToFail = null;
      throw StateError('activation interrupted');
    }
    return super.write(
      key: key,
      value: value,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
  }
}

/// Mimics flutter_secure_storage on web for a value encrypted under a lost
/// key: reading it throws, and `readAll()` throws while it is still stored.
class _UndecryptableStorage extends FlutterSecureStorage {
  _UndecryptableStorage(this.brokenKey);

  final String brokenKey;
  bool _broken = true;

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (_broken && key == brokenKey) {
      return Future.error(StateError('OperationError: decrypt failed'));
    }
    return super.read(key: key);
  }

  @override
  Future<Map<String, String>> readAll({
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (_broken) {
      return Future.error(StateError('OperationError: decrypt failed'));
    }
    return super.readAll();
  }

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
    if (key == brokenKey) _broken = false;
    return super.write(key: key, value: value);
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) {
    if (key == brokenKey) _broken = false;
    return super.delete(key: key);
  }
}
