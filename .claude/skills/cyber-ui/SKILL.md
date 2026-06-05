---
name: cyber-ui
description: >
  Design-system guide for building or restyling UI in this Flutter game (Pitch
  Duel). Use whenever adding/editing screens, widgets, cards, dialogs, meters,
  buttons or any visual element, or when asked to make the app feel more
  cyberpunk / esports-HUD / "less AI-generated". Encodes the palette, type,
  shape language, shared components and the design RULES (esp. the glow rule).
---

# Cyber UI — Pitch Duel design system

Premium dark **esports / cyberpunk HUD** aesthetic: neon-on-near-black, angular
clipped silhouettes, condensed display type, scarce intentional glow. The goal
is for new UI to look hand-designed and consistent — not like a uniformly-styled
template.

## North star: what makes it NOT feel AI-generated
1. **Hierarchy through scarcity, not uniformity.** Don't apply the same glow /
   gradient / radius to everything. One focal element per screen; everything
   else is calmer. Uniform treatment is the #1 "generated" tell.
2. **Texture over flat.** Pure flat dark gradients read as generated. Prefer
   grid/scanline/noise/vignette atmosphere (see `CyberBackground`).
3. **Asymmetry & data density.** Avoid the default centered column of buttons.
   Use off-grid HUD layouts, corner ticks, and "greeble" telemetry (IDs, coords,
   version strings, `//` prefixes) — the cyberpunk signature.
4. **Color discipline.** Cyan is dominant; magenta is the hot secondary. Gold =
   rewards only, red/danger = danger only, success = wins only, violet = elite.
   Don't spread the whole neon palette at equal weight.
5. **No stock Material look.** Replace default `SnackBar`, `CircularProgress-
   Indicator`, and bare `TextButton` ripples with the custom components below.

## THE GLOW RULE (most important; enforce on every change)
A glow means **"this is live / selected / primary / it matters."** It must be
**scarce**. See [theme.dart](../../../lib/config/theme.dart) `Cyber.glow(...)`.

- **DO glow:** primary CTAs, the selected/active item, the user's own row/card,
  LIVE badges, the champion/#1, hero headline text, "moment" screens (goal,
  win, pack reveal, level-up).
- **DON'T glow:** plain surfaces/panels, secondary chips/pills, dividers,
  static stat blocks, list rows that aren't "you", non-champion podium places,
  persistent chrome.
- **Always-on secondary elements never glow.** If it's always on screen and not
  interactive/active, it gets depth from fill + border + gradient, not shadow.
- Use the single source `Cyber.glow(color, {alpha, blur, spread})` so glows stay
  consistent. Gate it: `boxShadow: active ? Cyber.glow(accent) : null`.
- `CyberPanel` glow is **opt-in** (`glow: false` default). Set `glow: true` only
  on the one focal panel per screen.

## Palette — use `Cyber.*` constants ([theme.dart](../../../lib/config/theme.dart)), never raw hex
- Surfaces: `bg` `bg2` `card` `panel` `panel2` (near-black blue-greys).
- Accents: `cyan` (primary), `magenta` (hot), `violet` (elite), `gold` (reward/
  score), `amber`, `lime`/`success` (good), `danger`/`red` (bad).
- Lines/text: `line`, `borderSubtle`, `borderActive`, `muted`.
- Surfaces never glow on their own; the accent enters via `panelGradient(accent)`
  and a `border` at ~0.5 alpha.

## Typography ([theme.dart](../../../lib/config/theme.dart))
- `displayFont` = **Orbitron** (condensed display) — headlines, labels, numbers,
  buttons. `bodyFont` = **Onest** — running text.
- Helpers: `Cyber.display(size)`, `Cyber.body(size)`, `Cyber.label(size)`.
- Use `FontFeature.tabularFigures()` for all numbers (scores, XP, timers, %).
- UPPERCASE + generous `letterSpacing` (1.2–2.8) for labels/headers.
- Improvement opportunity: a **monospace** face for telemetry/data would sharpen
  the HUD feel (no mono is bundled yet — only Onest + Orbitron).

## Shape language
- **Diagonal corner cut** is the signature. Use `CyberClipper` (bottom-corner
  chamfer) from [cyber_widgets.dart](../../../lib/widgets/cyber/cyber_widgets.dart)
  for panels/cards; `_HudButtonClipper` (4-corner chamfer) for buttons.
- Prefer the chamfer (or corner brackets) over plain rounded rects. Keep radii
  small (0–3) elsewhere. Apply the cut consistently so it reads as a motif.

## Shared components — REUSE these, don't reinvent
From [cyber_widgets.dart](../../../lib/widgets/cyber/cyber_widgets.dart):
- `CyberBackground` — full textured page background. Composes a static
  `CyberGridPainter` (base fill + blueprint grid) + a `CyberTextureOverlay`
  (scanlines + grain + vignette) + an optional drifting radial glow
  (`animated: true`) + the child. Reuse instead of a flat `Container`/bg.
- `CyberTextureOverlay({vignette})` — transparent overlay of the shared HUD
  texture (CRT scanlines + tiled film-grain + optional edge vignette) for
  screens that draw their OWN background (home stadium, shop). Drop into a Stack
  above the bg, below content: `const Positioned.fill(child: CyberTextureOverlay())`.
  Grain is a procedural noise tile generated ONCE and cached app-wide
  (`_loadCyberNoise`, 256px, additive `BlendMode.plus`). Texture always sits
  BEHIND content. Tunables live in `_buildCyberNoise` (grain `nextInt`) and
  `_paintCyberTexture` (scanline alpha, vignette).
- `CyberPanel(accent, glow, padding)` — standard clipped surface. `glow` off by default.
- `CyberProgressBar(value, accent, height, radius, animate, trackColor, trackBorderColor)`
  — the one true meter/XP/rank/power bar. Smooth flow gradient (full colour by
  ~70%, bright leading edge), subtle glow, glossy sheen. Use for ALL progress bars.
- `CyberChip`, `HudLine` (divider), `SectionLabel`, `PremiumCardShell`
  (hover/selected/disabled card shell), `CyberPlayerCardTile`, `CyberActionCardTile`,
  `showCyberConfirmDialog`.
- CTAs: `HudCtaButton` (hero, animated glow border) and `CyberCtaButton`
  ([cyber_cta_button.dart](../../../lib/widgets/cyber/cyber_cta_button.dart)).
- Page chrome: `GameScaffold` / `ReactHeaderBar` ([game_scaffold.dart](../../../lib/widgets/game_scaffold.dart)).
- `CyberSegmentedTabs(tabs, activeIndex, onTap)` + `CyberTab(label, icon)`
  ([cyber_segmented_tabs.dart](../../../lib/widgets/cyber/cyber_segmented_tabs.dart))
  — top tab bar (e.g. MATCHES / PICK / GAMES). Calm dark bar; the ACTIVE tab is
  the one focal element: a raised, glowing cyan trapezoid (square top, chamfered
  bottom) that dips below the bar baseline, dark-ink icon + label on it, others
  muted. `CyberTab.icon` is an `(color, size) => Widget` builder so active/inactive
  tint stays centralised (use `Icon` or a `CustomPaint` for non-Material glyphs).

## Workflow for new/changed UI
1. Reuse a shared component above before building new. If a pattern repeats 2+
   times, extract it into `cyber_widgets.dart` (as was done for `CyberProgressBar`).
2. Pull colours/type from `Cyber.*`; never hardcode hex or `TextStyle` families.
3. Apply the glow rule: pick the single focal element, glow only that.
4. Apply the corner-cut shape language.
5. Keep numbers tabular; labels uppercase + spaced.
6. Run `flutter analyze <changed files>` — must be clean before done.
7. Visual changes: confirm in the running app (`/run`), not just analyze.

## Known follow-ups (track when extending this work)
- Glow-rule sweep DONE on: `theme.dart` (added `Cyber.glow`), `cyber_widgets.dart`
  (`CyberPanel` glow opt-in), `leaderboard_screen.dart`, `shop_screen.dart`
  (coin pill, standard coin tiles, pack tile container), `deck_builder_screen.dart`
  (already compliant), `match_widgets.dart` (scoreboard/digits/VS/slot/edge chrome;
  kept live dot + active round dashes + estimate frame).
- Glow-rule sweep DONE on: `daily_drop.dart` (glow gated on `ready`),
  `starter_pack_onboarding.dart` (`_MysterySlot` calmed; trophy/headline moment
  glows kept), `landing_bottom_navigation.dart` (removed persistent nav-bar
  glow; kept active-tab glow).
- Glow-rule sweep COMPLETE across navigable surfaces. Gameplay "moment" screens
  — `match_phases`, `penalty_phase`, `final_result_phase`, `level_up_celebration`,
  `card_unpack_animation` — are intentionally left glowing by design.
- Texture pass DONE and rolled out via `CyberTextureOverlay`:
  - `CyberBackground` screens (leaderboard, deck, all-cards, match-history, and
    all main match phases via `GameScaffold`/`MatchPhaseScaffold`) — covered.
  - `home` (`_HomeArenaBackground`) and `shop` (`_AnimatedShopBackground`) —
    overlay added on top of their custom backgrounds.
  - Grain tile is 256px; current grain strength is `nextInt(20)` (additive
    `BlendMode.plus`). Halve/double this single value to dim/strengthen grain.
  - Cinematic "moment" screens (toss + kickoff/reveal in `match_phases`) have
    their OWN bespoke grid/scanline treatment — intentionally left untouched.
  - Grain is background-only (not over content/panels). Optional future: a faint
    full-screen grain overlay ABOVE content. If `BlendMode.plus` grain lifts the
    blacks too much, switch to mid-grey noise + `BlendMode.overlay`/`softLight`.
- Add a monospace data font + `Cyber.mono(...)` helper.
- Home screen redesign DONE (point 4): replaced the centered icon/button column
  with an asymmetric HUD — logo emblem + wordmark hero, greeble status strip
  (`SYS://… vX`, live ONLINE dot) and a real-data telemetry row (LEVEL/XP/COINS).
  Every prior feature kept; the `HudCtaButton` PLAY MATCH and its disabled
  wrapper are unchanged; background (`_HomeArenaBackground`) untouched.
  - App logo lives at `assets/icons/app_logo.png` (covered by the existing
    `assets/icons/` pubspec entry — no pubspec edit needed). Load via
    `Image.asset` with an `errorBuilder` fallback to a `Cyber.*` icon so missing
    files never crash. Use this same emblem for any future brand lockup.
  - New home-local HUD patterns worth promoting to `cyber_widgets.dart` if reused
    elsewhere: corner-bracket frame (`_CornerBracketsPainter`), telemetry cell
    (`_HudStat`), flat HUD link (`_HudLink`), status strip (`_LobbyStatusBar`).
- Custom cyber `SnackBar` + loader to replace stock Material (home "Tutorial
  reset" still uses a stock `SnackBar`).
- Prediction quiz (`match_prediction_screen.dart`) is a gamified ONE-question-
  at-a-time flow (not a scrolled list): HUD header (corner brackets + kickoff
  time + team badges + split bar), a "QUIZ LOCKS IN hh:mm:ss" countdown to
  kickoff, a numbered question panel with a violet→cyan XP pill + A/B/C options,
  a progress-segment row (current = amber gradient w/ glow "you are here",
  answered+left = green gradient, pending = slate `#314158`), a docked
  PREVIOUS + NEXT button pair (`_QuizButton` on the `HudChamferClipper`
  silhouette: PREVIOUS = calm dark plate w/ cyan text+←, NEXT = glowing cyan
  focal w/ dark ink+→; final page swaps NEXT → SUBMIT/SETTLE/DONE, SUBMIT
  disabled until all answered), and a full-screen `_SubmittedOverlay`
  celebration (elasticOut tick ring + glow, then fades and pops). The dock
  background fades up into the page (bottom near-black → transparent) rather than
  a hard divider. The same paginated UI doubles as a read-only review when
  locked/finished (settled answers show correct/wrong). Patterns worth promoting
  if reused: `_CornerBracketsPainter` (HUD corner ticks) and `_QuizButton` (an
  arrow-aware HUD button on `HudChamferClipper`).
