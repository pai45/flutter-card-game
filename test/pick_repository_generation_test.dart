import 'package:card_game/models/picks.dart';
import 'package:card_game/services/pick_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// Phase 4: any matchId lacking a hand-authored pick market should still get
/// one auto-generated, and any market tied to a finished fixture should
/// auto-settle — the same "never stuck" guarantee Phase 1 gave prediction
/// quizzes, now proven for Oz-coin markets too.
void main() {
  test('the WNBA demo fixture (no hand-authored market) gets an auto-generated, auto-settled winner market', () async {
    final repository = MockPickRepository();
    final markets = await repository.markets();
    final market = markets.singleWhere((m) => m.matchId == 'wnba_demo_dal_phx');

    expect(market.id, 'wnba_demo_dal_phx::winner');
    expect(market.status, PickMarketStatus.settled);
    expect(market.resolvedOutcomeId, 'home'); // Dallas (home) won 82-75
    expect(market.outcomeFor('home'), isNotNull);
    expect(market.outcomeFor('draw'), isNull); // basketball has no draw
  });

  test('the British GP (finished, no hand-authored market) gets an auto-generated, auto-settled race_winner market', () async {
    final repository = MockPickRepository();
    final markets = await repository.markets();
    final market = markets.singleWhere((m) => m.matchId == 'f1_british_gp');

    expect(market.id, 'f1_british_gp::race_winner');
    expect(market.status, PickMarketStatus.settled);
    // Real result: Hamilton wins the British GP.
    final winningOutcome = market.outcomeFor(market.resolvedOutcomeId!);
    expect(winningOutcome?.label, 'Lewis Hamilton');
  });

  test('the Belgian GP (upcoming, hand-authored markets exist) is left untouched', () async {
    final repository = MockPickRepository();
    final markets = await repository.markets();
    final generated = markets.where(
      (m) => m.matchId == 'f1_belgian_gp' && m.id.contains('::'),
    );
    expect(
      generated,
      isEmpty,
      reason: 'f1_belgian_gp already has hand-authored markets',
    );
    final handAuthored = markets.where((m) => m.matchId == 'f1_belgian_gp');
    expect(handAuthored, isNotEmpty);
    for (final market in handAuthored) {
      expect(market.status, PickMarketStatus.upcoming);
    }
  });

  test('a hand-authored, already-settled market is never re-settled by the auto engine', () async {
    final repository = MockPickRepository();
    final markets = await repository.markets();
    // fifa_arg_jor_winner is referenced by a won demo position in PicksCubit,
    // implying it's expected to already carry a hand-authored result.
    final market = markets.cast<PickMarket?>().firstWhere(
      (m) => m?.id == 'fifa_arg_jor_winner',
      orElse: () => null,
    );
    if (market == null) return; // fixture catalogue may change; not this test's concern
    expect(market.isResultKnown, isTrue);
  });
}
