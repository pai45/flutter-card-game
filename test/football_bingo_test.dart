import 'package:card_game/blocs/football_bingo/football_bingo_cubit.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/data/football_bingo_puzzles.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/football_bingo.dart';
import 'package:card_game/screens/football_bingo/football_bingo_home_screen.dart';
import 'package:card_game/screens/football_bingo/football_bingo_hub.dart';
import 'package:card_game/screens/football_bingo/football_bingo_logs_screen.dart';
import 'package:card_game/screens/football_bingo/football_bingo_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:card_game/widgets/team_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<FootballBingoCubit> _loaded({DateTime? now}) async {
  final cubit = FootballBingoCubit(SecureGameStorage());
  await cubit.load(now: now);
  return cubit;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('seed puzzle is a valid 3x3 club-club grid', () {
    for (final puzzle in footballBingoPuzzles) {
      final errors = validateFootballBingoPuzzle(puzzle, allPlayerCards);
      expect(errors.map((e) => e.message), isEmpty);
    }
  });

  test(
    'archive creates day keys and rotates puzzles deterministically',
    () async {
      final firstDay = DateTime(2026, 1, 1, 9);
      final thirdDay = DateTime(2026, 1, 3, 9);
      final cubit = await _loaded(now: firstDay);
      await cubit.close();

      final reloaded = await _loaded(now: thirdDay);
      addTearDown(reloaded.close);

      expect(reloaded.state.unlockedDayKeys, [
        '2026-01-01',
        '2026-01-02',
        '2026-01-03',
      ]);
      expect(
        reloaded.state.archive.progressByDay['2026-01-03']!.puzzleId,
        footballBingoPuzzleForDayIndex(2).id,
      );
    },
  );

  test('legacy single progress migrates into a daily archive', () async {
    final storage = SecureGameStorage();
    final legacyCell = footballBingoPuzzles.first.cells.first.id;
    final legacy = FootballBingoProgress.initial(
      footballBingoPuzzles.first.id,
      DateTime(2026, 2, 4, 12),
    ).copyWith(solvedCellIds: [legacyCell], currentIndex: 1);
    await storage.saveFootballBingoProgress(legacy);

    final cubit = await _loaded(now: DateTime(2026, 2, 5, 10));
    addTearDown(cubit.close);

    expect(cubit.state.unlockedDayKeys, ['2026-02-04', '2026-02-05']);
    expect(
      cubit.state.archive.progressByDay['2026-02-04']!.solvedCellIds,
      contains(legacyCell),
    );
    expect(
      cubit.state.archive.progressByDay['2026-02-04']!.cellOrderIds,
      hasLength(9),
    );
  });

  test('daily prompt order is shuffled and persists across reloads', () async {
    final day = DateTime(2026, 4, 8, 9);
    final cubit = await _loaded(now: day);
    final authored = cubit.state.puzzle.cells.map((cell) => cell.id).toList();
    final order = cubit.state.progress.cellOrderIds;
    await cubit.close();

    final reloaded = await _loaded(now: day);
    addTearDown(reloaded.close);

    expect(order, hasLength(9));
    expect(order.toSet(), authored.toSet());
    expect(order, isNot(authored));
    expect(reloaded.state.progress.cellOrderIds, order);
    expect(reloaded.state.currentCell!.id, order.first);
  });

  test('correct answers solve and wrong answers spend lifelines', () async {
    final cubit = await _loaded();
    addTearDown(cubit.close);

    final first = cubit.state.currentCell!;
    final wrong = cubit.state.puzzle.cells.firstWhere(
      (cell) => cell.id != first.id,
    );
    expect(await cubit.selectCell(wrong.id), isFalse);
    expect(cubit.state.progress.lifelines, 4);
    expect(cubit.state.progress.solvedCellIds, isEmpty);

    expect(await cubit.selectCell(first.id), isTrue);
    expect(cubit.state.progress.solvedCellIds, contains(first.id));
    expect(cubit.state.currentCell!.id, isNot(first.id));
  });

  test(
    'zero lifelines blocks play until a 25 coin lifeline is bought',
    () async {
      final cubit = await _loaded();
      addTearDown(cubit.close);

      for (var i = 0; i < kFootballBingoStartingLifelines; i++) {
        final current = cubit.state.currentCell!;
        final wrong = cubit.state.puzzle.cells.firstWhere(
          (cell) => cell.id != current.id,
        );
        await cubit.selectCell(wrong.id);
      }
      expect(cubit.state.needsLifeline, isTrue);

      final blockedCell = cubit.state.currentCell!;
      await cubit.selectCell(blockedCell.id);
      expect(cubit.state.progress.solvedCellIds, isEmpty);

      expect(await cubit.buyLifeline(24), isFalse);
      expect(cubit.state.progress.lifelines, 0);
      expect(await cubit.buyLifeline(25), isTrue);
      expect(cubit.state.progress.lifelines, 1);
    },
  );

  test('progress persists across reloads', () async {
    final cubit = await _loaded();
    final first = cubit.state.currentCell!;
    final wrong = cubit.state.puzzle.cells.firstWhere(
      (cell) => cell.id != first.id,
    );
    await cubit.selectCell(first.id);
    await cubit.selectCell(wrong.id);
    await cubit.close();

    final reloaded = await _loaded();
    addTearDown(reloaded.close);

    expect(reloaded.state.progress.solvedCellIds, contains(first.id));
    expect(reloaded.state.progress.lifelines, 4);
  });

  test('previous days are read-only', () async {
    final cubit = await _loaded(now: DateTime(2026, 3, 1, 9));
    await cubit.close();

    final reloaded = await _loaded(now: DateTime(2026, 3, 2, 9));
    addTearDown(reloaded.close);
    await reloaded.openDay('2026-03-01', now: DateTime(2026, 3, 2, 9));

    expect(reloaded.state.readOnly, isTrue);
    expect(
      await reloaded.selectCell(reloaded.state.puzzle.cells.first.id),
      isFalse,
    );
    expect(reloaded.state.progress.solvedCellIds, isEmpty);
    expect(await reloaded.buyLifeline(100), isFalse);
  });

  testWidgets('screen renders grid, player, and lifelines', (tester) async {
    final bingo = await _loaded();
    final game = GameBloc(SecureGameStorage())..add(GameLoaded());
    addTearDown(bingo.close);
    addTearDown(game.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bingo),
            BlocProvider.value(value: game),
          ],
          child: FootballBingoScreen(onBack: () {}, onCompleted: () {}),
        ),
      ),
    );
    await tester.pump();

    final player = bingo.state.currentPlayer!;
    expect(find.text('BINGO GRID'), findsOneWidget);
    expect(find.byType(TeamLogo), findsNWidgets(6));
    await tester.drag(find.byType(ListView), const Offset(0, -260));
    await tester.pump();
    expect(find.text(player.position), findsOneWidget);
    expect(find.text(player.trait.toUpperCase()), findsOneWidget);
    expect(find.text(player.name), findsNothing);
    expect(find.text(player.countryCode), findsNothing);
    expect(find.byIcon(Icons.favorite), findsWidgets);
  });

  testWidgets('bingo home renders today, archive, and opens today grid', (
    tester,
  ) async {
    final game = GameBloc(SecureGameStorage())..add(GameLoaded());
    addTearDown(game.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: game,
          child: FootballBingoTabContent(onNavigate: (_) {}),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('FOOTBALL BINGO'), findsOneWidget);
    expect(find.text('DAILY LOGS'), findsOneWidget);
    expect(find.text('PLAY TODAY\'S GRID'), findsOneWidget);

    await tester.tap(find.text('PLAY TODAY\'S GRID'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('BINGO GRID'), findsOneWidget);
    final active = find.textContaining('/');
    expect(active, findsWidgets);
  });

  testWidgets('bingo home keeps log cards off the landing page', (
    tester,
  ) async {
    final bingo = await _loaded();
    for (var i = 0; i < 9; i++) {
      await bingo.selectCell(bingo.state.currentCell!.id);
    }
    final state = bingo.state;
    await bingo.close();

    await tester.pumpWidget(
      MaterialApp(
        home: FootballBingoHomeScreen(
          state: state,
          onBack: () {},
          onOpenDay: (_) {},
          onOpenLogs: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('DAILY LOGS'), findsOneWidget);
    expect(find.text('COMPLETED GRID'), findsNothing);
  });

  testWidgets('daily logs page uses the date as the log title', (tester) async {
    final cubit = await _loaded(now: DateTime(2026, 7, 2, 9));
    addTearDown(cubit.close);

    while (!cubit.state.completed) {
      await cubit.selectCell(cubit.state.currentCell!.id);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: FootballBingoLogsScreen(
          state: cubit.state,
          onBack: () {},
          onOpenDay: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('BINGO LOGS'), findsOneWidget);
    expect(find.text('JUL 2, 2026'), findsOneWidget);
    expect(find.text('CLUB CONNECTIONS'), findsNothing);
    expect(find.text('COMPLETED'), findsOneWidget);
  });

  testWidgets('completion overlay appears and returns home', (tester) async {
    final bingo = await _loaded();
    final game = GameBloc(SecureGameStorage())..add(GameLoaded());
    addTearDown(bingo.close);
    addTearDown(game.close);

    for (var i = 0; i < 8; i++) {
      await bingo.selectCell(bingo.state.currentCell!.id);
    }
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider.value(value: bingo),
            BlocProvider.value(value: game),
          ],
          child: FootballBingoScreen(
            onBack: () {},
            onCompleted: () => completed = true,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1000));

    final finalCell = bingo.state.currentCell!.id;
    final finalCellFinder = find.byKey(ValueKey('bingo-cell-$finalCell'));
    await tester.ensureVisible(finalCellFinder);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(finalCellFinder);
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byKey(const ValueKey('bingo-card-reveal')), findsNothing);
    for (var i = 0; i < 120 && !completed; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(completed, isTrue);
  });
}
