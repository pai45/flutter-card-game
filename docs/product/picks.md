# Picks

Picks is the market-style prediction surface. It is distinct from Prediction Matches: Picks focuses on outcome markets, pricing, and Oz Coin confirmation, while Prediction Matches focuses on quiz questions attached to a fixture.

## Product Purpose

Picks gives users a fast way to express a position on sports outcomes. The surface feels closer to a prediction marketplace: users browse markets, choose an outcome, select an amount, and confirm the pick.

## Where It Lives

Picks lives in the Predictions area under the **PICK** tab.

It sits beside:

- **MATCHES** for fixture quizzes
- **GAMES** for Pitch Duel and future game modes

## Market Browsing

The Pick tab has two layers of filters:

- sport filters such as All, IPL, EPL, NBA, LaLiga, and Serie A
- market filters such as All Picks, Matches, Event, and Futures

These filters establish the intended product taxonomy, even while the current market list is a prototype.

## Market Types

The current product surface demonstrates several market patterns:

- **Match market**: outcome choices for a live or upcoming match.
- **Binary event market**: yes/no style question, such as qualification or player participation.
- **Futures market**: longer-range outcome with multiple possible winners or results.

Market cards communicate:

- league or sport context
- question being asked
- status or close timing
- market volume
- selectable outcomes
- price per outcome

## Pick Confirmation Flow

1. User taps an outcome price.
2. A confirmation sheet opens.
3. The sheet shows the question, selected pick, price, and available balance.
4. User adjusts the amount in increments based on the selected price.
5. User cancels or confirms.
6. Confirmation closes the sheet and shows a short success message.

The confirmation flow uses Oz Coins as the visible currency language.

## Oz Coin Amount Behavior

The amount selector:

- starts at the selected price
- decreases only while above one price step
- increases only while the next step fits within the displayed balance
- keeps the user inside a simple, constrained amount range

This makes the pick action feel deliberate without requiring a full wallet or portfolio screen yet.

## Relationship To Other Features

Picks shares the same top-level Predictions destination as Matches. It should feel like a sibling product surface:

- Matches: answer quiz questions on specific fixtures.
- Picks: choose priced outcomes from markets.
- Leaderboard: eventually reflects performance, wins, coins, or pick activity.
- Wallet/coins: provides the product currency used for pick amounts.

## Current Product Notes

- Pick markets are currently hardcoded examples.
- Confirming a pick currently shows a success message but does not persist a portfolio, deduct coins, or settle a market.
- The tab is useful as a product prototype for market browsing, pick selection, and amount confirmation.
