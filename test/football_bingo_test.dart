import 'package:card_game/blocs/football_bingo/football_bingo_cubit.dart';
import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/data/football_bingo_puzzles.dart';
import 'package:card_game/models/cards.dart';
import 'package:card_game/models/football_bingo.dart';
import 'package:card_game/screens/football_bingo/football_bingo_hub.dart';
import 'package:card_game/screens/football_bingo/football_bingo_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
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

  test('seed puzzle is a valid 3x3 player country grid', () {
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
    final legacy = FootballBingoProgress.initial(
      footballBingoPuzzles.first.id,
      DateTime(2026, 2, 4, 12),
    ).copyWith(solvedCellIds: ['psg-uru'], currentIndex: 1);
    await storage.saveFootballBingoProgress(legacy);

    final cubit = await _loaded(now: DateTime(2026, 2, 5, 10));
    addTearDown(cubit.close);

    expect(cubit.state.unlockedDayKeys, ['2026-02-04', '2026-02-05']);
    expect(
      cubit.state.archive.progressByDay['2026-02-04']!.solvedCellIds,
      contains('psg-uru'),
    );
  });

  test('correct answers solve and wrong answers spend lifelines', () async {
    final cubit = await _loaded();
    addTearDown(cubit.close);

    final first = cubit.state.currentCell!;
    expect(await cubit.selectCell('psg-bra'), isFalse);
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
        await cubit.selectCell('psg-bra');
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
    await cubit.selectCell(first.id);
    await cubit.selectCell('psg-por');
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
    expect(await reloaded.selectCell('psg-uru'), isFalse);
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

    expect(find.text('BINGO GRID'), findsOneWidget);
    expect(find.text('URU'), findsOneWidget);
    expect(find.text('PSG'), findsOneWidget);
    expect(find.text('Manuel Ugarte'), findsOneWidget);
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
    expect(find.text('TODAY\'S GRID'), findsOneWidget);
    expect(find.text('PLAY TODAY\'S GRID'), findsOneWidget);

    await tester.tap(find.text('PLAY TODAY\'S GRID'));
    await tester.pumpAndSettle();

    expect(find.text('BINGO GRID'), findsOneWidget);
    expect(find.text('Manuel Ugarte'), findsOneWidget);
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

    final finalCell = bingo.state.currentCell!.id;
    await tester.tap(find.byKey(ValueKey('bingo-cell-$finalCell')));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('GRID COMPLETE'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    expect(completed, isTrue);
  });
}
