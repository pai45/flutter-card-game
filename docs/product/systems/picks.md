# Picks

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Market browsing, price/outcome selection, Oz Coin positions, persistence, portfolio/history, and settlement

## Product Purpose

Picks is the market-style prediction loop. Players use Oz Coins to back a priced
outcome, hold a durable ticket, and later settle the result. It is distinct from
fixture prediction quizzes, which primarily reward knowledge with XP.

## Where It Lives

Picks is the **PICK** tab in the PREDICT / PICK / GAMES hub. Market cards also
appear in match, league, team, and prediction detail contexts and open a shared
market-detail surface. Pick history is reachable from the prediction area.

## Player Flow

1. Filter or open a match/event/futures market.
2. Review question, outcomes, price/probability, volume, time, chart, and context.
3. Select an outcome and choose an affordable Oz Coin stake.
4. Confirm; the stake is spent and a persisted `PickPosition` ticket is created.
5. Reopen the market/portfolio to track the pending position.
6. When the seeded market resolves or voids, settle the ticket.
7. Receive the eligible payout through the wallet and settlement reveal.

## Mechanics and Rules

Markets support match, binary event, and futures patterns with upcoming, live,
closed/unresolved, settled, and voided lifecycle states. A position stores the
market/outcome snapshot, stake, share count, maximum payout, status, and realized
result. Settlement can produce a win payout, loss, or void/refund and is guarded
against being applied twice.

## Rewards and Progression

Picks spends and can return Oz Coins; it does not award XP. Wallet transactions
use typed pick sources. Win/void payouts are applied only after a fresh cubit
settlement result and then shown by the pick settlement reveal.

## Gratification and Feedback

Price selection, affordability bounds, confirmation, ticket creation, live
position metrics, status color, realized-profit copy, wallet count-up, and the
settlement reveal make risk and outcome legible.

## Visible States

Filtered/no-market, open/live/closed/unresolved/settled/voided market,
unselected/selected outcome, affordable/unaffordable stake, no position,
pending/won/lost/voided position, settleable, settled, and history states are represented.

## Persistence

`PicksCubit` loads and saves positions through `SecureGameStorage`. Market data
is currently local/seeded, while created tickets and final statuses persist.
Wallet entries remain in the shared Oz Coin ledger.

## Planned Scope and Current Limitations

- **BUILT:** Persistent positions, wallet stake, market detail/chart context,
  portfolio/history, result/void settlement, payout, and reveal.
- **PLANNED:** Markets and resolutions are locally seeded. Server-authoritative
  pricing, trading/liquidity, remote settlement, and real-money wagering are not implemented.

## Implementation References

- [`lib/models/picks.dart`](../../../lib/models/picks.dart)
- [`lib/blocs/picks/picks_cubit.dart`](../../../lib/blocs/picks/picks_cubit.dart)
- [`lib/screens/predictions/market_detail_screen.dart`](../../../lib/screens/predictions/market_detail_screen.dart)
- [`lib/screens/predictions/prediction_picks_history_screen.dart`](../../../lib/screens/predictions/prediction_picks_history_screen.dart)
- [`lib/screens/predictions/widgets/pick_settlement_reveal.dart`](../../../lib/screens/predictions/widgets/pick_settlement_reveal.dart)

## Tests

- [`test/picks_model_test.dart`](../../../test/picks_model_test.dart)
- [`test/picks_cubit_test.dart`](../../../test/picks_cubit_test.dart)
- [`test/picks_widget_test.dart`](../../../test/picks_widget_test.dart)
- [`test/pick_repository_generation_test.dart`](../../../test/pick_repository_generation_test.dart)
