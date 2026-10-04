# Pitch Duel Card Game

> **Status:** BUILT
> **Last verified:** 2026-10-04
> **Scope:** Starter pack, collection/deck gate, four-round card match, combinations, timing, settlement, and progression

Pitch Duel is StatOz's football card game. It turns the user's collection into a playable tactical match: build a squad, choose cards round by round, resolve football scenarios, and earn XP/coins from the result.

## Product Purpose

Pitch Duel gives users a playable game loop beyond sports predictions. It creates value for card collection, packs, progression, match history, and leaderboard ranking.

## Where It Lives

Pitch Duel is opened from the **GAMES** tab in the Predictions area.

The Games tab currently shows:

- **Pitch Duel** as the available tactical card game
- **Penalty Shootout** as a standalone spot-kick mode
- **Football Quiz** as a trivia gauntlet

When Pitch Duel opens, it becomes a full-screen game hub with internal navigation for home, deck, all cards, how to play, match, and related game views. Penalty Shootout opens as its own full-screen game hub from the same Games tab and is documented separately in [Penalty Shootout](penalty-shootout.md).

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

The active deck is used when starting a match. Actions must be distinct and support two attacks and two defenses, allowing special cards to cover either role once. If a deck is incomplete, lacks role coverage, or contains unowned cards, the match start is blocked with a deck-required state.

## Mechanics and Rules [BUILT]

Single-player matches retain four rounds: toss, role choice, scenario briefing,
one player plus one action, timing, resolution, then full time. The player
attacks twice and defends twice, alternating from the initial role. Every used
player and action is spent for the match, for both sides. Ownership is retained.
An action is **RESERVED** when using it would leave a later round without a
legal action; the hand explains the role it is protecting.

### Power and combinations

`Total = player OVR + action power + role scenario bonus + affinity match + scenario match + timing`

Affinity match adds **+4** once. Scenario match adds **+6** once. Both stack to
**+10**, at every rarity tier. Existing IDs, ratings, powers and tiers remain.
One affinity per attacker/defender is derived from their existing trait and
keyed by stable player ID in Pitch Duel metadata.

| Affinity | Matching actions |
|---|---|
| Finisher | Through Ball, Power Shot, Long Shot |
| Creator | Skill Move, Mind Game |
| Runner | Cut Inside, Quick Break, Fast Recovery |
| Stopper | Slide Tackle, Last-Ditch Tackle |
| Reader | Press High, Intercept, Mind Game |
| Anchor | Block Lane, Tight Marking, Fast Recovery |

Scenario briefing lists role-compatible matching actions. Authored matches
include Quick Break / Counter Attack, Long Shot / Set Piece Chance and Block
Lane / Box Defense. The complete mapping lives in `pitchScenarioActions` in
`lib/models/pitch_duel_rules.dart`. All In earns neither combination bonus.
Tactical Foul is displayed as **Disrupt Play**, preserving ID `act14` and power.
Accuracy penalties, bypasses, debuffs, fouls and red-card risks are inactive;
card details explain the actual power and matching bonuses.

### Timing and outcome

The centered meter sweeps in **900 ms per direction**, paused while its tutorial
is open. Marker distance from center determines the bonus, using the same zone
boundaries for painting and scoring:

| Zone | Distance from center | Bonus |
|---|---|---|
| Perfect | ≤ 0.045 | +8 |
| Great | ≤ 0.10 | +6 |
| Good | ≤ 0.25 | +4 |
| Early / Late | > 0.25 | +0 |

The marker freezes on impact, shows the exact bonus, and returns a typed timing
result. Reduced motion skips timing with fixed **+4**. CPU timing is a uniform
integer **0–8**. Card power and timing remain separate. **Rival power range**
covers the weakest remaining legal pair through the strongest plus eight;
it never reads the hidden committed selection or claims a goal probability.

Higher attack total produces **GOAL**; higher defense total produces **SAVED**.
Exact ties flip a coin between **GOAL** and **BLOCKED**. Only goals increment
the attacking side's score. A level score after four rounds is a **draw**.
Penalty Shootout is a separate mode. Older history with penalty fields remains
readable, but new Pitch Duel matches do not enter penalties.

### CPU and commitment

CPU decks supply two dedicated attack and two defense actions plus two extras.
The CPU spends players/actions once and observes the same reservation rules.
Difficulty uses the existing smartness chance (`min(1, Pitch Duel level / 12)`)
to choose the strongest contextual legal pair; otherwise it picks a random
legal pair. At equal strength it chooses randomly among tied pairs.

Moves only resolve in the play phase. Duplicate commit and round-advance events
are ignored after the phase changes. Reward settlement is serialized by the
existing shared event queue and guarded by the final-result phase.

## Gratification and Feedback [BUILT]

The persistent board keeps a compact rival header above the scenario and
power, with only the two current-role players below. Two anonymous card backs
represent the rival play; neither the hidden identities nor their hand positions
are exposed. Players remain full-size; short screens scroll the hand while COMMIT
stays docked. Action labels show the actual available MATCH +4/+6/+10 bonus.
The scenario's info action opens the full power calculation and matching actions.

Football cards use a dedicated sci-fi playing-card face: portrait windows, bold
corner indices, angular etched rails, mirrored lower player indices, quiet rarity
inlays, affinity glyphs, and blueprint action art. Selected frames brighten without
covering labels; used/reserved cards retain their silhouettes with muted labels.
Long-press opens the full ability. Portraits and frames are isolated for repaint;
the board no longer runs an animated stadium underneath its opaque pitch texture.

The normal **1.4-second** reveal explains player → action → scenario →
combination → timing → verdict → score. Existing HeadToHeadPowerMeter,
stingers and score ticks are reused. **TAP TO FINISH REVEAL** completes the
presentation without resolving the move again. NEXT ROUND becomes available
when the reveal finishes, with no additional countdown or automatic advance.
Reduced motion presents settled numbers immediately. Full time shows the best
combination and its contributions, with **PLAY AGAIN** prominent.

The lobby shows the equipped squad, next match goal and **PLAY MATCH**; an invalid
deck instead offers **FIX YOUR DECK**. Deck building shows matching actions, and
pack summaries suggest an available +4 pair. Reduced-motion pack opening goes
straight to the already-settled summary.

### Match goals and replay [BUILT]

Three skill goals rotate after completed, non-demo Pitch Duel matches:
**LINK TWO PLAYS**, **BUILD A +10 COMBO**, and **LINK BOTH ROLES**. Lobby shows
the next goal and the best linked-round count in retained history. The rival header
shows live goal progress, and full time reports completion plus the next goal.
Goals use settled combination breakdowns; they add no extra XP, coins or upgrades
and remain achievable with reduced motion. Other sports and demos do not advance
the cycle. Optional `pitchMasteryIndex` in match history preserves rotation when
older history is trimmed; legacy entries use the retained match count as a fallback.

Assets include two subdued PNG backgrounds, sixteen original vector action
illustrations, seven scenario emblems and six affinity glyphs under
`assets/pitch_duel/`. Existing football portraits are reused; text and card frames
remain Flutter-rendered. Other sport player cards keep their existing presentation.

## Final Result And Rewards

The final result records whether the user achieved:

- Victory
- Defeat
- Draw

Rewards connect the match to the broader product economy:

- Victory gives more coins than a draw or defeat.
- Match XP can increase or decrease based on result, margin, or shutout.
- XP never drops below zero. Current implementation derives level from total XP, so a large enough negative XP delta can de-level the user.
- Level-ups can trigger celebration states.

Match results are saved to history with the deck name, score, optional legacy penalty fields, round summary, optional power breakdowns, and XP earned.

For the full XP curve, pack XP formulas, level progress fields, de-leveling nuance, and CPU difficulty scaling, see [Progression and Leveling](../systems/progression-and-leveling.md).

## Player Flow
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
- Match history keeps the latest saved entries rather than an unlimited archive, including standalone Penalty Shootout entries.
- The game uses persistent local product state for decks, owned cards, wallet, progression, starter pack, daily drop, tutorials, and match history.

## Rewards and Progression
Match settlement credits the Pitch Duel XP track and Oz Coins through typed
ledgers. A regulation draw awards **+4 XP**. Wins/losses,
round/score context, and CPU level scaling use the formulas documented in
[Progression and Leveling](../systems/progression-and-leveling.md).

## Visible States

Starter-pack required/claimed, invalid/valid deck, matchmaking, round setup,
card ready/selected/spent, reserved action, match-goal progress, shot meter, resolving, round result, final result,
reward settlement, and level-up states are represented.

## Persistence

Owned cards, decks, progression tracks, wallet, XP/coin ledgers, starter pack,
daily drop, tutorial state, and bounded match history persist through shared
secure storage. An in-progress Pitch Duel match is not a cross-session resume contract.

## Persistence and Compatibility

`MatchHistoryRound` optionally stores player/opponent `PowerBreakdown`. Old
records without these fields still load. `MatchHistoryEntry.pitchMasteryIndex`
is also optional and does not migrate ownership or rewards. Affinities are scoped metadata, so
ownership and saved deck IDs need no migration. Old unsupported one-sided
decks stay editable but cannot start until repaired. Wallet, XP, reward sources,
and starter-pack contracts retain their existing formulas.

## Planned Scope and Current Limitations

- **BUILT:** Four-round combinations, symmetric card exhaustion, revised timing,
  sci-fi playing cards, compact board, faster contribution reveal, squad lobby,
  rotating match goals and recap.
- **PLANNED:** No additional gameplay scope is approved in this update. Cup runs,
  multiplayer, extra slots and persistent upgrades remain outside the release.
- **DEPRECATED:** Probabilistic risk/odds helpers remain for rollback; the live
  path uses deterministic totals and exact-tie coin flips.
- **Limitation:** The roughly 15-second return-to-first-choice target excludes
  starter packs and first-time tutorials; perceived clarity and pacing still
  benefit from player usability testing on physical devices.

## Implementation References

- `lib/models/pitch_duel_rules.dart`: metadata, legality, power, timing and range.
- `lib/models/pitch_duel_mastery.dart`: rotating skill goals and history-derived progress.
- `lib/blocs/game/game_bloc.dart`: CPU choices, commitment and settlement.
- `lib/screens/game/widgets/duel_board_phase.dart`, `match_phases.dart`, `final_result_phase.dart`.
- `lib/widgets/cyber/cyber_widgets.dart`: football variant, contribution strip and asset fallback.
- [Technical round reference](../../technical/round-resolution.md).

## Tests

`pitch_duel_rules_test.dart`, `pitch_duel_match_test.dart` and
`pitch_duel_presentation_test.dart` cover combinations, timing boundaries,
contextual wins, exhaustion, CPU range privacy, repeated commits/settlement,
history compatibility, phone layouts, tutorial pause, skip/reduced motion and
missing artwork. Existing shot-meter, briefing, round-result, collection/deck
and economy suites remain regression checks.

`pitch_duel_mastery_test.dart` checks goal rotation, attack/defense progress and
old history. `spotlight_walkthrough_test.dart` checks clear pixels for scaled and
overlapping targets, tap routing and teardown. `pitch_duel_card_visual_test.dart`
uses real fonts at enlarged phone layouts and can export renders with
`--dart-define=PITCH_VISUAL_QA=true`. Browser access was unavailable on 2026-10-04;
these rendered frames were reviewed, but browser/device frame pacing remains unverified.
