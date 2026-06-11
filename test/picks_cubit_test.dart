import 'dart:convert';

import 'package:card_game/blocs/picks/picks_cubit.dart';
import 'package:card_game/models/picks.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:card_game/services/secure_storage_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('placing a pick requires percentage stake multiples', () async {
    final cubit = PicksCubit(MockPickRepository(), SecureGameStorage());
    await cubit.load();

    final invalid = await cubit.placePick(
      marketId: 'ipl_2026_winner',
      outcomeId: 'mi',
      stakeOz: 49,
      balanceOz: 500,
    );
    expect(invalid.success, isFalse);

    final valid = await cubit.placePick(
      marketId: 'ipl_2026_winner',
      outcomeId: 'mi',
      stakeOz: 48,
      balanceOz: 500,
    );
    expect(valid.success, isTrue);
    expect(valid.shares, 2);

    final position = cubit.state.positionForMarket('ipl_2026_winner');
    expect(position?.stakeOz, 48);
    expect(position?.maxPayoutOz, 200);
  });

  test('repeat buys on the same outcome aggregate shares', () async {
    final cubit = PicksCubit(MockPickRepository(), SecureGameStorage());
    await cubit.load();

    await cubit.placePick(
      marketId: 'ipl_2026_winner',
      outcomeId: 'mi',
      stakeOz: 48,
      balanceOz: 500,
    );
    await cubit.placePick(
      marketId: 'ipl_2026_winner',
      outcomeId: 'mi',
      stakeOz: 24,
      balanceOz: 500,
    );

    final position = cubit.state.positionForMarket('ipl_2026_winner');
    expect(position?.stakeOz, 72);
    expect(position?.shareCount, 3);
  });

  test('FIFA finals market is built from uploaded bet dataset', () async {
    final market = await MockPickRepository().marketById('fifa_arg_por_final');

    expect(market, isNotNull);
    expect(
      market!.question,
      'Will Argentina or Portugal reach FIFA 26 Finals?',
    );
    expect(market.volumeOz, 13755);
    expect(market.priceHistory, hasLength(101));
    expect(market.outcomeFor('yes')?.probabilityPercent, 59);
    expect(market.outcomeFor('no')?.probabilityPercent, 41);
  });

  test('settling a winning stored pick returns payout', () async {
    final stored = PickPosition(
      id: 'stored_win',
      marketId: 'epl_mu_over_1_5',
      marketQuestion: 'Man Utd over 1.5 goals?',
      marketType: PickMarketType.event,
      leagueLabel: 'EPL',
      outcomeId: 'yes',
      outcomeLabel: 'YES',
      stakeOz: 64,
      shareCount: 1,
      averageProbabilityPercent: 64,
      submittedAt: DateTime(2026, 6, 9),
      status: PickPositionStatus.pending,
    );
    FlutterSecureStorage.setMockInitialValues({
      'pd_pick_positions_v1': jsonEncode([stored.toJson()]),
    });
    final cubit = PicksCubit(MockPickRepository(), SecureGameStorage());
    await cubit.load();

    expect(
      cubit.state.positions['stored_win']?.status,
      PickPositionStatus.settleable,
    );

    final result = await cubit.settlePosition('stored_win');

    expect(result.settled, isTrue);
    expect(result.payoutOz, 100);
    expect(cubit.state.positions['stored_win']?.status, PickPositionStatus.won);
  });
}
