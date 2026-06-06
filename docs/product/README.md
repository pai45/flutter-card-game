# StatOz Product Documentation

StatOz is a sports prediction and game app built around three connected product loops:

- users predict real-world-style matches, submit answers, and claim rewards when results settle
- users collect cards, build squads, and play the Pitch Duel tactical card game for XP and coins
- users compare progress through leaderboard surfaces across match day, tournaments, coins, and games

This documentation is the product source of truth. It explains how the app works from the user experience outward, so future changes can update the product behavior before implementation details drift.

## App Map

The app opens into the Predictions experience. From there, users move between:

- **Matches**: fixture cards grouped by league, with prediction quizzes for individual matches.
- **Pick**: a market-style picks surface where users choose outcomes and confirm an Oz Coin amount.
- **Games**: entry point for Pitch Duel, plus placeholders for future game modes.
- **Leaderboard**: ranking surfaces for match day, tournaments, coins, and games.
- **Shop and Profile**: supporting areas for collection, wallet, card backs, and player identity.

The main navigation keeps Predictions, Pick, Leaderboard, Shop, and Profile as app-level destinations. Pitch Duel opens as a full-screen game hub from the Games tab, then handles its own internal destinations such as home, deck, all cards, how to play, match, and match history.

## Feature Docs

- [Prediction Matches](prediction-matches.md)
- [Picks](picks.md)
- [Pitch Duel Card Game](pitch-duel-card-game.md)
- [Leaderboard](leaderboard.md)

## Product Loops

**Prediction loop**

1. User opens Matches.
2. User chooses an upcoming fixture.
3. User answers the match quiz before kickoff.
4. Prediction locks once the match is live or no longer editable.
5. Finished matches can be settled when result data is available.
6. Correct answers return coins/rewards.

**Pitch Duel card-game loop**

1. User enters Games and chooses Pitch Duel.
2. First-time users claim a starter pack.
3. User receives cards and a legal starter deck.
4. User plays a four-round card match.
5. Match result awards XP and coins.
6. User grows level, collection, and match history.

**Competition loop**

1. User predicts, picks, or plays game modes.
2. Activity earns XP, wins, coins, and visible progress.
3. Leaderboards convert that progress into rank, movement, podiums, and the user's current position.

## Current Product Notes

- Match fixtures and quizzes are currently mock-backed but written as product behavior so the surface can later connect to live data.
- The Pick tab currently behaves like a product prototype: users can choose a market and confirm an amount, but the confirmed pick is not yet a persisted portfolio position.
- Leaderboard entries are seeded to demonstrate ranking states, user highlighting, podiums, movement, and team boards.
- Pitch Duel gameplay, deck ownership, progression, wallet, daily drop, and match history are persistent product experiences.

## How To Maintain These Docs

When a feature changes, update the feature doc first, then update this main map if the change affects navigation, loops, or cross-feature behavior.

Each feature doc should answer:

- What problem this feature solves for the user
- Where the feature lives in the app
- What the primary user flow is
- What states the user can see
- What rewards or progression it affects
- What is current behavior versus planned or prototype behavior
