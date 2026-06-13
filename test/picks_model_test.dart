import 'package:card_game/models/picks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('percentage price controls shares, payout, and profit', () {
    expect(
      PickMath.isValidStake(
        stakeOz: 68,
        probabilityPercent: 68,
        balanceOz: 500,
      ),
      isTrue,
    );
    expect(PickMath.sharesForStake(stakeOz: 68, probabilityPercent: 68), 1);
    expect(PickMath.payoutForShares(1), 100);
    expect(PickMath.profitFor(stakeOz: 68, shares: 1), 32);
  });

  test('stake must be a multiple of the percentage price', () {
    expect(
      PickMath.isValidStake(
        stakeOz: 69,
        probabilityPercent: 68,
        balanceOz: 500,
      ),
      isFalse,
    );
    expect(PickMath.sharesForStake(stakeOz: 69, probabilityPercent: 68), 0);
  });

  test('pick position json round trips percent market fields', () {
    final position = PickPosition(
      id: 'p1',
      marketId: 'm1',
      marketQuestion: 'Who wins?',
      marketType: PickMarketType.match,
      leagueLabel: 'IPL',
      outcomeId: 'yes',
      outcomeLabel: 'YES',
      stakeOz: 82,
      shareCount: 2,
      averageProbabilityPercent: 41,
      submittedAt: DateTime(2026, 6, 10, 12),
      status: PickPositionStatus.live,
    );

    final parsed = PickPosition.fromJson(position.toJson());

    expect(parsed.marketType, PickMarketType.match);
    expect(parsed.averageProbabilityPercent, 41);
    expect(parsed.maxPayoutOz, 200);
    expect(parsed.profitIfCorrect, 118);
  });

  test('pick outcome json keeps percentage and color', () {
    const outcome = PickOutcome(
      id: 'mi',
      label: 'Mumbai',
      probabilityPercent: 24,
      color: Color(0xff2856a5),
    );

    final parsed = PickOutcome.fromJson(outcome.toJson());

    expect(parsed.probabilityPercent, 24);
    expect(parsed.color, const Color(0xff2856a5));
  });
}
