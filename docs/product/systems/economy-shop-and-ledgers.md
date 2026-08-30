# Oz Coins, Shop, Cosmetics, Rewards, Ledgers, and Settlement

> **Status:** BUILT
> **Last verified:** 2026-08-18
> **Scope:** Oz Coin wallet, shop inventory, cosmetics, reward application, XP/coin history, and idempotent settlement

## Product Purpose

The economy connects play, customization, entry costs, and rewards. Oz Coins
fund selected game entries, hints, lifelines, cards/packs, and cosmetics while
XP drives progression; both remain auditable through player-facing ledgers.

## Where It Lives

Wallet balances appear across the app. The Shop has avatar, frame, banner,
kit/livery, coin, pack, and card tabs. Tennis avatars that have bundled player
portraits appear in the AVATAR tab alongside the other sports, filtered by
country. Profile exposes XP and Oz Coin history.
Settlement helpers are used by games, predictions, picks, onboarding, referrals,
packs, achievements, and daily mysteries.

## Player Flow

1. Earn or receive a reward from an eligible source.
2. The settlement writes an idempotent wallet/progression transaction.
3. The balance, track progress, and history update.
4. Spend coins on an eligible entry or shop item.
5. See acquisition/reward feedback and the persisted ownership/balance state.

## Mechanics and Rules

XP and coins use typed transaction sources and separate ledgers. General
prediction settlement is XP-only, but the paid Scoreline prediction-contest
path is an explicit Oz Coin exception. Picks persist stakes/positions and can
settle payouts. The first-run welcome reward is 1,000 coins and is idempotent.

## Rewards and Progression

XP routes to a mode track and contributes to aggregate level. Coins do not set
level; they support entry, hints, lifelines, acquisition, and customization.
Settlement events must identify a reward so replaying a screen cannot double-pay.

## Gratification and Feedback

Count-ups, wallet pulses, reward settlement popups, shop acquisition overlays,
pack reveals, level-up beats, and coin/XP history give every meaningful balance
change an explainable payoff.

## Visible States

Affordable/unaffordable, acquiring, owned/equipped, reward-pending, settled,
duplicate/no-op, positive/negative ledger transactions, and empty history are
represented.

## Persistence

Wallet balance, progression tracks, owned/equipped cosmetics, shop acquisition,
and XP/coin ledgers persist through `SecureGameStorage`. Settlement identities
protect one-time rewards.

## Planned Scope and Current Limitations

- **BUILT:** Local wallet/progression, seven shop categories, cosmetic ownership,
  typed ledgers, onboarding bonus, and reusable settlement/reward presentation.
- **PLANNED:** Any real-money catalog, server-authoritative balance, refund, or
  fraud/abuse policy requires separate product and backend scope.

## Implementation References

- [`lib/models/oz_coin_ledger.dart`](../../../lib/models/oz_coin_ledger.dart)
- [`lib/models/xp_ledger.dart`](../../../lib/models/xp_ledger.dart)
- [`lib/models/shop.dart`](../../../lib/models/shop.dart)
- [`lib/services/settlement_writer.dart`](../../../lib/services/settlement_writer.dart)
- [`lib/screens/shop/shop_screen.dart`](../../../lib/screens/shop/shop_screen.dart)
- [`lib/widgets/reward_settlement_popup.dart`](../../../lib/widgets/reward_settlement_popup.dart)
- [`lib/screens/profile/oz_coin_history_screen.dart`](../../../lib/screens/profile/oz_coin_history_screen.dart)
- [`lib/screens/profile/xp_history_screen.dart`](../../../lib/screens/profile/xp_history_screen.dart)

## Tests

- [`test/progression_economy_test.dart`](../../../test/progression_economy_test.dart)
- [`test/services/settlement_writer_test.dart`](../../../test/services/settlement_writer_test.dart)
- [`test/onboarding_reward_storage_test.dart`](../../../test/onboarding_reward_storage_test.dart)
- [`test/oz_coin_tracker_widget_test.dart`](../../../test/oz_coin_tracker_widget_test.dart)
- [`test/xp_history_widget_test.dart`](../../../test/xp_history_widget_test.dart)
