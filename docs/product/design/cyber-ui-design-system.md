# Cyber UI Design System

> **Status:** BUILT
> **Last verified:** 2026-10-11
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
- **BUILT:** Orbitron is the display/HUD face. Space Grotesk is the body and utility
  face throughout Games, arcade play, rewards, and game-related sections of
  shared pages and real sports Matches, Pick,
  predictions, fixtures, and their details. The canonical typography manifest lives in Designer; `lib/design_system/typography.dart` is its generated local adapter. Numeric HUD values use tabular
  figures where comparison matters.
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
- **BUILT:** Sport and game identity uses the original StatOz 32 x 32 mark
  family in `statoz_icons.dart`: five sport marks and one distinct mark for
  each of the 18 game entries. The marks use a 1.75 px butt-cap, miter-join
  construction and inherit the surrounding identity color. Use them on sport
  selectors, discovery cards, quest/unlock moments, dossiers and other
  identity surfaces. Keep Material icons for actions and live gameplay cues
  such as shoot, defend, lock, search and navigation. Marks are decorative by
  default when an adjacent label already names the sport or game.
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

### Illustrated hub backgrounds [BUILT]

Matches and Games share six original filled isometric worlds: Trending
(collectible/play arena), Football (turf, goal and ball), Cricket (bat, wicket and
clay strip), Basketball (wood court, hoop and ball), Motorsport (raised track and
open-wheel car), and Tennis (blue court, net and racket). Game-card illustrations
inspire the solid forms, faceted shading, material palette and cast shadows;
background scenes are authored independently rather than copied from cards.
Sport identity keeps the canonical accent. Detail lives around the edges.
Artwork remains sharp beneath a pronounced dark navy overlay: a diagonal sweep,
asymmetric edge shading, a deep bottom fade, and strong central coverage.
The centre stays dark behind the feed rather than opening a vibrant window. Broad cyan-tinted diagonal
facets, chamfered navy plates and sparse segmented HUD edge marks make the
overlay subtly cyber at 32% of its original decorative intensity, without glow
or animation. The same source generates
the web CSS, Flutter gradients and bundled transparent overlay SVG. Neither
artwork nor foreground UI is blurred.

The background follows the active tab's resolved sport, including unlock
fallbacks, without resetting either tab's selection or feed scroll. It extends
behind the collapsing header and feed. Navigation, detail pages and gameplay
keep their existing treatment. Worlds crossfade for 240 ms, stay stationary
while browsing, ignore input and semantics, and switch immediately when system
animations are disabled or accessible navigation is enabled. Missing artwork
falls back to the existing navy gradient.

Original SVG geometry and presentation settings are owned by
statoz_web/scripts/hub-background-source. From statoz_web run
`npm run backgrounds:sync -- --flutter-root <card_game checkout>` to explicitly
update both local libraries. Run the same command with `--check` to verify
parity. Each platform builds from its bundled assets without another checkout.
Portrait and wide artwork have separate compositions; the wide breakpoint is
768 logical pixels. CyberHubBackground is exported by the shared cyber catalog.

### Game discovery launch cards [BUILT]

All 18 sport-specific Games entries and the curated Trending game tiles compose
`CyberGameLaunchCard`, exported through the shared cyber catalog. It extends
`ChamferedActionSurface` and `HudChamferClipper` with top-left and bottom-right
cuts (`smallCut: 0`), a flat panel, a quiet accent border, a white Orbitron title,
and a full-width action rail. Landscape hero cards keep the simulation on the
right; narrow Quick Play and tall Trending cards stack the illustration above
the title. Supporting labels are at least 10 px and compact titles at least 15 px.
With text scaled above 1.2x, phone Quick Play grids use one wider column and
Trending uses full-width tiles, retaining full game names and short action labels.

The illustrations are original, filled faceted 2.5D vectors on a 220 × 160 master.
Canonical layered SVGs and normalized motion tracks live in assets/game_discovery.
All 18 games retain their existing AppTheme.game* discovery accents. Natural
equipment colours and a base/shadow/highlight hierarchy give objects volume;
quiet settings, sparse seams and one gameplay cue replace wireframe scaffolding.
Quiz and mystery variants have sport-specific equipment and anonymous portraits.
No athletes, teams, or vehicle liveries imply a real identity or endorsement.

Flutter renders generated SVG layers with flutter_svg. statoz_web receives identical
layers, material tokens, game accents and motion tracks through
node tool/sync-game-discovery.mjs --web <web-root>. Each app runs independently;
--check verifies generated outputs without modifying them. The web also maintains a
local source snapshot for standalone artwork:sync and artwork:check.

Wide cards keep text left and art right; narrow cards place art above copy.
Both use the same badge/title/subtitle/action hierarchy, with contained artwork.
Hover/focus brightens the outline and rail and emphasizes art by 2%; a press
scales to 0.985 over 120 ms. Ambient borders never pulse or glow.

The entire card, action rail, keyboard Enter/Space and accessibility activation
invoke the existing game callback. Existing streak badges and quest lock/choice
veils still carry real progression state. Locked illustrations stay static and
the lock action continues through the existing mission-selection guard. Quick
Play uses challenge/clue/grid labels instead of implying every mode is free.
See [Motion, Audio, Haptics, and Celebration](motion-audio-haptics.md) for the
loop and reduced-motion contract.

### Cyberpunk UI kit — sport access

**BUILT:** Sport unlock sheets use the opt-in [Cyberpunk UI kit](cyberpunk-ui-kit.md).
It combines opposing chamfers, segmented section rules, numbered progression
entries, sport emblems and flat primary/secondary/icon actions. Its shared
`CyberKit` dimensions and motion values accompany the existing theme tokens.
Only an enabled primary action glows; unaffordable unlocks give that emphasis
to VIEW QUESTS. Existing components retain their defaults. The kit implements
the standard opposing cuts without migrating legacy `CyberPanel` callers.

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

### Football card presentation [BUILT]

`CyberPlayerCardTile` selects a football-specific presentation for attacker,
defender and keeper roles (`pitchDuelStyle` can opt out). `CyberActionCardTile`
shares the sci-fi playing-card frame: large corner OVR/power, angular etched
rails, quiet one-to-four rarity inlays, a separate nameplate and affinity glyph.
Players use portrait windows and mirrored lower indices; actions use tactical
blueprint art. Backs use a symmetric circuit print. The frame brightens on
selection, without a check square covering the card's index. Static print has no
continuous foil animation. Numeric indices fit their reserved corner width at
enlarged text; names/ability details retain scoped body typography.

Current-role players are full-size on the board; other-role cards are omitted
from that round's choices. Used/reserved football cards use muted labels through
`PremiumCardShell(calmDisabled: true, showSelectionMarker: false)`, preserving
other sports' existing shell behavior. Fronts/backs use opposing top-left and
bottom-right cuts. `CyberPanel(cornerCuts: true)` applies the same path to clipping
and border painting without migrating unrelated legacy panels.
`PitchContributionStrip` is shared by details and recap; `PitchMasteryPanel` is
shared by the lobby and full time. `PitchVectorArt` provides token tinting and
missing-art fallbacks. Backgrounds/artwork live in `assets/pitch_duel/`; text and
frames remain Flutter-rendered. Game text uses Orbitron display / Space Grotesk body.
The fixed-height `PlayerLevelBadge` fits its numeric stack within the header at
enlarged text, including expanded XP detail, avoiding clipped lobby chrome.

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

- **BUILT:** Tokenized dark palette, scoped Orbitron/Space Grotesk/Space Grotesk typography, chamfer language,
  cyber scaffolds/panels/progress/CTA/tab components, and established HUD patterns.
- **PLANNED:** Migrate the shared standard panel/card primitive from two bottom cuts to
  the top-left + bottom-right silhouette, including every painter that traces its border.
- **PLANNED:** Add a new shared primitive only after verifying no current
  component can be extended; update this page when the public component contract changes.

## Implementation References

- [`lib/config/theme.dart`](../../../lib/config/theme.dart)
- [`lib/widgets/game_scaffold.dart`](../../../lib/widgets/game_scaffold.dart)
- [`lib/widgets/cyber/cyber_widgets.dart`](../../../lib/widgets/cyber/cyber_widgets.dart)
- [`lib/widgets/cyber/cyber_game_launch_card.dart`](../../../lib/widgets/cyber/cyber_game_launch_card.dart)
- [`lib/widgets/cyber/statoz_icons.dart`](../../../lib/widgets/cyber/statoz_icons.dart)
- [`lib/widgets/cyber/game_launch_art.dart`](../../../lib/widgets/cyber/game_launch_art.dart)
- [`lib/screens/predictions/prediction_home_screen.dart`](../../../lib/screens/predictions/prediction_home_screen.dart)
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
Game-card routing/layout is covered by `game_hero_cta_test.dart`,
`final_over_games_tab_test.dart`, and `trending_hub_test.dart`. The shared
`cyber_game_launch_card_test.dart` covers motion shutdown/resume, input routes,
and all schematic variants with enlarged text; `tool/game_cards_preview.dart`
provides an isolated production-widget running-app preview.
`statoz_icons_test.dart` renders every sport and game mark and verifies the
opt-in semantics contract.

The opening Pitch Duel/Penalty Trending pair uses one 300px portrait row, with additional height for increased text scale. Tennis court lines and the raised net share one affine perspective grid, with posts anchored beyond the sidelines.

## Match Trending editorial discovery

Match Trending starts with one manual winner-Pick carousel (football, cricket, basketball, motorsport, extra football), then repeats one sport at a time: two wide fixtures, up to three Event rows, and a paired grid of one standalone sport quiz, one different compact fixture, and up to two free XP quiz missions. Missing records produce partial modules; no filler is created. Gold reveal strips and Futures stay in their dedicated lists.

Football team logos sit above names at the outer edges (home left, away right); the central score owns the hierarchy. Cricket and basketball use stacked left-aligned identities and right-aligned scores. Racing displays available session results, never driver standings as race classification. Events use 14px/500 questions, 12px/400 answers, independent details navigation and signed percentage-point movement. All cards have padded lifecycle/timing areas and complete labels. The revised cadence uses 20px page margins, 16px card padding, 16px match/grid gaps and 24px module gaps. The grid collapses below 360px or at 1.4 text scale.


Match cards omit the bottom action strip and arrow. The full plate remains the match-details target with keyboard focus and press feedback.

Match backgrounds have a quiet 9% tint fading from the top-right: LIVE red; other upcoming followed-team games cyan; ordinary upcoming games dark grey; finished games use a supported winner identity color. Draws, missing results and unavailable winner colors stay neutral. This tint does not animate or tint text/borders. Away identities align to the right card inset.

Outcome rows use the existing team/Draw colors on a contained chamfered percentage button (the price replaces BUY), with contrast-safe ink. Featured cards show at most three outcomes and one compact volume/details footer; full Futures lists retain every candidate.

Web presentation type uses generated rem adapters so increased browser text size scales the actual text. Both discovery and reveal grids collapse below 360px or at 1.4 text scale, including desktop.


### Match discovery HUD refinement

Match discovery now uses etched inner chamfer frames, a short sport-colored top rail, existing sport marks, inset Orbitron score plates, beveled team-colored percentage controls, gold XP reward labels and discrete progress segments from genuine answered-question counts. The navy fill and restrained top-right lifecycle/team tint remain. Lifecycle tabs dock at the top-right frame edge with zero outer inset; their text retains its internal padding. Wide headers reserve the measured tag width, and compact headers reserve height before metadata. Embedded Events dock each row's own lifecycle to its right edge. Event questions remain Space Grotesk 14px/500 and answers 12px/400. No extra match footer was restored.


### Carousel edge spacing · 2026-10-15

Featured Picks scroll through the full feed width, with 20px leading/trailing content insets and the header aligned to page content. Indicators retain their touch targets and sit 4px below the cards. Event percentages retain outcome color and signed movement without an underline. Other feed modules keep their page margins.


Percentage CTAs (2026-10-15): outcome percentage plates fill the outcome row height and dock flush to its right edge, without outer padding. Keep label padding, existing outcome colors, 44px minimum hit areas, disabled/access behavior and matching 6px chamfers. Long labels and increased text scale grow the row and percentage plate together.

Live match context (2026-10-15): available clock/minute context sits next to LIVE inside the flush lifecycle tag (for example LIVE 67′), with no repeated timing line. Missing context leaves LIVE alone; upcoming kickoff and market deadline placement stay authoritative.

Score presentation (2026-10-15): scores render as open Orbitron text, without an inset box, border, fill or box padding, in both mirrored and stacked scoreboards. Preserve the established sizes, weight and responsive layout.

Compact XP cards (2026-10-15): opposing team logos with a centered VS replace visible full team names; the quiz subtitle and action rail are removed. Genuine answer progress and potential XP remain, and the whole card opens the existing prediction flow. Team identities remain accessible. Motorsport retains race identity.

Status and long-name cleanup (2026-10-15): timing text equal to the lifecycle label is suppressed after whitespace/case normalization, so LIVE is not repeated below the competition. Genuine deadlines and clock context remain visible. Team names in match cards use at most two visible lines with ellipsis; full names remain in accessible text.

Future tail per sport (2026-10-15): one full-width Future market follows each sport grid, using the existing editorial market plate and up to three existing outcomes with colored percentage CTAs. Available championship/title/season markets lead; stable IDs preserve return/scroll order. Skip unavailable markets, exclude featured carousel records, and retain existing trade/detail guards. Futures also remain in their dedicated list.

Carousel header removal (2026-10-15): remove the entire visible header strip, including Featured Picks, All Picks and previous/next arrows. Cards start directly in the scrolling rail; swipe, dot selection, keyboard navigation and return-position restoration remain available.

VS typography (2026-10-15): upcoming match and compact XP-card VS labels use the existing shared 12px support size with Orbitron 600 weight. Labels continue to scale with accessibility text settings. Numeric scores retain their score typography.

## Recent discovery card library

The current match, Events, Picks, Futures, XP and reveal recipes are consolidated in [the discovery card library](../discovery-card-library.md). Keep the public match_discovery.dart import, reuse its focused primitives, and keep data/access rules in feature adapters. The shared numerical manifest generates local Flutter, web and Designer copies with explicit stale-output checks.

The racing car follows the road centreline. Football goal posts sit on the
projected end line, with net depth extending outside the pitch. Goal geometry
uses the court projection, rather than an independently positioned rectangle.

The complete car footprint uses an affine projection into the road plane: its
length follows the road and its width follows the road cross-section. Tyres,
curbs and the chequered line share that projection; all four tyre footprints
remain inside the asphalt. A screen-space rotation alone is insufficient.
