import 'dart:convert';

import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/blocs/game/game_state.dart';
import 'package:card_game/models/oz_coin_ledger.dart';
import 'package:card_game/models/progression.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<GameState> _load(GameBloc bloc) async {
  bloc.add(GameLoaded());
  return bloc.stream
      .firstWhere((state) => !state.loading)
      .timeout(const Duration(seconds: 3));
}

Future<GameState> _nextWhere(
  GameBloc bloc,
  bool Function(GameState state) test,
) => bloc.stream.firstWhere(test).timeout(const Duration(seconds: 3));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('first launch prepares a playable fallback deck', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);

    final state = await _load(bloc);

    expect(state.starterPackClaimed, isFalse);
    expect(state.pendingPackReveal, isNull);
    expect(state.deckReady, isTrue);
    expect(state.deckAttackers, hasLength(2));
    expect(state.deckDefenders, hasLength(2));
    expect(state.deckActions, hasLength(6));
    expect(
      state.ownedCardIds,
      containsAll([
        ...state.deckAttackers.map((card) => card.id),
        ...state.deckDefenders.map((card) => card.id),
      ]),
    );
    expect(
      state.ownedActionCardIds,
      containsAll(state.deckActions.map((card) => card.id)),
    );
  });

  test('daily drop cooldown is persisted after claiming', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    await _load(bloc);

    bloc.add(DailyDropClaimed());
    final claimed = await _nextWhere(
      bloc,
      (state) => state.dailyDropLastClaimedAt != null,
    );
    expect(dailyDropStatus(claimed.dailyDropLastClaimedAt).ready, isFalse);

    final reloadedBloc = GameBloc(SecureGameStorage());
    addTearDown(reloadedBloc.close);
    final reloaded = await _load(reloadedBloc);

    expect(reloaded.dailyDropLastClaimedAt, isNotNull);
    expect(dailyDropStatus(reloaded.dailyDropLastClaimedAt).ready, isFalse);
  });

  test('shop pack purchase deducts coins and reveals rolled cards', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    final loaded = await _load(bloc);

    bloc.add(CoinsAdded(150));
    await _nextWhere(bloc, (state) => state.coins == loaded.coins + 150);

    bloc.add(ShopPackPurchased('bronze'));
    final purchased = await _nextWhere(
      bloc,
      (state) => state.pendingPackReveal?.statusLabel == 'PURCHASED',
    );

    expect(purchased.coins, loaded.coins);
    expect(
      purchased.coinLedger.first.source,
      OzCoinTransactionSource.packPurchase,
    );
    expect(purchased.coinLedger.first.delta, -150);
    expect(purchased.pendingPackReveal?.items, hasLength(3));
    expect(
      purchased.progression.totalXP,
      greaterThan(loaded.progression.totalXP),
    );
  });

  test('coin ledger entry round trips through json', () {
    final entry = OzCoinLedgerEntry(
      id: 'coin-1',
      timestamp: DateTime(2026, 6, 14, 12, 30),
      delta: 250,
      balanceAfter: 1250,
      type: OzCoinTransactionType.topUp,
      source: OzCoinTransactionSource.shopTopUp,
      title: 'COIN TOP-UP',
      subtitle: 'Elite',
    );

    final restored = OzCoinLedgerEntry.fromJson(entry.toJson());

    expect(restored.id, entry.id);
    expect(restored.timestamp, entry.timestamp);
    expect(restored.delta, entry.delta);
    expect(restored.balanceAfter, entry.balanceAfter);
    expect(restored.type, entry.type);
    expect(restored.source, entry.source);
    expect(restored.title, entry.title);
    expect(restored.subtitle, entry.subtitle);
  });

  test('existing wallet balance seeds one opening ledger entry', () async {
    SharedPreferences.setMockInitialValues({
      'pitch_duel_wallet': jsonEncode({
        'coins': 777,
        'ownedCardIds': const [],
        'ownedActionCardIds': const [],
        'ownedCardBackIds': const ['default'],
        'equippedCardBackId': 'default',
      }),
    });
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);

    final loaded = await _load(bloc);

    expect(loaded.coins, 777);
    expect(loaded.coinLedger, hasLength(1));
    expect(loaded.coinLedger.single.type, OzCoinTransactionType.openingBalance);
    expect(loaded.coinLedger.single.balanceAfter, 777);
  });

  test('coin ledger persists through SecureGameStorage', () async {
    final storage = SecureGameStorage();
    final entry = OzCoinLedgerEntry(
      id: 'coin-storage',
      timestamp: DateTime(2026, 6, 14, 8),
      delta: -75,
      balanceAfter: 425,
      type: OzCoinTransactionType.spend,
      source: OzCoinTransactionSource.pickStake,
      title: 'PICK STAKE',
    );

    await storage.saveCoinLedger([entry]);
    final restored = await storage.loadCoinLedger();

    expect(restored, hasLength(1));
    expect(restored.single.id, entry.id);
    expect(restored.single.delta, -75);
    expect(restored.single.source, OzCoinTransactionSource.pickStake);
  });

  test('generic coin add and spend append ledger rows', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    await _load(bloc);

    bloc.add(
      CoinsAdded(
        120,
        source: OzCoinTransactionSource.shopTopUp,
        type: OzCoinTransactionType.topUp,
        title: 'COIN TOP-UP',
      ),
    );
    final toppedUp = await _nextWhere(bloc, (state) => state.coins == 120);

    bloc.add(
      CoinsSpent(
        40,
        source: OzCoinTransactionSource.pickStake,
        title: 'PICK STAKE',
      ),
    );
    final spent = await _nextWhere(bloc, (state) => state.coins == 80);

    expect(toppedUp.coinLedger.first.delta, 120);
    expect(toppedUp.coinLedger.first.type, OzCoinTransactionType.topUp);
    expect(spent.coinLedger.first.delta, -40);
    expect(spent.coinLedger.first.source, OzCoinTransactionSource.pickStake);
    expect(spent.coinLedger.first.balanceAfter, 80);
  });

  test('overspend leaves balance and ledger unchanged', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    await _load(bloc);
    bloc.add(CoinsAdded(20));
    final funded = await _nextWhere(bloc, (state) => state.coins == 20);

    bloc.add(CoinsSpent(999));
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(bloc.state.coins, funded.coins);
    expect(bloc.state.coinLedger, funded.coinLedger);
  });

  test('shootout reward records a game ledger entry', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    await _load(bloc);

    bloc.add(ShootoutFinished(playerGoals: 5, cpuGoals: 3));
    final rewarded = await _nextWhere(bloc, (state) => state.coins == 20);

    expect(
      rewarded.coinLedger.first.source,
      OzCoinTransactionSource.shootoutReward,
    );
    expect(rewarded.coinLedger.first.delta, 20);
  });
}
