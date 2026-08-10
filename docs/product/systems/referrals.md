# Referrals

> **Status:** PROTOTYPE
> **Last verified:** 2026-08-09
> **Scope:** Invite-code presentation, referral statuses, demo completion, reward settlement, and celebration

## Product Purpose

Referrals demonstrate a reward-bearing invite loop: share an identity/code,
track invite status, and turn a joined referral into a celebratory Oz Coin payout.

## Where It Lives

The referral screen is linked from Friends Arena and uses its own referral
cubit, invite card, reward animation, and shared wallet settlement.

## Player Flow

1. Open Referrals and review the invite card and referral rows.
2. Share/copy the presented code using the available device affordance.
3. In the demo, advance a pending referral to joined.
4. Receive the 500 Oz Coin reward through the shared wallet and celebration.

## Mechanics and Rules

The seeded fixture includes NovaQ as invited and Vortex as pending. Simulating a
pending referral joining makes the reward eligible once. The current experience
does not validate real installs, attribution, or remote accounts.

## Rewards and Progression

The prototype joined reward is 500 Oz Coins. It is written to the shared coin
economy and surfaced as a referral-specific celebration; it does not grant XP.

## Gratification and Feedback

Status transitions, gold reward emphasis, wallet movement, and the referral
reward celebration make the conversion feel like a game reward instead of an
administrative confirmation.

## Visible States

Invited, pending, joined/rewarded, copy/share feedback, loading, and reward
celebration states are represented.

## Persistence

The wallet transaction persists. Referral roster/attribution is demo-local and
is not a production referral ledger.

## Planned Scope and Current Limitations

- **PROTOTYPE:** Seeded referrals, status simulation, 500-coin settlement, and
  celebration.
- **PLANNED:** Secure codes, attribution, anti-abuse rules, backend persistence,
  eligibility windows, and production share/deep-link handling.

## Implementation References

- [`lib/models/referral.dart`](../../../lib/models/referral.dart)
- [`lib/blocs/referral/referral_cubit.dart`](../../../lib/blocs/referral/referral_cubit.dart)
- [`lib/screens/friends/referral_screen.dart`](../../../lib/screens/friends/referral_screen.dart)
- [`lib/widgets/referral_reward_celebration.dart`](../../../lib/widgets/referral_reward_celebration.dart)

## Tests

- [`test/referral_cubit_test.dart`](../../../test/referral_cubit_test.dart)
- [`test/referral_reward_test.dart`](../../../test/referral_reward_test.dart)
- [`test/referral_screen_test.dart`](../../../test/referral_screen_test.dart)
