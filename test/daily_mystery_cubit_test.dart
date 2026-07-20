import 'package:card_game/blocs/guess_driver/guess_driver_cubit.dart';
import 'package:card_game/blocs/guess_winner/guess_winner_cubit.dart';
import 'package:card_game/models/daily_mystery.dart';
import 'package:card_game/models/guess_driver.dart';
import 'package:card_game/models/guess_winner.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _slams = [
  GrandSlamCard(
    year: '2025',
    tournament: 'Wimbledon',
    category: 'Men Singles',
    winnerName: 'Carlos Alcaraz',
  ),
  GrandSlamCard(
    year: '2024',
    tournament: 'Australian Open',
    category: 'Women Singles',
    winnerName: 'Aryna Sabalenka',
  ),
];

const _races = [
  F1RaceCard(
    year: '2025',
    trackName: 'Silverstone',
    driverName: 'Lando Norris',
    teamName: 'McLaren',
    country: 'United Kingdom',
  ),
  F1RaceCard(
    year: '2024',
    trackName: 'Monza',
    driverName: 'Charles Leclerc',
    teamName: 'Ferrari',
    country: 'Italy',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  group('GuessWinnerCubit', () {
    test(
      'loads home, preserves ten-heart guessing, and records a win',
      () async {
        final cubit = GuessWinnerCubit(
          grandSlams: _slams,
          allPlayers: const [
            'Carlos Alcaraz',
            'Aryna Sabalenka',
            'Wrong Player',
          ],
          storage: SecureGameStorage(),
          now: () => DateTime(2026, 7, 19, 12),
        );
        addTearDown(cubit.close);

        await cubit.load();
        expect(cubit.state.loadStatus, DailyMysteryLoadStatus.ready);
        expect(cubit.state.viewMode, DailyMysteryViewMode.home);
        expect(cubit.state.todayKey, '2026-07-19');
        expect(
          cubit.targetForDay('2026-07-19').id,
          cubit.state.targetGrandSlam.id,
        );

        await cubit.openToday();
        expect(cubit.state.viewMode, DailyMysteryViewMode.play);

        cubit.submitGuess('Wrong Player');
        cubit.submitGuess('Wrong Player');
        expect(cubit.state.remainingHearts, 8);
        expect(cubit.state.guesses, ['Wrong Player', 'Wrong Player']);

        cubit.submitGuess(
          '  ${cubit.state.targetGrandSlam.winnerName.toUpperCase()}  ',
        );
        expect(cubit.state.gameState, GuessWinnerGameState.won);
        expect(cubit.state.viewMode, DailyMysteryViewMode.review);
        expect(cubit.state.freshResult, isTrue);
        expect(
          cubit.state.archive.resultsByDay['2026-07-19']!.heartsRemaining,
          8,
        );

        cubit.consumeResultReveal();
        expect(cubit.state.freshResult, isFalse);
        cubit.showHome();
        expect(cubit.state.viewMode, DailyMysteryViewMode.home);
        cubit.showLogs();
        expect(cubit.state.viewMode, DailyMysteryViewMode.logs);
      },
    );

    test('ten wrong guesses exhaust lives with the existing rules', () async {
      final cubit = GuessWinnerCubit(
        grandSlams: _slams,
        allPlayers: const ['Wrong Player'],
        storage: SecureGameStorage(),
        now: () => DateTime(2026, 7, 19, 12),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.openToday();

      for (var attempt = 0; attempt < GuessWinnerCubit.maxHearts; attempt++) {
        cubit.submitGuess('Wrong Player');
      }

      expect(cubit.state.remainingHearts, 0);
      expect(cubit.state.gameState, GuessWinnerGameState.lost);
      expect(cubit.state.viewMode, DailyMysteryViewMode.review);
      expect(cubit.state.guesses, hasLength(10));
    });

    test('rollover keeps today separate from historical review', () async {
      var now = DateTime(2026, 7, 18, 23, 58);
      final cubit = GuessWinnerCubit(
        grandSlams: _slams,
        allPlayers: const ['Carlos Alcaraz', 'Aryna Sabalenka'],
        storage: SecureGameStorage(),
        now: () => now,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.openToday();
      cubit.submitGuess(cubit.state.targetGrandSlam.winnerName);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      now = DateTime(2026, 7, 19, 0, 1);
      await cubit.refreshForCurrentDay();
      expect(cubit.state.todayKey, '2026-07-19');
      expect(cubit.state.activeDayKey, '2026-07-19');
      expect(cubit.state.viewMode, DailyMysteryViewMode.home);

      cubit.showLogs();
      await cubit.openDay('2026-07-18');
      expect(cubit.state.activeDayKey, '2026-07-18');
      expect(cubit.state.todayKey, '2026-07-19');
      expect(cubit.state.viewMode, DailyMysteryViewMode.review);
      expect(cubit.state.freshResult, isFalse);

      await cubit.openToday();
      expect(cubit.state.activeDayKey, '2026-07-19');
      expect(cubit.state.viewMode, DailyMysteryViewMode.play);
    });
  });

  group('GuessDriverCubit', () {
    test('skip immediately records the existing zero-heart loss', () async {
      final cubit = GuessDriverCubit(
        races: _races,
        allDrivers: const ['Lando Norris', 'Charles Leclerc'],
        storage: SecureGameStorage(),
        now: () => DateTime(2026, 7, 19, 12),
      );
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.openToday();

      cubit.skip();

      expect(cubit.state.gameState, GuessDriverGameState.lost);
      expect(cubit.state.remainingHearts, 0);
      expect(cubit.state.guesses, isEmpty);
      expect(cubit.state.viewMode, DailyMysteryViewMode.review);
      expect(cubit.state.archive.resultsByDay['2026-07-19']!.won, isFalse);
    });

    test(
      'wrong and correct guesses preserve matching and rewards data',
      () async {
        final cubit = GuessDriverCubit(
          races: _races,
          allDrivers: const ['Lando Norris', 'Charles Leclerc', 'Wrong Driver'],
          storage: SecureGameStorage(),
          now: () => DateTime(2026, 7, 19, 12),
        );
        addTearDown(cubit.close);
        await cubit.load();
        await cubit.openToday();

        cubit.submitGuess('Wrong Driver');
        expect(cubit.state.remainingHearts, 9);
        cubit.submitGuess(
          ' ${cubit.state.targetRace.driverName.toUpperCase()} ',
        );

        expect(cubit.state.gameState, GuessDriverGameState.won);
        expect(cubit.state.remainingHearts, 9);
        expect(cubit.state.archive.wonCount, 1);
        expect(cubit.state.archive.playedCount, 1);
        expect(cubit.state.archive.winRate, 1);
        expect(cubit.state.archive.bestHeartsRemaining, 9);
      },
    );

    test('daily target selection is deterministic across cubits', () async {
      GuessDriverCubit build() => GuessDriverCubit(
        races: _races,
        allDrivers: const ['Lando Norris', 'Charles Leclerc'],
        storage: SecureGameStorage(),
        now: () => DateTime(2026, 7, 19, 12),
      );

      final first = build();
      final second = build();
      addTearDown(first.close);
      addTearDown(second.close);
      await first.load();
      await second.load();

      expect(first.state.targetRace.id, second.state.targetRace.id);
      expect(
        first.targetForDay('2026-06-01').id,
        second.targetForDay('2026-06-01').id,
      );
      expect(first.archiveDayKeys(), hasLength(30));
      expect(first.archiveDayKeys().first, '2026-07-19');
    });
  });

  test('existing archive JSON remains serialization-compatible', () {
    final winner = GuessWinnerArchive.fromJson({
      'resultsByDay': {
        '2026-07-19': {
          'won': true,
          'heartsRemaining': 7,
          'targetWinnerName': 'Carlos Alcaraz',
        },
      },
    });
    final driver = GuessDriverArchive.fromJson({
      'resultsByDay': {
        '2026-07-19': {
          'won': false,
          'heartsRemaining': 0,
          'targetDriverName': 'Lando Norris',
        },
      },
    });

    expect(winner.toJson(), {
      'resultsByDay': {
        '2026-07-19': {
          'won': true,
          'heartsRemaining': 7,
          'targetWinnerName': 'Carlos Alcaraz',
        },
      },
    });
    expect(driver.toJson(), {
      'resultsByDay': {
        '2026-07-19': {
          'won': false,
          'heartsRemaining': 0,
          'targetDriverName': 'Lando Norris',
        },
      },
    });
  });

  test('archive metrics derive streak, rate, and best lives', () {
    const archive = GuessWinnerArchive(
      resultsByDay: {
        '2026-07-19': GuessWinnerDailyResult(
          won: true,
          heartsRemaining: 7,
          targetWinnerName: 'A',
        ),
        '2026-07-18': GuessWinnerDailyResult(
          won: true,
          heartsRemaining: 9,
          targetWinnerName: 'B',
        ),
        '2026-07-17': GuessWinnerDailyResult(
          won: false,
          heartsRemaining: 0,
          targetWinnerName: 'C',
        ),
      },
    );

    expect(archive.wonCount, 2);
    expect(archive.playedCount, 3);
    expect(archive.winRate, closeTo(2 / 3, 0.0001));
    expect(archive.bestHeartsRemaining, 9);
    expect(archive.winStreak('2026-07-19'), 2);
  });
}
