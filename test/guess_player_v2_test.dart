import 'dart:convert';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/guess_player/guess_player_cubit.dart';
import 'package:card_game/data/guess_player_data.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/guess_player.dart';
import 'package:card_game/models/sport_match.dart';
import 'package:card_game/models/streak.dart';
import 'package:card_game/models/xp_ledger.dart';
import 'package:card_game/screens/guess_player/widgets/guess_player_result_view.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('local daily puzzle repository', () {
    test('builds a valid non-repeating 30-day deck for every sport', () {
      final repositories = [
        LocalGuessPlayerPuzzleRepository(
          sport: Sport.football,
          timelines: footballGuessTimelines,
          players: footballPlayerCards,
        ),
        LocalGuessPlayerPuzzleRepository(
          sport: Sport.basketball,
          timelines: basketballGuessTimelines,
          players: basketballPlayerCards,
        ),
        LocalGuessPlayerPuzzleRepository(
          sport: Sport.cricket,
          timelines: cricketGuessTimelines,
          players: cricketPlayerCards,
        ),
      ];

      for (final repository in repositories) {
        expect(repository.validate(), isEmpty);
        expect(repository.puzzles, hasLength(greaterThanOrEqualTo(30)));
        expect(
          repository.puzzles.every((puzzle) => puzzle.clues.length == 6),
          isTrue,
        );
        final firstCycle = {
          for (var day = 0; day < 30; day++)
            repository.puzzleForDay(DateTime(2026, 1, 1 + day)).id,
        };
        expect(firstCycle, hasLength(30));
        expect(
          repository.puzzleForDay(DateTime(2026, 7, 18)).id,
          repository.puzzleForDay(DateTime(2026, 7, 18)).id,
        );
      }

      final ids = repositories
          .map(
            (repository) => repository.puzzleForDay(DateTime(2026, 7, 18)).id,
          )
          .toSet();
      expect(ids, hasLength(3));
    });

    test('search folding handles diacritics and token separators', () {
      expect(
        normalizeGuessPlayerSearch('  Vinícius-Júnior '),
        'vinicius junior',
      );
      expect(
        normalizeGuessPlayerSearch('KÉVIN   DE BRUYNE'),
        'kevin de bruyne',
      );
    });

    test('empty banks fail validation and selection explicitly', () {
      final repository = LocalGuessPlayerPuzzleRepository(
        sport: Sport.football,
        timelines: const [],
        players: const [],
      );

      expect(repository.validate(), isNotEmpty);
      expect(
        () => repository.puzzleForDay(DateTime(2026, 7, 18)),
        throwsStateError,
      );
    });

    test('daily routes use six chronological career-only nodes', () {
      final repository = _footballRepository();
      final timeline = footballGuessTimelines.first;
      final puzzle = repository.puzzles.firstWhere(
        (candidate) =>
            candidate.playerId ==
            footballPlayerCards
                .firstWhere((player) => player.name == timeline.playerName)
                .id,
      );
      final careerClues = puzzle.clues
          .where((clue) => clue.kind == GuessPlayerClueKind.career)
          .toList();

      expect(careerClues, isNotEmpty);
      expect(puzzle.clues.first.kind, GuessPlayerClueKind.career);
      expect(puzzle.clues, hasLength(6));
      expect(
        puzzle.clues.every((clue) => clue.kind == GuessPlayerClueKind.career),
        isTrue,
      );
      expect(
        careerClues.map((clue) => clue.year).whereType<int>(),
        orderedEquals(
          careerClues.map((clue) => clue.year).whereType<int>().toList()
            ..sort(),
        ),
      );
      expect(
        puzzle.clues.where((clue) => clue.kind == GuessPlayerClueKind.role),
        isEmpty,
      );
    });
  });

  group('GuessPlayerCubit v2 mechanics', () {
    test(
      'reveals clues, ignores duplicate guesses, scores and resumes',
      () async {
        final cubit = _footballCubit();
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.openToday();

        expect(cubit.state.attemptsRemaining, 6);
        expect(cubit.state.revealedClueCount, 1);
        final target = cubit.state.targetPlayer!;
        final wrong = footballPlayerCards.firstWhere(
          (player) => player.id != target.id,
        );

        await cubit.submitGuess(wrong);
        expect(cubit.state.attemptsRemaining, 5);
        expect(cubit.state.revealedClueCount, 2);
        expect(cubit.state.guesses, [wrong]);

        await cubit.submitGuess(wrong);
        expect(cubit.state.attemptsRemaining, 5);
        expect(cubit.state.feedback, GuessPlayerSubmissionFeedback.duplicate);

        await cubit.submitGuess(target);
        final result = cubit.state.activeRecord!;
        expect(result.status, GuessPlayerResultStatus.won);
        expect(result.score, 500);
        expect(result.xpEarned, 45);
        expect(cubit.state.settlementPending, isTrue);

        final restored = _footballCubit();
        addTearDown(restored.close);
        await restored.load();
        expect(
          restored.state.archive.resultsByDay['2026-07-18']?.status,
          GuessPlayerResultStatus.won,
        );
        await restored.openToday();
        expect(restored.state.viewMode, GuessPlayerViewMode.review);
        expect(restored.state.settlementPending, isTrue);
      },
    );

    test(
      'six wrong guesses exhaust hearts, then a paid extra attempt restores one guess',
      () async {
        final cubit = _footballCubit();
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.openToday();
        final targetId = cubit.state.targetPlayer!.id;
        final wrong = footballPlayerCards
            .where((player) => player.id != targetId)
            .take(6)
            .toList();

        for (final player in wrong) {
          await cubit.submitGuess(player);
        }

        expect(
          cubit.state.activeRecord?.status,
          GuessPlayerResultStatus.inProgress,
        );
        expect(cubit.state.viewMode, GuessPlayerViewMode.play);
        expect(cubit.state.attemptsRemaining, 0);
        expect(cubit.state.revealedClueCount, 6);
        expect(cubit.state.activeRecord?.xpEarned, 0);
        expect(cubit.state.settlementPending, isFalse);

        expect(await cubit.buyExtraAttempt(), isTrue);
        expect(cubit.state.attemptsRemaining, 1);
        expect(cubit.state.revealedClueCount, 6);

        final nextWrong = footballPlayerCards.firstWhere(
          (player) =>
              player.id != targetId &&
              !cubit.state.activeRecord!.guessedPlayerIds.contains(player.id),
        );
        await cubit.submitGuess(nextWrong);
        expect(cubit.state.attemptsRemaining, 0);
        expect(
          cubit.state.activeRecord?.status,
          GuessPlayerResultStatus.inProgress,
        );
      },
    );

    test('give up is distinct from running out of attempts', () async {
      final cubit = _footballCubit();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.openToday();

      await cubit.giveUp();

      expect(cubit.state.activeRecord?.status, GuessPlayerResultStatus.gaveUp);
      expect(cubit.state.attemptsRemaining, 6);
      expect(cubit.state.revealedClueCount, 6);
      expect(cubit.state.activeRecord?.score, 0);
    });

    test(
      'purchased profile hint persists without spending an attempt or clue',
      () async {
        final cubit = _footballCubit();
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.openToday();

        await cubit.unlockHint(GuessPlayerHintType.affiliation);

        expect(cubit.state.hasHint(GuessPlayerHintType.affiliation), isTrue);
        expect(
          cubit.state.activeRecord?.hasHint(GuessPlayerHintType.affiliation),
          isTrue,
        );
        expect(cubit.state.attemptsRemaining, 6);
        expect(cubit.state.revealedClueCount, 1);

        final restored = _footballCubit();
        addTearDown(restored.close);
        await restored.load();
        expect(restored.state.hasHint(GuessPlayerHintType.affiliation), isTrue);
      },
    );

    test('a first-attempt solve pays the full score and XP', () async {
      final cubit = _footballCubit();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.openToday();

      await cubit.submitGuess(cubit.state.targetPlayer!);

      expect(cubit.state.activeRecord?.score, 600);
      expect(cubit.state.activeRecord?.xpEarned, 50);
      expect(cubit.state.loadStatus, GuessPlayerLoadStatus.completed);
    });

    test(
      'reviewing a past v1 result never changes the real current day',
      () async {
        SharedPreferences.setMockInitialValues({
          'pd_guess_player_archive_football_v1': jsonEncode({
            'resultsByDay': {
              '2026-07-02': {
                'won': true,
                'heartsRemaining': 7,
                'targetPlayerName': 'Lionel Messi',
              },
            },
          }),
        });
        final cubit = _footballCubit();
        addTearDown(cubit.close);
        await cubit.load();

        expect(cubit.state.archive.resultsByDay['2026-07-02']?.legacy, isTrue);
        expect(await cubit.openDay('2026-07-02'), isTrue);
        expect(cubit.state.activeDayKey, '2026-07-02');
        expect(cubit.state.currentDayKey, '2026-07-18');

        cubit.showHome();
        expect(cubit.state.activeDayKey, '2026-07-18');
        expect(cubit.state.currentDayKey, '2026-07-18');
      },
    );

    test('unfinished earlier sessions expire on load', () async {
      final repository = _footballRepository();
      final puzzle = repository.puzzleForDay(DateTime(2026, 7, 17));
      final target = footballPlayerCards.firstWhere(
        (player) => player.id == puzzle.playerId,
      );
      final record = GuessPlayerDayRecord(
        dayKey: '2026-07-17',
        puzzleId: puzzle.id,
        playerId: target.id,
        targetPlayerName: target.name,
        status: GuessPlayerResultStatus.inProgress,
        guessedPlayerIds: const [],
        revealedClueCount: 1,
        attemptsRemaining: 6,
        score: 0,
        xpEarned: 0,
        elapsedMs: 0,
        startedAtEpochMs: 1,
        completedAtEpochMs: 0,
      );
      SharedPreferences.setMockInitialValues({
        'pd_guess_player_archive_football_v2': jsonEncode(
          GuessPlayerArchive(resultsByDay: {'2026-07-17': record}).toJson(),
        ),
      });
      final cubit = _footballCubit();
      addTearDown(cubit.close);
      await cubit.load();

      expect(
        cubit.state.archive.resultsByDay['2026-07-17']?.status,
        GuessPlayerResultStatus.expired,
      );
      expect(await cubit.openDay('2026-07-17'), isFalse);
    });

    test(
      'a date rollover expires the old session and opens a new day',
      () async {
        var clock = DateTime(2026, 7, 18, 23, 59);
        final cubit = GuessPlayerCubit(
          sport: Sport.football,
          timelines: footballGuessTimelines,
          allPlayers: footballPlayerCards,
          storage: SecureGameStorage(),
          repository: _footballRepository(),
          now: () => clock,
        );
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.openToday();

        clock = DateTime(2026, 7, 19, 0, 1);
        await cubit.refreshForCurrentDay();

        expect(cubit.state.currentDayKey, '2026-07-19');
        expect(cubit.state.activeDayKey, '2026-07-19');
        expect(
          cubit.state.archive.resultsByDay['2026-07-18']?.status,
          GuessPlayerResultStatus.expired,
        );
      },
    );

    test('stored puzzle ID wins over a changed daily schedule', () async {
      final base = _footballRepository();
      final storedPuzzle = base.puzzles.first;
      final scheduledPuzzle = base.puzzles[1];
      final target = footballPlayerCards.firstWhere(
        (player) => player.id == storedPuzzle.playerId,
      );
      final record = GuessPlayerDayRecord(
        dayKey: '2026-07-18',
        puzzleId: storedPuzzle.id,
        playerId: storedPuzzle.playerId,
        targetPlayerName: target.name,
        status: GuessPlayerResultStatus.inProgress,
        guessedPlayerIds: const [],
        revealedClueCount: 1,
        attemptsRemaining: 6,
        score: 0,
        xpEarned: 0,
        elapsedMs: 0,
        startedAtEpochMs: 0,
        completedAtEpochMs: 0,
      );
      SharedPreferences.setMockInitialValues({
        'pd_guess_player_archive_football_v2': jsonEncode(
          GuessPlayerArchive(resultsByDay: {'2026-07-18': record}).toJson(),
        ),
      });
      final cubit = GuessPlayerCubit(
        sport: Sport.football,
        timelines: footballGuessTimelines,
        allPlayers: footballPlayerCards,
        storage: SecureGameStorage(),
        repository: _ScheduleOverrideRepository(
          base: base,
          scheduledPuzzle: scheduledPuzzle,
        ),
        now: () => DateTime(2026, 7, 18, 12),
      );
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.puzzle?.id, storedPuzzle.id);
      expect(cubit.state.targetPlayer?.id, storedPuzzle.playerId);
    });

    test('missing stored puzzle IDs produce a retryable data error', () async {
      final player = footballPlayerCards.first;
      final record = GuessPlayerDayRecord(
        dayKey: '2026-07-18',
        puzzleId: 'removed-puzzle',
        playerId: player.id,
        targetPlayerName: player.name,
        status: GuessPlayerResultStatus.inProgress,
        guessedPlayerIds: const [],
        revealedClueCount: 1,
        attemptsRemaining: 6,
        score: 0,
        xpEarned: 0,
        elapsedMs: 0,
        startedAtEpochMs: 0,
        completedAtEpochMs: 0,
      );
      SharedPreferences.setMockInitialValues({
        'pd_guess_player_archive_football_v2': jsonEncode(
          GuessPlayerArchive(resultsByDay: {'2026-07-18': record}).toJson(),
        ),
      });
      final cubit = _footballCubit();
      addTearDown(cubit.close);

      await cubit.load();

      expect(cubit.state.loadStatus, GuessPlayerLoadStatus.error);
      expect(cubit.state.errorMessage, contains('removed-puzzle'));
    });

    test('persistence errors do not consume an attempt', () async {
      final storage = _ToggleFailStorage();
      final cubit = GuessPlayerCubit(
        sport: Sport.football,
        timelines: footballGuessTimelines,
        allPlayers: footballPlayerCards,
        storage: storage,
        repository: _footballRepository(),
        now: () => DateTime(2026, 7, 18, 12),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.openToday();
      final targetId = cubit.state.targetPlayer!.id;
      final wrong = footballPlayerCards.firstWhere(
        (player) => player.id != targetId,
      );
      storage.failSaves = true;

      await cubit.submitGuess(wrong);

      expect(cubit.state.loadStatus, GuessPlayerLoadStatus.error);
      expect(cubit.state.saving, isFalse);
      expect(cubit.state.attemptsRemaining, 6);
      expect(cubit.state.guesses, isEmpty);
      expect(cubit.state.errorMessage, contains('Could not save this guess'));
    });

    test('completed review mode is immutable', () async {
      final cubit = _footballCubit();
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.openToday();
      await cubit.submitGuess(cubit.state.targetPlayer!);
      final completed = cubit.state.activeRecord;
      final other = footballPlayerCards.firstWhere(
        (player) => player.id != cubit.state.targetPlayer!.id,
      );

      await cubit.submitGuess(other);
      await cubit.giveUp();

      expect(cubit.state.activeRecord, same(completed));
      expect(cubit.state.viewMode, GuessPlayerViewMode.review);
    });
  });

  test('share copy is complete and never exposes the answer', () {
    final puzzle = _footballRepository().puzzles.first;
    final target = footballPlayerCards.firstWhere(
      (player) => player.id == puzzle.playerId,
    );
    final record = GuessPlayerDayRecord(
      dayKey: '2026-07-18',
      puzzleId: puzzle.id,
      playerId: target.id,
      targetPlayerName: target.name,
      status: GuessPlayerResultStatus.won,
      guessedPlayerIds: const ['wrong-player', 'correct-player'],
      revealedClueCount: 2,
      attemptsRemaining: 5,
      score: 500,
      xpEarned: 45,
      elapsedMs: 12000,
      startedAtEpochMs: 1,
      completedAtEpochMs: 12001,
    );

    final share = buildGuessPlayerShareText(record: record, puzzle: puzzle);

    expect(share, contains('FOOTBALL · 2026-07-18'));
    expect(share, contains('2/6'));
    expect(share, contains('SCORE 500 · +45 XP'));
    expect(share, isNot(contains(target.name)));
    expect(share.split('\n'), hasLength(9));
  });

  test('daily settlement awards XP and streak exactly once', () async {
    final bloc = GameBloc(SecureGameStorage())..add(GameLoaded());
    addTearDown(bloc.close);
    final loaded = await bloc.stream
        .firstWhere((state) => !state.loading)
        .timeout(const Duration(seconds: 5));

    final event = DailyGuessPlayerSettled(
      sport: Sport.football,
      dayKey: '2026-07-18',
      xp: 45,
      score: 500,
      won: true,
      completedAt: DateTime(2026, 7, 18, 12),
    );
    bloc.add(event);
    bloc.add(event);
    final settled = await bloc.stream
        .firstWhere(
          (state) =>
              state.progression.totalXP == loaded.progression.totalXP + 45,
        )
        .timeout(const Duration(seconds: 5));

    expect(settled.xpLedger.first.source, XpTransactionSource.guessPlayer);
    expect(
      settled.streak.activitiesOn(DateTime(2026, 7, 18)),
      contains(StreakActivity.guessPlayer),
    );

    bloc.add(event);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(bloc.state.progression.totalXP, settled.progression.totalXP);
    expect(
      bloc.state.xpLedger.where(
        (entry) => entry.source == XpTransactionSource.guessPlayer,
      ),
      hasLength(1),
    );
  });
}

LocalGuessPlayerPuzzleRepository _footballRepository() {
  return LocalGuessPlayerPuzzleRepository(
    sport: Sport.football,
    timelines: footballGuessTimelines,
    players: footballPlayerCards,
  );
}

GuessPlayerCubit _footballCubit() {
  return GuessPlayerCubit(
    sport: Sport.football,
    timelines: footballGuessTimelines,
    allPlayers: footballPlayerCards,
    storage: SecureGameStorage(),
    repository: _footballRepository(),
    now: () => DateTime(2026, 7, 18, 12),
  );
}

class _ScheduleOverrideRepository implements GuessPlayerPuzzleRepository {
  _ScheduleOverrideRepository({
    required this.base,
    required this.scheduledPuzzle,
  });

  final GuessPlayerPuzzleRepository base;
  final GuessPlayerPuzzle scheduledPuzzle;

  @override
  List<GuessPlayerPuzzle> get puzzles => base.puzzles;

  @override
  GuessPlayerPuzzle? puzzleById(String id) => base.puzzleById(id);

  @override
  GuessPlayerPuzzle puzzleForDay(DateTime day) => scheduledPuzzle;

  @override
  List<String> validate() => base.validate();
}

class _ToggleFailStorage extends SecureGameStorage {
  bool failSaves = false;

  @override
  Future<void> saveGuessPlayerArchive(Sport sport, GuessPlayerArchive archive) {
    if (failSaves) {
      throw StateError('simulated storage failure');
    }
    return super.saveGuessPlayerArchive(sport, archive);
  }
}
