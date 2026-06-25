# StatOz Product Documentation

StatOz is a sports prediction and game app built around four connected product loops:

- users predict real-world-style matches, submit answers, and claim rewards when results settle
- users collect cards, build squads, and play game modes such as Pitch Duel and Penalty Shootout for XP and coins
- users compare progress through leaderboard surfaces across match day, tournaments, coins, and games
- users set up a profile identity with avatar, banner, followed leagues, and favorite teams

This documentation is the product source of truth. It explains how the app works from the user experience outward, so future changes can update the product behavior before implementation details drift.

## App Map

On first launch, the app opens into Profile Setup until onboarding is complete. After setup, the app opens into the Predictions experience. From there, users move between:

- **Matches**: fixture cards grouped by league, with prediction quizzes for individual matches.
- **Pick**: a market-style picks surface where users choose outcomes and confirm an Oz Coin amount.
- **Games**: entry point for Pitch Duel, Penalty Shootout, and Football Quiz.
- **Leaderboard**: ranking surfaces for match day, tournaments, coins, and games.
- **Shop and Profile**: supporting areas for identity setup, avatar and banner display, followed leagues, favorite teams, wallet, collection, card backs, and cosmetic browsing.

The main navigation keeps Predictions, Pick, Leaderboard, Shop, and Profile as app-level destinations. Game modes open as full-screen hubs from the Games tab; Pitch Duel and Penalty Shootout share deck, collection, progression, wallet, and match-history systems.

## Feature Docs

- [Prediction Matches](prediction-matches.md)
- [Prediction Gamification](prediction-gamification.md) (designed, not yet built)
- [Picks](picks.md)
- [Pitch Duel Card Game](pitch-duel-card-game.md)
- [Penalty Shootout](penalty-shootout.md)
- [Pitch Duel Leveling System](pitch-duel-leveling.md)
- [Leaderboard](leaderboard.md)
- [Profile And Identity](profile-and-identity.md)
- [Friends Referral System](friends-referral-system.md)

## Product Loops

**Prediction loop**

1. User opens Matches.
2. User chooses an upcoming fixture.
3. User answers the animated match quiz before kickoff.
4. Already-submitted predictions reopen as an editable review list until kickoff.
5. Prediction locks once the match is live or no longer editable, with vote results available for review.
6. Finished matches can show correct answers, vote distribution, and settlement when result data is available.
7. Finished settleable matches dock a REVEAL RESULTS action: settlement plays as a staged reveal cinematic and correct answers credit XP into the shared progression track (predictions never pay coins).
8. (Designed, not yet built) The reveal will also feed an accuracy streak, achievements, and daily quests — see [Prediction Gamification](prediction-gamification.md).

**Pitch Duel card-game loop**

1. User enters Games and chooses Pitch Duel.
2. First-time users claim a starter pack (see [Starter Pack](pitch-duel-card-game.md#first-time-entry-and-starter-pack) for composition, tier odds, and roll logic).
3. User receives cards and a legal starter deck.
4. User plays a four-round card match.
5. Match result awards XP and coins.
6. User grows level, collection, and match history. See [Pitch Duel Leveling System](pitch-duel-leveling.md) for the XP curve, match rewards, pack XP, and opponent scaling.

**Penalty Shootout loop**

1. User enters Games and chooses Penalty Shootout.
2. User makes sure the shared active deck is ready; the shootout takers use 2 attackers, 2 defenders, and 1 goalkeeper.
3. User faces a level-scaled CPU opponent in a five-kicks-each shootout.
4. The shootout can end early, or move into sudden death pairs after five kicks each.
5. Result awards smaller XP/coin rewards than a full Pitch Duel match.
6. Match history, XP/coin ledgers, and the penalty shootout streak are updated. See [Penalty Shootout](penalty-shootout.md) for full rules.

**Competition loop**

1. User predicts, picks, or plays game modes.
2. Activity earns XP, wins, coins, and visible progress.
3. Leaderboards convert that progress into rank, movement, podiums, and the user's current position.

**Identity loop**

1. First-time user chooses an avatar and profile banner.
2. User optionally follows leagues and picks favorite teams for those leagues.
3. Profile displays the selected identity and a Following band for favorite team badges.
4. Shop supports the identity layer with cosmetic browsing, including player portrait avatar tiles.

## Current Product Notes

- Match fixtures, quizzes, vote results, and match leaderboard rows are currently mock-backed but written as product behavior so the surface can later connect to live data.
- The Pick tab currently behaves like a product prototype: users can choose a market and confirm an amount, but the confirmed pick is not yet a persisted portfolio position.
- Leaderboard entries are seeded to demonstrate ranking states, user highlighting, podiums, movement, and team boards.
- Pitch Duel gameplay, Penalty Shootout gameplay, deck ownership, progression, wallet, daily drop, streaks, and match history are persistent product experiences.
- Profile setup and identity preferences are persistent local product state: avatar, banner, followed leagues, favorite teams, and onboarding completion.
- The prediction gamification layer (streaks, settlement reveal, achievements, prediction XP, daily quests) is a designed-not-yet-built system documented in [Prediction Gamification](prediction-gamification.md).

## How To Maintain These Docs

When a feature changes, update the feature doc first, then update this main map if the change affects navigation, loops, or cross-feature behavior.

Each feature doc should answer:

- What problem this feature solves for the user
- Where the feature lives in the app
- What the primary user flow is
- What states the user can see
- What rewards or progression it affects
- What is current behavior versus planned or prototype behavior
