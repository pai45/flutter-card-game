import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/blocs/prediction/prediction_cubit.dart';
import 'package:card_game/models/picks.dart';
import 'package:card_game/models/prediction.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });

  test('demo pick seeding tolerates missing markets', () async {
    final cubit = PicksCubit(_PartialDemoPickRepository(), SecureGameStorage());
    await cubit.load();
    expect(cubit.state.loading, isFalse);
  });

  test('unclaimed + revealed demo predictions seed', () {
    final preds = <String, UserPrediction>{};
    PredictionCubit.applyHistoryDemos(preds);
    final unclaimed = preds.values.firstWhere(
      (p) => p.matchId == 'fifa_demo_esp_ger',
    );
    final revealed = preds.values.firstWhere(
      (p) => p.matchId == 'fifa_arg_jor',
    );
    expect(unclaimed.status, isNot(PredictionStatus.settled));
    expect(revealed.status, PredictionStatus.settled);
    expect(revealed.rewardEarned, greaterThan(0));
  });
}

class _PartialDemoPickRepository implements PickRepository {
  final MockPickRepository _inner = MockPickRepository();

  @override
  Future<PickMarket?> marketById(String marketId) async {
    final markets = await this.markets();
    for (final market in markets) {
      if (market.id == marketId) {
        return market;
      }
    }
    return null;
  }

  @override
  Future<List<PickMarket>> markets() async {
    final markets = await _inner.markets();
    return markets.where((market) => market.id == 'fifa_arg_jor_winner').toList();
  }
}
