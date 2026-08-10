# Tutorials, How to Play, and Support

> **Status:** BUILT
> **Last verified:** 2026-08-09
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
  Talk to StatOz profile surface.
- **PLANNED:** Every newly shipped mode should add or explicitly waive tutorial
  and guide coverage; no automated content synchronization exists.

## Implementation References

- [`lib/widgets/tutorial.dart`](../../../lib/widgets/tutorial.dart)
- [`lib/config/tutorial_steps.dart`](../../../lib/config/tutorial_steps.dart)
- [`lib/screens/how_to_play/how_to_play_hub_screen.dart`](../../../lib/screens/how_to_play/how_to_play_hub_screen.dart)
- [`lib/screens/how_to_play/how_to_play_screen.dart`](../../../lib/screens/how_to_play/how_to_play_screen.dart)
- [`lib/screens/profile/talk_to_statoz_screen.dart`](../../../lib/screens/profile/talk_to_statoz_screen.dart)

## Tests

No dedicated tutorial/How to Play test file is currently present. Participating
mode widget tests provide indirect navigation coverage; new help behavior should
add targeted tests.
