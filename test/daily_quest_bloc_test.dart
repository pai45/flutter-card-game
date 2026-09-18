import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/models/daily_quest.dart';
import 'package:card_game/models/oz_coin_ledger.dart';
import 'package:card_game/models/streak.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FailingQuestStorage extends SecureGameStorage {
  String? failAt;
  void check(String step) {
    if (failAt == step) throw StateError('Interrupted $step');
  }

  @override
  Future<void> saveQuestClaimJournal(Map<String, dynamic> journal) async {
    check('journal');
    await super.saveQuestClaimJournal(journal);
  }

  @override
  Future<void> saveWallet(WalletSnapshot wallet) async {
    check('wallet');
    await super.saveWallet(wallet);
  }

  @override
  Future<void> saveCoinLedger(List<OzCoinLedgerEntry> ledger) async {
    check('ledger');
    await super.saveCoinLedger(ledger);
  }

  @override
  Future<void> saveDailyQuests(DailyQuestSnapshot quests) async {
    check('quests');
    await super.saveDailyQuests(quests);
  }

  @override
  Future<void> clearQuestClaimJournal() async {
    check('clear');
    await super.clearQuestClaimJournal();
  }
}

Future<GameBloc> loaded(SecureGameStorage storage) async {
  final bloc = GameBloc(storage)..add(GameLoaded());
  await bloc.stream.firstWhere((s) => !s.loading);
  return bloc;
}

Future<void> completeQuests(GameBloc bloc) async {
  for (var i = 0; i < 3; i++) {
    bloc.add(
      DailyQuestActivityRecorded(
        DailyQuestActivity.pitchDuel,
        sourceId: 'session-$i',
      ),
    );
  }
  await bloc.stream.firstWhere((s) => s.dailyQuests.claimableCoins == 50);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'new installation starts empty; claims and wallet events serialize and persist',
    () async {
      final storage = SecureGameStorage();
      final bloc = await loaded(storage);
      expect(bloc.state.dailyQuests.today.games, 0);
      expect(bloc.state.dailyQuests.claimableCoins, 0);
      await completeQuests(bloc);
      bloc.add(DailyQuestRewardsClaimed());
      bloc.add(DailyQuestRewardsClaimed());
      bloc.add(CoinsAdded(7));
      bloc.add(CoinsSpent(2));
      await bloc.stream.firstWhere((s) => s.coins == 55);
      await bloc.close();
      expect((await storage.loadWallet()).coins, 55);
      expect(
        (await storage.loadCoinLedger()).where(
          (e) => e.source == OzCoinTransactionSource.dailyQuestReward,
        ),
        hasLength(4),
      );
      final restored = await loaded(storage);
      expect(restored.state.dailyQuests.claimableCoins, 0);
      restored.add(MatchReset());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(restored.state.dailyQuests.today.completedCount, 3);
      await restored.close();
    },
  );

  for (final step in ['journal', 'wallet', 'ledger', 'quests', 'clear']) {
    test(
      'claim recovers after interruption at $step without loss or duplicate payout',
      () async {
        final storage = FailingQuestStorage();
        final bloc = await loaded(storage);
        await completeQuests(bloc);
        storage.failAt = step;
        bloc.add(DailyQuestRewardsClaimed());
        await bloc.stream.firstWhere((s) => s.questError != null);
        await bloc.close();
        storage.failAt = null;
        final restored = await loaded(storage);
        restored.add(DailyQuestRewardsClaimed());
        restored.add(CoinsAdded(1));
        await restored.stream.firstWhere((s) => s.coins == 51);
        await restored.close();
        expect((await storage.loadWallet()).coins, 51);
        final entries = (await storage.loadCoinLedger())
            .where((e) => e.source == OzCoinTransactionSource.dailyQuestReward)
            .toList();
        expect(entries, hasLength(4));
        expect(entries.map((e) => e.id).toSet(), hasLength(4));
        expect((await storage.loadDailyQuests()).claimableCoins, 0);
        expect(await storage.loadQuestClaimJournal(), isNull);
      },
    );
  }

  test('clearing the daily sweep forges exactly one streak shield', () async {
    final storage = SecureGameStorage();
    final bloc = await loaded(storage);
    expect(bloc.state.streak.shields, 0);

    await completeQuests(bloc);
    expect(bloc.state.streak.shields, 1);
    expect(
      bloc.state.streak.celebrationQueue.last.type,
      StreakCelebrationType.shieldEarned,
    );

    bloc.add(
      DailyQuestActivityRecorded(
        DailyQuestActivity.penaltyShootout,
        sourceId: 'after-sweep',
      ),
    );
    bloc.add(CoinsAdded(1));
    await bloc.stream.firstWhere((s) => s.coins == 1);
    expect(bloc.state.streak.shields, 1);
    await bloc.close();
    expect((await storage.loadStreak())?.shields, 1);
  });

  test('a pending claim blocks a spend until recovery succeeds', () async {
    final storage = FailingQuestStorage();
    final bloc = await loaded(storage);
    await completeQuests(bloc);
    storage.failAt = 'ledger';
    bloc.add(DailyQuestRewardsClaimed());
    await bloc.stream.firstWhere((s) => s.questError != null);
    bloc.add(CoinsAdded(7));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.coins, 0);
    storage.failAt = null;
    bloc.add(CoinsAdded(7));
    await bloc.stream.firstWhere((s) => s.coins == 57);
    await bloc.close();
    expect((await storage.loadWallet()).coins, 57);
  });
}
