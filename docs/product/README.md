# StatOz Product Documentation

StatOz is a sports prediction and game app built around four connected product loops:

- users predict real-world-style matches, submit answers, and claim rewards when results settle
- users collect cards, build squads, and play game modes such as Pitch Duel, Penalty Shootout, Final Over, Grand Prix Dash, Football Quiz, Football Bingo, Guess the Player, and Football Chess
- users compare progress through leaderboard surfaces across match day, tournaments, coins, and games
- users set up a profile identity with avatar, banner, followed leagues, and favorite teams

This documentation is the product source of truth. It explains how the app works from the user experience outward, so future changes can update the product behavior before implementation details drift.

## App Map

On first launch, the app opens into Profile Setup until onboarding is complete. After setup, the app opens into the Predictions experience. From there, users move between:

- **Matches**: fixture cards grouped by league, with prediction quizzes for individual matches.
- **Pick**: a market-style picks surface where users choose outcomes and confirm an Oz Coin amount.
- **Games**: entry point for Pitch Duel, Penalty Shootout, Final Over, Grand Prix Dash, Football Quiz, Football Bingo, Guess the Player, and 5v5 Football Chess.
- **Leaderboard**: ranking surfaces for match day, tournaments, coins, and games.
- **Shop and Profile**: supporting areas for identity setup, avatar and banner display, followed leagues, favorite teams, wallet, collection, card backs, and cosmetic browsing.

The main navigation keeps Predictions, Pick, Leaderboard, Shop, and Profile as app-level destinations. Game modes open as full-screen hubs from the Games tab; Pitch Duel and Penalty Shootout share deck, collection, progression, wallet, and match-history systems.

## Feature Docs

- [Prediction Matches](prediction-matches.md)
- [Prediction Gamification](prediction-gamification.md) (designed, not yet built)
- [Picks](picks.md)
- [Pitch Duel Card Game](pitch-duel-card-game.md)
- [Penalty Shootout](penalty-shootout.md)
- [Grand Prix Dash](grand-prix-dash.md)
- [Football Quiz](football-quiz.md)
- [Football Bingo](football-bingo.md)
- [Guess the Player](guess-the-player.md)
- [5v5 Football Chess](football-chess.md)
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

**Final Over loop**

1. User enters Games and chooses Final Over from the Cricket section.
2. First-time cricket players claim a cricket starter pack and equip a three-batsman deck.
3. User chooses a tier and starts a six-ball chase against a CPU target.
4. Each ball asks the user to time contact and manage overdrive.
5. Shot outcome updates score, wickets, and the chase state.
6. The completed over awards shared XP and updates Final Over stats.

**Grand Prix Dash loop**

1. User enters Games and chooses Grand Prix Dash from the F1 section.
2. User chooses a circuit and cosmetic livery, or keeps their last selections.
3. User starts from a randomized P8-P16 grid slot in a 20-car one-lap race.
4. User reacts to lights out, manages speed, steers through corners, uses slipstream, and avoids wall/contact losses.
5. Finish position and personal best status determine XP.
6. Local racing stats and circuit personal bests are updated. See [Grand Prix Dash](grand-prix-dash.md) for full rules.

**Football Quiz loop**

1. User enters Games and chooses Football Quiz.
2. User chooses a trivia category and an unlocked set.
3. Starting a set spends 25 Oz Coins.
4. User answers 10 multiple-choice questions and submits once every question has an answer.
5. The reveal overlay grades the set question by question.
6. Passing the set awards XP per correct answer and persists category/set progress. See [Football Quiz](football-quiz.md) for full rules.

**Football Bingo loop**

1. User enters Games and chooses Football Bingo.
2. The mode opens today's unlocked 3x3 grid and restores any saved progress for that day.
3. User places each active player into the matching row/column club-intersection cell.
4. Correct placements fill the grid; wrong placements spend lifelines.
5. If lifelines run out, the user can spend 25 Oz Coins to buy one lifeline and continue.
6. Completing all 9 cells saves the daily grid as complete. See [Football Bingo](football-bingo.md) for full rules.

**Guess the Player loop**

1. User enters Games and chooses Guess the Player.
2. The mode opens today's deterministic career-timeline mystery.
3. User studies the club timeline, searches the player pool, and submits guesses.
4. Wrong guesses spend hearts; a correct guess or zero hearts ends the daily run.
5. The result is saved into daily logs for review.
6. Guess the Player currently shows a win XP value in the result overlay, but does not yet credit the shared XP ledger. See [Guess the Player](guess-the-player.md) for full rules.

**Football Chess loop**

1. User enters Games and chooses 5v5 Football Chess.
2. User makes sure the shared active deck has 2 attackers, 2 defenders, and 1 goalkeeper.
3. User chooses a starting formation.
4. Matchmaking introduces a level-scaled CPU opponent and shows both squads.
5. User calls the coin toss, then alternates one-action board turns with the CPU.
6. Goals reset the board and give kickoff to the conceding side.
7. Full time awards XP, updates the local Football Chess record, and shows the result screen. See [5v5 Football Chess](football-chess.md) for full rules.

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
- Football Quiz persists category/set progress, spends coins on entry, and credits shared XP only for passed sets.
- Football Bingo persists a daily archive and spends coins only for optional lifeline purchases; completion currently does not credit XP or coins.
- Guess the Player persists daily results and logs; its result overlay shows a win XP value, but shared XP crediting is not yet wired.
- Final Over persists its own chase record and credits shared XP, but it does not pay coins.
- Grand Prix Dash currently persists its own race record, circuit personal bests, and shared XP, but it does not pay coins and abandons in-progress races on exit.
- Football Chess currently persists its own win/loss/draw/streak record and shared XP ledger entries, but it does not yet write match-history or coin-ledger entries.
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
