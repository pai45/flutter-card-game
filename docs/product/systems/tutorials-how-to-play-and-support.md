# Tutorials, How to Play, and Support

> **Status:** BUILT
> **Last verified:** 2026-10-04
> **Scope:** Contextual tutorials, rules/help hub, per-mode guides, and Talk to StatOz support entry

## Product Purpose

Help should get players back to fun quickly. Contextual tutorials explain the
next interaction, How to Play provides an intentional reference library, and
support offers an escape hatch when rules or account state remain unclear.

## Where It Lives

Tutorial overlays are configured and invoked by participating game screens.
The How to Play hub links to mode guides. Profile exposes Talk to StatOz.

## Player Flow

1. Encounter a new mode or request help.
2. Read a short contextual step or select a mode guide.
3. Advance/skip tutorial steps without changing gameplay settlement.
4. Return to play, or open the support surface for unresolved questions.

## Mechanics and Rules

Tutorial steps define target copy and ordering. Completion/dismissal controls
repeat behavior where a mode wires persistence. How to Play is explanatory and
must follow implemented mechanics; it does not override game code.

Talk to StatOz provides direct Bug, Feature Request, Score / Data Mismatch, and
Shoutout channels. The same screen includes a Follow Us On panel for Instagram,
Reddit, and YouTube, keeping the community destinations visible without
competing with the support actions.

### Pitch Duel clarity [BUILT]

Briefing lists matching actions and +6. Card details and deck selection explain
each affinity's +4, and RESERVED labels explain later-role coverage. Play/help
copy describes one-use cards for both sides, two additive combinations, higher
total resolution and exact-tie coin flips. Inactive fouls/red-card risks and old
accuracy/bypass promises are removed from visible football card descriptions.
The shot-meter tutorial pauses the 900 ms sweep until dismissed. Returning
players keep their seen flags and take the faster one-second briefing path;
first-time guidance remains skippable. The full guide explains draws and the
separate Penalty Shootout mode. `pitch_duel_presentation_test.dart` directly
checks pause and layout behavior.

### Spotlight visibility and lifecycle [BUILT]

The shared spotlight uses a root overlay entry, leaving the source route visible.
Bounds include transforms and are measured after layout/scrolling in overlay
coordinates. Overlapping clear regions are unioned, so they cannot become dark
again. Highlighted controls receive real taps; surrounding controls are blocked.
Only one spotlight can exist per overlay. The owner cancels it when disabled or
disposed, and no full-screen dim is painted before valid target bounds exist.
When the same coach widget is reused by the next phase, it cancels the old entry
and schedules the new tutorial identity, rather than inheriting a completed flag.
Pitch Duel play guidance follows player → action → power/COMMIT, showing full
scrollable copy. Existing seen flags and skip persistence remain intact.

## Rewards and Progression

Help surfaces do not directly award XP or coins. Their payoff is lower friction,
faster mastery, and fewer accidental losses/spends.

## Gratification and Feedback

Focused highlights, short steps, progress markers, skip/continue controls, and
return-to-action transitions preserve momentum. Help avoids excessive glow and
does not compete with live game moments.

## Visible States

First-step, intermediate, final, skipped/completed, mode selection, guide detail,
and support-contact states are represented.

## Persistence

Tutorial completion is mode-dependent. Static guide content does not need user
state; support delivery depends on the current Talk to StatOz implementation.

## Planned Scope and Current Limitations

- **BUILT:** Shared tutorial widget/config, How to Play hub/detail screens, and
  Talk to StatOz profile surface with four support channels and Instagram,
  Reddit, and YouTube follow options.
- **PLANNED:** Every newly shipped mode should add or explicitly waive tutorial
  and guide coverage; no automated content synchronization exists.

## Implementation References

- [`lib/widgets/spotlight_walkthrough.dart`](../../../lib/widgets/spotlight_walkthrough.dart)
- [`lib/widgets/tutorial.dart`](../../../lib/widgets/tutorial.dart)
- [`lib/config/tutorial_steps.dart`](../../../lib/config/tutorial_steps.dart)
- [`lib/screens/how_to_play/how_to_play_hub_screen.dart`](../../../lib/screens/how_to_play/how_to_play_hub_screen.dart)
- [`lib/screens/how_to_play/how_to_play_screen.dart`](../../../lib/screens/how_to_play/how_to_play_screen.dart)
- [`lib/screens/profile/talk_to_statoz_screen.dart`](../../../lib/screens/profile/talk_to_statoz_screen.dart)

## Tests

`test/spotlight_walkthrough_test.dart` checks visible scaled/overlapping cutouts,
tap routing, scrolling, disposal and phase-identity reuse.
`test/pitch_duel_presentation_test.dart` checks the Pitch Duel meter tutorial pause.
No dedicated whole-app How to Play test file is currently present. Participating
mode widget tests provide indirect navigation coverage; new help behavior should
add targeted tests.
