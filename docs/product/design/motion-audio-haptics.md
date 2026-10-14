# Motion, Celebrations, Audio, Haptics, and Reduced Motion

> **Status:** BUILT
> **Last verified:** 2026-10-04
> **Scope:** Motion hierarchy, celebration sequencing, audio cues, haptic feedback, skip behavior, and reduced-motion handling

## Product Purpose

Sensory feedback makes play legible and rewarding: motion shows state change,
audio establishes impact and rarity, and haptics confirm decisive touch moments.
Accessibility and pace controls keep those effects supportive rather than mandatory.

## Where It Lives

Shared audio is controlled by `AudioController` and mapped through game cue
helpers. Haptics live at decisive interaction/result points. Reduced-motion
behavior uses platform animation preferences and mode settings, with especially
explicit support in Basketball, Final Over, Grand Prix Dash, Tennis, streaks,
shootout, and matchmaking.

## Player Flow

1. Act or trigger a result.
2. Receive immediate local feedback.
3. Watch the proportional state/result/reward beat, or skip where supported.
4. The already-settled outcome remains identical.
5. With reduced motion, receive a shorter/static but equally informative state change.

## Mechanics and Rules

- Match cue intent to the event; use the [audio cue catalog](../../audio/CUE_CATALOG.md).
- Do not stack unrelated stingers, continuous haptics, and full-screen motion.
- Haptics confirm commitment, impact, selection, or rare payoff—not passive updates.
- Reduced motion removes camera shake, trails, repeated pulses, long staging, or
  reaction-time dependency while retaining score, verdict, and reward information.
- Respect sound/music/haptic settings where a mode exposes them.
- Settlement happens independently of animation completion or skip.

### Game discovery illustration loops [BUILT]

Games hero cards, Quick Play tiles, and Trending cards use identical shared
4.8-second normalized keyframes in Flutter and web. Each scene performs one
small gameplay action, settles and holds, then smoothly returns to its initial
pose. Only the action SVG layer transforms; static layers and labels remain stable.

Reduced motion, covered routes (TickerMode), locked state, background lifecycle,
and offscreen scroll positions stop Flutter's controller. Web uses reduced-motion
media queries, IntersectionObserver and document visibility. Static poses use phase
0.28. Optional explicit phase inputs support deterministic review and seeking.
Both evaluators interpolate transforms and opacity with smoothstep.

The 120 ms press and art emphasis become immediate/static under reduced motion.
Readable focus/outline/rail feedback remains. Taps retain selection haptics and
existing navigation guards. Loops are silent and never award a reward or delay play.

### Pitch Duel contribution reveal and timing [BUILT]

The persistent board reveals player → action → scenario → combination → timing
with HeadToHeadPowerMeter, then verdict/stinger and score. Normal presentation
lasts 1.4 seconds; tap-to-finish sets presentation to the settled end state.
Commit already stores the result, so skip and reduced motion do not change
totals or duplicate rewards. Reduced motion uses fixed player timing +4,
immediate round contributions and a static pack summary. The meter's centered
Perfect/Great/Good zones share scoring definitions. On impact it freezes for
600 ms with the exact +8/+6/+4/+0 bonus and proportional sound/haptic feedback.
The sweep remains paused during its tutorial. Final result keeps PLAY AGAIN and
adds a combination recap and completed/next skill goals. NEXT ROUND is available
when the reveal finishes, without another countdown. CPU toss decisions use
700 ms plus a 200 ms hold; reduced motion uses 180 ms plus the same hold.
The hidden-hand selection delay and redundant animated stadium under the pitch
texture are removed. See [Pitch Duel](../games/pitch-duel.md).
Lobby slide/deal entrances honor reduced motion immediately, and PLAY MATCH
precedes squad/goal detail. The 450 ms outcome stamp fits inside the 1.4-second
round reveal; tap-to-finish clears it too.

## Rewards and Progression

Pack rarity stings, XP/coin count-ups, level-up beats, achievement reveals,
streak milestones, referral rewards, and result celebrations communicate value;
they do not calculate or own it.

## Gratification and Feedback

Use a hierarchy of beats: subtle selection tick, impact confirmation, round
result, settlement reveal, and rare celebration. The largest audio/haptic/motion
combination is reserved for genuinely scarce outcomes.

## Visible States

Ambient, interactive, committed, impact, success/failure, reward count-up,
celebration, skipped, muted, haptics-off, and reduced-motion states must remain
visually understandable.

### Grand Prix Dash racing feedback [BUILT]

Grand Prix uses interpolated car poses, wheel/body steering, cached circuit
scenery and bounded tyre marks, smoke, sparks and speed streaks. The camera
stays anchored through corners; speed zoom and brief impact shake are optional
effects. Clean exits/passes and lap splits give short feedback moments, while
new circuit mastery stamps appear in the existing staged race result and XP
reveal. These visual moments do not calculate additional XP or coins.
Rivals hold lanes through straights and change lanes gradually; straight-line
body tilt is capped so the scroller projection does not exaggerate normal
steering into sideways motion. The compact left HUD omits direction/distance
guidance, leaving rival information and relevant race alerts.
Cars and livery previews use a shared 75% scale on both axes. Car glow, spin
rings and tyre/ERS/tow effects follow that scale; HUD text and control hit
areas retain their accessible sizes.

Original engine low/high bands crossfade by RPM/load with quieter wind and tyre
layers. The shared controller keeps global mute, and active-race ownership
prevents an old route from stopping a retry's audio. Pause/background stops
racing layers and releases inputs; resume keeps the race state and uses a
cancel-safe three-second countdown. Platform reduced motion skips the start
reaction, resume countdown and result animation. Saved reduced effects remove
marks, particles, shake and speed zoom; race haptics can be disabled separately.
See [Grand Prix Dash](../games/grand-prix-dash.md) for the driving and mastery
rules, persistence migration and verification references.

## Persistence

Tennis persists its sound, music, haptic, flash, and reduced-motion settings in
the tennis profile. Platform reduce-animation preferences are read at runtime by
shared/participating surfaces. Reward persistence belongs to settlement systems.

## Planned Scope and Current Limitations

- **BUILT:** Shared audio controller/cue mappings, broad event haptics, multiple
  celebration hosts, skip-safe settlements, platform and mode reduced-motion paths.
- **PLANNED:** Reduced-motion and setting coverage is not yet centralized across
  every mode; new motion must define its accessible fallback and test evidence.

## Implementation References

- [`lib/utils/sound_effects.dart`](../../../lib/utils/sound_effects.dart)
- [`lib/widgets/cyber/cyber_game_launch_card.dart`](../../../lib/widgets/cyber/cyber_game_launch_card.dart)
- [`lib/widgets/cyber/game_launch_art.dart`](../../../lib/widgets/cyber/game_launch_art.dart)
- [`lib/utils/game_audio_mappings.dart`](../../../lib/utils/game_audio_mappings.dart)
- [`lib/widgets/streak_celebration_host.dart`](../../../lib/widgets/streak_celebration_host.dart)
- [`lib/widgets/achievement_unlock_celebration.dart`](../../../lib/widgets/achievement_unlock_celebration.dart)
- [`lib/screens/tennis/tennis_match_screen.dart`](../../../lib/screens/tennis/tennis_match_screen.dart)
- [`docs/audio/CUE_CATALOG.md`](../../audio/CUE_CATALOG.md)

## Tests

- [`test/audio_controller_test.dart`](../../../test/audio_controller_test.dart)
- [`test/cyber_game_launch_card_test.dart`](../../../test/cyber_game_launch_card_test.dart)
- [`test/grand_prix_presentation_test.dart`](../../../test/grand_prix_presentation_test.dart)
- [`test/game_audio_mappings_test.dart`](../../../test/game_audio_mappings_test.dart)
- [`test/basketball_action_cue_test.dart`](../../../test/basketball_action_cue_test.dart)

Match Trending uses manual carousel navigation, brief 120ms press scaling, keyboard focus and selection haptics. Editorial borders never pulse. Sport-quiz artwork retains the shared discovery renderer’s reduced-motion, route/offscreen and lifecycle shutdown behavior.


### Match discovery card entrance

Cards enter once when at least 8% visible: 420ms easeOutCubic, opacity 0 to 1, translation 12px to 0, and the short signal rail extends from 20% to full width. Viewport bands stagger by 48ms, capped at three bands. Motion pauses offscreen, on inactive routes/pages and in the background. Reduced motion shows the final pose immediately. Stable card identities retain the entered state when returning; focus or press settles the entrance immediately so navigation never waits. This adds no ambient border pulse or audio.
