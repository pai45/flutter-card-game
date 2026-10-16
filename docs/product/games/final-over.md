# Final Over

> **Status:** BUILT
> **Last verified:** 2026-10-16
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

## Illustrated lobby

**Status: BUILT**

Final Over uses an original authored 192 × 256 pixel stadium scene on Flutter and web. A right-handed navy/cyan batter stands at the near crease; an amber/navy right-arm bowler runs in from the far end. Both use athletic 16-bit proportions, separate anatomical limbs and consistent equipment. There are 27 authored batsman poses and 27 bowler poses, with manually simplified distance rendering for the bowler. The supplied GIFs guide composition and delivery timing only; no GIF frames, generated images or bitmaps appear in runtime artwork.

The twelve-second, 30 fps loop covers guard, run-up, gather, overarm release, bounce, coordinated swing, lofted-six contact, follow-through and recovery. Both wickets sit on the pitch centre line. The simplified batter uses a side-on guard, waist-height grip, forward front-foot plant and rear-heel pivot; the front foot stays planted through the shot. Release, bounce and contact are explicit shared anchors; flags, a short ball trail, contact marks, pivot-anchored dust and staggered crowd reactions add restrained activity. The camera, title and controls stay fixed. Pose switching and motion use held integer-pixel positions. Character sheets and anchor data live beside the source.

A raised cyan pixel button replaces the outlined HUD action: stepped corners, dark label, six-pixel lower edge and four-pixel pressed travel. It retains TAKE GUARD / BUILD SQUAD, loading protection, keyboard activation and focus/disabled states. Orbitron headings, Space Grotesk supporting copy, difficulty inside the menu, existing utility destinations and the safe-area dock remain native.

Canonical source: web `scripts/final-over-lobby-source/artwork.mjs`, `characters.mjs` and `pixels.mjs`. Production `final-over.json` and `final-over-poster.svg` are byte-identical in both projects. They contain only local vector shapes/precompositions; no external resources or expressions. Wrappers align the stage to physical pixels. Loading, reduced motion and failure show the neutral guard poster. Playback pauses under panels, in the background and when inactive; starting play never waits for the art.

Squad readiness, starter-pack gating, tier persistence, state ownership, saved data, gameplay and match flow are unchanged. Short/enlarged-text layouts scroll supporting content above the reachable CTA. The original anonymous characters imply no athlete, club or sponsor endorsement.

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

The Games and Trending hero cards use Cricket's canonical white identity for
their frame, badge, subtitle, wicket, pitch outline, and delivery trail. The
green outfield and gold-brown pitch remain illustration colors rather than
interactive accents.

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

## Compact athletic revision

The original anonymous players now use compact athletic proportions, shorter two-bone arms, broader shoulders and simplified material clusters. The user-supplied retro batter reference informs the enlarged navy helmet, readable side profile, shoulder guard, cyan shirt, pale trousers/pads and navy shoes; no reference pixels are copied. The guard/backlift separates the blade from both arms; the preparation blade sits behind the shoulder/helmet while gloves remain on the handle. A pixel-mask check verifies arm clearance outside the shared grip in every pose. The batter is approximately 96 authored pixels tall, excluding the bat. There are 27 batter poses and 27 bowler poses. Hands share the bat-handle anchor; blade geometry stays fixed, head position holds through impact, the front foot plants before contact and recovery includes a lifted step back. The downswing and follow-through use an unwrapped continuous blade arc rather than reversing at contact.

The bowler uses a dedicated fixed-size 45 × 52 distance canvas with simplified clusters. Run-up and walking positions follow the pitch ground projection with authoring-time support-foot locking; there are no three-step character scale changes. Pitch edges, creases and both centred wickets derive from one centre-line model. Crowd reactions begin after the lofted ball reaches the stands.

The shared twelve-second timeline remains 30 fps: release frame 114, bounce frame 125 and contact frame 132. Editable movement metadata records pose anchors and the full bowler trajectory. Preview and production Lottie are derived from the same pixel source; the neutral guard SVG is the fallback. Existing lobby wrappers, controls, game state and match flow remain unchanged.

Revision evidence is in Designer's `output/final-over-compact`. Run `node --test tests/final-over-lobby-artwork.test.mjs` for supported vectors, reproducible assets, geometry, delivery anchors, grip/arm reach, planted feet, fixed distance dimensions and loop closure. Platform checks and their practical limits are recorded with the captures.
