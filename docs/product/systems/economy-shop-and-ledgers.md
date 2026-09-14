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

### Shop search ? BUILT

The Shop sport-strip search icon opens a dedicated search route across all sports
and all seven categories. Results match player full/short names, available
team/country names and codes, item names, sport, role/position, and tier.
Search requires two characters, ignores case and repeated whitespace, and
matches every query word against the item's metadata. Tennis country codes
also match their full country names. Missing player affiliations are not inferred.

Results group by category and sport, with exact-name and prefix matches first
inside each group. Search covers the complete card catalogue, including cards
beyond the normal browsing tab's 48-card display limit. Shared coin tiers and
standard packs appear once. Standard packs retain their existing shared purchase
behavior across non-racing sports; racing packs remain separate.

Result tiles reuse Shop prices, ownership/equipped states, confirmations,
purchase events, insufficient-funds feedback, acquisition reveals, and pack
opening. Ownership updates without clearing the query. Clear resets the input;
Back restores the Shop's previous selection. Search has no persisted history,
remote catalogue, or fuzzy typo matching.

## Rewards and Progression

### Daily quest rewards — BUILT

The [Streaks](streaks.md) hub grants 10 Oz Coins for each of three daily quests
and a 20-coin Daily Sweep bonus, capped at 50 earned coins per local day.
One claim action collects all available quest rewards, including earlier days.
Existing streak milestone rewards and XP formulas remain unchanged. The Daily
Sweep also forges a streak shield; shields are a streak-only protection item,
not a currency, and never enter the coin or XP ledgers.

Quest rewards use `OzCoinTransactionSource.dailyQuestReward`, deterministic
per-day/per-quest ledger IDs, and a dedicated coin-history icon. Earned amounts
are snapshotted before claim. A pending-claim journal stores absolute wallet,
ledger and quest-claim targets; replay completes interrupted writes before any
later GameBloc wallet mutation. Claims and other GameBloc events share one
queue. A failed recovery stops the attempted action with retry feedback.
This is local crash recovery, not cross-device or server-authoritative settlement.

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

- Search verification: `test/shop_user_search_test.dart`.
