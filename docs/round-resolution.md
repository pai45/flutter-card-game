# Round Resolution & Match-Phase Settlement

How a single round of Pitch Duel is settled: the inputs, the power formula, and
the probability table that turns two cards into one of six outcomes
(**goal / saved / blocked / missed / foul / red card**).

> **Source of truth:** [`lib/blocs/game/game_bloc.dart`](../lib/blocs/game/game_bloc.dart)
> — specifically `GameBloc._onMovePlayed` (builds the round) and
> `GameBloc._resolveRound` (decides the outcome). The honest goal odds are also
> exported as `goalChanceForDiff` near the top of that file. The outcome enum,
> labels and colours live in
> [`lib/utils/label_helpers.dart`](../lib/utils/label_helpers.dart) and the
> `RoundOutcome` enum in [`lib/config/enums.dart`](../lib/config/enums.dart).
>
> Line numbers below are accurate at time of writing but may drift — search by
> function name if they don't match.

---

## 1. Match-phase pipeline

A match is 4 rounds. Each round walks through these `MatchPhase`s, driven by
`GameBloc` events:

```
matchStart
  └─ toss            (TossResolved)        → coin toss decides first attack/defend choice
roleReveal           (RoleChosen / RoleRevealAcknowledged)
  └─ scenario        (ScenarioShown)       → a ScenarioCard is drawn, tilting the round
play                 (PlayStarted)         → you pick a player card + action card
  └─ MovePlayed  ───────────────────────►  ★ ROUND IS RESOLVED HERE ★
roundResult          (the clash cinematic + verdict + score)
  └─ RoundAdvanced
        ├─ round < 4 → next roleReveal (roles flip — see §7)
        └─ round = 4 → matchEnd
```

The **settlement** (this document) is everything that happens inside the
`MovePlayed` handler.

---

## 2. Inputs to a round

When `MovePlayed` fires, the bloc has:

| Input | Where it comes from |
|---|---|
| **Attacker / defender card** | Your selected player card + the CPU's player card, assigned to roles by who is attacking. |
| **Attack / defense action** | Your selected action card + the CPU's chosen action card. |
| **Scenario** | The `ScenarioCard` drawn this round, providing `attackBonus` / `defenseBonus`. |
| **Player swing** | `event.playerSurge` from the **Shot Meter** (0–20). Falls back to `random × 20` if absent (e.g. reduced-motion). |
| **CPU swing** | Always `random × 20`. |

The CPU's action choice is mildly strategic: when the scenario favours the CPU's
role it may (gated by a smartness roll tied to your level) pick its
highest-power action instead of a random one — see `_onMovePlayed`
([game_bloc.dart:649-662](../lib/blocs/game/game_bloc.dart#L649-L662)).

Roles are assigned so the *player's* swing always lands on the side the player is
playing:

```dart
attackSwing  = playerAttacking ? playerSwing : oppSwing;
defenseSwing = playerAttacking ? oppSwing    : playerSwing;
```

---

## 3. Power calculation

[game_bloc.dart:675-684](../lib/blocs/game/game_bloc.dart#L675-L684)

```
attackPower  = attackerCard.rating + attackAction.power + scenario.attackBonus  + attackSwing
defensePower = defenderCard.rating + defenseAction.power + scenario.defenseBonus + defenseSwing
```

Four additive contributions per side:

1. **Card rating** — the OVR of the player card in that role.
2. **Action power** — the chosen action card's power.
3. **Scenario bonus** — per-round tilt toward attack or defense.
4. **Swing** — the 0–20 wildcard (Shot Meter for the player, random for the CPU).

The only number that matters for the outcome table is the **gap**:

```
diff = attackPower − defensePower
```

---

## 4. Settlement algorithm

`GameBloc._resolveRound(attackPower, defensePower, attackAction, defenseAction)`
([game_bloc.dart:901-938](../lib/blocs/game/game_bloc.dart#L901-L938)).

It resolves in two stages — **risky-card overrides first**, then the **power
table**. Each `_random.nextDouble()` is an independent draw.

### Stage A — risky-card overrides (checked before power)

```dart
if (defenseAction.risky && random < 0.12) return RoundOutcome.redCard; // checked 1st
if (attackAction.risky  && random < 0.12) return RoundOutcome.foul;    // checked 2nd
```

- A **risky defense** action carries a flat **12% red-card** self-risk.
- A **risky attack** action carries a flat **12% foul** self-risk.
- These are independent of power. Red card is tested before foul. If either
  fires, the power table is skipped.

### Stage B — power table (when no risky override fired)

A single uniform `roll ∈ [0,1)` is bucketed by the `diff` band:

| Power gap `diff` | Goal | Saved | Other |
|---|---|---|---|
| **`> 15`** — attacker dominant | 80% | 15% | 5% blocked |
| **`> 5`** — attacker favored | 65% | 25% | 10% missed |
| **`-5 … 5`** — even | 45% | 35% | 20% (50-50 missed / blocked) |
| **`-15 … -5`** — defender favored | 10% | 65% | 25% blocked |
| **`≤ -15`** — defender dominant | 5% | 75% | 20% blocked |

(Bands are evaluated as `diff > 15`, `diff > 5`, `diff > -5`, `diff > -15`, else.)

---

## 5. Goal-odds reference (Shot Meter)

The goal column above is mirrored by `goalChanceForDiff(diff)`
([game_bloc.dart:25-31](../lib/blocs/game/game_bloc.dart#L25-L31)), which the
Shot Meter overlay uses to show **honest odds** before you shoot:

```dart
double goalChanceForDiff(double diff) {
  if (diff > 15)  return 0.80;
  if (diff > 5)   return 0.65;
  if (diff > -5)  return 0.45;
  if (diff > -15) return 0.10;
  return 0.05;
}
```

> ⚠️ **Invariant:** if you ever change the goal probabilities in `_resolveRound`,
> change `goalChanceForDiff` to match. They must stay in lockstep or the Shot
> Meter will lie. (See `test/shot_meter_odds_test.dart`.)

---

## 6. Applying the outcome to state

[game_bloc.dart:692-728](../lib/blocs/game/game_bloc.dart#L692-L728)

- **Goal** → the **attacking side's score increments by 1**
  (`playerScore` or `opponentScore`). This is the only outcome that changes the
  scoreboard.
- **Red card** → the **defender's card id** is added to the suspension list
  (`opponentRedCarded` if the player was attacking, else `redCardedCards`),
  removing that card for the rest of the match.
- All outcomes append a `RoundResult` (cards, actions, powers, outcome) to
  `roundResults` and transition the phase to `roundResult`, which the
  round-result cinematic renders.

### Outcome reference

| Outcome | Meaning | Score | Side effect |
|---|---|---|---|
| **Goal** | Attacker beats the defense | Attacker **+1** | — |
| **Saved** | Keeper stops the shot | none | — |
| **Blocked** | Defender smothers the shot | none | — |
| **Missed** | Shot off target | none | — |
| **Foul** | Risky attack gives the ball away | none | — (dead round) |
| **Red Card** | Risky defense → defender sent off | none | Defender card **suspended** rest of match |

Everything except a goal shows as **HELD** on the score banner.

---

## 7. Role alternation across the 4 rounds

`_onRoundAdvanced` ([game_bloc.dart:731-745](../lib/blocs/game/game_bloc.dart#L731-L745)):

```dart
playerAttacking: nextRound.isOdd ? initialAttack : !initialAttack
```

Odd rounds use your initial toss choice; even rounds flip it. So over a match you
alternate attack/defend each round, and your Shot-Meter swing applies to whichever
role you currently hold.

---

## 8. Worked example

You are **attacking** in round 1:

| Side | rating | action.power | scenario bonus | swing | **power** |
|---|---|---|---|---|---|
| Attack (you) | 84 | 20 | +10 | 15 (good meter) | **129** |
| Defense (CPU) | 80 | 18 | +6 | 8 (random) | **112** |

`diff = 129 − 112 = 17` → band **`> 15`** → **80% goal / 15% saved / 5% blocked**.
Neither action was risky, so no red-card/foul check applied. A `roll` of `0.31`
→ **GOAL**, and `playerScore` ticks to 1.

---

## 9. Design notes & extension points

- **Nothing is certain.** Even total dominance leaves a 5% upset (5% blocked when
  crushing, 5% goal when crushed) — variance is intentional.
- **Attack is favored at parity.** The even band still gives 45% goal; the bias
  only flips defensive once `diff < -5`. A clean chance tends to beat a level
  defense.
- **Risky cards are decoupled from power.** The 12% red-card / foul risks apply
  regardless of how strong your hand is — a pure high-risk/high-reward gamble.
- **Foul is currently inert** beyond "no goal this round" — it awards the defense
  nothing and carries no card. A natural extension point if fouls should matter
  (e.g. a next-round free-kick bonus, or accumulating toward a booking) is
  Stage A of `_resolveRound`.
- **Where to tune difficulty:** the `diff` thresholds and per-band probabilities
  in `_resolveRound`, the scenario `attackBonus`/`defenseBonus`, the 0–20 swing
  range, the 12% risky chances, and `cpuSmartness`. Remember to keep
  `goalChanceForDiff` in sync with any goal-probability change.
```
