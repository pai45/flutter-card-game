import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/models/xp_ledger.dart';
import 'package:card_game/screens/profile/widgets/level_progress.dart';
import 'package:card_game/screens/profile/xp_history_screen.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameState> _load(GameBloc bloc) async {
  bloc.add(GameLoaded());
  return bloc.stream
      .firstWhere((state) => !state.loading)
      .timeout(const Duration(seconds: 3));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('XP graph helpers handle ranges, balances, and selection', () {
    final now = DateTime(2026, 6, 22, 12);
    final ledger = [
      XpLedgerEntry(
        id: 'new',
        timestamp: now,
        delta: -10,
        balanceAfter: 140,
        type: XpTransactionType.loss,
        source: XpTransactionSource.match,
        title: 'LOSS',
      ),
      XpLedgerEntry(
        id: 'week',
        timestamp: now.subtract(const Duration(days: 2)),
        delta: 50,
        balanceAfter: 150,
        type: XpTransactionType.earn,
        source: XpTransactionSource.prediction,
        title: 'PREDICTION',
      ),
      XpLedgerEntry(
        id: 'old',
        timestamp: now.subtract(const Duration(days: 20)),
        delta: 100,
        balanceAfter: 100,
        type: XpTransactionType.openingBalance,
        source: XpTransactionSource.openingBalance,
        title: 'PREVIOUS PROGRESS',
      ),
    ];

    expect(xpLedgerForRange(ledger, XpChartRange.all), hasLength(3));
    expect(xpLedgerForRange(ledger, XpChartRange.week), hasLength(2));
    expect(xpBalanceValues(140, ledger), [100, 150, 140]);
    expect(selectedXpChartIndex(null, 3), 2);
    expect(xpChartIndexForDx(dx: 50, width: 100, pointCount: 3), 1);
    expect(xpBalanceValues(25, const []), [25]);
  });

  testWidgets('tapping level chip opens XP dashboard', (tester) async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    await _load(bloc);
    bloc.add(PredictionXpAdded(25));
    await bloc.stream.firstWhere((state) => state.progression.totalXP == 25);

    await tester.pumpWidget(
      BlocProvider.value(
        value: bloc,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: LevelChip(
                  level: bloc.state.progression.playerLevel,
                  onTap: () => showXpHistory(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('LVL'));
    await tester.pumpAndSettle();

    expect(find.text('XP PROGRESS'), findsOneWidget);
    expect(find.byKey(const ValueKey('xp-to-next-level')), findsOneWidget);
    expect(find.text('XP HISTORY'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('PREDICTION REWARD'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('PREDICTION REWARD'), findsOneWidget);
    expect(find.text('EARNED'), findsAtLeastNWidgets(1));
    expect(find.text('LOST'), findsAtLeastNWidgets(1));
    expect(find.text('GAMES'), findsOneWidget);
    expect(find.text('PREDICTIONS'), findsOneWidget);
    expect(find.text('REWARDS'), findsOneWidget);

    await tester.tap(find.text('LOST').last);
    await tester.pumpAndSettle();
    expect(find.text('No XP changes match this filter.'), findsOneWidget);
  });
}
