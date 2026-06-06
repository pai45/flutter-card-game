# Leaderboard

Leaderboard turns user activity into visible rank. It gives the app a competitive layer across predictions, tournaments, coins, and game performance.

## Product Purpose

The leaderboard answers three user questions:

- Where do I stand?
- Who is ahead of me?
- What kind of progress moved me up or down?

It supports both quick personal feedback through the user rank bar and broader competition through podiums and ranked lists.

## Where It Lives

Leaderboard is an app-level destination in the main navigation. It can also be reached from product surfaces that want to point users toward ranking or competition.

## Leaderboard Types

The screen has four top-level types:

- **Match Day**: short-term XP ranking around active match-day participation.
- **Tourney**: tournament ranking, with player/team views and time scopes.
- **Coins**: Oz Coin ranking.
- **Games**: game-mode ranking, expressed as wins.

Each type changes the scoring unit and accent treatment.

## Filters And Scopes

The leaderboard has sport filters such as IPL, UCL, NBA, and F1.

Depending on the selected type, the contextual filter changes:

- Match Day emphasizes match-day context and countdown-style urgency.
- Tournament can switch between players and teams.
- Tournament supports weekly, season, and all-time scopes.
- Games can switch between modes such as quiz, card duel, streaks, and accuracy.

This keeps one leaderboard screen flexible without turning every ranking into a separate page.

## Ranking Display

The ranking experience has three main parts:

- **Podium**: highlights the top three users.
- **Ranked list**: shows the broader leaderboard with ranks, avatars, score, movement, badges, and user highlighting.
- **User rank bar**: pins the current user's rank at the bottom so the user can always see their own position.

Rank movement is shown as climb, drop, held, or new. The current user is visually marked with a "YOU" tag.

## Team Tournament Board

Tournament mode can switch from individual players to teams.

Team ranking combines member scores and shows:

- team name
- rank
- combined score
- movement
- member-count badge
- whether the user's team is represented

This creates a path for future squad or club competition without changing the rest of the leaderboard product model.

## Empty States

Empty states are part of the product flow. They guide users toward the action that would make the leaderboard meaningful:

- no match-day board sends users toward tournament ranking
- unranked tournament state sends users toward playing
- locked coins leaderboard sends users toward picks
- no game scores sends users toward game play

## Relationship To Other Features

Leaderboard is downstream of the app's activity loops:

- Prediction Matches can feed correct predictions, XP, and reward-driven rank.
- Picks can feed coins and market performance once persistence and settlement are added.
- Pitch Duel feeds game wins, XP, coins, and match history.
- Profile can use leaderboard position as part of the user's identity and progress.

## Current Product Notes

- Leaderboard data is currently seeded to demonstrate rank, movement, podium, current-user highlighting, team boards, and empty-state pathways.
- The current user appears as `pai` in the seeded board.
- Match Day, Tournament, Coins, and Games are product surfaces ready for live ranking data later.
