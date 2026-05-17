# Pitch Duel Web Card Game - Complete Implementation Context

Last reviewed against the web source on 2026-05-17.

This document describes the card game implemented in the React web app under `src/app`. It focuses on the actual code behavior, including current rules, state transitions, UI constraints, storage, random systems, and implementation edge cases.

## 1. Product Summary

Pitch Duel is a single-player, turn-based football card duel. The player builds or selects a deck, enters a four-round match against a CPU opponent, alternates between attack and defense roles, and resolves each round through a combination of player card rating, action card power, scenario bonuses, and randomness.

The implemented web game includes:

- Home screen with play, deck builder, how-to-play, tutorial reset, and daily card reveal.
- Deck builder with saved deck slots in `localStorage`.
- Four-round match flow.
- Round-one coin toss.
- Scenario reveal before every round.
- Card selection for player and action card.
- CPU card selection.
- Probabilistic round resolution.
- Full-time result screen.
- Penalty shootout for tied matches.
- Final result archive with MVP display.
- Tutorial popups persisted in `localStorage`.

Primary implementation files:

- `src/app/App.tsx`
- `src/app/routes.tsx`
- `src/app/context/GameContext.tsx`
- `src/app/data/cards.ts`
- `src/app/components/screens/HomeScreen.tsx`
- `src/app/components/screens/DeckBuilderScreen.tsx`
- `src/app/components/screens/MatchScreen.tsx`
- `src/app/components/screens/match/*.tsx`
- `src/app/components/PlayerCardComponent.tsx`
- `src/app/components/ActionCardComponent.tsx`
- `src/app/tutorial.ts`

## 2. Tech Stack and Entry Points

The web app is a Vite React app.

Relevant dependencies from `package.json`:

- React and React DOM are peer dependencies at `18.3.1`.
- Vite is used for dev and build.
- React Router `7.13.0` handles navigation.
- Tailwind CSS `4.1.12` and custom CSS files handle styling.
- `motion` `12.23.24` is used for UI transitions and animations.
- Many Radix and UI dependencies exist, though the game screens mostly use custom components.

Scripts:

```json
{
  "dev": "vite",
  "build": "vite build"
}
```

Web entry:

- `src/main.tsx` creates the React root.
- `src/app/App.tsx` wraps the router in `GameProvider`.
- `src/app/routes.tsx` defines all web routes.

Routes:

| Route           | Component           | Notes                      |
| --------------- | ------------------- | -------------------------- |
| `/`             | `HomeScreen`        | Main screen.               |
| `/home`         | `HomeScreen`        | Alternate home route.      |
| `/deck-builder` | `DeckBuilderScreen` | Deck creation and editing. |
| `/match`        | `MatchScreen`       | Match phase orchestrator.  |
| `/how-to-play`  | `HowToPlayScreen`   | Static rules summary.      |
| `*`             | `HomeScreen`        | Fallback route.            |

There is no current web splash screen in the route table.

## 3. Core Data Model

All card catalog data lives in `src/app/data/cards.ts`.

### Player Cards

```ts
type CardTier = "silver" | "gold" | "purple";
type PlayerRole = "attacker" | "defender";

interface PlayerCard {
  id: string;
  name: string;
  role: PlayerRole;
  rating: number;
  trait: string;
  tier: CardTier;
  icon: GameIconName;
  image: string;
}
```

Player cards are split into attackers and defenders. The deck requires two of each.

Attackers:

| ID     | Name         | Rating | Tier   | Trait             |
| ------ | ------------ | -----: | ------ | ----------------- |
| `atk1` | Marcus Blaze |     92 | gold   | Clinical Finisher |
| `atk2` | Leo Viper    |     95 | purple | Dribble King      |
| `atk3` | Kai Thunder  |     88 | silver | Speed Demon       |
| `atk4` | Dante Fury   |     90 | gold   | Aerial Threat     |
| `atk5` | Riku Storm   |     86 | silver | Long Range        |
| `atk6` | Zane Phantom |     93 | purple | Ghost Run         |

Defenders:

| ID     | Name        | Rating | Tier   | Trait        |
| ------ | ----------- | -----: | ------ | ------------ |
| `def1` | Iron Wall   |     91 | gold   | Unbreakable  |
| `def2` | Shadow Lock |     89 | silver | Man Marker   |
| `def3` | Granite     |     94 | purple | Brick Wall   |
| `def4` | Hawk Eye    |     87 | gold   | Interceptor  |
| `def5` | Steel Trap  |     85 | silver | Slide Master |
| `def6` | Aegis       |     93 | purple | Last Stand   |

### Action Cards

```ts
type ActionCategory = "attack" | "defense" | "special";

interface ActionCard {
  id: string;
  title: string;
  category: ActionCategory;
  effect: string;
  power: number;
  risky: boolean;
  icon: GameIconName;
}
```

Action cards are deck cards used during round resolution. The player deck requires six action cards.

| ID      | Title             | Category | Power | Risky | Effect                   |
| ------- | ----------------- | -------- | ----: | ----- | ------------------------ |
| `act1`  | Through Ball      | attack   |    15 | false | +15 Attack Power         |
| `act2`  | Power Shot        | attack   |    20 | false | +20 Attack, -5 Accuracy  |
| `act3`  | Skill Move        | attack   |    12 | false | +12 Attack, Bypass Trait |
| `act4`  | Cut Inside        | attack   |    10 | false | +10 Attack, +5 Scenario  |
| `act5`  | Long Shot         | attack   |    25 | true  | +25 Attack, High Risk    |
| `act6`  | Quick Break       | attack   |    18 | false | +18 Counter Bonus        |
| `act7`  | Slide Tackle      | defense  |    15 | false | +15 Defense Power        |
| `act8`  | Press High        | defense  |    12 | false | +12 Defense, Disrupt     |
| `act9`  | Block Lane        | defense  |    10 | false | +10 Defense, +5 Position |
| `act10` | Tight Marking     | defense  |    14 | false | +14 Defense Power        |
| `act11` | Intercept         | defense  |    18 | false | +18 Defense, Read Play   |
| `act12` | Last-Ditch Tackle | defense  |    22 | true  | +22 Defense, Foul Risk   |
| `act13` | All In            | special  |    30 | true  | +30 Power, Red Card Risk |
| `act14` | Tactical Foul     | special  |     8 | true  | Stop Play, Yellow Risk   |
| `act15` | Mind Game         | special  |    10 | false | -10 Opponent Power       |
| `act16` | Fast Recovery     | special  |     8 | false | +8 All Stats             |

Important implementation detail: action card `effect` text is presentational only. The reducer uses only `power`, `category`, and `risky`. For example, `Mind Game` says `-10 Opponent Power`, but the implemented resolver treats it as `+10` to the side using it.

### Scenarios

```ts
interface Scenario {
  id: string;
  title: string;
  description: string;
  icon: GameIconName;
  attackBonus: number;
  defenseBonus: number;
}
```

| ID    | Title                | Attack Bonus | Defense Bonus | Description                         |
| ----- | -------------------- | -----------: | ------------: | ----------------------------------- |
| `sc1` | Counter Attack       |            8 |             3 | Quick transition, spaces open up    |
| `sc2` | 1v1 Final Third      |            5 |             5 | Face to face with the last defender |
| `sc3` | Set Piece Chance     |            6 |             6 | Free kick from a dangerous position |
| `sc4` | Last Minute Pressure |           10 |             2 | Everything on the line, final push  |
| `sc5` | Box Defense          |            2 |            10 | Packed defense, tight spaces        |
| `sc6` | Wide Break           |            7 |             4 | Overlapping run down the flank      |
| `sc7` | Penalty Box Chaos    |            8 |             8 | Scramble in the box, anything goes  |

Scenarios are selected randomly while avoiding repeats from previous rounds when possible. Since a match has four rounds and there are seven scenarios, normal matches should not repeat scenarios.

## 4. Global Game State

State is centralized in `src/app/context/GameContext.tsx` through `useReducer`.

### Match Phases

```ts
type MatchPhase =
  | "idle"
  | "toss"
  | "toss-result"
  | "scenario"
  | "play"
  | "resolving"
  | "round-result"
  | "match-end"
  | "penalty"
  | "final";
```

Implemented phase notes:

- `idle` is the pre-match state.
- `toss` and `toss-result` are used only before round 1.
- `scenario`, `play`, `round-result`, `match-end`, `penalty`, and `final` are active UI phases.
- `resolving` exists in the type and in `MatchScreen` routing, but no reducer action currently sets it.

### Round Outcomes

```ts
type RoundOutcome =
  | "goal"
  | "saved"
  | "blocked"
  | "missed"
  | "foul"
  | "red-card";
```

Only `goal` changes the regular match score.

### State Shape

The `GameState` includes:

- Player deck: `deckAttackers`, `deckDefenders`, `deckActions`.
- Match state: `phase`, `currentRound`, `playerScore`, `opponentScore`, `playerAttacking`.
- Toss state: `tossChoice`, `tossResult`, `playerWonToss`, `initialAttackingChoice`.
- Current selection: `selectedPlayerCard`, `selectedActionCard`.
- Tracking arrays: `usedPlayerCards`, `usedActionCards`, `redCardedCards`.
- Round log: `roundResults`.
- CPU deck: `opponentAttackers`, `opponentDefenders`, `opponentActions`.
- CPU tracking: `opponentUsedPlayerCards`, `opponentUsedActionCards`, `opponentRedCarded`.
- Penalties: `penaltyKicks`, `penaltyPlayerScore`, `penaltyOpponentScore`, `penaltyRound`, `penaltyPhaseOver`.

### Initial Deck

The starter web deck is:

- Attackers: `atk1`, `atk2`
- Defenders: `def1`, `def2`
- Actions: `act1`, `act2`, `act6`, `act7`, `act8`, `act15`

## 5. Home Screen

File: `src/app/components/screens/HomeScreen.tsx`

The home screen is the web app's first routed screen.

Features:

- Displays title through `HeaderBar`.
- Shows deck readiness based on exactly two attackers, exactly two defenders, and at least six action cards.
- `Play Match` dispatches `RESET` and navigates to `/match`.
- `Deck Builder` navigates to `/deck-builder`.
- `How to Play` navigates to `/how-to-play`.
- `Replay Walkthrough` clears tutorial progress and forces the home tutorial to reopen.
- `Daily Drop` opens a modal-style card reveal and randomly chooses one card from all attackers and defenders.

Daily card edge cases:

- The revealed daily card is not added to the player's deck or collection.
- There is no daily limit, persistence, cooldown, or duplicate tracking.
- The daily card feature is a visual/random reveal only.

## 6. Deck Builder

File: `src/app/components/screens/DeckBuilderScreen.tsx`

The deck builder lets the user create and save local deck slots.

### Deck Requirements

A deck is valid when:

- `selAttackers.length === 2`
- `selDefenders.length === 2`
- `selActions.length === 6`

The Play button is disabled until the deck is valid.

### Deck Slot Persistence

Deck slots are saved in browser `localStorage` under:

```txt
pd_deck_slots_v1
```

Stored decks save only card IDs:

```ts
interface StoredDeckSlot {
  id: string;
  name: string;
  attackers: string[];
  defenders: string[];
  actions: string[];
}
```

On load, stored IDs are hydrated against the current card catalogs. IDs that no longer exist are filtered out.

Edge cases:

- If localStorage read or JSON parsing fails, the builder falls back to the current default deck.
- If a stored deck hydrates with missing card IDs, it may become invalid.
- Deck names are generated as `All Star` for the initial fallback and `Squad N` for new decks.
- There is no UI to rename or delete a deck slot.
- Applying a different deck while editing dirty changes is blocked with a toast: `Save current deck first`.
- Creating a new deck while editing dirty changes is also blocked.
- Back navigation with dirty changes opens a discard confirmation.

### Editing Rules

When not editing:

- Deck cards can be viewed.
- The user can select saved deck pills.
- The main button says `Edit`.

When editing:

- Attackers tab allows selecting up to two attackers.
- Defenders tab allows selecting up to two defenders.
- Actions tab allows selecting up to six actions.
- If the relevant category is full, trying to add another card shows a toast.
- Clicking a selected card removes it.

### Action Balance Warning

The UI computes:

- Number of attack actions.
- Number of defense actions.
- Number of special actions.

If exactly six actions are selected and either attack actions or defense actions are zero, a warning is shown. This warning does not invalidate the deck. A deck with six special actions or no defense actions can still be saved and played if it has six total actions.

### Playing From Deck Builder

`playDeck`:

1. Requires the deck to be valid.
2. Calls `saveDeck()`.
3. Dispatches `RESET`.
4. Navigates to `/match`.

## 7. Match Screen Orchestration

File: `src/app/components/screens/MatchScreen.tsx`

`MatchScreen` owns match startup, phase rendering, and quit confirmation.

### Starting a Match

When match state is `idle`, or if the state looks invalid, `MatchScreen` starts a fresh match.

CPU deck generation:

- Randomly shuffles all attackers and picks two.
- Randomly shuffles all defenders and picks two.
- Randomly shuffles all actions and picks six.

The `START_MATCH` reducer action:

- Resets the match to initial state.
- Preserves the player's current deck.
- Stores the generated CPU deck.
- Sets `phase` to `toss`.
- Sets `currentRound` to `1`.

### Invalid Match State Recovery

`MatchScreen` computes `invalidMatchState` and restarts the match if:

- Phase is `play` but there is no `currentScenario`.
- Phase is `resolving` or `round-result` but there are no round results.
- Phase is `match-end` or `final` but there are no round results.

This prevents some broken direct-entry states from rendering empty result screens.

### Quit Flow

During an active match:

- Back invokes `requestQuit`.
- A confirm dialog appears: `Quit Match?`
- Confirming dispatches `RESET` and navigates home.

If not in progress:

- Back dispatches `RESET` and navigates home directly.

`matchInProgress` excludes `idle`, `final`, and `match-end`. Penalties are considered in progress.

## 8. Match Flow

A regular match is four rounds. Round 1 includes the toss. Rounds 2 through 4 skip the toss and alternate roles.

### Phase 1: Toss

File: `src/app/components/screens/match/TossPhase.tsx`

Flow:

1. Player selects `heads` or `tails`.
2. `FLIP COIN` dispatches `RESOLVE_TOSS`.
3. Reducer randomly chooses heads or tails.
4. `playerWonToss` is true if result matches the player's choice.
5. Phase becomes `toss-result`.

If the player wins:

- Player manually chooses Attack or Defend.
- `CHOOSE_ROLE` records the chosen role.

If the CPU wins:

- UI chooses `opponentChoice` randomly.
- After 1800 ms, the reducer dispatches `CHOOSE_ROLE` with the opposite role for the player.
- If CPU chooses attack, player defends.
- If CPU chooses defend, player attacks.

In round 1, `CHOOSE_ROLE` also sets `initialAttackingChoice`.

### Phase 2: Scenario

File: `src/app/components/screens/match/ScenarioPhase.tsx`

When the phase renders and `currentScenario` is null, it dispatches `SHOW_SCENARIO`.

`SHOW_SCENARIO`:

- Reads scenario IDs from `roundResults`.
- Selects an unused scenario if any exist.
- Falls back to any scenario if all are used.
- Sets `phase` to `scenario`.

The scenario screen displays:

- Scenario title.
- Description.
- Attack bonus.
- Defense bonus.
- Player role for this round.

Clicking `SELECT CARDS` dispatches `START_PLAY`.

### Phase 3: Play

File: `src/app/components/screens/match/PlayPhase.tsx`

The player selects:

- One player card from the role-appropriate roster.
- One action card from the role-appropriate action list.

When player is attacking:

- Player cards shown: `deckAttackers` excluding `redCardedCards`.
- Action cards shown: actions where category is `attack` or `special`.

When player is defending:

- Player cards shown: `deckDefenders` excluding `redCardedCards`.
- Action cards shown: actions where category is `defense` or `special`.

The estimated power preview is:

```txt
playerCard.rating + actionCard.power + relevantScenarioBonus
```

It does not include the hidden random roll.

The Execute button is disabled until both a player card and an action card are selected.

### Phase 4: Resolution

Reducer action: `PLAY_MOVE`

If no player card, action card, or scenario is selected, the action returns the current state unchanged.

CPU player selection:

```ts
const availableOppPlayers = state.playerAttacking
  ? state.opponentDefenders.filter(
      (c) => !state.opponentRedCarded.includes(c.id),
    )
  : state.opponentAttackers.filter(
      (c) => !state.opponentRedCarded.includes(c.id),
    );
```

CPU action selection:

```ts
const availableOppActions = state.opponentActions;
```

CPU selections are random.

Fallbacks:

- If there are no available CPU players after red-card filtering, the reducer falls back to the first CPU card of the required role.
- If there are no CPU actions, it falls back to `state.opponentActions[0]`, which would be undefined if the CPU action list were empty.

Since `START_MATCH` always creates six CPU actions from the global list, the empty CPU actions case should not happen in normal play.

Attacker and defender assignment:

| Player role      | Attacker card        | Defender card        | Attack action   | Defense action  |
| ---------------- | -------------------- | -------------------- | --------------- | --------------- |
| Player attacking | selected player card | CPU defender         | selected action | CPU action      |
| Player defending | CPU attacker         | selected player card | CPU action      | selected action |

The resolver produces one `RoundOutcome`.

If outcome is `goal`:

- Player score increments when `playerAttacking` is true.
- CPU score increments when `playerAttacking` is false.

The reducer then:

- Sets phase to `round-result`.
- Adds selected player card ID to `usedPlayerCards`.
- Adds selected action card ID to `usedActionCards`.
- Adds CPU player card ID to `opponentUsedPlayerCards`.
- Adds CPU action ID to `opponentUsedActionCards`.
- Appends a `RoundResult`.

### Phase 5: Round Result

File: `src/app/components/screens/match/RoundResultPhase.tsx`

Displays:

- Outcome icon and label.
- Score update when the outcome is a goal.
- Scenario title and player role.
- Attacker card and attack action.
- Defender card and defense action.
- Red card or foul notice if relevant.

Button behavior:

- Rounds 1 to 3: button label points to the next round and dispatches `NEXT_ROUND`.
- Round 4: button label says `FULL-TIME RESULT` and dispatches `NEXT_ROUND`.

### Phase 6: Next Round

Reducer action: `NEXT_ROUND`

If `currentRound >= 4`:

- Phase becomes `match-end`.

Otherwise:

- `currentRound` increments.
- Phase becomes `scenario`.
- `currentScenario` is cleared.
- Current selected cards are cleared.
- Player role alternates based on `initialAttackingChoice`.

Role alternation:

```txt
Round 1: initial role from toss
Round 2: opposite of round 1
Round 3: same as round 1
Round 4: opposite of round 1
```

This guarantees the player attacks twice and defends twice in a normal match.

### Phase 7: Full Time

File: `src/app/components/screens/match/MatchEndPhase.tsx`

After four rounds:

- If player score is greater than CPU score, the screen shows victory.
- If player score is lower than CPU score, the screen shows defeat.
- If scores are equal, the screen shows deadlock and offers penalty shootout.

Non-tied match:

- Button dispatches `FINISH_MATCH`.
- Phase becomes `final`.

Tied match:

- Button dispatches `GO_TO_PENALTY`.
- Phase becomes `penalty`.

### Phase 8: Penalty Shootout

File: `src/app/components/screens/match/PenaltyPhase.tsx`

Penalty state starts with:

- `penaltyRound = 0`
- `penaltyKicks = []`
- `penaltyPlayerScore = 0`
- `penaltyOpponentScore = 0`
- `penaltyPhaseOver = false`

Turn order:

- Player kicks when `penaltyRound % 2 === 0`.
- CPU kicks when `penaltyRound % 2 === 1`.

Player kicks require clicking `TAKE KICK`.

CPU kicks auto-fire after a 1100 ms delay.

Each penalty kick:

```ts
const chance = 0.65 + Math.random() * 0.1;
const scored = Math.random() < chance;
```

So each kick has a score probability from 65 percent to 75 percent.

If not scored:

- Result is randomly `saved` or `missed`.

Penalty ending logic:

- After at least six total kicks and an even number of kicks, if the scores differ, the shootout ends.
- The code also repeats the same even-kick check as a sudden-death comment.
- After at least six total kicks and an odd number of kicks, it checks whether either side is mathematically unable to catch up based on a three-kick baseline.

Implementation consequence:

- The shootout behaves as three kicks each before it can end on an even round.
- After three kicks each, ties continue in pairs until someone leads after equal attempts.

When `penaltyPhaseOver` is true:

- The result panel shows win or loss on penalties.
- Button dispatches `FINISH_MATCH`.

### Phase 9: Final Result

File: `src/app/components/screens/match/FinalResultPhase.tsx`

Final result determines player win if:

- Regular score is higher than CPU score, or
- Regular score is tied and penalty player score is higher than penalty CPU score.

The screen displays:

- Match won/lost label.
- Regular score.
- Penalty score chip if penalties happened.
- MVP if the player scored a regular-time goal.
- Round log.

MVP logic:

```ts
const mvp = state.roundResults.find(
  (r) => r.outcome === "goal" && r.playerAttacking,
)?.attackerCard;
```

This means:

- MVP is the first player-controlled regular-time goal scorer.
- Penalty goals do not count for MVP.
- CPU goal scorers do not count.
- If the player wins only on penalties without a regular-time player goal, no MVP is shown.

Final actions:

- `REMATCH`: dispatches `RESET`, navigates to `/match`.
- `HOME`: dispatches `RESET`, navigates to `/`.
- `DECK`: navigates to `/deck-builder` without resetting first.

## 9. Round Resolution Algorithm

Function: `resolveRound` in `src/app/context/GameContext.tsx`

### Power Calculation

```txt
attackPower =
  attackerCard.rating
  + attackAction.power
  + scenario.attackBonus
  + random number from 0 inclusive to 20 exclusive

defensePower =
  defenderCard.rating
  + defenseAction.power
  + scenario.defenseBonus
  + random number from 0 inclusive to 20 exclusive
```

The random component is `Math.random() * 20`.

### Risk Checks

Risk checks happen before power-difference outcome checks:

```ts
if (defenseAction.risky && Math.random() < 0.12) return "red-card";
if (attackAction.risky && Math.random() < 0.12) return "foul";
```

Important details:

- Defense risky check happens first.
- If both actions are risky and the defense roll triggers, the outcome is `red-card` and the attack risky check is skipped.
- If defense risky does not trigger, attack risky can still trigger `foul`.
- Each risky check has a 12 percent chance when evaluated.
- `red-card` and `foul` are terminal outcomes and do not score goals.

### Outcome Probability by Power Difference

```txt
diff = attackPower - defensePower
```

| Difference   | Outcome probabilities                                           |
| ------------ | --------------------------------------------------------------- |
| `diff > 15`  | 75 percent goal, 20 percent saved, 5 percent blocked            |
| `diff > 5`   | 60 percent goal, 30 percent saved, 10 percent missed            |
| `diff > -5`  | 45 percent goal, 35 percent saved, 20 percent missed or blocked |
| `diff > -15` | 65 percent saved, 25 percent blocked, 10 percent goal           |
| Otherwise    | 75 percent saved, 20 percent blocked, 5 percent goal            |

Boundary behavior:

- A diff of exactly `15` uses the `diff > 5` bucket.
- A diff of exactly `5` uses the `diff > -5` bucket.
- A diff of exactly `-5` uses the `diff > -15` bucket.
- A diff of exactly `-15` uses the final bucket.

Balanced bucket detail:

- In the `diff > -5` bucket, the final 20 percent outcome is split by another random call: roughly 10 percent missed and 10 percent blocked overall.

## 10. Card Usage and Availability

### Player Selection

The player UI filters player cards only by:

- Current role.
- Whether the card ID is in `redCardedCards`.

The player UI does not filter by `usedPlayerCards`.

Current implementation consequence:

- Player cards are reusable across rounds.
- `usedPlayerCards` is historical tracking only.
- Some tutorial text says used players are locked, but this is not enforced by the current `PlayPhase`.

### Action Selection

The player UI filters actions by:

- Attack role: `attack` or `special`.
- Defense role: `defense` or `special`.

The player UI does not filter by `usedActionCards`.

Current implementation consequence:

- Action cards are reusable across rounds.
- `usedActionCards` is historical tracking only.

### CPU Selection

CPU player cards are filtered by `opponentRedCarded`.

CPU action cards are not filtered by:

- Role category.
- Used status.
- Risk status.

Current implementation consequence:

- CPU may use an attack action while defending or a defense action while attacking.
- The action still contributes its `power` to the relevant side because resolver uses only the assigned attackAction or defenseAction object.

## 11. Red Cards and Fouls

### Intended Outcome Meaning

- `foul`: risky attack action disrupts the attack.
- `red-card`: risky defense action sends off a defender.

### Actual Reducer Behavior

In `PLAY_MOVE`, red-card handling is:

```ts
if (outcome === "red-card") {
  if (!state.playerAttacking) {
    oppNewRedCarded.push(oppPlayer.id);
  } else {
    oppNewRedCarded.push(oppPlayer.id);
  }
}
```

Both branches push the CPU selected player ID into `opponentRedCarded`.

Current implementation consequences:

- Player cards are never added to `redCardedCards` by the current reducer.
- When the player is attacking and the CPU defender's risky defense action causes a red card, the CPU defender is red-carded. This matches the expected concept.
- When the player is defending and the player's selected risky defense action causes a red card, the CPU attacker is added to `opponentRedCarded`. This does not match the displayed concept of the defender being purged.
- The UI can show `DEFENDER PURGED FROM ROSTER`, but the actual removed card may be the CPU attacker in the player-defending case.
- Because the player's red card array is never updated, the player should not naturally see their roster depleted from red cards in the current web implementation.

### Roster Depleted UI

`PlayPhase` has a `ROSTER DEPLETED` display when no player cards are available after filtering red-carded cards.

In current normal play, this is unlikely for the player because `redCardedCards` is never populated by the reducer. CPU depletion is possible, but the reducer fallback can still select the first CPU player even if all CPU players for that role are red-carded.

## 12. Scoring

### Regular Time

- Four rounds total.
- Each round can produce at most one goal.
- Goal gives one point to the attacking side.
- Saved, blocked, missed, foul, and red-card give no points.
- Maximum regular score is 4-0.

### Penalties

- Penalty scores are separate from regular scores.
- Penalty goals do not modify `playerScore` or `opponentScore`.
- Final win state uses penalty scores only when regular score is tied.

## 13. Tutorials

File: `src/app/tutorial.ts`

Tutorial seen state is stored in localStorage:

```txt
pd_tutorial_seen_v1
```

Tutorial keys:

- `home`
- `deck-builder`
- `toss`
- `scenario`
- `play`
- `round-result`
- `match-end`
- `penalty`
- `final`

Functions:

- `hasSeen(key)`
- `markSeen(key)`
- `resetTutorial()`
- `skipAll()`

Home screen can reset tutorials through `Replay Walkthrough`.

Edge cases:

- localStorage read/write errors are caught and ignored.
- If localStorage is unavailable, tutorials may show again because seen state cannot persist.

## 14. UI Components

### PlayerCardComponent

File: `src/app/components/PlayerCardComponent.tsx`

Displays:

- Player image or fallback visual.
- Rating badge.
- Role label.
- Trait.
- Name.
- Tier styling.
- Optional selected ring.
- Optional used badge.
- Optional red-card overlay.

Props include:

- `selected`
- `disabled`
- `redCarded`
- `used`
- `onClick`
- `size`

Implementation details:

- If image loading fails, it uses a CSS/fallback icon composition.
- `disabled`, `redCarded`, and `used` all make the card inactive inside the component.
- In current match selection, `used` is not passed for player roster cards, so used cards are not disabled in play.

### ActionCardComponent

File: `src/app/components/ActionCardComponent.tsx`

Displays:

- Category tag: ATK, DEF, or SPC.
- Power.
- Icon.
- Title.
- Effect.
- Risk warning marker.
- Optional used badge.

Props include:

- `selected`
- `disabled`
- `used`
- `onClick`
- `size`

Implementation details:

- `disabled` and `used` make the action inactive inside the component.
- In current match selection, `used` is not passed for action cards, so used actions are not disabled in play.

## 15. Persistence and Reset Behavior

### Persistent

Browser `localStorage` persists:

- Saved deck slots: `pd_deck_slots_v1`
- Tutorial seen state: `pd_tutorial_seen_v1`

### Not Persistent

The following reset on refresh or app remount:

- Current match.
- Scores.
- Round results.
- Penalty results.
- Daily revealed card.
- Active temporary deck draft state unless saved.

### RESET Action

`RESET` returns to `initialState` but preserves the current player deck:

```ts
return {
  ...initialState,
  deckAttackers: state.deckAttackers,
  deckDefenders: state.deckDefenders,
  deckActions: state.deckActions,
};
```

This is why rematch and home navigation can clear match state without losing the selected deck.

## 16. Complete Edge Case Inventory

### Routing and Match Startup

- Directly opening `/match` starts a fresh match if phase is `idle`.
- Directly reaching result-like phases without round results triggers a fresh match.
- Unknown routes fall back to Home.
- `/home` and `/` are equivalent.

### Toss

- `FLIP COIN` is disabled until heads or tails is selected.
- If the player loses the toss, CPU role choice is random and delayed by 1800 ms.
- Toss only occurs in round 1.
- `initialAttackingChoice` is set only when `currentRound === 1`.

### Scenario

- Scenarios avoid repeats by reading previous `roundResults`.
- A scenario is shown through an effect with an empty dependency array. Under the normal mount-per-phase flow it works because the component mounts with `currentScenario` null.
- If all scenarios were used, selection falls back to any scenario. Normal four-round matches do not exhaust all seven scenarios.

### Deck Validity

- Deck builder requires exactly two attackers, exactly two defenders, and exactly six actions.
- Home considers actions ready when action count is at least six, while deck builder enforces exactly six.
- Action category imbalance only warns; it does not block saving or play.
- A saved deck with missing catalog IDs can hydrate into an invalid deck.

### Card Reuse

- Used player and action arrays are tracked but not enforced in match selection.
- Current gameplay allows reusing the same player and action in multiple rounds.
- Tutorial copy in `PlayPhase` and `RoundResultPhase` mentions used cards being locked, but the current code does not enforce that behavior.

### CPU Action Legality

- CPU chooses from all opponent actions regardless of role.
- This can create mismatched CPU action categories.
- The resolver still treats the chosen action as attack or defense based on who is currently attacking.

### Red Cards

- Only `opponentRedCarded` is updated in current reducer logic.
- Player red cards are effectively not applied.
- A player risky defense red-card outcome removes the CPU attacker, not the player defender.
- If all CPU cards in a role are red-carded, fallback can still select the first CPU card of that role.

### Empty Selections

- `PLAY_MOVE` returns unchanged if selected player, selected action, or current scenario is missing.
- The UI prevents executing without a selected player and action.
- `MatchScreen` restarts if play phase has no scenario.

### Penalties

- Penalties only happen after a tied regular match.
- Player always kicks first.
- CPU kicks are automated after a delay.
- Kick chance is randomized per kick from 65 percent to 75 percent.
- Shootout cannot end before six total kicks under the implemented even-round check.
- A non-scoring kick is randomly saved or missed.
- Final result after penalties depends on penalty score only when regular score is tied.

### Final Result

- MVP only appears for the first player regular-time goal.
- Penalty-only wins may have no MVP.
- The Deck button from final result navigates to deck builder without first dispatching `RESET`; state remains final unless the user later starts or resets.

### Browser Storage

- localStorage failures are caught in deck and tutorial code.
- If localStorage is blocked, deck slots and tutorial progress do not persist.

## 17. Known Mismatches Between Text and Code

These are not necessarily bugs the user sees every time, but they are important for future development:

1. Tutorial says used players are locked for the match. The current match UI does not disable used player cards.
2. Tutorial says used cards appear side-by-side and cannot replay. The current reducer tracks used cards, but play selection does not enforce it.
3. `Mind Game` says it lowers opponent power, but the resolver treats it as positive power for the user of the card.
4. Red-card logic always pushes the CPU selected player into `opponentRedCarded`, even when the player defender used the risky defense action.
5. CPU action cards are not category-filtered by current role.
6. The phase type includes `resolving`, but no reducer path sets it.
7. Existing older documentation may mention a splash screen; the current web route table goes directly to Home.

## 18. Suggested Fixes If Continuing Development

The current implementation is playable, but these changes would align code with the intended rules:

1. Enforce used player cards if that is desired:
   - Filter `availablePlayerCards` by both `redCardedCards` and `usedPlayerCards`.
   - Decide what happens if a two-card roster runs out before the match ends.

2. Enforce or clarify action reuse:
   - Either filter by `usedActionCards`, or update tutorial text to say actions are reusable.

3. Fix red-card target logic:
   - When `outcome === 'red-card'`, add `defenderCard.id` to the red-card array belonging to the defender's owner.
   - If player is defending, add selected player card ID to `redCardedCards`.
   - If CPU is defending, add CPU defender ID to `opponentRedCarded`.

4. Filter CPU actions by role:
   - CPU defending should choose `defense` or `special`.
   - CPU attacking should choose `attack` or `special`.

5. Make card effect text match implemented mechanics:
   - Either implement special effects like `Mind Game`, or rewrite effects as simple power descriptions.

6. Remove or implement `resolving`:
   - Add a real resolving animation phase, or remove it from the phase type and renderer.

7. Decide penalty format language:
   - Current implementation is closer to three kicks each plus sudden death, not a full best-of-five penalty format.

## 19. Quick Mental Model for Future Agents

The game is not a server-backed multiplayer game. It is a local single-player React reducer game with random CPU choices and localStorage deck slots.

The authoritative game rules are in `GameContext.tsx`, not in the tutorial text. UI phase components mainly display and dispatch reducer actions. Card catalog values are static in `cards.ts`. Deck builder persistence is local-only. The largest logic risks are card-use enforcement, red-card ownership, and CPU action legality.
