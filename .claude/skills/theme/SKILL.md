---
name: theme
description: >
  Step-by-step guide for designing and building UI in the StatOz Flutter app
  (the Pitch Duel card game lives inside it). Use when creating or editing any
  screen or widget under lib/ — covers the dark theme, AppTheme/Cyber
  color/gradient/text tokens, scaffold + appbar layout, reusable cyber widgets,
  BlocBuilder state rendering, spacing, and assets. Follow it so new UI matches
  the existing look and feel. Pair with the cyber-ui skill for the aesthetic
  rules (glow, shape language, component catalog).
---

# Theme — StatOz UI build guide

StatOz is a **dark-mode-only** app (the Pitch Duel card game lives inside it). All visual
values come from `AppTheme` / `Cyber` in
[lib/config/theme.dart](../../../lib/config/theme.dart). Never hardcode a raw `Color(...)`,
`TextStyle(...)`, or inline gradient when a token already exists — match the existing look
exactly.

> **This skill owns the *build mechanics* (where files go, how to scaffold, which tokens to
> pull, how to render BLoC state, how to verify).** For the *aesthetic* decisions — the glow
> rule, the diagonal corner-cut shape language, which component to reach for and how to make
> it look hand-designed — **invoke the `cyber-ui` skill.** Use both together on any visual
> change; this one tells you how to assemble the screen, `cyber-ui` tells you how to make it
> look right.

## The 7 steps

```
- [ ] 1. Decide screen vs widget; create the file in the right folder
- [ ] 2. Scaffold the layout (Scaffold / background / page chrome)
- [ ] 3. Apply theme tokens (colors, gradients, text styles)
- [ ] 4. Add spacing, padding, and reuse existing cyber widgets
- [ ] 5. Wire data with BlocBuilder (loading / error / empty / loaded)
- [ ] 6. Wire interactions (buttons, navigation, snackbars, haptics)
- [ ] 7. Run flutter analyze, confirm in-app, check against cyber-ui
```

### Step 1 — File location

- Full screen → `lib/screens/<feature>/<name>_screen.dart`
  (e.g. [lib/screens/home/home_screen.dart](../../../lib/screens/home/home_screen.dart)).
- Feature-scoped widget → `lib/screens/<feature>/widgets/<name>.dart`.
- App-wide reusable widget → `lib/widgets/<name>.dart`; shared cyber/HUD components live
  under [lib/widgets/cyber/](../../../lib/widgets/cyber/).

Use `StatelessWidget` by default. Use `StatefulWidget` only when you need
`initState`/controllers/local UI state. Always `const` constructors with `super.key`.

### Step 2 — Scaffold & layout

- Wrap pages in a Material `Scaffold`. The global `scaffoldBackgroundColor` is
  `AppTheme.backgroundPrimary`, so a plain dark page needs no extra background.
- For an atmospheric page, wrap the body in `CyberBackground` (textured grid + scanlines +
  vignette), or drop a `CyberTextureOverlay` into a `Stack` above a custom background. Both
  are in [cyber_widgets.dart](../../../lib/widgets/cyber/cyber_widgets.dart) — reuse them
  instead of a flat `Container`.
- Page chrome (header bar / back) uses `GameScaffold` / `ReactHeaderBar`
  ([game_scaffold.dart](../../../lib/widgets/game_scaffold.dart)), not the Material `AppBar`.
- Standard list content padding is `EdgeInsets.fromLTRB(16, 16, 16, 8)`; use multiples of
  4/8 elsewhere.
- For the diagonal corner-cut silhouette these surfaces use, see the **cyber-ui** skill
  (shape language) rather than rolling your own clipper.

### Step 3 — Theme tokens (`AppTheme` / `Cyber`) — THE IMPORTANT ONE

Everything visual is tokenized in [lib/config/theme.dart](../../../lib/config/theme.dart).
`AppTheme` is the source of truth; `Cyber` is a **thin compatibility facade over `AppTheme`**
(`Cyber.bg == AppTheme.backgroundPrimary`, etc.) — same system, two views. Reach for whichever
reads cleaner at the call site, but never invent a raw value.

**Colors** — `AppTheme.*` constants, e.g. `backgroundPrimary`, `backgroundSecondary`,
`textPrimary`, `border`, `slate800`, `textMedium`, `yellowColor`, `dangerColor`, `green700`,
`matchesLabel`, `pickLabel`, `gamesLabel`. Or the `Cyber.*` aliases: `bg`, `bg2`, `card`,
`panel`, `cyan` (primary), `magenta`, `gold`, `amber`, `success`, `danger`, `violet`, plus
line/border tokens (`border`, `line`, `borderSubtle`, `borderActive`, `muted`). Apply opacity
with `AppTheme.textPrimary.withValues(alpha: 0.26)`.

**Gradients** — use the `AppTheme` getter that matches the surface:

```dart
Container(
  decoration: BoxDecoration(
    gradient: AppTheme.predictionCardGradient,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppTheme.border),
  ),
)
```

Available getters include `backgroundGradient`, `questionCardGradient`, `quizCardGradient`,
`xpGradient`, `predictionCardGradient`, `appBarGradient`, `matchesGradient`, `gamesGradient`,
`profileGradient`, `wagerPlacedGradient`, plus `Cyber.panelGradient([accent])` for clipped
cyber panels.

**Text** — never build a `TextStyle` from scratch. Pull from the theme's `textTheme` and
`copyWith` only what differs:

```dart
Text(
  title,
  style: AppTheme.darkTheme.textTheme.titleLarge?.copyWith(fontSize: 22),
)
```

…or use the helpers for one-off styles: `Cyber.display(size)`, `Cyber.body(size)`,
`Cyber.label(size)`. **Fonts: there are only two.** The text theme is rebuilt by
`Cyber.buildTextTheme`, so every `display*` / `headline*` / `title*` / `label*` family is
**Orbitron** (`Cyber.displayFont` — condensed display, used for brand/headers/labels/numbers)
and every `body*` family is **Onest** (`Cyber.bodyFont` — running text). There is **no** Plus
Jakarta Sans. Use Orbitron + `FontFeature.tabularFigures()` for all numbers (scores, XP,
timers, coins), and UPPERCASE + generous `letterSpacing` for labels/headers. Open
[lib/config/theme.dart](../../../lib/config/theme.dart) for the exact per-style sizes rather
than guessing.

### Step 4 — Spacing & reusable widgets

- Gaps: `const SizedBox(height: 8)` / `width: 8` (multiples of 4/8). List separators:
  `separatorBuilder: (_, __) => const SizedBox(height: 8)`.
- **Reuse cyber components before building anything new**
  ([cyber_widgets.dart](../../../lib/widgets/cyber/cyber_widgets.dart)):
  - Buttons / CTAs → `HudCtaButton` (hero, animated glow border) or `CyberCtaButton`
    ([cyber_cta_button.dart](../../../lib/widgets/cyber/cyber_cta_button.dart)).
  - Surfaces → `CyberPanel`. Meters / XP / progress → `CyberProgressBar` (the one true bar).
  - Also `CyberChip`, `HudLine` (divider), `SectionLabel`, `PremiumCardShell`,
    `CyberSegmentedTabs`
    ([cyber_segmented_tabs.dart](../../../lib/widgets/cyber/cyber_segmented_tabs.dart)),
    `showCyberConfirmDialog`.
  - If a pattern repeats 2+ times, extract it into `cyber_widgets.dart` rather than duplicate.
- Assets: reference directly via `Image.asset('assets/...')` with an `errorBuilder` fallback
  to a `Cyber.*` icon so a missing file never crashes. Assets are declared in `pubspec.yaml`.
  Use `flutter_svg` for SVG and `lottie` for animations where already in use.
- **Which** component to pick, and whether it should glow, is a cyber-ui call — defer to that
  skill (esp. THE GLOW RULE: glow = live/selected/primary, and it's scarce).

### Step 5 — Rendering data with BlocBuilder

State is managed with `flutter_bloc` (BLoC + Cubit). Blocs live in
[lib/blocs/](../../../lib/blocs/) (e.g. `game_bloc`, `picks_cubit`, `prediction_cubit`).
Render every state explicitly:

```dart
BlocBuilder<FooBloc, FooState>(
  builder: (context, state) {
    if (state is FooLoadingState) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state is FooErrorState) {
      return Center(child: Text('Error: ${state.error}'));
    }
    if (state is FooLoadedState) {
      if (state.items.isEmpty) {
        return const Center(child: Text('No data'));
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) => ItemCard(item: state.items[index]),
      );
    }
    return const SizedBox.shrink();
  },
)
```

- Trigger initial loads from `initState` via
  `WidgetsBinding.instance.addPostFrameCallback((_) => context.read<FooBloc>().add(...))`.
- Use `context.watch<FooBloc>().state` only when the whole `build` depends on it; otherwise
  prefer `BlocBuilder` to scope rebuilds; use `BlocListener` for side-effects (snackbars,
  navigation, celebrations).
- Loading uses a themed `CircularProgressIndicator` (`textPrimary`). A custom cyber loader is
  an open follow-up in cyber-ui — match whatever surrounding screens already do.

### Step 6 — Interactions

- **Navigation is imperative** — `Navigator.push(context, MaterialPageRoute(builder: (_) =>
  const FooScreen()))` and `Navigator.pop(context)`. There is **no** `go_router` / `context.go`
  in this app.
- Dispatch events: `context.read<FooBloc>().add(const SomeEvent());`.
- Feedback: stock `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` (a custom cyber
  snackbar is an open cyber-ui follow-up). Add `HapticFeedback` on meaningful taps for
  game-feel.

### Step 7 — Verify

- Run `flutter analyze <changed files>` — must be clean before a change is done.
- For visual changes, confirm in the running app (`/run`), not just analyze.
- **Re-check against cyber-ui:** glow scarcity (one focal element), corner-cut shape applied
  consistently, palette discipline (don't spread the whole neon set at equal weight).

## Conventions checklist (every UI change)

- [ ] No raw `Color(...)` / `TextStyle(...)` / inline gradient where an `AppTheme` / `Cyber`
      token exists
- [ ] Text styles come from `AppTheme.darkTheme.textTheme.*` (+ `copyWith`) or
      `Cyber.display/body/label`; fonts are Orbitron (display) + Onest (body) only
- [ ] Numbers use `FontFeature.tabularFigures()`; labels UPPERCASE + letterSpacing
- [ ] `const` constructors and widgets wherever possible
- [ ] Spacing in multiples of 4/8; list padding `fromLTRB(16, 16, 16, 8)`
- [ ] All BLoC states handled: loading, error, empty, loaded
- [ ] Reused existing cyber widgets (`HudCtaButton`, `CyberPanel`, `CyberProgressBar`,
      `CyberSegmentedTabs`, dialogs) instead of re-building
- [ ] Navigation via `Navigator.push` / `MaterialPageRoute` (no `go_router`)
- [ ] Glow / shape / component choices checked against the **cyber-ui** skill
- [ ] `flutter analyze` is clean
```
