# Hoop Duel

> **Status:** BUILT
> **Last verified:** 2026-08-25
> **Scope:** Basketball starter roster, real-time half-court match, rewards, and career stats

## Product Purpose

Hoop Duel is a fast one-on-one arcade basketball game. Its fantasy is readable
street-ball mastery: break down a defender, time the release, protect the rim,
build heat, and win a short match with a three-athlete roster.

## Where It Lives

Open **Sports -> Games -> Basketball -> Hoop Duel**. The first entry claims a
basketball starter pack. The lobby owns roster/starter choice, team kit,
difficulty, record, and matchmaking.

## Player Flow

1. Claim the starter roster and select three athletes plus one starter.
2. Choose Rookie, Pro, or All-Star and an owned basketball team kit.
3. Match against a CPU roster and play the first 45-second half.
4. Move with left/right controls and use the contextual action pad for shots,
   finishes, fakes, steals, blocks, rebounds, and defensive stance.
5. Make a halftime substitution, then play the second 45-second half.
6. If tied, enter sudden-death overtime.
7. Settle performance grade, XP, career stats, and result feedback.

## Mechanics and Rules

- The possession shot clock is 12 seconds.
- Feet beyond the arc produce three-point attempts; inside shots produce twos.
- Hold and release uses a timing meter with Perfect, Good, Early, and Late
  grades. Stamina and contest pressure alter the window.
- Double-tap movement drives; direction changes create crossovers; contextual
  actions select dunks, layups, jump shots, step-backs, fakes, steals, blocks,
  and rebounds.
- Baskets, stops, and offensive boards build heat. Six unanswered points also
  fills it. Active heat lasts a tuned window and ends when the opponent scores.
- Athletes use guard, wing, or big roles plus readable archetype traits.
- 69 supplied, labeled athlete portraits map to their exact current-roster
  cards; athletes without supplied art retain the collectible-card icon fallback.

## Rewards and Progression
Hoop Duel credits the **Hoop Duel** XP track and never pays coins. A regulation
loss earns 4 XP; an overtime loss earns 6 XP. Wins start at 16 XP, add 2 XP per
point of margin, cap at 26 XP, and can receive the overtime adjustment within
that cap. Settlement is idempotent through the shared game event.

## Gratification and Feedback

Perfect releases, dunks, blocks, steals, buzzer beaters, heat activation, and
overtime each receive distinct sound, haptic, camera, crowd, or overlay beats.
The result sequence reveals score, grade, box score, XP movement, and career
record before offering the next match.

## Visible States

- Starter-pack gate, loading, lobby, roster, kit, and difficulty selection
- Match intro, first half, halftime substitution, second half, overtime break
- Live HUD for score, clocks, stamina, heat, and shot timing
- Abandoned match, win/loss, performance grade, rematch, and exit

## Persistence

`BasketballStats` stores games, wins, losses, overtime games, streaks, scoring
records, dunks, blocks, perfect releases, last roster/starter/difficulty, hints,
and last team. Shared storage owns the starter pack, cards, team ownership,
progression, and XP ledger.

## Planned Scope and Current Limitations

- **BUILT:** Real-time engine, three-athlete roster, CPU difficulties,
  halftime substitution, overtime, heat, team cosmetics, XP, stats, and cues.
- **PROTOTYPE:** CPU-only local matches; no online PvP or remote roster service.
- **PLANNED:** No additional roadmap commitments are recorded.

## Implementation References

- [`lib/models/basketball.dart`](../../../lib/models/basketball.dart)
- [`lib/data/basketball_portraits.dart`](../../../lib/data/basketball_portraits.dart)
- [`lib/games/basketball/basketball_engine.dart`](../../../lib/games/basketball/basketball_engine.dart)
- [`lib/blocs/basketball/basketball_cubit.dart`](../../../lib/blocs/basketball/basketball_cubit.dart)
- [`lib/screens/basketball/basketball_lobby_screen.dart`](../../../lib/screens/basketball/basketball_lobby_screen.dart)
- [`lib/screens/basketball/basketball_match_screen.dart`](../../../lib/screens/basketball/basketball_match_screen.dart)

## Tests

- [`test/basketball_engine_test.dart`](../../../test/basketball_engine_test.dart)
- [`test/basketball_lobby_screen_test.dart`](../../../test/basketball_lobby_screen_test.dart)
- [`test/basketball_match_ui_test.dart`](../../../test/basketball_match_ui_test.dart)
- [`test/basketball_roster_deck_test.dart`](../../../test/basketball_roster_deck_test.dart)
- [`test/basketball_portraits_test.dart`](../../../test/basketball_portraits_test.dart)
- [`test/basketball_team_shop_test.dart`](../../../test/basketball_team_shop_test.dart)
