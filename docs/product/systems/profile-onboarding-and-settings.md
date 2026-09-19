# Profile, Onboarding, Identity, and Settings

> **Status:** BUILT
> **Last verified:** 2026-09-19
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
and the current settings sheet. Profile's **ALL DECKS** card opens the
sport-tabbed **Deck Locker**; a sport tab whose starter pack is still unclaimed
routes its **PLAY \<SPORT\>** action to that sport's GAMES tab instead of
showing a dead-end message (see
[`systems/collections-decks-and-packs.md`](collections-decks-and-packs.md)).

## Player Flow

First entry plays WELCOME TO STATOZ. Both its timer and tap-to-skip open the
**PROTOTYPE** login/signup page before the following built profile steps.
The supplied six-second StatOz card showcase loops silently above the form,
with a poster during loading/failure, on unsupported platforms, or with reduced
motion. Playback pauses when the app backgrounds and disposes on leaving.

The page offers email and Google preview entry. LOGIN / SIGNUP activates for a
valid trimmed email; Google preview works without an email. Both continue into
avatar setup with press/haptic feedback and the existing setup entrance motion.
A visible preview note explains that no account is created. Email is transient
and never saved or transmitted. Legal links show themed unavailability dialogs;
they do not represent published policies or record acceptance.

1. Choose avatar and profile banner.
2. Pick one **home sport** (single-select board, `PICK YOUR HOME SPORT`),
   then that sport's clubs page. The home sport is the only sport open in the
   app until more are unlocked for 50 Oz each; see
   [Sport and Game Unlocks](sport-and-game-unlocks.md).
3. Optionally follow leagues/competitions and favorite teams.
4. Confirm identity in the profile-locked reveal.
5. Receive the one-time **1,000 Oz Coin** welcome bonus and animation.
6. Use Profile to inspect/edit identity and open progression/social/history/help.
7. Use Settings to open **PROFILE SELECT**. Choose **FIRST-TIME PLAYER** for
   its isolated, blank career and onboarding flow, or **RETURNING PLAYER** to
   resume the separately saved career.

## Mechanics and Rules

League following is optional; favorite teams are selected only for followed
competitions — one favorite per followed league, and changing the primary sport
clears both, so in practice every stored favorite belongs to the primary sport.

A football league can also be followed directly from its league hub. This path
persists the canonical competition identity immediately and deliberately leaves
the favourite club unset. Profile's existing Following band represents that
state with a league-only **NO CLUB** chip. Unfollowing from the hub removes an
existing favourite only after the shared confirmation dialog.

The favorite is not decoration. It orders and marks the Predictions match feed:
on any day a followed club plays, that fixture is pinned above the rest of the
day as **YOUR CLUB** and marked wherever its card appears. Editing clubs from
Profile takes effect immediately, without an app restart. Nothing is filtered
out — the rest of the day still follows underneath. See
[`systems/predictions.md`](predictions.md) for the feed behavior. The welcome reward has its
own persisted status and ledger source so reload/re-entry cannot pay it twice.

The onboarding sport selector and Profile's editable Following selector share
the canonical sport identity palette: Football cyan, Cricket white, Basketball
yellow, Tennis green, and Motorsport red. Inactive icons remain recognizable at
reduced intensity; the selected sport uses full color with the only selector
glow. Changing this presentation does not alter the persisted primary sport.

All onboarding choice cards share one calm, angular selection surface with the
standard top-left / bottom-right chamfer. Card content is centered, while only
the current selection receives the accent border, slight lift, and restrained
glow. On the clubs step, the title stands alone without a duplicate explanatory
subheading; the dock keeps the neutral step instruction, and every club name is
white so team identity stays in the crest rather than reducing label contrast.
Existing dealt-card entrances are retained, and each identity or club choice now
answers selection with haptic/audio feedback.

The current Profile settings sheet contains the logout/profile-select action.
It opens a two-route local switchboard:

- **FIRST-TIME PLAYER** is a separate blank save slot on first use. It begins
  at level 1, zero XP, no streak, no coins, no cards, no unlocks, and incomplete
  onboarding; once played, its card becomes **CONTINUE ROOKIE PROFILE** and
  restores that slot's saved career.
- **RETURNING PLAYER** restores that slot's own level, streak, wallet, cards,
  predictions, picks, game history, unlocks, and identity exactly as it was
  when the player switched away.

The returning card stays visibly unavailable until that slot has completed
onboarding. Choosing a slot snapshots the outgoing career, restores the chosen
slot, and rebuilds the app state before gameplay resumes; no state leaks across
the two careers. Tennis owns a separate, mode-specific accessibility/control/
audio settings surface documented on its game/design pages.

## Rewards and Progression

Onboarding grants 1,000 Oz Coins once. It does not grant XP. Profile displays
the aggregate level, mode mastery, wallet, achievements, collection, and history
from their authoritative shared systems.

## Gratification and Feedback

The profile-locked identity reveal, dealt favorite-team badges, welcome-coin
animation, personalized hero, level/mastery meters, cosmetic previews, and
achievement/history shortcuts make setup feel like entering a player career.
The welcome-coin animation owns the first 1,000-coin payoff; the simultaneously
earned Treasury achievement is recorded without launching a competing reveal.

## Visible States

Incomplete/complete onboarding, per-step selection, optional empty following,
profile reveal, reward pending/claiming/claimed, configured profile, empty
history/collection, and settings/logout states are represented.

## Persistence

Each profile slot snapshots the game-owned `SecureGameStorage` keys and
game-owned SharedPreferences entries (including the wallet). Avatar ID, banner
ID, primary sport, followed league IDs, favorite team map, onboarding state,
progression, streak, economy, game modes, and histories therefore persist per
slot. The selector is device-local, not authentication or cloud account
switching.

## Planned Scope and Current Limitations

- **BUILT:** Five-step-capable identity setup, optional following, profile hero/
  hubs, local preference persistence, one-time 1,000-coin bonus, and logout.
- **PROTOTYPE:** Screenshot-inspired email/Google account-entry screen after
  welcome. This is not authentication; no provider, session, or account is created.
- **PLANNED:** Cross-device account sync, live personalization, privacy/account
  controls, and broader global sound/accessibility settings require new scope.

## Implementation References

- [`lib/screens/onboarding/login_signup_screen.dart`](../../../lib/screens/onboarding/login_signup_screen.dart)
- [`lib/screens/onboarding/profile_setup_screen.dart`](../../../lib/screens/onboarding/profile_setup_screen.dart)
- [`lib/screens/onboarding/widgets/onboarding_coin_reward_animation.dart`](../../../lib/screens/onboarding/widgets/onboarding_coin_reward_animation.dart)
- [`lib/screens/profile/profile_screen.dart`](../../../lib/screens/profile/profile_screen.dart)
- [`lib/data/followable_leagues.dart`](../../../lib/data/followable_leagues.dart)
- [`lib/models/avatar_option.dart`](../../../lib/models/avatar_option.dart)
- [`lib/models/profile_banner_option.dart`](../../../lib/models/profile_banner_option.dart)
- [`lib/services/secure_storage_service.dart`](../../../lib/services/secure_storage_service.dart)
- [`lib/blocs/game/game_bloc.dart`](../../../lib/blocs/game/game_bloc.dart)

## Tests

- [`test/login_signup_screen_test.dart`](../../../test/login_signup_screen_test.dart)
- [`test/profile_setup_screen_test.dart`](../../../test/profile_setup_screen_test.dart)
- [`test/league_follow_test.dart`](../../../test/league_follow_test.dart)
- [`test/onboarding_reward_storage_test.dart`](../../../test/onboarding_reward_storage_test.dart)
- [`test/onboarding_coin_reward_animation_test.dart`](../../../test/onboarding_coin_reward_animation_test.dart)
- [`test/player_profile_selector_screen_test.dart`](../../../test/player_profile_selector_screen_test.dart)
- [`test/local_profile_storage_test.dart`](../../../test/local_profile_storage_test.dart)
