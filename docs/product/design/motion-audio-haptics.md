# Motion, Celebrations, Audio, Haptics, and Reduced Motion

> **Status:** BUILT
> **Last verified:** 2026-08-09
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
- [`lib/utils/game_audio_mappings.dart`](../../../lib/utils/game_audio_mappings.dart)
- [`lib/widgets/streak_celebration_host.dart`](../../../lib/widgets/streak_celebration_host.dart)
- [`lib/widgets/achievement_unlock_celebration.dart`](../../../lib/widgets/achievement_unlock_celebration.dart)
- [`lib/screens/tennis/tennis_match_screen.dart`](../../../lib/screens/tennis/tennis_match_screen.dart)
- [`docs/audio/CUE_CATALOG.md`](../../audio/CUE_CATALOG.md)

## Tests

- [`test/audio_controller_test.dart`](../../../test/audio_controller_test.dart)
- [`test/game_audio_mappings_test.dart`](../../../test/game_audio_mappings_test.dart)
- [`test/basketball_action_cue_test.dart`](../../../test/basketball_action_cue_test.dart)
