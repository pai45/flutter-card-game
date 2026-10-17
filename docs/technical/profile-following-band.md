# Profile "Following" band — implementation guide

This is a portable version of the StatOz profile screen's **following band**:
the strip under the profile hero that shows the player's home sport, their
favourite club per followed league, and a pencil button. The pencil opens an
**EDIT CLUBS** sheet.

The original is `_FollowingBand` and `_FollowingEditorSheet` in
`lib/screens/profile/profile_screen.dart`. The guide specifies the look and
behaviour. Appendix A is a drop-in implementation with no dependency on the
original app's theme, state management, storage or team-colour database.

The reference code was checked with `flutter analyze` (no issues). Widget
tests covered the band states and a full edit → save round trip. It was also
rendered with the real fonts:

![Reference render](profile-following-band.png)

*Top: a followed league with a favourite club (Red Bull Racing / F1). Bottom:
a followed league with no club picked yet.*

---

## 1. Anatomy

```
╱‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾╲   ← card: 12 px cut corners,
│  ┌────┐  ┌──────────────┐ ┌──────────────┐                ┌──┐ │     1 px outline, hard 5 px shadow
│  │ 🏎 │  │ [RBR] RBR    │ │ [LFC] LFC    │  …wraps…       │✎ │ │
│  └────┘  │       F1     │ │       EPL    │                └──┘ │
│  sport   └──────────────┘ └──────────────┘                edit │
╲___________________________________________________________________╱
   40×40     club chips (Wrap, 10 px gaps)                    32×32
```

| Part | Spec |
|---|---|
| **Card** | fill `#0F172B`, 1 px outline `#314158`, all 4 corners cut 12 px, hard shadow `#04060B` offset (0, 5) with no blur. Padding `LTRB(14, 12, 14, 14)`; 14 px gap below the band. No gradient, no glow |
| **Sport marker** | 40×40 square: sport accent @ 10 % fill, accent @ 50 % 1 px border, sport icon 20 px in the accent. Semantics label `"{Sport} clubs"` |
| **Club chip** | min width 86, padding `LTRB(9, 8, 10, 8)`, fill `#1D293D` @ 56 %, 1 px border `#45556C`. Contents: **team badge** 30×32, 8 px gap, then a column (max width 58) of the **short name** (Orbitron w900 12, team UI colour, 1 line, ellipsis), 2 px gap, **league code** (Orbitron w800 8, `#90A1B9`, letter-spacing 1.1) |
| **League-only chip** (followed, no club) | same box, but fill = league accent @ 8 %, border = league accent @ 50 %. Contents: `bookmark_added_outlined` icon 22 px in the league accent, 8 px gap, league code (Orbitron w900 12, white) over `NO CLUB` (Orbitron w800 8, muted, letter-spacing 0.8) |
| **Empty state** | when nothing is followed: *"Pick the teams and clubs you follow."* (Onest 13, `#90A1B9`) in place of the chips |
| **Edit button** | 32×32 square: cyan `#5CDFFF` @ 12 % fill, 1 px border `#087B95`, `Icons.edit` 16 px cyan. Semantics: button, `"Edit followed teams"` |
| Row | marker, 10 px, `Expanded(chips)`, 10 px, edit button; vertically centred |

### Team badge

The badge is drawn in code, not an image:

1. **Body**: an octagon whose corners are cut by 15 % of the badge's short
   side, filled with the team's **primary** colour. It takes the top 90 % of
   the height.
2. **Hard base**: the same octagon shifted down by the remaining 10 %, filled
   with `lerp(primary, black, 0.58)`, and drawn first so it peeks out
   underneath.
3. **Accent band**: a strip 11 % of the body height along the bottom, in the
   team's **secondary** colour, clipped to the octagon.
4. **Label**: the short name in Onest w700, colour = the palette's text colour.
   - Font size = width × 0.38 for up to 2 characters, 0.33 for 3, 0.28 for
     4 or more.
   - Centred in the area above the band, nudged down 4 %.
5. Width is capped at 1.1 × height, so a badge never turns into a banner.

### Team colours (`TeamPalette`)

| Field | Use | Red Bull Racing (screenshot) |
|---|---|---|
| `primary` | badge fill | `#3671C6` |
| `text` | badge label | `#FFFFFF` |
| `secondary` | badge accent band | `#121F45` |
| `uiColor` | the club's short name in the chip, club names in the editor | `#6291D4` |

The app gets these from a generated per-team palette database. When you only
have one brand colour, `TeamPalette.derive(color)` rebuilds the same recipe:

- `text`: white or black, whichever contrasts more with `primary`.
- `secondary`: `primary` stepped toward white (dark colours) or black (light
  colours) until it reaches a 2.6:1 contrast with `primary`.
- `uiColor`: the closest **chromatic** candidate (primary first, then
  secondary) whose lightness is raised only as far as needed to reach
  **4.5:1** against every dark surface (`#0D111A`, `#0F172B`, `#1D293D`,
  `#10192D`). This keeps navy or black kits readable on the dark card.

---

## 2. Behaviour

### What the band shows

Inputs: the **home sport**, the **followed league ids** (in order) and
**favourite clubs** (`leagueId → teamId`).

- The sport marker always shows the home sport.
- There is one chip per followed league id, in order:
  - with a favourite club → **club chip**;
  - without one → **league-only chip** ("NO CLUB");
  - ids the catalog doesn't know are skipped silently.
- Chips wrap onto extra lines when there are many, and the card grows.
- The band is static chrome. It only responds to the pencil.

### Pencil → EDIT CLUBS sheet

- **Opening it:** a scroll-controlled modal bottom sheet, **86 % of screen
  height**. The modal's own background is transparent and the sheet paints
  `#0D111A`.
  - The header reads **EDIT CLUBS** (Orbitron w900 16, cyan), with a close ✕
    (muted) on the right.
- **Sport pills** (horizontal list, 48 px tall, 8 px gaps): every sport.
  - Selected: accent border 2 px @ 90 %, fill `#1D293D` @ 76 %, a soft accent
    glow (alpha 0.14, blur 12, spread −3), white label.
  - Others: 1 px border at the accent @ 45 %, fill @ 48 %, muted label.
  - Contents: icon 18 px (accent, or accent @ 62 % when unselected), 7 px
    gap, label in Orbitron w800 10 with letter-spacing 1.0. Changes animate
    over 150 ms.
- **League pills** (horizontal list, 96 px tall, 10 px gaps, 106 px wide,
  padding 8):
  - Top row: short code (Orbitron w900 13) and a checkbox icon 18 px.
  - Bottom: full name (Orbitron w800 8, muted, 2 lines).
  - Accent = lime `#51FF94` if followed, else cyan.
  - Active pill: full `#1D293D` fill and a 1.5 px accent border, with the code
    in the accent. Others: fill @ 58 %, 1 px `#45556C` border, muted code.
  - The league row shows **even for single-league sports**, unlike the
    onboarding wizard.
- **Club grid** (3 columns, 10 px spacing, aspect 0.92, padding
  `LTRB(16, 0, 16, 16)`):
  - Tile padding 6×8: badge 40×44, 7 px gap, name in Orbitron w800 8 (team UI
    colour, or white when selected), 1 line.
  - Selected: 2 px lime border and a **30×30 lime check seal top-left**.
  - Unselected: 1 px `#45556C` border.
  - Fill `#1D293D` @ 72 % when the league is followed, @ 38 % (dimmed) when
    not. Changes animate over 150 ms.
- **SAVE**: a full-width square button with a cyan fill, label in `#0D111A`
  (Orbitron w900 13) and 14 px vertical padding. It reads **SAVING** and is
  disabled (`#45556C`) while saving.

### Editor rules

| Action | Effect |
|---|---|
| Open | starts on the first followed league of the home sport, else that sport's first league |
| Tap another **sport** | that sport becomes the home sport; **all** follows and favourites clear; shows its first league |
| Tap a **league pill body** | shows that league's clubs (doesn't change follows) |
| Tap a **league checkbox** (unfollowed) | follows it, makes its **first club** the favourite, shows it |
| Tap a **league checkbox** (followed) | unfollows it and drops its favourite. If it was being shown, switches to the first followed league, else the sport's first league |
| Tap a **club** | follows the shown league (even if it was dimmed) and makes this club its favourite; one favourite per league |
| **SAVE** | sends home sport + followed leagues (**the current sport's only, in catalog order**) + favourites (only for followed leagues), then closes the sheet and returns `true` |
| ✕ / swipe down | closes without saving (`false` / `null`) |

Saving with nothing followed is allowed; the band then shows its empty state.

### After saving

The original app then:

1. writes home sport, followed league ids and favourite teams to storage;
2. reloads the band;
3. refreshes the match feed, so its **"YOUR CLUB"** pin follows the new
   favourites.

In the port, `onSave` does the persisting, and the caller reloads when
`showFollowingEditor` returns `true`. See §3.

---

## 3. Using it

Copy the four files from Appendix A into one folder, e.g.
`lib/profile/following/`. Requirements:

- Flutter 3.27+ / Dart 3.7+, because the code uses `Color.withValues` and
  `(_, _)` wildcard parameters. On older versions, swap in `withOpacity` and
  `(_, __)`.
- No extra packages.
- The **Orbitron** and **Onest** fonts (Google Fonts) declared in
  `pubspec.yaml`. Without them the layout still works but the look is off.

```dart
// In your profile screen's State:
FollowingSelection _following = const FollowingSelection(
  primarySportId: 'motorsport',
  followedLeagueIds: ['formula1'],
  favoriteTeams: {'formula1': 'rbr'},
);

@override
Widget build(BuildContext context) {
  return Column(
    children: [
      // …profile hero…
      FollowingBand(
        catalog: followingCatalog,
        selection: _following,
        onEdit: _editFollowing,
      ),
      // …rest of the profile…
    ],
  );
}

Future<void> _editFollowing() async {
  final saved = await showFollowingEditor(
    context,
    catalog: followingCatalog,
    initial: _following,
    onSave: followingRepository.save, // Future<void> Function(FollowingSelection)
  );
  if (saved != true || !mounted) return;
  final fresh = await followingRepository.load();
  setState(() => _following = fresh);
  // Refresh anything keyed on favourite clubs (StatOz: the match feed pin).
}
```

### Catalog

```dart
const followingCatalog = FollowingCatalog(
  sports: [ // order = editor pill order
    SportOption(id: 'football',   label: 'Football',   icon: Icons.sports_soccer,      accent: Color(0xFF5CDFFF)),
    SportOption(id: 'cricket',    label: 'Cricket',    icon: Icons.sports_cricket,     accent: Color(0xFFFFFFFF)),
    SportOption(id: 'motorsport', label: 'Motorsport', icon: Icons.sports_motorsports, accent: Color(0xFFF42D29)),
    SportOption(id: 'basketball', label: 'Basket',     icon: Icons.sports_basketball,  accent: Color(0xFFFDC700)),
    SportOption(id: 'tennis',     label: 'Tennis',     icon: Icons.sports_tennis,      accent: Color(0xFF51FF94)),
  ],
  leagues: [
    LeagueOption(
      id: 'formula1', sportId: 'motorsport', name: 'Formula 1', shortCode: 'F1',
      accent: Color(0xFFFF4FD8),
      teams: [
        TeamOption(
          id: 'rbr', name: 'Red Bull Racing', shortName: 'RBR', color: Color(0xFF263BFF),
          palette: TeamPalette(primary: Color(0xFF3671C6), text: Color(0xFFFFFFFF),
                               secondary: Color(0xFF121F45), uiColor: Color(0xFF6291D4)),
        ),
        TeamOption(id: 'fer', name: 'Ferrari', shortName: 'FER', color: Color(0xFFDC0000)), // palette derived
      ],
    ),
    LeagueOption(
      id: 'epl', sportId: 'football', name: 'English Premier League', shortCode: 'EPL',
      accent: Color(0xFFA855F7),
      teams: [/* … */],
    ),
  ],
);
```

**Data rules:** every sport needs at least one league and every league at
least one team. Store the three `FollowingSelection` fields together; the band
tolerates stale league or team ids.

---

## 4. Design rules to keep

- **No glow on the band.** It's always-on chrome, so depth comes from the flat
  fill, the outline and the hard shadow. The only glow anywhere in this
  feature is the selected sport pill in the editor.
- **Square corners on the chips and buttons, cut corners on the card.** No
  rounded rects.
- **Colour roles:**
  - the sport accent identifies the sport;
  - lime means followed / selected;
  - cyan means the action (edit, save, active unfollowed pill);
  - the team's UI colour is for team names only.
- **UPPERCASE** codes and labels, in Orbitron with letter-spacing.

---

## 5. Accessibility

- The sport marker announces `"{Sport} clubs"`.
- The edit button is a button labelled `"Edit followed teams"`.
- Every editor control is a labelled button with a selected state:
  - sport pills: sport name;
  - league pills: league name, selected = followed;
  - club tiles: club name, selected = favourite.
- Club short names and editor club names use the contrast-checked `uiColor`
  (≥ 4.5:1 on all dark surfaces).
- Touch targets:
  - The **edit button is 32×32 and the league checkbox icon 18×18**, below the
    48 dp guideline. Both match the original. If your project enforces 48 dp,
    pad their hit areas without changing the visuals.

---

## 6. Differences from the original

| Original (StatOz) | Reference implementation |
|---|---|
| The band reads the home sport from secure storage and follows from a `PredictionCubit` | `FollowingBand` takes a `FollowingSelection`; you own loading |
| The sheet writes to storage itself | `onSave` callback; the sheet shows SAVING while it runs |
| Team colours from a generated palette database with per-competition variants | `TeamOption.palette`, or `TeamPalette.derive(color)` |
| `TeamLogo` shows nationality flags / emoji for **tennis** players | not ported; tennis players get the short-name badge |
| Badge label uses the app's current body font (Onest, or Exo 2 inside game screens) | Onest |
| League pills in the sheet had no semantics wrapper; ✕ had no tooltip | both added |
| `ProfileCard` / `CutChipBorder` | `FollowingCard` / `CutCornerBorder` (same geometry) |

---

## 7. Acceptance checklist

- [ ] With home sport Motorsport and Red Bull Racing followed in F1, the band
      matches the reference render: red helmet marker, RBR badge with a dark
      base, `RBR` in `#6291D4`, `F1` muted, cyan pencil.
- [ ] A followed league without a club shows the bookmark "NO CLUB" chip in
      the league's accent.
- [ ] Nothing followed → *"Pick the teams and clubs you follow."*
- [ ] An unknown league id in the selection is skipped without errors.
- [ ] Many follows wrap onto new lines; the card grows; no overflow at 320 px.
- [ ] Pencil → EDIT CLUBS at 86 % height, starting on the home sport's first
      followed league.
- [ ] Switching sport in the sheet clears all picks.
- [ ] Tapping a club in a dimmed (unfollowed) league follows it.
- [ ] Following a league preselects its first club. Unfollowing the shown
      league moves the view to another league.
- [ ] SAVE → `onSave` receives the current sport, its followed leagues in
      catalog order and only their favourites. The sheet returns `true` and
      the band updates.
- [ ] ✕ or swipe-down saves nothing.

---

## Appendix A — reference implementation

Four files, about 1,100 lines, all in one folder (imports are relative).

| File | Contents |
|---|---|
| `following_theme.dart` | `FollowTokens`: colours, text styles, glow |
| `following_models.dart` | `SportOption`, `LeagueOption`, `TeamOption`, `TeamPalette` (+ `derive` / contrast helper), `FollowingCatalog`, `FollowingSelection` |
| `following_band.dart` | `FollowingBand`, `FollowingCard`, `CutCornerBorder`, chips, edit button, `TeamBadge` + painter |
| `following_editor_sheet.dart` | `showFollowingEditor`, `FollowingEditorSheet`, sport / league pills, club tiles |

### A.1 Tokens — `following_theme.dart`

```dart
import 'package:flutter/material.dart';

/// Colour + type tokens for the following band and its editor (the StatOz
/// "Cyber" palette flattened to plain values).
abstract final class FollowTokens {
  static const bg = Color(0xFF0D111A); // page / sheet background
  static const card = Color(0xFF0F172B); // band surface
  static const panel = Color(0xFF1D293D); // chips, pills, tiles
  static const chartSurface = Color(0xFF10192D); // contrast check only
  static const border = Color(0xFF314158); // band outline
  static const line = Color(0xFF45556C); // chip / tile outline
  static const shadow = Color(0xFF04060B); // hard drop shadow
  static const muted = Color(0xFF90A1B9);
  static const white = Color(0xFFFFFFFF);
  static const cyan = Color(0xFF5CDFFF);
  static const cyanEdge = Color(0xFF087B95); // edit button border
  static const lime = Color(0xFF51FF94); // followed / selected

  static const displayFont = 'Orbitron';
  static const bodyFont = 'Onest';

  static TextStyle display(double size, {Color color = white}) => TextStyle(
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: 1.5,
    height: 1,
    decoration: TextDecoration.none,
  );

  static TextStyle label(
    double size, {
    Color color = white,
    double letterSpacing = 0.9,
  }) => TextStyle(
    fontFamily: displayFont,
    fontSize: size,
    fontWeight: FontWeight.w800,
    color: color,
    letterSpacing: letterSpacing,
    height: 1,
    decoration: TextDecoration.none,
  );

  static TextStyle body(double size, {Color color = white}) => TextStyle(
    fontFamily: bodyFont,
    fontSize: size,
    fontWeight: FontWeight.w500,
    color: color,
    height: 1.35,
    decoration: TextDecoration.none,
  );

  static List<BoxShadow> glow(
    Color color, {
    double alpha = 0.3,
    double blur = 16,
    double spread = -2,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: alpha),
      blurRadius: blur,
      spreadRadius: spread,
    ),
  ];
}
```

### A.2 Models + team palette — `following_models.dart`

```dart
import 'package:flutter/material.dart';

import 'following_theme.dart';

class SportOption {
  const SportOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String id; // e.g. 'motorsport'
  final String label; // e.g. 'Motorsport'
  final IconData icon;
  final Color accent; // sport identity colour
}

/// Badge colours for one team.
class TeamPalette {
  const TeamPalette({
    required this.primary,
    required this.text,
    required this.secondary,
    required this.uiColor,
  });

  /// Badge fill.
  final Color primary;

  /// Label on the badge.
  final Color text;

  /// Accent band along the bottom of the badge.
  final Color secondary;

  /// Team colour for text on the dark HUD (e.g. the chip's short name),
  /// guaranteed 4.5:1 against every dark surface.
  final Color uiColor;

  /// Derives a full palette from one brand colour.
  factory TeamPalette.derive(Color primary) {
    final text =
        _contrast(primary, Colors.white) >= _contrast(primary, Colors.black)
        ? Colors.white
        : Colors.black;
    final lighten = primary.computeLuminance() < 0.35;
    var accent = primary;
    for (var i = 0; i < 80 && _contrast(accent, primary) < 2.6; i++) {
      accent = lighten
          ? Color.lerp(accent, Colors.white, 0.05)!
          : Color.lerp(accent, Colors.black, 0.07)!;
    }
    return TeamPalette(
      primary: primary,
      text: text,
      secondary: accent,
      uiColor: accessibleUiColor(primary, accent),
    );
  }

  /// The closest chromatic team colour that clears 4.5:1 against every dark
  /// surface the band can sit on (lifting lightness only as far as needed).
  static Color accessibleUiColor(Color primary, Color secondary) {
    final candidates = [primary, secondary];
    final chromatic = candidates
        .where((c) => HSLColor.fromColor(c).saturation >= 0.15)
        .toList();
    Color? best;
    var bestLift = double.infinity;
    for (final candidate in chromatic.isEmpty ? candidates : chromatic) {
      final hsl = HSLColor.fromColor(candidate);
      if (_minSurfaceContrast(candidate) >= 4.5) return candidate;
      var low = hsl.lightness;
      var high = 1.0;
      for (var i = 0; i < 32; i++) {
        final mid = (low + high) / 2;
        if (_minSurfaceContrast(hsl.withLightness(mid).toColor()) >= 4.5) {
          high = mid;
        } else {
          low = mid;
        }
      }
      final lift = high - hsl.lightness;
      if (lift < bestLift) {
        best = hsl.withLightness(high).toColor();
        bestLift = lift;
      }
    }
    return best!;
  }

  static double _minSurfaceContrast(Color color) => [
    FollowTokens.bg,
    FollowTokens.card,
    FollowTokens.panel,
    FollowTokens.chartSurface,
  ].map((s) => _contrast(color, s)).reduce((a, b) => a < b ? a : b);

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }
}

class TeamOption {
  const TeamOption({
    required this.id,
    required this.name,
    required this.shortName,
    required this.color,
    this.palette,
  });

  final String id;
  final String name;
  final String shortName; // 2-4 letters, drawn on the badge
  final Color color; // brand colour (used when [palette] is null)
  final TeamPalette? palette;

  TeamPalette get resolvedPalette => palette ?? TeamPalette.derive(color);
}

class LeagueOption {
  const LeagueOption({
    required this.id,
    required this.sportId,
    required this.name,
    required this.shortCode,
    required this.accent,
    required this.teams,
  });

  final String id;
  final String sportId;
  final String name;
  final String shortCode; // e.g. 'F1', 'EPL'
  final Color accent; // tints the "NO CLUB" chip
  final List<TeamOption> teams;
}

/// Every sport needs at least one league; every league at least one team.
class FollowingCatalog {
  const FollowingCatalog({required this.sports, required this.leagues});

  final List<SportOption> sports;
  final List<LeagueOption> leagues;

  SportOption sportById(String id) =>
      sports.firstWhere((s) => s.id == id, orElse: () => sports.first);

  List<LeagueOption> leaguesFor(String sportId) => [
    for (final league in leagues)
      if (league.sportId == sportId) league,
  ];

  LeagueOption? leagueById(String id) {
    for (final league in leagues) {
      if (league.id == id) return league;
    }
    return null;
  }

  TeamOption? teamById(String leagueId, String teamId) {
    for (final team in leagueById(leagueId)?.teams ?? const <TeamOption>[]) {
      if (team.id == teamId) return team;
    }
    return null;
  }
}

/// What the player follows. Persist all three fields together.
class FollowingSelection {
  const FollowingSelection({
    required this.primarySportId,
    required this.followedLeagueIds,
    required this.favoriteTeams,
  });

  final String primarySportId;

  /// Followed league ids, in catalog order after an edit.
  final List<String> followedLeagueIds;

  /// leagueId → teamId (at most one favourite club per followed league).
  final Map<String, String> favoriteTeams;
}
```

### A.3 The band — `following_band.dart`

```dart
import 'package:flutter/material.dart';

import 'following_models.dart';
import 'following_theme.dart';

/// Compact "following" strip for a profile page:
/// `[sport marker] [club chips…] [edit]`. Static chrome — nothing glows.
class FollowingBand extends StatelessWidget {
  const FollowingBand({
    required this.catalog,
    required this.selection,
    required this.onEdit,
    super.key,
  });

  final FollowingCatalog catalog;
  final FollowingSelection selection;
  final VoidCallback onEdit;

  /// One entry per followed league the catalog knows (unknown ids are
  /// skipped), with its favourite club when one is set.
  List<(LeagueOption, TeamOption?)> get _entries => [
    for (final leagueId in selection.followedLeagueIds)
      if (catalog.leagueById(leagueId) case final league?)
        (
          league,
          switch (selection.favoriteTeams[leagueId]) {
            final teamId? => catalog.teamById(leagueId, teamId),
            null => null,
          },
        ),
  ];

  @override
  Widget build(BuildContext context) {
    final sport = catalog.sportById(selection.primarySportId);
    final entries = _entries;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: FollowingCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Row(
          children: [
            _SportMarker(sport: sport),
            const SizedBox(width: 10),
            Expanded(
              child: entries.isEmpty
                  ? Text(
                      'Pick the teams and clubs you follow.',
                      style: FollowTokens.body(13, color: FollowTokens.muted),
                    )
                  : Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final (league, team) in entries)
                          if (team == null)
                            _LeagueOnlyChip(league: league)
                          else
                            _TeamChip(team: team, league: league),
                      ],
                    ),
            ),
            const SizedBox(width: 10),
            _EditButton(onTap: onEdit),
          ],
        ),
      ),
    );
  }
}

/// Elevated profile surface: flat card fill, 12 px cut corners, 1 px outline
/// and a hard (un-blurred) 5 px drop shadow. No gradient, no glow.
class FollowingCard extends StatelessWidget {
  const FollowingCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const ShapeDecoration(
        color: FollowTokens.card,
        shape: CutCornerBorder(
          cut: 12,
          side: BorderSide(color: FollowTokens.border),
        ),
        shadows: [BoxShadow(color: FollowTokens.shadow, offset: Offset(0, 5))],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Octagon outline: every corner cut by [cut].
class CutCornerBorder extends ShapeBorder {
  const CutCornerBorder({required this.cut, this.side = BorderSide.none});

  final double cut;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  ShapeBorder scale(double t) =>
      CutCornerBorder(cut: cut * t, side: side.scale(t));

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect.deflate(side.width), textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      octagonPath(rect, cut.clamp(0, rect.shortestSide / 2).toDouble());

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      getOuterPath(rect.deflate(side.width / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side.width
        ..color = side.color,
    );
  }
}

Path octagonPath(Rect rect, double cut) => Path()
  ..moveTo(rect.left + cut, rect.top)
  ..lineTo(rect.right - cut, rect.top)
  ..lineTo(rect.right, rect.top + cut)
  ..lineTo(rect.right, rect.bottom - cut)
  ..lineTo(rect.right - cut, rect.bottom)
  ..lineTo(rect.left + cut, rect.bottom)
  ..lineTo(rect.left, rect.bottom - cut)
  ..lineTo(rect.left, rect.top + cut)
  ..close();

/// 40 × 40 home-sport marker: sport icon in its accent on a 10 % wash.
class _SportMarker extends StatelessWidget {
  const _SportMarker({required this.sport});

  final SportOption sport;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${sport.label} clubs',
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sport.accent.withValues(alpha: 0.1),
          border: Border.all(color: sport.accent.withValues(alpha: 0.5)),
        ),
        child: Icon(sport.icon, color: sport.accent, size: 20),
      ),
    );
  }
}

/// Favourite club: badge + short name (team UI colour) over the league code.
class _TeamChip extends StatelessWidget {
  const _TeamChip({required this.team, required this.league});

  final TeamOption team;
  final LeagueOption league;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.fromLTRB(9, 8, 10, 8),
      decoration: BoxDecoration(
        color: FollowTokens.panel.withValues(alpha: 0.56),
        border: Border.all(color: FollowTokens.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TeamBadge(team: team, width: 30, height: 32),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 58),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  team.shortName.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FollowTokens.display(
                    12,
                    color: team.resolvedPalette.uiColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  league.shortCode,
                  style: FollowTokens.label(
                    8,
                    color: FollowTokens.muted,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A followed league with no favourite club yet.
class _LeagueOnlyChip extends StatelessWidget {
  const _LeagueOnlyChip({required this.league});

  final LeagueOption league;

  @override
  Widget build(BuildContext context) {
    final accent = league.accent;
    return Container(
      constraints: const BoxConstraints(minWidth: 86),
      padding: const EdgeInsets.fromLTRB(9, 8, 10, 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_added_outlined, color: accent, size: 22),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(league.shortCode, style: FollowTokens.display(12)),
              const SizedBox(height: 2),
              Text(
                'NO CLUB',
                style: FollowTokens.label(
                  8,
                  color: FollowTokens.muted,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 32 × 32 pencil button that opens the editor.
class _EditButton extends StatelessWidget {
  const _EditButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Edit followed teams',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FollowTokens.cyan.withValues(alpha: 0.12),
            border: Border.all(color: FollowTokens.cyanEdge),
          ),
          child: const Icon(Icons.edit, color: FollowTokens.cyan, size: 16),
        ),
      ),
    );
  }
}

/// Club badge: an octagon in the team colour sitting on a darker "hard base"
/// (offset 10 % down), a secondary-colour band along its bottom edge and the
/// short name centred above the band. Width is capped at 1.1 × height.
class TeamBadge extends StatelessWidget {
  const TeamBadge({
    required this.team,
    required this.width,
    required this.height,
    super.key,
  });

  final TeamOption team;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width < height * 1.1 ? width : height * 1.1,
      height: height,
      child: CustomPaint(
        painter: TeamBadgePainter(
          label: team.shortName,
          palette: team.resolvedPalette,
        ),
      ),
    );
  }
}

class TeamBadgePainter extends CustomPainter {
  const TeamBadgePainter({required this.label, required this.palette});

  final String label;
  final TeamPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final bodyHeight = size.height * 0.9;
    final cut = size.shortestSide * 0.15;
    final body = octagonPath(Rect.fromLTWH(0, 0, size.width, bodyHeight), cut);

    // Hard base: the same octagon, shifted down and darkened.
    canvas.drawPath(
      body.shift(Offset(0, size.height - bodyHeight)),
      Paint()..color = Color.lerp(palette.primary, Colors.black, 0.58)!,
    );
    canvas.drawPath(body, Paint()..color = palette.primary);

    // Secondary band along the bottom, clipped to the octagon.
    final band = bodyHeight * 0.11;
    canvas
      ..save()
      ..clipPath(body)
      ..drawRect(
        Rect.fromLTWH(0, bodyHeight - band, size.width, band),
        Paint()..color = palette.secondary,
      )
      ..restore();

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: palette.text,
          fontFamily: FollowTokens.bodyFont,
          fontSize:
              size.width *
              switch (label.length) {
                <= 2 => 0.38,
                3 => 0.33,
                _ => 0.28,
              },
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);
    final labelBand = bodyHeight - band;
    text.paint(
      canvas,
      Offset(
        (size.width - text.width) / 2,
        (labelBand - text.height) / 2 + labelBand * 0.04,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant TeamBadgePainter old) =>
      old.label != label ||
      old.palette.primary != palette.primary ||
      old.palette.text != palette.text ||
      old.palette.secondary != palette.secondary;
}
```

### A.4 The EDIT CLUBS sheet — `following_editor_sheet.dart`

```dart
import 'package:flutter/material.dart';

import 'following_band.dart';
import 'following_models.dart';
import 'following_theme.dart';

/// Opens the EDIT CLUBS sheet. [onSave] persists the new selection (the SAVE
/// button reads SAVING meanwhile). Resolves to true when the player saved,
/// false / null when they closed or swiped it away.
Future<bool?> showFollowingEditor(
  BuildContext context, {
  required FollowingCatalog catalog,
  required FollowingSelection initial,
  required Future<void> Function(FollowingSelection selection) onSave,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FollowingEditorSheet(
      catalog: catalog,
      initial: initial,
      onSave: onSave,
    ),
  );
}

class FollowingEditorSheet extends StatefulWidget {
  const FollowingEditorSheet({
    required this.catalog,
    required this.initial,
    required this.onSave,
    super.key,
  });

  final FollowingCatalog catalog;
  final FollowingSelection initial;
  final Future<void> Function(FollowingSelection selection) onSave;

  @override
  State<FollowingEditorSheet> createState() => _FollowingEditorSheetState();
}

class _FollowingEditorSheetState extends State<FollowingEditorSheet> {
  FollowingCatalog get _catalog => widget.catalog;

  late String _sportId = widget.initial.primarySportId;
  late final Set<String> _followed = widget.initial.followedLeagueIds.toSet();
  late final Map<String, String> _favorites = Map.of(
    widget.initial.favoriteTeams,
  );
  late String _activeLeagueId = _initialActiveLeagueId();
  bool _saving = false;

  List<LeagueOption> get _leagues => _catalog.leaguesFor(_sportId);

  LeagueOption get _activeLeague =>
      _catalog.leagueById(_activeLeagueId) ?? _leagues.first;

  /// Opens on the first followed league of the home sport, else its first.
  String _initialActiveLeagueId() {
    for (final id in _followed) {
      if (_catalog.leagueById(id)?.sportId == _sportId) return id;
    }
    return _leagues.first.id;
  }

  /// Switching sport clears every follow and favourite.
  void _selectSport(String sportId) {
    if (_sportId == sportId) return;
    setState(() {
      _sportId = sportId;
      _followed.clear();
      _favorites.clear();
      _activeLeagueId = _leagues.first.id;
    });
  }

  /// Checkbox: follow (first club becomes the favourite, league shown) or
  /// unfollow (favourite dropped; if it was shown, fall back to another).
  void _toggleLeague(LeagueOption league) {
    setState(() {
      if (_followed.remove(league.id)) {
        _favorites.remove(league.id);
        if (_activeLeagueId == league.id) {
          _activeLeagueId = _followed.isNotEmpty
              ? _followed.first
              : _leagues.first.id;
        }
      } else {
        _followed.add(league.id);
        _favorites[league.id] = league.teams.first.id;
        _activeLeagueId = league.id;
      }
    });
  }

  /// Picking a club follows the shown league and makes it the favourite.
  void _selectTeam(String teamId) {
    setState(() {
      _followed.add(_activeLeague.id);
      _favorites[_activeLeague.id] = teamId;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    // Catalog order, current sport only; favourites only for followed leagues.
    final ordered = [
      for (final league in _leagues)
        if (_followed.contains(league.id)) league.id,
    ];
    await widget.onSave(
      FollowingSelection(
        primarySportId: _sportId,
        followedLeagueIds: ordered,
        favoriteTeams: {
          for (final id in ordered)
            if (_favorites[id] != null) id: _favorites[id]!,
        },
      ),
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeLeague;
    final selectedTeamId = _favorites[active.id];
    return FractionallySizedBox(
      heightFactor: 0.86,
      child: ColoredBox(
        color: FollowTokens.bg,
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: Row(
                  children: [
                    Text(
                      'EDIT CLUBS',
                      style: FollowTokens.display(16, color: FollowTokens.cyan),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close, color: FollowTokens.muted),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _catalog.sports.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final sport = _catalog.sports[index];
                    return _SportPill(
                      sport: sport,
                      selected: sport.id == _sportId,
                      onTap: () => _selectSport(sport.id),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: _leagues.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final league = _leagues[index];
                    return _LeaguePill(
                      league: league,
                      active: league.id == _activeLeagueId,
                      followed: _followed.contains(league.id),
                      onTap: () => setState(() => _activeLeagueId = league.id),
                      onToggle: () => _toggleLeague(league),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: active.teams.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.92,
                  ),
                  itemBuilder: (context, index) {
                    final team = active.teams[index];
                    return _TeamTile(
                      team: team,
                      selected: team.id == selectedTeamId,
                      enabled: _followed.contains(active.id),
                      onTap: () => _selectTeam(team.id),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FollowTokens.cyan,
                    foregroundColor: FollowTokens.bg,
                    disabledBackgroundColor: FollowTokens.line,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving ? 'SAVING' : 'SAVE',
                    style: FollowTokens.display(13, color: FollowTokens.bg),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportPill extends StatelessWidget {
  const _SportPill({
    required this.sport,
    required this.selected,
    required this.onTap,
  });

  final SportOption sport;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = sport.accent.withValues(alpha: selected ? 1 : 0.62);
    return Semantics(
      button: true,
      selected: selected,
      label: sport.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: FollowTokens.panel.withValues(alpha: selected ? 0.76 : 0.48),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.9 : 0.45),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? FollowTokens.glow(
                    sport.accent,
                    alpha: 0.14,
                    blur: 12,
                    spread: -3,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(sport.icon, color: color, size: 18),
              const SizedBox(width: 7),
              Text(
                sport.label.toUpperCase(),
                style: FollowTokens.label(
                  10,
                  color: selected ? FollowTokens.white : FollowTokens.muted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 106 px pill: body tap shows the league's clubs; checkbox follows it.
class _LeaguePill extends StatelessWidget {
  const _LeaguePill({
    required this.league,
    required this.active,
    required this.followed,
    required this.onTap,
    required this.onToggle,
  });

  final LeagueOption league;
  final bool active;
  final bool followed;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final accent = followed ? FollowTokens.lime : FollowTokens.cyan;
    return Semantics(
      button: true,
      selected: followed,
      label: league.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 106,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active
                ? FollowTokens.panel
                : FollowTokens.panel.withValues(alpha: 0.58),
            border: Border.all(
              color: active ? accent : FollowTokens.line,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      league.shortCode,
                      style: FollowTokens.display(
                        13,
                        color: active ? accent : FollowTokens.muted,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onToggle,
                    child: Icon(
                      followed ? Icons.check_box : Icons.check_box_outline_blank,
                      color: accent,
                      size: 18,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                league.name.toUpperCase(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: FollowTokens.label(
                  8,
                  color: FollowTokens.muted,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({
    required this.team,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final TeamOption team;
  final bool selected;
  final bool enabled; // league followed — otherwise dimmed (still tappable)
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: team.name,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: FollowTokens.panel.withValues(alpha: enabled ? 0.72 : 0.38),
            border: Border.all(
              color: selected ? FollowTokens.lime : FollowTokens.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Center(child: TeamBadge(team: team, width: 40, height: 44)),
                  const SizedBox(height: 7),
                  Text(
                    team.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: FollowTokens.label(
                      8,
                      color: selected
                          ? FollowTokens.white
                          : team.resolvedPalette.uiColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              if (selected)
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  color: FollowTokens.lime,
                  child: const Icon(
                    Icons.check,
                    color: FollowTokens.bg,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
```
