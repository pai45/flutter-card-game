# Final Over

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Cricket starter pack, batting deck, three-over chase, rewards, and career record

## Product Purpose

Final Over is StatOz's timing-driven cricket arcade mode. It turns a compact
run chase into a high-pressure batting session where shot selection, contact
timing, wickets, objectives, and OVERDRIVE all matter.

## Where It Lives

Open **Sports -> Games -> Cricket -> Final Over**. First entry requires the
free cricket starter pack and a three-batsman deck. The hub exposes tier,
career record, kit selection, deck editing, and the play CTA.

## Player Flow

1. Claim the cricket starter pack if required.
2. Equip three batsmen and choose an owned kit.
3. Select Rookie, Pro, or Elite.
4. Enter matchmaking and receive a target from the tier's approved ladder.
5. Chase the target across up to 18 legal balls, using tap/swipe batting and
   OVERDRIVE when available.
6. Watch ball, over, score, wicket, requirement, combo, and objective feedback.
7. Finish on a successful chase, exhausted balls, or exhausted wickets.
8. Settle XP, career stats, and the staged result cinematic; rematch or exit.

## Mechanics and Rules

| Tier | Target ladder | XP multiplier | Intent |
|---|---:|---:|---|
| Rookie | 32, 36, 40 | 0.8x | Wider timing and forgiving chase |
| Pro | 44, 48, 52, 56 | 1.0x | Baseline challenge |
| Elite | 58, 62, 66 | 1.35x | Boundary-led high pressure |

The engine allows three six-ball overs. Extras do not consume a legal ball.
Each tier also owns timing windows, wickets in hand, fielding behavior, and
OVERDRIVE cost through `GameplayTuning`.

Product copy in the Games hero still says "six-ball cricket chase" while the
current engine runs up to 18 legal balls; the engine behavior is authoritative
until that entry copy is changed.

## Rewards and Progression
Final Over credits the **Final Over** XP track and writes an XP-ledger entry.
It does not pay Oz Coins.

```text
base = win ? 30 : 10
xp = base + runs + (stars * 8) + objective bonus
   + win-only balls-to-spare bonus + unbeaten-chase bonus
final xp = round(xp * tier multiplier)
```

An objective adds 15 XP, every ball to spare adds 4 XP on a win, and a
zero-wicket win adds 10 XP. Match IDs prevent duplicate settlement.

## Gratification and Feedback

Runs tick immediately, boundaries receive crowd/audio/haptic beats, wickets
interrupt the rhythm, completed overs introduce a new bowler, and OVERDRIVE
gets a live charge state. The result reveals verdict, reason, ball ledger,
box score, grade, XP, level progress, and career record in stages.

## Visible States

- Loading and starter-pack gate
- Hub, tier selection, deck builder, kit picker, and matchmaking
- First-match hints, active delivery, between-over reveal, and paused state
- Chase won, chase lost, result settlement, rematch, and exit
- Invalid deck or unavailable kit fallback

## Persistence

`FinalOverStats` stores games, wins, runs, wickets, boundaries, records,
selected tier, selected kit, last batsmen, and hint completion. The shared game
state stores cricket starter-pack ownership, cards/decks, progression, and XP
ledger.

## Planned Scope and Current Limitations

- **BUILT:** Three-over engine, tier tuning, starter pack, deck, kits, XP,
  stats, first-match hints, audio/haptics, and result settlement.
- **PROTOTYPE:** Opponents and all state are local; there is no network match.
- **CURRENT LIMITATION:** Games-tab subtitle says six balls while gameplay
  permits 18 legal balls.
- **PLANNED:** No additional roadmap commitments are recorded.

## Implementation References

- [`lib/models/final_over.dart`](../../../lib/models/final_over.dart)
- [`lib/blocs/final_over/final_over_cubit.dart`](../../../lib/blocs/final_over/final_over_cubit.dart)
- [`lib/screens/final_over/final_over_hub.dart`](../../../lib/screens/final_over/final_over_hub.dart)
- [`lib/screens/final_over/final_over_match_screen.dart`](../../../lib/screens/final_over/final_over_match_screen.dart)
- [`final_over/lib/`](../../../final_over/lib/)

## Tests

- [`test/final_over_balance_test.dart`](../../../test/final_over_balance_test.dart)
- [`test/final_over_batting_controls_test.dart`](../../../test/final_over_batting_controls_test.dart)
- [`test/final_over_kit_selector_test.dart`](../../../test/final_over_kit_selector_test.dart)
- [`test/final_over_kit_shop_test.dart`](../../../test/final_over_kit_shop_test.dart)
