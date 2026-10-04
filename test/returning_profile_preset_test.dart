import 'dart:convert';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/config/game_ladder.dart';
import 'package:card_game/models/progression.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/streak.dart';
import 'package:card_game/services/returning_profile_preset.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 1, 12);

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('clean install keeps FIRST-TIME blank and readies preset v1', () async {
    final storage = SecureGameStorage();
    await storage.bootstrapLocalProfiles(now: now);

    expect(await storage.loadActiveLocalProfile(), LocalProfileSlot.firstTime);
    final first = await storage.loadLocalProfileSummary(
      LocalProfileSlot.firstTime,
      now: now,
    );
    final returning = await storage.loadLocalProfileSummary(
      LocalProfileSlot.returning,
      now: now,
    );
    expect(first.ready, isFalse);
    expect(first.displayName, 'PLAYER ONE');
    expect(returning.ready, isTrue);
    expect(returning.displayName, returningProfileDisplayName);
    expect(returning.level, 15);
    expect(returning.streak, 7);
  });

  test('active legacy returning career is replaced before bloc load', () async {
    FlutterSecureStorage.setMockInitialValues({
      'pd_onboarding_complete_v1': 'true',
      'pd_display_name_v1': 'old-career',
      'pd_progression_v1': jsonEncode(PlayerProgression(totalXP: 850).toJson()),
    });
    final storage = SecureGameStorage();

    await storage.bootstrapLocalProfiles(now: now);

    expect(await storage.loadActiveLocalProfile(), LocalProfileSlot.returning);
    expect(await storage.loadDisplayName(), returningProfileDisplayName);
    expect((await storage.loadProgression()).totalXP, 11250);

    final bloc = GameBloc(storage)..add(GameLoaded());
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((state) => !state.loading);
    expect(bloc.state.displayName, returningProfileDisplayName);
    expect(bloc.state.progression.playerLevel, 15);
    expect(bloc.state.streak.current(StreakCategory.overall, now: now), 7);
  });

  test('match reset preserves the returning profile identity', () async {
    final storage = SecureGameStorage();
    await storage.bootstrapLocalProfiles(now: now);
    await storage.switchLocalProfile(LocalProfileSlot.returning);

    final bloc = GameBloc(storage)..add(GameLoaded());
    addTearDown(bloc.close);
    await bloc.stream.firstWhere((state) => !state.loading);
    bloc.add(MatchReset());
    await Future<void>.delayed(Duration.zero);

    expect(bloc.state.displayName, returningProfileDisplayName);
  });

  test(
    'preset is complete, playable, catalog-backed, and reconciled',
    () async {
      final storage = SecureGameStorage();
      await storage.bootstrapLocalProfiles(now: now);
      await storage.switchLocalProfile(LocalProfileSlot.returning);

      final progression = await storage.loadProgression();
      expect(progression.totalXP, 11250);
      expect(ProgressTrack.values.map(progression.xpFor), [
        1200,
        700,
        700,
        1000,
        600,
        900,
        850,
        850,
        900,
        900,
        1700,
        950,
      ]);
      final xpLedger = await storage.loadXpLedger();
      expect(xpLedger, hasLength(12));
      expect(
        xpLedger.map((entry) => entry.delta).reduce((a, b) => a + b),
        11250,
      );

      final wallet = await storage.loadWallet();
      expect(wallet.coins, 5000);
      expect(wallet.ownedCardIds.length, greaterThanOrEqualTo(30));
      expect(wallet.ownedActionCardIds, hasLength(12));
      expect(wallet.equippedCardBackId, 'cyan-circuit');
      expect(wallet.equippedAvatarFrameId, 'frame_liv');
      expect(
        wallet.ownedAvatarIds,
        containsAll(['bellingham', 'rodri', 'raphinha', 'camavinga']),
      );
      expect(
        wallet.ownedBannerIds,
        containsAll(['south_africa', 'green_red', 'czech']),
      );
      expect((await storage.loadCoinLedger()).single.balanceAfter, 5000);

      final unlocks = (await storage.loadUnlockProgress())!;
      expect(unlocks.unlockedSports, Sport.values.toSet());
      expect(unlocks.completedQuests, Sport.values.toSet());
      expect(unlocks.pendingReveals, isEmpty);
      expect(ArcadeGame.values.every(unlocks.isGameUnlocked), isTrue);

      expect(await storage.loadMatchHistory(), hasLength(18));
      expect(await storage.loadPredictions(), hasLength(15));
      expect(await storage.loadPredictionQuizzes(), hasLength(15));
      expect(await storage.loadPickPositions(), hasLength(15));
      for (final sport in Sport.values) {
        final predictions = (await storage.loadPredictions())
            .where((prediction) => _fixtureSport(prediction.matchId) == sport)
            .toList();
        expect(predictions, hasLength(3));
        final picks = (await storage.loadPickPositions())
            .where((pick) => pick.id.contains('-${sport.name}-'))
            .toList();
        expect(picks, hasLength(3));
        expect(
          (await storage.loadQuizProgress(sport)).byMode.values.every(
            (mode) =>
                mode.sets.values.where((set) => set.completed).length == 3,
          ),
          isTrue,
        );
      }

      final streak = (await storage.loadStreak())!;
      for (final category in StreakCategory.values) {
        expect(streak.current(category, now: now), 7);
      }
      expect(streak.celebrationQueue, isEmpty);

      final bloc = GameBloc(storage)..add(GameLoaded());
      addTearDown(bloc.close);
      await bloc.stream.firstWhere((state) => !state.loading);
      expect((await storage.loadDecks()).single.name, 'CHIEF XI');
      expect(bloc.state.sportDeckReadyCount, 5);
    },
  );

  test('version marker preserves later changes and slot isolation', () async {
    final storage = SecureGameStorage();
    await storage.bootstrapLocalProfiles(now: now);

    await storage.saveDisplayName('rookie-name');
    await storage.saveProgression(PlayerProgression(totalXP: 125));
    await storage.switchLocalProfile(LocalProfileSlot.returning);
    await storage.saveDisplayName('custom-chief');
    await storage.saveProgression(PlayerProgression(totalXP: 12000));
    await storage.switchLocalProfile(LocalProfileSlot.firstTime);

    await SecureGameStorage().bootstrapLocalProfiles(now: now);
    expect(await storage.loadDisplayName(), 'rookie-name');
    expect((await storage.loadProgression()).totalXP, 125);

    await storage.switchLocalProfile(LocalProfileSlot.returning);
    expect(await storage.loadDisplayName(), 'custom-chief');
    expect((await storage.loadProgression()).totalXP, 12000);
    expect(
      await const FlutterSecureStorage().read(
        key: 'statoz_returning_profile_preset_version',
      ),
      '$returningProfilePresetVersion',
    );
  });
}

Sport _fixtureSport(String fixtureId) {
  if (fixtureId.startsWith('epl_') || fixtureId.startsWith('fifa_')) {
    return Sport.football;
  }
  if (fixtureId.startsWith('ipl_')) return Sport.cricket;
  if (fixtureId.startsWith('401') || fixtureId.startsWith('wnba_')) {
    return Sport.basketball;
  }
  if (fixtureId.startsWith('f1_')) return Sport.motorsport;
  return Sport.tennis;
}
