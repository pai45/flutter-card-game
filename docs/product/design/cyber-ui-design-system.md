# Cyber UI Design System

> **Status:** BUILT
> **Last verified:** 2026-08-09
> **Scope:** Theme tokens, typography, shape language, glow hierarchy, layout, and shared cyber components

## Product Purpose

The Cyber UI system gives StatOz/Pitch Duel a coherent esports HUD identity:
dark, information-dense, energetic, and readable, with strong hierarchy that
keeps the primary game action unmistakable.

## Where It Lives

Core tokens live in `AppTheme` and `Cyber`; shared layout and component patterns
live in `GameScaffold` and `lib/widgets/cyber/`. Product screens should compose
these primitives before creating new visual widgets.

## Player Flow

The design system supports a consistent visual sequence: atmospheric scaffold,
HUD identity and resources, focused content panel, one primary live action,
clear state/result feedback, and a reward/next-action handoff.

## Mechanics and Rules

- Dark theme only; use `AppTheme`/`Cyber` tokens rather than raw screen-local colors.
- Orbitron is the display/HUD face; Onest is the body and utility face. Numeric
  HUD values use tabular figures where comparison matters.
- Panels are flat and layered with chamfered/diagonal corner cuts; avoid generic
  rounded white cards and excessive pills.
- Cyan is the dominant live/action signal; gold identifies rewards; red signals
  danger/failure; violet is reserved for elite/special rarity.
- **Glow rule:** glow means live, selected, primary, or a genuine moment. Keep it
  scarce; inactive secondary content should not glow.
- Reuse `GameScaffold`, `CyberPanel`, `CyberProgressBar`, `HudCtaButton`,
  `CyberCtaButton`, and `CyberSegmentedTabs`. If a visual pattern repeats, extend
  the shared cyber catalog rather than duplicate it.

## Rewards and Progression

Progression uses explicit meters, level/rank chips, and before/after movement.
Rewards use gold/rarity hierarchy and reveal staging. Cosmetic ownership and
selection remain distinguishable from affordability and primary action.

## Gratification and Feedback

Selected/live controls may pulse or glow; confirmations get contained impact;
round and reward moments can temporarily expand the visual hierarchy. Ambient
effects stay behind content and must not flatten every state into equal intensity.

## Visible States

Shared components must support default, focused/selected, pressed, disabled,
locked, loading, success, danger, reward, and reduced-motion-safe variants
without losing labels or contrast.

## Persistence

Theme tokens and components are code-level contracts rather than player data.
Selected cosmetics and mode settings persist through their owning systems; a
widget must not become the authoritative store for durable state.

## Planned Scope and Current Limitations

- **BUILT:** Tokenized dark palette, Orbitron/Onest typography, chamfer language,
  cyber scaffolds/panels/progress/CTA/tab components, and established HUD patterns.
- **PLANNED:** Add a new shared primitive only after verifying no current
  component can be extended; update this page when the public component contract changes.

## Implementation References

- [`lib/config/theme.dart`](../../../lib/config/theme.dart)
- [`lib/widgets/game_scaffold.dart`](../../../lib/widgets/game_scaffold.dart)
- [`lib/widgets/cyber/cyber_widgets.dart`](../../../lib/widgets/cyber/cyber_widgets.dart)
- [`lib/widgets/cyber/cyber_cta_button.dart`](../../../lib/widgets/cyber/cyber_cta_button.dart)
- [`lib/widgets/cyber/cyber_segmented_tabs.dart`](../../../lib/widgets/cyber/cyber_segmented_tabs.dart)

## Tests

Component behavior is exercised by screen/widget tests linked from the owning
feature pages. Visual changes also require running-app review under the project
instructions; documentation-only edits do not.
