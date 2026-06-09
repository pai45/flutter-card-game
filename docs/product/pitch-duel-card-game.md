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

The starter pack adds cards to the user's collection, grants XP from the opened cards, marks the starter pack as claimed, and equips the starter deck.

### Pack Composition

Each starter pack roll gives **11 cards** — enough to field a legal starter deck:

| Slot | Count | Pool |
|------|-------|------|
| Strikers (attackers) | 2 | Full attacker roster |
| Defenders | 2 | Full defender roster |
| Goalkeeper | 1 | Full goalkeeper roster |
| Action cards | 6 | Attack + defense action pools |

Action cards are split as evenly as possible between attack and defense. When the count is odd (6 cards → 3 + 3, or 5 → 3 + 2), the heavier side is chosen at random.

**No duplicate cards** appear inside a single starter pack. Once a card is drawn for one slot, it cannot be drawn again in another slot.

### Rarity Tiers

Starter-pack rolls use the same four tiers as the rest of the collection:

- **bronze**
- **silver**
- **gold**
- **platinum**

Each card slot is rolled independently. The roller does **not** read the card's authored `tier` badge directly. Instead, it buckets cards by stats, rolls a target tier, then picks a matching card from the correct position pool.

#### Player cards — rating bands

| Tier | Player rating (OVR) |
|------|---------------------|
| Platinum | 90+ |
| Gold | 86–89 |
| Silver | 80–85 |
| Bronze | Below 80 |

#### Action cards — power bands

| Tier | Action power |
|------|--------------|
| Platinum | 22+ |
| Gold | 16–21 |
| Silver | 10–15 |
| Bronze | Below 10 |

### Drop Weights (Per Card Slot)

Each individual card draw uses these relative weights:

| Tier | Weight | Stated odds (UI) |
|------|--------|------------------|
| Bronze | 55 | 55% |
| Silver | 35 | 35% |
| Gold | 4 | 4% |
| Platinum | 1 | 1% |

The weights sum to **95**, so the roller normalizes them to 100% when picking:

| Tier | Effective roll chance |
|------|-----------------------|
| Bronze | ~57.9% |
| Silver | ~36.8% |
| Gold | ~4.2% |
| Platinum | ~1.1% |

Because every slot is rolled separately, a full 11-card pack will usually contain a mix of tiers — not exactly one card per odds row.

### Roll Logic (Per Slot)

For each striker, defender, keeper, and action slot:

1. **Roll a target tier** using the 55 / 35 / 4 / 1 weights above.
2. **Filter the position pool** to cards not already taken in this pack.
3. **Pick a card** whose stat bucket matches the rolled tier.
4. **Fallback** — if no card of the rolled tier remains in that pool, pick from the **nearest available tier** (by tier distance) instead of failing the draw.
5. **Record the pick** so it cannot repeat in a later slot.

Example: if the roller lands **Gold** for a striker slot, it looks for attackers with rating **86–89**, chooses one at random, and marks it as taken.

### User Flow After The Roll

1. Intro screen shows the pack name and mystery slots.
2. Player cards are revealed one at a time through the pack-unwrapping animation (up to 5 animated player reveals).
3. Action cards are shown together in a grouped unlock step.
4. Summary screen lists all cards, XP gained, and any level-up.
5. The user continues into Pitch Duel with the starter deck equipped.

The user can **SKIP** during intro or card reveals to jump ahead in the flow.

### Implementation Reference

| Concern | Source |
|---------|--------|
| Pack roller and tier mapping | `lib/models/starter_pack.dart` |
| Pack result assembly (11 cards) | `lib/models/packs.dart` → `buildStarterPack()` |
| Claim + equip on first entry | `lib/blocs/game/game_bloc.dart` → `StarterPackOpened` |
| Reveal UI | `lib/screens/home/widgets/starter_pack_onboarding.dart` |
| On-screen odds copy | `lib/screens/home/widgets/starter_pack.dart` |

Unit tests for composition, tier mapping, and weight distribution live in `test/starter_pack_test.dart`.

> **Note:** The shop also lists a free "Starter Pack" tile with different bronze/silver/gold/platinum odds (70 / 25 / 5 / 0). That table applies to generic `rollPack()` shop packs, **not** the first-time starter pack described here. First-time onboarding always uses `rollStarterPack()` with the 55 / 35 / 4 / 1 weights above.

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

Round resolution compares **attack strength** and **defense strength** and turns the gap between them into one of six outcomes.

### Power Calculation

Each side's power is the sum of four contributions:

```
attack power  = attacker rating + attack action power + scenario attack bonus  + attack swing
defense power = defender rating + defense action power + scenario defense bonus + defense swing
```

- **Card rating** — the OVR of the player card in that role.
- **Action power** — the chosen action card's power.
- **Scenario bonus** — the round's attack or defense tilt.
- **Swing** — the 0–20 wildcard: the Shot Meter surge on the user's side, and a hidden random swing on the CPU's side.

Only the **gap** between the two matters for the outcome:

```
diff = attack power − defense power
```

### Settlement Order

The result is decided in two stages. Risky-card effects are checked first and override the power table.

**Stage 1 — risky-card overrides (independent of power):**

- A **risky defense** action carries a flat **12% chance of a red card** (the defender is sent off).
- A **risky attack** action carries a flat **12% chance of a foul**.
- Red card is checked before foul. If either triggers, the power table below is skipped.

**Stage 2 — power table:** if no risky effect fired, the power gap maps to outcome probabilities. The game is **attack-oriented** — a clear attacking advantage converts most of the time:

| Power gap `diff` | Goal | Saved | Other |
|------------------|------|-------|-------|
| **> 15** — attacker dominant | 80% | 15% | 5% blocked |
| **> 5** — attacker favored | 65% | 25% | 10% missed |
| **−5 to 5** — even | 45% | 35% | 20% (missed / blocked) |
| **−15 to −5** — defender favored | 10% | 65% | 25% blocked |
| **≤ −15** — defender dominant | 5% | 75% | 20% blocked |

The goal column is exactly the **Goal Chance / Stop Chance** the Shot Meter shows before the strike, so the displayed odds are honest. A stronger power advantage gives better scoring odds, but a goal is never fully guaranteed (still 5% when dominated) and a stop is never fully guaranteed.

### Outcome Effects

| Outcome | Meaning | Effect on the match |
|---------|---------|---------------------|
| **Goal** | Attacker beats the defense | Attacking side scores **+1** — the only outcome that changes the score |
| **Saved** | Keeper stops the shot | No change (HELD) |
| **Blocked** | Defender smothers the shot | No change (HELD) |
| **Missed** | Shot off target | No change (HELD) |
| **Foul** | Risky attack gives the ball away | No change (HELD) |
| **Red Card** | Risky defense → defender sent off | Defender card removed for the rest of the match; no score change |

Risky actions can create fouls or red cards, so high-power choices can carry downside. Red-carded cards are removed from future availability for the affected side.

### Implementation Reference

| Concern | Source |
|---------|--------|
| Round build + power calculation | `lib/blocs/game/game_bloc.dart` → `_onMovePlayed` |
| Outcome resolution table | `lib/blocs/game/game_bloc.dart` → `_resolveRound` |
| Shot Meter honest odds | `lib/blocs/game/game_bloc.dart` → `goalChanceForDiff` |
| Full mechanics reference | `docs/round-resolution.md` |

Odds-table parity between the engine and the Shot Meter is guarded by `test/shot_meter_odds_test.dart`.

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
