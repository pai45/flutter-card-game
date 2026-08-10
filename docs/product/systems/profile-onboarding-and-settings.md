# Profile, Onboarding, Identity, and Settings

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** First-run identity, welcome reward, Profile hub, followed competitions/teams, cosmetics, and settings

## Product Purpose

Identity makes the player feel present before the first match and gives every
later level, collection, rank, and reward a home. Onboarding collects only the
preferences needed to personalize that identity and pays completion back with
a welcome moment.

## Where It Lives

Profile Setup gates first entry until onboarding is complete. Profile is a main
destination containing the identity hero, level/wallet, following, statistics,
achievements, histories, collections/decks, social/help shortcuts, cosmetics,
and the current settings sheet.

## Player Flow

1. Choose avatar and profile banner.
2. Select a primary sport/module.
3. Optionally follow leagues/competitions and favorite teams.
4. Confirm identity in the profile-locked reveal.
5. Receive the one-time **1,000 Oz Coin** welcome bonus and animation.
6. Use Profile to inspect/edit identity and open progression/social/history/help.
7. Use Settings to log out/reset the onboarding entry state when intended.

## Mechanics and Rules

League following is optional; favorite teams are selected only for followed
competitions. Seeded identifiers align with fixture/team data where available
but do not automatically filter or reorder content. The welcome reward has its
own persisted status and ledger source so reload/re-entry cannot pay it twice.

The current Profile settings sheet contains the logout action. Tennis owns a
separate, mode-specific accessibility/control/audio settings surface documented
on its game/design pages.

## Rewards and Progression

Onboarding grants 1,000 Oz Coins once. It does not grant XP. Profile displays
the aggregate level, mode mastery, wallet, achievements, collection, and history
from their authoritative shared systems.

## Gratification and Feedback

The profile-locked identity reveal, dealt favorite-team badges, welcome-coin
animation, personalized hero, level/mastery meters, cosmetic previews, and
achievement/history shortcuts make setup feel like entering a player career.

## Visible States

Incomplete/complete onboarding, per-step selection, optional empty following,
profile reveal, reward pending/claiming/claimed, configured profile, empty
history/collection, and settings/logout states are represented.

## Persistence

Avatar ID, banner ID, primary sport, followed league IDs, favorite team map,
onboarding-complete flag, and onboarding-reward status persist through
`SecureGameStorage`. Identity is local and is not a remote account profile.

## Planned Scope and Current Limitations

- **BUILT:** Five-step-capable identity setup, optional following, profile hero/
  hubs, local preference persistence, one-time 1,000-coin bonus, and logout.
- **PLANNED:** Cross-device account sync, live personalization, privacy/account
  controls, and broader global sound/accessibility settings require new scope.

## Implementation References

- [`lib/screens/onboarding/profile_setup_screen.dart`](../../../lib/screens/onboarding/profile_setup_screen.dart)
- [`lib/screens/onboarding/widgets/onboarding_coin_reward_animation.dart`](../../../lib/screens/onboarding/widgets/onboarding_coin_reward_animation.dart)
- [`lib/screens/profile/profile_screen.dart`](../../../lib/screens/profile/profile_screen.dart)
- [`lib/data/followable_leagues.dart`](../../../lib/data/followable_leagues.dart)
- [`lib/models/avatar_option.dart`](../../../lib/models/avatar_option.dart)
- [`lib/models/profile_banner_option.dart`](../../../lib/models/profile_banner_option.dart)
- [`lib/services/secure_storage_service.dart`](../../../lib/services/secure_storage_service.dart)
- [`lib/blocs/game/game_bloc.dart`](../../../lib/blocs/game/game_bloc.dart)

## Tests

- [`test/profile_setup_screen_test.dart`](../../../test/profile_setup_screen_test.dart)
- [`test/onboarding_reward_storage_test.dart`](../../../test/onboarding_reward_storage_test.dart)
- [`test/onboarding_coin_reward_animation_test.dart`](../../../test/onboarding_coin_reward_animation_test.dart)
