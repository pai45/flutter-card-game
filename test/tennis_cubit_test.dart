import 'dart:math';

import 'package:card_game/blocs/tennis/tennis_cubit.dart';
import 'package:card_game/models/tennis.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('settles a match exactly once and persists career progress', () async {
    final storage = SecureGameStorage();
    final cubit = TennisCubit(storage);
    addTearDown(cubit.close);
    await cubit.load();
    final config = cubit.buildMatch(mode: TennisMode.quickMatch);
    final summary = _summary(config, won: true, playerGames: 6);

    final reward = await cubit.settle(summary);
    final duplicate = await cubit.settle(summary);

    expect(reward.xp, greaterThan(0));
    expect(duplicate, TennisReward.zero);
    expect(cubit.state.profile.setsPlayed, 1);
    expect(cubit.state.profile.setsWon, 1);
    expect(cubit.state.profile.settledMatchIds, contains(config.matchId));
    final restored = await storage.loadTennisProfile();
    expect(restored.setsWon, 1);
    expect(restored.settledMatchIds, contains(config.matchId));
  });

  test('saves an exact resume record and deliberate quit clears it', () async {
    final storage = SecureGameStorage();
    final cubit = TennisCubit(storage);
    addTearDown(cubit.close);
    await cubit.load();
    final config = cubit.buildMatch(mode: TennisMode.targetPractice);
    final snapshot = TennisMatchSnapshot(
      config: config,
      engine: const <String, dynamic>{
        'rng': 42,
        'ball': <String, dynamic>{'x': 1.2, 'z': 0.8},
      },
      savedAtMillis: 123,
    );
    await cubit.saveSnapshot(snapshot);
    expect((await storage.loadTennisMatchSnapshot())?.engine['rng'], 42);
    expect(cubit.state.canResume, isTrue);

    await cubit.abandonMatch();
    expect(cubit.state.canResume, isFalse);
    expect(await storage.loadTennisMatchSnapshot(), isNull);
  });

  test('mirrors the granted deck card into the profile and persists it', () async {
    final storage = SecureGameStorage();
    final cubit = TennisCubit(storage, random: Random(7));
    addTearDown(cubit.close);
    await cubit.load();

    expect(cubit.state.profile.starterPackClaimed, isFalse);
    const starterId = 'frances-tiafoe';
    await cubit.syncFromDeck(const [starterId], starterId);

    expect(cubit.state.profile.starterPackClaimed, isTrue);
    expect(cubit.state.profile.ownedPlayerIds, [starterId]);
    expect(cubit.state.profile.selectedPlayerId, starterId);
    expect(cubit.state.profile.lastOpponentId, isNot(starterId));
    final restored = await storage.loadTennisProfile();
    expect(restored.starterPackClaimed, isTrue);
    expect(restored.ownedPlayerIds, [starterId]);
  });

  test('ignores deck ids that are not on the tennis roster', () async {
    final storage = SecureGameStorage();
    final cubit = TennisCubit(storage, random: Random(7));
    addTearDown(cubit.close);
    await cubit.load();

    await cubit.syncFromDeck(const ['eng-harry-kane'], 'eng-harry-kane');

    expect(cubit.state.profile.starterPackClaimed, isFalse);
    expect(cubit.state.profile.ownedPlayerIds, isEmpty);
  });

  test('quick-match preview rolls a deterministic rated rival', () async {
    final firstStorage = SecureGameStorage();
    final first = TennisCubit(firstStorage, random: Random(11));
    addTearDown(first.close);
    await first.load();
    await first.syncFromDeck(const ['frances-tiafoe'], 'frances-tiafoe');
    first.prepareQuickMatchPreview();
    final firstProfile = first.state.profile;

    SharedPreferences.setMockInitialValues({});
    final secondStorage = SecureGameStorage();
    final second = TennisCubit(secondStorage, random: Random(11));
    addTearDown(second.close);
    await second.load();
    await second.syncFromDeck(const ['frances-tiafoe'], 'frances-tiafoe');
    second.prepareQuickMatchPreview();
    final secondProfile = second.state.profile;

    expect(firstProfile.selectedPlayerId, secondProfile.selectedPlayerId);
    expect(firstProfile.lastOpponentId, secondProfile.lastOpponentId);
    expect(firstProfile.lastOpponentId, isNot(firstProfile.selectedPlayerId));
    expect(
      tennisPlayers.map((player) => player.id),
      contains(firstProfile.lastOpponentId),
    );
  });

  test('continues all three tournament rounds and awards the title', () async {
    final storage = SecureGameStorage();
    final cubit = TennisCubit(storage);
    addTearDown(cubit.close);
    await cubit.load();
    cubit.selectDifficulty(TennisDifficulty.rookie);
    cubit.prepareTournament();
    final tournamentId = cubit.state.profile.tournament!.id;

    for (var round = 0; round < 3; round++) {
      final config = cubit.buildMatch(mode: TennisMode.tournament);
      expect(config.tournamentId, tournamentId);
      expect(config.tournamentRound, round);
      await cubit.settle(
        _summary(
          config,
          won: true,
          playerGames: 6,
          tournamentChampion: round == 2,
        ),
      );
    }

    final tournament = cubit.state.profile.tournament!;
    expect(tournament.active, isFalse);
    expect(tournament.champion, isTrue);
    expect(tournament.results, ['W', 'W', 'W']);
    expect(cubit.state.profile.trophies['rookie'], 1);
    expect(cubit.state.profile.achievements, contains('champion'));
    expect(cubit.state.profile.isPlayerUnlocked('frances-tiafoe'), isFalse);
  });
}

TennisMatchSummary _summary(
  TennisMatchConfig config, {
  required bool won,
  required int playerGames,
  bool tournamentChampion = false,
}) => TennisMatchSummary(
  matchId: config.matchId,
  mode: config.mode,
  playerId: config.playerId,
  opponentId: config.opponentId,
  difficulty: config.difficulty,
  playerGames: playerGames,
  opponentGames: won ? 2 : 6,
  won: won,
  stats: const TennisMatchStats(
    aces: 1,
    winners: 5,
    firstServesIn: 5,
    firstServesAttempted: 8,
    perfectContacts: 2,
    longestRally: 10,
    shotTypesUsed: {TennisShotType.normal, TennisShotType.topspin},
  ),
  tournamentChampion: tournamentChampion,
);
