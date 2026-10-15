# Football Shot Map — implementation and porting reference

> **Status:** BUILT
> **Last verified:** 2026-09-12
> **Scope:** `FootballShotMapPanel` and the nine types around it in
> [`lib/screens/predictions/widgets/football_shot_map.dart`](../../lib/screens/predictions/widgets/football_shot_map.dart),
> plus the shared goal-mouth painter in
> [`lib/widgets/cyber/goal_mouth.dart`](../../lib/widgets/cyber/goal_mouth.dart)
> — the `SHOT MAP` panel on a football match's **STATS → MOMENTUM** tab.

**Written to be portable.** Every widget, painter, frame and model is reproduced
*exactly as implemented*, in the section that explains it. The appendices add a
flattened drop-in copy of the design tokens and stand-ins for the two things that
cannot travel (team palettes, the bundled feed).

---

## 0. Port map

| # | Layer | Source | Here |
| --- | --- | --- | --- |
| 1 | Pitch geometry | `PitchFrame` | §3 — verbatim |
| 2 | The pitch surface | `paintFootballPitch`, `_dashedArc` | §4 — verbatim |
| 3 | The marks | `FootballShotMapPainter` | §5 — verbatim |
| 4 | The panel | `FootballShotMapPanel` + state | §6 — verbatim |
| 5 | Outcome key | `_ShotOutcomeLegend`, `_OutcomeSwatch` | §7 — verbatim |
| 6 | Tap payoff | `_SelectedShotRow`, `_ShotFact` | §8 — verbatim |
| 7 | Net diagram | `_ShotNetDiagram`, `ShotNetPainter` | §9 — verbatim |
| 8 | Goal mouth | `GoalMouthFrame`, `paintGoalMouth`, `paintGoalBall` | §10 — verbatim |
| 9 | Model + frame maths | `FootballShot`, `FootballShotOutcome`, `footballAttackingOffset` | App. A — verbatim |
| 10 | Shared widgets | `StatsRowShell`, `TeamLegendMark`, `TeamLegendRow`, `CyberChartRangeTabs` | App. B |
| 11 | Tokens + stand-ins | `Cyber`, `paletteForTeam`, `titleSmall` | App. C |

**Toolchain**

- **Dart 3** — records as a return type (`(double, double) pitchOffset`), record
  patterns (`final (mx, my) = ...`), destructuring in a `for` (`for (final (label,
  outcome) in ...)`), switch expressions, and **switch statements over an enum with
  no `default`** in both painters (exhaustiveness is what guarantees every outcome
  gets a mark).
- **Flutter 3.27+** — `Color.withValues(alpha:)` throughout.
- **Fonts** — Orbitron (labels) and Onest. Only `Cyber.label` and one `titleSmall`
  are used; see App. C.
- **No third-party packages.** `dart:math`, `flutter/material.dart`,
  `flutter/services.dart`.
- **One shared dependency:** `CyberChartRangeTabs` from the charting engine. If you
  have already ported [`match-momentum-chart.md`](match-momentum-chart.md) you have
  it; otherwise App. B says what to do.

---

## 1. What it is

A **full pitch drawn to real proportions**, with every tracked attempt plotted
where it was taken — home attacking right, away attacking left. Tap a mark and the
panel tells you who took it, from where, how it finished, and draws a goal mouth
with the ball placed where the attempt crossed the line.

```
FootballShotMapPanel(match, shots, homeColor, awayColor)
  └─ Container (Cyber.chartSurface + border, no glow)
       ├─ header            SHOT MAP            "32 ATTEMPTS"
       ├─ CyberChartRangeTabs    ALL | 1ST | 2ND | GOALS
       ├─ AspectRatio(105/68)
       │    └─ GestureDetector(onTapUp → nearest mark within 24px)
       │         └─ Stack
       │              ├─ TweenAnimationBuilder(0→1, 900ms, re-keyed per range)
       │              │    └─ CustomPaint(FootballShotMapPainter)
       │              │         paintFootballPitch + staggered marks
       │              └─ [shots.isEmpty] "NO PLOTTED ATTEMPTS IN THIS FILTER"
       ├─ TeamLegendRow          colour → club identity
       ├─ _ShotOutcomeLegend     shape → outcome (neutral grey)
       ├─ [selected] _SelectedShotRow
       │    ├─ minute + shooter
       │    ├─ _ShotFact × 3-4   SHOT TYPE / FROM / RESULT / ASSIST
       │    └─ _ShotNetDiagram → CustomPaint(ShotNetPainter)
       │         goal mouth + ball lerped into place, net ripples on a goal
       └─ caption   "TRACKED SHOT POSITIONS // CHE ATTACK RIGHT // …"
```

**The two legends split the encoding.** Colour carries *which team*
(`TeamLegendRow`, from the club palette); shape carries *how it finished*
(`_ShotOutcomeLegend`, drawn in neutral `Cyber.muted`). Neither duplicates the
other, which is why a mark needs no label.

---

## 2. The coordinate problem this solves

The feed gives every attempt in **the shooting side's own attacking frame**, and
that frame does not flip at half time:

- `fieldX` is progress towards the goal being attacked — `1` is the goal line, the
  penalty-area edge sits near `0.83`, six-yard-box efforts above `0.94`.
- `fieldY` runs across the pitch with **the attacker's left as the high value** —
  left-of-goal near `0.68`, central near `0.49`, right-of-goal near `0.32`.

So both sides arrive in the *same* frame, and drawing them on one pitch means
mirroring one of them. That happens in exactly one place —
`footballAttackingOffset` (App. A):

```dart
attackingRight
    ? (fieldX * length, (1 - fieldY) * width)
    : ((1 - fieldX) * length, fieldY * width)
```

Both cases invert an axis, but **different** axes, and the comment in the source
explains why: screen `y` grows downwards, so a side facing right has its left hand
at the top of the pitch while a side facing left has it at the bottom. Get this
wrong and the marks look plausible but are laterally flipped for one team — the
kind of bug no amount of visual checking catches, which is why
[`test/football_shot_map_test.dart`](../../test/football_shot_map_test.dart) pins
both the prose-to-zone mapping and the half each side's marks land in.

**Never read `fieldX` / `fieldY` directly in UI code.** Go through
`shot.pitchOffset(length, width)` so the mirroring stays in one place.

A second frame exists for the net diagram: `netPlacement` is a
`(double, double)?` in **goal-mouth space** as the viewer faces the goal — `x` 0 at
the left post, 1 at the right; `y` 0 at the crossbar, 1 at the ground. Values
outside `0..1` are misses placed beyond the frame, and `null` means the attempt
never reached the goal. The model deliberately leaves a missing placement missing
rather than defaulting it to the centre.

---

## 3. Pitch geometry — `PitchFrame`

Verbatim:

```dart
/// Pitch geometry in metres, converted once into paint space.
///
/// The pitch is drawn to real proportions the way the basketball court is, so
/// the markings land where the tracked coordinates expect them rather than
/// being placed by eye.
class PitchFrame {
  PitchFrame(this.rect);

  final Rect rect;

  static const double lengthM = 105;
  static const double widthM = 68;
  static const double penaltyDepthM = 16.5;
  static const double penaltyWidthM = 40.32;
  static const double goalAreaDepthM = 5.5;
  static const double goalAreaWidthM = 18.32;
  static const double centreCircleM = 9.15;
  static const double penaltySpotM = 11;
  static const double goalWidthM = 7.32;
  static const double goalDepthM = 2;

  double dx(double m) => rect.left + rect.width * (m / lengthM);
  double dy(double m) => rect.top + rect.height * (m / widthM);
  Offset p(double x, double y) => Offset(dx(x), dy(y));
  double get scale => rect.width / lengthM;

  Rect box(double left, double top, double right, double bottom) =>
      Rect.fromLTRB(dx(left), dy(top), dx(right), dy(bottom));

  /// Where an attempt lands in paint space, clamped just inside the touchlines
  /// so a byline effort still reads as a mark rather than a clipped sliver.
  Offset offsetFor(FootballShot shot) {
    final (mx, my) = shot.pitchOffset(lengthM, widthM);
    return p(mx.clamp(1.0, lengthM - 1), my.clamp(1.0, widthM - 1));
  }

  /// The largest true-proportion pitch that fits [size], inset far enough to
  /// leave room for the goal mouths that hang outside the goal lines.
  static PitchFrame fit(Size size) {
    final available = Offset.zero & size;
    final padded = available.deflate(size.width * 0.026);
    const ratio = lengthM / widthM;
    var width = padded.width;
    var height = width / ratio;
    if (height > padded.height) {
      height = padded.height;
      width = height * ratio;
    }
    return PitchFrame(
      Rect.fromCenter(
        center: available.center,
        width: width,
        height: height,
      ),
    );
  }
}
```

**The pitch is drawn in metres, then converted once.** Every marking is a real
dimension — 105 × 68 m, a 16.5 m penalty box 40.32 m wide, a 9.15 m centre circle,
the spot at 11 m — so the lines land where the tracked coordinates expect them
instead of being placed by eye. `dx`/`dy`/`p`/`box` are the metre→paint-space
conversions and `scale` converts a radius.

Two details worth keeping:

- **`fit` centres the largest true-proportion pitch that fits**, after deflating by
  `width * 0.026`. That inset is not decorative: the goal frames are drawn at
  *negative* depth (`span(-goalDepthM, …)`), hanging **outside** the goal lines, so
  without the inset they would be clipped.
- **`offsetFor` clamps to `1 .. length-1` / `1 .. width-1`** so a byline effort
  still reads as a full mark rather than a sliver cut off by the touchline.

---

## 4. The pitch surface — `paintFootballPitch`

Verbatim:

```dart
/// Draws the pitch itself — turf, markings and goal frames, to real
/// proportions.
///
/// Shared by the shot map and the per-player heatmap: both plot tracked
/// coordinates onto the same surface, so the surface is drawn in one place.
void paintFootballPitch(Canvas canvas, PitchFrame f) {
  final turf = Paint()..color = Cyber.bg.withValues(alpha: 0.55);
  final line = Paint()
    ..color = Cyber.line
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final faint = Paint()
    ..color = Cyber.borderSubtle
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;
  final boxTint = Paint()..color = Cyber.cyan.withValues(alpha: 0.05);
  // The goal frames are furniture, not the focus — kept dim so the scored
  // goals stay the brightest thing on the pitch.
  final goalPaint = Paint()
    ..color = Cyber.amber.withValues(alpha: 0.38)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;

  canvas.drawRect(f.rect, turf);
  canvas.drawRect(f.rect, line);

  const midX = PitchFrame.lengthM / 2;
  const midY = PitchFrame.widthM / 2;

  canvas.drawLine(f.p(midX, 0), f.p(midX, PitchFrame.widthM), line);
  canvas.drawCircle(
    f.p(midX, midY),
    PitchFrame.centreCircleM * f.scale,
    faint,
  );
  canvas.drawCircle(f.p(midX, midY), 1.4, Paint()..color = Cyber.line);

  for (final atLeft in [true, false]) {
    double x(double depth) => atLeft ? depth : PitchFrame.lengthM - depth;

    Rect span(double depth, double halfWidth) => f.box(
      math.min(x(0), x(depth)),
      midY - halfWidth,
      math.max(x(0), x(depth)),
      midY + halfWidth,
    );

    final penalty = span(
      PitchFrame.penaltyDepthM,
      PitchFrame.penaltyWidthM / 2,
    );
    canvas.drawRect(penalty, boxTint);
    canvas.drawRect(penalty, line);
    canvas.drawRect(
      span(PitchFrame.goalAreaDepthM, PitchFrame.goalAreaWidthM / 2),
      faint,
    );

    final spot = f.p(x(PitchFrame.penaltySpotM), midY);
    canvas.drawCircle(spot, 1.2, Paint()..color = Cyber.line);

    // Only the arc standing outside the penalty area is drawn.
    final sweep = math.acos(
      (PitchFrame.penaltyDepthM - PitchFrame.penaltySpotM) /
          PitchFrame.centreCircleM,
    );
    _dashedArc(
      canvas,
      Rect.fromCircle(
        center: spot,
        radius: PitchFrame.centreCircleM * f.scale,
      ),
      atLeft ? -sweep : math.pi - sweep,
      sweep * 2,
      faint,
    );

    canvas.drawRect(
      span(-PitchFrame.goalDepthM, PitchFrame.goalWidthM / 2),
      goalPaint,
    );
  }
}

/// A dashed arc, used for the penalty-area arcs.
void _dashedArc(
  Canvas canvas,
  Rect rect,
  double start,
  double sweep,
  Paint paint,
) {
  const segments = 9;
  final step = sweep / (segments * 2 - 1);
  for (var i = 0; i < segments; i++) {
    canvas.drawArc(rect, start + step * i * 2, step, false, paint);
  }
}
```

A free function, not a painter, because **it is shared** — the shot map and the
per-player heatmap both plot tracked coordinates onto the same surface, so the
surface is drawn in one place.

- **The `for (final atLeft in [true, false])` loop draws both ends from one body.**
  `x(depth)` flips the depth to the far end and `span` uses `math.min`/`math.max`
  so the `Rect` stays well-formed in both directions — which also makes the
  negative-depth goal frame work at both ends.
- **Paint hierarchy:** turf is `Cyber.bg @ 0.55`, the main lines `Cyber.line`, the
  secondary markings `Cyber.borderSubtle`, the penalty boxes get a `Cyber.cyan @
  0.05` tint, and the goal frames are `Cyber.amber @ 0.38` — deliberately dim,
  because they are furniture and the scored goals must stay the brightest thing on
  the pitch.
- **The penalty arc is the fiddly bit.** Only the part of the 9.15 m circle
  standing *outside* the box is drawn, so the sweep is
  `acos((penaltyDepth - penaltySpot) / centreCircle)` either side of the axis,
  mirrored for the far end via `atLeft ? -sweep : pi - sweep`. Drawn dashed by
  `_dashedArc` (9 segments, drawing every other step).

---

## 5. The marks — `FootballShotMapPainter`

Verbatim:

```dart
/// Plots tracked attempts on a full pitch, home attacking right and away
/// attacking left. Goals are the only mark that glows — everything else reads
/// as calm telemetry so the scoring moments carry the eye.
class FootballShotMapPainter extends CustomPainter {
  FootballShotMapPainter({
    required this.shots,
    required this.homeColor,
    required this.awayColor,
    required this.reveal,
    this.selectedPlayId,
  });

  final List<FootballShot> shots;
  final Color homeColor;
  final Color awayColor;
  final double reveal;
  final String? selectedPlayId;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = PitchFrame.fit(size);
    paintFootballPitch(canvas, frame);
    _paintShots(canvas, frame);
  }

  void _paintShots(Canvas canvas, PitchFrame f) {
    // Goals paint last so their glow is never buried under a calmer mark.
    final ordered = [
      ...shots.where((shot) => !shot.isGoal),
      ...shots.where((shot) => shot.isGoal),
    ];

    for (var i = 0; i < ordered.length; i++) {
      final shot = ordered[i];
      final stagger = ordered.length < 2 ? 0.0 : i / ordered.length;
      final t = ((reveal - stagger * 0.45) / 0.55).clamp(0.0, 1.0);
      if (t <= 0) continue;

      final centre = f.offsetFor(shot);
      final color = shot.isHomeTeam ? homeColor : awayColor;
      final selected = shot.playId == selectedPlayId;
      final r = 4.4 * t;

      if (shot.isGoal || selected) {
        canvas.drawCircle(
          centre,
          r * 2.1,
          Paint()
            ..color = color.withValues(alpha: 0.5 * t)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }

      switch (shot.outcome) {
        case FootballShotOutcome.goal:
          canvas.drawCircle(centre, r * 1.35, Paint()..color = color);
          canvas.drawCircle(
            centre,
            r * 1.35,
            Paint()
              ..color = Cyber.bg
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
          canvas.drawCircle(
            centre,
            r * 0.5,
            Paint()..color = Cyber.bg.withValues(alpha: 0.9),
          );
        case FootballShotOutcome.onTarget:
          canvas.drawCircle(
            centre,
            r,
            Paint()..color = color.withValues(alpha: 0.9),
          );
          canvas.drawCircle(
            centre,
            r,
            Paint()
              ..color = Cyber.bg.withValues(alpha: 0.6)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
          );
        case FootballShotOutcome.offTarget:
          canvas.drawCircle(
            centre,
            r,
            Paint()
              ..color = color.withValues(alpha: 0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        case FootballShotOutcome.blocked:
          canvas.drawCircle(
            centre,
            r * 0.8,
            Paint()
              ..color = color.withValues(alpha: 0.45)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
      }

      if (selected) {
        canvas.drawCircle(
          centre,
          r * 2.4,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FootballShotMapPainter old) =>
      old.shots != shots ||
      old.reveal != reveal ||
      old.selectedPlayId != selectedPlayId ||
      old.homeColor != homeColor ||
      old.awayColor != awayColor;
}
```

### 5.1 Goals paint last

```dart
final ordered = [
  ...shots.where((shot) => !shot.isGoal),
  ...shots.where((shot) => shot.isGoal),
];
```

A goal's blur halo would be buried under any calmer mark drawn after it. Reordering
the list is the whole fix — keep it.

### 5.2 The staggered reveal

```dart
final stagger = ordered.length < 2 ? 0.0 : i / ordered.length;
final t = ((reveal - stagger * 0.45) / 0.55).clamp(0.0, 1.0);
if (t <= 0) continue;
```

Each mark gets its own window inside the single 0→1 `reveal`: the first starts
immediately, the last starts at 45% and every mark takes 55% of the timeline to
grow. `t` then scales the radius (`r = 4.4 * t`) and the halo alpha, so the map
populates rather than appearing. The `continue` skips marks that haven't started —
cheaper than drawing at zero radius.

Because the stagger is derived from **index in the reordered list**, goals animate
in last as a group. That is the payoff beat.

### 5.3 Shape per outcome, and the one glow

| Outcome | Mark |
| --- | --- |
| `goal` | solid disc at `r × 1.35`, `Cyber.bg` ring, dark `r × 0.5` pupil |
| `onTarget` | solid disc at `r`, `alpha 0.9`, faint dark outline |
| `offTarget` | **hollow** ring at `r`, stroke `1.5` |
| `blocked` | smaller hollow ring at `r × 0.8`, `alpha 0.45` |

Filled = reached the goal, hollow = didn't; the goal is biggest and the only one
with a pupil, so it reads as a distinct glyph rather than a bigger dot. **Only a
goal (or the selected mark) gets the blurred halo** — `r × 2.1` at `0.5 × t` with a
5px blur. A selected mark additionally gets a `r × 2.4` stroked ring, which is the
only thing that marks selection on the pitch.

---

## 6. The panel — `FootballShotMapPanel`

Verbatim:

```dart
/// The shot map keeps its own painter — it plots coordinates, not a series —
/// but wears the same panel chrome and range switcher as the line charts, so it
/// reads as one system with the basketball scoring map.
class FootballShotMapPanel extends StatefulWidget {
  const FootballShotMapPanel({
    required this.match,
    required this.shots,
    required this.homeColor,
    required this.awayColor,
    super.key,
  });

  final SportMatch match;
  final List<FootballShot> shots;
  final Color homeColor;
  final Color awayColor;

  @override
  State<FootballShotMapPanel> createState() => _FootballShotMapPanelState();
}

class _FootballShotMapPanelState extends State<FootballShotMapPanel> {
  static const _ranges = ['ALL', '1ST', '2ND', 'GOALS'];

  String _range = _ranges.first;
  String? _selectedPlayId;

  List<FootballShot> get _visible => switch (_range) {
    '1ST' => widget.shots.where((shot) => shot.period == 1).toList(),
    '2ND' => widget.shots.where((shot) => shot.period == 2).toList(),
    'GOALS' => widget.shots.where((shot) => shot.isGoal).toList(),
    _ => widget.shots,
  };

  FootballShot? _shotAt(Offset local, Size size, List<FootballShot> shots) {
    final frame = PitchFrame.fit(size);
    FootballShot? nearest;
    var nearestDistance = 24.0;
    for (final shot in shots) {
      final distance = (frame.offsetFor(shot) - local).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = shot;
      }
    }
    return nearest;
  }

  void _handleTap(Offset local, Size size, List<FootballShot> shots) {
    final hit = _shotAt(local, size, shots);
    if (hit == null) {
      if (_selectedPlayId != null) setState(() => _selectedPlayId = null);
      return;
    }
    HapticFeedback.selectionClick();
    setState(
      () => _selectedPlayId = _selectedPlayId == hit.playId ? null : hit.playId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final shots = _visible;
    FootballShot? selected;
    for (final shot in shots) {
      if (shot.playId == _selectedPlayId) selected = shot;
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: Cyber.chartSurface,
        border: Border.all(color: Cyber.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'SHOT MAP',
                  style: Cyber.label(10, color: Cyber.cyan),
                ),
              ),
              Text(
                '${shots.length} ATTEMPTS',
                style: Cyber.label(9, color: Cyber.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          CyberChartRangeTabs(
            ranges: _ranges,
            active: _range,
            onChanged: (range) => setState(() {
              _range = range;
              _selectedPlayId = null;
            }),
          ),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: PitchFrame.lengthM / PitchFrame.widthM,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) =>
                      _handleTap(details.localPosition, size, shots),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TweenAnimationBuilder<double>(
                        key: ValueKey('football-shot-map-reveal-$_range'),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0, end: 1),
                        builder: (context, reveal, _) => CustomPaint(
                          key: const ValueKey('football-shot-map'),
                          painter: FootballShotMapPainter(
                            shots: shots,
                            homeColor: widget.homeColor,
                            awayColor: widget.awayColor,
                            reveal: reveal,
                            selectedPlayId: _selectedPlayId,
                          ),
                        ),
                      ),
                      if (shots.isEmpty)
                        Center(
                          child: Text(
                            'NO PLOTTED ATTEMPTS IN THIS FILTER',
                            style: Cyber.label(8, color: Cyber.muted),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          TeamLegendRow(match: widget.match),
          const SizedBox(height: 8),
          const _ShotOutcomeLegend(),
          if (selected != null) ...[
            const SizedBox(height: 10),
            _SelectedShotRow(
              shot: selected,
              accent: selected.isHomeTeam ? widget.homeColor : widget.awayColor,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            'TRACKED SHOT POSITIONS // '
            '${widget.match.home.shortName.toUpperCase()} ATTACK RIGHT // '
            '${widget.match.away.shortName.toUpperCase()} ATTACK LEFT',
            textAlign: TextAlign.center,
            style: Cyber.label(7.5, color: Cyber.muted, letterSpacing: 0.7),
          ),
        ],
      ),
    );
  }
}
```

- **It wears the chart panel's chrome deliberately** — same
  `Cyber.chartSurface` + `Cyber.border` container, same `fromLTRB(12, 12, 12, 10)`
  padding, same header/caption type, same `CyberChartRangeTabs` — so it reads as
  one system with the line charts and the basketball scoring map. It keeps its own
  painter because it plots coordinates, not a series. Note it has **no `glow`
  parameter at all**: unlike `CyberChartPanel` there is no reveal glow here, because
  the marks themselves carry the reveal.
- **Hit-testing is nearest-mark-within-24px**, not a bounding box (`_shotAt` seeds
  `nearestDistance` at `24.0` and only ever lowers it). Marks are ~6–9 px across and
  cluster in the box, so a generous radius with a nearest-wins tiebreak is what makes
  them tappable at all. A tap that hits nothing **clears** the selection, and
  re-tapping the selected mark toggles it off.
- **The reveal re-keys on the range**
  (`ValueKey('football-shot-map-reveal-$_range')`), so switching filter replays the
  populate animation on the new set rather than snapping. Changing range also clears
  the selection — an index-free selection by `playId` would survive, but the shot
  may not be in the new filter.
- **`AspectRatio(105/68)` sizes the plot**, so the panel works in an unbounded
  `ListView` (which is how it is hosted, and what the widget test reproduces).
- **The empty state is an overlay, not a branch.** `shots.isEmpty` stacks a caption
  *over* the still-drawn pitch, so filtering to GOALS in a 0-0 match shows an empty
  pitch with a label rather than collapsing the panel.
- **The caption is greeble that earns its place:** `CHE ATTACK RIGHT // BHA ATTACK
  LEFT` is the legend for the mirroring, and without it the left/right split is
  unexplained.

---

## 7. The outcome key — `_ShotOutcomeLegend` and `_OutcomeSwatch`

Verbatim:

```dart
/// Shape key for the four outcomes. Team colour is carried by the team legend
/// directly above, so these marks stay neutral and only encode shape.
class _ShotOutcomeLegend extends StatelessWidget {
  const _ShotOutcomeLegend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (label, outcome) in const [
          ('GOAL', FootballShotOutcome.goal),
          ('ON TARGET', FootballShotOutcome.onTarget),
          ('OFF TARGET', FootballShotOutcome.offTarget),
          ('BLOCKED', FootballShotOutcome.blocked),
        ])
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _OutcomeSwatch(outcome: outcome),
              const SizedBox(width: 5),
              Text(label, style: Cyber.label(7.5, color: Cyber.muted)),
            ],
          ),
      ],
    );
  }
}

class _OutcomeSwatch extends StatelessWidget {
  const _OutcomeSwatch({required this.outcome});

  final FootballShotOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final filled =
        outcome == FootballShotOutcome.goal ||
        outcome == FootballShotOutcome.onTarget;
    final size = outcome == FootballShotOutcome.goal ? 10.0 : 8.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? Cyber.muted : null,
        border: filled
            ? null
            : Border.all(
                color: Cyber.muted.withValues(
                  alpha: outcome == FootballShotOutcome.blocked ? 0.5 : 0.9,
                ),
                width: 1.2,
              ),
        // Only the goal swatch glows, matching the map itself.
        boxShadow: outcome == FootballShotOutcome.goal
            ? Cyber.glow(Cyber.muted, alpha: 0.5, blur: 6)
            : null,
      ),
    );
  }
}
```

**The swatches are neutral on purpose.** Team colour is carried by
`TeamLegendRow` directly above, so these marks encode *shape only* and are drawn in
`Cyber.muted`. Tint them by team and the two legends start fighting.

The swatch mirrors the map's own logic: filled for goal/on-target, hollow
otherwise, the goal 10px against everyone else's 8, blocked at `alpha 0.5` versus
`0.9`. And the one glow is mirrored too —
`Cyber.glow(Cyber.muted, alpha: 0.5, blur: 6)` on the goal swatch alone, matching
the only mark that glows on the pitch. A legend whose swatches don't match the plot
is worse than no legend.

Note the Dart 3 destructuring in the `for`:
`for (final (label, outcome) in const [('GOAL', FootballShotOutcome.goal), …])`.

---

## 8. The tap payoff — `_SelectedShotRow` and `_ShotFact`

Verbatim:

```dart
/// The payoff for tapping a mark: who took it, and where it finished.
///
/// Facts sit on the left, the goal mouth on the right. The frame is always
/// drawn — a blocked attempt shows an empty net rather than collapsing the row,
/// so tapping between shots never makes the panel jump.
class _SelectedShotRow extends StatelessWidget {
  const _SelectedShotRow({required this.shot, required this.accent});

  final FootballShot shot;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return StatsRowShell(
      accent: accent,
      selected: true,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  shot.minuteLabel,
                  style: Cyber.label(10, color: accent),
                ),
              ),
              Expanded(
                child: Text(
                  shot.shooter.isEmpty ? 'UNCREDITED' : shot.shooter,
                  style: AppTheme.darkTheme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShotFact(
                      label: 'SHOT TYPE',
                      value: shot.isHeader ? 'HEADER' : 'FOOT',
                    ),
                    _ShotFact(
                      label: 'FROM',
                      value: (shot.zone ?? 'UNRECORDED').toUpperCase(),
                    ),
                    _ShotFact(
                      label: 'RESULT',
                      value: shot.outcomeLabel,
                      accent: shot.isGoal ? accent : null,
                    ),
                    if (shot.assist != null)
                      _ShotFact(
                        label: 'ASSIST',
                        value: shot.assist!.toUpperCase(),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ShotNetDiagram(shot: shot, accent: accent),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShotFact extends StatelessWidget {
  const _ShotFact({required this.label, required this.value, this.accent});

  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(label, style: Cyber.label(7.5, color: Cyber.muted)),
          ),
          Expanded(
            child: Text(
              value,
              style: Cyber.label(8, color: accent ?? Cyber.cyan),
            ),
          ),
        ],
      ),
    );
  }
}
```

Facts on the left, goal mouth on the right, on a `StatsRowShell` with
`selected: true` so it gets the accent tint and a solid accent border — the same
surface every stat row in the STATS views sits on.

- **`_ShotFact` uses a fixed `62` label column** so the four rows' values align
  into a column.
- **`ASSIST` appears only when present**; everything else always renders, with
  `shot.zone ?? 'UNRECORDED'` and `shooter.isEmpty ? 'UNCREDITED'` covering the
  gaps. **`RESULT` is the only fact that takes the accent** (and only on a goal) —
  every other value is `Cyber.cyan`.
- The shooter name is the single non-`Cyber` text style in the file:
  `AppTheme.darkTheme.textTheme.titleSmall`. App. C gives the one-line equivalent.

---

## 9. The net diagram — `_ShotNetDiagram` and `ShotNetPainter`

Verbatim:

```dart
/// The goal mouth with the ball placed where the attempt finished.
class _ShotNetDiagram extends StatelessWidget {
  const _ShotNetDiagram({required this.shot, required this.accent});

  final FootballShot shot;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final caption = switch (shot.outcome) {
      FootballShotOutcome.blocked => 'BLOCKED // NEVER REACHED THE GOAL',
      _ when shot.netPlacement == null => 'PLACEMENT UNRECORDED',
      FootballShotOutcome.goal => 'SCORED',
      FootballShotOutcome.onTarget => 'KEPT OUT',
      FootballShotOutcome.offTarget => 'MISSED THE FRAME',
    };

    return SizedBox(
      width: 132,
      child: Column(
        children: [
          SizedBox(
            height: 84,
            width: 132,
            child: TweenAnimationBuilder<double>(
              // Re-keyed per attempt so picking another one replays the strike.
              key: ValueKey('shot-net-${shot.playId}'),
              duration: const Duration(milliseconds: 720),
              curve: Curves.easeOutCubic,
              tween: Tween(begin: 0, end: 1),
              builder: (context, progress, _) => CustomPaint(
                key: const ValueKey('football-shot-net'),
                painter: ShotNetPainter(
                  shot: shot,
                  accent: accent,
                  progress: progress,
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: Cyber.label(7, color: Cyber.muted, letterSpacing: 0.6),
          ),
        ],
      ),
    );
  }
}

/// Draws the goal mouth and marks where the attempt finished.
///
/// Only a goal glows and ripples the net — a save, a miss and a block all stay
/// calm, so a scoreline moment is the one thing that carries.
class ShotNetPainter extends CustomPainter {
  ShotNetPainter({
    required this.shot,
    required this.accent,
    required this.progress,
  });

  final FootballShot shot;
  final Color accent;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Misses are plotted outside the posts and the ball flies in from below the
    // frame, so the diagram must not spill over its neighbours.
    canvas.clipRect(Offset.zero & size);

    final frame = GoalMouthFrame.diagram(size);
    final placement = shot.netPlacement;
    final target = placement == null
        ? null
        : frame.at(placement.$1, placement.$2);

    paintGoalMouth(
      canvas,
      frame,
      cols: 7,
      rows: 4,
      meshAlpha: 0.16,
      meshStroke: 0.8,
      frameStroke: 2.4,
      groundLine: false,
      impactRing: shot.isGoal,
      rippleAmplitude: 5,
      rippleFalloff: 20,
      rippleT: shot.isGoal && target != null ? progress : 0,
      rippleCenter: shot.isGoal ? target : null,
    );

    if (target == null) return;

    // The mark travels the last stretch into its resting place.
    final from = Offset(frame.at(0.5, 1.15).dx, frame.at(0.5, 1.15).dy);
    final centre = Offset.lerp(from, target, Curves.easeOutCubic.transform(
      progress.clamp(0.0, 1.0),
    ))!;

    switch (shot.outcome) {
      case FootballShotOutcome.goal:
        canvas.drawCircle(
          centre,
          9,
          Paint()
            ..color = accent.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        paintGoalBall(canvas, centre, 0.62);
      case FootballShotOutcome.onTarget:
        canvas.drawCircle(
          centre,
          4.2,
          Paint()..color = accent.withValues(alpha: 0.9),
        );
        canvas.drawCircle(
          centre,
          4.2,
          Paint()
            ..color = Cyber.bg.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      case FootballShotOutcome.offTarget:
        canvas.drawCircle(
          centre,
          4.2,
          Paint()
            ..color = accent.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      case FootballShotOutcome.blocked:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ShotNetPainter old) =>
      old.shot.playId != shot.playId ||
      old.progress != progress ||
      old.accent != accent;
}
```

### 9.1 The frame is always drawn

The caption switch covers all five cases, and **`blocked` is checked before the
null-placement guard**:

```dart
FootballShotOutcome.blocked => 'BLOCKED // NEVER REACHED THE GOAL',
_ when shot.netPlacement == null => 'PLACEMENT UNRECORDED',
FootballShotOutcome.goal => 'SCORED',
FootballShotOutcome.onTarget => 'KEPT OUT',
FootballShotOutcome.offTarget => 'MISSED THE FRAME',
```

Order matters: a blocked shot also has a null placement, and "never reached the
goal" is the more useful sentence. The painter then returns early after
`paintGoalMouth` when `target == null`, so a block draws **an empty net** rather
than collapsing the row — tapping between shots never makes the panel jump. That
behaviour is pinned by the widget test.

### 9.2 The strike animation

Re-keyed per attempt (`ValueKey('shot-net-${shot.playId}')`) so picking another
mark **replays** the strike rather than holding the previous end state. 720 ms,
`easeOutCubic`, and the ball is lerped from `frame.at(0.5, 1.15)` — centre,
*below* the frame — into its resting place, so it flies in from the viewer's side
of the goal.

### 9.3 Only a goal ripples

`impactRing: shot.isGoal` and
`rippleT: shot.isGoal && target != null ? progress : 0` — a save, a miss and a
block all leave the mesh flat. The goal additionally gets a `0.55`-alpha blurred
halo and the real ball glyph (`paintGoalBall`); a save is a small disc, a miss a
hollow ring, a block nothing at all.

### 9.4 The clip is load-bearing

```dart
canvas.clipRect(Offset.zero & size);
```

Misses are plotted **outside** the posts and the ball starts below the frame, so
without the clip the diagram would paint over its neighbours in the row.

---

## 10. The goal mouth — `GoalMouthFrame`, `paintGoalMouth`, `paintGoalBall`

Shared with the penalty shootout, which is where it was extracted from, so the
shootout scene, its emblem and this diagram all agree on one goal mouth. Verbatim:

```dart
/// Where the posts, crossbar and ground sit for a goal drawn face-on.
///
/// Extracted from the penalty shootout so the shootout scene, its emblem and the
/// football shot map all agree on one goal mouth instead of each re-deriving it.
class GoalMouthFrame {
  const GoalMouthFrame({
    required this.left,
    required this.right,
    required this.crossbarY,
    required this.groundY,
  });

  /// A mouth for an inline diagram.
  ///
  /// The margins are not decorative: attempts that missed are placed *outside*
  /// the frame, so the goal is sized to leave room for them. A miss at x 1.12
  /// or y -0.14 still lands inside the canvas at these proportions.
  factory GoalMouthFrame.diagram(Size size) => GoalMouthFrame(
    left: size.width * 0.13,
    right: size.width * 0.87,
    crossbarY: size.height * 0.22,
    groundY: size.height * 0.92,
  );

  final double left;
  final double right;
  final double crossbarY;
  final double groundY;

  double get width => right - left;
  double get mouthH => groundY - crossbarY;

  /// A point in mouth space: [x] 0 at the left post and 1 at the right, [y] 0 at
  /// the crossbar and 1 at the ground. Values outside 0..1 fall outside the
  /// frame, which is how attempts that missed are placed.
  Offset at(double x, double y) =>
      Offset(left + width * x, crossbarY + mouthH * y);
}

/// Posts, crossbar and net grid. On a goal the net bulges outward around
/// [rippleCenter] while [rippleT] runs 0→1.
///
/// Defaults reproduce the penalty shootout's frame exactly; the inline diagram
/// overrides the mesh density and stroke weights for its smaller size.
void paintGoalMouth(
  Canvas canvas,
  GoalMouthFrame g, {
  int cols = 9,
  int rows = 5,
  double meshAlpha = 0.20,
  double meshStroke = 1,
  double frameStroke = 4,
  double rippleT = 0,
  Offset? rippleCenter,
  double rippleAmplitude = 11,
  double rippleFalloff = 42,
  bool impactRing = true,
  bool groundLine = true,
  double groundWidth = double.infinity,
  Offset? spot,
}) {
  final netPaint = Paint()
    ..color = Cyber.cyan.withValues(alpha: meshAlpha)
    ..strokeWidth = meshStroke
    ..style = PaintingStyle.stroke;

  Offset displace(Offset p) {
    final c = rippleCenter;
    if (c == null || rippleT <= 0 || rippleT >= 1) return p;
    final d = (p - c).distance;
    if (d < 1) return p;
    final amp =
        rippleAmplitude *
        sin(rippleT * pi) *
        exp(-(d * d) / (2 * rippleFalloff * rippleFalloff));
    return p + (p - c) / d * amp;
  }

  Path netLine(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  List<Offset> sample(Offset a, Offset b) => [
    for (var i = 0; i <= 10; i++) displace(Offset.lerp(a, b, i / 10)!),
  ];

  for (var i = 1; i < cols; i++) {
    final x = g.left + g.width * i / cols;
    canvas.drawPath(
      netLine(sample(Offset(x, g.crossbarY), Offset(x, g.groundY))),
      netPaint,
    );
  }
  for (var i = 1; i < rows; i++) {
    final y = g.crossbarY + g.mouthH * i / rows;
    canvas.drawPath(
      netLine(sample(Offset(g.left, y), Offset(g.right, y))),
      netPaint,
    );
  }

  final c = rippleCenter;
  if (impactRing && c != null && rippleT > 0 && rippleT < 1) {
    canvas.drawCircle(
      c,
      8 + 34 * rippleT,
      Paint()
        ..color = Cyber.lime.withValues(alpha: 0.5 * (1 - rippleT))
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  final framePaint = Paint()
    ..color = Colors.white.withValues(alpha: 0.92)
    ..strokeWidth = frameStroke
    ..strokeCap = StrokeCap.round
    ..style = PaintingStyle.stroke;
  canvas.drawLine(
    Offset(g.left, g.groundY),
    Offset(g.left, g.crossbarY),
    framePaint,
  );
  canvas.drawLine(
    Offset(g.right, g.groundY),
    Offset(g.right, g.crossbarY),
    framePaint,
  );
  canvas.drawLine(
    Offset(g.left, g.crossbarY),
    Offset(g.right, g.crossbarY),
    framePaint,
  );

  if (groundLine) {
    canvas.drawLine(
      Offset(0, g.groundY),
      Offset(
        groundWidth.isFinite ? groundWidth : g.left * 2 + g.width,
        g.groundY,
      ),
      Paint()
        ..color = Cyber.cyan.withValues(alpha: 0.35)
        ..strokeWidth = 1.5,
    );
  }

  if (spot != null) {
    canvas.drawCircle(
      spot,
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
  }
}

/// The match ball, shared by the shootout scene and the shot-map net diagram.
void paintGoalBall(
  Canvas canvas,
  Offset pos,
  double scale, {
  double alpha = 1,
}) {
  final r = 8.0 * scale;
  canvas.drawCircle(
    pos,
    r,
    Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha),
  );
  final seam = Paint()
    ..color = Cyber.bg2.withValues(alpha: 0.85 * alpha)
    ..strokeWidth = 1.2
    ..style = PaintingStyle.stroke;
  canvas.drawCircle(pos, r * 0.45, seam);
  canvas.drawArc(
    Rect.fromCircle(center: pos, radius: r * 0.85),
    0.6,
    1.6,
    false,
    seam,
  );
}
```

- **`GoalMouthFrame.diagram`'s margins are not decorative.** `left: 0.13`,
  `right: 0.87`, `crossbarY: 0.22`, `groundY: 0.92` leave room for the misses that
  sit outside the frame — a miss at `x 1.12` or `y -0.14` still lands inside the
  canvas at these proportions. Tighten them and misses get clipped.
- **`at(x, y)` is the only coordinate conversion**, and values outside `0..1` are
  *expected* — that is how misses are placed.
- **The ripple is a radial displacement field:**
  `amp = rippleAmplitude × sin(rippleT × π) × exp(-d²/(2 × falloff²))`, pushing each
  sampled point away from `rippleCenter`. `sin(πt)` makes it swell and settle within
  the animation; the Gaussian localises it near the impact. Mesh lines are sampled
  at 11 points and drawn as paths so they *curve*; a straight-line grid can't bulge.
  Both the ripple and the impact ring are gated on `rippleT > 0 && rippleT < 1`, so
  the net is flat at rest **and** flat when the animation lands.
- **The shot map overrides the shootout defaults** for its smaller size: `cols: 7`,
  `rows: 4`, `meshAlpha: 0.16`, `meshStroke: 0.8`, `frameStroke: 2.4`,
  `rippleAmplitude: 5`, `rippleFalloff: 20`, and `groundLine: false` — there is no
  ground in an inline diagram.
- The frame itself is white at `0.92` with round caps; the mesh is `Cyber.cyan` at
  the given alpha; the impact ring is `Cyber.lime` fading out as it expands.

---

## 11. Every layout and timing value in one place

| Element | Value |
| --- | --- |
| Pitch | `105 × 68 m`, box `16.5 × 40.32`, goal area `5.5 × 18.32`, circle `9.15`, spot `11`, goal `7.32 × 2` |
| `PitchFrame.fit` inset | `size.width × 0.026` |
| Mark clamp | `1 .. length-1` by `1 .. width-1` metres |
| Panel padding | `EdgeInsets.fromLTRB(12, 12, 12, 10)` |
| Panel surface | `Cyber.chartSurface`, `Cyber.border` 1px, **no glow** |
| Title / caption | `Cyber.label(10, cyan)` / `Cyber.label(9, muted)` |
| Plot aspect | `105 / 68` |
| Map reveal | `900 ms`, `easeOutCubic`, re-keyed per range |
| Mark stagger | start `i / n × 0.45`, each takes `0.55` of the timeline |
| Mark radius | `4.4 × t`; goal `× 1.35`, blocked `× 0.8`, pupil `× 0.5` |
| Mark halo | `r × 2.1`, alpha `0.5 × t`, blur `5` — goals and selection only |
| Selection ring | `r × 2.4`, stroke `1.2` |
| Hit radius | `24` logical px, nearest wins |
| Turf / lines | `Cyber.bg @ 0.55` / `Cyber.line` / `Cyber.borderSubtle` |
| Box tint / goal frame | `Cyber.cyan @ 0.05` / `Cyber.amber @ 0.38`, stroke `1.1` |
| Penalty arc | `9` dashed segments, sweep `acos((16.5−11)/9.15)` either side |
| Outcome swatch | `10` (goal) / `8`, alpha `0.9` (`0.5` blocked), glow on goal only |
| Outcome legend | `Wrap` centred, spacing `14`, run `6`, `Cyber.label(7.5, muted)` |
| Fact label column | `62` wide, `Cyber.label(7.5, muted)`; value `Cyber.label(8)` |
| Minute column | `46` wide, `Cyber.label(10, accent)` |
| Net diagram | `132 × 84`, caption `Cyber.label(7, muted, ls 0.6)` |
| Net animation | `720 ms`, `easeOutCubic`, re-keyed per `playId` |
| Net mouth | `left 0.13`, `right 0.87`, `crossbar 0.22`, `ground 0.92` |
| Net mesh | `cols 7`, `rows 4`, alpha `0.16`, stroke `0.8`, frame `2.4` |
| Ripple | amplitude `5`, falloff `20`, goals only |
| Ball | `paintGoalBall(…, 0.62)`, halo `9` @ `0.55` blur `6` |
| Net marks | save/miss radius `4.2`; block draws nothing |
| Footer caption | `Cyber.label(7.5, muted, ls 0.7)`, centred |

---

## 12. Design rules to keep

1. **Colour = team, shape = outcome.** Two legends, two encodings, no overlap. The
   outcome swatches stay neutral grey.
2. **Only a goal glows** — the map halo, the swatch glow, the net halo and the net
   ripple are all gated on `isGoal`. A selected mark borrows the halo, which is the
   one exception and why selection also adds a stroked ring to stay distinguishable.
3. **Goals paint last.** Always.
4. **Filled means it reached the goal; hollow means it didn't.** Keep the
   filled/hollow split aligned with `isOnTarget`.
5. **The frame is always drawn.** A blocked attempt shows an empty net. Never
   collapse the row — the panel must not jump as you tap between marks.
6. **A missing placement stays missing.** Never default `netPlacement` to the centre;
   print `PLACEMENT UNRECORDED`.
7. **Mirror in one place.** `footballAttackingOffset` is the only code that knows
   about attacking direction. UI reads `pitchOffset`, never `fieldX`/`fieldY`.
8. **Real proportions, not eyeballed ones.** Markings come from metres so the
   geometry agrees with the tracked coordinates.
9. **The goal frames stay dim.** They are furniture; scored goals are the brightest
   thing on the pitch.
10. **Re-key the animations.** The map re-keys on range, the net on `playId` — both
    so a change replays rather than snapping.

---

## 13. Tests

This feature has its own suite —
[`test/football_shot_map_test.dart`](../../test/football_shot_map_test.dart), 8
tests — and it is unusually worth porting, because it pins the coordinate contract
that is otherwise invisible:

| Test | Pins |
| --- | --- |
| every tracked attempt decodes | the feed → `FootballShot` path |
| the feed frame lands each attempt in the zone its prose describes | `fieldX` thresholds (`> 0.94` very close, `> 0.83` in the box, `< 0.83` outside) and that **the attacker's left is the HIGH lateral value** |
| the two sides are mirrored onto opposite goals | every mark is in-bounds, and `isHomeTeam ? x > length/2 : x < length/2` |
| the shot map renders on the football MOMENTUM tab | `ValueKey('football-shot-map')` in its real host |
| net placement is read for every attempt that reached the goal | `netPlacement` non-null exactly when expected |
| placement matches the corner the commentary names | the viewer's-left convention |
| selecting an attempt reveals where it finished | no net until tapped; goal → `SCORED` + shooter; blocked → frame still drawn + `BLOCKED // NEVER REACHED THE GOAL` |
| filtering narrows the plotted attempts | `32 ATTEMPTS` → GOALS → `5 ATTEMPTS` |

Keys to port: `ValueKey('football-shot-map')` (the map `CustomPaint`),
`ValueKey('football-shot-net')` (the net `CustomPaint`),
`ValueKey('football-shot-map-reveal-$_range')` (the reveal, re-keyed per filter).

The widget tests host the panel in a `ListView` with
`padding: fromLTRB(16, 14, 16, 28)` — deliberately, because the panel is always in
a scrolling report list and needs unbounded height rather than a fixed viewport.
Reproduce that in a port or `AspectRatio` will fight the test harness.

Not covered today, worth adding: the 24px nearest-mark hit test (including
tap-to-clear and tap-to-toggle), the staggered reveal ordering (goals last), and
that only a goal ripples the net.

---

## 14. Port checklist

1. **Tokens.** Drop in the flattened `Cyber` from App. C (10 colours, `glow`,
   `label`, `display`) or map onto your own theme.
2. **Model.** Add `FootballShotOutcome`, `FootballShot` and
   `footballAttackingOffset` from App. A. If you map your own type, it must expose
   `playId`, `minuteLabel`, `period`, `isHomeTeam`, `shooter`, `assist`, `outcome`,
   `zone`, `isHeader`, `netPlacement`, `isGoal`, `outcomeLabel` and
   `pitchOffset(length, width)`.
3. **Goal mouth.** Copy §10 into its own file. It needs only `Cyber` (`cyan`,
   `lime`, `bg2`) and `dart:math`.
4. **Pitch + marks.** Copy §3, §4, §5. `paintFootballPitch` is a free function —
   keep it that way if you also want a heatmap on the same surface.
5. **Shared widgets.** From App. B: `StatsRowShell`, `TeamLegendMark` +
   `TeamLegendRow`, and `CyberChartRangeTabs` (already yours if you ported the
   momentum chart; otherwise take it from there or substitute any equal-width tab
   strip — the panel only calls it with `ranges`/`active`/`onChanged`).
6. **Accents.** Replace `paletteForTeam(...).secondaryTextColor` with your own
   per-team colour or the App. C stand-in. It must clear 4.5:1 against
   `Cyber.chartSurface` *and* against the turf (`Cyber.bg @ 0.55`) — a dark club
   colour makes every one of that side's marks vanish into the grass.
7. **Panel + payoff.** Paste §6, §7, §8, §9. Swap the one
   `AppTheme.darkTheme.textTheme.titleSmall` for the App. C equivalent.
8. **Verify.** `flutter analyze` clean, then in the running app: markings line up
   with where marks cluster (the box edge should sit just behind the bulk of
   attempts), home marks are all in the right half and away marks all in the left,
   the map populates with goals arriving last, tapping a mark selects it and tapping
   empty grass clears it, switching filter replays the reveal, and a blocked attempt
   shows an empty net with the frame intact.

---

## Implementation References

- [`lib/screens/predictions/widgets/football_shot_map.dart`](../../lib/screens/predictions/widgets/football_shot_map.dart)
  — `PitchFrame` (18), `FootballShotMapPainter` (74), `FootballShotMapPanel` (199),
  `_FootballShotMapPanelState` (217), `_ShotOutcomeLegend` (365),
  `_OutcomeSwatch` (394), `_SelectedShotRow` (433), `_ShotFact` (505),
  `_ShotNetDiagram` (536), `ShotNetPainter` (591), `paintFootballPitch` (688),
  `_dashedArc` (768).
- [`lib/widgets/cyber/goal_mouth.dart`](../../lib/widgets/cyber/goal_mouth.dart)
  — `GoalMouthFrame` (11), `GoalMouthFrame.diagram` (25), `paintGoalMouth` (51),
  `paintGoalBall` (168).
- [`lib/models/football_match_data.dart`](../../lib/models/football_match_data.dart)
  — `FootballShotOutcome` (129), `FootballShot` (146), `netPlacement` (187),
  `isGoal` (190), `reachedGoalFrame` (194), `isOnTarget` (203),
  `outcomeLabel` (208), `pitchOffset` (217), `footballAttackingOffset` (237).
- [`lib/screens/predictions/widgets/match_stats_shell.dart`](../../lib/screens/predictions/widgets/match_stats_shell.dart)
  — `StatsRowShell` (222), `TeamLegendMark` (382), `TeamLegendRow` (435).
- [`lib/widgets/cyber/cyber_chart.dart`](../../lib/widgets/cyber/cyber_chart.dart)
  — `CyberChartRangeTabs` (927).
- [`lib/config/theme.dart`](../../lib/config/theme.dart) — `Cyber` (558),
  `Cyber.glow` (597), `titleSmall` (713).
- Call site: `_MomentumSection` in
  [`football_match_stats_view.dart`](../../lib/screens/predictions/widgets/football_match_stats_view.dart)
  (437–443) — rendered only when `footballDetails?.shots` is non-empty.
- Tests: [`test/football_shot_map_test.dart`](../../test/football_shot_map_test.dart).
- Siblings: [`match-momentum-chart.md`](match-momentum-chart.md) (the chart this
  panel sits under, and the source of `CyberChartRangeTabs`) and
  [`match-timeline-panel.md`](match-timeline-panel.md).
- Product context: [`docs/product/systems/predictions.md`](../product/systems/predictions.md).

---

## Appendix A — model and frame maths, verbatim

From `lib/models/football_match_data.dart`. The long doc comments are the
coordinate contract — keep them, they are the only place it is written down:

```dart
enum FootballShotOutcome { goal, onTarget, offTarget, blocked }

/// One attempt with a tracked pitch position.
///
/// [fieldX] and [fieldY] are the feed's own normalised frame, rescaled to 0..1
/// and always expressed from the shooting side's point of view:
///
/// * [fieldX] is progress towards the goal being attacked — `1` is the goal
///   line, the penalty-area edge sits near `0.83` and six-yard-box efforts land
///   above `0.94`.
/// * [fieldY] runs across the pitch with the attacker's **left** as the high
///   value — left-of-goal attempts sit near `0.68`, central ones near `0.49`
///   and right-of-goal ones near `0.32`.
///
/// Both sides arrive in that same attacking frame and it does not flip at half
/// time, so drawing a full pitch means mirroring one team. Use [pitchOffset]
/// rather than reading the raw fields, so that mirroring stays in one place.
class FootballShot {
  const FootballShot({
    required this.playId,
    required this.minuteLabel,
    required this.minute,
    required this.period,
    required this.isHomeTeam,
    required this.team,
    required this.shooter,
    required this.outcome,
    required this.fieldX,
    required this.fieldY,
    required this.isHeader,
    this.zone,
    this.assist,
    this.netPlacement,
  });

  final String playId;
  final String minuteLabel;
  final int minute;
  final int period;
  final bool isHomeTeam;
  final String team;
  final String shooter;
  final String? assist;
  final FootballShotOutcome outcome;
  final String? zone;
  final double fieldX;
  final double fieldY;
  final bool isHeader;

  /// Where the attempt crossed the goal line, as the viewer faces the goal:
  /// `x` 0 at the left post and 1 at the right, `y` 0 at the crossbar and 1 at
  /// the ground. Values outside 0..1 are misses placed beyond the frame.
  ///
  /// Null when the attempt never reached the goal — every blocked shot, and any
  /// wording the feed uses that we do not recognise. A missing placement is
  /// left missing rather than defaulted to the centre.
  ///
  /// The feed describes placement in prose ("to the bottom left corner") without
  /// saying whose left. Broadcast convention is the viewer's, so that is what
  /// this uses; the feed cannot settle it either way.
  final (double, double)? netPlacement;

  bool get isGoal => outcome == FootballShotOutcome.goal;

  /// Whether the attempt has a placement inside the frame — true for goals and
  /// saves, false for misses (which sit outside it) and blocks (which have none).
  bool get reachedGoalFrame {
    final placement = netPlacement;
    if (placement == null) return false;
    final (x, y) = placement;
    return x >= 0 && x <= 1 && y >= 0 && y <= 1;
  }

  /// Whether the attempt made the goal frame (a goal counts).
  bool get isOnTarget =>
      outcome == FootballShotOutcome.goal ||
      outcome == FootballShotOutcome.onTarget;

  String get outcomeLabel => switch (outcome) {
    FootballShotOutcome.goal => 'GOAL',
    FootballShotOutcome.onTarget => 'ON TARGET',
    FootballShotOutcome.offTarget => 'OFF TARGET',
    FootballShotOutcome.blocked => 'BLOCKED',
  };

  /// The attempt placed on a full pitch measured `0..length` by `0..width`,
  /// with the home side attacking to the right and the away side to the left.
  (double, double) pitchOffset(double length, double width) =>
      footballAttackingOffset(
        fieldX,
        fieldY,
        length,
        width,
        attackingRight: isHomeTeam,
      );
}

/// Places a point given in the acting side's own attacking frame onto a pitch
/// measured `0..length` by `0..width`.
///
/// Both shots and touches arrive from the feed in that same frame — `x` is
/// progress towards the goal being attacked and `y` runs across the pitch with
/// the attacker's left as the high value — so one side has to be mirrored to
/// draw them together, and this is the single place that happens.
///
/// Screen `y` grows downwards, so a side facing right has its left hand at the
/// top of the pitch while a side facing left has it at the bottom — which is
/// why the two cases invert different axes.
(double, double) footballAttackingOffset(
  double fieldX,
  double fieldY,
  double length,
  double width, {
  required bool attackingRight,
}) => attackingRight
    ? (fieldX * length, (1 - fieldY) * width)
    : ((1 - fieldX) * length, fieldY * width);
```

`reachedGoalFrame` and `isOnTarget` are not used by the shot map (they serve other
views) but are cheap to keep and document the placement contract.

---

## Appendix B — shared widgets

### B.1 `StatsRowShell`, verbatim

The surface `_SelectedShotRow` sits on. Tinting is opt-in via `accent`; per the
glow rule it never glows.

```dart
/// The flat data-surface shell every stat row, event card and roster row sits
/// on — the market detail outcome-row container. Tinting is opt-in via
/// [accent]; per the glow rule it never glows.
class StatsRowShell extends StatelessWidget {
  const StatsRowShell({
    required this.child,
    this.accent,
    this.selected = false,
    this.onTap,
    this.padding = const EdgeInsets.all(10),
    super.key,
  });

  final Widget child;
  final Color? accent;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final accent = this.accent;
    final surface = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: selected && accent != null
            ? accent.withValues(alpha: 0.12)
            : Cyber.chartSurface,
        border: Border.all(
          color: selected && accent != null
              ? accent
              : accent?.withValues(alpha: 0.4) ?? Cyber.border,
        ),
      ),
      child: child,
    );
    if (onTap == null) return surface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: surface,
    );
  }
}
```

### B.2 `TeamLegendMark` and `TeamLegendRow`, verbatim

The colour→team legend above the outcome key.

```dart
/// Team identity marker used above a comparison block — a colour swatch, the
/// short code and the full name.
class TeamLegendMark extends StatelessWidget {
  const TeamLegendMark({
    required this.team,
    required this.sport,
    this.competition,
    this.alignEnd = false,
    super.key,
  });

  final SportTeam team;
  final Sport sport;
  final String? competition;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final color = paletteForTeam(
      team,
      sport: sport,
      competition: competition,
    ).secondaryTextColor;
    final swatch = Container(width: 4, height: 30, color: color);
    final copy = Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          team.shortName.toUpperCase(),
          style: Cyber.display(13, color: color),
        ),
        Text(
          team.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Cyber.label(8, color: Cyber.muted, letterSpacing: 0.8),
        ),
      ],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: alignEnd
          ? [Flexible(child: copy), const SizedBox(width: 8), swatch]
          : [swatch, const SizedBox(width: 8), Flexible(child: copy)],
    );
  }
}

/// The home/away identity pair that heads a comparison block. Both sides flex,
/// so a long club name ellipsises instead of overflowing the row.
class TeamLegendRow extends StatelessWidget {
  const TeamLegendRow({required this.match, super.key});

  final SportMatch match;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TeamLegendMark(
            team: match.home,
            sport: match.sport,
            competition: match.leagueId,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TeamLegendMark(
            team: match.away,
            sport: match.sport,
            competition: match.leagueId,
            alignEnd: true,
          ),
        ),
      ],
    );
  }
}
```

Both sides are `Expanded` with a `Flexible` copy column, so a long club name
ellipsises instead of overflowing. `TeamLegendMark` calls `paletteForTeam` itself —
the one place in this port that needs the palette stand-in besides the panel's own
`homeColor`/`awayColor`.

### B.3 `CyberChartRangeTabs`

Not reproduced here — it belongs to the charting engine and is given in full in
[`match-momentum-chart.md` §12](match-momentum-chart.md). The panel uses only:

```dart
CyberChartRangeTabs(
  ranges: ['ALL', '1ST', '2ND', 'GOALS'],
  active: _range,
  onChanged: (range) => setState(() { _range = range; _selectedPlayId = null; }),
)
```

Any equal-width tab strip with that signature will do. The app's version is a
`Row` of `Expanded` buttons, 30px tall with a 7px gap, where the active tab is the
single tinted element (cyan fill `0.14`, cyan border) and **does not glow**.

---

## Appendix C — tokens and stand-ins

### C.1 Flattened `Cyber`

The real `Cyber` ([`lib/config/theme.dart`](../../lib/config/theme.dart):558) is a
facade over `AppTheme` carrying the whole app palette. The shot map and the goal
mouth together touch **ten colours, `glow`, and two text helpers** — this is a
drop-in replacement with every alias resolved to a literal:

```dart
import 'package:flutter/material.dart'; // re-exports FontFeature

/// Only the tokens the shot map and goal mouth use. Values are the resolved
/// AppTheme literals from the source app.
class Cyber {
  // Surfaces
  static const bg = Color(0xFF0D111A); // turf @ 0.55, mark outlines
  static const bg2 = Color(0xFF070C1F); // the ball's seam
  static const chartSurface = Color(0xFF10192D); // panel + row fill

  // Lines
  static const border = Color(0xFF314158); // panel outline
  static const line = Color(0xFF45556C); // pitch markings, spots
  static const borderSubtle = Color(0x1AFFFFFF); // white @ 10% — faint markings

  // Text
  static const muted = Color(0xFF90A1B9); // captions, neutral swatches

  // Accents
  static const cyan = Color(0xFF5CDFFF); // titles, box tint, net mesh, facts
  static const lime = Color(0xFF51FF94); // the goal impact ring
  static const amber = Color(0xFFFF8904); // the goal frames (kept dim)

  /// The app's single glow source. Used once here, on the goal swatch:
  /// `Cyber.glow(Cyber.muted, alpha: 0.5, blur: 6)`.
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

  static const displayFont = 'Orbitron';
  static const bodyFont = 'Onest';

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
```

`borderSubtle` is white at 10% opacity — it must stay *translucent*, because it is
drawn over the turf and is meant to read as a faint marking rather than a second
line weight.

If you retarget the palette, the constraint that matters is that `line` and
`borderSubtle` stay legible over `bg @ 0.55` while staying quieter than any shot
mark. Markings that compete with the marks defeat the panel.

### C.2 The one non-`Cyber` text style

`_SelectedShotRow` styles the shooter name with
`AppTheme.darkTheme.textTheme.titleSmall`, which this app rebuilds as Orbitron.
The exact equivalent:

```dart
// was: AppTheme.darkTheme.textTheme.titleSmall
Cyber.display(14, letterSpacing: 0.8, weight: FontWeight.w800)
```

(Material's `titleSmall` is 14px; the app's `buildTextTheme` overrides it to
Orbitron `w800`, `letterSpacing: 0.8`, `height: 1`, white — which is exactly what
`Cyber.display` produces at those arguments.)

### C.3 Team accents — `paletteForTeam` stand-in

The real lookup ([`lib/data/team_palettes.dart`](../../lib/data/team_palettes.dart):4526)
resolves a sport- and competition-namespaced table of generated club palettes, then
falls back to deriving one from the team's colour. `secondaryTextColor` is
specifically the *accessible* member — the closest chromatic brand colour clearing
4.5:1 against every standard dark surface. Two `Color`s are needed:

```dart
/// Returns a team's accent, lightened until it clears 4.5:1 on the turf.
/// Replace the brand lookup with your own.
Color shotAccent(Color brand, {Color on = const Color(0xFF141A26)}) {
  var candidate = HSLColor.fromColor(brand);
  while (_contrast(candidate.toColor(), on) < 4.5 && candidate.lightness < 0.95) {
    candidate = candidate.withLightness(
      (candidate.lightness + 0.04).clamp(0.0, 1.0),
    );
  }
  return candidate.toColor();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
```

The default `on` is `Cyber.bg @ 0.55` composited over `Cyber.chartSurface` — the
turf, which is the darkest thing a mark is drawn on and therefore the binding
constraint. Checking against the panel fill alone is not enough.

With no brand colours, `Cyber.cyan` for home and `Cyber.magenta`
(`Color(0xFFC27AFF)`) for away is what the widget tests use and it reads correctly.

### C.4 Feed data

The shots come from a bundled match package in this app, decoded into
`FootballShot` before the UI sees them. Nothing in §3–§10 knows where they came
from, so a port only has to produce the list. The minimum each record needs:

| Field | Note |
| --- | --- |
| `playId` | must be unique — it is the selection key *and* the net animation key |
| `period` | `1` / `2`, drives the 1ST / 2ND filters |
| `fieldX`, `fieldY` | the attacking frame described in §2 |
| `isHomeTeam` | which way this side attacks |
| `outcome` | one of the four |
| `netPlacement` | goal-mouth space, or `null` when it never reached the goal |
| `minuteLabel`, `shooter`, `zone`, `assist`, `isHeader` | display only |

If your feed gives absolute pitch coordinates rather than an attacking frame, skip
`footballAttackingOffset` entirely and have `pitchOffset` return them scaled —
that is the single seam where a different data shape plugs in.
