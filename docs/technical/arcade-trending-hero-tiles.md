# Arcade Trending Hero Tiles — Implementation & Porting Reference

> **Status:** BUILT · **Written:** 2026-09-16 · **Audience:** Flutter engineers rebuilding these tiles in another project
>
> **Source of truth:**
> [`lib/screens/predictions/prediction_home_screen.dart`](../../lib/screens/predictions/prediction_home_screen.dart)
> covers:
> - the `'final-over'`, `'hoop-duel'`, `'grand-prix-dash'` and `'tennis-rally'`
>   arms of `_TrendingGamesTabState._buildGameTile`
> - `_ArcadeHeroGameTile`, `_HeroBadge`, `_HeroTitle` and `_HudChamferCardPainter`
> - `_HoopDuelMiniCourtPainter` and `_FinalOverMiniPitchPainter`
>
> Supporting files:
> - `lib/widgets/cyber/sport_signal_painters.dart` (Tennis and F1 painters)
> - `lib/widgets/cyber/cyber_widgets.dart` (chamfer clipper, bento grid)
> - `lib/screens/predictions/trending_hub_catalog.dart` (catalog)
> - `lib/widgets/staggered_card_entrance.dart`
> - `lib/widgets/streak_widgets.dart`
> - `lib/config/sport_modules.dart`
>
> **This document is self-contained.** Appendix A holds every file, at the path
> in its heading. Declarations are copied **verbatim** by script; the only new
> code is the small grid host marked `PORT HOST` in A.1. Dropped into an empty
> Flutter package, Appendix A analyzes clean and its widget test passes (§9).
>
> The games these tiles open have their own port docs:
> - [Final Over](final-over-cricket-port.md)
> - [Hoop Duel](hoop-duel-basketball-port.md)
> - [Grand Prix Dash](grand-prix-dash-port.md)
> - [Tennis Rally](tennis-rally-port.md)

---

## 1. What these are

On the **GAMES → Trending** feed, each arcade game is advertised by a *hero
tile*. It is a chamfered HUD card with:

- a coloured badge
- a big display-font title
- an accent subtitle
- a small code-drawn scene on the right that says which sport it is

Tapping anywhere on the tile gives a selection haptic and opens the game.

| Tile | Key | Catalog span | Title (lines) | Subtitle | Badge | Accent | Scene (right side) | Opens |
|---|---|---|---|---|---|---|---|---|
| Final Over | `trending-final-over-card` | **wide** (2×1) | FINAL OVER | SIX-BALL CRICKET CHASE | FEATURED // SIX BALLS | `sportModuleFor(Sport.cricket).accent` = **white** `#FFFFFF` | Green oval outfield, tan perspective pitch, crease, 3 stumps + bail, white ball with red seam and a faint travel line | `onOpenFinalOver` |
| Hoop Duel | `trending-hoop-duel-card` | **square** (1×1) | HOOP DUEL | STREET 1-ON-1 | FEATURED // STREET | `Cyber.gold` `#FDC700` | Olive-gold court wedge, key oval, backboard pole + white board, gold rim, gold ball with seams | `onOpenBasketball` |
| Grand Prix Dash | `trending-grand-prix-card` | **square** (1×1) | GRAND PRIX / DASH | ONE-LAP ARCADE RACER | FEATURED // RACE | `Cyber.f1Red` `#F42D29` | S-bend track band with red halo and centre line, red top-down car tilted −0.22 rad | `onOpenGrandPrix` |
| Tennis Rally | `trending-tennis-rally-card` | **wide** (2×1) | TENNIS RALLY | 2D ARCADE SETS // 5 MODES | FEATURED // NEW | `Cyber.lime` `#51FF94` | Cyan-tinted perspective court, service and centre lines, lime ball, lime shadow ring | `onOpenTennisRally` |

All four pass `emphasis: false`, `tightContent: true` and `largeType: true`,
and use the default `layout: GameHeroLayout.landscape` with no streak.

## 2. Anatomy of `_ArcadeHeroGameTile` (landscape)

```
Semantics(button, label: "$title, $ctaLabel")
 └ GestureDetector(opaque) → HapticFeedback.selectionClick(); onTap()
    └ CustomPaint(_HudChamferCardPainter: fill Cyber.panel, 1.2px border accent@0.86,
    │              blurred 2px glow only if emphasis)
       └ ClipPath(HudChamferClipper(bigCut: 14, smallCut: 4))
          └ LayoutBuilder → SizedBox(height: 174)
             └ Stack(expand)
                ├ background  (CustomPaint painter, fills the card)
                ├ [compact only] vertical scrim bg@0.2 → bg@0.72
                └ Padding(17, or 12 when compact)
                   └ Column(start)
                      ├ _HeroBadge   (accent@0.16 fill, Orbitron 10, accent)
                      ├ SizedBox(12)            ← tightContent (else Spacer)
                      ├ _HeroTitle   (Orbitron w900, white, 20 / 13 compact, height 1.02)
                      ├ SizedBox(5, or 3 compact)
                      └ subtitle     (Orbitron 10 (largeType), accent, 1 line / 2 compact)
```

- **Compact mode:** kicks in when `layout == landscape` and the tile is
  **narrower than 165 px**. That only happens to the square tiles on narrow
  phones. On a 390 px screen the grid is 358 px wide, so a square cell is
  173 px (not compact). On a 320 px screen a cell is 138 px (compact: scrim
  on, tighter padding, 13 px title, 2-line subtitle).
- **Height:** the `SizedBox(height: 174)` is a preferred height. Inside a
  bento cell the tight cell constraints win, so the card is the cell's
  height.
- **Chamfer shape:** `HudChamferClipper` cuts a 14 px chamfer top-left and
  bottom-right, and 4 px accents on the other two corners. The same path is
  used for the fill, the border and the clip, so the art never bleeds past
  the border.
- **Multi-line titles:** `titleLines` (Grand Prix: `['GRAND PRIX', 'DASH']`)
  renders one `Text` per line. Outside compact mode the lines are
  constrained to `clamp(width·0.56, 168, 214)`, so the title never runs
  into the scene. Single titles are one ellipsized line.
- **Streaks:** `streak > 0` would show `StreakBadge(scale: 1.25)` above the
  title. None of these four tiles has a streak.
- **Portrait layout:** `GameHeroLayout.portrait` (art in the bottom 56 %,
  text in the top 50 %, `TAP // PLAY` footer) exists for the tall
  Pitch Duel / Penalty / Chess tiles. It is kept for parity and not used
  here.

## 3. The four scene painters

Every painter follows the same recipe:

1. Fill the whole card with a **left-transparent → right-tinted** horizontal
   gradient (stops `0.36 → 1`), so the text side stays dark.
2. Draw the sport scene in the **right ~45 %** using fractional coordinates
   (`size.width * k`), so it scales with the tile.

`shouldRepaint` returns false for the private painters, and compares
`accent` for the two shared ones.

| Painter | Gradient end | Scene recipe (fractions of w/h) |
|---|---|---|
| `_FinalOverMiniPitchPainter` | `#D10B2B39` teal | Oval centre (.79, .55), size .58w × .68h, fill `#153E36` · pitch trapezoid (.74,.20)(.84,.20)(.96,1.02)(.57,1.02), fill `#8B7545`, white@.48 1.2 px stroke · crease line y .83 from x .61→.93, white@.66 · stumps at x .80 ±6 px, y .28→.48, 2.2 px round white · bail y .30, ±7 px · travel line (.72,.52)→ball, white@.28 · ball (.88,.65) r7 `#F3F6F8` + red seam arc r5 from −1.2 rad sweeping 2.4 |
| `_HoopDuelMiniCourtPainter` | `#D12C260D` olive | Court wedge (.64,.16)(1,.16)(1,1)(.52,1), fill `#665116`, gold@.58 1.2 px stroke · key oval centre (.79,.73), 108×76 px · pole x .82, y .16→.52 · backboard (.74→.91, .28), 3 px white@.55 · rim oval (.82,.39) 36×10 px, 3 px gold · ball (.91,.60) r17 gold, seams (cross + vertical oval 16×34) in `#17120A`@.78 |
| `TennisMysterySignalPainter(accent: lime)` | `bg2` blended with cyan@.24 | Court trapezoid (.67,.12)(.94,.12)(1.08,1.03)(.48,1.03), fill `bg2`+cyan@.28, `textPrimary`@.52 1 px lines · service line y .57 from x .57→1 · centre line (.75,.12)→(.67,1) · ball (.83,.39) r6 accent · shadow oval (.83,.78) 27×9, accent@.36 1.5 px |
| `F1MysterySignalPainter(accent: f1Red)` | `bg2` blended with accent@.2 | Track: two cubics from (.70,−12 px) via (.84,.61) to (.96,1.08), drawn as a 42 px `Cyber.border` band, then a 46 px accent@.22 halo, then a 1.3 px `textPrimary`@.34 centre line · car at (.82,.60), rotated −0.22: 48×18 r5 accent body, 17×12 `bg` cockpit, four 13×5 `bg` wheels at x −12/+14, y ±10 |

**Port note.** In the source, the halo is drawn after the band, so the
translucent red sits on top of it. Keep that order.

## 4. Placement: the bento feed

`ArcadeTrendingGamesGrid` (A.1, `PORT HOST`) reproduces the source feed for
these four tiles:

- **Container:** a `ListView(key: 'games-trending-feed', padding: 16/12)`
  holding a `CyberBentoGrid`.
- **Grid:** two columns, 12 px gaps, max width 440, square rows (row height
  = column width).
- **Packing:** `_packBentoTiles` densely packs each tile into the first free
  cell, in catalog order.
- **Catalog order:** wide Final Over → square Hoop Duel + square Grand Prix
  side by side → wide Tennis Rally, which gives **three rows**.
- **Entrance:** each tile is wrapped in `StaggeredCardEntrance(index)`:
  - fade in and slide 48 px from the left over `320 ms + 70 ms × index`
  - staggered with `Interval(delay, 1, easeOutCubic)`
  - skipped when `animate` is false, for index > 7, or when the OS reduced
    motion setting is on
- **Play the entrance once.** The source plays it only the first time the
  feed appears in a session (`animateIntro` plus an `onIntroPlayed`
  callback posted after the first frame). Pass `animateIntro: false` on
  later visits.
- **Unknown catalog ids** render a `MODE OFFLINE` placeholder.
- **Catalog toggle:** `enabled: false` on a `TrendingTileConfig` hides a
  tile without touching the widget code.

In the source app, these four tiles share the feed with Pitch Duel, Penalty
Shootout, Football Chess (tall hero tiles) and three quick-play tiles. The
feed sits under a sport tab strip, and Pitch Duel / Penalty read streaks from
the global `GameBloc`. None of that affects these four tiles.

## 5. Wiring the callbacks

```dart
ArcadeTrendingGamesGrid(
  onOpenFinalOver:   () => Navigator.push(context, /* Final Over hub */),
  onOpenBasketball:  () => Navigator.push(context, /* Hoop Duel hub */),
  onOpenGrandPrix:   () => Navigator.push(context, /* Grand Prix lobby */),
  onOpenTennisRally: () => Navigator.push(context, /* Tennis Rally hub */),
  animateIntro: !introAlreadyPlayed,
)
```

The source makes `onOpenFinalOver` and `onOpenTennisRally` optional at the
screen level and falls back to `() {}`. The port requires all four.

## 6. Design rules carried by this code

- **Glow is scarce.** These tiles use `emphasis: false`, so only a crisp
  1.2 px border shows. The blurred border glow is reserved for the one
  focal tile (Pitch Duel).
- **Shape:** the diagonal chamfer (14/4) is used for fill, border and clip.
- **Colour:** all colours come from `Cyber` / `AppTheme` tokens. The only
  raw hex values are the scene "content" colours inside the private
  painters (grass, clay, hardwood, gradient tints), exactly as in the
  source.
- **Contrast:** the text sits on the dark left side, and the art lives on
  the right. Compact tiles add a scrim instead of shrinking the art.
- **Feedback:** every tap pays back instantly with a selection haptic
  before navigation.

## 7. Copy notes (product vs. engine)

The tile copy is kept verbatim. Two strings no longer match the shipped games:

- **Final Over:** "SIX-BALL CRICKET CHASE" / "SIX BALLS". The engine now
  plays up to **18 legal balls (3 overs)**. `docs/product/games/final-over.md`
  already records this as an open copy issue.
- **Grand Prix Dash:** "ONE-LAP ARCADE RACER". Races can now be **1, 3 or
  5 laps**.

Change them in your port if you want the tile to describe the current game.
The widget test (Appendix A) asserts titles, not subtitles.

## 8. File map and port checklist

| Target path | Contents | Where |
|---|---|---|
| `lib/widgets/arcade_trending_tiles.dart` | Hero tile, badge, title, card painter, Hoop Duel + Final Over painters (verbatim), and the `ArcadeTrendingGamesGrid` host with the four verbatim switch arms | A.1 |
| `lib/widgets/arcade_trending_catalog.dart` | `TrendingTileKind`, `TrendingTileConfig` and the four catalog entries (verbatim) | A.2 |
| `lib/widgets/cyber/cyber_widgets.dart` | `HudChamferClipper`, `CyberBentoSpan`/`Tile`/`Grid` + packing (verbatim subset) | A.3 |
| `lib/widgets/cyber/sport_signal_painters.dart` | `TennisMysterySignalPainter`, `F1MysterySignalPainter` (verbatim subset) | A.4 |
| `lib/widgets/staggered_card_entrance.dart` | Entrance animation (verbatim, whole file) | A.5 |
| `lib/widgets/streak_widgets.dart` | `StreakBadge` (verbatim subset) | A.6 |
| `lib/config/sport_modules.dart` | `SportModule`, `sportModuleFor`, sport tab order (verbatim, whole file) | A.7 |
| `lib/config/theme.dart` | **Stand-in** `AppTheme` / `Cyber` / `StreakTheme` tokens (source literal values) | A.8 |
| `lib/models/sport_match.dart` | **Stand-in**: the `Sport` enum (verbatim) | A.9 |
| `test/arcade_trending_tiles_test.dart` | Widget test at 390 px and 320 px (new) | A.10 |

Checklist:

1. Copy A.1–A.10 to the listed paths. If your project already has a theme,
   `Sport` enum or `sport_modules`, map A.8 / A.9 / A.7 onto yours and keep
   the names.
2. Declare the **Orbitron** font (`Cyber.displayFont`) in `pubspec.yaml`, or
   point `displayFont` at your display face. The tiles depend on a heavy
   condensed display type.
3. Mount `ArcadeTrendingGamesGrid` in your GAMES tab and wire the four
   callbacks (§5).
4. Run `flutter analyze` and `flutter test test/arcade_trending_tiles_test.dart`.
5. Look at it on device at 320 px and 390+ px:
   - the square tiles switch to compact below 165 px
   - the scene never overlaps the title
   - the entrance plays once

## 9. Verification performed for this document

A script read **only this markdown file** and wrote every Appendix A block to
its heading path in an empty Flutter package (Flutter 3.44.4, no
dependencies beyond the SDK and `flutter_lints`).

- **Verbatim check:** every declaration marked verbatim was extracted from
  the source files by name.
- **Analyze:** `flutter analyze` → **No issues found!** A.1 carries one
  file-level `ignore_for_file: unused_element_parameter`, because these four
  tiles never pass the kept `streak` / `layout` parameters.
- **Test:** `flutter test` → **2 tests passed**. At 390 px and 320 px, all
  four keyed tiles render with no exceptions, each tap routes to the right
  callback, the four titles are present, and the wide tiles are more than
  1.9× the width of the square ones.
- **Not checked:** the visual output was not compared pixel-for-pixel with
  the source app.

---

## Appendix A — Files

Copy each block to the path in its heading.

### A.1 `lib/widgets/arcade_trending_tiles.dart`

<sub>680 lines</sub>

```dart
// PORT LIBRARY: the Trending arcade hero tiles for Final Over, Hoop Duel,
// Grand Prix Dash and Tennis Rally.
//
// Everything above the `PORT HOST` marker is copied verbatim from
// lib/screens/predictions/prediction_home_screen.dart. The classes stay
// library-private exactly as in the source; ArcadeTrendingGamesGrid (below
// the marker) is the only new code and is the public entry point.
//
// `streak` and `layout: portrait` are kept on _ArcadeHeroGameTile for
// parity with the source (Pitch Duel / Penalty / Chess tiles pass them),
// but none of these four tiles does, hence the ignore below.
// ignore_for_file: unused_element_parameter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/sport_modules.dart';
import '../config/theme.dart';
import '../models/sport_match.dart';
import 'arcade_trending_catalog.dart';
import 'cyber/cyber_widgets.dart';
import 'cyber/sport_signal_painters.dart';
import 'staggered_card_entrance.dart';
import 'streak_widgets.dart';

enum GameHeroLayout { landscape, portrait }

class _ArcadeHeroGameTile extends StatelessWidget {
  const _ArcadeHeroGameTile({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.ctaLabel,
    required this.accent,
    required this.background,
    required this.onTap,
    this.titleLines,
    this.streak = 0,
    this.layout = GameHeroLayout.landscape,
    this.emphasis = true,
    this.tightContent = false,
    this.largeType = false,
    super.key,
  });

  final String title;
  final List<String>? titleLines;
  final String subtitle;
  final String badgeLabel;
  final String ctaLabel;
  final Color accent;
  final Widget background;
  final VoidCallback onTap;
  final int streak;
  final GameHeroLayout layout;
  final bool emphasis;
  final bool tightContent;
  final bool largeType;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title, $ctaLabel',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: CustomPaint(
          painter: _HudChamferCardPainter(
            bigCut: 14,
            smallCut: 4,
            fillColor: Cyber.panel,
            borderColor: accent.withValues(alpha: 0.86),
            borderGlow: emphasis,
          ),
          child: ClipPath(
            clipper: const HudChamferClipper(bigCut: 14, smallCut: 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact =
                    layout == GameHeroLayout.landscape &&
                    constraints.maxWidth < 165;
                return SizedBox(
                  height: 174,
                  child: layout == GameHeroLayout.portrait
                      ? _buildPortrait()
                      : _buildLandscape(compact: compact),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscape({bool compact = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        if (compact)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Cyber.bg.withValues(alpha: 0.2),
                  Cyber.bg.withValues(alpha: 0.72),
                ],
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.all(compact ? 12 : 17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroBadge(
                label: badgeLabel,
                accent: accent,
                largeType: largeType,
              ),
              if (tightContent) const SizedBox(height: 12) else const Spacer(),
              _HeroTitle(
                title: title,
                titleLines: titleLines,
                streak: streak,
                square: compact,
              ),
              SizedBox(height: compact ? 3 : 5),
              Text(
                subtitle,
                maxLines: compact ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: Cyber.display(
                  largeType
                      ? 10
                      : compact
                      ? 6.5
                      : 8,
                  color: accent,
                  letterSpacing: compact ? 0.3 : 0.5,
                ).copyWith(height: 1.08),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPortrait() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: 0.56,
            child: background,
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: FractionallySizedBox(
            widthFactor: 1,
            heightFactor: 0.5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 14, 13, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _HeroBadge(
                    label: badgeLabel,
                    accent: accent,
                    largeType: largeType,
                  ),
                  SizedBox(height: tightContent ? 8 : 12),
                  _HeroTitle(
                    title: title,
                    titleLines: titleLines,
                    streak: streak,
                    compact: true,
                  ),
                  SizedBox(height: tightContent ? 4 : 6),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Cyber.display(
                      largeType ? 10 : 7,
                      color: accent,
                      letterSpacing: 0.4,
                    ).copyWith(height: 1.15),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 13,
          bottom: 11,
          child: Text(
            'TAP // PLAY',
            style: Cyber.label(
              largeType ? 10 : 6.5,
              color: accent.withValues(alpha: 0.84),
              letterSpacing: 0.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroBadge extends StatelessWidget {
  const _HeroBadge({
    required this.label,
    required this.accent,
    required this.largeType,
  });

  final String label;
  final Color accent;
  final bool largeType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      color: accent.withValues(alpha: 0.16),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Cyber.display(
          largeType ? 10 : 7,
          color: accent,
          letterSpacing: largeType ? 0.3 : 0,
        ),
      ),
    );
  }
}

class _HeroTitle extends StatelessWidget {
  const _HeroTitle({
    required this.title,
    required this.titleLines,
    required this.streak,
    this.compact = false,
    this.square = false,
  });

  final String title;
  final List<String>? titleLines;
  final int streak;
  final bool compact;
  final bool square;

  TextStyle get _style => Cyber.display(
    square
        ? 13
        : compact
        ? 15
        : 20,
    color: Colors.white,
    letterSpacing: square
        ? 0.35
        : compact
        ? 0.6
        : 1,
  ).copyWith(height: 1.02);

  @override
  Widget build(BuildContext context) {
    final lines = titleLines;
    if (lines == null || lines.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (streak > 0) ...[
            StreakBadge(value: streak, scale: 1.25),
            const SizedBox(height: StreakTheme.space4),
          ],
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style,
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final titleWidth = compact || square
            ? constraints.maxWidth
            : (constraints.maxWidth * 0.56).clamp(168.0, 214.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (streak > 0) ...[
              StreakBadge(value: streak, scale: 1.25),
              const SizedBox(height: StreakTheme.space4),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: titleWidth.toDouble()),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final line in lines)
                    Text(
                      line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _style,
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Paints a flat fill plus a stroke that traces the full [HudChamferClipper]
/// outline — including the diagonal cut edges.
class _HudChamferCardPainter extends CustomPainter {
  const _HudChamferCardPainter({
    required this.bigCut,
    required this.smallCut,
    required this.fillColor,
    required this.borderColor,
    this.borderGlow = false,
  });

  final double bigCut;
  final double smallCut;
  final Color fillColor;
  final Color borderColor;
  final bool borderGlow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final path = HudChamferClipper(
      bigCut: bigCut,
      smallCut: smallCut,
    ).buildPath(size);

    canvas.drawPath(path, Paint()..color = fillColor);

    if (borderGlow) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = borderColor.withValues(alpha: 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = borderColor,
    );
  }

  @override
  bool shouldRepaint(covariant _HudChamferCardPainter old) =>
      old.bigCut != bigCut ||
      old.smallCut != smallCut ||
      old.fillColor != fillColor ||
      old.borderColor != borderColor ||
      old.borderGlow != borderGlow;
}

class _HoopDuelMiniCourtPainter extends CustomPainter {
  const _HoopDuelMiniCourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00101825), Color(0xd12c260d)],
          stops: [0.36, 1],
        ).createShader(Offset.zero & size),
    );

    final court = Path()
      ..moveTo(size.width * 0.64, size.height * 0.16)
      ..lineTo(size.width, size.height * 0.16)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.52, size.height)
      ..close();
    canvas.drawPath(court, Paint()..color = const Color(0xff665116));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Cyber.gold.withValues(alpha: 0.58);
    canvas.drawPath(court, line);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.79, size.height * 0.73),
        width: 108,
        height: 76,
      ),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.82, size.height * 0.16),
      Offset(size.width * 0.82, size.height * 0.52),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.74, size.height * 0.28),
      Offset(size.width * 0.91, size.height * 0.28),
      Paint()
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: 0.55),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.82, size.height * 0.39),
        width: 36,
        height: 10,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Cyber.gold,
    );

    final ball = Offset(size.width * 0.91, size.height * 0.60);
    canvas.drawCircle(ball, 17, Paint()..color = Cyber.gold);
    final seam = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = const Color(0xff17120a).withValues(alpha: 0.78);
    canvas.drawLine(ball.translate(-17, 0), ball.translate(17, 0), seam);
    canvas.drawLine(ball.translate(0, -17), ball.translate(0, 17), seam);
    canvas.drawOval(Rect.fromCenter(center: ball, width: 16, height: 34), seam);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FinalOverMiniPitchPainter extends CustomPainter {
  const _FinalOverMiniPitchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0x00101825), Color(0xd10b2b39)],
          stops: [0.36, 1],
        ).createShader(Offset.zero & size),
    );

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.79, size.height * 0.55),
        width: size.width * 0.58,
        height: size.height * 0.68,
      ),
      Paint()..color = const Color(0xff153e36),
    );
    final pitch = Path()
      ..moveTo(size.width * 0.74, size.height * 0.20)
      ..lineTo(size.width * 0.84, size.height * 0.20)
      ..lineTo(size.width * 0.96, size.height * 1.02)
      ..lineTo(size.width * 0.57, size.height * 1.02)
      ..close();
    canvas.drawPath(pitch, Paint()..color = const Color(0xff8b7545));
    canvas.drawPath(
      pitch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppTheme.whiteColor.withValues(alpha: 0.48),
    );
    final crease = Paint()
      ..strokeWidth = 1.3
      ..color = Colors.white.withValues(alpha: 0.66);
    canvas.drawLine(
      Offset(size.width * 0.61, size.height * 0.83),
      Offset(size.width * 0.93, size.height * 0.83),
      crease,
    );

    final wicketX = size.width * 0.80;
    for (final dx in [-6.0, 0.0, 6.0]) {
      canvas.drawLine(
        Offset(wicketX + dx, size.height * 0.28),
        Offset(wicketX + dx, size.height * 0.48),
        Paint()
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round
          ..color = AppTheme.whiteColor,
      );
    }
    canvas.drawLine(
      Offset(wicketX - 7, size.height * 0.30),
      Offset(wicketX + 7, size.height * 0.30),
      Paint()
        ..strokeWidth = 2
        ..color = AppTheme.whiteColor,
    );

    final ball = Offset(size.width * 0.88, size.height * 0.65);
    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.52),
      ball,
      Paint()
        ..strokeWidth = 2
        ..color = AppTheme.whiteColor.withValues(alpha: 0.28),
    );
    canvas.drawCircle(ball, 7, Paint()..color = const Color(0xfff3f6f8));
    canvas.drawArc(
      Rect.fromCircle(center: ball, radius: 5),
      -1.2,
      2.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Cyber.danger,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// PORT HOST (new code). Mirrors _TrendingGamesTabState.build /
// _buildGameTile in the source, minus the other Trending modes, the sport
// tab strip and the GameBloc streak read (these four tiles never show a
// streak). The four switch arms are verbatim.
// ---------------------------------------------------------------------------

class ArcadeTrendingGamesGrid extends StatelessWidget {
  const ArcadeTrendingGamesGrid({
    required this.onOpenFinalOver,
    required this.onOpenBasketball,
    required this.onOpenGrandPrix,
    required this.onOpenTennisRally,
    this.animateIntro = true,
    super.key,
  });

  final VoidCallback onOpenFinalOver;
  final VoidCallback onOpenBasketball;
  final VoidCallback onOpenGrandPrix;
  final VoidCallback onOpenTennisRally;
  final bool animateIntro;

  // Keeps the source's `widget.` prefix valid inside the verbatim arms.
  ArcadeTrendingGamesGrid get widget => this;

  @override
  Widget build(BuildContext context) {
    final catalog = arcadeTrendingCatalog
        .where((item) => item.enabled)
        .toList(growable: false);
    return ListView(
      key: const ValueKey('games-trending-feed'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      children: [
        CyberBentoGrid(
          tiles: [
            for (var index = 0; index < catalog.length; index++)
              CyberBentoTile(
                span: catalog[index].span,
                child: StaggeredCardEntrance(
                  key: ValueKey(catalog[index].id),
                  index: index,
                  animate: animateIntro,
                  child: _buildGameTile(catalog[index]),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildGameTile(TrendingTileConfig config) {
    return switch (config.sourceId) {
      'final-over' => _ArcadeHeroGameTile(
        key: const ValueKey('trending-final-over-card'),
        title: 'FINAL OVER',
        subtitle: 'SIX-BALL CRICKET CHASE',
        badgeLabel: 'FEATURED // SIX BALLS',
        ctaLabel: 'START THE CHASE',
        accent: sportModuleFor(Sport.cricket).accent,
        emphasis: false,
        tightContent: true,
        largeType: true,
        background: const CustomPaint(painter: _FinalOverMiniPitchPainter()),
        onTap: widget.onOpenFinalOver,
      ),
      'hoop-duel' => _ArcadeHeroGameTile(
        key: const ValueKey('trending-hoop-duel-card'),
        title: 'HOOP DUEL',
        subtitle: 'STREET 1-ON-1',
        badgeLabel: 'FEATURED // STREET',
        ctaLabel: 'HIT THE COURT',
        accent: Cyber.gold,
        emphasis: false,
        tightContent: true,
        largeType: true,
        background: const CustomPaint(painter: _HoopDuelMiniCourtPainter()),
        onTap: widget.onOpenBasketball,
      ),
      'grand-prix-dash' => _ArcadeHeroGameTile(
        key: const ValueKey('trending-grand-prix-card'),
        title: 'GRAND PRIX DASH',
        titleLines: const ['GRAND PRIX', 'DASH'],
        subtitle: 'ONE-LAP ARCADE RACER',
        badgeLabel: 'FEATURED // RACE',
        ctaLabel: 'RACE NOW',
        accent: Cyber.f1Red,
        emphasis: false,
        tightContent: true,
        largeType: true,
        background: const CustomPaint(painter: F1MysterySignalPainter()),
        onTap: widget.onOpenGrandPrix,
      ),
      'tennis-rally' => _ArcadeHeroGameTile(
        key: const ValueKey('trending-tennis-rally-card'),
        title: 'TENNIS RALLY',
        subtitle: '2D ARCADE SETS // 5 MODES',
        badgeLabel: 'FEATURED // NEW',
        ctaLabel: 'STEP ON COURT',
        accent: Cyber.lime,
        emphasis: false,
        tightContent: true,
        largeType: true,
        background: const CustomPaint(painter: TennisMysterySignalPainter()),
        onTap: widget.onOpenTennisRally,
      ),
      _ => Center(
        child: Text(
          'MODE OFFLINE\n${config.sourceId}',
          textAlign: TextAlign.center,
          style: Cyber.label(10, color: Cyber.muted),
        ),
      ),
    };
  }
}
```

### A.2 `lib/widgets/arcade_trending_catalog.dart`

<sub>56 lines</sub>

```dart
// SUBSET of lib/screens/predictions/trending_hub_catalog.dart: the types
// verbatim, and the four arcade entries of gamesTrendingCatalog verbatim
// (same order and spans as the source).
import '../models/sport_match.dart';
import 'cyber/cyber_widgets.dart';

enum TrendingTileKind { match, future, pick, predict, game }

class TrendingTileConfig {
  const TrendingTileConfig({
    required this.id,
    required this.kind,
    required this.sourceId,
    required this.span,
    this.sport,
    this.enabled = true,
  });

  final String id;
  final TrendingTileKind kind;
  final String sourceId;
  final CyberBentoSpan span;
  final Sport? sport;
  final bool enabled;
}

const arcadeTrendingCatalog = <TrendingTileConfig>[
  TrendingTileConfig(
    id: 'trend-game-final-over',
    kind: TrendingTileKind.game,
    sourceId: 'final-over',
    sport: Sport.cricket,
    span: CyberBentoSpan.wide,
  ),
  TrendingTileConfig(
    id: 'trend-game-hoop-duel',
    kind: TrendingTileKind.game,
    sourceId: 'hoop-duel',
    sport: Sport.basketball,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-game-grand-prix',
    kind: TrendingTileKind.game,
    sourceId: 'grand-prix-dash',
    sport: Sport.motorsport,
    span: CyberBentoSpan.square,
  ),
  TrendingTileConfig(
    id: 'trend-game-tennis-rally',
    kind: TrendingTileKind.game,
    sourceId: 'tennis-rally',
    sport: Sport.tennis,
    span: CyberBentoSpan.wide,
  ),
];
```

### A.3 `lib/widgets/cyber/cyber_widgets.dart`

<sub>201 lines</sub>

```dart
// SUBSET of lib/widgets/cyber/cyber_widgets.dart — verbatim declarations.
import 'dart:math';

import 'package:flutter/material.dart';

/// Angular HUD silhouette shared by the primary CTA ([HudCtaButton]) and player
/// cards: a strong chamfer on the top-left and bottom-right corners with smaller
/// accent cuts on the top-right and bottom-left. Keeping one silhouette across
/// buttons and cards makes them read as the same "HUD hardware" family.
class HudChamferClipper extends CustomClipper<Path> {
  const HudChamferClipper({required this.bigCut, required this.smallCut});

  final double bigCut;
  final double smallCut;

  Path buildPath(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(bigCut, 0) // after the top-left chamfer
      ..lineTo(w - smallCut, 0) // top edge
      ..lineTo(w, smallCut) // top-right accent
      ..lineTo(w, h - bigCut) // right edge
      ..lineTo(w - bigCut, h) // bottom-right chamfer
      ..lineTo(smallCut, h) // bottom edge
      ..lineTo(0, h - smallCut) // bottom-left accent
      ..lineTo(0, bigCut) // left edge
      ..close();
  }

  @override
  Path getClip(Size size) => buildPath(size);

  @override
  bool shouldReclip(covariant HudChamferClipper old) =>
      old.bigCut != bigCut || old.smallCut != smallCut;
}

/// Cell footprints supported by [CyberBentoGrid].
enum CyberBentoSpan { square, wide, tall }

class CyberBentoTile {
  const CyberBentoTile({required this.span, required this.child});

  final CyberBentoSpan span;
  final Widget child;
}

/// A dependency-free, dense two-column bento layout shared by the MATCH and
/// GAMES Trending feeds.
///
/// `square` occupies 1x1, `wide` 2x1, and `tall` 1x2. Items are densely packed
/// into the first available cells, while the source order remains the semantic
/// traversal order. The grid stays phone-sized on wide screens so illustrated
/// cards do not become oversized. [rowHeightFactor] can tighten a feature's
/// cards without changing its column widths; the default preserves square cells.
class CyberBentoGrid extends StatelessWidget {
  const CyberBentoGrid({
    required this.tiles,
    this.gap = 12,
    double? rowGap,
    this.maxWidth = 440,
    this.rowHeightFactor = 1,
    this.minRowHeight = 0,
    super.key,
  }) : rowGap = rowGap ?? gap,
       assert(rowGap == null || rowGap >= 0),
       assert(rowHeightFactor > 0),
       assert(minRowHeight >= 0);

  final List<CyberBentoTile> tiles;
  final double gap;
  final double rowGap;
  final double maxWidth;

  /// Multiplier for each grid row relative to a column cell's width.
  final double rowHeightFactor;

  /// Keeps dense cards readable on narrow phones.
  final double minRowHeight;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = min(constraints.maxWidth, maxWidth);
        final unit = (width - gap) / 2;
        final rowHeight = max(unit * rowHeightFactor, minRowHeight).toDouble();
        final layout = _packBentoTiles(tiles);
        final height =
            layout.rowCount * rowHeight + max(0, layout.rowCount - 1) * rowGap;

        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (var index = 0; index < tiles.length; index++)
                  Positioned(
                    left: layout.cells[index].column * (unit + gap),
                    top: layout.cells[index].row * (rowHeight + rowGap),
                    width:
                        layout.cells[index].columnSpan * unit +
                        (layout.cells[index].columnSpan - 1) * gap,
                    height:
                        layout.cells[index].rowSpan * rowHeight +
                        (layout.cells[index].rowSpan - 1) * rowGap,
                    child: tiles[index].child,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CyberBentoCell {
  const _CyberBentoCell({
    required this.row,
    required this.column,
    required this.rowSpan,
    required this.columnSpan,
  });

  final int row;
  final int column;
  final int rowSpan;
  final int columnSpan;
}

class _CyberBentoLayout {
  const _CyberBentoLayout({required this.cells, required this.rowCount});

  final List<_CyberBentoCell> cells;
  final int rowCount;
}

_CyberBentoLayout _packBentoTiles(List<CyberBentoTile> tiles) {
  final occupied = <List<bool>>[];
  final cells = <_CyberBentoCell>[];

  void ensureRows(int count) {
    while (occupied.length < count) {
      occupied.add(<bool>[false, false]);
    }
  }

  bool fits(int row, int column, int rowSpan, int columnSpan) {
    if (column + columnSpan > 2) return false;
    ensureRows(row + rowSpan);
    for (var y = row; y < row + rowSpan; y++) {
      for (var x = column; x < column + columnSpan; x++) {
        if (occupied[y][x]) return false;
      }
    }
    return true;
  }

  for (final tile in tiles) {
    final (rowSpan, columnSpan) = switch (tile.span) {
      CyberBentoSpan.square => (1, 1),
      CyberBentoSpan.wide => (1, 2),
      CyberBentoSpan.tall => (2, 1),
    };
    var row = 0;
    var placed = false;
    while (!placed) {
      for (var column = 0; column < 2; column++) {
        if (!fits(row, column, rowSpan, columnSpan)) continue;
        for (var y = row; y < row + rowSpan; y++) {
          for (var x = column; x < column + columnSpan; x++) {
            occupied[y][x] = true;
          }
        }
        cells.add(
          _CyberBentoCell(
            row: row,
            column: column,
            rowSpan: rowSpan,
            columnSpan: columnSpan,
          ),
        );
        placed = true;
        break;
      }
      if (!placed) row++;
    }
  }

  var rowCount = occupied.length;
  while (rowCount > 0 && occupied[rowCount - 1].every((cell) => !cell)) {
    rowCount--;
  }
  return _CyberBentoLayout(cells: cells, rowCount: rowCount);
}
```

### A.4 `lib/widgets/cyber/sport_signal_painters.dart`

<sub>199 lines</sub>

```dart
// SUBSET of lib/widgets/cyber/sport_signal_painters.dart — verbatim classes.
import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Shared court telemetry promoted from the Games hub tennis card.
class TennisMysterySignalPainter extends CustomPainter {
  const TennisMysterySignalPainter({this.accent = Cyber.lime});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Cyber.bg.withValues(alpha: 0),
            Color.alphaBlend(Cyber.cyan.withValues(alpha: 0.24), Cyber.bg2),
          ],
          stops: const [0.36, 1],
        ).createShader(bounds),
    );

    final court = Path()
      ..moveTo(size.width * 0.67, size.height * 0.12)
      ..lineTo(size.width * 0.94, size.height * 0.12)
      ..lineTo(size.width * 1.08, size.height * 1.03)
      ..lineTo(size.width * 0.48, size.height * 1.03)
      ..close();
    canvas.drawPath(
      court,
      Paint()
        ..color = Color.alphaBlend(
          Cyber.cyan.withValues(alpha: 0.28),
          Cyber.bg2,
        ),
    );
    final line = Paint()
      ..color = AppTheme.textPrimary.withValues(alpha: 0.52)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(court, line);
    canvas.drawLine(
      Offset(size.width * 0.57, size.height * 0.57),
      Offset(size.width, size.height * 0.57),
      line,
    );
    canvas.drawLine(
      Offset(size.width * 0.75, size.height * 0.12),
      Offset(size.width * 0.67, size.height),
      line,
    );
    canvas.drawCircle(
      Offset(size.width * 0.83, size.height * 0.39),
      6,
      Paint()..color = accent,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.83, size.height * 0.78),
        width: 27,
        height: 9,
      ),
      Paint()
        ..color = accent.withValues(alpha: 0.36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant TennisMysterySignalPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

/// Shared circuit telemetry promoted from the Games hub Grand Prix card.
class F1MysterySignalPainter extends CustomPainter {
  const F1MysterySignalPainter({this.accent = Cyber.f1Red});

  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Cyber.bg.withValues(alpha: 0),
            Color.alphaBlend(accent.withValues(alpha: 0.2), Cyber.bg2),
          ],
          stops: const [0.36, 1],
        ).createShader(bounds),
    );

    final track = Path()
      ..moveTo(size.width * 0.70, -12)
      ..cubicTo(
        size.width * 1.01,
        size.height * 0.10,
        size.width * 0.68,
        size.height * 0.43,
        size.width * 0.84,
        size.height * 0.61,
      )
      ..cubicTo(
        size.width * 0.98,
        size.height * 0.78,
        size.width * 0.72,
        size.height * 0.87,
        size.width * 0.96,
        size.height * 1.08,
      );
    canvas.drawPath(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 42
        ..strokeCap = StrokeCap.round
        ..color = Cyber.border,
    );
    canvas.drawPath(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 46
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.22),
    );
    canvas.drawPath(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = AppTheme.textPrimary.withValues(alpha: 0.34),
    );

    final carCenter = Offset(size.width * 0.82, size.height * 0.60);
    final carBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: carCenter, width: 48, height: 18),
      const Radius.circular(5),
    );
    canvas.save();
    canvas.translate(carCenter.dx, carCenter.dy);
    canvas.rotate(-0.22);
    canvas.translate(-carCenter.dx, -carCenter.dy);
    canvas.drawRRect(carBody, Paint()..color = accent);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: carCenter.translate(2, 0),
          width: 17,
          height: 12,
        ),
        const Radius.circular(5),
      ),
      Paint()..color = Cyber.bg,
    );
    for (final dy in [-10.0, 10.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: carCenter.translate(-12, dy),
            width: 13,
            height: 5,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Cyber.bg,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: carCenter.translate(14, dy),
            width: 13,
            height: 5,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = Cyber.bg,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant F1MysterySignalPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}
```

### A.5 `lib/widgets/staggered_card_entrance.dart`

<sub>56 lines</sub>

```dart
import 'package:flutter/material.dart';

class StaggeredCardEntrance extends StatelessWidget {
  const StaggeredCardEntrance({
    required this.index,
    required this.animate,
    required this.child,
    this.maxAnimatedIndex = 7,
    this.slideOffset = 48,
    this.slideFromLeft = true,
    super.key,
  });

  final int index;
  final bool animate;
  final int maxAnimatedIndex;
  final double slideOffset;
  final bool slideFromLeft;
  final Widget child;

  static const _baseDuration = Duration(milliseconds: 320);
  static const _stagger = Duration(milliseconds: 70);

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.maybeOf(context);
    if (!animate ||
        index > maxAnimatedIndex ||
        (mediaQuery?.disableAnimations ?? false)) {
      return child;
    }

    final delay = Duration(milliseconds: _stagger.inMilliseconds * index);
    final duration = _baseDuration + delay;
    final delayFactor = delay.inMilliseconds / duration.inMilliseconds;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: Interval(delayFactor, 1, curve: Curves.easeOutCubic),
      builder: (context, value, animatedChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              (slideFromLeft ? -slideOffset : slideOffset) * (1 - value),
              0,
            ),
            child: animatedChild,
          ),
        );
      },
      child: child,
    );
  }
}
```

### A.6 `lib/widgets/streak_widgets.dart`

<sub>46 lines</sub>

```dart
// SUBSET of lib/widgets/streak_widgets.dart — StreakBadge verbatim.
import 'package:flutter/material.dart';

import '../config/theme.dart';

class StreakBadge extends StatelessWidget {
  const StreakBadge({
    required this.value,
    this.compact = false,
    this.scale = 1,
    super.key,
  }) : assert(scale > 0);

  final int value;
  final bool compact;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();
    return Semantics(
      label: '$value day streak',
      child: SizedBox(
        height: StreakTheme.badgeHeight * scale,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              color: StreakTheme.primary,
              size: StreakTheme.badgeIconSize * scale,
            ),
            if (!compact) SizedBox(width: StreakTheme.space4 * scale),
            if (!compact)
              Text(
                '$value',
                style: StreakTheme.badge(
                  color: StreakTheme.primary,
                ).apply(fontSizeFactor: scale),
              ),
          ],
        ),
      ),
    );
  }
}
```

### A.7 `lib/config/sport_modules.dart`

<sub>135 lines</sub>

```dart
import 'package:flutter/material.dart';

import '../models/sport_match.dart';
import 'theme.dart';

class SportModule {
  const SportModule({
    required this.sport,
    required this.label,
    required this.shortLabel,
    required this.systemCode,
    required this.icon,
    required this.accent,
    required this.availableModules,
  });

  final Sport sport;
  final String label;
  final String shortLabel;
  final String systemCode;
  final IconData icon;
  final Color accent;
  final List<String> availableModules;
}

const sportModules = <SportModule>[
  SportModule(
    sport: Sport.football,
    label: 'Football',
    shortLabel: 'FTBL',
    systemCode: 'SPORT://FOOTBALL',
    icon: Icons.sports_soccer,
    accent: Cyber.cyan,
    availableModules: ['MATCHES', 'PICKS', 'GAMES', 'CARDS'],
  ),
  SportModule(
    sport: Sport.cricket,
    label: 'Cricket',
    shortLabel: 'CRKT',
    systemCode: 'SPORT://CRICKET',
    icon: Icons.sports_cricket,
    accent: AppTheme.whiteColor,
    availableModules: ['MATCHES', 'PICKS', 'FOLLOWING'],
  ),
  SportModule(
    sport: Sport.motorsport,
    label: 'Motorsport',
    shortLabel: 'Motorsport',
    systemCode: 'SPORT://MOTORSPORT',
    icon: Icons.sports_motorsports,
    accent: Cyber.f1Red,
    availableModules: ['FOLLOWING', 'COMING SOON'],
  ),
  SportModule(
    sport: Sport.basketball,
    label: 'Basket',
    shortLabel: 'BALL',
    systemCode: 'SPORT://BASKETBALL',
    icon: Icons.sports_basketball,
    accent: Cyber.gold,
    availableModules: ['FOLLOWING', 'COMING SOON'],
  ),
  SportModule(
    sport: Sport.tennis,
    label: 'Tennis',
    shortLabel: 'TENNIS',
    systemCode: 'SPORT://TENNIS',
    icon: Icons.sports_tennis,
    accent: Cyber.lime,
    availableModules: ['FOLLOWING', 'COMING SOON'],
  ),
];

/// Tab order for the MATCH / GAMES / archive sport strip
/// (Football → Cricket → Basketball → Motorsport → Tennis).
///
/// Every other sport strip in the app mirrors this order — the collection,
/// leaderboard and shop each keep their own list because they show different
/// subsets, so a change here has to be made in all four.
const sportTabOrder = <Sport>[
  Sport.football,
  Sport.cricket,
  Sport.basketball,
  Sport.motorsport,
  Sport.tennis,
];

final sportTabLabels = sportTabOrder
    .map((sport) => sportModuleFor(sport).label.toUpperCase())
    .toList(growable: false);

final sportTabIcons = sportTabOrder
    .map((sport) => sportModuleFor(sport).icon)
    .toList(growable: false);

/// Canonical identity colors for sport tabs, in [sportTabOrder].
final sportTabColors = sportTabOrder
    .map((sport) => sportModuleFor(sport).accent)
    .toList(growable: false);

/// MATCH / GAMES hub index contract.
///
/// Trending is a real selectable destination. The trailing MORE action lives
/// one slot after the sports, but is never persisted as the active index.
const hubTrendingTabIndex = 0;
final hubMoreTabIndex = sportTabOrder.length + 1;

int hubIndexForSport(Sport sport) => sportTabOrder.indexOf(sport) + 1;

Sport? sportForHubIndex(int index) {
  final sportIndex = index - 1;
  if (sportIndex < 0 || sportIndex >= sportTabOrder.length) return null;
  return sportTabOrder[sportIndex];
}

enum SportHubMode { matches, games }

SportModule sportModuleFor(Sport sport) {
  for (final module in sportModules) {
    if (module.sport == sport) return module;
  }
  return sportModules.first;
}

Sport sportFromStorage(String? raw) {
  if (raw == null || raw.isEmpty) return Sport.football;
  // Pre-rename installs persisted the enum name 'f1'; keep resolving it to
  // the renamed Sport.motorsport so existing installs don't silently reset
  // to football.
  if (raw == 'f1') return Sport.motorsport;
  for (final sport in Sport.values) {
    if (sport.name == raw) return sport;
  }
  return Sport.football;
}
```

### A.8 `lib/config/theme.dart`

<sub>72 lines</sub>

```dart
// STAND-IN for lib/config/theme.dart — only the tokens the tiles read,
// resolved to the source app's literal values.
import 'package:flutter/material.dart';

class AppTheme {
  static const Color whiteColor = Color(0xFFFFFFFF);
  static const Color textPrimary = Color.fromRGBO(92, 223, 255, 1);
}

class Cyber {
  static const Color bg = Color.fromRGBO(13, 17, 26, 1);
  static const Color bg2 = Color.fromRGBO(7, 12, 31, 1);
  static const Color panel = Color.fromRGBO(29, 41, 61, 1);
  static const Color cyan = Color.fromRGBO(92, 223, 255, 1);
  static const Color lime = Color.fromRGBO(81, 255, 148, 1);
  static const Color gold = Color.fromRGBO(253, 199, 0, 1);
  static const Color amber = Color.fromRGBO(255, 137, 4, 1);
  static const Color danger = Color.fromRGBO(255, 77, 77, 1);
  static const Color violet = Color.fromRGBO(194, 122, 255, 1);
  static const Color border = Color.fromRGBO(49, 65, 88, 1);
  static const Color muted = Color.fromRGBO(144, 161, 185, 1);

  /// Grand Prix Dash brand accent (racing red).
  static const Color f1Red = Color(0xFFF42D29);

  static const String displayFont = 'Orbitron';

  static TextStyle display(
    double size, {
    Color color = Colors.white,
    double letterSpacing = 1.5,
    FontWeight weight = FontWeight.w900,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: 1,
    decoration: TextDecoration.none,
  );

  static TextStyle label(
    double size, {
    Color color = Colors.white,
    FontWeight weight = FontWeight.w800,
    double letterSpacing = 0.9,
    double height = 1,
    List<FontFeature>? fontFeatures,
  }) => TextStyle(
    color: color,
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    height: height,
    fontFeatures: fontFeatures,
    decoration: TextDecoration.none,
  );
}

/// Only the StreakTheme members StreakBadge reads (values verbatim).
class StreakTheme {
  static const Color primary = Cyber.gold;
  static const Color text = AppTheme.whiteColor;
  static const double space4 = 4;
  static const double badgeHeight = 26;
  static const double badgeIconSize = 16;

  static TextStyle badge({Color color = text}) =>
      Cyber.label(11, color: color, letterSpacing: 0.4);
}
```

### A.9 `lib/models/sport_match.dart`

<sub>2 lines</sub>

```dart
// STAND-IN for lib/models/sport_match.dart — only the Sport enum (verbatim).
enum Sport { football, cricket, motorsport, basketball, tennis }
```

### A.10 `test/arcade_trending_tiles_test.dart`

<sub>52 lines</sub>

```dart
import 'package:card_game/widgets/arcade_trending_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final width in [390.0, 320.0]) {
    testWidgets('arcade hero tiles render and route at ${width}px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final opened = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ArcadeTrendingGamesGrid(
              onOpenFinalOver: () => opened.add('final-over'),
              onOpenBasketball: () => opened.add('hoop-duel'),
              onOpenGrandPrix: () => opened.add('grand-prix'),
              onOpenTennisRally: () => opened.add('tennis-rally'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      const keys = {
        'trending-final-over-card': 'final-over',
        'trending-hoop-duel-card': 'hoop-duel',
        'trending-grand-prix-card': 'grand-prix',
        'trending-tennis-rally-card': 'tennis-rally',
      };
      for (final entry in keys.entries) {
        final tile = find.byKey(ValueKey(entry.key));
        expect(tile, findsOneWidget);
        await tester.tap(tile);
        expect(opened.last, entry.value);
      }
      expect(find.text('FINAL OVER'), findsOneWidget);
      expect(find.text('HOOP DUEL'), findsOneWidget);
      expect(find.text('GRAND PRIX'), findsOneWidget);
      expect(find.text('TENNIS RALLY'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // wide, square, square, wide → three rows in a two-column grid.
      final finalOver = tester.getSize(find.byKey(const ValueKey('trending-final-over-card')));
      final hoop = tester.getSize(find.byKey(const ValueKey('trending-hoop-duel-card')));
      expect(finalOver.width, greaterThan(hoop.width * 1.9));
    });
  }
}
```
