# Friends Referral Frontend Experience

## Product Purpose

The referral experience gives players a clear way to invite friends with a
personal link and demonstrates the reward loop:

> Refer a friend and earn 500 Oz Coins.

This is a frontend-only prototype. It does not track link opens, installations,
accounts, or real referrals.

## Where It Lives

The main entry is an **Invite Friends** card at the top of Friends Arena, above
player search. It advertises the 500-coin reward and opens the full referral
screen.

Profile continues to route into Friends Arena through the existing `FRIENDS`
pill. A compact gold gift badge with `+500` makes the referral reward visible
from the profile hero.

## Referral Screen

The referral screen contains:

- an `EARN 500 OZ COINS` reward hero
- three steps: share link, friend joins, receive 500 coins
- the player's stable referral link
- copy-link and native platform share actions
- invited, pending, rewarded, and coins-earned counters
- locally stored recent referral rows
- a debug-only reward simulation

The referral link is generated from the existing persistent player tag:

`https://play.statoz.app/invite?ref={playerTag}`

The URL is shareable text only. It is not configured as a deep link.

## Sharing

The native share sheet is opened with `share_plus`. The message is:

```text
Join me on StatOz and start building your football legacy! Use my invite link:
{url}. When you join, I earn 500 Oz Coins.
```

The share action supplies an origin rectangle for iPad compatibility. If native
sharing throws, the link is copied to the clipboard and the player sees
`Sharing unavailable - link copied`.

Copying the link triggers haptics, changes the copy icon to a check briefly, and
shows `Referral link copied`.

## Local Referral State

On first use, the prototype seeds:

- `NovaQ` — invited
- `Vortex` — pending

These entries are persisted through `SecureGameStorage`, so reopening the
screen does not reseed or reset referral progress.

Referral statuses are:

- invited
- pending
- rewarded

## Demo Reward

Debug builds show `SIMULATE FRIEND JOINED`. Selecting it changes the first
pending referral to rewarded and disables further claims when no pending entry
remains.

The simulation:

1. persists the rewarded status
2. adds 500 Oz Coins through the shared `GameBloc`
3. writes a `FRIEND REFERRAL` wallet ledger entry
4. shows a local `+500 COINS` celebration

The action is guarded against repeated or rapid double taps, so Vortex can only
pay once.

Oz Coin History displays referral rewards with a gift icon, the referred
friend's name, and `+500`.

## Implementation Reference

| Concern | Source |
|---|---|
| Referral model | `lib/models/referral.dart` |
| Local referral state | `lib/blocs/referral/referral_cubit.dart` |
| Referral screen | `lib/screens/friends/referral_screen.dart` |
| Friends Arena entry | `lib/screens/friends/widgets/referral_invite_card.dart` |
| Local persistence | `lib/services/secure_storage_service.dart` |
| Coin reward ledger | `lib/models/oz_coin_ledger.dart` |

## Current Limitations

- Sharing a link does not create a referral automatically.
- Referral rows are demo data.
- The 500-coin reward is only triggered by the debug simulation.
- There is no API, authentication, database, install attribution, or real
  referral verification.
