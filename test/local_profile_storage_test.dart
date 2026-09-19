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
