import 'package:card_game/blocs/game/game_bloc.dart';
import 'package:card_game/blocs/game/game_event.dart';
import 'package:card_game/models/oz_coin_ledger.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('referral reward adds 500 coins and one ledger entry', () async {
    final bloc = GameBloc(SecureGameStorage());
    addTearDown(bloc.close);
    bloc.add(GameLoaded());
    await bloc.stream.firstWhere((state) => !state.loading);

    bloc.add(
      CoinsAdded(
        500,
        source: OzCoinTransactionSource.referralReward,
        type: OzCoinTransactionType.earn,
        title: 'FRIEND REFERRAL',
        subtitle: 'Vortex',
      ),
    );
    final rewarded = await bloc.stream.firstWhere(
      (state) => state.coins == 500,
    );

    expect(rewarded.coinLedger, hasLength(1));
    expect(
      rewarded.coinLedger.single.source,
      OzCoinTransactionSource.referralReward,
    );
    expect(rewarded.coinLedger.single.title, 'FRIEND REFERRAL');
    expect(rewarded.coinLedger.single.subtitle, 'Vortex');
    expect(rewarded.coinLedger.single.delta, 500);
  });
}
