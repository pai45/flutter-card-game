import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/models/oz_coin_ledger.dart';
import 'package:card_game/models/xp_ledger.dart';
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

  test('TennisFinished pays XP and coins exactly once per match ID', () async {
    final storage = SecureGameStorage();
    final bloc = GameBloc(storage);
    addTearDown(bloc.close);
    final event = TennisFinished(
      matchId: 'tennis-settlement-1',
      playerName: 'Frances Tiafoe',
      opponentName: 'Jett Okafor',
      modeLabel: 'QUICK MATCH',
      difficultyLabel: 'PRO',
      resultLabel: 'Victory',
      grade: 'A',
      playerGames: 6,
      opponentGames: 3,
      xp: 28,
      coins: 30,
    );

    bloc.add(event);
    await bloc.stream.firstWhere(
      (state) => state.progression.totalXP == 28 && state.coins == 30,
    );
    bloc.add(event);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(bloc.state.progression.totalXP, 28);
    expect(bloc.state.coins, 30);
    expect(
      bloc.state.matchHistory.where((item) => item.id == event.matchId),
      hasLength(1),
    );
    expect(
      bloc.state.xpLedger.where(
        (entry) => entry.source == XpTransactionSource.tennis,
      ),
      hasLength(1),
    );
    expect(
      bloc.state.coinLedger.where(
        (entry) => entry.source == OzCoinTransactionSource.tennisReward,
      ),
      hasLength(1),
    );
    expect(
      await storage.loadTennisRewardSettlementIds(),
      contains(event.matchId),
    );
  });
}
