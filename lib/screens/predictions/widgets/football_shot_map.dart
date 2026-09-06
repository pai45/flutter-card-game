import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../../models/football_match_data.dart';
import '../../../models/sport_match.dart';
import '../../../widgets/cyber/cyber_chart.dart';
import '../../../widgets/cyber/goal_mouth.dart';
import 'match_stats_shell.dart';

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
