# Profile And Identity

Profile And Identity is the user's personal setup and display layer. It gives the app a durable player identity before the user enters the main experience, then carries that identity into Profile, leaderboard surfaces, and supporting shop cosmetics.

## Product Purpose

Profile setup makes the first launch feel intentional instead of anonymous. The user chooses how they appear, which competitions they follow, and which teams they want attached to their profile.

This also gives future prediction and leaderboard features a clean place to read identity preferences from without mixing them into match or game state.

## Where It Lives

Profile setup appears before the main app when onboarding is not complete.

After onboarding, identity is visible and editable through **Profile**. Shop remains the supporting destination for collection and cosmetic browsing, including avatar-style player portrait tiles.

## First-Run Profile Setup

The first-run gate is now **Profile Setup**, replacing the older single-step avatar entry.

The setup flow has four possible steps:

1. **Choose avatar**: pick one profile portrait from the seeded avatar options.
2. **Choose banner**: pick a profile banner visual.
3. **Follow leagues**: optionally choose competitions to follow.
4. **Pick teams**: for each followed league, optionally choose one favorite team.

Following leagues is optional. If the user skips league selection, setup can finish without favorite teams.

When the user finishes, the flow plays a profile-locked reveal. The reveal shows the chosen avatar and banner as an identity card, then deals in favorite team badges if any were selected.

## Profile Surface Behavior

Profile presents the user's selected identity as part of the profile hero:

- selected avatar
- selected banner
- level and progression context
- wallet and coin history
- collection and game shortcuts

When favorite teams are available, Profile also shows a compact **FOLLOWING** band. The band displays the favorite team badge for each followed league with the league code underneath.

The Following band renders nothing until the user has at least one followed league with a selected favorite team.

## Followable League Catalog

The followable league catalog is seeded locally. It currently includes:

- English Premier League
- La Liga
- Serie A
- Bundesliga
- Indian Premier League

EPL and IPL ids mirror the prediction repository ids so favorite teams can line up with fixture data later. Seeded leagues that do not currently have prediction fixtures are still valid identity preferences and should not create empty match sections.

## Persistence

Identity preferences are saved locally through `SecureGameStorage`:

- selected avatar id
- selected profile banner id
- followed league ids
- favorite team per followed league
- onboarding completion flag

These preferences are local product state. They are not currently synced to a backend account and do not imply cross-device identity.

## Relationship To Shop

Shop supports the identity and collection loop with cosmetic-style browsing.

The avatar shop tiles now use real player portrait assets from the player image catalog instead of generated placeholder avatar drawings. This is a visual refresh of the shop surface; it does not change the first-run avatar setup or introduce a backend purchase inventory.

## Implementation Reference

| Concern | Source |
|---------|--------|
| First-run setup result | `ProfileSetupResult` |
| Setup screen | `lib/screens/onboarding/profile_setup_screen.dart` |
| Local identity persistence | `lib/services/secure_storage_service.dart` |
| Followable leagues and teams | `lib/data/followable_leagues.dart` |
| Avatar options | `lib/models/avatar_option.dart` |
| Banner options | `lib/models/profile_banner_option.dart` |
| Shared banner rendering | `lib/widgets/profile_banner_visual.dart` |

## Current Product Notes

- Profile setup is built and replaces the old single-step avatar onboarding gate.
- Avatar, banner, followed leagues, favorite teams, and onboarding completion are persistent local preferences.
- Favorite leagues and teams are seeded locally and are not yet powered by a live personalization service.
- Profile can display selected favorite teams, but those preferences do not yet reorder fixtures, filter prediction markets, or drive leaderboard membership.
- Shop avatar tiles use player portrait art for browsing, while first-run profile avatars still use the seeded `avatarOptions` set.
