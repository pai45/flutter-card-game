# Cyber UI Design System

> **Status:** BUILT
> **Last verified:** 2026-09-07
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
- **PLANNED:** Standard boxes, panels, and cards use opposing diagonal cuts at the
  top-left and bottom-right; the top-right and bottom-left remain square. Two clipped
  bottom corners are not the reference silhouette. Specialized buttons, badges, tabs,
  and decorative silhouettes may retain their established geometry.
- **BUILT / LEGACY:** `CyberClipper` and `CyberPanel` still use bottom-left +
  bottom-right cuts. Until the shared primitive and matching border painters are migrated,
  this runtime shape is an implementation mismatch rather than the design precedent.
- Keep panels flat and layered; avoid generic rounded white cards and excessive pills.
- Cyan is the dominant live/action signal; gold identifies rewards; red signals
  danger/failure; violet is reserved for elite/special rarity.
- **BUILT:** Cross-sport identity uses one canonical palette: Football cyan,
  Cricket white, Basketball yellow, Tennis green, and Motorsport red. Sport
  icons keep a subdued form of their own color in inactive tabs; the selected
  sport uses full color and owns the tab's single glowing underline. These
  identity colors do not replace semantic LIVE, reward, danger, rarity, team,
  or game-mode colors.
- **BUILT:** Team identity uses a four-role, competition-scoped palette. The
  supplied `primaryColor`, `secondaryColor`, and `textColor` are reserved for
  exact octagonal logo rendering. `secondaryTextColor` is the full-strength
  team color for names, comparison bars, chart/map marks, timeline rails,
  controls, and avatar frames on dark surfaces; every generated value clears
  WCAG AA (4.5:1) on `Cyber.bg`, `Cyber.card`, `Cyber.panel`, and
  `Cyber.chartSurface`. Translucent team washes are decorative and must be
  paired with a full-strength identity label, marker, or border. LIVE, danger,
  success, reward, and selected-state semantics override team color, and team
  identity never creates a persistent glow.
- **Glow rule:** glow means live, selected, primary, or a genuine moment. Keep it
  scarce; inactive secondary content should not glow.
- **BUILT:** Backgrounds use the calm blueprint grid, scanlines, and optional
  vignette only. Procedural film-grain/noise is retired across every screen so
  match and reward moments stay crisp without visual speckling.
- Reuse `GameScaffold`, `CyberPanel`, `CyberProgressBar`, `HudCtaButton`,
  `CyberCtaButton`, and `CyberSegmentedTabs`. If a visual pattern repeats, extend
  the shared cyber catalog rather than duplicate it.

### Charts — one system

All charts use `lib/widgets/cyber/cyber_chart.dart`. There is no charting
package; the app draws its own.

- `CyberChartPanel` is the whole treatment: a flat `Cyber.chartSurface` panel
  with a cyan section label, an optional range switcher, a scrubbable plot, an
  expand button, and a legend. Dragging it moves a dashed playhead with selection
  haptics; the legend reads every series at that point plus a caller-supplied
  context label (a minute, an over, a game clock). The expand button pushes
  `CyberChartFullScreen` with the same plot.
- `ChartSeries` is one line: values, colour, an optional gradient `fill`, and a
  `readout(value, index)` so a series can label itself from a parallel list.
- `ChartMarker` pins a moment (goal, wicket, lead change) to the plot as a dot,
  diamond or ring. Only the `focal` marker draws a full-height rule — a dense
  marker set otherwise reads as a cage.
- `CyberChartPainter` handles the grid, the optional `signed` two-sided baseline,
  the step/linear interpolation, the reveal sweep and the playhead. Set
  `percentScale` for a probability axis (pinned 0–100); everything else scales to
  its own data and never pads an all-positive series below zero.
- Per the glow rule a chart panel is calm; `glow` is set only while the reveal
  sweep runs.

### Data-page furniture

Data-dense pages (pick market detail, match STATS) share:
`CyberSectionHeading` (label + hairline rule) instead of a per-section telemetry
panel, `CyberMiniMetric` (small KPI cell), `CyberStatPill` (tinted outline token),
`CyberDeltaChip` (▲/▼ movement), and — for match reports —
`MatchPulseHeader`, `StatsRowShell` and `StatComparisonRow` from
`lib/screens/predictions/widgets/match_stats_shell.dart`. A contested home-vs-away
split uses two flat colour segments, not two progress meters: a static stat block
gets its depth from fill, never a sheen.

Persistent search uses the shared `CyberSearchField`: a calm 56 px rectangular
panel with one cyan outline, no glow, and no nested filled input or clipped
corners. Chamfers remain reserved for cards, panels, and action controls; the
plain search silhouette prioritizes a clean typing target.

## Rewards and Progression

Progression uses explicit meters, level/rank chips, and before/after movement.
Rewards use gold/rarity hierarchy and reveal staging. Cosmetic ownership and
selection remain distinguishable from affordability and primary action.

## Gratification and Feedback

Selected/live controls may pulse or glow; confirmations get contained impact;
round and reward moments can temporarily expand the visual hierarchy. Ambient
effects stay behind content and must not flatten every state into equal intensity.

## Visible States

`HudCtaButton` supports an opt-in `outlined` secondary treatment: flat panel
fill with accent text, paired with `glow: false`. Account entry uses this for
Google preview and supplies tokenized `labelStyle` values to both actions.
Existing callers keep their original fill and inherited label styling.

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
- **PLANNED:** Migrate the shared standard panel/card primitive from two bottom cuts to
  the top-left + bottom-right silhouette, including every painter that traces its border.
- **PLANNED:** Add a new shared primitive only after verifying no current
  component can be extended; update this page when the public component contract changes.

## Implementation References

- [`lib/config/theme.dart`](../../../lib/config/theme.dart)
- [`lib/widgets/game_scaffold.dart`](../../../lib/widgets/game_scaffold.dart)
- [`lib/widgets/cyber/cyber_widgets.dart`](../../../lib/widgets/cyber/cyber_widgets.dart)
- [`lib/widgets/cyber/cyber_cta_button.dart`](../../../lib/widgets/cyber/cyber_cta_button.dart)
- [`lib/widgets/cyber/cyber_segmented_tabs.dart`](../../../lib/widgets/cyber/cyber_segmented_tabs.dart)
- [`lib/widgets/cyber/cyber_chart.dart`](../../../lib/widgets/cyber/cyber_chart.dart)
- [`lib/data/team_palettes.dart`](../../../lib/data/team_palettes.dart)
- [`lib/widgets/team_logo.dart`](../../../lib/widgets/team_logo.dart)
- [`lib/screens/predictions/widgets/match_stats_shell.dart`](../../../lib/screens/predictions/widgets/match_stats_shell.dart)

## Tests

Component behavior is exercised by screen/widget tests linked from the owning
feature pages; the shared chart system has its own
[`test/cyber_chart_test.dart`](../../../test/cyber_chart_test.dart). Visual changes also require running-app review under the project
instructions; documentation-only edits do not.
