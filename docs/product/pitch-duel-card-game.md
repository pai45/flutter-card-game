# Pitch Duel Card Game

Pitch Duel is StatOz's football card game. It turns the user's collection into a playable tactical match: build a squad, choose cards round by round, resolve football scenarios, and earn XP/coins from the result.

## Product Purpose

Pitch Duel gives users a playable game loop beyond sports predictions. It creates value for card collection, packs, progression, match history, and leaderboard ranking.

## Where It Lives

Pitch Duel is opened from the **GAMES** tab in the Predictions area.

The Games tab currently shows:

- **Pitch Duel** as the available tactical card game
- **Quiz Streak** as coming soon
- **Accuracy Challenge** as coming soon

When Pitch Duel opens, it becomes a full-screen game hub with internal navigation for home, deck, all cards, how to play, match, and related game views.

## First-Time Entry And Starter Pack

If the user has not claimed a starter pack, entering Pitch Duel triggers the starter pack flow before the game opens.

The starter pack gives enough cards to field a legal starter deck:

- 2 attackers
- 2 defenders
- 1 goalkeeper
- 6 action cards

The starter pack adds cards to the user's collection, grants XP from the opened cards, marks the starter pack as claimed, and equips the starter deck.

## Collection And Packs

Cards are collectible and have tiers:

- bronze
- silver
- gold
- platinum

The collection includes:

- player cards: attackers, defenders, and goalkeepers
- action cards: attack, defense, and special actions
- card backs

Packs can add player and action cards. Duplicate-aware behavior is represented through new-card counts and refund-style messaging in pack reveal summaries.

The daily drop gives one card on a 24-hour cooldown and feeds the same collection/progression loop.

## Deck Requirements

A playable deck requires:

- 2 owned attackers
- 2 owned defenders
- 1 owned goalkeeper
- 6 owned action cards

The active deck is used when starting a match. If a deck is incomplete or contains unowned cards, the match start is blocked with a deck-required state.

## Match Structure

A Pitch Duel match has four regular rounds.

The match flow is:

1. Match intro
2. Coin toss
3. Role choice or CPU role assignment
4. Scenario reveal
5. Player/action card selection
6. Shot Meter strike
7. Round resolution
8. Round result
9. Next round until full time
10. Penalties if tied
11. Final result, rewards, and match history

The user attacks twice and defends twice across the four rounds. The first-round role is determined by the toss result and role choice; later rounds alternate from that starting role.

## Round Play

Each round presents a football scenario, such as counter attack, set piece chance, box defense, or penalty box chaos.

The scenario gives attack and defense context. The user then chooses:

- a role-appropriate player card
- a role-appropriate action card

When attacking, the user chooses from attackers and attack/special actions. When defending, the user chooses from defenders and defense/special actions.

The opponent chooses from its generated deck. As the user's level increases, the opponent is tuned toward stronger cards and smarter action choices.

Once both cards are selected, the action button shows the user's current goal or stop chance and invites them to strike. This opens the Shot Meter.

## Shot Meter

The Shot Meter is the user's active timing moment inside each round. It replaces the user's hidden power roll with a skill-based strike.

Before the strike, the meter shows:

- **Goal Chance** when the user is attacking.
- **Stop Chance** when the user is defending.
- **Power range** from the selected card/action/scenario base up to base plus 20.
- **Risk warning** when the selected action can trigger a foul or red card.

The meter sweeps across a strike bar. The user taps to stop the marker. Timing quality creates a power surge from 0 to 20:

- **Perfect**: best timing, strongest surge.
- **Great**: strong timing, high surge.
- **Good**: usable timing, moderate surge.
- **Early/Late**: weak timing, low surge.

The surge is added to the user's side of the round:

- while attacking, the surge boosts attack power
- while defending, the surge boosts defense power

The CPU still receives its own hidden random swing, so the Shot Meter gives the user agency without removing uncertainty.

If the device has reduced motion enabled, the timed meter is skipped and the round falls back to the standard random swing.

## Round Outcomes

Round resolution compares attack strength and defense strength.

Attack and defense strength are built from:

- selected player rating
- selected action card power
- scenario attack or defense bonus
- the Shot Meter surge for the user's side
- the CPU's hidden swing

Possible outcomes are:

- goal
- saved
- blocked
- missed
- foul
- red card

Only goals change the regular match score. Risky actions can create fouls or red cards, so high-power choices can carry downside.

The displayed goal/stop chance is based on the same resolution model used by the match result. A stronger power advantage gives better scoring odds, but a goal is never fully guaranteed and a stop is never fully guaranteed.

Red-carded cards are removed from future availability for the affected side.

## Penalty Shootout

If the match is tied after four rounds, the match moves to penalties.

Penalty play uses direction choice:

- left
- center
- right

The shooter scores when the shot direction and keeper direction differ. The user and opponent alternate kicks. The shootout can end early if one side cannot catch up, otherwise it reaches three kicks each and then moves into sudden death pairs if still tied.

## Final Result And Rewards

The final result records whether the user achieved:

- Victory
- Defeat
- Draw

Rewards connect the match to the broader product economy:

- Victory gives more coins than a draw or defeat.
- Match XP can increase or decrease based on result, margin, shutout, or penalties.
- XP never drops below zero and does not de-level the user.
- Level-ups can trigger celebration states.

Match results are saved to history with the deck name, score, penalty score if any, round summary, and XP earned.

## Product Loop

1. Claim or buy packs.
2. Add cards to collection.
3. Build a legal deck.
4. Play Pitch Duel.
5. Earn coins and XP.
6. Level up and improve collection.
7. Use stronger cards against stronger opponents.

## Current Product Notes

- Pitch Duel is currently a single-player game against a CPU opponent.
- Opponent strength scales with player level.
- Match history keeps the latest saved entries rather than an unlimited archive.
- The game uses persistent local product state for decks, owned cards, wallet, progression, starter pack, daily drop, tutorials, and match history.
