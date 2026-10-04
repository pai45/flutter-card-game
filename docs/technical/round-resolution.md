# Pitch Duel Round Resolution

> **Status:** BUILT
> **Last verified:** 2026-10-04
> **Scope:** Legal commitment, contextual power, timing, CPU selection, history and settlement

Code is authoritative: `lib/models/pitch_duel_rules.dart` owns pure calculations;
`lib/blocs/game/game_bloc.dart` owns events, CPU choices and rewards.

## Pipeline

`toss → roleReveal → scenario → play → roundResult`, repeated for four rounds,
then `finalResult`. Roles alternate from `initialAttackingChoice`. The scenario
is drawn without repeating previous scenarios while unused ones remain.
`PlayStarted` chooses the hidden CPU pair once. `MovePlayed` resolves only in
`play`, with an unused on-role player and a legal unused action. Resolution
consumes both sides' player and action IDs and stores a `RoundResult` before
presentation begins. Duplicate commitment after the phase change is ignored.
`RoundAdvanced` likewise requires `roundResult`.

## Legal actions

`pitchActionFitsRole` permits the current role category or a special action.
`pitchRemainingRoles` lists the remaining alternating roles through round four.
`pitchCanComplete` solves the small distinct-ID matching problem recursively.
`pitchLegalActions` filters unused role-compatible actions whose removal still
allows every future role to be filled. UI, CPU selection and commitment use
this same function. A compatible excluded action is visibly RESERVED.

Deck readiness requires unique owned 2 attackers, 2 defenders, 1 keeper and
6 actions with four-round coverage. Saved decks use their existing schema;
unsupported old decks remain editable rather than being silently replaced.
CPU generation supplies two attack/two defense actions plus two extras.

## One power calculation

`pitchPower(player, action, scenario, attacking, timing)` returns `PowerBreakdown`:

```
base  = player.rating + action.power + roleScenarioBonus + affinity + scenarioCombo
total = base + timing
```

`affinity` is +4 or zero; `scenarioCombo` is +6 or zero. Each is one set-membership
check, independent of tier, so combination power cannot exceed +10. Metadata
is scoped to football and keyed by stable player/scenario/action IDs. Tiered
action IDs reduce to their base ID for matching and illustration lookup.
All In (`act13`) is absent from both mappings. Disrupt Play keeps `act14`.
Other sport players have no Pitch Duel affinity. Ratings/powers are not mutated.

The live board previews this function's `base`. Final round totals use the same
function with a timing bonus. `RoundResult` stores both optional role-oriented
breakdowns and the player's typed `ShotTimingResult`. History stores optional
player/opponent breakdowns; absent fields in older JSON decode as null.

## Timing

`ShotTimingResult.at(position)` clamps position to [0,1] and measures distance
from 0.5. Inclusive half widths are Perfect .045, Great .10 and Good .25;
larger distances are Early/Late. Shared quality bonuses are 8,6,4,0. A 1e-9
boundary tolerance accommodates floating-point representation. The painter
reads those same widths, and labels read the same quality bonuses.

Normal sweep duration is 900 ms per direction. Tutorial completion starts the
sweep after preparation. Impact freezes the marker and returns the typed result
after 600 ms. Reduced motion commits `ShotTimingResult.accessible` (+4), skipping
reaction timing. CPU gets `nextInt(9)` (0–8 inclusive). Legacy `playerSurge`
inputs are rounded/clamped 0–8; absent timing defaults to +4.

## CPU strategy and privacy

`_pickOpponentMove` enumerates remaining unused legal player/action pairs,
scored with `pitchPower.base`. With probability `cpuSmartness(level)` it picks
the strongest contextual pair, randomizing ties; otherwise any legal pair.
Smartness remains `min(1, level / 12)` and level comes from the Pitch Duel track.

`pitchRivalRange` enumerates all remaining legal pairs independently of the
stored CPU choice. It returns min base through max base +8. The UI wrapper
`playerRivalRange` filters used/suspended cards. Switching a hidden commitment
cannot change the preview. It is a scouting power range, not a probability.

## Verdict and full time

`resolveRoundDeterministic(attackPower - defensePower)` returns GOAL when positive,
SAVED when negative, and GOAL/BLOCKED by a coin flip when exactly zero. Only
GOAL increments the attacking score. Four-round level scores end in a draw;
Penalty Shootout is separate. Foul/red/miss enum values and former probabilistic
helpers remain **DEPRECATED** rollback/history compatibility code, unused by
the live resolver.

## Presentation and settlement

The 1.4-second board timeline reveals player, action, scenario, combo and timing,
then verdict and score. Tap-to-finish and reduced motion present the settled data;
they do not invoke `MovePlayed`. NEXT ROUND is ready after the reveal, without
a second countdown or automatic advance. Full time reuses existing wallet/XP/quest/streak
contracts. GameBloc's cross-event queue serializes handlers, and the final phase
guards repeat `MatchFinished`. History receives one match record.

## Match goals and history compatibility

`pitch_duel_mastery.dart` derives three rotating combination goals from real
non-demo `mode: match` records. `MatchFinished` writes the optional
`pitchMasteryIndex` before prepending the new history entry. On the next match,
the latest index advances modulo three, including when bounded history is full.
Older records lack the field and use retained match count; round breakdowns remain
optional. Live progress and result progress use the player's settled breakdown
for each role. These goals do not add any settlement or reaction-time requirement.

## Verification

- `test/pitch_duel_rules_test.dart`: both bonuses, all tiers/affinities, caps,
  lower-rated contextual wins, zone boundaries, reservation continuations,
  generated CPU decks, range bounds and old/new history JSON.
- `test/pitch_duel_match_test.dart`: four-round completion from both initial
  roles, preview parity, hidden-pick independence, CPU exhaustion, duplicate
  commitment/advance/settlement and draws.
- `test/pitch_duel_presentation_test.dart`: enlarged text, compact/tall phone
  reachability, tutorial pause/marker freeze, skip/reduced motion and asset fallback.
- Existing `shot_meter_odds_test.dart`, `scenario_briefing_transition_test.dart`,
  `round_result_overflow_test.dart`, collection/deck and economy suites.

On 2026-10-03, all 100 focused regressions passed and targeted Flutter analysis
was clean. The release preview was reviewed at 360 × 740 and 412 × 915, including
1.4× text, attack/defense choices, the meter, lobby, deck builder, full-time recap,
and reduced-motion pack summary.

`tool/pitch_duel_preview.dart` renders production widgets with isolated fixtures
without loading a saved profile. Run `flutter run -d web-server -t
tool/pitch_duel_preview.dart`; query parameters select `screen=board`, `defense`,
`scenario`, `reveal`, `meter`, `lobby`, `deck`, `result`, or `pack`. Add `text=1.4`
and/or `motion=reduced` for accessibility review.

On 2026-10-04 the board/card/walkthrough simplification adds focused mastery,
spotlight and real-font visual regressions. The SDK platform-message callback
locally contained a duplicate `completer.complete(reply)`; removing that one line
restored runtime callbacks without discarding other SDK changes. Browser access
was unavailable in this session; Flutter-rendered phone frames were inspected.
Preview also supports `screen=cards` and interactive `screen=flow`, plus
`tutorial=play` or `tutorial=shot-meter` for targeted walkthrough checks.
