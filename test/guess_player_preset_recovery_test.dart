import 'dart:convert';

import 'package:card_game/blocs/guess_player/guess_player_cubit.dart';
import 'package:card_game/data/guess_player_data.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/guess_player.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/services/returning_profile_preset.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime(2026, 10, 1, 12);
  final sports = <Sport, (List<GuessPlayerTimeline>, List<PlayerCard>)>{
    Sport.football: (footballGuessTimelines, footballPlayerCards),
    Sport.cricket: (cricketGuessTimelines, cricketPlayerCards),
    Sport.basketball: (basketballGuessTimelines, basketballPlayerCards),
  };

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'returning preset uses playable catalog puzzles for every sport',
    () async {
      final preset = await buildReturningProfilePreset(now: today);
      final settlements = Set<String>.from(
        jsonDecode(
              preset.preferences['pd_guess_player_reward_settlements_v1']
                  as String,
            )
            as List,
      );
      for (final entry in sports.entries) {
        final sport = entry.key;
        final repository = LocalGuessPlayerPuzzleRepository(
          sport: sport,
          timelines: entry.value.$1,
          players: entry.value.$2,
        );
        final archive = GuessPlayerArchive.fromJson(
          jsonDecode(
                preset.preferences['pd_guess_player_archive_${sport.name}_v2']
                    as String,
              )
              as Map<String, dynamic>,
        );
        expect(archive.resultsByDay, hasLength(3));
        for (final record in archive.resultsByDay.values) {
          final puzzle = repository.puzzleById(record.puzzleId);
          expect(puzzle, isNotNull);
          expect(puzzle!.playerId, record.playerId);
          expect(
            settlements,
            contains('guess-player:${sport.name}:${record.dayKey}'),
          );
          if (record.status == GuessPlayerResultStatus.lost) {
            expect(record.guessedPlayerIds, isNot(contains(record.playerId)));
          }
        }
      }
    },
  );

  test('returning profile opens Cricket without a duplicate reward', () async {
    final storage = SecureGameStorage();
    await storage.bootstrapLocalProfiles(now: today);
    await storage.switchLocalProfile(LocalProfileSlot.returning);
    final cubit = GuessPlayerCubit(
      sport: Sport.cricket,
      timelines: cricketGuessTimelines,
      allPlayers: cricketPlayerCards,
      storage: storage,
      now: () => today,
    );
    try {
      await cubit.load();
      expect(cubit.state.loadStatus, GuessPlayerLoadStatus.ready);
      expect(cubit.state.settlementPending, isFalse);
      await cubit.openToday();
      expect(cubit.state.viewMode, GuessPlayerViewMode.review);
    } finally {
      await cubit.close();
    }
  });

  test('saved preset IDs recover on load without losing results', () async {
    for (final entry in sports.entries) {
      SharedPreferences.setMockInitialValues({});
      final sport = entry.key;
      final players = entry.value.$2;
      final repository = LocalGuessPlayerPuzzleRepository(
        sport: sport,
        timelines: entry.value.$1,
        players: players,
      );
      final target = players.firstWhere(
        (player) => player.id == repository.puzzles.first.playerId,
      );
      final archive = GuessPlayerArchive(
        resultsByDay: {
          '2026-10-01': _record(
            '2026-10-01',
            'preset-${sport.name}-1',
            target.id,
            target.name,
          ),
          '2026-09-30': _record(
            '2026-09-30',
            'preset-${sport.name}-2',
            'missing-player',
            'Old preset target',
          ),
        },
      );
      final storage = SecureGameStorage();
      await storage.saveGuessPlayerArchive(sport, archive);
      final cubit = GuessPlayerCubit(
        sport: sport,
        timelines: entry.value.$1,
        allPlayers: players,
        storage: storage,
        repository: repository,
        now: () => today,
      );
      try {
        await cubit.load();
        expect(cubit.state.loadStatus, GuessPlayerLoadStatus.ready);
        final current = cubit.state.archive.resultsByDay['2026-10-01']!;
        expect(current.puzzleId, isNot(startsWith('preset-')));
        expect(current.playerId, target.id);
        expect(current.status, GuessPlayerResultStatus.won);
        expect(current.xpEarned, 25);
        expect(cubit.state.targetPlayer?.id, target.id);
        expect(cubit.state.settlementPending, isFalse);

        final previous = cubit.state.archive.resultsByDay['2026-09-30']!;
        expect(
          previous.puzzleId,
          repository.puzzleForDay(DateTime(2026, 9, 30)).id,
        );
        expect(previous.xpEarned, 25);
        expect(await cubit.openDay('2026-09-30'), isTrue);
        cubit.showHome();
        await cubit.openToday();
        expect(cubit.state.viewMode, GuessPlayerViewMode.review);

        final persisted = await storage.loadGuessPlayerArchive(sport);
        expect(
          persisted!.resultsByDay['2026-10-01']!.puzzleId,
          current.puzzleId,
        );
        expect(
          persisted.resultsByDay['2026-09-30']!.puzzleId,
          previous.puzzleId,
        );
        expect(
          await storage.loadGuessPlayerSettlementIds(),
          containsAll([
            'guess-player:${sport.name}:2026-10-01',
            'guess-player:${sport.name}:2026-09-30',
          ]),
        );
      } finally {
        await cubit.close();
      }
    }
  });
}

GuessPlayerDayRecord _record(
  String day,
  String puzzleId,
  String playerId,
  String playerName,
) => GuessPlayerDayRecord(
  dayKey: day,
  puzzleId: puzzleId,
  playerId: playerId,
  targetPlayerName: playerName,
  status: GuessPlayerResultStatus.won,
  guessedPlayerIds: [playerId],
  revealedClueCount: 2,
  attemptsRemaining: 5,
  score: 500,
  xpEarned: 25,
  elapsedMs: 10000,
  startedAtEpochMs: 1,
  completedAtEpochMs: 10001,
);
