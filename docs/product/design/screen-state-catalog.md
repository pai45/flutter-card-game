# StatOz Screen and State Catalog

> **Status:** BUILT
> **Last verified:** 2026-09-19
> **Scope:** Reproducible product and QA evidence for StatOz screens, game entries, and representative visible states.

## Product Purpose

This catalog gives designers, developers, and QA one searchable visual baseline
for the StatOz player journey. StatOz is the product; Pitch Duel is one of six
Football game modes and one of 18 shipped game entries.

## Where It Lives

- Full-resolution PNGs: `output/screenshots/statoz/`
- Machine-readable manifests: `manifest.json`, `manifest.csv`,
  `coverage_audit.csv`, and `qa_findings.csv` beside the PNGs
- Searchable PDF: `output/pdf/statoz-screen-state-catalog.pdf`
- Shared flow map: [StatOz Google Drawing](https://docs.google.com/drawings/d/1Dt5Hz0iPcj4us5wnJx4wp2nqExcSLf0ivTe5G_BZiSA/edit)

## Player Flow

1. Enter through the first-launch welcome and profile setup.
2. Reach MATCH, PICK, or GAMES from the main StatOz sports hub.
3. Filter Football, Cricket, Basketball, Tennis, or Motorsport.
4. Enter a fixture/market or one of the 18 game modes.
5. Return through shop, collections, profile, progression, leaderboard, social,
   tutorial, or support destinations.
6. Receive reward and failure feedback at the action's point of consequence.

## Mechanics and Rules

Every captured scenario has a stable ID, feature, surface, state,
preconditions, player action, expected result, data source, tags, keyframe,
file path, and flow links. PNG names follow
`<order>_<feature>__<surface>__<state>.png`. Baseline captures are 393×852 at
device-pixel-ratio 1.

## Rewards and Progression

Reward moments are tagged in the manifest. Timing-dependent level-up, pack,
and settlement overlays remain explicitly non-capturable in this baseline when
their focused golden evidence is authoritative; they are never replaced by
invented frames.

## Gratification and Feedback

The catalog preserves the shipped cyber-HUD styling and records onboarding,
starter-gate, referral, shop, and game-entry beats. The Drawing legend reserves
cyan for primary flow, magenta for alternatives, gold for gratification, red
for failure/QA, and dotted gray for return paths.

## Visible States

The baseline contains 70 production-widget captures, including every sport
lane, each PREDICT, PICKS, TOPS, and STATS match-detail tab for Football,
Cricket, Basketball, Motorsport, and Tennis, plus a terminal scroll-position
STATS continuation for each sport, all 18 game entries, seven shop
categories, profile, leaderboard, friends, referrals, tutorials, and support.
`coverage_audit.csv` indexes every Dart file
under `lib/screens/`; entries without a dedicated frame are marked
`indexed-no-dedicated-frame` with a reason. `manifest.json` separately records
BUILT, PROTOTYPE, PLANNED, and DEPRECATED behavior that was not capturable.

The next baseline regeneration must add dedicated production-widget captures
for the new ESPN team hub: EPL MATCHES and PLAYERS, LaLiga PREDICTIONS, IPL
MATCHES and PLAYERS, plus the live-refresh-failure state where bundled data
remains visible. Each capture must enter from a real TABLE or STATS team row and
retain the 393x852 / DPR 1 catalog contract.

The next regeneration must also capture the quest hub's three derived states:
tabless ROOKIE PATH, graduated one-sport TODAY, and graduated multi-sport
QUESTS. The rookie top-bar flag and DAILY QUESTS UNLOCKED reveal are separate
required keyframes.

## Persistence

The capture app seeds only local test data, mutes audio, freezes the prediction
clock, uses mock prediction/pick repositories, and satisfies starter-pack gates.
The compiled web harness is captured through Chrome DevTools Protocol after an
exact 393 x 852 / DPR 1 device-metrics override. Every frame is rejected unless
the runtime, visual, document, and layout viewports all match that contract and
the resulting PNG is exactly 393 x 852. This avoids Chrome's narrow-window clamp,
which previously laid the app out wider than the saved bitmap and cropped the
right side. The harness does not change production navigation or public APIs.
Output artifacts are regenerated from the current working-tree code.

## Planned Scope and Current Limitations

- **BUILT:** The production-widget web harness and 393×852 baseline artifacts.
- **PROTOTYPE:** Service-backed values use deterministic local repositories.
- **PLANNED:** Expand each indexed sub-screen into dedicated loading, empty,
  validation, error, active, outcome, and celebration keyframes.
- **DEPRECATED:** Deprecated product behavior is indexed only and is not
  visually recreated.
- **QA:** `games.tennis-rally.entry` remained in its loading frame after the
  capture budget and is retained as `QA-001`.
- **ENVIRONMENT:** The Flutter tester image encoder currently throws
  `Bad state: Future already completed` even for a one-color control golden;
  capture therefore uses the compiled web harness plus headless Chrome. Chrome
  is controlled through its DevTools Protocol rather than the `--window-size`
  screenshot shortcut so the layout and output widths cannot diverge.

## Implementation References

- [`tool/statoz_catalog_app.dart`](../../../tool/statoz_catalog_app.dart)
- [`tool/capture_statoz_catalog.ps1`](../../../tool/capture_statoz_catalog.ps1)
- [`tool/capture_chrome_viewport.mjs`](../../../tool/capture_chrome_viewport.mjs)
- [`tool/build_statoz_screen_catalog.py`](../../../tool/build_statoz_screen_catalog.py)
- [`test/screenshot_catalog/statoz_screenshot_catalog_test.dart`](../../../test/screenshot_catalog/statoz_screenshot_catalog_test.dart)
- [`lib/app.dart`](../../../lib/app.dart)
- [`lib/utils/sound_effects.dart`](../../../lib/utils/sound_effects.dart)

## Tests

- `flutter analyze lib/utils/sound_effects.dart tool/statoz_catalog_app.dart test/screenshot_catalog/statoz_screenshot_catalog_test.dart`
- Two complete capture passes verify the same 70 stable scenario IDs and file
  names; every CDP response reports a 393 x 852 layout and screenshot at DPR 1.
- Manifest validation verifies 45 unique IDs, PNG integrity, exact dimensions,
  complete metadata, and searchable PDF IDs.
- All 48 PDF pages are rendered and visually inspected; the cricket match hub,
  Grand Prix Dash lobby, and pack shop are retained as right-edge regression
  checks.
