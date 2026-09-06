import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../config/theme.dart';
import '../../../models/football_match_data.dart';
import '../../../widgets/team_logo.dart';
import 'football_shot_map.dart';

/// Smoothed touch density over the pitch.
///
/// Built once per player and cached by the widget — never inside `paint`. The
/// two steps that matter:
///
/// 1. **Bilinear splat.** Each touch is spread across the four nearest cell
///    centres by distance, so a player with 40 touches reads as a cloud rather
///    than 40 lit squares.
/// 2. **Two passes of a separable 1-2-1 blur**, which approximates a Gaussian
///    of about one cell — roughly 4.4 m, the right smoothing scale for football
///    and a few thousand float operations rather than an image filter.
class TouchHeatGrid {
  const TouchHeatGrid._({
    required this.cells,
    required this.peakIndex,
    required this.peakCount,
    required this.centroid,
    required this.sampleCount,
  });

  /// Cell counts across the pitch length and width. 24x16 puts a cell at about
  /// 4.4 m by 4.3 m.
  static const cols = 24;
  static const rows = 16;

  /// Normalised 0..1 density, row-major, `cols * rows` long.
  final List<double> cells;

  /// The hottest cell — the only thing on the panel allowed to glow.
  final int peakIndex;

  /// Raw weight in the hottest cell, before normalising.
  final double peakCount;

  /// Mean touch position in the 0..1 attacking frame, or null without touches.
  final (double, double)? centroid;

  final int sampleCount;

  bool get isEmpty => sampleCount == 0;

  /// [touches] are normalised 0..1 pairs in the acting side's attacking frame.
  ///
  /// [attackingRight] false mirrors the cloud, for a future view that draws
  /// both sides on one pitch. A single-player card always leaves it true: the
  /// card is about that player's own pitch, and flipping the away side would
  /// make their cards read backwards from the home side's for no benefit.
  factory TouchHeatGrid.from(
    List<(double, double)> touches, {
    bool attackingRight = true,
  }) {
    if (touches.isEmpty) {
      return const TouchHeatGrid._(
        cells: [],
        peakIndex: -1,
        peakCount: 0,
        centroid: null,
        sampleCount: 0,
      );
    }

    final grid = List<double>.filled(cols * rows, 0);
    var sumX = 0.0;
    var sumY = 0.0;

    for (final (rawX, rawY) in touches) {
      final (mx, my) = footballAttackingOffset(
        rawX,
        rawY,
        1,
        1,
        attackingRight: attackingRight,
      );
      sumX += mx;
      sumY += my;

      // Continuous cell-centre space: cell i spans [i, i+1), centre at i + 0.5.
      final fx = (mx * cols - 0.5).clamp(-0.5, cols - 0.5);
      final fy = (my * rows - 0.5).clamp(-0.5, rows - 0.5);
      final x0 = fx.floor();
      final y0 = fy.floor();
      final tx = fx - x0;
      final ty = fy - y0;

      void add(int cx, int cy, double weight) {
        if (cx < 0 || cx >= cols || cy < 0 || cy >= rows) return;
        grid[cy * cols + cx] += weight;
      }

      add(x0, y0, (1 - tx) * (1 - ty));
      add(x0 + 1, y0, tx * (1 - ty));
      add(x0, y0 + 1, (1 - tx) * ty);
      add(x0 + 1, y0 + 1, tx * ty);
    }

    final blurred = _blur(_blur(grid));

    var peak = 0.0;
    var peakIndex = 0;
    for (var i = 0; i < blurred.length; i++) {
      if (blurred[i] > peak) {
        peak = blurred[i];
        peakIndex = i;
      }
    }
    final normalised = peak <= 0
        ? blurred
        : [for (final value in blurred) value / peak];

    return TouchHeatGrid._(
      cells: List.unmodifiable(normalised),
      peakIndex: peakIndex,
      peakCount: peak,
      centroid: (sumX / touches.length, sumY / touches.length),
      sampleCount: touches.length,
    );
  }

  /// One separable 1-2-1 pass, horizontal then vertical, clamped at the edges
  /// so a touchline cell is not dragged towards zero by neighbours that do not
  /// exist.
  static List<double> _blur(List<double> source) {
    final horizontal = List<double>.filled(source.length, 0);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final left = source[y * cols + math.max(0, x - 1)];
        final mid = source[y * cols + x];
        final right = source[y * cols + math.min(cols - 1, x + 1)];
        horizontal[y * cols + x] = (left + 2 * mid + right) / 4;
      }
    }
    final out = List<double>.filled(source.length, 0);
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        final up = horizontal[math.max(0, y - 1) * cols + x];
        final mid = horizontal[y * cols + x];
        final down = horizontal[math.min(rows - 1, y + 1) * cols + x];
        out[y * cols + x] = (up + 2 * mid + down) / 4;
      }
    }
    return out;
  }
}

/// Paints a player's touch density onto a true-proportion pitch.
///
/// The cloud is built from **additive radial falloffs** rather than a blur
/// filter: every live cell draws a soft circle at [BlendMode.plus] inside one
/// `saveLayer`, so overlapping falloffs accumulate into smooth heat. That keeps
/// it dependency-free and cheap enough to animate.
class FootballPlayerHeatmapPainter extends CustomPainter {
  FootballPlayerHeatmapPainter({
    required this.grid,
    required this.accent,
    required this.reveal,
    this.showAveragePosition = true,
  });

  final TouchHeatGrid grid;
  final Color accent;

  /// 0..1 sweep of the left-to-right scan reveal.
  final double reveal;

  final bool showAveragePosition;

  /// Below this a cell is not worth a draw call — it would be invisible anyway.
  static const _floor = 0.06;

  /// Above this a cell earns the chamfered HUD outline.
  static const _hot = 0.72;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = PitchFrame.fit(size);
    paintFootballPitch(canvas, frame);
    if (grid.isEmpty) return;
    _paintHeat(canvas, frame);
    _paintHotCells(canvas, frame);
    if (showAveragePosition) _paintAveragePosition(canvas, frame);
  }

  /// Cool to hot: cyan through amber to white.
  ///
  /// Deliberately NOT keyed to the team colour. A ramp has to be perceptually
  /// ordered to be readable, and a club whose accent is already white or amber
  /// (Fulham, for one) would collapse the two ends into the same colour and
  /// wash the whole map out. Team identity enters through the panel border and
  /// the chamfered outlines on the hot cells instead.
  Color _heatColor(double value) {
    if (value < 0.35) {
      return Color.lerp(Cyber.cyan, Cyber.lime, value / 0.35)!;
    }
    if (value < 0.70) {
      return Color.lerp(Cyber.lime, Cyber.amber, (value - 0.35) / 0.35)!;
    }
    return Color.lerp(Cyber.amber, Colors.white, (value - 0.70) / 0.30)!;
  }

  /// How far a given cell has been uncovered by the scan. The sweep runs a
  /// little ahead of `reveal` so the trailing cells finish together.
  double _cellReveal(int col) {
    final normalised = (col + 0.5) / TouchHeatGrid.cols;
    return ((reveal * 1.25) - normalised).clamp(0.0, 1.0);
  }

  void _paintHeat(Canvas canvas, PitchFrame f) {
    final cellW = f.rect.width / TouchHeatGrid.cols;
    final cellH = f.rect.height / TouchHeatGrid.rows;
    final radius = math.sqrt(cellW * cellW + cellH * cellH) * 1.05;

    canvas.save();
    canvas.clipRect(f.rect);
    canvas.saveLayer(f.rect, Paint());
    for (var y = 0; y < TouchHeatGrid.rows; y++) {
      for (var x = 0; x < TouchHeatGrid.cols; x++) {
        final value = grid.cells[y * TouchHeatGrid.cols + x];
        if (value < _floor) continue;
        final progress = _cellReveal(x);
        if (progress <= 0) continue;
        final centre = Offset(
          f.rect.left + (x + 0.5) * cellW,
          f.rect.top + (y + 0.5) * cellH,
        );
        final colour = _heatColor(
          value,
        ).withValues(alpha: value * 0.62 * progress);
        canvas.drawCircle(
          centre,
          radius,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(centre, radius, [
              colour,
              colour.withValues(alpha: 0),
            ], const [0.0, 1.0]),
        );
      }
    }
    canvas.restore();
    canvas.restore();
  }

  /// The chamfered outline on the hottest cells. This is what makes the map
  /// read as HUD telemetry rather than a generic weather blob.
  void _paintHotCells(Canvas canvas, PitchFrame f) {
    final cellW = f.rect.width / TouchHeatGrid.cols;
    final cellH = f.rect.height / TouchHeatGrid.rows;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = accent.withValues(alpha: 0.5);

    for (var y = 0; y < TouchHeatGrid.rows; y++) {
      for (var x = 0; x < TouchHeatGrid.cols; x++) {
        final index = y * TouchHeatGrid.cols + x;
        final value = grid.cells[index];
        if (value < _hot) continue;
        if (_cellReveal(x) < 1) continue;
        final rect = Rect.fromLTWH(
          f.rect.left + x * cellW,
          f.rect.top + y * cellH,
          cellW,
          cellH,
        ).deflate(cellW * 0.14);
        final path = buildOctagonPath(rect, cutRatio: 0.3);
        canvas.drawPath(path, stroke);

        // The single glow on the panel: the one cell the player owned most.
        if (index == grid.peakIndex) {
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = Colors.white.withValues(alpha: 0.85)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
          );
        }
      }
    }
  }

  /// A crosshair at the player's mean position. Held back until the scan has
  /// almost finished so it lands as the closing beat rather than competing
  /// with the sweep.
  void _paintAveragePosition(Canvas canvas, PitchFrame f) {
    final centroid = grid.centroid;
    if (centroid == null || grid.sampleCount < 8) return;
    final fade = ((reveal - 0.85) / 0.15).clamp(0.0, 1.0);
    if (fade <= 0) return;

    final centre = Offset(
      f.rect.left + centroid.$1 * f.rect.width,
      f.rect.top + centroid.$2 * f.rect.height,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.9 * fade);
    const arm = 7.0;
    canvas.drawLine(
      centre.translate(-arm, 0),
      centre.translate(arm, 0),
      paint,
    );
    canvas.drawLine(
      centre.translate(0, -arm),
      centre.translate(0, arm),
      paint,
    );
    canvas.drawCircle(centre, 3.2, paint);
  }

  @override
  bool shouldRepaint(covariant FootballPlayerHeatmapPainter old) =>
      old.grid != grid ||
      old.accent != accent ||
      old.reveal != reveal ||
      old.showAveragePosition != showAveragePosition;
}
